/*
 * COMPENG 3DQ5 - Milestone 1 SRAM interface STARTER
 * Adapted to project-group-60-main/rtl/SRAM_controller.sv
 *
 * This is a scaffold, NOT a complete M1 decoder. The SRAM lead-in
 * transactions are implemented conservatively; CC arithmetic, RGB
 * packing, pipelined prefetch and row/lead-out logic are TODOs.
 *
 * SRAM_we_n: 1 = READ, 0 = WRITE (active-low write enable).
 */
`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module Milestone1_SRAM_interface (
    input  logic        Clock,
    input  logic        Resetn,
    input  logic        Enable,
    output logic        Finish,
    output logic [17:0] SRAM_address,
    output logic [15:0] SRAM_write_data,
    output logic        SRAM_we_n,
    input  logic [15:0] SRAM_read_data
);

    localparam logic [17:0] Y_BASE   = 18'd0;
    localparam logic [17:0] U_BASE   = 18'd18816;
    localparam logic [17:0] V_BASE   = 18'd28224;
    localparam logic [17:0] RGB_BASE = 18'd205696;
    localparam int unsigned PIXELS_PER_ROW = 224;
    localparam int unsigned PAIRS_PER_ROW  = 112;
    localparam int unsigned ROWS           = 168;

    typedef enum logic [4:0] {
        S_M1_IDLE,
        S_M1_LI_REQ, S_M1_LI_WAIT_0, S_M1_LI_WAIT_1, S_M1_LI_CAPTURE,
        S_M1_SETUP,
        S_M1_CC0, S_M1_CC1, S_M1_CC2, S_M1_CC3,
        S_M1_CC4, S_M1_CC5, S_M1_CC6,
        S_M1_ROW_END, S_M1_LEAD_OUT, S_M1_DONE
    } m1_state_t;
    m1_state_t state;

    logic [3:0] li_index;      // 0: Y0/Y1; 1..4: U; 5..8: V
    logic [7:0] pair_index;    // 0..111
    logic [7:0] row_index;     // 0..167

    // Storage for the nine initial SRAM words, matching the spreadsheet.
    logic [15:0] Y_word;
    logic [15:0] U_words [0:3];
    logic [15:0] V_words [0:3];

    // Later SRAM reads will be captured here (after verified latency).
    logic [15:0] U_buffer, V_buffer, Y_buffer;
    logic [7:0] U_reg [0:7];
    logic [7:0] V_reg [0:7];

    // RGB results: replace TODOs in CC states with real arithmetic.
    logic [7:0] R_even, G_even, B_even;
    logic [7:0] R_odd,  G_odd,  B_odd;

    // Example signed accumulator declarations for your datapath.
    logic signed [31:0] U_odd_accum, V_odd_accum;
    logic signed [31:0] R_even_accum, G_even_accum, B_even_accum;
    logic signed [31:0] R_odd_accum,  G_odd_accum,  B_odd_accum;

    // Address selection for the lead-in words, as in the user's state table.
    function automatic logic [17:0] lead_in_address(input logic [3:0] index);
        case (index)
            4'd0: lead_in_address = Y_BASE;
            4'd1: lead_in_address = U_BASE;
            4'd2: lead_in_address = U_BASE + 18'd1;
            4'd3: lead_in_address = U_BASE + 18'd2;
            4'd4: lead_in_address = U_BASE + 18'd3;
            4'd5: lead_in_address = V_BASE;
            4'd6: lead_in_address = V_BASE + 18'd1;
            4'd7: lead_in_address = V_BASE + 18'd2;
            4'd8: lead_in_address = V_BASE + 18'd3;
            default: lead_in_address = Y_BASE;
        endcase
    endfunction

    // Three 16-bit SRAM words hold the six RGB bytes for a pixel pair.
    function automatic logic [15:0] rgb_word(
        input logic [1:0] word_select,
        input logic [7:0] re, ge, be, ro, go, bo
    );
        case (word_select)
            2'd0: rgb_word = {re, ge};
            2'd1: rgb_word = {be, ro};
            2'd2: rgb_word = {go, bo};
            default: rgb_word = 16'd0;
        endcase
    endfunction

    // Helper address: first pair (0,1) -> 205696,205697,205698.
    function automatic logic [17:0] rgb_address(
        input logic [7:0] row,
        input logic [7:0] pair,
        input logic [1:0] word_select
    );
        rgb_address = RGB_BASE + 18'(row) * 18'd336
                               + 18'(pair) * 18'd3
                               + 18'(word_select);
    endfunction

    integer i;
    always_ff @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
            state <= S_M1_IDLE;
            SRAM_address <= Y_BASE;
            SRAM_write_data <= 16'd0;
            SRAM_we_n <= 1'b1;
            Finish <= 1'b0;
            li_index <= 4'd0;
            pair_index <= 8'd0;
            row_index <= 8'd0;
            Y_word <= 16'd0;
            U_buffer <= 16'd0;
            V_buffer <= 16'd0;
            Y_buffer <= 16'd0;
            R_even <= 0; G_even <= 0; B_even <= 0;
            R_odd <= 0; G_odd <= 0; B_odd <= 0;
            U_odd_accum <= 0; V_odd_accum <= 0;
            R_even_accum <= 0; G_even_accum <= 0; B_even_accum <= 0;
            R_odd_accum <= 0; G_odd_accum <= 0; B_odd_accum <= 0;
            for (i = 0; i < 4; i = i + 1) begin
                U_words[i] <= 16'd0;
                V_words[i] <= 16'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                U_reg[i] <= 8'd0;
                V_reg[i] <= 8'd0;
            end
        end else begin
            // Default: no write. SRAM_address retains its previous value.
            SRAM_we_n <= 1'b1;
            case (state)
                S_M1_IDLE: begin
                    Finish <= 1'b0;
                    if (Enable) begin
                        li_index <= 4'd0;
                        pair_index <= 8'd0;
                        row_index <= 8'd0;
                        state <= S_M1_LI_REQ;
                    end
                end

                // Conservative, easy-to-debug initial read protocol.
                // IMPORTANT: this is NOT the optimized one-request-per-cycle
                // schedule shown in the spreadsheet. It is deliberately slow
                // until the exact controller/testbench latency is verified.
                S_M1_LI_REQ: begin
                    SRAM_address <= lead_in_address(li_index);
                    state <= S_M1_LI_WAIT_0;
                end
                S_M1_LI_WAIT_0: state <= S_M1_LI_WAIT_1;
                S_M1_LI_WAIT_1: state <= S_M1_LI_CAPTURE;
                S_M1_LI_CAPTURE: begin
                    case (li_index)
                        4'd0: Y_word <= SRAM_read_data;
                        4'd1: U_words[0] <= SRAM_read_data;
                        4'd2: U_words[1] <= SRAM_read_data;
                        4'd3: U_words[2] <= SRAM_read_data;
                        4'd4: U_words[3] <= SRAM_read_data;
                        4'd5: V_words[0] <= SRAM_read_data;
                        4'd6: V_words[1] <= SRAM_read_data;
                        4'd7: V_words[2] <= SRAM_read_data;
                        4'd8: V_words[3] <= SRAM_read_data;
                        default: ;
                    endcase
                    if (li_index == 4'd8)
                        state <= S_M1_SETUP;
                    else begin
                        li_index <= li_index + 4'd1;
                        state <= S_M1_LI_REQ;
                    end
                end

                S_M1_SETUP: begin
                    // TODO: build boundary-extended U_reg/V_reg windows
                    // from U_words/V_words for pixel pair 0,1.
                    // TODO: load Y_even/Y_odd from Y_word.
                    // Do not simply map U0..U7 into the active window:
                    // the first pixel pair needs left-edge handling.
                    state <= S_M1_CC0;
                end

                S_M1_CC0: begin
                    // TODO: MUL1 = -6*(U_reg[0]+U_reg[7]);
                    // TODO: MUL2 = -6*(V_reg[0]+V_reg[7]);
                    // TODO: MUL3 = 12083*(V_even-128);
                    // TODO: first U/V MAC terms, R_even calculation.
                    // TODO: SRAM read/prefetch per finalized table.
                    state <= S_M1_CC1;
                end
                S_M1_CC1: begin
                    // TODO: MUL1/MUL2 = -21 * respective tap pairs;
                    // TODO: MUL3 = -1352*(U_even-128).
                    state <= S_M1_CC2;
                end
                S_M1_CC2: begin
                    // TODO: MUL1/MUL2 = 59 * respective tap pairs;
                    // TODO: MUL3 = -4678*(V_even-128).
                    state <= S_M1_CC3;
                end
                S_M1_CC3: begin
                    // TODO: MUL1/MUL2 = 224 * respective tap pairs;
                    // TODO: MUL3 = 15409*(U_even-128).
                    // TODO: produce packed RGB word 0 when valid.
                    state <= S_M1_CC4;
                end
                S_M1_CC4: begin
                    // TODO: MUL1 = 12083*(V_odd-128);
                    // TODO: MUL3 = -1352*(U_odd-128).
                    state <= S_M1_CC5;
                end
                S_M1_CC5: begin
                    // TODO: MUL1 = 15409*(U_odd-128);
                    // TODO: MUL3 = -4678*(V_odd-128).
                    // TODO: produce packed RGB word 1 when valid.
                    state <= S_M1_CC6;
                end
                S_M1_CC6: begin
                    // TODO: produce packed RGB word 2 when valid.
                    // TODO: shift U/V windows, choose next byte from buffers.
                    // TODO: replace this temporary transition with actual
                    // row/lead-out control AND pipelined SRAM scheduling.
                    state <= S_M1_ROW_END;
                end

                S_M1_ROW_END: begin
                    // TODO: advance pair_index (0..111), prefetch Y,
                    // and handle end-of-row chroma replication.
                    // SAFETY: stop here rather than falsely claim that
                    // 224x168 pixels have been converted.
                    state <= S_M1_LEAD_OUT;
                end
                S_M1_LEAD_OUT: begin
                    // TODO: flush pending RGB writes and row boundary.
                    state <= S_M1_DONE;
                end
                S_M1_DONE: begin
                    Finish <= 1'b1;
                    if (!Enable) state <= S_M1_IDLE;
                end
                default: state <= S_M1_IDLE;
            endcase
        end
    end
endmodule
