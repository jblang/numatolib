module vga(pixel_clk, button, vga_hsync, vga_vsync, vga_red, vga_green, vga_blue);
	// Timing values for 
	// See http://www-mtl.mit.edu/Courses/6.111/labkit/vga.shtml

	/*
	// 640x480 @ 60Hz
	// 25.175 MHz pixel clock
	parameter H_ACTIVE = 640;
	parameter H_FRONT = 24;
	parameter H_PULSE = 96;
	parameter H_BACK = 48;
	parameter V_ACTIVE = 480;
	parameter V_FRONT = 11;
	parameter V_PULSE = 2;
	parameter V_BACK = 9;
	*/
	
	// 640x480 @ 85Hz
	// 36 MHz pixel clock
	parameter H_ACTIVE = 640;
	parameter H_FRONT = 32;
	parameter H_PULSE = 48;
	parameter H_BACK = 112;
	parameter V_ACTIVE = 480;
	parameter V_FRONT = 1;
	parameter V_PULSE = 3;
	parameter V_BACK = 25;
	
	/*
	// 800x600 @ 60Hz
	// 40MHz pixel clock
	parameter H_ACTIVE = 800;
	parameter H_FRONT = 40;
	parameter H_PULSE = 128;
	parameter H_BACK = 88;
	parameter V_ACTIVE = 600;
	parameter V_FRONT = 1;
	parameter V_PULSE = 4;
	parameter V_BACK = 23;
	*/
	
	input pixel_clk;
	input [6:3] button;
	
	output vga_hsync;
	output vga_vsync; 
	
	output [2:0] vga_red;
	output [2:0] vga_green;
	output [1:0] vga_blue;
	
	reg [9:0] h_count;
	reg [9:0] v_count;
	reg [9:0] h_shift;
	reg [9:0] v_shift;
	reg [19:0] frame;
	
	wire [9:0] limit;
	wire [9:0] muncher;

	always @(posedge pixel_clk)
	begin
		if (h_count < H_ACTIVE + H_FRONT + H_PULSE + H_BACK - 1)
			// Increment horizontal for each tick
			h_count <= h_count + 1;
		else
		begin
			// At the end of the line, reset horizontal count and increment vertical
			h_count <= 0;
			if (v_count < V_ACTIVE + V_FRONT + V_PULSE + V_BACK - 1)
				v_count <= v_count + 1;
			else
				// At the end of the frame, reset vertical count and increment frame count
				v_count <= 0;
				frame <= frame  + 1;
		end
	end
	
	// After the specified number of frames, check buttons and pan accordingly
	always @(posedge frame[8])
	begin
		if(button[3]) // up
			v_shift = v_shift - 1;
		if(button[4]) // right
			h_shift = h_shift + 1;
		if(button[5]) // down
			v_shift = v_shift + 1;
		if(button[6]) // left
			h_shift = h_shift - 1;
	end
	
	// Generate horizontal and vertical sync pulses at the appropriate time
	assign vga_hsync = h_count > H_ACTIVE + H_FRONT && h_count < H_ACTIVE + H_FRONT + H_PULSE;
	assign vga_vsync = v_count > V_ACTIVE + V_FRONT && v_count < V_ACTIVE + V_FRONT + V_PULSE;
	
	// Munching squares: http://en.wikipedia.org/wiki/Munching_square
	// Take x xor y and if the result is less than a limit derived from the
	// frame count, use the value of x xor y, otherwise show black.
	assign limit = frame[19] ? frame[18:9] : ~frame[18:9];
	assign muncher = ((h_count+h_shift) ^ (v_count+v_shift)) < limit ? (h_count+h_shift) ^ (v_count+v_shift) : 9'b0;

	// Use different portions of the bit pattern for red, green and blue
	// Output black during horizontal and vertical blanking interval
	assign vga_red = h_count < H_ACTIVE && v_count < V_ACTIVE ? muncher[8:6] : 3'b0;
	assign vga_green = h_count < H_ACTIVE && v_count < V_ACTIVE ? muncher[5:3] : 3'b0;
	assign vga_blue = h_count < H_ACTIVE && v_count < V_ACTIVE ? muncher[2:1] : 2'b0;
endmodule

module add3(in, out);
	input [3:0] in;
	output reg [3:0] out;

	always @ (in)
		case (in)
			4'b0000: out <= 4'b0000;
			4'b0001: out <= 4'b0001;
			4'b0010: out <= 4'b0010;
			4'b0011: out <= 4'b0011;
			4'b0100: out <= 4'b0100;
			4'b0101: out <= 4'b1000;
			4'b0110: out <= 4'b1001;
			4'b0111: out <= 4'b1010;
			4'b1000: out <= 4'b1011;
			4'b1001: out <= 4'b1100;
			default: out <= 4'bXXXX;
		endcase
endmodule
