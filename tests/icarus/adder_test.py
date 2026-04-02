"""Cocotb tests for the `adder` module."""

import os
import pathlib

from cocotb.handle import HierarchyObject
from cocotb.triggers import Timer
from python.runfiles import Runfiles

import cocotb


@cocotb.test()
async def test_adder(dut: HierarchyObject) -> None:
    """Test the 8-bit adder with carry input"""

    test_vectors = [
        # (x, y, carry_in, expected_sum, expected_carry_output)
        (0x00, 0x00, 0, 0x00, 0),
        (0x01, 0x01, 0, 0x02, 0),
        (0xFF, 0x01, 0, 0x00, 1),
        (0x7F, 0x01, 0, 0x80, 0),
        (0x80, 0x80, 0, 0x00, 1),
        (0x55, 0xAA, 1, 0x00, 1),
        (0x55, 0xAA, 0, 0xFF, 0),
        (0xFF, 0xFF, 1, 0xFF, 1),
    ]

    for x, y, carry_in, expected_sum, expected_carry_output in test_vectors:
        # Apply inputs
        dut.x.value = x
        dut.y.value = y
        dut.carry_in.value = carry_in

        # Wait for a short time to allow the signals to propagate
        await Timer(1, units="ns")

        # Check the outputs
        sum_val = int(dut.sum.value)
        carry_output_val = int(dut.carry_output_bit.value)
        assert sum_val == expected_sum and carry_output_val == expected_carry_output, (
            f"Adder result incorrect for inputs x={x}, y={y}, carry_in={carry_in}: "
            f"expected sum={expected_sum}, carry_output={expected_carry_output} "
            f"but got sum={sum_val}, carry_output={carry_output_val}"
        )

    cocotb.log.info("All test vectors passed!")


@cocotb.test()
async def test_env_attr(dut: HierarchyObject) -> None:
    """Test reading environment variables"""
    del dut

    runfiles = Runfiles.Create()
    assert runfiles, "Failed to initialize runfiles"
    rlocationpath = os.getenv("LOCATION")
    assert rlocationpath, "Failed read in environment variable"
    runfile = runfiles.Rlocation(rlocationpath)
    assert runfile, f"Failed to find runfile: {rlocationpath}"
    assert "THIS IS A TEST FILE" == pathlib.Path(runfile).read_text(encoding="utf-8")
