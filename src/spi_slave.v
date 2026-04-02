/*
 * Copyright (c) 2026 Ved Dwivedi
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_slave (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        spi_clk,
    input  wire        spi_mosi,
    input  wire        spi_cs_n,
    input  wire [15:0] tx_data,
    output reg         spi_miso,
    output reg  [15:0] rx_data,
    output reg         rx_valid
);

    reg spi_clk_meta;
    reg spi_clk_sync;
    reg spi_clk_prev;

    reg spi_mosi_meta;
    reg spi_mosi_sync;

    reg spi_cs_n_meta;
    reg spi_cs_n_sync;
    reg spi_cs_n_prev;

    reg [15:0] rx_shift;
    reg [15:0] tx_shift;
    reg [3:0]  bit_count;

    wire cs_active;
    wire cs_assert;
    wire cs_deassert;
    wire sclk_rise;
    wire sclk_fall;

    assign cs_active   = ~spi_cs_n_sync;
    assign cs_assert   = spi_cs_n_prev & ~spi_cs_n_sync;
    assign cs_deassert = ~spi_cs_n_prev & spi_cs_n_sync;
    assign sclk_rise   = cs_active & ~spi_clk_prev & spi_clk_sync;
    assign sclk_fall   = cs_active & spi_clk_prev & ~spi_clk_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk_meta <= 1'b0;
            spi_clk_sync <= 1'b0;
            spi_clk_prev <= 1'b0;

            spi_mosi_meta <= 1'b0;
            spi_mosi_sync <= 1'b0;

            spi_cs_n_meta <= 1'b1;
            spi_cs_n_sync <= 1'b1;
            spi_cs_n_prev <= 1'b1;

            rx_shift  <= 16'd0;
            tx_shift  <= 16'd0;
            bit_count <= 4'd0;

            spi_miso <= 1'b0;
            rx_data  <= 16'd0;
            rx_valid <= 1'b0;
        end else begin
            spi_clk_prev <= spi_clk_sync;
            spi_clk_sync <= spi_clk_meta;
            spi_clk_meta <= spi_clk;

            spi_mosi_sync <= spi_mosi_meta;
            spi_mosi_meta <= spi_mosi;

            spi_cs_n_prev <= spi_cs_n_sync;
            spi_cs_n_sync <= spi_cs_n_meta;
            spi_cs_n_meta <= spi_cs_n;

            rx_valid <= 1'b0;

            if (cs_assert) begin
                rx_shift  <= 16'd0;
                tx_shift  <= tx_data;
                bit_count <= 4'd0;
                spi_miso  <= tx_data[15];
            end else if (cs_deassert) begin
                bit_count <= 4'd0;
                spi_miso  <= 1'b0;
            end else begin
                if (sclk_rise) begin
                    rx_shift <= {rx_shift[14:0], spi_mosi_sync};

                    if (bit_count == 4'd15) begin
                        rx_data  <= {rx_shift[14:0], spi_mosi_sync};
                        rx_valid <= 1'b1;
                        bit_count <= 4'd0;
                    end else begin
                        bit_count <= bit_count + 4'd1;
                    end
                end

                if (sclk_fall) begin
                    tx_shift <= {tx_shift[14:0], 1'b0};
                    spi_miso <= tx_shift[14];
                end
            end
        end
    end

endmodule

`default_nettype wire
