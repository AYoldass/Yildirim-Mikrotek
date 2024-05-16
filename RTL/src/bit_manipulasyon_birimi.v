`timescale 1ns / 1ps

`include "riscv_controller.vh"

module bit_manipulasyon_birimi#(
	parameter integer XLEN = 32
) (
	// control signals
	input             clk_i,          // positive edge clk_i
	input             rst_i,          // synchronous rst_i

	// data input
	input             din_valid_i,      // input is valid
	output            din_ready_o,      // core accepts input
	output            din_decoded_o,    // core can decode insn
	input  [XLEN-1:0] din_value1_i,        // value of 1st argument
	input  [XLEN-1:0] din_value2_i,        // value of 2nd argument
	input  [XLEN-1:0] din_value3_i,        // value of 3rd argument
	input      [31:0] din_instruction_i,       // value of instruction word

	// data output
	output            dout_valid_o,     // output is valid
	input             dout_ready_i,     // accept output
	output [XLEN-1:0] dout_result_o         // output value

`ifdef RVB_DEBUG
,	output [XLEN-1:0] debug_value2_o,
	output            debug_instruction_bitcnt_o,
	output            debug_instruction_clmul_o,
	output            debug_instruction_crc_o,
	output            debug_instruction_shifter_o,
	output            debug_instruction_simple_o
`endif
);
	wire insn_bitcnt;
	wire insn_clmul;
	wire insn_crc;
	wire insn_shifter;
	wire insn_simple;

	wire [XLEN-1:0] imm    = $signed(din_instruction_i[31:20]);
	wire [XLEN-1:0] value2 = din_instruction_i[5] ? din_value2_i : imm;

