`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:23:57 01/25/2015 
// Design Name: 
// Module Name:    spi 
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


module spi(CLKIN, SPI_SCK, SPI_SI, SPI_INITB, DIP, SPI_SO, LED, SSEG, ANODE);
	input CLKIN;
	input SPI_SCK;
	input SPI_SI;
	input SPI_INITB;
	input [8:1] DIP;
	
	output SPI_SO;
	output [1:1] LED;
	output [7:0] SSEG;
	output [3:1] ANODE;

	// sync SCK to the FPGA clock using a 3-bits shift register
	reg [2:0] SCKr;  always @(posedge CLKIN) SCKr <= {SCKr[1:0], SPI_SCK};
	wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
	wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

	// same thing for SSEL
	reg [2:0] SSELr;  always @(posedge CLKIN) SSELr <= {SSELr[1:0], SPI_INITB};
	wire SSEL_active = ~SSELr[1];  // SSEL is active low
	wire SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
	wire SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge

	// and for MOSI
	reg [1:0] MOSIr;  always @(posedge CLKIN) MOSIr <= {MOSIr[0], SPI_SI};
	wire MOSI_data = MOSIr[1];
	
	// we handle SPI in 8-bits format, so we need a 3 bits counter to count the bits as they come in
	reg [2:0] bitcnt;

	reg byte_received;  // high when a byte has been received
	reg [7:0] byte_data_received;
	
	seven_segment_mux mux(CLKIN, {8'b0, byte_data_received}, 3'b0, SSEG, ANODE);

	always @(posedge CLKIN)
	begin
	  if(~SSEL_active)
		 bitcnt <= 3'b000;
	  else
	  if(SCK_risingedge)
	  begin
		 bitcnt <= bitcnt + 3'b001;

		 // implement a shift-left register (since we receive the data MSB first)
		 byte_data_received <= {byte_data_received[6:0], MOSI_data};
	  end
	end

	always @(posedge CLKIN) byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);

	// we use the LSB of the data received to control an LED
	reg LED;
	always @(posedge CLKIN) if(byte_received) LED <= byte_data_received[0];	

	reg [7:0] byte_data_sent;

	reg [7:0] cnt;
	always @(posedge CLKIN) if(SSEL_startmessage) cnt<=cnt+8'h1;  // count the messages

	always @(posedge CLKIN)
	if(SSEL_active)
	begin
	  if(SCK_fallingedge)
	  begin
		 if(bitcnt==3'b000)
			byte_data_sent <= ~DIP;  // after that, we send 0s
		 else
			byte_data_sent <= {byte_data_sent[6:0], 1'b0};
	  end
	end

	assign SPI_SO = byte_data_sent[7];  // send MSB first
	// we assume that there is only one slave on the SPI bus
	// so we don't bother with a tri-state buffer for MISO
	// otherwise we would need to tri-state MISO when SSEL is inactive

endmodule


/*
module spi_slave(
    input clk,
    input rst,
    input ss,
    input mosi,
    output miso,
    input sck,
    output done,
    input [7:0] din,
    output [7:0] dout
    );

reg mosi_d, mosi_q;
reg ss_d, ss_q;
reg sck_d, sck_q;
reg sck_old_d, sck_old_q;
reg [7:0] data_d, data_q;
reg done_d, done_q;
reg [2:0] bit_ct_d, bit_ct_q;
reg [7:0] dout_d, dout_q;
reg miso_d, miso_q;

assign miso = miso_q;
assign done = done_q;
assign dout = dout_q;

always @(*) begin
    ss_d = ss;
    mosi_d = mosi;
    miso_d = miso_q;
    sck_d = sck;
    sck_old_d = sck_q;
    data_d = data_q;
    done_d = 1'b0;
    bit_ct_d = bit_ct_q;
    dout_d = dout_q;

    if (ss_q) begin
        bit_ct_d = 3'b0;
        data_d = din;
        miso_d = data_q[7];
    end else begin
        if (!sck_old_q && sck_q) begin // rising edge
            data_d = {data_q[6:0], mosi_q};
            bit_ct_d = bit_ct_q + 1'b1;
            if (bit_ct_q == 3'b111) begin
                dout_d = {data_q[6:0], mosi_q};
                done_d = 1'b1;
                data_d = din;
            end
        end else if (sck_old_q && !sck_q) begin // falling edge
            miso_d = data_q[7];
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        done_q <= 1'b0;
        bit_ct_q <= 3'b0;
        dout_q <= 8'b0;
        miso_q <= 1'b1;
    end else begin
        done_q <= done_d;
        bit_ct_q <= bit_ct_d;
        dout_q <= dout_d;
        miso_q <= miso_d;
    end

    sck_q <= sck_d;
    mosi_q <= mosi_d;
    ss_q <= ss_d;
    data_q <= data_d;
    sck_old_q <= sck_old_d;

end

endmodule

module spi(CLKIN, SPI_SCK, SPI_SI, SPI_INITB, DIP, SPI_SO, LED, SSEG, ANODE);
	input CLKIN;
	input SPI_SCK;
	input SPI_SI;
	input SPI_INITB;
	input [8:1] DIP;
	
	output SPI_SO;
	output [1:1] LED;
	output [7:0] SSEG;
	output [3:1] ANODE;
	
	wire [7:0] data_in;

	spi_slave spi_slave(CLKIN, 1'b0, SPI_INITB, SPI_SI, SPI_SO, SPI_SCK, LED[1], data_in, DIP);
	seven_segment_mux mux(CLKIN, {8'b0, data_in}, 3'b0, SSEG, ANODE);
endmodule
*/