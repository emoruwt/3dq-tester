/*
 * COMPENG 3DQ5 - Milestone 2 architecture TEMPLATE
 * Two shared multipliers, four 256x16 true dual-port BRAMs.
 * NOT a finished/verified RTL implementation.
 */
`timescale 1ns/100ps
`default_nettype none
module m2_compute_s (
    input logic Clock, Resetn, start,
    input logic [1:0] plane,
    output logic busy, done,
    // BRAM0/1 hold upper/lower halves of same 32-bit T element.
    output logic [7:0] t_address,
    input logic [15:0] t_upper, t_lower,
    output logic [5:0] c8_index_a, c8_index_b,
    input logic signed [15:0] c8_data_a, c8_data_b,
    output logic signed [31:0] mul1_a, mul1_b, mul2_a, mul2_b,
    input logic signed [63:0] product1, product2,
    // BRAM3 S region (unpacked, one 8-bit result per 16-bit location)
    output logic [7:0] s_address_a, s_address_b,
    output logic [15:0] s_write_data_a, s_write_data_b,
    output logic s_write_a, s_write_b
);
    typedef enum logic [2:0] {CS_IDLE,CS_PRIME,CS_MAC,CS_DRAIN,CS_STORE,CS_DONE} state_t;
    state_t state;
    logic [2:0] row_pair; // 0,2,4,6
    logic [3:0] col;      // 0..15 for Y, 0..7 for U/V
    logic [2:0] k;        // 0..7
    logic [3:0] width;
    logic signed [63:0] acc1, acc2;
    logic [7:0] s0, s1;
    logic signed [31:0] t_value;
    always_comb begin
        width = plane == 2'd0 ? 4'd16 : 4'd8;
        t_address = k * width + col;
        t_value = $signed({t_upper,t_lower});
        c8_index_a = {k,row_pair};
        c8_index_b = {k,row_pair} + 6'd1;
        mul1_a = t_value;
        mul2_a = t_value;
        mul1_b = {{16{c8_data_a[15]}},c8_data_a};
        mul2_b = {{16{c8_data_b[15]}},c8_data_b};
        s_address_a = 8'd128 + row_pair * width + col;
        s_address_b = s_address_a + 2 * width;
        s_write_data_a = {8'd0,s0};
        s_write_data_b = {8'd0,s1};
        s_write_a = (state == CS_STORE);
        s_write_b = (state == CS_STORE);
        busy = state != CS_IDLE && state != CS_DONE;
        done = state == CS_DONE;
    end
    always_ff @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            state <= CS_IDLE;
            row_pair <= 0; col <= 0; k <= 0;
            acc1 <= 0; acc2 <= 0;
            s0 <= 0; s1 <= 0;
        end else begin
            case (state)
                CS_IDLE: if (start) begin
                    row_pair <= 0; col <= 0; k <= 0;
                    acc1 <= 0; acc2 <= 0;
                    state <= CS_PRIME;
                end
                CS_PRIME: begin
                    // TODO: wait BRAM read latency; align T halves and products.
                    state <= CS_MAC;
                end
                CS_MAC: begin
                    acc1 <= acc1 + product1;
                    acc2 <= acc2 + product2;
                    if (k == 3'd7) state <= CS_DRAIN;
                    else k <= k + 3'd1;
                end
                CS_DRAIN: begin
                    // TODO: replace direct slice with specified rounding,
                    // fixed-point shift, saturation/clipping to 0..255.
                    s0 <= acc1[7:0];
                    s1 <= acc2[7:0];
                    state <= CS_STORE;
                end
                CS_STORE: begin
                    if (col + 4'd1 < width) begin
                        col <= col + 4'd1; k <= 0;
                        acc1 <= 0; acc2 <= 0;
                        state <= CS_PRIME;
                    end else if (row_pair < 3'd6) begin
                        row_pair <= row_pair + 3'd2; col <= 0; k <= 0;
                        acc1 <= 0; acc2 <= 0;
                        state <= CS_PRIME;
                    end else state <= CS_DONE;
                end
                CS_DONE: state <= CS_IDLE;
                default: state <= CS_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
