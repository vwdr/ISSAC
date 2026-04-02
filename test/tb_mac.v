`default_nettype none
`timescale 1ns / 1ps

module tb_mac;

  initial begin
    $dumpfile("tb_mac.vcd");
    $dumpvars(0, tb_mac);
    #1;
  end

  reg [7:0] a;
  reg [7:0] b;
  reg [15:0] acc_in;
  reg clr;
  wire [15:0] acc_out;

  mac_unit dut (
      .a(a),
      .b(b),
      .acc_in(acc_in),
      .clr(clr),
      .acc_out(acc_out)
  );

endmodule

`default_nettype wire
