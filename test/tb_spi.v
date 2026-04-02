`default_nettype none
`timescale 1ns / 1ps

module tb_spi;

  initial begin
    $dumpfile("tb_spi.vcd");
    $dumpvars(0, tb_spi);
    #1;
  end

  reg        clk;
  reg        rst_n;
  reg        spi_clk;
  reg        spi_mosi;
  reg        spi_cs_n;
  reg [15:0] tx_data;
  wire       spi_miso;
  wire [15:0] rx_data;
  wire        rx_valid;

  spi_slave dut (
      .clk(clk),
      .rst_n(rst_n),
      .spi_clk(spi_clk),
      .spi_mosi(spi_mosi),
      .spi_cs_n(spi_cs_n),
      .tx_data(tx_data),
      .spi_miso(spi_miso),
      .rx_data(rx_data),
      .rx_valid(rx_valid)
  );

endmodule

`default_nettype wire
