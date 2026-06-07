`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  sikistirilmis_cozucu  -  RVC (16-bit) -> RV32I (32-bit) genisletici
// ---------------------------------------------------------------------------
//  16-bit sikistirilmis buyrugu esdeger 32-bit RV32I buyruguna acar. Getir
//  asamasinda kullanilir; cikti normal coz asamasina beslenir (coz degismez).
//
//  Kapsam: RV32C tamsayi kumesi.
//    Q0: C.ADDI4SPN, C.LW, C.SW
//    Q1: C.ADDI, C.JAL, C.LI, C.LUI/C.ADDI16SP, C.SRLI/C.SRAI/C.ANDI,
//        C.SUB/C.XOR/C.OR/C.AND, C.J, C.BEQZ, C.BNEZ
//    Q2: C.SLLI, C.LWSP, C.JR/C.MV/C.EBREAK/C.JALR/C.ADD, C.SWSP
//  (F/D yukleri ve RV64 (C.*W) kapsam disi -> gecersiz_o.)
//
//  buyruk_i[1:0] == 2'b11 ise zaten 32-bit -> bu modul cagrilmaz (getir karar verir).
// ===========================================================================

module sikistirilmis_cozucu (
   input  [15:0] c_i,             // 16-bit sikistirilmis buyruk
   output reg [31:0] buyruk_o,    // genisletilmis 32-bit RV32I buyrugu
   output reg        gecersiz_o   // tanimsiz/desteklenmeyen sikistirilmis buyruk
);

   // 7-bit opcode'lar
   localparam [6:0] OPIMM = 7'b0010011, OP = 7'b0110011, LUI = 7'b0110111,
                    LOAD = 7'b0000011, STORE = 7'b0100011, JAL = 7'b1101111,
                    JALR = 7'b1100111, BRANCH = 7'b1100011, SYSTEM = 7'b1110011;

   wire [1:0] op = c_i[1:0];
   wire [2:0] f3 = c_i[15:13];

   // Tam (5-bit) ve kisitli (x8-x15) yazmac alanlari
   wire [4:0] rd   = c_i[11:7];
   wire [4:0] rs2  = c_i[6:2];
   wire [4:0] rdp  = {2'b01, c_i[4:2]};   // rd'/rs2'
   wire [4:0] rs1p = {2'b01, c_i[9:7]};   // rs1'/rd'
   wire [4:0] shamt= c_i[6:2];

   // Anliklar (32-bit, isaret/sifir genisletilmis)
   wire [31:0] imm_ci   = {{27{c_i[12]}}, c_i[6:2]};                               // CI: sext6
   wire [31:0] imm_lui  = {{15{c_i[12]}}, c_i[6:2], 12'b0};                        // C.LUI
   wire [31:0] imm_a16  = {{23{c_i[12]}}, c_i[4:3], c_i[5], c_i[2], c_i[6], 4'b0}; // C.ADDI16SP
   wire [31:0] imm_a4   = {22'b0, c_i[10:7], c_i[12:11], c_i[5], c_i[6], 2'b0};    // C.ADDI4SPN
   wire [31:0] imm_clw  = {25'b0, c_i[5], c_i[12:10], c_i[6], 2'b0};               // C.LW/C.SW
   wire [31:0] imm_lwsp = {24'b0, c_i[3:2], c_i[12], c_i[6:4], 2'b0};              // C.LWSP
   wire [31:0] imm_swsp = {24'b0, c_i[8:7], c_i[12:9], 2'b0};                      // C.SWSP
   wire [31:0] imm_cj   = {{21{c_i[12]}}, c_i[8], c_i[10:9], c_i[6], c_i[7],
                           c_i[2], c_i[11], c_i[5:3], 1'b0};                       // C.J/C.JAL
   wire [31:0] imm_cb   = {{24{c_i[12]}}, c_i[6:5], c_i[2], c_i[11:10],
                           c_i[4:3], 1'b0};                                        // C.BEQZ/C.BNEZ

   // Buyruk tipi kuruculari (fonksiyon yerine wire kisayollar gerektiginde inline)
   // I-tipi:    {imm[11:0], rs1, f3, rd, opcode}
   // S-tipi:    {imm[11:5], rs2, rs1, f3, imm[4:0], opcode}
   // B-tipi:    {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], opcode}
   // U-tipi:    {imm[31:12], rd, opcode}
   // J-tipi:    {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode}

   always @* begin
      buyruk_o   = 32'h00000013;   // varsayilan: nop (addi x0,x0,0)
      gecersiz_o = 1'b0;

      case (op)
      // ============================ Q0 ============================
      2'b00: case (f3)
         3'b000: begin // C.ADDI4SPN -> addi rd', x2, uimm
            if (imm_a4 == 0) gecersiz_o = 1'b1;   // tum sifir / nzuimm=0 ayrilmis
            else buyruk_o = {imm_a4[11:0], 5'd2, 3'b000, rdp, OPIMM};
         end
         3'b010: // C.LW -> lw rd', off(rs1')
            buyruk_o = {imm_clw[11:0], rs1p, 3'b010, rdp, LOAD};
         3'b110: // C.SW -> sw rs2', off(rs1')
            buyruk_o = {imm_clw[11:5], rdp, rs1p, 3'b010, imm_clw[4:0], STORE};
         default: gecersiz_o = 1'b1;   // C.FLD/FLW/FSD/FSW
      endcase

      // ============================ Q1 ============================
      2'b01: case (f3)
         3'b000: // C.ADDI -> addi rd, rd, imm (rd==0 & imm==0 => nop)
            buyruk_o = {imm_ci[11:0], rd, 3'b000, rd, OPIMM};
         3'b001: // C.JAL -> jal x1, offset
            buyruk_o = {imm_cj[20], imm_cj[10:1], imm_cj[11], imm_cj[19:12], 5'd1, JAL};
         3'b010: // C.LI -> addi rd, x0, imm
            buyruk_o = {imm_ci[11:0], 5'd0, 3'b000, rd, OPIMM};
         3'b011: begin
            if (rd == 5'd2) // C.ADDI16SP -> addi x2, x2, imm
               buyruk_o = {imm_a16[11:0], 5'd2, 3'b000, 5'd2, OPIMM};
            else begin      // C.LUI -> lui rd, imm
               if (imm_lui == 0) gecersiz_o = 1'b1;
               else buyruk_o = {imm_lui[31:12], rd, LUI};
            end
         end
         3'b100: begin // MISC-ALU
            case (c_i[11:10])
            2'b00: // C.SRLI -> srli rd', rd', shamt
               buyruk_o = {7'b0000000, shamt, rs1p, 3'b101, rs1p, OPIMM};
            2'b01: // C.SRAI -> srai rd', rd', shamt
               buyruk_o = {7'b0100000, shamt, rs1p, 3'b101, rs1p, OPIMM};
            2'b10: // C.ANDI -> andi rd', rd', imm
               buyruk_o = {imm_ci[11:0], rs1p, 3'b111, rs1p, OPIMM};
            2'b11: begin
               if (c_i[12] == 1'b0) case (c_i[6:5])
                  2'b00: buyruk_o = {7'b0100000, rdp, rs1p, 3'b000, rs1p, OP}; // C.SUB
                  2'b01: buyruk_o = {7'b0000000, rdp, rs1p, 3'b100, rs1p, OP}; // C.XOR
                  2'b10: buyruk_o = {7'b0000000, rdp, rs1p, 3'b110, rs1p, OP}; // C.OR
                  2'b11: buyruk_o = {7'b0000000, rdp, rs1p, 3'b111, rs1p, OP}; // C.AND
               endcase
               else gecersiz_o = 1'b1;   // C.SUBW/C.ADDW (RV64)
            end
            endcase
         end
         3'b101: // C.J -> jal x0, offset
            buyruk_o = {imm_cj[20], imm_cj[10:1], imm_cj[11], imm_cj[19:12], 5'd0, JAL};
         3'b110: // C.BEQZ -> beq rs1', x0, offset
            buyruk_o = {imm_cb[12], imm_cb[10:5], 5'd0, rs1p, 3'b000, imm_cb[4:1], imm_cb[11], BRANCH};
         3'b111: // C.BNEZ -> bne rs1', x0, offset
            buyruk_o = {imm_cb[12], imm_cb[10:5], 5'd0, rs1p, 3'b001, imm_cb[4:1], imm_cb[11], BRANCH};
      endcase

      // ============================ Q2 ============================
      2'b10: case (f3)
         3'b000: // C.SLLI -> slli rd, rd, shamt
            buyruk_o = {7'b0000000, shamt, rd, 3'b001, rd, OPIMM};
         3'b010: begin // C.LWSP -> lw rd, off(x2)
            if (rd == 5'd0) gecersiz_o = 1'b1;   // rd=0 ayrilmis
            else buyruk_o = {imm_lwsp[11:0], 5'd2, 3'b010, rd, LOAD};
         end
         3'b100: begin // C.JR / C.MV / C.EBREAK / C.JALR / C.ADD
            if (c_i[12] == 1'b0) begin
               if (rs2 == 5'd0) begin // C.JR -> jalr x0, 0(rs1)
                  if (rd == 5'd0) gecersiz_o = 1'b1;   // rs1=0 ayrilmis
                  else buyruk_o = {12'b0, rd, 3'b000, 5'd0, JALR};
               end else            // C.MV -> add rd, x0, rs2
                  buyruk_o = {7'b0000000, rs2, 5'd0, 3'b000, rd, OP};
            end else begin
               if (rs2 == 5'd0) begin
                  if (rd == 5'd0)  // C.EBREAK
                     buyruk_o = 32'h00100073;
                  else             // C.JALR -> jalr x1, 0(rs1)
                     buyruk_o = {12'b0, rd, 3'b000, 5'd1, JALR};
               end else            // C.ADD -> add rd, rd, rs2
                  buyruk_o = {7'b0000000, rs2, rd, 3'b000, rd, OP};
            end
         end
         3'b110: // C.SWSP -> sw rs2, off(x2)
            buyruk_o = {imm_swsp[11:5], rs2, 5'd2, 3'b010, imm_swsp[4:0], STORE};
         default: gecersiz_o = 1'b1;   // C.FLDSP/FLWSP/FSDSP/FSWSP
      endcase

      // op == 2'b11 : zaten 32-bit, bu modul cagrilmamali
      default: gecersiz_o = 1'b1;
      endcase
   end

endmodule
