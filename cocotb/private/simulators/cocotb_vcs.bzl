"""Cocotb Synopsys VCS simulator integration"""

load(
    ":cocotb_sim_utils.bzl",
    "CocotbSimInfo",
    "CocotbSimOutputInfo",
    "SIM_ENV_ATTR",
    "collect_hdl_sources",
)

CocotbSimVcsInfo = provider(
    doc = "VCS-specific extension of `CocotbSimInfo`.",
    fields = {
        "all_files": "depset[File]: All transitive runfiles required by the VCS tools.",
        "vcs": "File: The `vcs` compiler executable.",
    },
)

def vcs_compile(ctx, simulator, module, sim_opts):
    """Stage HDL sources for a VCS simulation at test time.

    No Bazel-time invocation of `vcs` happens — the simulator is
    commercial and not generally available in CI. The cocotb runner
    does the actual build at test time via `Runner.build(sources=...)`,
    producing a `simv` binary that it then invokes for the run.

    Args:
        ctx (ctx): The rule's context object.
        simulator (Target): The `cocotb_vcs_sim` target.
        module (Target): The Verilog/SystemVerilog module to compile.
        sim_opts (list): Additional flags forwarded to cocotb's runner.

    Returns:
        CocotbSimOutputInfo: Provider with a stamp file and the sources
        cocotb's runner will (re)compile at test time.
    """
    sim_info = simulator[CocotbSimVcsInfo]
    if not sim_info.vcs:
        fail("cocotb_vcs_sim requires a vcs binary")

    # Walk transitive Verilog deps. VCS is Verilog-only; a `verilog_library`
    # with cross-language `vhdl_deps` (or a `vhdl_library` handed in as the
    # top-level module) is rejected at analysis time — vcs cannot compile
    # VHDL sources and would fail deep in cocotb's runner otherwise.
    sources = collect_hdl_sources(
        module,
        sim = "vcs",
        allowed_languages = ["verilog"],
    )

    return CocotbSimOutputInfo(
        runfiles = ctx.runfiles(transitive_files = sources.runfiles),
        build_args = list(sim_opts),
        build_sources = sources.build_sources,
    )

def _cocotb_vcs_sim_impl(ctx):
    all_files = ctx.attr.vcs[DefaultInfo].default_runfiles.files

    return [
        CocotbSimInfo(
            all_files = all_files,
            bins = {"vcs": ctx.executable.vcs},
            compile = vcs_compile,
            env = ctx.attr.env,
        ),
        CocotbSimVcsInfo(
            all_files = all_files,
            vcs = ctx.executable.vcs,
        ),
    ]

cocotb_vcs_sim = rule(
    doc = """\
A simulator configuration for running [Synopsys
VCS](https://www.synopsys.com/verification/simulation/vcs.html)
simulations in cocotb tests.

### Status

Infrastructure only. VCS is commercial, with no BCR module and no
redistributable binary; `rules_cocotb` cannot validate this rule in
CI. Wire it up downstream by pointing `vcs` at your own install and
registering a `cocotb_toolchain` that routes `sim = "vcs"` through
this rule. Cocotb's runner handles the actual build/sim (cocotb's VCS
runner produces a `simv` binary and executes it for the run).

### Notes

VCS accepts Verilog/SystemVerilog (`VerilogInfo`) modules. The cocotb
runner internally manages `vcs`'s build flow and the `simv` output
binary, so only the `vcs` compiler binary is needed as a rule
attribute.
""",
    implementation = _cocotb_vcs_sim_impl,
    attrs = {
        "env": SIM_ENV_ATTR,
        "vcs": attr.label(
            doc = "The `vcs` compiler binary.",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
    },
)
