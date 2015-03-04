`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:32:01 03/03/2015 
// Design Name: 
// Module Name:    seven_segment 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

// Decode 4 bits into seven-segment representation
module seven_segment_decoder(value, dp, segments);
	input [3:0] value;
	input dp;
	
	output reg [7:0] segments;
	
	// Decode 4-bit hex or bcd digit to lit segments.
	// The segments are controlled by the cathode (negative electrode)
	// so they are active low, meaning 0 is on and 1 is off.
	//
	// Segment legend:
	//
	//     _a_
	//   f|_g_|b
	//   e|_d_|c .dp
	//
	always @(value, dp) begin
		case (value)
			// Segment columns:  abcdefg
			4'h1 : segments = 7'b1001111;
			4'h2 : segments = 7'b0010010;
			4'h3 : segments = 7'b0000110;
			4'h4 : segments = 7'b1001100;
			4'h5 : segments = 7'b0100100;
			4'h6 : segments = 7'b0100000;
			4'h7 : segments = 7'b0001111;
			4'h8 : segments = 7'b0000000;
			4'h9 : segments = 7'b0000100;
			4'hA : segments = 7'b0001000; 
			4'hB : segments = 7'b1100000; // lower case
			4'hC : segments = 7'b0110001; 
			4'hD : segments = 7'b1000010; // lower case
			4'hE : segments = 7'b0110000; 
			4'hF : segments = 7'b0111000; 
			4'h0 : segments = 7'b0000001;
			default : segments = 7'b1111111;
		endcase
		segments[7] = ~dp;
	end
endmodule

// Display a value on a multiplexed seven segment display
module seven_segment_mux(clk, value, dp, segments, anodes);
	// Refresh the seven segment display too fast, and it will ghost; too slow, and it will flicker.
	// See http://en.wikipedia.org/wiki/Flicker_fusion_threshold for more information.
	// I have found that a refresh rate of around 14
	
	// Calculates the number of bits required for a given value
	function integer clog2;
	input integer value;
	begin
		value = value-1;
		for (clog2 = 0; value > 0; clog2 = clog2 + 1)
			value = value >> 1;
		end
	endfunction

	// Number of digits in the display
	parameter WIDTH = 3;

	input clk;
	input [4*WIDTH-1:0] value;
	input [WIDTH-1:0] dp;
	
	output [7:0] segments;
	output [WIDTH-1:0] anodes;
	
	reg [clog2(WIDTH)-1:0] active = 0;
	
	// Decode the 4 bits containing the current digit
	seven_segment_decoder decoder(.value(value[active*4 +: 4]), .dp(dp[active]), .segments(segments));

	// Anodes are driven by a PNP transistor which inverts its input, so they're active low
	// and we have to invert the output another time to get the correct digit to light up.
	assign anodes = ~(1 << active);

	// Cycle through multiplexed digits on each clock pulse.
	always @(posedge clk) active <= (active < WIDTH) ? (active + 1) : 0;
endmodule