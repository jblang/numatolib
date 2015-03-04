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

// Demo the seven-segment display using values from the dip switches and buttons
module mimasv2_demo(gclk1, dips, buttons, segments, anodes, leds, hsync, vsync, red, green, blue, rx, tx);
	input gclk1;
	input [8:1] dips;
	input [6:1] buttons;

	output [7:0] segments;
	output [3:1] anodes;
	output [8:1] leds;

	output hsync, vsync;
	output [2:0] red, green;
	output [1:0] blue;
	wire [7:0] color;
	wire [9:0] x, y;

	reg [11:0] cnt;

	wire [11:0] bcd;
	wire pixel_clk, led_clk;

	input rx;
	output tx;

	reg [9:0] baud_count;
	reg baud_clk;
	wire [7:0] uart_data;
	wire ready;

	//assign leds[6:1] = ~buttons;
	//assign leds[8:7] = 2'b0;
	
	// Convert binary input from DIP switches into BCD
	binary_to_bcd conv (
		.binary({4'b0, ~dips}),
		.bcd(bcd)
		);
	
	// Clock dividers
	always @(posedge gclk1) cnt <= cnt + 1;
	assign pixel_clk = cnt[1]; // 25MHz - VGA pixel clock
	assign led_clk = cnt[11];	// 24.4kHz - Digit multiplexing clock

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
		 .clk(pixel_clk), 
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

	// UART taken from PicoBlaze, available at
	// http://www.xilinx.com/products/intellectual-property/picoblaze.html
	// To learn how UARTs work, see http://www.fpga4fun.com/SerialInterface.html
	
	// Set baud rate to 19200 for the UART communications
	// 100MHz / (19200 * 16) = a period of 325 cycles
	always @(posedge gclk1) begin
      if (baud_count == 325) begin
			baud_count <= 1'b0;
			baud_clk <= 1'b1;
		end else begin
			baud_count <= baud_count + 1;
			baud_clk <= 1'b0;
		end
	end

	// Currently, just echo the character pressed on the console
	uart_rx6 rx_inst (
		 .serial_in(rx), 
		 .en_16_x_baud(baud_clk), 
		 .data_out(uart_data), 
		 .buffer_read(ready), 
		 .buffer_data_present(ready), 
		 .buffer_half_full(), 
		 .buffer_full(), 
		 .buffer_reset(1'b0), 
		 .clk(gclk1)
		 );
		 
	uart_tx6 tx_inst (
		 .data_in(uart_data), 
		 .buffer_write(ready), 
		 .buffer_reset(1'b0), 
		 .en_16_x_baud(baud_clk), 
		 .serial_out(tx), 
		 .buffer_data_present(), 
		 .buffer_half_full(), 
		 .buffer_full(), 
		 .clk(gclk1)
		 );

	// Show binary code for last character pressed on LEDs
	assign leds = uart_data;		 
endmodule



