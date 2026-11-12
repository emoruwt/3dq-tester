
/*
Copyright by Henry Ko and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module milestone1 (
    input logic Clock_50,
    input logic Resetn,
    input logic Start,

    input logic [15:0] SRAM_read_data,
    output logic [17:0] SRAM_address,
    output logic [15:0] SRAM_write_data,
    output logic SRAM_we_n,

    output logic Done
);

// =====================================================
// FSM STATES
// =====================================================

typedef enum logic [4:0] {

    // Lead-in states
    LI_READ_U0,
    LI_READ_U1,
    LI_READ_U2,
    LI_READ_V0,
    LI_READ_V1,
    LI_READ_V2,
    LI_READ_Y,
    LI_LOAD_V1,
    LI_LOAD_V2,
    LI_CALCULATE_V,

    // Common case states
    S_U_CALCULATIONS,
    S_V_CALCULATIONS1,
    S_V_CALCULATIONS2,
    S_UV_EVEN_CALCULATIONS,
    S_UV_ODD_CALCULATIONS,
    S_RGB_CALCULATIONS_EVEN,
    S_RGB_CALCULATIONS_ODD

} state_type;

state_type state;

// =====================================================
// IMAGE PARAMETERS
// =====================================================

localparam logic [17:0] Y_BASE = 18'd0;
localparam logic [17:0] U_BASE = 18'd18816;
localparam logic [17:0] V_BASE = 18'd28224;
localparam logic [17:0] RGB_BASE = 18'd205696;

localparam int IMAGE_WIDTH = 224;
localparam int IMAGE_HEIGHT = 168;

// =====================================================
// CONTROL
// =====================================================

logic running;

// =====================================================
// PIXEL COUNTERS
// =====================================================

logic [9:0] pixel_X_pos;
logic [9:0] pixel_Y_pos;

// =====================================================
// SRAM ADDRESS COUNTERS
// =====================================================

logic [17:0] Y_address_counter;
logic [17:0] U_address_counter;
logic [17:0] V_address_counter;
logic [17:0] RGB_write_address;

// =====================================================
// SRAM DATA REGISTERS
// =====================================================

logic [15:0] Y_data;
logic [15:0] U_word_buffer;
logic [15:0] V_word_buffer;

logic [7:0] U_buffer;
logic [7:0] V_buffer;

// =====================================================
// CHROMA SHIFT REGISTERS
// =====================================================

logic [7:0] U_data [0:7];
logic [7:0] V_data [0:7];

// =====================================================
// INTERPOLATION SUMS
// =====================================================

logic [8:0] U_sum1;
logic [8:0] U_sum2;
logic [8:0] U_sum3;
logic [8:0] U_sum4;

logic [8:0] V_sum1;
logic [8:0] V_sum2;
logic [8:0] V_sum3;
logic [8:0] V_sum4;

// =====================================================
// YUV REGISTERS
// =====================================================

logic [7:0] Y_even;
logic [7:0] Y_odd;

logic [7:0] U_even;
logic [7:0] U_odd;

logic [7:0] V_even;
logic [7:0] V_odd;

// =====================================================
// CHROMA INTERPOLATION ACCUMULATORS
// =====================================================

logic signed [31:0] U_odd_accumulator;
logic signed [31:0] V_odd_accumulator;

// =====================================================
// RGB ACCUMULATORS
// =====================================================

logic signed [31:0] R_even_accumulator;
logic signed [31:0] G_even_accumulator;
logic signed [31:0] B_even_accumulator;

logic signed [31:0] R_odd_accumulator;
logic signed [31:0] G_odd_accumulator;
logic signed [31:0] B_odd_accumulator;

// =====================================================
// RGB OUTPUT REGISTERS
// =====================================================

logic [7:0] R_even;
logic [7:0] G_even;
logic [7:0] B_even;

logic [7:0] R_odd;
logic [7:0] G_odd;
logic [7:0] B_odd;

// =====================================================
// THREE SHARED COMBINATIONAL MULTIPLIERS
// =====================================================

logic signed [31:0] op1;
logic signed [31:0] op2;
logic signed [31:0] op3;
logic signed [31:0] op4;
logic signed [31:0] op5;
logic signed [31:0] op6;

wire signed [31:0] mult_1;
wire signed [31:0] mult_2;
wire signed [31:0] mult_3;

assign mult_1 = op1 * op2;
assign mult_2 = op3 * op4;
assign mult_3 = op5 * op6;

// =====================================================
// MULTIPLIER OPERAND SELECTION
// =====================================================

always_comb begin

    op1 = 32'sd0;
    op2 = 32'sd0;
    op3 = 32'sd0;
    op4 = 32'sd0;
    op5 = 32'sd0;
    op6 = 32'sd0;

    case (state)

        S_U_CALCULATIONS: begin

        end

        S_V_CALCULATIONS1: begin

        end

        S_V_CALCULATIONS2: begin

        end

        S_UV_EVEN_CALCULATIONS: begin

        end

        S_UV_ODD_CALCULATIONS: begin

        end

        S_RGB_CALCULATIONS_EVEN: begin

        end

        S_RGB_CALCULATIONS_ODD: begin

        end

        default: begin

        end

    endcase

end

// =====================================================
// FSM
// =====================================================

integer i;

always_ff @(posedge Clock_50 or negedge Resetn) begin

    if (Resetn == 1'b0) begin

        // FSM
        state <= LI_READ_U0;
        running <= 1'b0;
        Done <= 1'b0;

        // SRAM
        SRAM_we_n <= 1'b1;
        SRAM_write_data <= 16'd0;
        SRAM_address <= 18'd0;

        // Pixel counters
        pixel_X_pos <= 10'd0;
        pixel_Y_pos <= 10'd0;

        // Address counters
        Y_address_counter <= Y_BASE;
        U_address_counter <= U_BASE;
        V_address_counter <= V_BASE;
        RGB_write_address <= RGB_BASE;

        // SRAM data registers
        Y_data <= 16'd0;
        U_word_buffer <= 16'd0;
        V_word_buffer <= 16'd0;

        U_buffer <= 8'd0;
        V_buffer <= 8'd0;

        // Chroma shift registers
        for (i = 0; i < 8; i = i + 1) begin
            U_data[i] <= 8'd0;
            V_data[i] <= 8'd0;
        end

        // U interpolation sums
        U_sum1 <= 9'd0;
        U_sum2 <= 9'd0;
        U_sum3 <= 9'd0;
        U_sum4 <= 9'd0;

        // V interpolation sums
        V_sum1 <= 9'd0;
        V_sum2 <= 9'd0;
        V_sum3 <= 9'd0;
        V_sum4 <= 9'd0;

        // Chroma accumulators
        U_odd_accumulator <= 32'sd0;
        V_odd_accumulator <= 32'sd0;

        // YUV registers
        Y_even <= 8'd0;
        Y_odd <= 8'd0;

        U_even <= 8'd0;
        U_odd <= 8'd0;

        V_even <= 8'd0;
        V_odd <= 8'd0;

        // Even RGB accumulators
        R_even_accumulator <= 32'sd0;
        G_even_accumulator <= 32'sd0;
        B_even_accumulator <= 32'sd0;

        // Odd RGB accumulators
        R_odd_accumulator <= 32'sd0;
        G_odd_accumulator <= 32'sd0;
        B_odd_accumulator <= 32'sd0;

        // Even RGB output
        R_even <= 8'd0;
        G_even <= 8'd0;
        B_even <= 8'd0;

        // Odd RGB output
        R_odd <= 8'd0;
        G_odd <= 8'd0;
        B_odd <= 8'd0;

    end else begin

        if (running == 1'b0) begin

            if (Start == 1'b1) begin
                running <= 1'b1;
                Done <= 1'b0;
                state <= LI_READ_U0;
            end

        end else begin

            case (state)

                // =====================================
                // LEAD-IN STATES
                // =====================================

                LI_READ_U0: begin

                    state <= LI_READ_U1;
                end

                LI_READ_U1: begin

                    state <= LI_READ_U2;
                end

                LI_READ_U2: begin

                    state <= LI_READ_V0;
                end

                LI_READ_V0: begin

                    state <= LI_READ_V1;
                end

                LI_READ_V1: begin

                    state <= LI_READ_V2;
                end

                LI_READ_V2: begin

                    state <= LI_READ_Y;
                end

                LI_READ_Y: begin

                    state <= LI_LOAD_V1;
                end

                LI_LOAD_V1: begin

                    state <= LI_LOAD_V2;
                end

                LI_LOAD_V2: begin

                    state <= LI_CALCULATE_V;
                end

                LI_CALCULATE_V: begin

                    state <= S_U_CALCULATIONS;
                end


                // =====================================
                // COMMON CASE STATES
                // =====================================

                S_U_CALCULATIONS: begin

                    state <= S_V_CALCULATIONS1;
                end

                S_V_CALCULATIONS1: begin

                    state <= S_V_CALCULATIONS2;
                end

                S_V_CALCULATIONS2: begin

                    state <= S_UV_EVEN_CALCULATIONS;
                end

                S_UV_EVEN_CALCULATIONS: begin

                    state <= S_UV_ODD_CALCULATIONS;
                end

                S_UV_ODD_CALCULATIONS: begin

                    state <= S_RGB_CALCULATIONS_EVEN;
                end

                S_RGB_CALCULATIONS_EVEN: begin

                    state <= S_RGB_CALCULATIONS_ODD;
                end

                S_RGB_CALCULATIONS_ODD: begin

                    // TODO: Implement pixel-pair counter,
                    // end-of-row detection, row address
                    // updates, and image completion.

                    state <= S_U_CALCULATIONS;
                end

                default: begin
                    state <= LI_READ_U0;
                end

            endcase

        end

    end

end

endmodule

`ifndef DISABLE_DEFAULT_NET
`default_nettype wire
`endif
