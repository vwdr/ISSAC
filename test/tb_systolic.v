`default_nettype none
`timescale 1ns / 1ps

module tb_systolic;

  initial begin
    $dumpfile("tb_systolic.vcd");
    $dumpvars(0, tb_systolic);
    #1;
  end

  reg        clk;
  reg        rst_n;
  reg [31:0] weights;
  reg [15:0] input_vec;
  reg        start;
  reg        clr;
  wire [63:0] result;
  wire        valid;

  systolic_array_2x2 dut (
      .clk(clk),
      .rst_n(rst_n),
      .weights(weights),
      .input_vec(input_vec),
      .start(start),
      .clr(clr),
      .result(result),
      .valid(valid)
  );

endmodule

`default_nettype wire
