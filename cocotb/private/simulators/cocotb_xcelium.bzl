"""Cocotb Cadence Xcelium / Incisive simulator integration"""

load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")
load("@rules_vhdl//vhdl:defs.bzl", "VhdlInfo")
load(":cocotb_sim_utils.bzl", "CocotbSimInfo", "CocotbSimOutputInfo", "SIM_ENV_ATTR")

CocotbSimXceliumInfo = provider(
    doc = "Xcelium/Incisive-specific extension of `CocotbSimInfo`.",
    fields = {
        "all_files": "depset[File]: All transitive runfiles required by the Xcelium tools.",
        "xrun": "File: The `xrun` driver executable.",
    },
)

def xcelium_compile(ctx, simulator, module, sim_opts):
    """Stage HDL sources for an Xcelium/Incisive simulation at test time.

    No Bazel-time invocation of `xrun` happens — the simulator is
    commercial and not generally available in CI. The cocotb runner does
    the actual build at test time via `Runner.build(sources=...)`.

    Args:
        ctx (ctx): The rule's context object.
        simulator (Target): The `cocotb_xcelium_sim` target.
        module (Target): The HDL module to compile (`VerilogInfo` or `VhdlInfo`).
        sim_opts (list): Additional flags forwarded to cocotb's runner.

    Returns:
        CocotbSimOutputInfo: Provider with a stamp file and the sources
        cocotb's runner will (re)compile at test time.
    """
    sim_info = simulator[CocotbSimXceliumInfo]
    if not sim_info.xrun:
        fail("cocotb_xcelium_sim requires an xrun binary")

    if VerilogInfo in module:
        all_srcs = module[VerilogInfo].srcs
        all_data = module[VerilogInfo].data
    elif VhdlInfo in module:
        all_srcs = module[VhdlInfo].srcs
        all_data = module[VhdlInfo].data
    else:
        fail("Module must provide VerilogInfo or VhdlInfo")

    return CocotbSimOutputInfo(
        runfiles = ctx.runfiles(
            transitive_files = depset(transitive = [all_srcs, all_data]),
        ),
        build_args = list(sim_opts),
        build_sources = all_srcs.to_list(),
    )

def _cocotb_xcelium_sim_impl(ctx):
    all_files = ctx.attr.xrun[DefaultInfo].default_runfiles.files

    return [
        CocotbSimInfo(
            all_files = all_files,
            bins = {"xrun": ctx.executable.xrun},
            compile = xcelium_compile,
            env = ctx.attr.env,
        ),
        CocotbSimXceliumInfo(
            all_files = all_files,
            xrun = ctx.executable.xrun,
        ),
    ]

cocotb_xcelium_sim = rule(
    doc = """\
A simulator configuration for running [Cadence
Xcelium](https://www.cadence.com/en_US/home/tools/system-design-and-verification/simulation-and-testbench-verification/xcelium-simulator.html)
(and the older Incisive — cocotb uses the same `xcelium` runner for
both) simulations in cocotb tests.

### Status

Infrastructure only. Xcelium/Incisive is commercial, with no BCR
module and no redistributable binary; `rules_cocotb` cannot validate
this rule in CI. Wire it up downstream by pointing `xrun` at your own
install and registering a `cocotb_toolchain` that routes
`sim = "xcelium"` through this rule. Cocotb's runner handles the
actual build/sim via `Runner.build` / `Runner.test`.

### Notes

Xcelium accepts both Verilog/SystemVerilog (`VerilogInfo`) and VHDL
(`VhdlInfo`) modules. The `xrun` driver dispatches to the appropriate
compiler internally, so only the one binary attr is needed.
""",
    implementation = _cocotb_xcelium_sim_impl,
    attrs = {
        "env": SIM_ENV_ATTR,
        "xrun": attr.label(
            doc = "The `xrun` driver binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
    },
)
