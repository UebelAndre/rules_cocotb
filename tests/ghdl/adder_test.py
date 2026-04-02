"""Cocotb tests for the VHDL `adder` module."""

from cocotb.handle import HierarchyObject
from cocotb.triggers import Timer

import cocotb


@cocotb.test()
async def test_adder(dut: HierarchyObject) -> None:
    """Drive a handful of vectors through the 8-bit VHDL adder."""
    vectors = [
        # (x, y, carry_in, expected_sum, expected_carry_out)
        (0x00, 0x00, 0, 0x00, 0),
        (0x01, 0x01, 0, 0x02, 0),
        (0xFF, 0x01, 0, 0x00, 1),
        (0x7F, 0x01, 0, 0x80, 0),
        (0x80, 0x80, 0, 0x00, 1),
        (0x55, 0xAA, 1, 0x00, 1),
        (0x55, 0xAA, 0, 0xFF, 0),
        (0xFF, 0xFF, 1, 0xFF, 1),
    ]

    for x, y, cin, exp_sum, exp_cout in vectors:
        dut.x.value = x
        dut.y.value = y
        dut.carry_in.value = cin

        await Timer(1, units="ns")

        sum_val = int(dut.sum.value)
        cout_val = int(dut.carry_output_bit.value)
        assert sum_val == exp_sum and cout_val == exp_cout, (
            f"Adder mismatch for x={x:#04x} y={y:#04x} cin={cin}: "
            f"expected sum={exp_sum:#04x} cout={exp_cout}, "
            f"got sum={sum_val:#04x} cout={cout_val}"
        )
