"""Common utilties for cocotb simulator actions"""

load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")
load("@rules_vhdl//vhdl:defs.bzl", "VhdlInfo")

def collect_hdl_sources(module, *, sim, allowed_languages):
    """Walk a cocotb DUT's provider chain and stage its transitive HDL sources.

    Each simulator integration's `compile()` function calls this to turn the
    user-facing `cocotb_test.module` target into the full source set cocotb's
    runner needs at test time. The walk visits three layers per direction:

      1. The direct module's own `VhdlInfo` / `VerilogInfo` sources (and
         `hdrs` for `VerilogInfo`).
      2. Transitive same-language deps via `.deps`.
      3. Transitive cross-language deps via `VhdlInfo.verilog_deps`
         (from a VHDL DUT reaching Verilog) or `VerilogInfo.vhdl_deps`
         (from a Verilog DUT reaching VHDL). These are the depsets the
         hdl_library-elimination refactor introduced so `vhdl_library`
         and `verilog_library` can express component-bound cross-language
         instantiations without a shared wrapper rule.

    Cross-language deps that reach a language outside `allowed_languages`
    are rejected at analysis time. Silently dropping them would produce a
    much worse test-time failure — cocotb would build with an incomplete
    source list and the simulator would fail with "cannot resolve entity"
    long after the DUT wire-up decision was made.

    Args:
        module: `cocotb_test.module` target. Must provide at least one of
            `VhdlInfo` / `VerilogInfo` (both is legal — the walk visits
            each half independently).
        sim: str name of the calling simulator, used in error messages.
        allowed_languages: iterable of `"vhdl"` and/or `"verilog"`
            indicating what this sim can compile. VHDL-only sims
            (`ghdl`, `nvc`) pass `["vhdl"]`; Verilog-only sims
            (`icarus`, `verilator`, `vcs`) pass `["verilog"]`;
            mixed-language sims (`activehdl`, `dsim`, `questa`,
            `riviera`, `xcelium`) pass both.

    Returns:
        `struct(srcs, hdrs, data, runfiles, build_sources)` where:
            * `srcs` (`depset[File]`) — compilable HDL sources
              (`.v` / `.sv` / `.vhd` / `.vhdl`). Order is dep-first
              (`VhdlInfo.deps` / `VerilogInfo.deps` are postorder depsets),
              so VHDL package/entity compile order is naturally satisfied.
              Feed to `Runner.build(sources=srcs.to_list())` via
              `build_sources`, or to a Bazel-side compile action's
              command line (icarus / verilator).
            * `hdrs` (`depset[File]`) — Verilog/SV headers (`.vh` / `.svh`).
              Textually included by the preprocessor at compile time and
              must ship in runfiles alongside sources, but MUST NOT be
              handed to a compiler as a top-level compilation unit
              (iverilog would emit `syntax error` at the first header).
            * `data` (`depset[File]`) — runtime data files declared on
              any reachable library.
            * `runfiles` (`depset[File]`) — pre-merged `srcs + hdrs + data`
              suitable for `ctx.runfiles(transitive_files=)`. Handles the
              common case; simulators that also need to stage a per-sim
              library tree merge additional transitive depsets themselves.
            * `build_sources` (`list[File]`) — flat pre-materialised
              `srcs.to_list()` for direct use in `CocotbSimOutputInfo`.
    """
    src_depsets = []
    hdr_depsets = []
    data_depsets = []

    verilog_allowed = "verilog" in allowed_languages
    vhdl_allowed = "vhdl" in allowed_languages

    if VhdlInfo not in module and VerilogInfo not in module:
        fail("cocotb sim '{}': module '{}' must provide VerilogInfo or VhdlInfo".format(
            sim,
            module.label,
        ))

    if VhdlInfo in module:
        if not vhdl_allowed:
            fail(
                "cocotb sim '{}' does not support VHDL, but module '{}' provides ".format(sim, module.label) +
                "VhdlInfo. Choose a VHDL-capable sim (activehdl, dsim, ghdl, nvc, " +
                "questa, riviera, xcelium) or point `module` at a `verilog_library`.",
            )
        vhdl_info = module[VhdlInfo]
        for dep_info in vhdl_info.deps.to_list():
            src_depsets.append(dep_info.srcs)
            data_depsets.append(dep_info.data)
        src_depsets.append(vhdl_info.srcs)
        data_depsets.append(vhdl_info.data)

        cross_lang_verilog = vhdl_info.verilog_deps.to_list()
        if cross_lang_verilog and not verilog_allowed:
            fail(
                ("cocotb sim '{}' is VHDL-only, but module '{}' reaches Verilog " +
                 "sources through cross-language `verilog_deps` on a `vhdl_library` " +
                 "in its dep chain. Cross-language libraries: {}. Switch to a " +
                 "mixed-language sim (activehdl, dsim, questa, riviera, xcelium) " +
                 "or split the DUT so the cocotb top exercises only one language.").format(
                    sim,
                    module.label,
                    sorted([info.library for info in cross_lang_verilog if info.library]),
                ),
            )
        for dep_info in cross_lang_verilog:
            src_depsets.append(dep_info.srcs)
            hdr_depsets.append(dep_info.hdrs)
            data_depsets.append(dep_info.data)

    if VerilogInfo in module:
        if not verilog_allowed:
            fail(
                "cocotb sim '{}' does not support Verilog, but module '{}' provides ".format(sim, module.label) +
                "VerilogInfo. Choose a Verilog-capable sim (activehdl, dsim, icarus, " +
                "questa, riviera, vcs, verilator, xcelium) or point `module` at a " +
                "`vhdl_library`.",
            )
        verilog_info = module[VerilogInfo]
        for dep_info in verilog_info.deps.to_list():
            src_depsets.append(dep_info.srcs)
            hdr_depsets.append(dep_info.hdrs)
            data_depsets.append(dep_info.data)
        src_depsets.append(verilog_info.srcs)
        hdr_depsets.append(verilog_info.hdrs)
        data_depsets.append(verilog_info.data)

        cross_lang_vhdl = verilog_info.vhdl_deps.to_list()
        if cross_lang_vhdl and not vhdl_allowed:
            fail(
                ("cocotb sim '{}' is Verilog-only, but module '{}' reaches VHDL " +
                 "sources through cross-language `vhdl_deps` on a `verilog_library` " +
                 "in its dep chain. Cross-language libraries: {}. Switch to a " +
                 "mixed-language sim (activehdl, dsim, questa, riviera, xcelium) " +
                 "or split the DUT so the cocotb top exercises only one language.").format(
                    sim,
                    module.label,
                    sorted([info.library for info in cross_lang_vhdl if info.library]),
                ),
            )
        for dep_info in cross_lang_vhdl:
            src_depsets.append(dep_info.srcs)
            data_depsets.append(dep_info.data)

    srcs = depset(transitive = src_depsets)
    hdrs = depset(transitive = hdr_depsets)
    data = depset(transitive = data_depsets)
    return struct(
        srcs = srcs,
        hdrs = hdrs,
        data = data,
        runfiles = depset(transitive = [srcs, hdrs, data]),
        build_sources = srcs.to_list(),
    )

