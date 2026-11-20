/*
 * COMPENG 3DQ5 - Milestone 2 architecture TEMPLATE
 * Two shared multipliers, four 256x16 true dual-port BRAMs.
 * NOT a finished/verified RTL implementation.
 */
`timescale 1ns/100ps
`default_nettype none
module m2_write_s (
    input logic Clock, Resetn, start,
    input logic [1:0] plane,
    input logic [8:0] block_index,
    output logic busy, done,
    // BRAM3 S is UNPACKED: one sample per 16-bit location at 128..255.
    output logic [7:0] s_bram_address,
    input logic [15:0] s_bram_read_data,
    input logic s_bram_read_valid,
    output logic [17:0] sram_address,
    output logic [15:0] sram_write_data,
    output logic sram_we_n
);
    typedef enum logic [2:0] {W_IDLE,W_READ_EVEN,W_READ_ODD,W_WRITE,W_DONE} state_t;
    state_t state;
    logic [7:0] even_sample, odd_sample;
    logic [6:0] pair_index;
    logic [7:0] width;
    logic [7:0] out_stride;
    logic [17:0] out_base;
    logic [8:0] block_row, block_col;
    logic [7:0] row_in_block, pair_in_row;
    logic [6:0] total_pairs;
    always_comb begin
        width = plane == 2'd0 ? 8'd16 : 8'd8;
        out_stride = plane == 2'd0 ? 8'd112 : 8'd56;
        out_base = plane == 2'd0 ? 18'd0 :
                   plane == 2'd1 ? 18'd18816 : 18'd28224;
        block_row = block_index / 9'd21;
        block_col = block_index % 9'd21;
        row_in_block = pair_index / (width / 2);
        pair_in_row = pair_index % (width / 2);
        sram_address = out_base + (block_row * 9'd8 + row_in_block)
                       * out_stride + block_col * (width / 2) + pair_in_row;
        s_bram_address = 8'd128 + row_in_block * width + pair_in_row * 2
                         + (state == W_READ_ODD ? 8'd1 : 8'd0);
        sram_write_data = {even_sample,odd_sample};
        sram_we_n = (state == W_WRITE) ? 1'b0 : 1'b1;
        total_pairs = plane == 2'd0 ? 7'd64 : 7'd32;
        busy = state != W_IDLE && state != W_DONE;
        done = state == W_DONE;
    end
    always_ff @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            state <= W_IDLE;
            pair_index <= 0;
            even_sample <= 0; odd_sample <= 0;
        end else begin
            case (state)
                W_IDLE: if (start) begin
                    pair_index <= 0;
                    state <= W_READ_EVEN;
                end
                W_READ_EVEN: if (s_bram_read_valid) begin
                    even_sample <= s_bram_read_data[7:0];
                    state <= W_READ_ODD;
                end
                W_READ_ODD: if (s_bram_read_valid) begin
                    odd_sample <= s_bram_read_data[7:0];
                    state <= W_WRITE;
                end
                W_WRITE: begin
                    // TODO: honor SRAM write acceptance and timing.
                    if (pair_index == total_pairs - 7'd1) state <= W_DONE;
                    else begin
                        pair_index <= pair_index + 7'd1;
                        state <= W_READ_EVEN;
                    end
                end
                W_DONE: state <= W_IDLE;
                default: state <= W_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
