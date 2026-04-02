# Simulators

A simulator integration is a Bazel rule that wires a specific HDL
simulator into the cocotb test harness. `cocotb_test` doesn't talk to
simulators directly — it picks one of the simulators registered in the
active `cocotb_toolchain` by name (via its `sim` attribute), and the
toolchain dispatches compile + run through the matching `cocotb_*_sim`
target.

Each `cocotb_*_sim` rule produces a `CocotbSimInfo` provider that the
shared `cocotb_test` rule consumes. New simulator integrations can be
added by writing a rule that returns the same provider and registering
it in a `cocotb_toolchain.simulators` dict.

## Built-in integrations

| Rule | HDL languages | Source | CI-verified |
|------|---------------|--------|-------------|
| [`cocotb_verilator_sim`](./cocotb_verilator_sim.md) | Verilog / SystemVerilog | BCR `verilator` + `rules_verilator` | ✅ |
| [`cocotb_icarus_sim`](./cocotb_icarus_sim.md) | Verilog / SystemVerilog | BCR `iverilog` | ✅ |
| [`cocotb_ghdl_sim`](./cocotb_ghdl_sim.md) | VHDL | BCR `ghdl` | ✅ |
| [`cocotb_nvc_sim`](./cocotb_nvc_sim.md) | VHDL | bring-your-own (no BCR module yet) | — |
| [`cocotb_questa_sim`](./cocotb_questa_sim.md) | Verilog / SystemVerilog / VHDL | bring-your-own (commercial; also covers ModelSim) | — |
| [`cocotb_xcelium_sim`](./cocotb_xcelium_sim.md) | Verilog / SystemVerilog / VHDL | bring-your-own (commercial; also covers Incisive) | — |
| [`cocotb_vcs_sim`](./cocotb_vcs_sim.md) | Verilog / SystemVerilog | bring-your-own (commercial) | — |
| [`cocotb_dsim_sim`](./cocotb_dsim_sim.md) | Verilog / SystemVerilog / VHDL | bring-your-own (commercial) | — |
| [`cocotb_riviera_sim`](./cocotb_riviera_sim.md) | Verilog / SystemVerilog / VHDL | bring-your-own (commercial) | — |
| [`cocotb_activehdl_sim`](./cocotb_activehdl_sim.md) | Verilog / SystemVerilog / VHDL | bring-your-own (commercial; cocotb runner support pending) | — |

The default toolchain (`//cocotb/toolchain:toolchain`) registers only
the CI-verified row — Verilator (default), Icarus Verilog, and GHDL.
For any other simulator, define your own
[`cocotb_toolchain`](./cocotb_toolchain.md) that wires the relevant
`cocotb_*_sim` to your install and register it ahead of the default.

The "CI-verified" column is what `rules_cocotb`'s own
`//tests/...` exercises. The other rules are wired
correctly against [cocotb's runner
classes](https://docs.cocotb.org/en/stable/library_reference.html#cocotb_tools.runner),
but `rules_cocotb` can't ship the binaries (commercial license or no
BCR module yet), so we can't validate them ourselves — please file
issues if you hit problems wiring one up.

### Other simulators

[Tachyon DA CVC](http://www.tachyon-da.com/index.php/products/cvc-rtl-simulator/)
has no `cocotb_tools.runner` class as of the cocotb version pinned by
this module, so there's no `cocotb_cvc_sim` rule. If/when cocotb adds
runner support upstream we can add the wiring.

Per-simulator status, known limitations, and any downstream-wiring
patterns are inline on each simulator's reference page.
