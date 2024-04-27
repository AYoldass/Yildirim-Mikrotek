`timescale 1ns / 1ps

module bit_manipulasyon_birimi_crc#(
	parameter integer XLEN = 32
) (
	// control signals
	input             clk_i,         
	input             rst_i,          
	
	// data input
	input             din_valid_i,    
	output            din_ready_o,    
	input  [XLEN-1:0] din_value1_i,        
	input             din_instruction_bit20_i,    
	input             din_instruction_bit21_i,     
	input             din_instruction_bit23_i,     
	
	// data output
	output            dout_valid_o,    
	input             dout_ready_i,     
	output [XLEN-1:0] dout_result_o         
);
	reg            cmode;
	reg [3:0]      state;
	reg [XLEN-1:0] data, next;

	assign din_ready_o = &state || (dout_valid_o && dout_ready_i);
	assign dout_valid_o = !state;
	assign dout_result_o = data;

	integer i;
	always @* begin
		next = data;
		for (i = 0; i < 8; i = i+1)
			next = (next >> 1) ^ (next[0] ? (cmode ? 32'h 82F63B78 : 32'h EDB88320) : 0);
	end

	always @(posedge clk_i) begin
		if (|state != &state) begin
			state <= state - 1;
			data <= next;
		end
		if (dout_valid_o && dout_ready_i) begin
			state <= 15;
		end
		if (din_valid_i && din_ready_o) begin
			cmode <= din_instruction_bit23_i;
			state <= 1 << {din_instruction_bit21_i, din_instruction_bit20_i};
			data <= din_value1_i;
		end
		if (rst_i) begin
			state <= 15;
		end
	end
endmodule