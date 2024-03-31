`timescale 1ns / 1ps

module bit_manupulasyon_birimi_zbs #(
	parameter integer XLEN = 32,
	parameter [0:0] SBOP = 1,
	parameter [0:0] BFP = 1
) (
	// control signals
	input             clk_i,          // positive edge clk_i
	input             rst_i,          // synchronous rst_i

	// data input
	input             din_valid_i,      // input is valid
	output            din_ready_o,      // core accepts input
	input  [XLEN-1:0] din_value1_i,        // value of 1st argument
	input  [XLEN-1:0] din_value2_i,        // value of 2nd argument
	input  [XLEN-1:0] din_value3_i,        // value of 3rd argument
	input             din_instruction_bit3_i,      // value of instruction bit 3
	input             din_instruction_bit13_i,     // value of instruction bit 13
	input             din_instruction_bit14_i,     // value of instruction bit 14
	input             din_instruction_bit26_i,     // value of instruction bit 26
	input             din_instruction_bit27_i,     // value of instruction bit 27
	input             din_instruction_bit29_i,     // value of instruction bit 29
	input             din_instruction_bit30_i,     // value of instruction bit 30

	// data output
	output            dout_valid_o,     // output is valid
	input             dout_ready_i,     // accept output
	output [XLEN-1:0] dout_result_o         // output value
);
	// 30 29 27 26 14 13  3   Function
	// --------------------   --------
	//  0  0  0  0  0  0  W   SLL
	//  0  0  0  0  1  0  W   SRL
	//  1  0  0  0  1  0  W   SRA
	//  0  1  0  0  0  0  W   SLO
	//  0  1  0  0  1  0  W   SRO
	//  1  1  0  0  0  0  W   ROL
	//  1  1  0  0  1  0  W   ROR
	// --------------------   --------
	//  0  0  1  0  0  0  1   SLLIU.W
	// --------------------   --------
	//  -  -  -  1  0  0  W   FSL
	//  -  -  -  1  1  0  W   FSR
	// --------------------   --------
	//  0  1  1  0  0  0  W   SBSET
	//  1  0  1  0  0  0  W   SBCLR
	//  1  1  1  0  0  0  W   SBINV
	//  1  0  1  0  1  0  W   SBEXT
	// --------------------   --------
	//  1  0  1  0  1  1  W   BFP

	assign dout_valid_o = din_valid_i;
	assign din_ready_o = dout_ready_i;

	wire slliumode = (XLEN == 64) && !din_instruction_bit30_i && !din_instruction_bit29_i && din_instruction_bit27_i && !din_instruction_bit26_i && !din_instruction_bit14_i;
	wire wmode = (XLEN == 32) || (din_instruction_bit3_i && !slliumode);
	wire sbmode = SBOP && (din_instruction_bit30_i || din_instruction_bit29_i) && din_instruction_bit27_i && !din_instruction_bit26_i;
	wire bfpmode = BFP && din_instruction_bit13_i;

	reg [63:0] Y;
	wire [63:0] A, B, X;
	assign A = slliumode ? din_value1_i[31:0] : din_value1_i, B = din_value3_i;
	assign dout_result_o = wmode ? {{32{Y[31]}}, Y[31:0]} : Y;

	reg [63:0] aa, bb;
	reg [6:0] shamt;

	wire [15:0] bfp_config_hi = din_value2_i >> 48, bfp_config_lo = din_value2_i >> 32;
	wire [15:0] bfp_config = wmode ? din_value2_i[31:16] : bfp_config_hi[15:14] == 2 ? bfp_config_hi : bfp_config_lo;

	wire [5:0] bfp_len = wmode ? {!bfp_config[11:8], bfp_config[11:8]} : {!bfp_config[12:8], bfp_config[12:8]};
	wire [5:0] bfp_off = wmode ? bfp_config[4:0] : bfp_config[5:0];
	wire [31:0] bfp_mask = 32'h FFFFFFFF << bfp_len;

	always @* begin
		shamt = din_value2_i;
		aa = A;
		bb = B;

		if (wmode || !din_instruction_bit26_i)
			shamt[6] = 0;

		if (wmode && !din_instruction_bit26_i)
			shamt[5] = 0;

		if (din_instruction_bit14_i)
			shamt = -shamt;

		if (!din_instruction_bit26_i) begin
			casez ({din_instruction_bit30_i, din_instruction_bit29_i})
				2'b 0z: bb = {64{din_instruction_bit29_i}};
				2'b 10: bb = {64{wmode ? A[31] : A[63]}};
				2'b 11: bb = A;
			endcase
			if (sbmode && !din_instruction_bit14_i) begin
				aa = 1;
				bb = 0;
			end
		end

		if (bfpmode) begin
			aa = {32'h 0000_0000, ~bfp_mask};
			bb = 0;
			shamt = bfp_off;
		end
	end

	always @* begin
		Y = X;
		if (sbmode) begin
			casez ({din_instruction_bit30_i, din_instruction_bit29_i, din_instruction_bit14_i})
				3'b zz1: Y = 1 &  X;
				3'b 0zz: Y = A |  X;
				3'b z0z: Y = A & ~X;
				3'b 11z: Y = A ^  X;
			endcase
		end
		if (bfpmode)
			Y = (A & ~X) | {32'b0, din_value2_i[31:0] & ~bfp_mask} << bfp_off;
	end

	rvb_shifter_datapath #(
		.XLEN(XLEN)
	) datapath (
		.A     (aa   ),
		.B     (bb   ),
		.X     (X    ),
		.shamt (shamt),
		.wmode (wmode)
	);
endmodule

module rvb_shifter_datapath #(
	parameter integer XLEN = 64
) (
	input  [63:0] A, B,
	output [63:0] X,
	input  [ 6:0] shamt,
	input         wmode
);
	reg [127:0] tmp;

	always @* begin
		tmp = {B, A};

		tmp = {
			(wmode ? 0 : shamt[5]) ? tmp[127:96] : tmp[ 31: 0],
			(wmode ? 1 : shamt[5]) ? tmp[ 31: 0] : tmp[ 63:32],
			(wmode ? 0 : shamt[5]) ? tmp[ 63:32] : tmp[ 95:64],
			(wmode ? 1 : shamt[5]) ? tmp[ 95:64] : tmp[127:96]
		};

		tmp = {
			(wmode ?  shamt[5] : shamt[6]) ? tmp[ 95:64] : tmp[ 31: 0],
			(wmode ? !shamt[5] : shamt[6]) ? tmp[127:96] : tmp[ 63:32],
			(wmode ? !shamt[5] : shamt[6]) ? tmp[ 31: 0] : tmp[ 95:64],
			(wmode ?  shamt[5] : shamt[6]) ? tmp[ 63:32] : tmp[127:96]
		};

		tmp = shamt[4] ? {tmp[111:0], tmp[127:112]} : tmp;
		tmp = shamt[3] ? {tmp[119:0], tmp[127:120]} : tmp;
		tmp = shamt[2] ? {tmp[123:0], tmp[127:124]} : tmp;
		tmp = shamt[1] ? {tmp[125:0], tmp[127:126]} : tmp;
		tmp = shamt[0] ? {tmp[126:0], tmp[127:127]} : tmp;

		if (XLEN == 32) begin
			tmp = {64'bx, B[31:0], A[31:0]};
			tmp[63:0] = shamt[5] ? {tmp[31:0], tmp[63:32]} : tmp[63:0];
			tmp[63:0] = shamt[4] ? {tmp[47:0], tmp[63:48]} : tmp[63:0];
			tmp[63:0] = shamt[3] ? {tmp[55:0], tmp[63:56]} : tmp[63:0];
			tmp[63:0] = shamt[2] ? {tmp[59:0], tmp[63:60]} : tmp[63:0];
			tmp[63:0] = shamt[1] ? {tmp[61:0], tmp[63:62]} : tmp[63:0];
			tmp[63:0] = shamt[0] ? {tmp[62:0], tmp[63:63]} : tmp[63:0];
		end
	end

	assign X = (XLEN == 32) ? {32'bx, tmp[31:0]} : tmp[63:0];
endmodule