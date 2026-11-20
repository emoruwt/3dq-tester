/*
 * COMPENG 3DQ5 - Milestone 2 architecture TEMPLATE
 * Two shared multipliers, four 256x16 true dual-port BRAMs.
 * NOT a finished/verified RTL implementation.
 */
`timescale 1ns/100ps
`default_nettype none
module m2_fetch_sprime (
    input logic Clock, Resetn, start,
    input logic [1:0] plane, // 0=Y, 1=U, 2=V
    input logic [8:0] block_index, // 0..293, row-major 21 blocks per row
    output logic busy, done,
    output logic [17:0] sram_address,
    input logic [15:0] sram_read_data,
    // Parent asserts this when data for a prior request is actually valid.
    input logic sram_read_valid,
    output logic [7:0] bram3_address,
    output logic [15:0] bram3_write_data,
    output logic bram3_write_enable
);
    typedef enum logic [1:0] {F_IDLE,F_RUN,F_DRAIN,F_DONE} state_t;
    state_t state;
    logic [7:0] request_index, response_index;
    logic [17:0] base_addr;
    logic [7:0] width;
    logic [7:0] row_stride;
    logic [8:0] block_row, block_col;
    logic [7:0] row_in_block, col_in_block;
    logic [7:0] total_samples;
    always_comb begin
        block_row = block_index / 9'd21;
        block_col = block_index % 9'd21;
        base_addr = plane == 2'd0 ? 18'd37632 :
                    plane == 2'd1 ? 18'd75264 : 18'd94080;
        width = plane == 2'd0 ? 8'd16 : 8'd8;
        row_stride = plane == 2'd0 ? 8'd224 : 8'd112;
        total_samples = plane == 2'd0 ? 8'd128 : 8'd64;
        row_in_block = request_index / width;
        col_in_block = request_index % width;
        sram_address = base_addr + ((block_row * 9'd8 + row_in_block)
                         * row_stride) + block_col * width + col_in_block;
        bram3_address = response_index; // S' occupies 0..127
        bram3_write_data = sram_read_data;
        bram3_write_enable = (state == F_RUN || state == F_DRAIN) && sram_read_valid;
        busy = (state == F_RUN || state == F_DRAIN);
        done = (state == F_DONE);
    end
    always_ff @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            state <= F_IDLE;
            request_index <= 8'd0;
            response_index <= 8'd0;
        end else begin
            case (state)
                F_IDLE: if (start) begin
                    request_index <= 8'd0;
                    response_index <= 8'd0;
                    state <= F_RUN;
                end
                F_RUN: begin
                    // TODO: advance request_index ONLY when SRAM request is accepted;
                    // track outstanding reads to avoid overwriting response addresses.
                    // The following simple issue schedule assumes one request/clock.
                    if (request_index == total_samples - 8'd1) state <= F_DRAIN;
                    else request_index <= request_index + 8'd1;
                    if (sram_read_valid) response_index <= response_index + 8'd1;
                end
                F_DRAIN: if (sram_read_valid) begin
                    response_index <= response_index + 8'd1;
                    if (response_index == total_samples - 8'd1) state <= F_DONE;
                end
                F_DONE: state <= F_IDLE;
                default: state <= F_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
