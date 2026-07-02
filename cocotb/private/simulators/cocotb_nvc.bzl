"""Cocotb NVC simulator integration"""

load(
    ":cocotb_sim_utils.bzl",
    "CocotbSimInfo",
    "CocotbSimOutputInfo",
    "SIM_ENV_ATTR",
    "collect_hdl_sources",
)

# Basename used for the per-instance consolidated library tree. The
# rloc helper below picks it out of `vhdl_libs` runfiles without
# enumerating the opaque TreeArtifact's contents.
_LIBROOT_DIRNAME = "nvc_libs_root"

def _stage_vhdl_libs(ctx):
    """Stage every input library TreeArtifact under one root.

    Each entry of `ctx.attr.vhdl_libs` is expected to be a
    per-library TreeArtifact whose basename is the NVC library
    identifier (`std`, `ieee`, `nvc.08`, ...). They're laid out as
    siblings of one another inside a single TreeArtifact output, so
    `NVC_LIBPATH` only needs a single value at sim time.

    Lives in rules_cocotb (not the BCR `nvc` module) because an
    upstream packaging of nvc — a `.tar.gz` redistribution, a `.deb`,
    a system install — exposes per-library directories at a fixed
    layout rather than a single Bazel-rule-derived TreeArtifact root.
    The BCR module mirrors that shape (a `filegroup` of per-library
    TreeArtifacts); the consolidation lives here, inside the
    simulator integration that actually needs it.

    Returns `None` when `vhdl_libs` is empty (the caller leaves
    `NVC_LIBPATH` unset and nvc falls back to its compiled-in
    defaults).
    """
    libs = []
    for t in ctx.attr.vhdl_libs:
        libs.extend(t.files.to_list())
    if not libs:
        return None

    out = ctx.actions.declare_directory(ctx.label.name + "/" + _LIBROOT_DIRNAME)

    args = ctx.actions.args()
    args.add_all([out], before_each = "--out", expand_directories = False)
    args.add_all(libs, before_each = "--lib", expand_directories = False)

    ctx.actions.run(
        executable = ctx.executable._libdir_stage,
        arguments = [args],
        inputs = depset(libs),
        outputs = [out],
        mnemonic = "NvcLibdirStage",
        progress_message = "Staging NVC library tree for %s" % ctx.label,
    )
    return out

def _libroot_rloc(ctx, lib_root_file):
    """Return the rlocationpath spec for the consolidated NVC library root."""
    if lib_root_file.short_path.startswith("../"):
        return lib_root_file.short_path[len("../"):]
    return "{}/{}".format(ctx.workspace_name, lib_root_file.short_path)

CocotbSimNvcInfo = provider(
    doc = "NVC-specific extension of `CocotbSimInfo`.",
    fields = {
        "all_files": "depset[File]: All transitive runfiles required by the NVC tools.",
        "lib_root": "File-or-None: Consolidated NVC library root TreeArtifact (or None when `vhdl_libs` was empty).",
        "nvc": "File: The `nvc` simulator executable.",
        "nvc_libpath": "str: Literal value to set as `NVC_LIBPATH` at sim time. Empty falls back to deriving from `lib_root`, or to nvc's compiled-in defaults.",
    },
)

def nvc_compile(ctx, simulator, module, sim_opts):
    """Stage VHDL sources for an NVC simulation at test time.

    Bazel-time `nvc -a` runs are intentionally skipped: cocotb's
    `Runner.build()` invokes the full `nvc -a / -e / -r` pipeline in
    a writable build_dir at test time, and the consolidated library
    root we point `NVC_LIBPATH` at is read-only — nvc creates its own
    writable work library in the test's build_dir and finds
    STD/IEEE/NVC inside the staged libroot.

    Args:
        ctx (ctx): The rule's context object.
        simulator (Target): The `cocotb_nvc_sim` target.
        module (Target): The VHDL module to compile (must provide `VhdlInfo`).
        sim_opts (list): Additional flags forwarded to cocotb's runner.

    Returns:
        CocotbSimOutputInfo: Provider with the sources cocotb's runner
        will compile at test time plus `NVC_LIBPATH` if `vhdl_libs`
        was wired.
    """
    sim_info = simulator[CocotbSimNvcInfo]
    if not sim_info.nvc:
        fail("cocotb_nvc_sim requires an nvc binary")

    # Walk transitive VHDL deps. NVC is VHDL-only, so a Verilog dep
    # (whether via `VerilogInfo` on the top or via a `vhdl_library`'s
    # `verilog_deps`) is rejected at analysis time — nvc would otherwise
    # fail at `nvc -a` with an unhelpful "unit not found" error.
    sources = collect_hdl_sources(
        module,
        sim = "nvc",
        allowed_languages = ["vhdl"],
    )

    sim_env = {}
    if sim_info.nvc_libpath:
        # Literal override — appropriate for system installs that know
        # their own prefix (e.g. "/usr/local/lib/nvc" on a Debian box).
        sim_env["NVC_LIBPATH"] = sim_info.nvc_libpath
    elif sim_info.lib_root:
        # Fall back to deriving NVC_LIBPATH from the staged library
        # root. The cocotb wrapper resolves the rlocationpath to an
        # absolute path at test time.
        sim_env["NVC_LIBPATH"] = "abs:" + _libroot_rloc(ctx, sim_info.lib_root)

    lib_root_files = [sim_info.lib_root] if sim_info.lib_root else []
    return CocotbSimOutputInfo(
        runfiles = ctx.runfiles(
            transitive_files = depset(
                direct = lib_root_files,
                transitive = [sources.runfiles],
            ),
        ),
        sim_env = sim_env,
        build_args = list(sim_opts),
        build_sources = sources.build_sources,
    )

