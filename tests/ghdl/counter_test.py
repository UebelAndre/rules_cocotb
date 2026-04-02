"""Cocotb tests for the VHDL `counter` module."""

from cocotb.clock import Clock
from cocotb.handle import HierarchyObject
from cocotb.triggers import ClockCycles, RisingEdge

import cocotb


@cocotb.test()
async def test_counter_reset(dut: HierarchyObject) -> None:
    """Verify the counter resets to zero."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst.value = 1
    dut.enable.value = 0
    await ClockCycles(dut.clk, 3)

    count = int(dut.count.value)
    assert count == 0, f"Counter should be 0 after reset, got {count}"

    cocotb.log.info("Reset test passed")


@cocotb.test()
async def test_counter_counts(dut: HierarchyObject) -> None:
    """Verify the counter increments when enabled."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst.value = 1
    dut.enable.value = 0
    await ClockCycles(dut.clk, 2)

    dut.rst.value = 0
    dut.enable.value = 1
    await RisingEdge(dut.clk)

    for expected in range(1, 6):
        await RisingEdge(dut.clk)
        count = int(dut.count.value)
        assert count == expected, f"Counter expected {expected}, got {count}"

    cocotb.log.info("Count test passed")
