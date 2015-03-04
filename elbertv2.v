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



