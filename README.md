![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# ISAAC

ISAAC is an INT8 neural-network inference accelerator for Tiny Tapeout. The current implementation targets a 2x2 systolic matrix-vector multiply core with SPI-based loading and 16-bit result readback.

The current submission branch is configured for a `1x2` Tiny Tapeout footprint so the full 2x2 INT8 compute path can harden successfully.

## Status

- `mac_unit`, `systolic_array_2x2`, `spi_slave`, `control_fsm`, and `tt_um_isaac` are implemented.
- Cocotb regressions exist at both module level and top level.
- The default `make -B` flow runs the end-to-end top-level SPI regression.

## Top Module

`tt_um_isaac`

## Quick Test

```sh
cd test
make -B
```

## Design Summary

- `ui_in[0]`: `spi_clk`
- `ui_in[1]`: `spi_mosi`
- `ui_in[2]`: `spi_cs_n`
- `ui_in[4:3]`: mode select
- `uo_out[0]`: `spi_miso`
- `uo_out[1]`: `busy`
- `uo_out[2]`: `done`
- `uio[7:0]`: parallel data bus / result output bus

Mode values:

- `00`: idle
- `01`: load weights
- `10`: load input vector
- `11`: compute and output

See `docs/info.md` for the project datasheet content.

## GitHub Actions

- `test`: runs cocotb RTL verification
- `docs`: builds the Tiny Tapeout docs page from `info.yaml` and `docs/info.md`
- `gds`: runs hardening, precheck, gate-level test, and viewer generation

For local hardening guidance, see https://www.tinytapeout.com/guides/local-hardening/.