`ifdef RVB_DEBUG
	assign debug_value2_o              = value2;
	assign debug_instruction_bitcnt_o  = insn_bitcnt;
	assign debug_instruction_clmul_o   = insn_clmul;
	assign debug_instruction_crc_o     = insn_crc;
	assign debug_instruction_shifter_o = insn_shifter;
	assign debug_instruction_simple_o  = insn_simple;
`endif

	rvb_full_decoder #(.XLEN(XLEN)) decoder (
		.insn        (din_instruction_i    ),
		.insn_bitcnt (insn_bitcnt          ),
		.insn_clmul  (insn_clmul           ),
		.insn_crc    (insn_crc             ),
		.insn_shifter(insn_shifter         ),
		.insn_simple (insn_simple          )
	);

	wire stall;
	assign din_decoded_o = insn_bitcnt || insn_clmul || insn_crc || insn_shifter || insn_simple;
	assign din_ready_o = !rst_i && !stall && din_decoded_o;


	// ---- Input Stage ----

	reg in_bitcnt;
	reg in_clmul;
	reg in_crc;
	reg in_shifter;
	reg in_simple;

	wire in_bitcnt_ready;
	wire in_clmul_ready;
	wire in_crc_ready;
	wire in_shifter_ready;
	wire in_simple_ready;

	reg [XLEN-1:0] in_value1, in_value2, in_value3;
	reg [31:0]     in_instruction;

	always @(posedge clk_i) begin
		if (in_bitcnt_ready ) 
		  in_bitcnt  <= 0;
		if (in_clmul_ready  ) 
		  in_clmul   <= 0;
		if (in_crc_ready    ) 
		  in_crc     <= 0;
		if (in_shifter_ready) 
		  in_shifter <= 0;
		if (in_simple_ready ) 
		  in_simple  <= 0;

		if (din_ready_o && din_valid_i) begin
			in_bitcnt         <=     insn_bitcnt;
			in_clmul          <=     insn_clmul;
			in_crc            <=     insn_crc;
			in_shifter        <=     insn_shifter;
			in_simple         <=     insn_simple;
			in_value1         <=     din_value1_i;
			in_value2         <=     value2;
			in_value3         <=     din_value3_i;
			in_instruction    <=     din_instruction_i;
		end

		if (rst_i) begin
			in_bitcnt  <= 0;
			in_clmul   <= 0;
			in_crc     <= 0;
			in_shifter <= 0;
			in_simple  <= 0;
		end
	end


	// ---- Process Stage ----

	wire [XLEN-1:0] out_bitcnt;
	wire [XLEN-1:0] out_clmul;
	wire [XLEN-1:0] out_crc;
	wire [XLEN-1:0] out_shifter;
	wire [XLEN-1:0] out_simple;

	wire out_bitcnt_valid;
	wire out_clmul_valid;
	wire out_crc_valid;
	wire out_shifter_valid;
	wire out_simple_valid;
	wire out_ready;


	bit_manipulasyon_birim_bitcnt #(
		.XLEN(XLEN),
		.BMAT(1)
	) rvb_bitcnt (
		.clk_i                                (clk_i              ),
		.rst_i                                (rst_i              ),
		.din_valid_i                          (in_bitcnt          ),
		.din_ready_o                          (in_bitcnt_ready    ),
		.din_value1_i                         (in_value1          ),
		.din_instruction_bit3_i               (in_instruction[3]  ),
		.din_instruction_bit20_i              (in_instruction[20] ),
		.din_instruction_bit21_i              (in_instruction[21] ),
		.din_instruction_bit22_i              (in_instruction[22] ),
		.dout_valid_o                         (out_bitcnt_valid   ),
		.dout_ready_i                         (out_ready          ),
		.dout_result_o                        (out_bitcnt         )
	);


	bit_manipulasyon_birimi_zbc #(
		.XLEN(XLEN)
	) rvb_clmul (
		.clk_i                    (clk_i              ),
		.rst_i                    (rst_i              ),
		.din_valid_i              (in_clmul           ),
		.din_ready_o              (in_clmul_ready     ),
		.din_value1_i             (in_value1          ),
		.din_value2_i             (in_value2          ),
		.din_instruction_bit3_i   (in_instruction[3]  ),
		.din_instruction_bit12_i  (in_instruction[12] ),
		.din_instruction_bit13_i  (in_instruction[13] ),
		.dout_valid_o             (out_clmul_valid    ),
		.dout_ready_i             (out_ready          ),
		.dout_result_o            (out_clmul          )
	);

	bit_manipulasyon_birimi_crc #(
		.XLEN(XLEN)
	) rvb_crc (
		.clk_i                    (clk_i              ),
		.rst_i                    (rst_i              ),
		.din_valid_i              (in_crc             ),
		.din_ready_o              (in_crc_ready       ),
		.din_value1_i             (in_value1          ),
		.din_instruction_bit20_i  (in_instruction[20] ),
		.din_instruction_bit21_i  (in_instruction[21] ),
		.din_instruction_bit23_i  (in_instruction[23] ),
		.dout_valid_o             (out_crc_valid      ),
		.dout_ready_i             (out_ready          ),
		.dout_result_o            (out_crc            )
	);

	bit_manipulasyon_birimi_zbs #(
		.XLEN(XLEN),
		.SBOP(1),
		.BFP(1)
	) rvb_shifter (
		.clk_i                    (clk_i              ),
		.rst_i                    (rst_i              ),
		.din_valid_i              (in_shifter         ),
		.din_ready_o              (in_shifter_ready   ),
		.din_value1_i             (in_value1          ),
		.din_value2_i             (in_value2          ),
		.din_value3_i             (in_value3          ),
		.din_instruction_bit3_i   (in_instruction[3]  ),
		.din_instruction_bit13_i  (in_instruction[13] ),
		.din_instruction_bit14_i  (in_instruction[14] ),
		.din_instruction_bit26_i  (in_instruction[26] ),
		.din_instruction_bit27_i  (in_instruction[27] ),
		.din_instruction_bit29_i  (in_instruction[29] ),
		.din_instruction_bit30_i  (in_instruction[30] ),
		.dout_valid_o             (out_shifter_valid  ),
		.dout_ready_i             (out_ready          ),
		.dout_result_o            (out_shifter        )
	);

	bit_manipulasyon_birimi_zba #(
		.XLEN(XLEN)
	) rvb_simple (
		.clk_i                    (clk_i              ),
		.rst_i                    (rst_i              ),
		.din_valid_i              (in_simple          ),
		.din_ready_o              (in_simple_ready    ),
		.din_value1_i             (in_value1          ),
		.din_value2_i             (in_value2          ),
		.din_value3_i             (in_value3          ),
		.din_instruction_bit3_i   (in_instruction[3]  ),
		.din_instruction_bit5_i   (in_instruction[5]  ),
		.din_instruction_bit12_i  (in_instruction[12] ),
		.din_instruction_bit13_i  (in_instruction[13] ),
		.din_instruction_bit14_i  (in_instruction[14] ),
		.din_instruction_bit25_i  (in_instruction[25] ),
		.din_instruction_bit26_i  (in_instruction[26] ),
		.din_instruction_bit27_i  (in_instruction[27] ),
		.din_instruction_bit30_i  (in_instruction[30] ),
		.dout_valid_o             (out_simple_valid   ),
		.dout_ready_i             (out_ready          ),
		.dout_result_o            (out_simple         )
	);


	// ---- Output Stage ----

	reg            output_valid;
	reg [XLEN-1:0] output_value;

	assign out_ready = !dout_valid_o || dout_ready_i;

	always @(posedge clk_i) begin
		if (dout_valid_o && dout_ready_i) begin
			output_valid <= 0;
		end
		if (out_ready) begin
			(* parallel_case *)
			case (1'b1)
				out_bitcnt_valid:  begin output_valid <= 1; 
				                         output_value <= out_bitcnt; 
				                         end
				out_clmul_valid:   begin output_valid <= 1; 
				                         output_value <= out_clmul;   
				                         end
				out_crc_valid:     begin output_valid <= 1; 
				                         output_value <= out_crc;     
				                         end
				out_shifter_valid: begin output_valid <= 1; 
				                         output_value <= out_shifter; 
				                         end
				out_simple_valid:  begin output_valid <= 1; 
				                         output_value <= out_simple;  
				                         end
			endcase
		end
		if (rst_i) begin
			output_valid <= 0;
		end
	end

	assign dout_valid_o = !rst_i && output_valid;
	assign dout_result_o = output_value;


	// ---- Arbiter ----

	reg busy, busy_reg;
	wire out_any_valid = out_bitcnt_valid || out_clmul_valid || out_crc_valid || out_shifter_valid || out_simple_valid;
	assign stall = busy;

	always @* begin
		busy = busy_reg;
		if (in_bitcnt ) 
		  busy = 1;
		if (in_clmul  ) 
		  busy = 1;
		if (in_crc    ) 
		  busy = 1;
		if (in_shifter) 
		  busy = 1;
		if (in_simple ) 
		  busy = 1;
		if (out_ready && out_any_valid) 
		  busy = 0;
		if (rst_i) 
		  busy = 0;
	end

	always @(posedge clk_i) begin
		busy_reg <= busy;
	end
endmodule

module rvb_full_decoder #(
	parameter integer XLEN = 32
) (
	input [31:0] insn,
	output reg insn_bitcnt,
	output reg insn_clmul,
	output reg insn_crc,
	output reg insn_shifter,
	output reg insn_simple
);
	always @* begin
		insn_bitcnt  = 0;
		insn_clmul   = 0;
		insn_crc     = 0;
		insn_shifter = 0;
		insn_simple  = 0;

		(* parallel_case *)
		casez ({insn, XLEN == 64})
			33'b0100000_?????_?????_111_?????_0110011_?: insn_simple = 1;  // ANDN
			33'b0100000_?????_?????_110_?????_0110011_?: insn_simple = 1;  // ORN
			33'b0100000_?????_?????_100_?????_0110011_?: insn_simple = 1;  // XNOR

			33'b0010000_?????_?????_010_?????_0110011_?: insn_simple = 1;  // SH1ADD
			33'b0010000_?????_?????_100_?????_0110011_?: insn_simple = 1;  // SH2ADD
			33'b0010000_?????_?????_110_?????_0110011_?: insn_simple = 1;  // SH3ADD

			33'b0000000_?????_?????_001_?????_0110011_?: insn_shifter = 1; // SLL
			33'b0000000_?????_?????_101_?????_0110011_?: insn_shifter = 1; // SRL
			33'b0100000_?????_?????_101_?????_0110011_?: insn_shifter = 1; // SRA
			33'b0010000_?????_?????_001_?????_0110011_?: insn_shifter = 1; // SLO
			33'b0010000_?????_?????_101_?????_0110011_?: insn_shifter = 1; // SRO
			33'b0110000_?????_?????_001_?????_0110011_?: insn_shifter = 1; // ROL
			33'b0110000_?????_?????_101_?????_0110011_?: insn_shifter = 1; // ROR

			33'b0100100_?????_?????_001_?????_0110011_?: insn_shifter = 1; // SBCLR
			33'b0010100_?????_?????_001_?????_0110011_?: insn_shifter = 1; // SBSET
			33'b0110100_?????_?????_001_?????_0110011_?: insn_shifter = 1; // SBINV
			33'b0100100_?????_?????_101_?????_0110011_?: insn_shifter = 1; // SBEXT


			33'b00000_00?????_?????_001_?????_0010011_0: insn_shifter = 1; // SLLI (RV32)
			33'b00000_00?????_?????_101_?????_0010011_0: insn_shifter = 1; // SRLI (RV32)
			33'b01000_00?????_?????_101_?????_0010011_0: insn_shifter = 1; // SRAI (RV32)
			33'b00100_00?????_?????_001_?????_0010011_0: insn_shifter = 1; // SLOI (RV32)
			33'b00100_00?????_?????_101_?????_0010011_0: insn_shifter = 1; // SROI (RV32)
			33'b01100_00?????_?????_101_?????_0010011_0: insn_shifter = 1; // RORI (RV32)


			33'b01001_00?????_?????_001_?????_0010011_0: insn_shifter = 1; // SBCLRI (RV32)
			33'b00101_00?????_?????_001_?????_0010011_0: insn_shifter = 1; // SBSETI (RV32)
			33'b01101_00?????_?????_001_?????_0010011_0: insn_shifter = 1; // SBINVI (RV32)
			33'b01001_00?????_?????_101_?????_0010011_0: insn_shifter = 1; // SBEXTI (RV32)


			33'b01001_0??????_?????_001_?????_0010011_1: insn_shifter = 1; // SBCLRI (RV64)
			33'b00101_0??????_?????_001_?????_0010011_1: insn_shifter = 1; // SBSETI (RV64)
			33'b01101_0??????_?????_001_?????_0010011_1: insn_shifter = 1; // SBINVI (RV64)
			33'b01001_0??????_?????_101_?????_0010011_1: insn_shifter = 1; // SBEXTI (RV64)
			33'b00101_0??????_?????_101_?????_0010011_1: insn_shifter = 1; // GORCI (RV64)
			33'b01101_0??????_?????_101_?????_0010011_1: insn_shifter = 1; // GREVI (RV64)

			33'b?????11_?????_?????_001_?????_0110011_?: insn_simple  = 1; // CMIX
			33'b?????11_?????_?????_101_?????_0110011_?: insn_simple  = 1; // CMOV
			33'b?????10_?????_?????_001_?????_0110011_?: insn_shifter = 1; // FSL
			33'b?????10_?????_?????_101_?????_0110011_?: insn_shifter = 1; // FSR
			33'b?????1_0?????_?????_101_?????_0010011_0: insn_shifter = 1; // FSRI (RV32)
			33'b?????1_??????_?????_101_?????_0010011_1: insn_shifter = 1; // FSRI (RV64)

			33'b0110000_00000_?????_001_?????_0010011_?: insn_bitcnt  = 1; // CLZ
			33'b0110000_00001_?????_001_?????_0010011_?: insn_bitcnt  = 1; // CTZ
			33'b0110000_00010_?????_001_?????_0010011_?: insn_bitcnt  = 1; // PCNT
			33'b0110000_00011_?????_001_?????_0010011_1: insn_bitcnt  = 1; // BMATFLIP
			33'b0110000_00100_?????_001_?????_0010011_?: insn_bitcnt  = 1; // SEXT.B
			33'b0110000_00101_?????_001_?????_0010011_?: insn_bitcnt  = 1; // SEXT.H

			33'b0110000_10000_?????_001_?????_0010011_?: insn_crc     = 1; // CRC32.B
			33'b0110000_10001_?????_001_?????_0010011_?: insn_crc     = 1; // CRC32.H
			33'b0110000_10010_?????_001_?????_0010011_?: insn_crc     = 1; // CRC32.W
			33'b0110000_10011_?????_001_?????_0010011_?: insn_crc     = 1; // CRC32.D
			33'b0110000_11000_?????_001_?????_0010011_?: insn_crc     = 1; // CRC32C.B
			33'b0110000_11001_?????_001_?????_0010011_?: insn_crc     = 1; // CRC32C.H
			33'b0110000_11010_?????_001_?????_0010011_?: insn_crc     = 1; // CRC32C.W
			33'b0110000_11011_?????_001_?????_0010011_?: insn_crc     = 1; // CRC32C.D

			33'b0000101_?????_?????_001_?????_0110011_?: insn_clmul   = 1; // CLMUL
			33'b0000101_?????_?????_010_?????_0110011_?: insn_clmul   = 1; // CLMULR
			33'b0000101_?????_?????_011_?????_0110011_?: insn_clmul   = 1; // CLMULH
			33'b0000101_?????_?????_100_?????_0110011_?: insn_simple  = 1; // MIN
			33'b0000101_?????_?????_101_?????_0110011_?: insn_simple  = 1; // MAX
			33'b0000101_?????_?????_110_?????_0110011_?: insn_simple  = 1; // MINU
			33'b0000101_?????_?????_111_?????_0110011_?: insn_simple  = 1; // MAXU


			33'b0000100_?????_?????_100_?????_0110011_?: insn_simple  = 1; // PACK
			33'b0100100_?????_?????_100_?????_0110011_?: insn_simple  = 1; // PACKU
			33'b0000100_?????_?????_111_?????_0110011_?: insn_simple  = 1; // PACKH

			33'b0100100_?????_?????_111_?????_0110011_?: insn_shifter = 1; // BFP


			33'b???????_?????_?????_100_?????_0011011_1: insn_simple  = 1; // ADDIWU
			33'b000010_??????_?????_001_?????_0011011_1: insn_shifter = 1; // SLLIU.W

			33'b0000101_?????_?????_000_?????_0111011_1: insn_simple  = 1; // ADDWU
			33'b0100101_?????_?????_000_?????_0111011_1: insn_simple  = 1; // SUBWU
			33'b0000100_?????_?????_000_?????_0111011_1: insn_simple  = 1; // ADDUW
			33'b0100100_?????_?????_000_?????_0111011_1: insn_simple  = 1; // SUBUW

			33'b0010000_?????_?????_010_?????_0111011_1: insn_simple = 1;  // SH1ADDU.W
			33'b0010000_?????_?????_100_?????_0111011_1: insn_simple = 1;  // SH2ADDU.W
			33'b0010000_?????_?????_110_?????_0111011_1: insn_simple = 1;  // SH3ADDU.W

			33'b0000000_?????_?????_001_?????_0111011_1: insn_shifter = 1; // SLLW
			33'b0000000_?????_?????_101_?????_0111011_1: insn_shifter = 1; // SRLW
			33'b0100000_?????_?????_101_?????_0111011_1: insn_shifter = 1; // SRAW
			33'b0010000_?????_?????_001_?????_0111011_1: insn_shifter = 1; // SLOW
			33'b0010000_?????_?????_101_?????_0111011_1: insn_shifter = 1; // SROW
			33'b0110000_?????_?????_001_?????_0111011_1: insn_shifter = 1; // ROLW
			33'b0110000_?????_?????_101_?????_0111011_1: insn_shifter = 1; // RORW

			33'b0100100_?????_?????_001_?????_0111011_1: insn_shifter = 1; // SBCLRW
			33'b0010100_?????_?????_001_?????_0111011_1: insn_shifter = 1; // SBSETW
			33'b0110100_?????_?????_001_?????_0111011_1: insn_shifter = 1; // SBINVW
			33'b0100100_?????_?????_101_?????_0111011_1: insn_shifter = 1; // SBEXTW


			33'b00000_00?????_?????_001_?????_0011011_1: insn_shifter = 1; // SLLIW
			33'b00000_00?????_?????_101_?????_0011011_1: insn_shifter = 1; // SRLIW
			33'b01000_00?????_?????_101_?????_0011011_1: insn_shifter = 1; // SRAIW
			33'b00100_00?????_?????_001_?????_0011011_1: insn_shifter = 1; // SLOIW
			33'b00100_00?????_?????_101_?????_0011011_1: insn_shifter = 1; // SROIW
			33'b01100_00?????_?????_101_?????_0011011_1: insn_shifter = 1; // RORIW

			33'b01001_00?????_?????_001_?????_0011011_1: insn_shifter = 1; // SBCLRIW
			33'b00101_00?????_?????_001_?????_0011011_1: insn_shifter = 1; // SBSETIW
			33'b01101_00?????_?????_001_?????_0011011_1: insn_shifter = 1; // SBINVIW


			33'b?????10_?????_?????_001_?????_0111011_1: insn_shifter = 1; // FSLW
			33'b?????10_?????_?????_101_?????_0111011_1: insn_shifter = 1; // FSRW
			33'b?????1_0?????_?????_101_?????_0011011_1: insn_shifter = 1; // FSRIW

			33'b0110000_00000_?????_001_?????_0011011_1: insn_bitcnt  = 1; // CLZW
			33'b0110000_00001_?????_001_?????_0011011_1: insn_bitcnt  = 1; // CTZW
			33'b0110000_00010_?????_001_?????_0011011_1: insn_bitcnt  = 1; // PCNTW

			33'b0000101_?????_?????_001_?????_0111011_1: insn_clmul   = 1; // CLMULW
			33'b0000101_?????_?????_010_?????_0111011_1: insn_clmul   = 1; // CLMULRW
			33'b0000101_?????_?????_011_?????_0111011_1: insn_clmul   = 1; // CLMULHW


			33'b0000100_?????_?????_100_?????_0111011_1: insn_simple  = 1; // PACKW
			33'b0100100_?????_?????_100_?????_0111011_1: insn_simple  = 1; // PACKUW
			33'b0100100_?????_?????_111_?????_0111011_1: insn_shifter = 1; // BFPW
		endcase
	end
endmodule