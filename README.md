# rules_cocotb

Bazel rules that run [cocotb](https://github.com/cocotb/cocotb) Python
testbenches against Verilog/SystemVerilog and VHDL modules.

The two public rules are:

- **[`cocotb_test`](https://hw-bzl.github.io/rules_cocotb/cocotb_test.html)** —
  a Bazel `test` target that pairs a Verilog/VHDL `*_library` with one
  or more cocotb Python sources, runs them under the simulator picked
  by the active toolchain.
- **[`cocotb_toolchain`](https://hw-bzl.github.io/rules_cocotb/cocotb_toolchain.html)** —
  binds cocotb to one or more `cocotb_*_sim` integrations (Verilator,
  Icarus, GHDL, NVC, Questa/ModelSim, Riviera/Active-HDL, VCS, Xcelium,
  DSim, xsim).

Full documentation, end-to-end example, and per-simulator status are
hosted at **<https://hw-bzl.github.io/rules_cocotb/>**.
