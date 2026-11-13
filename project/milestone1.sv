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

  output logic Done);

typedef enum logic [4:0] {
  // Lead-in states
  LI_READ_U0,                 // 0
  LI_READ_U1,                 // 1
  LI_READ_U2,                 // 2
  LI_READ_V0,                 // 3
  LI_READ_V1,                 // 4
  LI_READ_V2,                 // 5
  LI_LOAD_V0,                  // 6
  LI_LOAD_V1,                 // 7

  // Common case states
  S_M1_INTERPOLATE_TAP_0,
  S_M1_INTERPOLATE_TAP_1,
  S_M1_INTERPOLATE_TAP_2,
  S_M1_INTERPOLATE_TAP_3,
  S_M1_COMPUTE_ODD_RED_GREEN,
  S_M1_COMPUTE_ODD_BLUE_GREEN,
} state_type;

state_type state;

localparam logic [17:0] Y_BASE = 18'd0;
localparam logic [17:0] U_BASE = 18'd18816;
localparam logic [17:0] V_BASE = 18'd28224;
localparam logic [17:0] RGB_BASE = 18'd205696;

localparam int IMAGE_WIDTH = 224;
localparam int IMAGE_HEIGHT = 168;

logic running;

logic [9:0] pixel_X_pos;
logic [9:0] pixel_Y_pos;

// SRAM address counters
logic [17:0] Y_address_counter;
logic [17:0] U_address_counter;
logic [17:0] V_address_counter;
logic [17:0] RGB_write_address;

logic [15:0] Y_data;
logic [7:0] U_word_buffer;
logic [7:0] V_word_buffer;

logic [7:0] U_buffer;
logic [7:0] V_buffer;

logic [7:0] U_data [0:7];
logic [7:0] V_data [0:7];

// Sum regs
logic [8:0] U_sum1;
logic [8:0] U_sum2;
logic [8:0] U_sum3;
logic [8:0] U_sum4;

logic [8:0] V_sum1;
logic [8:0] V_sum2;
logic [8:0] V_sum3;
logic [8:0] V_sum4;

// Registers Y, U, V
logic [7:0] Y_even;
logic [7:0] Y_odd;

logic [7:0] U_even;
logic [7:0] U_odd;

logic [7:0] V_even;
logic [7:0] V_odd;

// Accums
logic signed [31:0] U_odd_accumulator;
logic signed [31:0] V_odd_accumulator;

logic signed [31:0] R_even_accumulator;
logic signed [31:0] G_even_accumulator;
logic signed [31:0] B_even_accumulator;

logic signed [31:0] R_odd_accumulator;
logic signed [31:0] G_odd_accumulator;
logic signed [31:0] B_odd_accumulator;

// RGB registers
logic [7:0] R_even;
logic [7:0] G_even;
logic [7:0] B_even;

logic [7:0] R_odd;
logic [7:0] G_odd;
logic [7:0] B_odd;

//multipliers 
logic signed [31:0] op1;
logic signed [31:0] op2;
logic signed [31:0] op3;
logic signed [31:0] op4;
logic signed [31:0] op5;
logic signed [31:0] op6;

logic signed [31:0] mult_1;
logic signed [31:0] mult_2;
logic signed [31:0] mult_3;

assign mult_1 = op1 * op2;
assign mult_2 = op3 * op4;
assign mult_3 = op5 * op6;

