"""Cocotb simulator dispatch"""

load(
    "//cocotb/private/simulators:cocotb_activehdl.bzl",
    _CocotbSimActiveHdlInfo = "CocotbSimActiveHdlInfo",
    _cocotb_activehdl_sim = "cocotb_activehdl_sim",
)
load(
    "//cocotb/private/simulators:cocotb_dsim.bzl",
    _CocotbSimDsimInfo = "CocotbSimDsimInfo",
    _cocotb_dsim_sim = "cocotb_dsim_sim",
)
load(
    "//cocotb/private/simulators:cocotb_ghdl.bzl",
    _CocotbSimGhdlInfo = "CocotbSimGhdlInfo",
    _cocotb_ghdl_sim = "cocotb_ghdl_sim",
)
load(
    "//cocotb/private/simulators:cocotb_icarus.bzl",
    _CocotbSimIcarusInfo = "CocotbSimIcarusInfo",
    _cocotb_icarus_sim = "cocotb_icarus_sim",
)
load(
    "//cocotb/private/simulators:cocotb_nvc.bzl",
    _CocotbSimNvcInfo = "CocotbSimNvcInfo",
    _cocotb_nvc_sim = "cocotb_nvc_sim",
)
load(
    "//cocotb/private/simulators:cocotb_questa.bzl",
    _CocotbSimQuestaInfo = "CocotbSimQuestaInfo",
    _cocotb_questa_sim = "cocotb_questa_sim",
)
load(
    "//cocotb/private/simulators:cocotb_riviera.bzl",
    _CocotbSimRivieraInfo = "CocotbSimRivieraInfo",
    _cocotb_riviera_sim = "cocotb_riviera_sim",
)
load(
    "//cocotb/private/simulators:cocotb_sim_utils.bzl",
    _CocotbSimInfo = "CocotbSimInfo",
    _CocotbSimOutputInfo = "CocotbSimOutputInfo",
)
load(
    "//cocotb/private/simulators:cocotb_vcs.bzl",
    _CocotbSimVcsInfo = "CocotbSimVcsInfo",
    _cocotb_vcs_sim = "cocotb_vcs_sim",
)
load(
    "//cocotb/private/simulators:cocotb_verilator.bzl",
    _CocotbSimVerilatorInfo = "CocotbSimVerilatorInfo",
    _cocotb_verilator_sim = "cocotb_verilator_sim",
)
load(
    "//cocotb/private/simulators:cocotb_xcelium.bzl",
    _CocotbSimXceliumInfo = "CocotbSimXceliumInfo",
    _cocotb_xcelium_sim = "cocotb_xcelium_sim",
)

CocotbSimActiveHdlInfo = _CocotbSimActiveHdlInfo
CocotbSimDsimInfo = _CocotbSimDsimInfo
CocotbSimGhdlInfo = _CocotbSimGhdlInfo
CocotbSimIcarusInfo = _CocotbSimIcarusInfo
CocotbSimInfo = _CocotbSimInfo
CocotbSimNvcInfo = _CocotbSimNvcInfo
CocotbSimOutputInfo = _CocotbSimOutputInfo
CocotbSimQuestaInfo = _CocotbSimQuestaInfo
CocotbSimRivieraInfo = _CocotbSimRivieraInfo
CocotbSimVcsInfo = _CocotbSimVcsInfo
CocotbSimVerilatorInfo = _CocotbSimVerilatorInfo
CocotbSimXceliumInfo = _CocotbSimXceliumInfo
cocotb_activehdl_sim = _cocotb_activehdl_sim
cocotb_dsim_sim = _cocotb_dsim_sim
cocotb_ghdl_sim = _cocotb_ghdl_sim
cocotb_icarus_sim = _cocotb_icarus_sim
cocotb_nvc_sim = _cocotb_nvc_sim
cocotb_questa_sim = _cocotb_questa_sim
cocotb_riviera_sim = _cocotb_riviera_sim
cocotb_vcs_sim = _cocotb_vcs_sim
cocotb_verilator_sim = _cocotb_verilator_sim
cocotb_xcelium_sim = _cocotb_xcelium_sim

def cocotb_sim_compile(ctx, simulator, **kwargs):
    """Dispatch compilation to the simulator's compile function via its provider.

    Each `cocotb_*_sim` target carries a `CocotbSimInfo` provider whose `compile`
    field references the simulator-specific compile function. This dispatcher
    simply calls it, removing the need for a static mapping of simulator names
    to functions.

    Args:
        ctx (ctx): The rule's context object.
        simulator (Target): The `cocotb_*_sim` target that provides `CocotbSimInfo`.
        **kwargs: Arguments forwarded to the compile function (typically
            `module` and `sim_opts`).

    Returns:
        CocotbSimOutputInfo: The compiled simulator binary and its runfiles.
    """
    return simulator[CocotbSimInfo].compile(ctx = ctx, simulator = simulator, **kwargs)
