`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:32:46 03/03/2015 
// Design Name: 
// Module Name:    binary_to_bcd 
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
// Convert binary number to BCD
module binary_to_bcd(binary, bcd);
	parameter BITS_IN = 8;
	parameter DIGITS_OUT = 3;
	
	input [BITS_IN-1:0] binary;
	
	output reg [4*DIGITS_OUT-1:0] bcd;
	
	integer b, d;
	
	// Double dabble algorithm: http://en.wikipedia.org/wiki/Double_dabble
	always @(binary)
	begin
		bcd = 0;
		for (b = BITS_IN - 1; b >= 0; b = b - 1)
		begin
			for (d = 0; d < DIGITS_OUT; d = d + 1)
				if (bcd[d*4 +: 4] >= 5)
					bcd[d*4 +: 4] = bcd[d*4 +: 4] + 3;
			bcd = bcd << 1; 
			bcd[0] = binary[b];
		end
	end
endmodule