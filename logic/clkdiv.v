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

/**
 * Simple Clock Devider
 * 
 * Devides a given input clock.
 * 
 * parameters:
 * 		div		count which is used to devide the input clock
 * inputs:
 * 		clk_i	input clock
 * outputs:
 * 		clk_o	output clock	
 */
module clkdiv(
	input rst,
	input clk_i,
	input [15:0] div,
	output clk_o
	);
		
	reg r_clk_o = 1'b0;
	reg [15:0] count = 16'h0;
	
	always @(posedge clk_i) begin
		
		if(rst) begin
			r_clk_o = 1'b0;
			count = 16'h0;			
		end
		else begin
			count = count + 1;
			if(count == div) begin
				count = 16'h0;
				r_clk_o = ~r_clk_o;
			end
		end
	end
	
	assign clk_o = r_clk_o;
	
endmodule