# Shared `env` attribute used by every `cocotb_*_sim` rule. Surfaced on
# the rule's `CocotbSimInfo.env` field; consumed by `cocotb_test` when
# it builds the `--sim_env` list passed to the process wrapper. The doc
# describes the test-time precedence ordering.
SIM_ENV_ATTR = attr.string_dict(
    doc = (
        "Environment variables to set when the cocotb runner invokes " +
        "this simulator at test time (license-server pointers, install " +
        "root vars, …). Precedence: toolchain `env` < sim `env` < " +
        "rule-level `cocotb_test(env = ...)`."
    ),
    default = {},
)

CocotbSimOutputInfo = provider(
    doc = "Compiled simulator outputs.",
    fields = {
        "bin": "File-or-None: The pre-compiled executable artifact for cocotb to run. Set when the simulator integration pre-compiles at Bazel time (e.g. `cocotb_icarus_sim`/`cocotb_verilator_sim`). Leave unset for build-at-test-time rules — cocotb's `Runner.build()` will produce its own artifact under `test_dir`. When `bin` is set, cocotb's runner uses `bin.parent` as `build_dir` and finds the artifact at the simulator's conventional `sim_file` path (e.g. `sim.vvp`, `simv`, `<hdl_toplevel>`).",
        "build_args": "list[str]: Optional extra args forwarded to cocotb runner's `build_args` (per-simulator compile flags). Only relevant when `build_sources` is set.",
        "build_sources": "list[File]: Optional source files to (re)build at test time via `cocotb_tools.runner.Runner.build()`. Required for build-at-test-time rules (no pre-compiled `bin`) and for JIT-only simulators whose pre-built work libraries aren't relocatable (e.g. GHDL).",
        "runfiles": "Runfiles: The runfiles object carrying the artifacts and sources cocotb needs at test time.",
        "sim_env": """\
dict[str, str]: Optional environment variables to set when invoking cocotb's
runner at test time. Literal string values are set verbatim; values prefixed
with `abs:[upN:]<rlocationpath>` are resolved by the cocotb process wrapper
to an absolute filesystem path, optionally walking N parent directories up
(e.g. `abs:up3:ghdl+/vhdl_libs_v08/ieee/v08/ieee-obj08.cf` resolves to the
`vhdl_libs_v08` root directory).
""",
        "test_args": "list[str]: Optional extra args forwarded to cocotb runner's `test_args` (per-simulator command-line flags).",
    },
)

