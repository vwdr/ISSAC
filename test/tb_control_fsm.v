`default_nettype none
`timescale 1ns / 1ps

module tb_control_fsm;

  initial begin
    $dumpfile("tb_control_fsm.vcd");
    $dumpvars(0, tb_control_fsm);
    #1;
  end

  reg        clk;
  reg        rst_n;
  reg [1:0]  mode;
  reg [15:0] spi_rx_data;
  reg        spi_rx_valid;
  reg [7:0]  parallel_data;
  reg        parallel_valid;
  reg [63:0] compute_result;
  reg        compute_valid;
  wire [31:0] weights;
  wire [15:0] input_vec;
  wire [31:0] result_data;
  wire [15:0] spi_tx_data;
  wire [7:0]  parallel_out;
  wire        start;
  wire        clr;
  wire        done;
  wire        busy;
  wire [2:0]  state_dbg;
  wire [2:0]  byte_count_dbg;

  control_fsm dut (
      .clk(clk),
      .rst_n(rst_n),
      .mode(mode),
      .spi_rx_data(spi_rx_data),
      .spi_rx_valid(spi_rx_valid),
      .parallel_data(parallel_data),
      .parallel_valid(parallel_valid),
      .compute_result(compute_result),
      .compute_valid(compute_valid),
      .weights(weights),
      .input_vec(input_vec),
      .result_data(result_data),
      .spi_tx_data(spi_tx_data),
      .parallel_out(parallel_out),
      .start(start),
      .clr(clr),
      .done(done),
      .busy(busy),
      .state_dbg(state_dbg),
      .byte_count_dbg(byte_count_dbg)
  );

endmodule

`default_nettype wire
