"""Cocotb Questa / ModelSim simulator integration"""

load(
    ":cocotb_sim_utils.bzl",
    "CocotbSimInfo",
    "CocotbSimOutputInfo",
    "SIM_ENV_ATTR",
    "collect_hdl_sources",
)

CocotbSimQuestaInfo = provider(
    doc = "Questa/ModelSim-specific extension of `CocotbSimInfo`.",
    fields = {
        "all_files": "depset[File]: All transitive runfiles required by the Questa tools.",
        "vcom": "File: The `vcom` VHDL compiler executable.",
        "vlib": "File: The `vlib` library manager executable.",
        "vlog": "File: The `vlog` Verilog compiler executable.",
        "vsim": "File: The `vsim` simulator executable.",
    },
)

def questa_compile(ctx, simulator, module, sim_opts):
    """Stage HDL sources for a Questa/ModelSim simulation at test time.

    No Bazel-time invocation of `vlib` / `vlog` / `vcom` happens — the
    simulator binaries are commercial and not generally available in CI.
    The cocotb runner does the actual build at test time via
    `Runner.build(sources=...)` (see `build_sources` on the returned
    `CocotbSimOutputInfo`).

    Args:
        ctx (ctx): The rule's context object.
        simulator (Target): The `cocotb_questa_sim` target.
        module (Target): The HDL module to compile (`VerilogInfo` or `VhdlInfo`).
        sim_opts (list): Additional flags forwarded to cocotb's runner.

    Returns:
        CocotbSimOutputInfo: Provider with a stamp file and the sources
        cocotb's runner will (re)compile at test time.
    """
    sim_info = simulator[CocotbSimQuestaInfo]
    if not sim_info.vsim:
        fail("cocotb_questa_sim requires a vsim binary")

    # Walk transitive same-language + cross-language deps. Questa/ModelSim
    # is a mixed-language simulator, so `vhdl_deps` on Verilog libraries
    # (and `verilog_deps` on VHDL libraries) contribute sources — cocotb's
    # runner will `vlog`/`vcom` each into the appropriate work library.
    sources = collect_hdl_sources(
        module,
        sim = "questa",
        allowed_languages = ["vhdl", "verilog"],
    )

    return CocotbSimOutputInfo(
        runfiles = ctx.runfiles(transitive_files = sources.runfiles),
        build_args = list(sim_opts),
        build_sources = sources.build_sources,
    )

def _cocotb_questa_sim_impl(ctx):
    all_files = depset(transitive = [
        ctx.attr.vlib[DefaultInfo].default_runfiles.files,
        ctx.attr.vlog[DefaultInfo].default_runfiles.files,
        ctx.attr.vcom[DefaultInfo].default_runfiles.files,
        ctx.attr.vsim[DefaultInfo].default_runfiles.files,
    ])

    return [
        CocotbSimInfo(
            all_files = all_files,
            bins = {
                "vcom": ctx.executable.vcom,
                "vlib": ctx.executable.vlib,
                "vlog": ctx.executable.vlog,
                "vsim": ctx.executable.vsim,
            },
            compile = questa_compile,
            env = ctx.attr.env,
        ),
        CocotbSimQuestaInfo(
            all_files = all_files,
            vcom = ctx.executable.vcom,
            vlib = ctx.executable.vlib,
            vlog = ctx.executable.vlog,
            vsim = ctx.executable.vsim,
        ),
    ]

cocotb_questa_sim = rule(
    doc = """\
A simulator configuration for running [Mentor/Siemens
EDA Questa](https://eda.sw.siemens.com/en-US/ic/questa/) (and the older
ModelSim — cocotb uses the same `questa` runner for both) simulations
in cocotb tests.

### Status

Infrastructure only. Questa/ModelSim is commercial, with no BCR
module and no redistributable binary; `rules_cocotb` cannot validate
this rule in CI. Wire it up downstream by pointing the binary attrs at
your own install (e.g. via `new_local_repository` over `$MODEL_TECH` or
the equivalent Questa install directory) and registering a
`cocotb_toolchain` that routes `sim = "questa"` through this rule.
Cocotb's runner handles the actual build/sim via `Runner.build` /
`Runner.test`.

### Notes

Questa accepts both Verilog/SystemVerilog (`VerilogInfo`) and VHDL
(`VhdlInfo`) modules. The rule defers the `vlib` / `vlog` / `vcom`
invocations to cocotb's runner at test time rather than running them
during the Bazel build, so the simulator only needs to be present on
the test execution environment.
""",
    implementation = _cocotb_questa_sim_impl,
    attrs = {
        "env": SIM_ENV_ATTR,
        "vcom": attr.label(
            doc = "The `vcom` VHDL compiler binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "vlib": attr.label(
            doc = "The `vlib` library manager binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "vlog": attr.label(
            doc = "The `vlog` Verilog/SystemVerilog compiler binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "vsim": attr.label(
            doc = "The `vsim` simulator binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
    },
)
