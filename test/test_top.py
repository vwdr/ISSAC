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

SPI_HALF_PERIOD_NS = Decimal(100)
CS_SETUP_NS = Decimal(100)


def set_ui_fields(dut, host, *, mode=None, spi_clk=None, mosi=None, cs_n=None) -> None:
    if mode is not None:
        host["mode"] = mode & 0x3
    if spi_clk is not None:
        host["spi_clk"] = spi_clk & 0x1
    if mosi is not None:
        host["mosi"] = mosi & 0x1
    if cs_n is not None:
        host["cs_n"] = cs_n & 0x1

    dut.ui_in.value = (
        (host["mode"] << 3)
        | (host["cs_n"] << 2)
        | (host["mosi"] << 1)
        | host["spi_clk"]
    )


async def reset_dut(dut, host) -> None:
    dut.ena.value = 1
    dut.uio_in.value = 0
    set_ui_fields(dut, host, mode=MODE_IDLE, spi_clk=0, mosi=0, cs_n=1)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


async def spi_transfer_word(dut, host, word: int, expected_latched_tx: int | None = None) -> int:
    miso_word = 0

    set_ui_fields(dut, host, spi_clk=0, cs_n=0)
    await Timer(CS_SETUP_NS, units="ns")

    if expected_latched_tx is not None:
        observed_tx = int(dut.dut.spi_if.tx_shift.value)
        assert observed_tx == expected_latched_tx, (
            f"expected latched tx_shift 0x{expected_latched_tx:04X}, got 0x{observed_tx:04X}"
        )

    for bit_idx in range(15, -1, -1):
        set_ui_fields(dut, host, mosi=(word >> bit_idx) & 1)
        await Timer(SPI_HALF_PERIOD_NS, units="ns")

        set_ui_fields(dut, host, spi_clk=1)
        await Timer(SPI_HALF_PERIOD_NS / 2, units="ns")
        miso_word = (miso_word << 1) | (int(dut.uo_out.value) & 0x1)
        await Timer(SPI_HALF_PERIOD_NS / 2, units="ns")

        set_ui_fields(dut, host, spi_clk=0)
        await Timer(SPI_HALF_PERIOD_NS, units="ns")

    set_ui_fields(dut, host, cs_n=1, mosi=0)
    await ClockCycles(dut.clk, 8)

    return miso_word


async def wait_for_done(dut) -> None:
    for _ in range(40):
        await RisingEdge(dut.clk)
        if ((int(dut.uo_out.value) >> 2) & 0x1) == 1:
            return

    raise AssertionError("done did not assert")


@cocotb.test
async def test_top_end_to_end_spi_flow(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    host = {"mode": MODE_IDLE, "spi_clk": 0, "mosi": 0, "cs_n": 1}
    await reset_dut(dut, host)

    set_ui_fields(dut, host, mode=MODE_LOAD_WEIGHTS)
    await ClockCycles(dut.clk, 2)
    assert int(dut.uio_oe.value) == 0x00
    await spi_transfer_word(dut, host, 0x0203)
    await spi_transfer_word(dut, host, 0x0405)

    set_ui_fields(dut, host, mode=MODE_LOAD_INPUT)
    await ClockCycles(dut.clk, 2)
    await spi_transfer_word(dut, host, 0x0607)

    set_ui_fields(dut, host, mode=MODE_COMPUTE)
    await wait_for_done(dut)

    assert int(dut.uio_oe.value) == 0xFF
    assert int(dut.uio_out.value) == 0x21
    assert int(dut.dut.ctrl.spi_tx_data.value) == 0x0021

    row0_word = await spi_transfer_word(dut, host, 0x0000, expected_latched_tx=0x0021)
    assert row0_word == 0x0021, f"expected first result word 0x0021, got 0x{row0_word:04X}"
    assert int(dut.uio_out.value) == 0x3B

    row1_word = await spi_transfer_word(dut, host, 0x0000, expected_latched_tx=0x003B)
    assert row1_word == 0x003B, f"expected second result word 0x003B, got 0x{row1_word:04X}"

    set_ui_fields(dut, host, mode=MODE_IDLE)
    await ClockCycles(dut.clk, 2)
    assert int(dut.uio_oe.value) == 0x00
