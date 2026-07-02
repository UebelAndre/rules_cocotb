"""Cocotb Aldec Active-HDL simulator integration"""

load(
    ":cocotb_sim_utils.bzl",
    "CocotbSimInfo",
    "CocotbSimOutputInfo",
    "SIM_ENV_ATTR",
    "collect_hdl_sources",
)

CocotbSimActiveHdlInfo = provider(
    doc = "Active-HDL-specific extension of `CocotbSimInfo`.",
    fields = {
        "all_files": "depset[File]: All transitive runfiles required by the Active-HDL tools.",
        "vcom": "File: The `vcom` VHDL compiler executable.",
        "vlib": "File: The `vlib` library manager executable.",
        "vlog": "File: The `vlog` Verilog compiler executable.",
        "vsimsa": "File: The `vsimsa` batch simulation runner executable.",
    },
)

def activehdl_compile(ctx, simulator, module, sim_opts):
    """Stage HDL sources for an Active-HDL simulation at test time.

    No Bazel-time `vlib` / `vlog` / `vcom` runs — the simulator is
    commercial and not generally available in CI. The cocotb runner
    drives the full build/sim flow at test time via `Runner.build()`.

    Args:
        ctx (ctx): The rule's context object.
        simulator (Target): The `cocotb_activehdl_sim` target.
        module (Target): The HDL module (`VerilogInfo` or `VhdlInfo`).
        sim_opts (list): Additional flags forwarded to cocotb's runner.

    Returns:
        CocotbSimOutputInfo: Provider with a stamp file and the sources
        cocotb's runner will (re)compile at test time.
    """
    sim_info = simulator[CocotbSimActiveHdlInfo]
    if not sim_info.vsimsa:
        fail("cocotb_activehdl_sim requires a vsimsa binary")

    # Walk transitive same-language + cross-language deps. Active-HDL is a
    # mixed-language simulator: cocotb's runner drives `vlog`/`vcom` per
    # source, so every reachable Verilog/VHDL file (including cross-lang
    # `verilog_deps` / `vhdl_deps`) must be in `build_sources`.
    sources = collect_hdl_sources(
        module,
        sim = "activehdl",
        allowed_languages = ["vhdl", "verilog"],
    )

    return CocotbSimOutputInfo(
        runfiles = ctx.runfiles(transitive_files = sources.runfiles),
        build_args = list(sim_opts),
        build_sources = sources.build_sources,
    )

def _cocotb_activehdl_sim_impl(ctx):
    all_files = depset(transitive = [
        ctx.attr.vlib[DefaultInfo].default_runfiles.files,
        ctx.attr.vlog[DefaultInfo].default_runfiles.files,
        ctx.attr.vcom[DefaultInfo].default_runfiles.files,
        ctx.attr.vsimsa[DefaultInfo].default_runfiles.files,
    ])

    vlib_exe = ctx.executable.vlib
    vlog_exe = ctx.executable.vlog
    vcom_exe = ctx.executable.vcom
    vsimsa_exe = ctx.executable.vsimsa

    return [
        CocotbSimInfo(
            all_files = all_files,
            bins = {
                "vcom": vcom_exe,
                "vlib": vlib_exe,
                "vlog": vlog_exe,
                "vsimsa": vsimsa_exe,
            },
            compile = activehdl_compile,
            env = ctx.attr.env,
        ),
        CocotbSimActiveHdlInfo(
            all_files = all_files,
            vcom = vcom_exe,
            vlib = vlib_exe,
            vlog = vlog_exe,
            vsimsa = vsimsa_exe,
        ),
    ]

cocotb_activehdl_sim = rule(
    doc = """\
A simulator configuration for running Aldec Active-HDL simulations in
cocotb tests.

### Status

Infrastructure only. Active-HDL is commercial, with no BCR module and
no redistributable binary; `rules_cocotb` cannot validate this rule in
CI. Wire it up downstream by pointing the binary attrs at your own
install and registering a `cocotb_toolchain` that routes
`sim = "activehdl"` through this rule. Cocotb's runner handles the
actual build/sim via `Runner.build` / `Runner.test`.

### Downstream wiring

The pattern matches `cocotb_riviera_sim` — wrap the installed `vlib`,
`vlog`, `vcom`, and `vsimsa` binaries via a local repository, then:

```python
load("@rules_cocotb//cocotb:cocotb_activehdl_sim.bzl", "cocotb_activehdl_sim")
load("@rules_cocotb//cocotb:cocotb_toolchain.bzl", "cocotb_toolchain")

cocotb_activehdl_sim(
    name = "cocotb_activehdl",
    vlib = "@activehdl//:vlib",
    vlog = "@activehdl//:vlog",
    vcom = "@activehdl//:vcom",
    vsimsa = "@activehdl//:vsimsa",
)

cocotb_toolchain(
    name = "my_cocotb_toolchain",
    cocotb = "//path/to:cocotb_py_library",
    simulators = {":cocotb_activehdl": "activehdl"},
)
```

Register the toolchain in `MODULE.bazel` ahead of `//cocotb/toolchain`
and use `cocotb_test(sim = "activehdl", ...)`.

Active-HDL accepts both Verilog/SystemVerilog (`VerilogInfo`) and VHDL
(`VhdlInfo`) modules.
""",
    implementation = _cocotb_activehdl_sim_impl,
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
            doc = "The `vlog` Verilog compiler binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "vsimsa": attr.label(
            doc = "The `vsimsa` batch simulation runner binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
    },
)
