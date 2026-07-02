"""Cocotb Siemens DSim simulator integration"""

load(
    ":cocotb_sim_utils.bzl",
    "CocotbSimInfo",
    "CocotbSimOutputInfo",
    "SIM_ENV_ATTR",
    "collect_hdl_sources",
)

CocotbSimDsimInfo = provider(
    doc = "DSim-specific extension of `CocotbSimInfo`.",
    fields = {
        "all_files": "depset[File]: All transitive runfiles required by the DSim tools.",
        "dsim": "File: The `dsim` simulator executable.",
    },
)

def dsim_compile(ctx, simulator, module, sim_opts):
    """Stage HDL sources for a DSim simulation at test time.

    No Bazel-time invocation of `dsim` happens — the simulator is
    commercial and not generally available in CI. The cocotb runner
    does the actual build at test time via `Runner.build(sources=...)`.

    Args:
        ctx (ctx): The rule's context object.
        simulator (Target): The `cocotb_dsim_sim` target.
        module (Target): The HDL module to compile (`VerilogInfo` or `VhdlInfo`).
        sim_opts (list): Additional flags forwarded to cocotb's runner.

    Returns:
        CocotbSimOutputInfo: Provider with a stamp file and the sources
        cocotb's runner will (re)compile at test time.
    """
    sim_info = simulator[CocotbSimDsimInfo]
    if not sim_info.dsim:
        fail("cocotb_dsim_sim requires a dsim binary")

    # Walk transitive same-language + cross-language deps. `dsim` handles
    # both `.v`/`.sv` and `.vhd` inputs via its unified driver, so
    # mixed-language DUTs require every reachable source on the command
    # line (including cross-lang `verilog_deps` / `vhdl_deps`).
    sources = collect_hdl_sources(
        module,
        sim = "dsim",
        allowed_languages = ["vhdl", "verilog"],
    )

    return CocotbSimOutputInfo(
        runfiles = ctx.runfiles(transitive_files = sources.runfiles),
        build_args = list(sim_opts),
        build_sources = sources.build_sources,
    )

def _cocotb_dsim_sim_impl(ctx):
    all_files = ctx.attr.dsim[DefaultInfo].default_runfiles.files

    return [
        CocotbSimInfo(
            all_files = all_files,
            bins = {"dsim": ctx.executable.dsim},
            compile = dsim_compile,
            env = ctx.attr.env,
        ),
        CocotbSimDsimInfo(
            all_files = all_files,
            dsim = ctx.executable.dsim,
        ),
    ]

cocotb_dsim_sim = rule(
    doc = """\
A simulator configuration for running [Siemens
DSim](https://www.metrics.ca/dsim/) (formerly Metrics DSim) simulations
in cocotb tests.

### Status

Infrastructure only. DSim is commercial, with no BCR module and no
redistributable binary; `rules_cocotb` cannot validate this rule in
CI. Wire it up downstream by pointing `dsim` at your own install and
registering a `cocotb_toolchain` that routes `sim = "dsim"` through
this rule. Cocotb's runner handles the actual build/sim via
`Runner.build` / `Runner.test`.

### Notes

DSim accepts both Verilog/SystemVerilog (`VerilogInfo`) and VHDL
(`VhdlInfo`) modules. The `dsim` driver handles compile and run
phases internally, so only the one binary attr is needed.
""",
    implementation = _cocotb_dsim_sim_impl,
    attrs = {
        "dsim": attr.label(
            doc = "The `dsim` simulator binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "env": SIM_ENV_ATTR,
    },
)
