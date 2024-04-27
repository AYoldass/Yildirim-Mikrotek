`timescale 1ns / 1ps

`include "riscv_controller.vh"

module bit_manipulasyon_birimi_zbb(
    // control signals
	input             clk_i,               // positive edge clk_i
	input             rst_i,               // synchronous rst_i

	// data input
	input             din_valid_i,         // input is valid
	output            din_ready_o,         // core accepts input
	output            din_decoded_o,       // core can decode insn
	input      [31:0] din_value1_i,        // value of 1st argument
	input      [31:0] din_value2_i,        // value of 2nd argument
	input      [31:0] din_instruction_i,   // value of instruction word

	// data output
	output            dout_valid_o,        // output is valid
	input             dout_ready_i,        // accept output
	output     [31:0] dout_result_o        // output value
);

//Bu çýkýþlar, belirli bit manipülasyon komutlarýnýn aktif olup olmadýðýný gösterir. 
//Her biri, karþýlýk gelen iþlem türü için bir sinyaldir ve talimatýn o iþlemi gerektirip gerektirmediðini belirtir.
	wire instruction_bitcnt;
	wire instruction_minmax;
	wire instruction_shift;
	wire instruction_opneg;
	wire instruction_pack;

	integer i;
	reg [31:0] dout_bitcnt = 0;
	reg [31:0] dout_minmax = 0;
	reg [31:0] dout_shift = 0;
	reg [31:0] dout_opneg = 0;
	reg [31:0] dout_pack = 0;

	assign dout_valid_o = din_valid_i  && !rst_i;
	assign din_ready_o  = dout_ready_i && !rst_i;

	assign din_decoded_o = |{instruction_bitcnt, instruction_minmax, instruction_shift, instruction_opneg, instruction_pack};

	assign dout_result_o = instruction_bitcnt ? dout_bitcnt : instruction_minmax ? dout_minmax :
			               instruction_shift  ? dout_shift  : instruction_opneg  ? dout_opneg  : dout_pack;

	bit_manipulasyon_birimi_zbb_cozucu decoder (
	
		.instruction         (din_instruction_i   ),
		.instruction_bitcnt  (instruction_bitcnt  ),
		.instruction_minmax  (instruction_minmax  ),
		.instruction_shift   (instruction_shift   ),
		.instruction_opneg   (instruction_opneg   ),
		.instruction_pack    (instruction_pack    )
		
	);

