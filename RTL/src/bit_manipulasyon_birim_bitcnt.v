`timescale 1ns / 1ps

module bit_manipulasyon_birim_bitcnt#(
	parameter integer XLEN = 32,
	parameter integer BMAT = 0
) (
	// control signals
	input             clk_i,          
	input             rst_i,         

	// data input
	input             din_valid_i,      
	output            din_ready_o,     
	input  [XLEN-1:0] din_value1_i,       
	input             din_instruction_bit3_i,     
	input             din_instruction_bit20_i,    
	input             din_instruction_bit21_i,     
	input             din_instruction_bit22_i,     

	// data output
	output            dout_valid_o,    
	input             dout_ready_i,    
	output [XLEN-1:0] dout_result_o         
);
	// 22 21 20  3   Function
	// -----------   --------
	//  0  0  0  W   CLZ
	//  0  0  1  W   CTZ
	//  0  1  0  W   PCNT
	//  0  1  1  0   BMATFLIP
	//  1  0  0  0   SEXT.B
	//  1  0  1  0   SEXT.H

	assign din_ready_o  = dout_ready_i && !rst_i;
	assign dout_valid_o = din_valid_i  && !rst_i;

	wire wmode     = (XLEN == 32) || din_instruction_bit3_i;
	wire revmode   = !din_instruction_bit20_i;
	wire czmode    = !din_instruction_bit21_i;
	wire bmatmode  = (XLEN == 64) && BMAT && din_instruction_bit20_i && din_instruction_bit21_i;

	wire            sextbit = din_instruction_bit20_i ? din_value1_i[15] : din_value1_i[7];
	wire [XLEN-1:0] sextval = {{XLEN-16{sextbit}}, din_instruction_bit20_i ? din_value1_i[15:8] : {8{din_value1_i[7]}}, din_value1_i[7:0]};

	integer i;
	reg [XLEN-1:0] data;
	reg [XLEN-1:0] transp;
	reg [7:0]      cnt;

	always @* begin
		for (i = 0; i < XLEN; i = i+1)
			data[i] = (i < 32 && wmode) ? din_value1_i[(64-i-1) % 32] : din_value1_i[(64-i-1) % XLEN];
		if (!revmode)
			data = din_value1_i;
		if (czmode)
			data = (data-1) & ~data;
		if (wmode)
			data = data & 32'hFFFFFFFF;

		cnt = 0;
		for (i = 0; i < XLEN; i = i+1)
			cnt = cnt + data[i];

		for (i = 0; i < XLEN; i=i+1)
			transp[i] = din_value1_i[{i[2:0], i[5:3]} % XLEN];
	end 

	assign dout_result_o = din_instruction_bit22_i ? sextval : bmatmode ? transp : cnt;
endmodule