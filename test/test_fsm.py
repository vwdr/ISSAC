# SPDX-FileCopyrightText: 2026 Ved Dwivedi
# SPDX-License-Identifier: Apache-2.0

import cocotb
from decimal import Decimal
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer


MODE_IDLE = 0b00
MODE_LOAD_WEIGHTS = 0b01
MODE_LOAD_INPUT = 0b10
MODE_COMPUTE = 0b11

STATE_IDLE = 0
STATE_LOAD_WEIGHTS = 1
STATE_LOAD_INPUT = 2
STATE_COMPUTE = 3
STATE_OUTPUT = 4


async def sample_after_edge(dut) -> None:
    await RisingEdge(dut.clk)
    await Timer(Decimal("1"), units="ps")


async def reset_dut(dut) -> None:
    dut.mode.value = MODE_IDLE
    dut.spi_rx_data.value = 0
    dut.spi_rx_valid.value = 0
    dut.parallel_data.value = 0
    dut.parallel_valid.value = 0
    dut.compute_result.value = 0
    dut.compute_valid.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await sample_after_edge(dut)


async def pulse_spi_word(dut, word: int) -> None:
    dut.spi_rx_data.value = word & 0xFFFF
    dut.spi_rx_valid.value = 1
    await sample_after_edge(dut)
    dut.spi_rx_valid.value = 0


async def pulse_parallel_byte(dut, value: int) -> None:
    dut.parallel_data.value = value & 0xFF
    dut.parallel_valid.value = 1
    await sample_after_edge(dut)
    dut.parallel_valid.value = 0


@cocotb.test
async def test_fsm_full_spi_sequence(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.mode.value = MODE_LOAD_WEIGHTS
    await sample_after_edge(dut)
    assert int(dut.state_dbg.value) == STATE_LOAD_WEIGHTS
    assert int(dut.clr.value) == 1
    assert int(dut.busy.value) == 1

    await pulse_spi_word(dut, 0x0102)
    assert int(dut.byte_count_dbg.value) == 2
    assert int(dut.weights.value) == 0x00000201

    await pulse_spi_word(dut, 0x0304)
    assert int(dut.weights.value) == 0x04030201
    assert int(dut.state_dbg.value) == STATE_IDLE
    assert int(dut.busy.value) == 0

    dut.mode.value = MODE_LOAD_INPUT
    await sample_after_edge(dut)
    assert int(dut.state_dbg.value) == STATE_LOAD_INPUT
    assert int(dut.clr.value) == 1

    await pulse_spi_word(dut, 0x0506)
    assert int(dut.input_vec.value) == 0x0605
    assert int(dut.state_dbg.value) == STATE_IDLE

    dut.mode.value = MODE_COMPUTE
    await sample_after_edge(dut)
    assert int(dut.state_dbg.value) == STATE_COMPUTE
    assert int(dut.start.value) == 1
    assert int(dut.busy.value) == 1

    dut.compute_result.value = 0x0010000F00080007
    dut.compute_valid.value = 1
    await sample_after_edge(dut)
    dut.compute_valid.value = 0

    assert int(dut.state_dbg.value) == STATE_OUTPUT
    assert int(dut.done.value) == 1
    assert int(dut.result_data.value) == 0x00080007
    assert int(dut.spi_tx_data.value) == 0x0007
    assert int(dut.parallel_out.value) == 0x07

    dut.mode.value = MODE_IDLE
    await sample_after_edge(dut)
    assert int(dut.state_dbg.value) == STATE_IDLE
    assert int(dut.busy.value) == 0


@cocotb.test
async def test_fsm_parallel_load_path(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.mode.value = MODE_LOAD_WEIGHTS
    await sample_after_edge(dut)

    await pulse_parallel_byte(dut, 0x11)
    assert int(dut.byte_count_dbg.value) == 1
    await pulse_parallel_byte(dut, 0x22)
    assert int(dut.byte_count_dbg.value) == 2
    await pulse_parallel_byte(dut, 0x33)
    assert int(dut.byte_count_dbg.value) == 3
    await pulse_parallel_byte(dut, 0x44)

    assert int(dut.weights.value) == 0x44332211
    assert int(dut.state_dbg.value) == STATE_IDLE

    dut.mode.value = MODE_LOAD_INPUT
    await sample_after_edge(dut)
    await pulse_parallel_byte(dut, 0x55)
    await pulse_parallel_byte(dut, 0x66)

    assert int(dut.input_vec.value) == 0x6655
    assert int(dut.state_dbg.value) == STATE_IDLE


@cocotb.test
async def test_fsm_compute_requires_loaded_operands(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.mode.value = MODE_COMPUTE
    await sample_after_edge(dut)

    assert int(dut.state_dbg.value) == STATE_IDLE
    assert int(dut.start.value) == 0
    assert int(dut.busy.value) == 0