def _cocotb_nvc_sim_impl(ctx):
    lib_root = _stage_vhdl_libs(ctx)
    lib_root_files = [lib_root] if lib_root else []
    all_files = depset(
        direct = lib_root_files,
        transitive = [ctx.attr.nvc[DefaultInfo].default_runfiles.files],
    )

    return [
        CocotbSimInfo(
            all_files = all_files,
            bins = {"nvc": ctx.executable.nvc},
            compile = nvc_compile,
            env = ctx.attr.env,
        ),
        CocotbSimNvcInfo(
            all_files = all_files,
            lib_root = lib_root,
            nvc = ctx.executable.nvc,
            nvc_libpath = ctx.attr.nvc_libpath,
        ),
    ]

cocotb_nvc_sim = rule(
    doc = """\
A simulator configuration for running [NVC](https://www.nickg.me.uk/nvc/)
(open-source VHDL simulator) in cocotb tests.

### Status

Working against the BCR `nvc` module from version `1.21.0` onward,
which links the `nvc` binary with `-Wl,--dynamic-list=src/symbols.txt`
so cocotb's `libcocotbvpi_nvc.so` plugin can resolve unprefixed
`vpi_*` / `vhpi_*` symbols at `dlopen` time.

### Notes

NVC only supports VHDL (`VhdlInfo`); pair it with a `vhdl_library`
target as the `module`. The integration is build-at-test-time:
cocotb's runner runs `nvc -a` / `-e` / `-r` in a writable build_dir
via `Runner.build()` / `Runner.test()`.

`vhdl_libs` accepts a list of per-library TreeArtifact targets —
typically `["@nvc//:vhdl_libs"]`, the BCR `nvc` module's filegroup
of per-library directories laid out exactly like a system install
under `<prefix>/lib/nvc/<library>/`. The rule's implementation
stages those TreeArtifacts side-by-side under a single root and
points `NVC_LIBPATH` at it so nvc finds every shipped library (STD,
IEEE, NVC, plus the SYNOPSYS / VITAL extras inside IEEE) at
simulation time.
""",
    implementation = _cocotb_nvc_sim_impl,
    attrs = {
        "env": SIM_ENV_ATTR,
        "nvc": attr.label(
            doc = "The `nvc` simulator binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "nvc_libpath": attr.string(
            doc = """\
Literal value to set as `NVC_LIBPATH` at simulation time. Use this
for nvc installs where the prefix is a stable absolute path on disk —
typically a system / `.deb` / Homebrew install
(e.g. `"/usr/local/lib/nvc"`).

When unset (default), `NVC_LIBPATH` is auto-derived from `vhdl_libs`
if it's populated (per-library TreeArtifacts staged into one root by
this rule), otherwise left unset so nvc falls back to its own
compiled-in search paths.
""",
        ),
        "vhdl_libs": attr.label_list(
            doc = """\
Per-library TreeArtifact targets to stage side-by-side under a
single `NVC_LIBPATH` root. Typically `["@nvc//:vhdl_libs"]` — the
BCR `nvc` module's filegroup of per-library directories. Empty (the
default) leaves `NVC_LIBPATH` unset.
""",
            allow_files = True,
            cfg = "exec",
        ),
        "_libdir_stage": attr.label(
            default = Label("//tools/nvc_libdir_stage"),
            executable = True,
            cfg = "exec",
        ),
    },
)
