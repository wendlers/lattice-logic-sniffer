/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2015 Stefan Wendler
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
 
module top 
(
	input clk
	/* synthesis loc="27" pullmode="none" */,

	input rx
	/* synthesis loc="73" */,
	
	input [7:0] pin
	/* synthesis loc="10, 9, 6, 5, 4, 3, 2, 1" */,
	
	output tx
	/* synthesis loc="74" */,
   
	output [7:0] led
	/* synthesis loc="107, 106, 105, 104, 100, 99, 98, 97" */,

	output x2en
	/* synthesis loc="32" */,
	
	output [7:0] pout
	/* synthesis loc="96, 95, 94, 93, 92, 91, 86, 85" */, 
	
	output clk_sample
	/* synthesis loc="14" */
);
  	
   	parameter ENABLE  = 1'b1;
	parameter DISABLE = 1'b0;

	parameter STATE_RCV_REG = 2'b0;
	parameter STATE_RCV_VAL = 2'b1;
	
	parameter REG_LED			= 7'h0;
	parameter REG_MEMADR_RD_LO	= 7'h1;
	parameter REG_MEMADR_RD_HI	= 7'h2;
	parameter REG_MEMADR_WR_LO	= 7'h3;
	parameter REG_MEMADR_WR_HI	= 7'h4;
	parameter REG_MEM			= 7'h5;
	parameter REG_STATUS		= 7'h6;
	parameter REG_TRIG_EN		= 7'h7;
	parameter REG_TRIG_VAL		= 7'h8;
	parameter REG_CLKDIV_LO		= 7'h9;
	parameter REG_CLKDIV_HI		= 7'hA;	
	
	reg rst = ENABLE;
	reg transmit = DISABLE;
	reg [7:0] tx_byte;
	
	reg [6:0] register;
	reg [7:0] value;
	reg [2:0] state = 2'b0;
	
	reg [7:0] r_led = 8'b0;
	
	reg [13:0] memadr_rd = 13'h0;
	reg [13:0] memadr_wr = 13'h0;
	reg memwe = DISABLE;
	reg [7:0] memdata_in;
	wire [7:0] memdata_out;
	
	reg [7:0] memcnt_rd = 10'h0;

	reg [7:0] trig_en = 8'h0;
	reg [7:0] trig_val = 8'h0;
	
	reg [15:0] clkdiv = 16'h1;

	/** 
	 * Status register bits:
	 *
	 * Bit	Direction	Function
	 *   0	WR			Write 1 to start sampling, is set to 0 after sampling started
	 *   1	 R			1 if sampling is in progress, 0 no sampling in progress
	 *   2	WR			Trigger enable
	 *   3	
	 *   4
	 *   5
	 *   6
	 *   7
	 */
	reg [7:0] status = 8'b0;
	
	wire received;
	wire [7:0] rx_byte;
	wire is_receiving;
	wire is_transmitting;
	wire rcv_error;

	wire clk_96M; 
	wire clk_48M; 
	wire clk_24M; 
	wire clk_1M;

	// pll
	pll pll1 (
		clk, 
		clk_96M, 
		clk_48M, 
		clk_24M, 
		clk_1M
	);

	reg clk_sample_rst = DISABLE;
	// wire clk_sample;
	
	clkdiv div1 (
		clk_sample_rst,
		clk_96M,
		clkdiv,
		clk_sample
	);
	
	// DP ram
	ram ram1 (
		memadr_wr[13:0] - 1'b1,
		memadr_rd[13:0],
		memdata_in[7:0],
		memwe,
		clk_96M,
		ENABLE,
		rst,
		clk_96M,
		ENABLE,
		memdata_out[7:0]
	);

	// uart 115200 baud (12 MHz * 1000 * 1000 / (115200 * 4))
	// uart #(26) uart1 (
	uart #(26) uart1 (
		clk_96M, 				// The master clock for this module
		rst, 					// Synchronous reset.
		rx, 					// Incoming serial line
		tx, 					// Outgoing serial line
		transmit, 				// Signal to transmit
		tx_byte, 				// Byte to transmit
		received, 				// Indicated that a byte has been received.
		rx_byte, 				// Byte received
		is_receiving, 			// Low when receive line is idle.
		is_transmitting, 		// Low when transmit line is idle.
		recv_error 				// Indicates error in receiving packet.
    );

	////
	// communication loop
	////
	always @(posedge clk_96M) begin
		
		if(rst) begin
			rst <= DISABLE;
		end
		else if(received) begin
						
			case(state)
				STATE_RCV_REG: 
					begin
						register[6:0] = rx_byte[6:0];
						
						// check if bit 7 is 0, this means read access
						if(rx_byte[7] == 0) begin							
							
							////
							// handle register command
							////
							case(register)
								REG_STATUS			: tx_byte[7:0] = status[7:0];
								REG_LED				: tx_byte[7:0] = r_led[7:0];
								REG_MEMADR_RD_LO	: tx_byte[7:0] = memadr_rd[7:0];
								REG_MEMADR_RD_HI	: tx_byte[7:0] = memadr_rd[13:8];
								REG_MEMADR_WR_LO	: tx_byte[7:0] = memadr_wr[7:0];
								REG_MEMADR_WR_HI	: tx_byte[7:0] = memadr_wr[13:8];								
								REG_MEM				: state <= STATE_RCV_VAL;				// this takes the number of bytes as a parameter
								REG_TRIG_EN			: tx_byte[7:0] = trig_en[7:0];
								REG_TRIG_VAL		: tx_byte[7:0] = trig_val[7:0];
								REG_CLKDIV_LO		: tx_byte[7:0] = clkdiv[7:0];
								REG_CLKDIV_HI		: tx_byte[7:0] = clkdiv[15:8];	
								default				: tx_byte[7:0] = 8'hff;
							endcase
							
							// for single read access, begin data transfer
							if(register != REG_MEM) begin
								transmit <= ENABLE;
							end
						end
						else begin
							// write access always takes a parameter
							state <= STATE_RCV_VAL;
						end
					end
				STATE_RCV_VAL: 
					begin
						value[7:0] = rx_byte[7:0];
						
						////
						// handle parameter
						////
						case(register)
							REG_STATUS			: 
								begin
									status[0] = value[0];	// start sampling
									status[2] = value[2];	// enable trigger
								end
							REG_LED				: r_led[7:0] = value[7:0];
							REG_MEMADR_RD_LO	: memadr_rd[7:0] = value[7:0];
							REG_MEMADR_RD_HI	: memadr_rd[13:8] = value[5:0];	
							REG_MEM				: memcnt_rd[7:0] = value[7:0];
							REG_TRIG_EN			: trig_en[7:0] = value[7:0];
							REG_TRIG_VAL		: trig_val[7:0] = value[7:0];
							REG_CLKDIV_LO		: clkdiv[7:0] = value[7:0];
							REG_CLKDIV_HI		: clkdiv[15:8] = value[7:0];															
						endcase
						
						// reset sample clk
						if(register == REG_CLKDIV_LO || register == REG_CLKDIV_HI) begin
							clk_sample_rst = ENABLE;
						end
						
						// ready to receive next command
						state <= STATE_RCV_REG;
					end
			endcase
						
		end
		else if(is_transmitting) begin
			transmit <= DISABLE;
		end
		else if(!transmit && memcnt_rd) begin
			
			// send the requested bytes from memory until count is zero
			
			tx_byte[7:0] = memdata_out[7:0];
			memadr_rd = memadr_rd + 1;
			memcnt_rd = memcnt_rd - 1;
			
			transmit <= ENABLE;
		end		
		else if(status[1] && status[0]) begin
			status[0] = 1'b0;
		end
		else begin
			// enable sample clk in case it was disabled
			clk_sample_rst = DISABLE;
		end
	end
	
	////
	// sampling loop
	////
	always @(posedge clk_sample) begin
		
		// stop writing to memory
		memwe = DISABLE;
	
		// start sampling is requesetd but sampling not started
		if(status[0] && !status[1] && 
			// check trigger if enabled
			(!status[2] || (status[2] && (pin[7:0] & trig_en[7:0]) == trig_val[7:0]))) 
			begin
			
			memadr_wr = 14'h00;			// start writing samples to address 0
			status[1] = ENABLE;			// sampling started
		end
		// sampling already in progress
		else if(status[1]) begin
			
			memdata_in[7:0] = pin[7:0];		// put sample to memory
			memadr_wr = memadr_wr + 1;		// auto advance to next address
			memwe = ENABLE;				// write to memory
			
			// when address is 0 again, whole sample memory is written - done sampling
			if(!memadr_wr) begin
				status[1] = DISABLE;
			end
		end	
	end
	
	reg [7:0] r_pout = 8'h0;
	
	// create some test data on the output
	always @(posedge clk_24M) begin
		r_pout <= r_pout + 1;
	end
	
	assign x2en = 1'b1; 
	assign led[7:0] = ~r_led[7:0];
	assign pout = r_pout;
endmodule
