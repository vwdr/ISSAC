## How it works

ISAAC is a Tiny Tapeout INT8 inference building block built around a 2x2 systolic multiply-accumulate core.

The top-level module `tt_um_isaac` exposes a small SPI slave plus an 8-bit bidirectional data bus. The host loads four signed 8-bit weights and two signed 8-bit input values, then requests a compute step. Internally the design contains:

- `spi_slave`: synchronizes `spi_clk`, `spi_mosi`, and `spi_cs_n` into the system clock domain and performs 16-bit SPI transfers in mode 0.
- `control_fsm`: sequences weight loading, input loading, compute launch, and result output.
- `systolic_array_2x2`: computes a 2x2 matrix times 2x1 vector using four `mac_unit` instances.
- `mac_unit`: performs signed INT8 multiply plus saturated INT16 accumulation.

The current core computes:

```text
[w00 w01] x [in0] = [w00*in0 + w01*in1]
[w10 w11]   [in1]   [w10*in0 + w11*in1]
```

Results are exposed as two 16-bit words. The low result word is available first on SPI MISO and on the `uio` bus in output mode, followed by the high result word on the next SPI transaction.

Pin usage:

- `ui_in[0]`: `spi_clk`
- `ui_in[1]`: `spi_mosi`
- `ui_in[2]`: `spi_cs_n`
- `ui_in[4:3]`: mode select
- `uo_out[0]`: `spi_miso`
- `uo_out[1]`: `busy`
- `uo_out[2]`: `done`
- `uo_out[7:3]`: debug/state bits
- `uio[7:0]`: 8-bit parallel load/output bus

Mode encoding:

- `00`: IDLE
- `01`: LOAD_WEIGHTS
- `10`: LOAD_INPUT
- `11`: COMPUTE / OUTPUT

## How to test

For local RTL verification, the default cocotb target runs the full top-level integration test:

```sh
cd test
make -B
```

That test performs the full SPI flow:

1. Reset the design.
2. Set `mode=01` and send two 16-bit SPI words to load four weights.
3. Set `mode=10` and send one 16-bit SPI word to load two inputs.
4. Set `mode=11` to start compute.
5. Wait for `done=1` on `uo_out[2]`.
6. Read back two 16-bit result words over SPI MISO.

Example values used by the regression:

```text
weights = [[2, 3],
           [4, 5]]
input   = [6, 7]

result  = [33, 59]
```

Useful module-level regressions:

```sh
cd test
make -B PROJECT_SOURCES=mac_unit.v TB_FILE=tb_mac.v TOPLEVEL=tb_mac MODULE=test_mac
make -B PROJECT_SOURCES="mac_unit.v systolic_array_2x2.v" TB_FILE=tb_systolic.v TOPLEVEL=tb_systolic MODULE=test_systolic
make -B PROJECT_SOURCES=spi_slave.v TB_FILE=tb_spi.v TOPLEVEL=tb_spi MODULE=test_spi
make -B PROJECT_SOURCES=control_fsm.v TB_FILE=tb_control_fsm.v TOPLEVEL=tb_control_fsm MODULE=test_fsm
```

## External hardware

The design expects a host that can drive the Tiny Tapeout user I/O pins:

- SPI master for `spi_clk`, `spi_mosi`, `spi_cs_n`, and `spi_miso`
- Optional 8-bit parallel load/output path on `uio[7:0]`
- A system clock supplied by the Tiny Tapeout board / RP2040

No additional external analog hardware is required.
