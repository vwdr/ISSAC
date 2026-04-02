/*
 * Copyright (c) 2026 Ved Dwivedi
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns / 1ps

module mac_unit (
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    input  wire [15:0] acc_in,
    input  wire        clr,
    output wire [15:0] acc_out
);

    localparam signed [16:0] ACC_MAX = 17'sh07fff;
    localparam signed [16:0] ACC_MIN = 17'sh18000;

    wire signed [15:0] product;
    wire signed [16:0] sum_ext;
    wire signed [15:0] acc_sat;

    assign product = $signed(a) * $signed(b);
    assign sum_ext = $signed(acc_in) + $signed(product);

    // Clamp overflow so downstream logic always sees a valid INT16 result.
    assign acc_sat = (sum_ext > ACC_MAX) ? 16'sh7fff :
                     (sum_ext < ACC_MIN) ? 16'sh8000 :
                     sum_ext[15:0];

    assign acc_out = clr ? product : acc_sat;

endmodule

`default_nettype wire
