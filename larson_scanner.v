`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:40:51 01/22/2015 
// Design Name: 
// Module Name:    larson_scanner 
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

// Display a Larson Scanner (aka Cylon Eyes)
module larson_scanner(CLKIN, LED);
	input CLKIN;

	output [8:1] LED;
	
	reg [22:0] cnt = 0;
	wire direction;
	wire [2:0] position;
	
	// A counter that increments on each clock tick (12MHz = 12 million times a second)
	// When it reaches 2^23 (~8 million), it starts over again at 0.
	always @(posedge CLKIN) cnt <= cnt + 1;
	
	// If the first bit is flipping from 0 to 1 and back 12 million times a second, then the 22nd
	// bit in the counter flips from 0 to 1 and back just over 2.86 times a second (12,000,000 / 2^22).
	assign direction = cnt[22];

	// Each of the bits 21 through 19 change state twice as fast as the one to its left.
	// Bit 21 changes 1.43 times, 20 changes around ever 3/4 of a second, and so on.
	// Here we treat bit 22 as a direction indicator. 0 means count up; 1 means count down.
	// To acomplish this, we invert the bits 21 through 19 when bit 22 is 0 and not when it's 1.
	assign position = direction ? cnt[21:19] : ~cnt[21:19];

	// We take 1 (meaning on) and shift it to the current position among the 8 LEDs.
	// This makes the LEDs appear to scan back and forth, just like a Cylon's eyes.
	assign LED = (1 << position);
endmodule