//din_value1_i giriþ argümanýnýn bit düzeyinde ters çevrilmesi (bit reversal) için kullanýlýyor.
//Bu iþlem genellikle bit düzeyinde manipülasyonlar ve bazý özel hesaplamalarda kullanýlýr.
	reg [31:0] din_rev;

	always @* begin
		din_rev = din_value1_i;
		din_rev = ((din_rev & 32'h55555555) <<  1) | ((din_rev & 32'hAAAAAAAA) >>  1);
		din_rev = ((din_rev & 32'h33333333) <<  2) | ((din_rev & 32'hCCCCCCCC) >>  2);
		din_rev = ((din_rev & 32'h0F0F0F0F) <<  4) | ((din_rev & 32'hF0F0F0F0) >>  4);
		din_rev = ((din_rev & 32'h00FF00FF) <<  8) | ((din_rev & 32'hFF00FF00) >>  8);
		din_rev = ((din_rev & 32'h0000FFFF) << 16) | ((din_rev & 32'hFFFF0000) >> 16);
	end


	wire bitcnt_ctz  = din_instruction_i[20];
	wire bitcnt_pcnt = din_instruction_i[21];

	wire [31:0] bitcnt_data = bitcnt_ctz  ? din_value1_i :  din_rev;
	wire [31:0] bitcnt_bits = bitcnt_pcnt ? bitcnt_data  : (bitcnt_data-1) & ~bitcnt_data;

	always @* begin
		dout_bitcnt = 0;
		for (i = 0; i < 32; i=i+1)
			dout_bitcnt[5:0] = dout_bitcnt[5:0] + bitcnt_bits[i];
	end


	wire value1_msb = !din_instruction_i[13] && din_value1_i[31];
	wire value2_msb = !din_instruction_i[13] && din_value2_i[31];
	wire minmax_lt  = $signed({value1_msb, din_value1_i}) < $signed({value2_msb, din_value2_i});//minmax_lt deðiþkeni, "minimum" ve "maksimum" iþlemleri için karþýlaþtýrma sonucunu belirlemek amacýyla kullanýlýr. 

	always @* begin
		dout_minmax = (din_instruction_i[12] ^ minmax_lt) ? din_value1_i : din_value2_i;
	end


	wire [4:0] shamt = din_instruction_i[5] ? din_value2_i : din_instruction_i[24:20];

	wire shift_left  = !din_instruction_i[14] && !din_instruction_i[27];
	wire shift_ones  = din_instruction_i[30:29] == 2'b01;
	wire shift_arithmetic = din_instruction_i[30:29] == 2'b10;
	wire shift_rot   = din_instruction_i[30:29] == 2'b11;
	wire shift_none  = din_instruction_i[27];

	wire shift_op_rev   = din_instruction_i[27] && shamt[3:2] == 2'b11;
	wire shift_op_rev8  = din_instruction_i[27] && shamt[3:2] == 2'b10;
	wire shift_op_orc_b = din_instruction_i[27] && shamt[3:2] == 2'b01;

	always @* begin
		dout_shift = din_value1_i;

		if (shift_op_rev || shift_left) begin
			dout_shift = din_rev;
		end

		if (!shift_none) begin
			dout_shift = {shift_rot ? dout_shift : {32{shift_ones || (shift_arithmetic && din_value1_i[31])}}, dout_shift} >> shamt;
		end

		if (shift_op_orc_b || shift_left) begin
			dout_shift = (shift_op_orc_b ? dout_shift : 32'h0) | ((dout_shift & 32'h55555555) <<  1) | ((dout_shift & 32'hAAAAAAAA) >>  1);
			dout_shift = (shift_op_orc_b ? dout_shift : 32'h0) | ((dout_shift & 32'h33333333) <<  2) | ((dout_shift & 32'hCCCCCCCC) >>  2);
			dout_shift = (shift_op_orc_b ? dout_shift : 32'h0) | ((dout_shift & 32'h0F0F0F0F) <<  4) | ((dout_shift & 32'hF0F0F0F0) >>  4);
		end

		if (shift_op_rev8 || shift_left) begin
			dout_shift = ((dout_shift & 32'h00FF00FF) <<  8) | ((dout_shift & 32'hFF00FF00) >>  8);
			dout_shift = ((dout_shift & 32'h0000FFFF) << 16) | ((dout_shift & 32'hFFFF0000) >> 16);
		end
	end


	always @* begin
		dout_opneg = din_value1_i ^ ~din_value2_i;
		if (din_instruction_i[13]) dout_opneg = din_value1_i | ~din_value2_i;
		if (din_instruction_i[12]) dout_opneg = din_value1_i & ~din_value2_i;
	end


	always @* begin
		dout_pack = {din_value2_i[15:0], din_value1_i[15:0]};
	end
endmodule

module bit_manipulasyon_birimi_zbb_cozucu (
	input [31:0] instruction,
	output reg instruction_bitcnt,
	output reg instruction_minmax,
	output reg instruction_shift,
	output reg instruction_opneg,
	output reg instruction_pack
);
	always @* begin
		instruction_bitcnt = 0;
		instruction_minmax = 0;
		instruction_shift  = 0;
		instruction_opneg  = 0;
		instruction_pack   = 0;

		(* parallel_case *)
		casez (instruction)
			32'b0100000_?????_?????_111_?????_0110011: instruction_opneg = 1;  // ANDN
			32'b0100000_?????_?????_110_?????_0110011: instruction_opneg = 1;  // ORN
			32'b0100000_?????_?????_100_?????_0110011: instruction_opneg = 1;  // XNOR

			32'b0000000_?????_?????_001_?????_0110011: instruction_shift = 1; // SLL
			32'b0000000_?????_?????_101_?????_0110011: instruction_shift = 1; // SRL
			32'b0100000_?????_?????_101_?????_0110011: instruction_shift = 1; // SRA
			32'b0010000_?????_?????_001_?????_0110011: instruction_shift = 1; // SLO
			32'b0010000_?????_?????_101_?????_0110011: instruction_shift = 1; // SRO
			32'b0110000_?????_?????_001_?????_0110011: instruction_shift = 1; // ROL
			32'b0110000_?????_?????_101_?????_0110011: instruction_shift = 1; // ROR

			32'b00000_00?????_?????_001_?????_0010011: instruction_shift = 1; // SLLI
			32'b00000_00?????_?????_101_?????_0010011: instruction_shift = 1; // SRLI
			32'b01000_00?????_?????_101_?????_0010011: instruction_shift = 1; // SRAI
			32'b00100_00?????_?????_001_?????_0010011: instruction_shift = 1; // SLOI
			32'b00100_00?????_?????_101_?????_0010011: instruction_shift = 1; // SROI
			32'b01100_00?????_?????_101_?????_0010011: instruction_shift = 1; // RORI

			32'b01101_0011111_?????_101_?????_0010011: instruction_shift = 1; // REV
			32'b01101_0011000_?????_101_?????_0010011: instruction_shift = 1; // REV8
			32'b00101_0000111_?????_101_?????_0010011: instruction_shift = 1; // ORC.B

			32'b0110000_00000_?????_001_?????_0010011: instruction_bitcnt  = 1; // CLZ
			32'b0110000_00001_?????_001_?????_0010011: instruction_bitcnt  = 1; // CTZ
			32'b0110000_00010_?????_001_?????_0010011: instruction_bitcnt  = 1; // PCNT

			32'b0000101_?????_?????_100_?????_0110011: instruction_minmax  = 1; // MIN
			32'b0000101_?????_?????_101_?????_0110011: instruction_minmax  = 1; // MAX
			32'b0000101_?????_?????_110_?????_0110011: instruction_minmax  = 1; // MINU
			32'b0000101_?????_?????_111_?????_0110011: instruction_minmax  = 1; // MAXU

			32'b0000100_?????_?????_100_?????_0110011: instruction_pack  = 1; // PACK
		endcase
	end
endmodule
