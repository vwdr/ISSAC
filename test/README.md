# Sample testbench for a Tiny Tapeout project

This is a sample testbench for a Tiny Tapeout project. It uses [cocotb](https://docs.cocotb.org/en/stable/) to drive the DUT and check the outputs.
See below to get started or for more information, check the [website](https://tinytapeout.com/hdl/testing/).

## Setting up

1. Edit [Makefile](Makefile) and modify `PROJECT_SOURCES` to point to your Verilog files.
2. Edit the selected testbench wrapper such as [tb_top.v](tb_top.v) and point it at your top module.

## How to run

To run the RTL simulation:

```sh
make -B
```

This repository defaults to the full top-level ISAAC regression using:

- `tb_top.v`
- `test_top.py`
- `tt_um_isaac.v control_fsm.v spi_slave.v systolic_array_2x2.v mac_unit.v`

To run a module-specific test, override the Makefile variables. For example:

```sh
make -B PROJECT_SOURCES=spi_slave.v TB_FILE=tb_spi.v TOPLEVEL=tb_spi MODULE=test_spi
```

To run gatelevel simulation, first harden your project and copy `../runs/wokwi/results/final/verilog/gl/{your_module_name}.v` to `gate_level_netlist.v`.

Then run:

```sh
make -B GATES=yes
```

## How to view the VCD file

Using GTKWave
```sh
gtkwave tb.vcd tb.gtkw
```

Using Surfer
```sh
surfer tb.vcd
```
