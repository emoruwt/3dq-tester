/*
 * COMPENG 3DQ5 - Milestone 2 architecture TEMPLATE
 * Two shared multipliers, four 256x16 true dual-port BRAMs.
 * NOT a finished/verified RTL implementation.
 */
`timescale 1ns/100ps
`default_nettype none
module milestone2 (
    input logic Clock, Resetn, M2_start,
    output logic M2_finish,
    // External SRAM interface; connect through project.sv arbitration
    output logic [17:0] SRAM_address,
    output logic [15:0] SRAM_write_data,
    output logic SRAM_we_n,
    input logic [15:0] SRAM_read_data
);
    typedef enum logic [2:0] {
        S_IDLE, S_FETCH_INITIAL, S_CT_INITIAL,
        S_MEGA_A, S_MEGA_B, S_CS_FINAL, S_WS_FINAL, S_FINISH
    } top_state_t;
    top_state_t state;

    logic fetch_start, ct_start, cs_start, ws_start;
    logic fetch_done, ct_done, cs_done, ws_done;
    logic fetch_busy, ct_busy, cs_busy, ws_busy;
    logic [1:0] plane; // 0=Y, 1=U, 2=V
    logic [8:0] block_index; // 0..293 per plane
    localparam logic [8:0] LAST_BLOCK = 9'd293;

    // Per-engine request interfaces: ONE top-level owner/mux drives each RAM port.
    // TODO: instantiate all four engines and route SRAM, BRAM0..3 and multiplier
    // requests through shared-resource arbitration. Do not let engines drive RAM
    // signals directly from multiple always_comb blocks.
    // TODO: implement C8 constants as two combinational lookup muxes.
    // TODO: instantiate exactly TWO shared multipliers and select CT/CS operands.
    // TODO: handle SRAM read latency and BRAM registered outputs explicitly.
    // TODO: check BRAM3 concurrent writes (S results + next S' fetch).

    logic fetch_started, ct_started, cs_started, ws_started;
    // Start flags ensure one-cycle pulses even if a child finishes early.
    always_ff @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            state <= S_IDLE;
            plane <= 2'd0;
            block_index <= 9'd0;
            fetch_started <= 1'b0;
            ct_started <= 1'b0;
            cs_started <= 1'b0;
            ws_started <= 1'b0;
        end else begin
            case (state)
                S_IDLE: if (M2_start) begin
                    plane <= 2'd0;
                    block_index <= 9'd0;
                    state <= S_FETCH_INITIAL;
                end
                S_FETCH_INITIAL: if (fetch_done) state <= S_CT_INITIAL;
                S_CT_INITIAL: if (ct_done) begin
                    if (plane == 2'd2 && block_index == LAST_BLOCK)
                        state <= S_CS_FINAL;
                    else state <= S_MEGA_A;
                end
                S_MEGA_A: if (cs_done && fetch_done) begin
                    // The fetched block becomes the next compute block.
                    if (block_index == LAST_BLOCK) begin
                        block_index <= 9'd0;
                        plane <= plane + 2'd1;
                    end else block_index <= block_index + 9'd1;
                    state <= S_MEGA_B;
                end
                S_MEGA_B: if (ct_done && ws_done) begin
                    if (plane == 2'd2 && block_index == LAST_BLOCK)
                        state <= S_CS_FINAL;
                    else state <= S_MEGA_A;
                end
                S_CS_FINAL: if (cs_done) state <= S_WS_FINAL;
                S_WS_FINAL: if (ws_done) state <= S_FINISH;
                S_FINISH: state <= S_IDLE;
                default: state <= S_IDLE;
            endcase
            // TODO: replace the simplified transition logic above with explicit
            // current-block / next-block descriptors and a complete per-plane
            // boundary sequence. As written, this FSM is a structural sketch.
            if (state != S_FETCH_INITIAL && state != S_MEGA_A) fetch_started <= 1'b0;
            else if (!fetch_started) fetch_started <= 1'b1;
            if (state != S_CT_INITIAL && state != S_MEGA_B) ct_started <= 1'b0;
            else if (!ct_started) ct_started <= 1'b1;
            if (state != S_MEGA_A && state != S_CS_FINAL) cs_started <= 1'b0;
            else if (!cs_started) cs_started <= 1'b1;
            if (state != S_MEGA_B && state != S_WS_FINAL) ws_started <= 1'b0;
            else if (!ws_started) ws_started <= 1'b1;
        end
    end
    always_comb begin
        fetch_start = (state == S_FETCH_INITIAL || state == S_MEGA_A) && !fetch_started;
        ct_start    = (state == S_CT_INITIAL || state == S_MEGA_B) && !ct_started;
        cs_start    = (state == S_MEGA_A || state == S_CS_FINAL) && !cs_started;
        ws_start    = (state == S_MEGA_B || state == S_WS_FINAL) && !ws_started;
        M2_finish = (state == S_FINISH);
        // Safe idle defaults until SRAM arbitration is implemented.
        SRAM_address = 18'd0;
        SRAM_write_data = 16'd0;
        SRAM_we_n = 1'b1;
    end
endmodule

`default_nettype wire
