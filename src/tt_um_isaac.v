/*
 * Copyright (c) 2026 Ved Dwivedi
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_isaac (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    localparam [2:0] STATE_LOAD_WEIGHTS = 3'd1;
    localparam [2:0] STATE_LOAD_INPUT   = 3'd2;
    localparam [2:0] STATE_OUTPUT       = 3'd4;

    wire       spi_clk = ui_in[0];
    wire       spi_mosi = ui_in[1];
    wire       spi_cs_n = ui_in[2];
    wire [1:0] mode = ui_in[4:3];

    wire        spi_miso;
    wire [15:0] spi_rx_data;
    wire        spi_rx_valid;
    wire [15:0] spi_tx_data;

    wire [31:0] weights;
    wire [15:0] input_vec;
    wire [63:0] compute_result;
    wire        compute_valid;

    wire [31:0] result_data;
    wire [7:0]  parallel_out;
    wire        start;
    wire        clr;
    wire        done;
    wire        busy;
    wire [2:0]  state_dbg;
    wire [2:0]  byte_count_dbg;

    reg  [7:0]  uio_in_prev;
    reg         parallel_valid;

    wire load_bus_active = (state_dbg == STATE_LOAD_WEIGHTS) || (state_dbg == STATE_LOAD_INPUT);
    wire output_bus_active = (state_dbg == STATE_OUTPUT);

    // Keep these as separate nets so LVS preserves the intended one-bit-to-one-pin mapping
    // even though all OE bits share the same logical value.
    (* keep *) wire uio_oe_0 = output_bus_active;
    (* keep *) wire uio_oe_1 = output_bus_active;
    (* keep *) wire uio_oe_2 = output_bus_active;
    (* keep *) wire uio_oe_3 = output_bus_active;
    (* keep *) wire uio_oe_4 = output_bus_active;
    (* keep *) wire uio_oe_5 = output_bus_active;
    (* keep *) wire uio_oe_6 = output_bus_active;
    (* keep *) wire uio_oe_7 = output_bus_active;

    spi_slave spi_if (
        .clk(clk),
        .rst_n(rst_n),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .tx_data(spi_tx_data),
        .spi_miso(spi_miso),
        .rx_data(spi_rx_data),
        .rx_valid(spi_rx_valid)
    );

    control_fsm ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .spi_rx_data(spi_rx_data),
        .spi_rx_valid(spi_rx_valid),
        .parallel_data(uio_in),
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

    systolic_array_2x2 core (
        .clk(clk),
        .rst_n(rst_n),
        .weights(weights),
        .input_vec(input_vec),
        .start(start),
        .clr(clr),
        .result(compute_result),
        .valid(compute_valid)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uio_in_prev   <= 8'd0;
            parallel_valid <= 1'b0;
        end else begin
            parallel_valid <= 1'b0;

            if (load_bus_active && (uio_in != uio_in_prev)) begin
                parallel_valid <= 1'b1;
            end

            uio_in_prev <= uio_in;
        end
    end

    assign uo_out = {
        byte_count_dbg[1:0],
        state_dbg,
        done,
        busy,
        spi_miso
    };

    assign uio_out = output_bus_active ? parallel_out : 8'd0;
    assign uio_oe  = {
        uio_oe_7,
        uio_oe_6,
        uio_oe_5,
        uio_oe_4,
        uio_oe_3,
        uio_oe_2,
        uio_oe_1,
        uio_oe_0
    };

    wire _unused = &{ena, ui_in[7:5], result_data[31:0], byte_count_dbg[2], 1'b0};

endmodule

`default_nettype wire