def _cocotb_sim_info_init(*, all_files, bins, compile, env = {}, coverage = None):
    return {
        "all_files": all_files,
        "bins": bins,
        "compile": compile,
        "coverage": coverage,
        "env": env,
    }

CocotbSimInfo, _ = provider(
    doc = """\
Common simulator interface required by the cocotb toolchain.

`CocotbSimInfo` is the *only* contract `cocotb_test` and `cocotb_toolchain`
depend on — any target that returns it can plug into the toolchain's
`simulators` dict. The shipped `cocotb_*_sim` rules each return one (plus
their own per-simulator extension provider, e.g. `CocotbSimGhdlInfo`), but
they aren't privileged in any way.

This is the public extension point for shipping a simulator the bundled
rules don't cover, or wrapping an install shape they don't fit (vendored
tarball, system `.deb`, internal corp build, ...). Write a Starlark rule
whose impl returns `CocotbSimInfo`, drop it into a `cocotb_toolchain`
under the simulator name of your choice, and `cocotb_test(sim = ...)`
resolves through it.

Simulator-specific providers (`CocotbSimGhdlInfo`, `CocotbSimIcarusInfo`,
etc.) are only consumed by the corresponding shipped `compile` function —
custom rules don't need to return them unless they want to reuse a
shipped `compile`.
""",
    init = _cocotb_sim_info_init,
    fields = {
        "all_files": "depset[File]: All transitive runfiles required by the simulator.",
        "bins": "dict[str, File]: Simulator binaries to place on PATH at test time. Keys are the expected binary names (e.g. {'verilator': <File>} or {'iverilog': <File>, 'vvp': <File>}).",
        "compile": "callable: A function with signature `compile(ctx, simulator, module, sim_opts) -> CocotbSimOutputInfo` that performs code-generation and compilation for this simulator.",
        "coverage": ("struct-or-None: Per-sim coverage bridge for " +
                     "`bazel coverage`. When set AND the test's compile " +
                     "step instrumented the sim binary (typically via " +
                     "`ctx.coverage_instrumented()`), the wrapper invokes " +
                     "the tool after `runner.test()` returns, producing " +
                     "lcov at `$COVERAGE_OUTPUT_FILE`. Fields:\n" +
                     "  * `tool` (Target): post-processor binary. The " +
                     "consumer pulls `[DefaultInfo].files_to_run.executable` " +
                     "for the wrapper arg AND `default_runfiles` so the " +
                     "launcher's interpreter + sibling data ship alongside " +
                     "the executable (lets py_venv-shaped binaries work, " +
                     "not just single-file native tools).\n" +
                     "  * `args` (list[str]): args template. `{output}` " +
                     "is substituted with `$COVERAGE_OUTPUT_FILE`; " +
                     "`{data_files}` is substituted with the absolute " +
                     "paths of files matching `data_glob` in the sim's " +
                     "build dir (one positional arg per file).\n" +
                     "  * `data_glob` (str): shell glob, relative to the " +
                     "sim's build dir, matching the raw coverage data " +
                     "file(s) the tool consumes.\n" +
                     "Verilator example: " +
                     "`struct(tool=verilator_coverage_target, " +
                     "args=['--write-info', '{output}', '{data_files}'], " +
                     "data_glob='coverage.dat')`. " +
                     "GHDL example: `struct(tool=ghdl_target, " +
                     "args=['coverage', '--format=lcov', '-o', '{output}', " +
                     "'{data_files}'], data_glob='*.cov')`. " +
                     "Sims that don't support coverage leave this None; " +
                     "the wrapper skips the bridge."),
        "env": "dict[str, str]: Environment variables this simulator needs when the cocotb runner invokes it at test time (e.g. license-server pointers, install-root vars). Surfaced from the sim rule's `env` attr; defaults to `{}` when a sim integration omits it. Precedence at test time: toolchain `env` < sim `env` < rule-level `cocotb_test(env = ...)`.",
    },
)