always_comb begin
  op1 = 32'sd0;
  op2 = 32'sd0;
  op3 = 32'sd0;
  op4 = 32'sd0;
  op5 = 32'sd0;
  op6 = 32'sd0;

  case (state)
    S_M1_INTERPOLATE_TAP_0: begin
	 
	 op1 = $signed({1'b0, U_sum1});
	 op2 = -32'sd6;
	 
	 op3 = $signed({1'b0, U_sum3});
	 op4 = 32'sd59;
	 
	 
	 op5 = $signed({1'b0, U_sum2});
	 op6 = -32'sd21;
	 
    end

    S_M1_INTERPOLATE_TAP_1: begin
	 	
	 op1 = $signed({1'b0, U_sum4});
	 op2 = 32'sd224;
	 
	 op3 = $signed({1'b0, V_sum1});
	 op4 = -32'sd6;
	 
	 
	 op5 = $signed({1'b0, V_sum2});
	 op6 = -32'sd21;
	 
	 
    end

    S_M1_INTERPOLATE_TAP_2: begin
	 
	 op1 = $signed({1'b0, V_sum3});
	 op2 = 32'sd59;
	 
	 op3 = $signed({1'b0, V_sum4});
	 op4 = 32'sd224;
	 
	 op5 = $signed({1'b0, V_even}) - 32'sd128;
	 op6 = 32'sd12083;
	 
	 

    end

    S_M1_INTERPOLATE_TAP_3: begin
	 
	 op1 = $signed({1'b0, U_even}) - 32'sd128;
	 op2 = -32'sd1352;
	 
	 op1 = $signed({1'b0, V_even}) - 32'sd128;
	 op2 = -32'sd4678;
	 
	 op5 = $signed({1'b0, U_even}) - 32'sd128;
	 op6 = 32'sd15409;
	 
    end

    S_M1_COMPUTE_ODD_RED_GREEN: begin
	 
	 op1 = $signed({1'b0, U_sum2});
	 op2 = -32'sd6;

	 
	 op5 = $signed({1'b0, U_even}) - 32'sd128;
	 op6 = -32'sd1352;
	 
    end

    S_M1_COMPUTE_ODD_BLUE_GREEN: begin
	 
	 op1 = $signed({1'b0, U_sum2});
	 op2 = -32'sd6;
	 
	 op3 = 32'b0;
	 op4 = 32'b0;
	 
	 op5 = $signed({1'b0, U_even}) - 32'sd128;
	 op6 = -32'sd1352;
	 
    end

    default: begin
    end
  endcase
end

// FSM
integer i;

always_ff @(posedge Clock_50 or negedge Resetn) begin
  if (Resetn == 1'b0) begin
    // FSM
    state <= LI_READ_U0;
  //  running <= 1'b0;
  //  Done <= 1'b0;
	 
    SRAM_we_n <= 1'b1;
    SRAM_write_data <= 16'd0;
    SRAM_address <= 18'd0;
    pixel_X_pos <= 10'd0;
    pixel_Y_pos <= 10'd0;

    Y_address_counter <= Y_BASE;
    U_address_counter <= U_BASE;
    V_address_counter <= V_BASE;
    RGB_write_address <= RGB_BASE;

    Y_data <= 16'd0;
    U_word_buffer <= 8'd0;
    V_word_buffer <= 8'd0;

    U_buffer <= 8'd0;
    V_buffer <= 8'd0;

    // Chroma shift registers
    for (i = 0; i < 8; i = i + 1) begin
      U_data[i] <= 8'd0;
      V_data[i] <= 8'd0;
    end

    U_sum1 <= 9'd0;
    U_sum2 <= 9'd0;
    U_sum3 <= 9'd0;
    U_sum4 <= 9'd0;
    V_sum1 <= 9'd0;
    V_sum2 <= 9'd0;
    V_sum3 <= 9'd0;
    V_sum4 <= 9'd0;

    U_odd_accumulator <= 32'sd0;
    V_odd_accumulator <= 32'sd0;

    Y_even <= 8'd0;
    Y_odd <= 8'd0;
    U_even <= 8'd0;
    U_odd <= 8'd0;
    V_even <= 8'd0;
    V_odd <= 8'd0;

    R_even_accumulator <= 32'sd0;
    G_even_accumulator <= 32'sd0;
    B_even_accumulator <= 32'sd0;
    R_odd_accumulator <= 32'sd0;
    G_odd_accumulator <= 32'sd0;
    B_odd_accumulator <= 32'sd0;


    R_even <= 8'd0;
    G_even <= 8'd0;
    B_even <= 8'd0;
    R_odd <= 8'd0;
    G_odd <= 8'd0;
    B_odd <= 8'd0;
	 
  end else begin

      case (state)
        // LEAD-IN STATES
        LI_READ_U0: begin
				
				SRAM_we_n <= 1'b1; 
				SRAM_address <= 18'd18816; 
		  
				state <= LI_READ_U1;
        end

        LI_READ_U1: begin
		  
				SRAM_we_n <= 1'b1; 
				SRAM_address <= SRAM_address + 1'b1; 
				
				state <= LI_READ_U2;
        end

        LI_READ_U2: begin
				SRAM_we_n <= 1'b1; 
				SRAM_address <= SRAM_address + 1'b1; 
				
				state <= LI_READ_V0;
        end

        LI_READ_V0: begin
				SRAM_we_n <= 1'b1; 
				SRAM_address <= 18'd28224; 
				
				U_data[7] <= SRAM_read_data[15:8]; // U0
				U_data[6] <= SRAM_read_data[15:8]; // U0
				U_data[5] <= SRAM_read_data[15:8]; // U0
				U_data[4] <= SRAM_read_data[15:8]; // U0
				U_data[3] <= SRAM_read_data[7:0];  // U1
				
				state <= LI_READ_V1;
        end

        LI_READ_V1: begin
				SRAM_we_n <= 1'b1; 
				SRAM_address <= SRAM_address + 1'b1; 
				
				U_data[2] <= SRAM_read_data[15:8]; // U2
				U_data[1] <= SRAM_read_data[7:0];  // U3
				
				state <= LI_READ_V2;
        end

        LI_READ_V2: begin
				SRAM_we_n <= 1'b1; 
				SRAM_address <= SRAM_address + 1'b1; 
				
				U_data[0] <= SRAM_read_data[15:8]; // U4
				U_buffer <= SRAM_read_data[7:0]; // U0
				
				state <= LI_LOAD_V0;
        end

        LI_LOAD_V0: begin
				
				V_data[7] <= SRAM_read_data[15:8]; // V0
				V_data[6] <= SRAM_read_data[15:8]; // V0
				V_data[5] <= SRAM_read_data[15:8]; // V0
				V_data[4] <= SRAM_read_data[15:8]; // V0
				V_data[3] <= SRAM_read_data[7:0];  // V1		
		
		
				//need to add u registers here 
				U_sum1 <= U_data[7] + U_data[0]; 
				U_sum2 <= U_data[6] + U_data[1];
				U_sum3 <= U_data[5] + U_data[2];
				U_sum4 <= U_data[4] + U_data[3];	
							
				state <= LI_LOAD_V1;
        end

        LI_LOAD_V1: begin
		  
				SRAM_we_n <= 1'b1; 
				SRAM_address <= 18'd0; 
				
				V_data[2] <= SRAM_read_data[15:8]; // V2
				V_data[1] <= SRAM_read_data[7:0];  // V3	
		  
				state <= LI_LOAD_V2;
        end

        LI_LOAD_V2: begin
		  
				V_data[0] <= SRAM_read_data[15:8]; // V0
				V_buffer <= SRAM_read_data[7:0];   // V1			  
				state <= S_M1_INTERPOLATE_TAP_0;
        end


        // COMMON CASE STATES
        S_M1_INTERPOLATE_TAP_0: begin
		  		  
				Y_data <= SRAM_read_data[15:0]; 
		  
				//need to add v regists here.
				V_sum1 <= V_data[7] + V_data[0]; 
				V_sum2 <= V_data[6] + V_data[1];
				V_sum3 <= V_data[5] + V_data[2];
				V_sum4 <= V_data[4] + V_data[3];	
				
				state <= S_M1_INTERPOLATE_TAP_1;
        end

        S_M1_INTERPOLATE_TAP_1: begin
				state <= S_M1_INTERPOLATE_TAP_2;
        end

        S_M1_INTERPOLATE_TAP_2: begin
				state <= S_M1_INTERPOLATE_TAP_3;
        end

        S_M1_INTERPOLATE_TAP_3: begin
				state <= S_M1_COMPUTE_ODD_RED_GREEN;
        end

        S_M1_COMPUTE_ODD_RED_GREEN: begin
				state <= S_M1_COMPUTE_ODD_BLUE_GREEN;
        end

        S_M1_COMPUTE_ODD_BLUE_GREEN: begin
				// TODO: Implement pixel-pair counter,
				// end-of-row detection, row address
				// updates, and image completion.		  
				state <= S_M1_INTERPOLATE_TAP_0;
        end


        default: begin
				state <= LI_READ_U0;
        end
      endcase
  end
end

endmodule

`ifndef DISABLE_DEFAULT_NET
`default_nettype wire
`endif
