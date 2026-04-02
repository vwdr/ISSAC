# SPDX-FileCopyrightText: 2026 Ved Dwivedi
# SPDX-License-Identifier: Apache-2.0

import cocotb
from decimal import Decimal
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer


SPI_HALF_PERIOD_NS = Decimal(100)
CS_SETUP_NS = Decimal(100)


async def reset_dut(dut) -> None:
    dut.spi_clk.value = 0
    dut.spi_mosi.value = 0
    dut.spi_cs_n.value = 1
    dut.tx_data.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def spi_transfer_word(dut, mosi_word: int) -> int:
    miso_word = 0

    dut.spi_clk.value = 0
    dut.spi_cs_n.value = 0
    await Timer(CS_SETUP_NS, units="ns")

    for bit_idx in range(15, -1, -1):
        dut.spi_mosi.value = (mosi_word >> bit_idx) & 1
        await Timer(SPI_HALF_PERIOD_NS, units="ns")

        dut.spi_clk.value = 1
        await Timer(SPI_HALF_PERIOD_NS / 2, units="ns")
        miso_word = (miso_word << 1) | int(dut.spi_miso.value)
        await Timer(SPI_HALF_PERIOD_NS / 2, units="ns")

        dut.spi_clk.value = 0
        await Timer(SPI_HALF_PERIOD_NS, units="ns")

    dut.spi_cs_n.value = 1
    dut.spi_mosi.value = 0
    await ClockCycles(dut.clk, 4)

    return miso_word


async def monitor_rx_valid(dut, state: dict[str, int]) -> None:
    while True:
        await RisingEdge(dut.clk)
        if int(dut.rx_valid.value) == 1:
            state["count"] = state.get("count", 0) + 1
            state["last_data"] = int(dut.rx_data.value)


@cocotb.test
async def test_spi_receive_16bit_word(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    rx_state = {"count": 0, "last_data": 0}
    rx_monitor = cocotb.start_soon(monitor_rx_valid(dut, rx_state))

    dut.tx_data.value = 0x0000
    observed_miso = await spi_transfer_word(dut, 0xA5C3)
    rx_monitor.kill()

    assert rx_state["count"] == 1, f"expected one rx_valid pulse, saw {rx_state['count']}"
    assert rx_state["last_data"] == 0xA5C3, f"expected rx_data 0xA5C3, got 0x{rx_state['last_data']:04X}"
    assert observed_miso == 0x0000, f"expected idle tx_data on MISO, got 0x{observed_miso:04X}"


@cocotb.test
async def test_spi_transmit_16bit_word(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    rx_state = {"count": 0, "last_data": 0}
    rx_monitor = cocotb.start_soon(monitor_rx_valid(dut, rx_state))

    dut.tx_data.value = 0xB16B
    observed_miso = await spi_transfer_word(dut, 0x1234)
    rx_monitor.kill()

    assert observed_miso == 0xB16B, f"expected MISO 0xB16B, got 0x{observed_miso:04X}"
    assert rx_state["count"] == 1, f"expected one rx_valid pulse, saw {rx_state['count']}"
    assert rx_state["last_data"] == 0x1234, f"expected rx_data 0x1234, got 0x{rx_state['last_data']:04X}"


@cocotb.test
async def test_spi_tx_latches_new_word_per_transaction(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    first_state = {"count": 0, "last_data": 0}
    first_monitor = cocotb.start_soon(monitor_rx_valid(dut, first_state))

    dut.tx_data.value = 0x55AA
    first_miso = await spi_transfer_word(dut, 0x0000)
    first_monitor.kill()

    second_state = {"count": 0, "last_data": 0}
    second_monitor = cocotb.start_soon(monitor_rx_valid(dut, second_state))

    dut.tx_data.value = 0x0F0F
    second_miso = await spi_transfer_word(dut, 0xFFFF)
    second_monitor.kill()

    assert first_miso == 0x55AA, f"expected first MISO word 0x55AA, got 0x{first_miso:04X}"
    assert second_miso == 0x0F0F, f"expected second MISO word 0x0F0F, got 0x{second_miso:04X}"
    assert first_state["count"] == 1, f"expected one rx_valid pulse on first transfer, saw {first_state['count']}"
    assert second_state["count"] == 1, f"expected one rx_valid pulse on second transfer, saw {second_state['count']}"
    assert second_state["last_data"] == 0xFFFF, f"expected rx_data 0xFFFF, got 0x{second_state['last_data']:04X}"
