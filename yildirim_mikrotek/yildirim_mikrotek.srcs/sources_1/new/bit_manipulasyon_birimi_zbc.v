`timescale 1ns / 1ps


module bit_manipulasyon_birimi_zbc#(
	parameter integer XLEN = 32  //width
) (
	// control signals
	input             clk_i,          
	input             rst_i,         
	
	// data input
	input             din_valid_i,      
	output            din_ready_o,      
	input  [XLEN-1:0] din_value1_i,        
	input  [XLEN-1:0] din_value2_i,        
	input             din_instruction_bit3_i,      // value of instruction bit 3
	input             din_instruction_bit12_i,     // value of instruction bit 12
	input             din_instruction_bit13_i,     // value of instruction bit 13
	
	// data output
	output            dout_valid_o,     
	input             dout_ready_i,                // accept output
	output [XLEN-1:0] dout_result_o       
);
	// 13 12  3   Function
	// --------   --------
	//  0  1  0   CLMUL
	//  1  0  0   CLMULR
	//  1  1  0   CLMULH
	// --------   --------
	//  0  1  1   CLMULW
	//  1  0  1   CLMULRW
	//  1  1  1   CLMULHW

	localparam SLEN = XLEN == 32 ? 3 : 4;

	reg mesgul;
	reg [SLEN-1:0] state;
	reg [XLEN-1:0] value1_reg, value2_reg, result_reg;
	reg funct_clmul__r, funct_clmul__h, funct_clmul__w;

	wire [XLEN-1:0] next_result_reg = (result_reg << 8) ^
			 (value2_reg[XLEN-1] ? value1_reg << 7 : 0) ^ (value2_reg[XLEN-2] ? value1_reg << 6 : 0) ^
			 (value2_reg[XLEN-3] ? value1_reg << 5 : 0) ^ (value2_reg[XLEN-4] ? value1_reg << 4 : 0) ^
			 (value2_reg[XLEN-5] ? value1_reg << 3 : 0) ^ (value2_reg[XLEN-6] ? value1_reg << 2 : 0) ^
			 (value2_reg[XLEN-7] ? value1_reg << 1 : 0) ^ (value2_reg[XLEN-8] ? value1_reg << 0 : 0);

	function [XLEN-1:0] bit_reverse;
		input [XLEN-1:0] in_value;
		integer i;
		begin
			for (i = 0; i < XLEN; i = i+1)
				bit_reverse[i] = in_value[XLEN-1-i];
		end
	endfunction

	function [XLEN-1:0] bit_reverse32;
		input [XLEN-1:0] in_value;
		integer i;
		begin
			bit_reverse32 = 'bx;
			for (i = 0; i < 32; i = i+1)
				bit_reverse32[i] = in_value[31-i];
		end
	endfunction

	assign din_ready_o = (!mesgul || (dout_valid_o && dout_ready_i)) && !rst_i;
	assign dout_valid_o = !state && mesgul && !rst_i;

	reg [XLEN-1:0] dout_result_reg;
	assign dout_result_o = dout_result_reg;
	
	always @* begin
		dout_result_reg = result_reg;
		if (funct_clmul__r) begin
			if (funct_clmul__w && XLEN != 32) begin
				dout_result_reg = bit_reverse32(dout_result_reg);
				dout_result_reg[XLEN-32] = 0;
			end else begin
				dout_result_reg = bit_reverse(dout_result_reg);
			end
		end
		if (funct_clmul__h) begin
			dout_result_reg = dout_result_reg >> 1;
		end
		if (funct_clmul__w && XLEN != 32) begin
			dout_result_reg[XLEN-1:XLEN-32] = {32{dout_result_reg[31]}};
		end
	end

	always @(posedge clk_i) begin
		if (dout_valid_o && dout_ready_i) begin
			mesgul <= 0;
		end
		if (!state) begin
			if (din_valid_i && din_ready_o) begin
				funct_clmul__r <= din_instruction_bit13_i;
				funct_clmul__h <= din_instruction_bit13_i && din_instruction_bit12_i;
				if (din_instruction_bit3_i && XLEN != 32) begin
					funct_clmul__w <= 1;
					value1_reg <= din_instruction_bit13_i ? bit_reverse32(din_value1_i) : din_value1_i;
					value2_reg <= din_instruction_bit13_i ? bit_reverse(din_value2_i)   : {din_value2_i, 32'bx};
				end else begin
					funct_clmul__w <= 0;
					value1_reg <= din_instruction_bit13_i ? bit_reverse(din_value1_i) : din_value1_i;
					value2_reg <= din_instruction_bit13_i ? bit_reverse(din_value2_i) : din_value2_i;
				end
				mesgul <= 1;
				state <= (din_instruction_bit3_i || XLEN == 32) ? 4 : 8;
			end
		end else begin
			result_reg <= next_result_reg;
			value2_reg <= value2_reg << 8;
			state <= state - 1;
		end
		if (rst_i) begin
			mesgul <= 0;
			state <= 0;
		end
	end
endmodule
