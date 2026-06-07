`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  coz_asamasi  -  Coz (Decode) + Yazmac Oku Asamasi  (saf cozme)
// ---------------------------------------------------------------------------
//  Getir alt sisteminden gelen (buyruk, PS) cifti cozulur (sema B: header'daki
//  bit-alanli 28-bit mikroislem), DISARIDAKI yazmac obeginden okunan rs1/rs2
//  degerleriyle operandlar olusturulur, anlik (imm) uretilir ve coz->yurut
//  ardisik duzen kaydina yazilir.
//
//  Yazmac obegi (scoreboard RF) bu modulun DISINDA (ust seviyede) durur; cunku
//  RF hem coz (okuma) hem geri-yazma (yazma) tarafindan paylasilir ve hazard
//  kilidi (scoreboard) writeback ile birlikte calismalidir.
//
//  Tehlike (hazard) kancalari:
//    - oku_adres1/2_o : RF okuma adresleri
//    - rs1/rs2_kullanilir_o : bu buyruk ilgili kaynagi gercekten okuyor mu
//      (ust seviye, RF gecerli-bitiyle birlikte durdur_i uretir)
//    - rezerve_* : yazma yapan buyruk yayinlanirken rd'yi RF'de rezerve eder
//      (etiket atar, gecerli-biti dusurur). yurut_etiket_o ile yuruyen etiket
//      writeback'te eslestirme icin kullanilir.
//
//  MIKROISLEM (sema B) alanlari: GERIYAZ 1:0 | YAZMAC 2 | OPERAND 4:3 |
//     BIRIM 7:5 | DAL 10:8 | ALU 14:11 | BOLME 16:15 | CARPMA 18:17 | BIB 21:19
//
//  OPERAND: REG(00) IMM(01) PC(10) PCIMM(11)  ->  bit1: op1=PS, bit0: op2=imm
//
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module coz_asamasi (
   input                          clk_i,
   input                          rst_i,

   // --- Getir alt sisteminden ---
   input   [31:0]                 coz_buyruk_i,
   input   [31:0]                 coz_buyruk_ps_i,
   input                          coz_buyruk_gecerli_i,
   input                          coz_buyruk_atladi_i,
   input                          coz_buyruk_rvc_i,

   // --- Yazmac obegi okuma arayuzu (ust seviyedeki RF'ye) ---
   output  [4:0]                  oku_adres1_o,
   output  [4:0]                  oku_adres2_o,
   input   [31:0]                 rs1_deger_i,
   input   [31:0]                 rs2_deger_i,

   // --- Kayan nokta (F) yazmac obegi okuma ---
   output  [4:0]                  f_oku1_o,
   output  [4:0]                  f_oku2_o,
   input   [31:0]                 frs1_deger_i,
   input   [31:0]                 frs2_deger_i,

   // --- Tehlike (hazard) bilgisi ---
   output                         rs1_kullanilir_o,
   output                         rs2_kullanilir_o,
   output                         f_rs1_kullanilir_o,
   output                         f_rs2_kullanilir_o,

   // --- rd rezervasyonu (tamsayi RF etiket portuna) ---
   output  [4:0]                  rezerve_adres_o,
   output  [3:0]                  rezerve_etiket_o,
   output                         rezerve_gecerli_o,

   // --- f[rd] rezervasyonu (F RF etiket portuna) ---
   output  [4:0]                  f_rezerve_adres_o,
   output  [3:0]                  f_rezerve_etiket_o,
   output                         f_rezerve_gecerli_o,

   // --- Ardisik duzen kontrolu ---
   input                          durdur_i,    // bu asamayi duraklat (kabarcik gonder)
   input                          dondur_i,    // YURUT'u dondur (y_* tutulur; bellek beklemesi)
   input                          bosalt_i,    // bu asamayi bosalt (kabarcik)

   // --- Yurut asamasina giden (kayitli) cikislar ---
   output reg [31:0]              yurut_ps_o,
   output reg [31:0]              yurut_deger1_o,
   output reg [31:0]              yurut_deger2_o,
   output reg [31:0]              yurut_rs2_deger_o,
   output reg [31:0]              yurut_imm_o,
   output reg [`MI_BIT-1:0]       yurut_mikroislem_o,
   output reg [4:0]               yurut_rd_adres_o,
   output reg [4:0]               yurut_rs1_adres_o,
   output reg [4:0]               yurut_rs2_adres_o,
   output reg [3:0]               yurut_etiket_o,
   output reg [31:0]              yurut_buyruk_o,
   output reg [31:0]              yurut_fdeger1_o,
   output reg [31:0]              yurut_fdeger2_o,
   output reg                     yurut_gecerli_o,
   output reg                     yurut_atladi_o,
   output reg                     yurut_rvc_o
);

   // ---------------- Buyruk alanlari ----------------
   wire [4:0] opcode = coz_buyruk_i[6:2];
   wire [2:0] funct3 = coz_buyruk_i[14:12];
   wire       bit30  = coz_buyruk_i[30];
   wire       bit25  = coz_buyruk_i[25];
   wire [6:0] funct7 = coz_buyruk_i[31:25];
   wire [4:0] rs2f   = coz_buyruk_i[24:20];   // OP-IMM B icin alt-kod

   // ---------------- Bit-manipulasyon (B) tespiti (desteklenen alt-kume) ----
   //  YALNIZCA bit_manipulasyon_birimi'nin cozdugu kodlamalar yonlendirilmeli
   //  (cozulemeyen bir buyruk yonlendirilirse birim el-sikismaz -> ardisik duzen kilitlenir).
   wire b_rtype = (opcode == `OPCODE_RTYPE) && (
        (funct7 == 7'b0100000 && (funct3==3'b111 || funct3==3'b110 || funct3==3'b100)) || // ANDN/ORN/XNOR
        (funct7 == 7'b0000101 &&  funct3 != 3'b000) ||                                     // MIN/MAX/U, CLMUL*
        (funct7 == 7'b0010000 && (funct3==3'b010 || funct3==3'b100 || funct3==3'b110)) ||  // SH1/2/3ADD
        (funct7 == 7'b0110000 && (funct3==3'b001 || funct3==3'b101)) );                    // ROL/ROR
   wire b_itype = (opcode == `OPCODE_ITYPE) && (
        (funct7 == 7'b0110000 && funct3==3'b101) ||                                        // RORI
        (funct7 == 7'b0110000 && funct3==3'b001 &&                                         // CLZ/CTZ/CPOP/SEXT.B/H
            (rs2f==5'b00000 || rs2f==5'b00001 || rs2f==5'b00010 ||
             rs2f==5'b00100 || rs2f==5'b00101)) );
   wire b_instr = b_rtype || b_itype;

   // ---------------- Kayan nokta (F) siniflandirmasi ----------------
   wire is_flw = (opcode == `OPCODE_FPU_LW);
   wire is_fsw = (opcode == `OPCODE_FPU_SW);
   wire is_fpu = (opcode == `OPCODE_FPU);
   // FPU sonucu tamsayi RF'ye mi? (FEQ/FLT/FLE, FCVT.W.S, FMV.X.W/FCLASS)
   wire fpu_int_res = is_fpu && (funct7==7'b1010000 || funct7==7'b1100000 || funct7==7'b1110000);
   wire fpu_f_res   = is_fpu && !fpu_int_res;                       // f[rd] yazan FPU op
   wire fpu_int_src = is_fpu && (funct7==7'b1101000 || funct7==7'b1111000); // FCVT.S.W/FMV.W.X
   wire fpu_fsrc1   = is_fpu && !fpu_int_src;                       // f[rs1] okur
   wire fpu_fsrc2   = is_fpu && (funct7==7'b0000000 || funct7==7'b0000100 ||
                                 funct7==7'b0001000 || funct7==7'b0010000 ||
                                 funct7==7'b0010100 || funct7==7'b1010000); // ikili: f[rs2]
   // f[rd] yazan buyruk (FLW dahil), int[rd] yazan FPU buyrugu
   wire f_yaz   = is_flw || fpu_f_res;
   wire int_fpu_yaz = fpu_int_res;

   assign f_oku1_o = rs1_adres;
   assign f_oku2_o = rs2_adres;
   assign f_rs1_kullanilir_o = fpu_fsrc1;
   assign f_rs2_kullanilir_o = fpu_fsrc2 || is_fsw;
   wire [4:0] rs1_adres = coz_buyruk_i[19:15];
   wire [4:0] rs2_adres = coz_buyruk_i[24:20];
   wire [4:0] rd_adres  = coz_buyruk_i[11:7];

   assign oku_adres1_o = rs1_adres;
   assign oku_adres2_o = rs2_adres;

   // ---------------- Anlik (immediate) ----------------
   reg [31:0] imm;
   always @* begin
      case (opcode)
         `OPCODE_ITYPE, `OPCODE_LOAD, `OPCODE_JALR, `OPCODE_FPU_LW:
            imm = {{20{coz_buyruk_i[31]}}, coz_buyruk_i[31:20]};
         `OPCODE_STORE, `OPCODE_FPU_SW:
            imm = {{20{coz_buyruk_i[31]}}, coz_buyruk_i[31:25], coz_buyruk_i[11:7]};
         `OPCODE_BRANCH:
            imm = {{19{coz_buyruk_i[31]}}, coz_buyruk_i[31], coz_buyruk_i[7],
                   coz_buyruk_i[30:25], coz_buyruk_i[11:8], 1'b0};
         `OPCODE_LUI, `OPCODE_AUIPC:
            imm = {coz_buyruk_i[31:12], 12'b0};
         `OPCODE_JAL:
            imm = {{11{coz_buyruk_i[31]}}, coz_buyruk_i[31], coz_buyruk_i[19:12],
                   coz_buyruk_i[20], coz_buyruk_i[30:21], 1'b0};
         default:
            imm = 32'b0;
      endcase
   end

   // ---------------- Kaynak kullanimi (hazard icin) ----------------
   reg rs1_kul, rs2_kul;
   always @* begin
      rs1_kul = 1'b0;
      rs2_kul = 1'b0;
      case (opcode)
         `OPCODE_RTYPE:  begin rs1_kul=1; rs2_kul=1; end
         `OPCODE_ITYPE:  begin rs1_kul=1;            end
         `OPCODE_LOAD:   begin rs1_kul=1;            end
         `OPCODE_STORE:  begin rs1_kul=1; rs2_kul=1; end
         `OPCODE_BRANCH: begin rs1_kul=1; rs2_kul=1; end
         `OPCODE_JALR:   begin rs1_kul=1;            end
         `OPCODE_ATOMIC: begin rs1_kul=1; rs2_kul=1; end
         // CSRRW/CSRRS/CSRRC (funct3 != 0, immediate degil) rs1 okur.
         `OPCODE_SYSTEM: begin rs1_kul = (funct3 != 3'b000) && !funct3[2]; end
         `OPCODE_FPU_LW: begin rs1_kul=1;            end   // adres
         `OPCODE_FPU_SW: begin rs1_kul=1;            end   // adres (veri = f[rs2])
         `OPCODE_FPU:    begin rs1_kul = fpu_int_src; end  // FCVT.S.W / FMV.W.X
         default:        begin rs1_kul=0; rs2_kul=0; end // LUI/AUIPC/JAL/...
      endcase
   end
   assign rs1_kullanilir_o = rs1_kul;
   assign rs2_kullanilir_o = rs2_kul;

   // ---------------- Mikroislem (sema B) cozme ----------------
   reg [`MI_BIT-1:0] mikroislem;
   always @* begin
      mikroislem            = {`MI_BIT{1'b0}};
      mikroislem[`BIRIM]    = `BIRIM_ALU;
      mikroislem[`ALU]      = `ALU_TOPLAMA;
      mikroislem[`OPERAND]  = `OPERAND_REG;
      mikroislem[`GERIYAZ]  = `GERIYAZ_KAYNAK_YOK;
      mikroislem[`YAZMAC]   = `YAZMAC_YAZMA;

      case (opcode)
         `OPCODE_RTYPE: begin
            mikroislem[`OPERAND] = `OPERAND_REG;
            mikroislem[`YAZMAC]  = `YAZMAC_YAZ;
            if (funct7 == 7'b0000001) begin          // M uzantisi (mul/div)
               if (funct3[2] == 1'b0) begin
                  mikroislem[`BIRIM]   = `BIRIM_CARPMA;
                  mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_CARP;
                  case (funct3[1:0])
                     2'b00: mikroislem[`CARPMA] = `CARPMA_MUL;
                     2'b01: mikroislem[`CARPMA] = `CARPMA_MULH;
                     2'b10: mikroislem[`CARPMA] = `CARPMA_MULHSU;
                     2'b11: mikroislem[`CARPMA] = `CARPMA_MULHU;
                  endcase
               end else begin
                  mikroislem[`BIRIM]   = `BIRIM_BOLME;
                  mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YURUT;
                  case (funct3[1:0])
                     2'b00: mikroislem[`BOLME] = `BOLME_DIV;
                     2'b01: mikroislem[`BOLME] = `BOLME_DIVU;
                     2'b10: mikroislem[`BOLME] = `BOLME_REM;
                     2'b11: mikroislem[`BOLME] = `BOLME_REMU;
                  endcase
               end
            end else if (b_rtype) begin              // B uzantisi (bit-manip)
               mikroislem[`BMANIP]  = 1'b1;
               mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK;  // yurut bmanip_mi ile secer
            end else begin                            // taban R-tipi
               mikroislem[`BIRIM]   = `BIRIM_ALU;
               mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YURUT;
               mikroislem[`ALU]     = alu_kodu(funct3, bit30, 1'b1);
            end
         end
         `OPCODE_ITYPE: begin
            if (b_itype) begin                        // B uzantisi (CLZ/CTZ/CPOP/SEXT/RORI)
               mikroislem[`OPERAND] = `OPERAND_REG;
               mikroislem[`BMANIP]  = 1'b1;
               mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK;
               mikroislem[`YAZMAC]  = `YAZMAC_YAZ;
            end else begin
               mikroislem[`BIRIM]   = `BIRIM_ALU;
               mikroislem[`OPERAND] = `OPERAND_IMM;
               mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YURUT;
               mikroislem[`YAZMAC]  = `YAZMAC_YAZ;
               mikroislem[`ALU]     = alu_kodu(funct3, bit30, 1'b0);
            end
         end
         `OPCODE_LOAD: begin
            mikroislem[`BIRIM]   = `BIRIM_BIB;
            mikroislem[`OPERAND] = `OPERAND_IMM;
            mikroislem[`ALU]     = `ALU_TOPLAMA;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YURUT;
            mikroislem[`YAZMAC]  = `YAZMAC_YAZ;
            case (funct3)
               `LB:  mikroislem[`BIB] = `BIB_LB;
               `LH:  mikroislem[`BIB] = `BIB_LH;
               `LW:  mikroislem[`BIB] = `BIB_LW;
               `LBU: mikroislem[`BIB] = `BIB_LBU;
               `LHU: mikroislem[`BIB] = `BIB_LHU;
               default: mikroislem[`BIB] = `BIB_LW;
            endcase
         end
         `OPCODE_STORE: begin
            mikroislem[`BIRIM]   = `BIRIM_BIB;
            mikroislem[`OPERAND] = `OPERAND_IMM;
            mikroislem[`ALU]     = `ALU_TOPLAMA;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK;
            case (funct3)
               `SB: mikroislem[`BIB] = `BIB_SB;
               `SH: mikroislem[`BIB] = `BIB_SH;
               `SW: mikroislem[`BIB] = `BIB_SW;
               default: mikroislem[`BIB] = `BIB_SW;
            endcase
         end
         `OPCODE_BRANCH: begin
            mikroislem[`BIRIM]   = `BIRIM_DALLANMA;
            mikroislem[`OPERAND] = `OPERAND_REG;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK;
            case (funct3)
               `FUNCT3_EQ:  mikroislem[`DAL] = `DAL_EQ;
               `FUNCT3_NEQ: mikroislem[`DAL] = `DAL_NE;
               `FUNCT3_LT:  mikroislem[`DAL] = `DAL_LT;
               `FUNCT3_GE:  mikroislem[`DAL] = `DAL_GE;
               `FUNCT3_LTU: mikroislem[`DAL] = `DAL_LTU;
               `FUNCT3_GEU: mikroislem[`DAL] = `DAL_GEU;
               default:     mikroislem[`DAL] = `DAL_YOK;
            endcase
         end
         `OPCODE_JAL: begin
            mikroislem[`BIRIM]   = `BIRIM_DALLANMA;
            mikroislem[`DAL]     = `DAL_JAL;
            mikroislem[`OPERAND] = `OPERAND_PCIMM;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_PC;
            mikroislem[`YAZMAC]  = `YAZMAC_YAZ;
         end
         `OPCODE_JALR: begin
            mikroislem[`BIRIM]   = `BIRIM_DALLANMA;
            mikroislem[`DAL]     = `DAL_JALR;
            mikroislem[`OPERAND] = `OPERAND_IMM;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_PC;
            mikroislem[`YAZMAC]  = `YAZMAC_YAZ;
         end
         `OPCODE_LUI: begin
            mikroislem[`BIRIM]   = `BIRIM_ALU;
            mikroislem[`ALU]     = `ALU_GECIR;
            mikroislem[`OPERAND] = `OPERAND_IMM;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YURUT;
            mikroislem[`YAZMAC]  = `YAZMAC_YAZ;
         end
         `OPCODE_AUIPC: begin
            mikroislem[`BIRIM]   = `BIRIM_ALU;
            mikroislem[`ALU]     = `ALU_TOPLAMA;
            mikroislem[`OPERAND] = `OPERAND_PCIMM;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YURUT;
            mikroislem[`YAZMAC]  = `YAZMAC_YAZ;
         end
         `OPCODE_ATOMIC: begin
            // LR.W / SC.W / AMO*  (adres=rs1, kaynak=rs2; funct5=buyruk[31:27])
            mikroislem[`BIRIM]   = `BIRIM_ATOMIC;
            mikroislem[`OPERAND] = `OPERAND_REG;     // deger1=rs1, deger2=rs2
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK; // yurut atomik_mi ile secer
            mikroislem[`YAZMAC]  = `YAZMAC_YAZ;       // rd: eski deger / SC sonucu
         end
         `OPCODE_SYSTEM: begin
            mikroislem[`OPERAND] = `OPERAND_REG;     // CSRRW/S/C -> deger1 = rs1
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK;
            if (funct3 == 3'b000) begin
               // ECALL / EBREAK / MRET / illegal (rd yazmaz)
               mikroislem[`BIRIM]  = `BIRIM_ALU;
               mikroislem[`YAZMAC] = `YAZMAC_YAZMA;
               case (coz_buyruk_i[31:20])           // funct12
                  12'h000: mikroislem[`SYS] = `SYS_ECALL;
                  12'h001: mikroislem[`SYS] = `SYS_EBREAK;
                  12'h302: mikroislem[`SYS] = `SYS_MRET;
                  default: mikroislem[`SYS] = `SYS_ILLEGAL;
               endcase
            end else begin
               // CSR oku/yaz: rd = eski CSR (yurut BIRIM_CSR ile secer)
               mikroislem[`BIRIM]  = `BIRIM_CSR;
               mikroislem[`YAZMAC] = `YAZMAC_YAZ;
            end
         end
         `OPCODE_FPU_LW: begin               // FLW: yukle (adres=rs1+imm), sonuc -> f[rd]
            mikroislem[`BIRIM]   = `BIRIM_BIB;
            mikroislem[`OPERAND] = `OPERAND_IMM;
            mikroislem[`ALU]     = `ALU_TOPLAMA;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK;
            mikroislem[`YAZMAC]  = `YAZMAC_YAZMA;  // tamsayi RF'ye yazmaz
            mikroislem[`BIB]     = `BIB_LW;
         end
         `OPCODE_FPU_SW: begin               // FSW: sakla (adres=rs1+imm, veri=f[rs2])
            mikroislem[`BIRIM]   = `BIRIM_BIB;
            mikroislem[`OPERAND] = `OPERAND_IMM;
            mikroislem[`ALU]     = `ALU_TOPLAMA;
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK;
            mikroislem[`YAZMAC]  = `YAZMAC_YAZMA;
            mikroislem[`BIB]     = `BIB_SW;
         end
         `OPCODE_FPU: begin                  // FPU hesaplama/karsilastirma/donusum
            mikroislem[`BIRIM]   = `BIRIM_FPU;
            mikroislem[`OPERAND] = `OPERAND_REG;   // deger1 = int rs1 (FCVT.S.W/FMV.W.X)
            mikroislem[`GERIYAZ] = `GERIYAZ_KAYNAK_YOK;
            // int sonuc (FEQ/FLT/FLE/FCVT.W.S/FMV.X.W/FCLASS) -> tamsayi RF yaz
            mikroislem[`YAZMAC]  = fpu_int_res ? `YAZMAC_YAZ : `YAZMAC_YAZMA;
         end
         default: begin
            mikroislem[`YAZMAC] = `YAZMAC_YAZMA;
         end
      endcase
   end

   function [3:0] alu_kodu;
      input [2:0] f3;
      input       b30;
      input       rtype;
      begin
         case (f3)
            `FUNCT3_ADD:  alu_kodu = (rtype && b30) ? `ALU_CIKARMA : `ALU_TOPLAMA;
            `FUNCT3_SLL:  alu_kodu = `ALU_SLL;
            `FUNCT3_SLT:  alu_kodu = `ALU_SLT;
            `FUNCT3_SLTU: alu_kodu = `ALU_SLTU;
            `FUNCT3_XOR:  alu_kodu = `ALU_XOR;
            `FUNCT3_SRA:  alu_kodu = b30 ? `ALU_SRA : `ALU_SRL;
            `FUNCT3_OR:   alu_kodu = `ALU_OR;
            `FUNCT3_AND:  alu_kodu = `ALU_AND;
            default:      alu_kodu = `ALU_TOPLAMA;
         endcase
      end
   endfunction

   // ---------------- Operand secimi ----------------
   wire [1:0] operand_kodu = mikroislem[`OPERAND];
   wire       op1_pc  = operand_kodu[1];
   wire       op2_imm = operand_kodu[0];
   wire [31:0] deger1_w = op1_pc  ? coz_buyruk_ps_i : rs1_deger_i;
   wire [31:0] deger2_w = op2_imm ? imm             : rs2_deger_i;

   // ---------------- Yayinlama (issue) ve rezervasyon ----------------
   //  yaziyor  : tamsayi RF'ye yazar (YAZMAC_YAZ; FPU-int sonuclari dahil).
   //  f_yaz    : F RF'ye yazar (FLW + FPU f-sonuclari).
   wire yaziyor   = (mikroislem[`YAZMAC] == `YAZMAC_YAZ) && (rd_adres != 5'd0);
   wire yayinla   = coz_buyruk_gecerli_i && !durdur_i && !bosalt_i && !dondur_i; // bu cevrim issue

   reg [3:0] etiket_sayac_r;   // yuruyen etiket sayaci (int + f paylasimli)

   assign rezerve_adres_o   = rd_adres;
   assign rezerve_etiket_o  = etiket_sayac_r;
   assign rezerve_gecerli_o = yayinla && yaziyor;

   assign f_rezerve_adres_o   = rd_adres;
   assign f_rezerve_etiket_o  = etiket_sayac_r;
   assign f_rezerve_gecerli_o = yayinla && f_yaz;

   // ---------------- coz -> yurut ardisik duzen kaydi ----------------
   always @(posedge clk_i) begin
      if (!rst_i) begin
         yurut_gecerli_o    <= 1'b0;
         yurut_atladi_o     <= 1'b0;
         yurut_mikroislem_o <= {`MI_BIT{1'b0}};
         yurut_ps_o         <= 32'b0;
         yurut_deger1_o     <= 32'b0;
         yurut_deger2_o     <= 32'b0;
         yurut_rs2_deger_o  <= 32'b0;
         yurut_imm_o        <= 32'b0;
         yurut_rd_adres_o   <= 5'b0;
         yurut_rs1_adres_o  <= 5'b0;
         yurut_rs2_adres_o  <= 5'b0;
         yurut_etiket_o     <= 4'b0;
         yurut_buyruk_o     <= 32'b0;
         yurut_fdeger1_o    <= 32'b0;
         yurut_fdeger2_o    <= 32'b0;
         yurut_rvc_o        <= 1'b0;
         etiket_sayac_r     <= 4'b0;
      end
      // dondur_i (bellek beklemesi): YURUT'taki buyruk execute'te kalmali ->
      // y_* DEGISTIRILMEZ (tutulur). En yuksek oncelik.
      else if (dondur_i) begin
         // tut: hicbir atama yok
      end
      else begin
         // durdur_i (hazard) = bu cevrim YAYINLAMA, asagiya kabarcik gonder,
         // (girisi getir cek_duraklat_i ile tutar). bosalt_i = flush.
         if (durdur_i || bosalt_i || !coz_buyruk_gecerli_i) begin
            yurut_gecerli_o    <= 1'b0;
            yurut_atladi_o     <= 1'b0;
            yurut_mikroislem_o <= {`MI_BIT{1'b0}};
         end
         else begin
            yurut_gecerli_o    <= 1'b1;
            yurut_atladi_o     <= coz_buyruk_atladi_i;
            yurut_mikroislem_o <= mikroislem;
            yurut_ps_o         <= coz_buyruk_ps_i;
            yurut_deger1_o     <= deger1_w;
            yurut_deger2_o     <= deger2_w;
            yurut_rs2_deger_o  <= rs2_deger_i;
            yurut_imm_o        <= imm;
            yurut_rd_adres_o   <= rd_adres;
            yurut_rs1_adres_o  <= rs1_adres;
            yurut_rs2_adres_o  <= rs2_adres;
            yurut_etiket_o     <= etiket_sayac_r;
            yurut_buyruk_o     <= coz_buyruk_i;
            yurut_fdeger1_o    <= frs1_deger_i;
            yurut_fdeger2_o    <= frs2_deger_i;
            yurut_rvc_o        <= coz_buyruk_rvc_i;
            if (yaziyor || f_yaz) etiket_sayac_r <= etiket_sayac_r + 4'd1;
         end
      end
   end

endmodule
