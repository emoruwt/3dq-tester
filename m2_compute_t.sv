/*
 * COMPENG 3DQ5 - Milestone 2 architecture TEMPLATE
 * Two shared multipliers, four 256x16 true dual-port BRAMs.
 * NOT a finished/verified RTL implementation.
 */
`timescale 1ns/100ps
`default_nettype none
module m2_compute_t (
    input logic Clock, Resetn, start,
    input logic [1:0] plane,
    output logic busy, done,
    // BRAM3: shared S' value; BRAM2: C16 (Y only); C8 via constant MUX (U/V).
    output logic [7:0] sprime_address,
    input logic signed [15:0] sprime_data,
    output logic [7:0] c16_address_a, c16_address_b,
    input logic signed [15:0] c16_data_a, c16_data_b,
    output logic [5:0] c8_index_a, c8_index_b,
    input logic signed [15:0] c8_data_a, c8_data_b,
    // Two SHARED multipliers: parent routes operands/results to this engine.
    output logic signed [31:0] mul1_a, mul1_b, mul2_a, mul2_b,
    input logic signed [63:0] product1, product2,
    // T split across BRAM0 upper and BRAM1 lower, 1 index per T element.
    output logic [7:0] t_address_a, t_address_b,
    output logic [15:0] t_upper_a, t_upper_b, t_lower_a, t_lower_b,
    output logic t_write_a, t_write_b
);
    typedef enum logic [2:0] {CT_IDLE,CT_PRIME,CT_MAC,CT_DRAIN,CT_STORE,CT_DONE} state_t;
    state_t state;
    logic [2:0] i; // 8 rows
    logic [3:0] j; // even output column 0..14
    logic [3:0] k; // Y needs 0..15; U/V 0..7
    logic [3:0] width;
    logic signed [63:0] acc1, acc2;
    logic signed [31:0] t0, t1;
    logic mac_valid;
    always_comb begin
        width = plane == 2'd0 ? 4'd16 : 4'd8;
        sprime_address = i * width + k;
        c16_address_a = k * 8'd16 + j;
        c16_address_b = k * 8'd16 + j + 8'd1;
        c8_index_a = {k[2:0],j[2:0]};
        c8_index_b = {k[2:0],j[2:0]} + 6'd1;
        mul1_a = {{16{sprime_data[15]}},sprime_data};
        mul2_a = mul1_a;
        mul1_b = plane == 2'd0 ? {{16{c16_data_a[15]}},c16_data_a} :
                                    {{16{c8_data_a[15]}},c8_data_a};
        mul2_b = plane == 2'd0 ? {{16{c16_data_b[15]}},c16_data_b} :
                                    {{16{c8_data_b[15]}},c8_data_b};
        t_address_a = i * width + j;
        t_address_b = t_address_a + 8'd1;
        t_upper_a = t0[31:16]; t_lower_a = t0[15:0];
        t_upper_b = t1[31:16]; t_lower_b = t1[15:0];
        t_write_a = (state == CT_STORE);
        t_write_b = (state == CT_STORE);
        busy = state != CT_IDLE && state != CT_DONE;
        done = state == CT_DONE;
    end
    always_ff @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            state <= CT_IDLE;
            i <= '0; j <= '0; k <= '0;
            acc1 <= '0; acc2 <= '0;
            t0 <= '0; t1 <= '0;
        end else begin
            case (state)
                CT_IDLE: if (start) begin
                    i <= 0; j <= 0; k <= 0;
                    acc1 <= 0; acc2 <= 0;
                    state <= CT_PRIME;
                end
                CT_PRIME: begin
                    // TODO: wait actual BRAM read latency; align k, coefficients,
                    // S' and multiplier pipeline valid signals.
                    state <= CT_MAC;
                end
                CT_MAC: begin
                    // PLACEHOLDER only: assumes product1/2 correspond to current k.
                    // Replace with a pipelined valid/data schedule.
                    acc1 <= acc1 + product1;
                    acc2 <= acc2 + product2;
                    if (k == width - 4'd1) state <= CT_DRAIN;
                    else k <= k + 4'd1;
                end
                CT_DRAIN: begin
                    // TODO: account for accumulator NBA and exact fixed-point
                    // rounding/scaling from the project before truncating to 32 bits.
                    t0 <= acc1[31:0]; t1 <= acc2[31:0];
                    state <= CT_STORE;
                end
                CT_STORE: begin
                    if (j + 4'd2 < width) begin
                        j <= j + 4'd2;
                        k <= 0; acc1 <= 0; acc2 <= 0;
                        state <= CT_PRIME;
                    end else if (i < 3'd7) begin
                        i <= i + 3'd1; j <= 0; k <= 0;
                        acc1 <= 0; acc2 <= 0;
                        state <= CT_PRIME;
                    end else state <= CT_DONE;
                end
                CT_DONE: state <= CT_IDLE;
                default: state <= CT_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
