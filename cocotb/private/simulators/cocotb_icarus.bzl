"""Cocotb Icarus Verilog simulator integration"""

load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")
load(":cocotb_sim_utils.bzl", "CocotbSimInfo", "CocotbSimOutputInfo", "SIM_ENV_ATTR")

CocotbSimIcarusInfo = provider(
    doc = "Icarus Verilog-specific extension of `CocotbSimInfo`.",
    fields = {
        "all_files": "depset[File]: All transitive runfiles required by the Icarus tools.",
        "iverilog": "File: The `iverilog` compiler executable.",
        "ivl_base": "File: The assembled IVL base directory (contains ivl, vvp.tgt, etc.).",
        "vvp": "File: The `vvp` simulation runner executable.",
    },
)

def icarus_compile(ctx, simulator, module, sim_opts):
    """Compile Verilog sources with Icarus Verilog.

    Runs `iverilog` to produce a VVP simulation binary that cocotb's Icarus
    runner can execute via `vvp`.

    Args:
        ctx (ctx): The rule's context object.
        simulator (Target): The `cocotb_icarus_sim` target.
        module (Target): The Verilog module to compile.
        sim_opts (list): Additional flags for `iverilog`.

    Returns:
        CocotbSimOutputInfo: Provider with the compiled VVP binary and runfiles.
    """
    sim_info = simulator[CocotbSimIcarusInfo]
    verilog_info = module[VerilogInfo]
    all_srcs = verilog_info.srcs
    all_data = verilog_info.data

    module_top = module.label.name

    output_vvp = ctx.actions.declare_file(
        "{}.icarus/sim.vvp".format(ctx.label.name),
    )

    args = ctx.actions.args()
    args.add("-o", output_vvp)
    args.add("-DCOCOTB_SIM=1")
    args.add("-g2012")
    args.add("-s", module_top)
    args.add_all(ctx.attr.params, format_each = "-P%s")
    args.add_all(sim_opts)
    args.add_all(all_srcs)

    env = {}
    if sim_info.ivl_base:
        env["IVL_BASE"] = sim_info.ivl_base.path

    ctx.actions.run(
        arguments = [args],
        mnemonic = "CocotbIcarusCompile",
        executable = sim_info.iverilog,
        inputs = all_srcs,
        outputs = [output_vvp],
        tools = sim_info.all_files,
        env = env,
    )

    return CocotbSimOutputInfo(
        bin = output_vvp,
        runfiles = ctx.runfiles(transitive_files = all_data),
    )

def _assemble_ivl_base(ctx):
    """Assemble the IVL base directory from individual component labels."""
    if not ctx.attr.ivl_files:
        return None, depset()

    base_dir = ctx.actions.declare_directory("_ivl_base")

    commands = ["mkdir -p {}/include".format(base_dir.path)]
    inputs = []
    for target, dest_name in ctx.attr.ivl_files.items():
        f = target.files.to_list()[0]
        inputs.append(f)
        if "/" in dest_name:
            commands.append("mkdir -p {}/{}".format(base_dir.path, dest_name.rsplit("/", 1)[0]))
        commands.append("cp {} {}/{}".format(f.path, base_dir.path, dest_name))

    ctx.actions.run_shell(
        command = " && ".join(commands),
        inputs = inputs,
        outputs = [base_dir],
        mnemonic = "CocotbIcarusIvlBase",
    )

    return base_dir, depset([base_dir])

def _resolve_ivl_base(ctx):
    """Return (File-or-None, depset) for the IVL base directory."""
    if ctx.attr.ivl_base and ctx.attr.ivl_files:
        fail("Set at most one of `ivl_base` and `ivl_files` on {}".format(ctx.label))

    if ctx.attr.ivl_base:
        files = ctx.attr.ivl_base[DefaultInfo].files.to_list()
        if len(files) != 1:
            fail("`ivl_base` on {} must point at a single file/directory; got {} files".format(
                ctx.label,
                len(files),
            ))
        return files[0], depset(files)

    return _assemble_ivl_base(ctx)

def _cocotb_icarus_sim_impl(ctx):
    iverilog_files = ctx.attr.iverilog[DefaultInfo].default_runfiles.files
    vvp_files = ctx.attr.vvp[DefaultInfo].default_runfiles.files
    transitive = [iverilog_files, vvp_files]

    ivl_base_dir, ivl_base_depset = _resolve_ivl_base(ctx)
    if ivl_base_dir:
        transitive.append(ivl_base_depset)

    all_files = depset(transitive = transitive)

    iverilog_exe = ctx.executable.iverilog
    vvp_exe = ctx.executable.vvp

    return [
        CocotbSimInfo(
            all_files = all_files,
            bins = {
                "iverilog": iverilog_exe,
                "vvp": vvp_exe,
            },
            compile = icarus_compile,
            env = ctx.attr.env,
        ),
        CocotbSimIcarusInfo(
            all_files = all_files,
            iverilog = iverilog_exe,
            ivl_base = ivl_base_dir,
            vvp = vvp_exe,
        ),
    ]

cocotb_icarus_sim = rule(
    doc = """\
A simulator configuration for running [Icarus
Verilog](https://github.com/steveicarus/iverilog) binaries in cocotb tests.

### Status

Fully functional. Sourced from the BCR `iverilog` module
(`bazel_dep(name = "iverilog", version = "13.0.bcr.1")`). The default
toolchain wires `iverilog`, `vvp`, and the IVL backend components.
Exercised end-to-end by the in-tree `adder_icarus_test`.

### Notes

The `iverilog` driver locates its backend components (`ivl`,
`vvp.tgt`, `system.vpi`, etc.) via the `IVL_BASE` environment variable.
For the BCR `iverilog` module, the components are exposed as individual
labels; this rule's `ivl_files` attribute maps each label to its
expected filename and assembles them into a directory for `IVL_BASE`.

Icarus only supports Verilog/SystemVerilog (`VerilogInfo`); pair it
with a `verilog_library` target as the `module`.
""",
    implementation = _cocotb_icarus_sim_impl,
    attrs = {
        "env": SIM_ENV_ATTR,
        "iverilog": attr.label(
            doc = "The `iverilog` compiler binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "ivl_base": attr.label(
            doc = """\
A pre-assembled `IVL_BASE` directory (e.g. a `filegroup` wrapping
`/usr/lib/ivl` for a system iverilog). The rule sets `IVL_BASE` to
this directory's path during compilation. Mutually exclusive with
`ivl_files`.
""",
            allow_single_file = True,
            cfg = "exec",
        ),
        "ivl_files": attr.label_keyed_string_dict(
            doc = """\
Components to assemble into an `IVL_BASE` directory. Maps source
labels to destination filenames (e.g. `{"@iverilog//:ivl": "ivl",
"@iverilog//tgt-vvp:vvp_tgt": "vvp.tgt"}`). Designed for the BCR
`iverilog` module's per-component layout — for an `IVL_BASE` directory
that already exists on disk, use `ivl_base` instead. Mutually exclusive
with `ivl_base`.
""",
            allow_files = True,
            cfg = "exec",
        ),
        "vvp": attr.label(
            doc = "The `vvp` simulation runner binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
    },
)
