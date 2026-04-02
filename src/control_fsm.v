/*
 * Copyright (c) 2026 Ved Dwivedi
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns / 1ps

module control_fsm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  mode,
    input  wire [15:0] spi_rx_data,
    input  wire        spi_rx_valid,
    input  wire [7:0]  parallel_data,
    input  wire        parallel_valid,
    input  wire [63:0] compute_result,
    input  wire        compute_valid,
    output reg  [31:0] weights,
    output reg  [15:0] input_vec,
    output reg  [31:0] result_data,
    output reg  [15:0] spi_tx_data,
    output reg  [7:0]  parallel_out,
    output reg         start,
    output reg         clr,
    output reg         done,
    output wire        busy,
    output wire [2:0]  state_dbg,
    output wire [2:0]  byte_count_dbg
);

    localparam [1:0] MODE_IDLE         = 2'b00;
    localparam [1:0] MODE_LOAD_WEIGHTS = 2'b01;
    localparam [1:0] MODE_LOAD_INPUT   = 2'b10;
    localparam [1:0] MODE_COMPUTE      = 2'b11;

    localparam [2:0] STATE_IDLE         = 3'd0;
    localparam [2:0] STATE_LOAD_WEIGHTS = 3'd1;
    localparam [2:0] STATE_LOAD_INPUT   = 3'd2;
    localparam [2:0] STATE_COMPUTE      = 3'd3;
    localparam [2:0] STATE_OUTPUT       = 3'd4;

    reg [2:0] state;
    reg [2:0] byte_count;
    reg [1:0] consumed_mode;
    reg       weights_loaded;
    reg       input_loaded;
    reg       output_word_sel;

    assign busy           = (state != STATE_IDLE);
    assign state_dbg      = state;
    assign byte_count_dbg = byte_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            byte_count     <= 3'd0;
            consumed_mode  <= MODE_IDLE;
            weights_loaded <= 1'b0;
            input_loaded   <= 1'b0;
            output_word_sel <= 1'b0;

            weights     <= 32'd0;
            input_vec   <= 16'd0;
            result_data <= 32'd0;
            spi_tx_data <= 16'd0;
            parallel_out <= 8'd0;

            start <= 1'b0;
            clr   <= 1'b0;
            done  <= 1'b0;
        end else begin
            start <= 1'b0;
            clr   <= 1'b0;
            done  <= 1'b0;

            if (mode == MODE_IDLE) begin
                consumed_mode <= MODE_IDLE;
            end

            case (state)
                STATE_IDLE: begin
                    byte_count <= 3'd0;

                    if ((mode != MODE_IDLE) && (mode != consumed_mode)) begin
                        case (mode)
                            MODE_LOAD_WEIGHTS: begin
                                state          <= STATE_LOAD_WEIGHTS;
                                consumed_mode  <= MODE_LOAD_WEIGHTS;
                                weights_loaded <= 1'b0;
                                weights        <= 32'd0;
                                clr            <= 1'b1;
                            end

                            MODE_LOAD_INPUT: begin
                                state        <= STATE_LOAD_INPUT;
                                consumed_mode <= MODE_LOAD_INPUT;
                                input_loaded <= 1'b0;
                                input_vec    <= 16'd0;
                                clr          <= 1'b1;
                            end

                            MODE_COMPUTE: begin
                                if (weights_loaded && input_loaded) begin
                                    state         <= STATE_COMPUTE;
                                    consumed_mode <= MODE_COMPUTE;
                                    start         <= 1'b1;
                                    output_word_sel <= 1'b0;
                                end
                            end

                            default: begin
                                state <= STATE_IDLE;
                            end
                        endcase
                    end
                end

                STATE_LOAD_WEIGHTS: begin
                    if (mode != MODE_LOAD_WEIGHTS) begin
                        state          <= STATE_IDLE;
                        byte_count     <= 3'd0;
                        weights_loaded <= 1'b0;
                    end else if (parallel_valid) begin
                        case (byte_count)
                            3'd0: weights[7:0]   <= parallel_data;
                            3'd1: weights[15:8]  <= parallel_data;
                            3'd2: weights[23:16] <= parallel_data;
                            3'd3: weights[31:24] <= parallel_data;
                            default: weights     <= weights;
                        endcase

                        if (byte_count == 3'd3) begin
                            state          <= STATE_IDLE;
                            byte_count     <= 3'd0;
                            weights_loaded <= 1'b1;
                        end else begin
                            byte_count <= byte_count + 3'd1;
                        end
                    end else if (spi_rx_valid) begin
                        case (byte_count)
                            3'd0: begin
                                weights[7:0]   <= spi_rx_data[15:8];
                                weights[15:8]  <= spi_rx_data[7:0];
                                byte_count     <= 3'd2;
                            end

                            3'd1: begin
                                weights[15:8]  <= spi_rx_data[15:8];
                                weights[23:16] <= spi_rx_data[7:0];
                                byte_count     <= 3'd3;
                            end

                            3'd2: begin
                                weights[23:16] <= spi_rx_data[15:8];
                                weights[31:24] <= spi_rx_data[7:0];
                                state          <= STATE_IDLE;
                                byte_count     <= 3'd0;
                                weights_loaded <= 1'b1;
                            end

                            3'd3: begin
                                weights[31:24] <= spi_rx_data[15:8];
                                state          <= STATE_IDLE;
                                byte_count     <= 3'd0;
                                weights_loaded <= 1'b1;
                            end

                            default: begin
                                state      <= STATE_IDLE;
                                byte_count <= 3'd0;
                            end
                        endcase
                    end
                end

                STATE_LOAD_INPUT: begin
                    if (mode != MODE_LOAD_INPUT) begin
                        state        <= STATE_IDLE;
                        byte_count   <= 3'd0;
                        input_loaded <= 1'b0;
                    end else if (parallel_valid) begin
                        case (byte_count)
                            3'd0: input_vec[7:0]  <= parallel_data;
                            3'd1: input_vec[15:8] <= parallel_data;
                            default: input_vec    <= input_vec;
                        endcase

                        if (byte_count == 3'd1) begin
                            state        <= STATE_IDLE;
                            byte_count   <= 3'd0;
                            input_loaded <= 1'b1;
                        end else begin
                            byte_count <= byte_count + 3'd1;
                        end
                    end else if (spi_rx_valid) begin
                        case (byte_count)
                            3'd0: begin
                                input_vec[7:0]  <= spi_rx_data[15:8];
                                input_vec[15:8] <= spi_rx_data[7:0];
                                state           <= STATE_IDLE;
                                byte_count      <= 3'd0;
                                input_loaded    <= 1'b1;
                            end

                            3'd1: begin
                                input_vec[15:8] <= spi_rx_data[15:8];
                                state           <= STATE_IDLE;
                                byte_count      <= 3'd0;
                                input_loaded    <= 1'b1;
                            end

                            default: begin
                                state      <= STATE_IDLE;
                                byte_count <= 3'd0;
                            end
                        endcase
                    end
                end

                STATE_COMPUTE: begin
                    if (compute_valid) begin
                        result_data  <= compute_result[31:0];
                        spi_tx_data  <= compute_result[15:0];
                        parallel_out <= compute_result[7:0];
                        output_word_sel <= 1'b0;
                        state        <= STATE_OUTPUT;
                        done         <= 1'b1;
                    end
                end

                STATE_OUTPUT: begin
                    if (mode != MODE_COMPUTE) begin
                        state <= STATE_IDLE;
                    end else if (spi_rx_valid) begin
                        if (!output_word_sel) begin
                            spi_tx_data     <= result_data[31:16];
                            parallel_out    <= result_data[23:16];
                            output_word_sel <= 1'b1;
                        end else begin
                            spi_tx_data     <= result_data[15:0];
                            parallel_out    <= result_data[7:0];
                            output_word_sel <= 1'b0;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
