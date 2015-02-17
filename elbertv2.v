`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Elbert V2 Library
// Copyright (c) 2015 J.B. Langston
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
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

module vga_driver(clk, color, hsync, vsync, red, green, blue, x, y);
	// VGA signal explanation and timing values for specific modes:
	// http://www-mtl.mit.edu/Courses/6.111/labkit/vga.shtml

	// 640x480 @ 60Hz, 25MHz pixel clock
	parameter H_ACTIVE = 640;
	parameter H_FRONT = 16;
	parameter H_PULSE = 96;
	parameter H_BACK = 48;
	parameter V_ACTIVE = 480;
	parameter V_FRONT = 11;
	parameter V_PULSE = 2;
	parameter V_BACK = 31;
	
	input clk;
	input [7:0] color;
	
	output hsync, vsync;
	output [9:0] x, y;
	output [2:0] red, green;
	output [1:0] blue;
	
	reg [9:0] h_count;
	reg [9:0] v_count;
	
	always @(posedge clk)
	begin
		if (h_count < H_ACTIVE + H_FRONT + H_PULSE + H_BACK - 1)
			// Increment horizontal count for each tick of the pixel clock
			h_count <= h_count + 1;
		else
		begin
			// At the end of the line, reset horizontal count and increment vertical
			h_count <= 0;
			if (v_count < V_ACTIVE + V_FRONT + V_PULSE + V_BACK - 1)
				v_count <= v_count + 1;
			else
				// At the end of the frame, reset vertical count
				v_count <= 0;
		end
	end
	
	// Generate horizontal and vertical sync pulses at the appropriate time
	assign hsync = h_count > H_ACTIVE + H_FRONT && h_count < H_ACTIVE + H_FRONT + H_PULSE;
	assign vsync = v_count > V_ACTIVE + V_FRONT && v_count < V_ACTIVE + V_FRONT + V_PULSE;
	
	// Output x and y coordinates
	assign x = h_count < H_ACTIVE ? h_count : 0;
	assign y = v_count < V_ACTIVE ? v_count : 0;

	// Generate separate RGB signals from different parts of color byte
	// Output black during horizontal and vertical blanking intervals
	assign red = h_count < H_ACTIVE && v_count < V_ACTIVE ? color[7:5] : 3'b0;
	assign green = h_count < H_ACTIVE && v_count < V_ACTIVE ? color[4:2] : 3'b0;
	assign blue = h_count < H_ACTIVE && v_count < V_ACTIVE ? color[1:0] : 2'b0;
endmodule

module munching_squares(x, y, vsync, color);
	// Munching squares: http://en.wikipedia.org/wiki/Munching_square
	input [9:0] x, y;
	input vsync;
	
	output [7:0] color;

	reg [10:0] frame;
	wire [9:0] limit;
	
	// We count the frames after each vsync signal
	always @(negedge vsync) frame <= frame + 1;	
	
	// Use frame count to generate an up-down counter for munching
	assign limit = frame[10] ? frame[9:0] : ~frame[9:0];
	
	// Assign color based on xor of x and y coordinates. If coordinates
	// are greater than limit, use black instead to create munching animation
	assign color = (x ^ y) < limit ? ((x ^ y) >> 2) : 9'b0;	
endmodule

// Demo the seven-segment display using values from the dip switches and buttons
module elbertv2_demo(clkin, dips, segments, anodes, leds, hsync, vsync, red, green, blue, rxd, txd);
	input clkin;
	input [8:1] dips;

	output [7:0] segments;
	output [3:1] anodes;
	output [8:1] leds;

	output hsync, vsync;
	output [2:0] red, green;
	output [1:0] blue;
	wire [7:0] color;
	wire [9:0] x, y;

	input rxd;
	output txd;

	reg [9:0] cnt;
	reg [9:0] baud_count;
	reg en_16_x_baud;


	wire [11:0] bcd;
	wire clk, led_clk;

	wire [7:0] uart_data;
	wire ready;

	// Use the DCM to multiply the incoming 12MHz clock to a 2MHz clock
	clock_mgr dcm (
		 .CLKIN_IN(clkin), 
		 .CLKFX_OUT(clk), 
		 .CLKIN_IBUFG_OUT(), 
		 .CLK0_OUT()
		 );

	// Convert binary input from DIP switches into BCD
	binary_to_bcd conv (
		.binary({4'b0, ~dips}),
		.bcd(bcd)
		);
	
	// Increment a counter for each clock cycle which can be used to divide the clock as needed
	always @(posedge clk) cnt <= cnt + 1;
	
	// Refresh the seven segment display too fast, and it will ghost; too slow, and it will flicker.
	// See http://en.wikipedia.org/wiki/Flicker_fusion_threshold for more information.
	// I'm dividing the incoming 25Mhz clock by 2^10 (1024), yielding a ~24.4kHz refresh.
	assign led_clk = cnt[9];

	// Multiplex BCD value across seven segment display (no decimal points)
   seven_segment_mux mux (
		.clk(led_clk), 
		.value({4'b0, bcd}), 
		.dp(3'b000), 
		.segments(segments), 
		.anodes(anodes)
		);

	// Generate sync pulses and x/y coordinates
	vga_driver vga (
		 .clk(clk), 
		 .color(color), 
		 .hsync(hsync), 
		 .vsync(vsync), 
		 .red(red),
		 .green(green),
		 .blue(blue),
		 .x(x), 
		 .y(y)
		 );
	
	// Generate munching squares pattern
	munching_squares munch (
		 .x(x), 
		 .y(y), 
		 .vsync(vsync),
		 .color(color)
		 );

	// Set baud rate to 115200 for the UART communications
	// 25MHz / (115200 * 16) = a period of 13 cycles
	always @(posedge clk) begin
      if (baud_count == 13) 
		begin
           		baud_count <= 1'b0;
      	     	en_16_x_baud <= 1'b1;
		end
       else
		begin
           		baud_count <= baud_count + 1;
           		en_16_x_baud <= 1'b0;
      	end
    end

	// UART taken from PicoBlaze, available at
	// http://www.xilinx.com/products/intellectual-property/picoblaze.html
	// Currently, just echo the character pressed on the console
	uart_rx rx_inst (
		 .serial_in(rxd), 
		 .data_out(uart_data), 
		 .read_buffer(ready), 
		 .reset_buffer(0), 
		 .en_16_x_baud(en_16_x_baud), 
		 .buffer_data_present(ready), 
		 .buffer_full(), 
		 .buffer_half_full(), 
		 .clk(clk)
		 );
		 
	uart_tx tx_inst (
		 .data_in(uart_data), 
		 .write_buffer(ready), 
		 .reset_buffer(0), 
		 .en_16_x_baud(en_16_x_baud), 
		 .serial_out(txd), 
		 .buffer_full(), 
		 .buffer_half_full(), 
		 .clk(clk)
		 );
	
	// Show binary code for last character pressed on LEDs
	assign leds = uart_data;
		 
endmodule



