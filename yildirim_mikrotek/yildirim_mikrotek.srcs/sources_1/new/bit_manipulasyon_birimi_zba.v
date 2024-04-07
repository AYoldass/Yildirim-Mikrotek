`timescale 1ns / 1ps


module bit_manipulasyon_birimi_zba#(
	parameter integer XLEN = 32
) (
	// control signals
	input             clk_i,          
	input             rst_i,         

	input             din_valid_i,      
	output            din_ready_o,     
	input  [XLEN-1:0] din_value1_i,       
	input  [XLEN-1:0] din_value2_i,       
	input  [XLEN-1:0] din_value3_i,        
	input             din_instruction_bit3_i,      
	input             din_instruction_bit5_i,      
	input             din_instruction_bit12_i,     
	input             din_instruction_bit13_i,    
	input             din_instruction_bit14_i,     
	input             din_instruction_bit25_i,     
	input             din_instruction_bit26_i,     
	input             din_instruction_bit27_i,    
	input             din_instruction_bit30_i,     

	output            dout_valid_o,     
	input             dout_ready_i,    
	output [XLEN-1:0] dout_result_o        
);
	// 30 27 26 25 14 13 12  5  3   Function
	// --------------------------   --------
	//  0  1  0  1  1  0  0  1  0   MIN
	//  0  1  0  1  1  0  1  1  0   MAX
	//  0  1  0  1  1  1  0  1  0   MINU
	//  0  1  0  1  1  1  1  1  0   MAXU
	// --------------------------   --------
	//  1  0  0  0  1  1  1  1  0   ANDN
	//  1  0  0  0  1  1  0  1  0   ORN
	//  1  0  0  0  1  0  0  1  0   XNOR
	// --------------------------   --------
	//  0  1  0  0  1  0  0  1  0   PACK
	//  0  1  0  0  1  0  0  1  1   PACKW
	//  0  1  0  0  1  1  1  1  0   PACKH
	//  1  1  0  0  1  0  0  1  0   PACKU
	//  1  1  0  0  1  0  0  1  1   PACKUW
	// --------------------------   --------
	//  -  -  0  1  0  0  1  1  0   CMIX
	//  -  -  0  1  1  0  1  1  0   CMOV
	// --------------------------   --------
	//  -  -  -  -  1  0  0  0  1   ADDIWU
	//  0  1  0  1  0  0  0  1  1   ADDWU
	//  1  1  0  1  0  0  0  1  1   SUBWU
	//  0  1  0  0  0  0  0  1  1   ADDUW
	//  1  1  0  0  0  0  0  1  1   SUBUW
	// --------------------------   --------
	//  0  0  0  0  0  1  0  1  0   SH1ADD
	//  0  0  0  0  1  0  0  1  0   SH2ADD
	//  0  0  0  0  1  1  0  1  0   SH3ADD
	// --------------------------   --------
	//  0  0  0  0  0  1  0  1  1   SH1ADDU.W
	//  0  0  0  0  1  0  0  1  1   SH2ADDU.W
	//  0  0  0  0  1  1  0  1  1   SH3ADDU.W
	// --------------------------   --------

	assign din_ready_o  = dout_ready_i && !rst_i;
	assign dout_valid_o = din_valid_i  && !rst_i;


	// ---- SH1ADD SH2ADD SH3ADD SH1ADDW.U SH2ADDW.U SH3ADDW.U ----

	wire            shadd_active   = !{din_instruction_bit30_i, din_instruction_bit27_i, din_instruction_bit26_i, din_instruction_bit25_i} && din_instruction_bit5_i;
	wire [1:0]      shadd_shamt    = {din_instruction_bit14_i, din_instruction_bit13_i};
	wire [XLEN-1:0] shadd_tmp      = (din_instruction_bit3_i ? din_value1_i[31:0]       : din_value1_i) << shadd_shamt;
	wire [XLEN-1:0] shadd_out      = shadd_active            ? shadd_tmp + din_value2_i : 0;


	// ---- ADDIW ADDWU SUBWU ADDUW SUBUW ----

	wire            wuw_active = (XLEN == 64) && (!din_instruction_bit5_i || (din_instruction_bit3_i && !din_instruction_bit14_i && din_instruction_bit27_i));

	wire            wuw_sub    = din_instruction_bit30_i && din_instruction_bit5_i;
	wire            wuw_wu     = !din_instruction_bit5_i || din_instruction_bit25_i;

	wire [XLEN-1:0] wuw_arg    = wuw_wu ? din_value2_i : din_value2_i[31:0];
	wire [XLEN-1:0] wuw_sum    = din_value1_i + (wuw_arg ^ {XLEN{wuw_sub}}) + wuw_sub;
	wire [XLEN-1:0] wuw_out    = wuw_wu ? wuw_sum[31:0] : wuw_sum;

	wire [XLEN-1:0] wuw_dout = wuw_active ? wuw_out : 0;


	// ---- MIN MAX MINU MAXU ----

	wire          minmax_active     = !wuw_active && {din_instruction_bit30_i, din_instruction_bit27_i, din_instruction_bit26_i, din_instruction_bit25_i, din_instruction_bit14_i} == 5'b 01011;
	wire [XLEN:0] minmax_a          = {din_instruction_bit13_i ? 1'b0 : din_value1_i[XLEN-1], din_value1_i};
	wire [XLEN:0] minmax_b          = {din_instruction_bit13_i ? 1'b0 : din_value2_i[XLEN-1], din_value2_i};
	wire          minmax_a_larger_b = $signed(minmax_a) > $signed(minmax_b);
	wire          minmax_choose_b   = minmax_a_larger_b ^ din_instruction_bit12_i;

	wire [XLEN-1:0] minmax_dout = minmax_active ? (minmax_choose_b ? din_value2_i : din_value1_i) : 0;


	// ---- ANDN ORN XNOR ----

	wire            logicn_active  = !wuw_active && {din_instruction_bit30_i, din_instruction_bit27_i, din_instruction_bit26_i, din_instruction_bit25_i, din_instruction_bit14_i} == 5'b 10001;

	wire [XLEN-1:0] logicn_dout    = !logicn_active ? 0 : din_instruction_bit12_i ? din_value1_i & ~din_value2_i :
			                                              din_instruction_bit13_i ? din_value1_i | ~din_value2_i : 
			                                              din_value1_i ^ ~din_value2_i;


	// ---- PACK PACKW PACKH PACKU PACKUW ----

	wire pack_active = !wuw_active && {din_instruction_bit27_i, din_instruction_bit26_i, din_instruction_bit25_i, din_instruction_bit14_i} == 4'b 1001;

	wire [31:0] pack_value1 = din_instruction_bit30_i ? ((din_instruction_bit3_i || XLEN == 32) 
	                                                  ? {16'bx, din_value1_i[31:16]} : din_value1_i >> 32) 
	                                                                                 : din_value1_i;
	wire [31:0] pack_value2 = din_instruction_bit30_i ? ((din_instruction_bit3_i || XLEN == 32) 
	                                                  ? {16'bx, din_value2_i[31:16]} : din_value2_i >> 32) 
	                                                                                 : din_value2_i;

	wire [31:0] pack_dout32 = {pack_value2[15:0], pack_value1[15:0]};
	wire [63:0] pack_dout64 = {pack_value2[31:0], pack_value1[31:0]};

	wire [XLEN-1:0] pack_dout = !pack_active ? 0 : din_instruction_bit13_i ? {din_value2_i[7:0], din_value1_i[7:0]} :
			                    (din_instruction_bit3_i || XLEN == 32)     ? {{32{pack_dout32[31]}}, pack_dout32}   : pack_dout64;


	// ---- CMIX CMOV ----

	wire            cmixmov_active = !wuw_active && din_instruction_bit26_i;

	wire [XLEN-1:0] cmixmov_dout   = !cmixmov_active ? 0 : din_instruction_bit14_i ? (din_value2_i ? din_value1_i : din_value3_i) 
	                                                     : (din_value1_i & din_value2_i) | (din_value3_i & ~din_value2_i);


	// ---- Output Stage ----

	assign dout_result_o = shadd_out | wuw_dout | minmax_dout | logicn_dout | pack_dout | cmixmov_dout;
endmodule