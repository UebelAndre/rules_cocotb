# `rules_cocotb` simple example (Verilator)

Self-contained downstream project that builds an 8-bit Verilog adder and
drives it with a cocotb testbench under Verilator. Demonstrates the
minimum wiring needed to assemble a custom `cocotb_toolchain`.

```text
examples/simple/
├── MODULE.bazel              # bazel_deps + cocotb_pip_deps + register custom toolchain
├── BUILD.bazel               # py_library(cocotb) + cocotb_verilator_sim + cocotb_toolchain + cocotb_test
├── adder.sv                  # 8-bit DUT
├── adder_test.py             # cocotb tests
├── requirements_*.txt        # pinned cocotb pip wheels (copied from rules_cocotb)
└── README.md                 # this file
```

## Run it

From this directory:

```text
bazel test //...
```

Expected output:

```text
//:adder_test                                                            PASSED
Executed 1 out of 1 test: 1 test passes.
```

## What a downstream project needs

`rules_cocotb` deliberately does *not* register a default toolchain for
downstream consumers — its in-tree `@rules_cocotb//cocotb/toolchain` is
scoped to the rules_cocotb dev workflow. A downstream project assembles
its own with the simulators it actually wants. This example shows the
minimum:

1. **`MODULE.bazel`** — `bazel_dep` on `rules_cocotb` plus the BCR
   modules for whatever simulators you want (`verilator` +
   `rules_verilator` for Verilator), `rules_req_compile` for cocotb's
   pip wheels, and `rules_venv` for the `py_library` rule. The example
   reuses rules_cocotb's pinned lock files via local copies; a real
   project would maintain its own and could pin a different cocotb
   version.

2. **`BUILD.bazel`** — four pieces in order:
   - A `py_library(name = "cocotb", deps = ["@cocotb_pip_deps//cocotb", ...])`
     wrapping the wheel. The cocotb toolchain and the verilator sim
     both consume this label.
   - `cocotb_verilator_sim(verilator = ..., cocotb = ":cocotb",
     deps = ["@verilator//:verilated"])`. The rule extracts
     `verilator.cpp` and the cocotb VPI `.so` files from the cocotb
     wheel internally — nothing else to wire.
   - `cocotb_toolchain` + `toolchain()` rules to register the sim.
   - `verilog_library` + `cocotb_test` for the actual DUT and test.

3. **`register_toolchains("//:cocotb_toolchain")`** in `MODULE.bazel`
   to make the toolchain discoverable.

## Adding more simulators

The `simulators` dict on `cocotb_toolchain` is a mapping from
`cocotb_*_sim` targets to the names `cocotb_test(sim = "...")` selects
by. To add Icarus or GHDL, instantiate `cocotb_icarus_sim` /
`cocotb_ghdl_sim` alongside `cocotb_verilator` and extend the dict:

```python
simulators = {
    ":cocotb_verilator": "verilator",
    ":cocotb_icarus":    "icarus",
    ":cocotb_ghdl":      "ghdl",
},
```

Each simulator integration has its own reference page in the
[rules_cocotb book](../../docs/src/simulators.md) listing the
attributes it needs.
