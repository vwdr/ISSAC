# SPDX-FileCopyrightText: 2026 Ved Dwivedi
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import Timer


def to_s8(value: int) -> int:
    value &= 0xFF
    return value - 0x100 if value & 0x80 else value


def to_s16(value: int) -> int:
    value &= 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def sat_s16(value: int) -> int:
    return max(-32768, min(32767, value))


async def drive_and_check(dut, a: int, b: int, acc_in: int, clr: int, expected: int):
    dut.a.value = a & 0xFF
    dut.b.value = b & 0xFF
    dut.acc_in.value = acc_in & 0xFFFF
    dut.clr.value = clr
    await Timer(1, units="ns")

    observed = to_s16(int(dut.acc_out.value))
    assert observed == expected, (
        f"a={to_s8(a)} b={to_s8(b)} acc_in={to_s16(acc_in)} clr={clr} "
        f"expected {expected}, got {observed}"
    )


@cocotb.test()
async def test_mac_unit(dut):
    cases = [
        (0, 0, 0, 1, 0),
        (1, 1, 0, 1, 1),
        (127, 127, 0, 1, 16129),
        (-128, 127, 0, 1, -16256),
        (-1, -1, 0, 1, 1),
    ]

    for a, b, acc_in, clr, expected in cases:
        await drive_and_check(dut, a, b, acc_in, clr, expected)


@cocotb.test()
async def test_mac_accumulation_over_multiple_cycles(dut):
    running_sum = 0

    products = [(3, 4), (-2, 5), (7, -8), (127, 127)]
    first_a, first_b = products[0]
    running_sum = to_s8(first_a) * to_s8(first_b)
    await drive_and_check(dut, first_a, first_b, 0, 1, running_sum)

    for a, b in products[1:]:
        acc_before = running_sum
        running_sum = sat_s16(running_sum + to_s8(a) * to_s8(b))
        await drive_and_check(dut, a, b, acc_before, 0, running_sum)


@cocotb.test()
async def test_mac_positive_saturation(dut):
    await drive_and_check(dut, 127, 127, 30000, 0, 32767)


@cocotb.test()
async def test_mac_negative_saturation(dut):
    await drive_and_check(dut, -128, 127, -30000, 0, -32768)
