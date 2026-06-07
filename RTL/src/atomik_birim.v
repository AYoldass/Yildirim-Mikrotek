`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  atomik_birim  -  RV32A atomik buyruk birimi (LR/SC + AMO*)
// ---------------------------------------------------------------------------
//  Yurut asamasinda calisir (execute = writeback). Cekirdegin veri bellegi
//  KOMBINASYONEL okuma + SENKRON yazma oldugundan, AMO (read-modify-write) ve
//  LR/SC tek cevrimde tamamlanir:
//    - eski deger = mem_eski_i (kombinasyonel okuma, adres = rs1)
//    - rd  <- eski deger (AMO/LR) veya basari kodu (SC: 0=basari,1=basarisiz)
//    - yeni deger -> bellege (ayni posedge'de senkron yazma)
//
//  Adres = rs1 (offset yok). funct5 = buyruk[31:27].
//
//  LR/SC rezervasyonu (tek-hart): LR adresi rezerve eder; SC yalnizca gecerli
//  ve adres eslesen rezervasyon varsa basarir (sonra rezervasyonu temizler).
//  AMO da rezervasyonu temizler. (Cok-hart/normal-store cakismasi kapsam disi.)
//
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module atomik_birim (
   input              clk_i,
   input              rst_i,

   input              gecerli_i,       // execute'te gecerli atomik buyruk
   input   [4:0]      kod_i,           // funct5 (buyruk[31:27])
   input   [31:0]     adres_i,         // rs1 (bellek adresi)
   input   [31:0]     rs2_i,           // AMO/SC kaynak verisi
   input   [31:0]     mem_eski_i,      // mem[adres] (kombinasyonel okuma)

   output reg [31:0]  rd_veri_o,       // rd'ye yazilacak
   output reg [31:0]  mem_yeni_o,      // bellege yazilacak
   output reg         mem_oku_o,
   output reg         mem_yaz_o,
   output             sc_basari_o      // (izleme) SC basarili miydi
);

   reg        rez_gecerli_r;
   reg [31:0] rez_adres_r;

   wire is_lr = (kod_i == `LR_W);
   wire is_sc = (kod_i == `SC_W);
   wire is_amo = gecerli_i && !is_lr && !is_sc;
   wire sc_ok = rez_gecerli_r && (rez_adres_r == adres_i);

   assign sc_basari_o = gecerli_i && is_sc && sc_ok;

   // AMO sonucu
   reg [31:0] amo_yeni;
   always @* begin
      case (kod_i)
         `AMOSWAP_W: amo_yeni = rs2_i;
         `AMOADD_W:  amo_yeni = mem_eski_i + rs2_i;
         `AMOXOR_W:  amo_yeni = mem_eski_i ^ rs2_i;
         `AMOAND_W:  amo_yeni = mem_eski_i & rs2_i;
         `AMOOR_W:   amo_yeni = mem_eski_i | rs2_i;
         `AMOMIN_W:  amo_yeni = ($signed(mem_eski_i) < $signed(rs2_i)) ? mem_eski_i : rs2_i;
         `AMOMAX_W:  amo_yeni = ($signed(mem_eski_i) > $signed(rs2_i)) ? mem_eski_i : rs2_i;
         `AMOMINU_W: amo_yeni = (mem_eski_i < rs2_i) ? mem_eski_i : rs2_i;
         `AMOMAXU_W: amo_yeni = (mem_eski_i > rs2_i) ? mem_eski_i : rs2_i;
         default:    amo_yeni = rs2_i;
      endcase
   end

   always @* begin
      rd_veri_o  = 32'b0;
      mem_yeni_o = 32'b0;
      mem_oku_o  = 1'b0;
      mem_yaz_o  = 1'b0;
      if (gecerli_i) begin
         if (is_lr) begin
            mem_oku_o = 1'b1;
            rd_veri_o = mem_eski_i;
         end
         else if (is_sc) begin
            if (sc_ok) begin
               mem_yaz_o  = 1'b1;
               mem_yeni_o = rs2_i;
               rd_veri_o  = 32'd0;     // basari
            end else begin
               rd_veri_o  = 32'd1;     // basarisiz
            end
         end
         else begin // AMO*
            mem_oku_o  = 1'b1;
            mem_yaz_o  = 1'b1;
            rd_veri_o  = mem_eski_i;   // eski deger rd'ye
            mem_yeni_o = amo_yeni;
         end
      end
   end

   always @(posedge clk_i) begin
      if (!rst_i) begin
         rez_gecerli_r <= 1'b0;
         rez_adres_r   <= 32'b0;
      end
      else if (gecerli_i) begin
         if (is_lr) begin
            rez_gecerli_r <= 1'b1;
            rez_adres_r   <= adres_i;
         end
         else begin   // SC veya AMO -> rezervasyonu temizle
            rez_gecerli_r <= 1'b0;
         end
      end
   end

endmodule
