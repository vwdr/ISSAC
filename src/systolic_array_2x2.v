/*
 * Copyright (c) 2026 Ved Dwivedi
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns / 1ps

module systolic_array_2x2 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] weights,
    input  wire [15:0] input_vec,
    input  wire        start,
    input  wire        clr,
    output reg  [63:0] result,
    output reg         valid
);

    // weights[7:0]=w00, weights[15:8]=w01, weights[23:16]=w10, weights[31:24]=w11
    // input_vec[7:0]=in0, input_vec[15:8]=in1
    // result[15:0]=row0_sum, result[31:16]=row1_sum,
    // result[47:32]=row0_partial, result[63:48]=row1_partial

    wire [7:0] w00 = weights[7:0];
    wire [7:0] w01 = weights[15:8];
    wire [7:0] w10 = weights[23:16];
    wire [7:0] w11 = weights[31:24];

    wire [7:0] in0 = input_vec[7:0];
    wire [7:0] in1 = input_vec[15:8];

    reg  [15:0] row0_partial_reg;
    reg  [15:0] row1_partial_reg;
    reg  [7:0]  w01_reg;
    reg  [7:0]  w11_reg;
    reg  [7:0]  in1_reg;
    reg         stage0_valid;
    reg         stage1_valid;

    wire [15:0] row0_partial_wire;
    wire [15:0] row1_partial_wire;
    wire [15:0] row0_sum_wire;
    wire [15:0] row1_sum_wire;

    mac_unit mac_row0_col0 (
        .a(w00),
        .b(in0),
        .acc_in(16'd0),
        .clr(1'b1),
        .acc_out(row0_partial_wire)
    );

    mac_unit mac_row0_col1 (
        .a(w01_reg),
        .b(in1_reg),
        .acc_in(row0_partial_reg),
        .clr(1'b0),
        .acc_out(row0_sum_wire)
    );

    mac_unit mac_row1_col0 (
        .a(w10),
        .b(in0),
        .acc_in(16'd0),
        .clr(1'b1),
        .acc_out(row1_partial_wire)
    );

    mac_unit mac_row1_col1 (
        .a(w11_reg),
        .b(in1_reg),
        .acc_in(row1_partial_reg),
        .clr(1'b0),
        .acc_out(row1_sum_wire)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row0_partial_reg <= 16'd0;
            row1_partial_reg <= 16'd0;
            w01_reg          <= 8'd0;
            w11_reg          <= 8'd0;
            in1_reg          <= 8'd0;
            stage0_valid     <= 1'b0;
            stage1_valid     <= 1'b0;
            result           <= 64'd0;
            valid            <= 1'b0;
        end else if (clr) begin
            row0_partial_reg <= 16'd0;
            row1_partial_reg <= 16'd0;
            w01_reg          <= 8'd0;
            w11_reg          <= 8'd0;
            in1_reg          <= 8'd0;
            stage0_valid     <= 1'b0;
            stage1_valid     <= 1'b0;
            result           <= 64'd0;
            valid            <= 1'b0;
        end else begin
            valid        <= stage1_valid;
            stage1_valid <= stage0_valid;
            stage0_valid <= start;

            if (start) begin
                row0_partial_reg <= row0_partial_wire;
                row1_partial_reg <= row1_partial_wire;
                w01_reg          <= w01;
                w11_reg          <= w11;
                in1_reg          <= in1;
            end

            if (stage0_valid) begin
                result <= {
                    row1_partial_reg,
                    row0_partial_reg,
                    row1_sum_wire,
                    row0_sum_wire
                };
            end
        end
    end

endmodule

`default_nettype wire
