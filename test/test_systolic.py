# SPDX-FileCopyrightText: 2026 Ved Dwivedi
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge


def to_s8(value: int) -> int:
    value &= 0xFF
    return value - 0x100 if value & 0x80 else value


def to_s16(value: int) -> int:
    value &= 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def pack_weights(w00: int, w01: int, w10: int, w11: int) -> int:
    return (
        ((w11 & 0xFF) << 24)
        | ((w10 & 0xFF) << 16)
        | ((w01 & 0xFF) << 8)
        | (w00 & 0xFF)
    )


def pack_input_vec(in0: int, in1: int) -> int:
    return ((in1 & 0xFF) << 8) | (in0 & 0xFF)


def unpack_results(result_word: int) -> tuple[int, int, int, int]:
    row0_sum = to_s16(result_word)
    row1_sum = to_s16(result_word >> 16)
    row0_partial = to_s16(result_word >> 32)
    row1_partial = to_s16(result_word >> 48)
    return row0_sum, row1_sum, row0_partial, row1_partial


def numpy_expected(weights: tuple[int, int, int, int], input_vec: tuple[int, int]) -> tuple[int, int, int, int]:
    np = __import__("numpy")

    matrix = np.array(
        [
            [to_s8(weights[0]), to_s8(weights[1])],
            [to_s8(weights[2]), to_s8(weights[3])],
        ],
        dtype=np.int16,
    )
    vector = np.array([to_s8(input_vec[0]), to_s8(input_vec[1])], dtype=np.int16)
    result = matrix @ vector
    return (
        int(result[0]),
        int(result[1]),
        int(matrix[0, 0] * vector[0]),
        int(matrix[1, 0] * vector[0]),
    )


async def reset_dut(dut) -> None:
    dut.start.value = 0
    dut.clr.value = 0
    dut.weights.value = 0
    dut.input_vec.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def run_transaction(dut, weights: tuple[int, int, int, int], input_vec: tuple[int, int]):
    dut.weights.value = pack_weights(*weights)
    dut.input_vec.value = pack_input_vec(*input_vec)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await ReadOnly()

    assert int(dut.valid.value) == 0, "valid asserted too early on start cycle"
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(dut.valid.value) == 0, "valid asserted too early after one cycle"
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(dut.valid.value) == 1, "valid did not assert two cycles after start"

    observed = unpack_results(int(dut.result.value))
    expected = numpy_expected(weights, input_vec)
    assert observed == expected, f"expected {expected}, got {observed}"

    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(dut.valid.value) == 0, "valid should pulse for one cycle"
    await ClockCycles(dut.clk, 1)


@cocotb.test
async def test_systolic_known_matrix_vector(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    await run_transaction(dut, weights=(2, 3, 4, 5), input_vec=(6, 7))


@cocotb.test
async def test_systolic_signed_cases(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    cases = [
        ((127, -128, -5, 12), (-1, 2)),
        ((-128, 127, 127, -128), (127, -128)),
        ((0, -3, 9, -11), (-7, 5)),
    ]

    for weights, input_vec in cases:
        await run_transaction(dut, weights=weights, input_vec=input_vec)


@cocotb.test
async def test_systolic_clear_resets_pipeline(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.weights.value = pack_weights(1, 2, 3, 4)
    dut.input_vec.value = pack_input_vec(5, 6)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    dut.clr.value = 1
    await RisingEdge(dut.clk)
    dut.clr.value = 0

    assert int(dut.valid.value) == 0
    assert int(dut.result.value) == 0

    await ClockCycles(dut.clk, 3)
    assert int(dut.valid.value) == 0, "cleared pipeline should not produce a stale valid pulse"
