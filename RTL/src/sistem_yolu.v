`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  sistem_yolu  -  SoC veri yolu (bus) + bellek + cevresel birimler
// ---------------------------------------------------------------------------
//  Cekirdegin buyruk-getirme ve veri arayuzlerini, adres cozumuyle birden cok
//  slave'e (RAM, UART, zamanlayici, tohost) baglar. Tek master (cekirdek veri
//  portu) + ayri buyruk-getirme portu.
//
//  Bellek haritasi (slave secimi adres[31:28] ile):
//    0x8xxx_xxxx : RAM (buyruk + veri)         -> RAM_GECIKME cevrim bekleme
//    0x1xxx_xxxx : cevresel birimler (tek cevrim, hazir=1)
//        +0x00 UART_TX | +0x04 UART_DURUM | +0x10/14 MTIME | +0x18/1C MTIMECMP | +0x20 TOHOST
//
//  Bekleme: RAM veri erisimi RAM_GECIKME cevrim "mesgul" (d_hazir_o=0); cekirdek
//  bu sirada buyrugu execute'te dondurur. Buyruk-getirme her zaman tek cevrim.
//  (Bu protokol gercek onbellek/AXI bus birimlerine genisletilebilir.)
// ===========================================================================

module sistem_yolu #(
   parameter integer KELIME = 8192,
   parameter integer RAM_GECIKME = 0,            // RAM veri bekleme cevrimi (0 = tek cevrim)
   parameter [31:0]  RAM_TABAN   = 32'h8000_0000,
   parameter [31:0]  PERIF_TABAN = 32'h1000_0000
)(
   input             clk_i,
   input             rst_i,

   // Buyruk getirme (kombinasyonel, beklemesiz)
   input  [31:0]     i_adres_i,
   output [31:0]     i_veri_o,

   // Veri portu (kombinasyonel okuma; d_hazir_o=0 -> bekleme)
   input  [31:0]     d_adres_i,
   input             d_oku_i,
   input             d_yaz_i,
   input  [31:0]     d_veri_i,
   input  [3:0]      d_maske_i,
   output [31:0]     d_oku_veri_o,
   output            d_hazir_o,

   // Zamanlayici kesmesi -> cekirdek
   output            zaman_kesme_o,

   // Gozlem / sonlandirma
   output reg        uart_gecerli_o,
   output reg [7:0]  uart_veri_o,
   output reg        bitti_o,
   output reg [31:0] cikis_kodu_o
);

   localparam integer AW = $clog2(KELIME);

   // ---------------- Adres cozumu ----------------
   wire ram_sec   = (d_adres_i[31:28] == RAM_TABAN[31:28]);
   wire perif_sec = (d_adres_i[31:28] == PERIF_TABAN[31:28]);
   wire [7:0] perif_ofs = d_adres_i[7:0];

   // ---------------- RAM ----------------
   reg [31:0] ram [0:KELIME-1];
   wire [AW-1:0] i_idx = i_adres_i[AW+1:2];
   wire [AW-1:0] d_idx = d_adres_i[AW+1:2];
   assign i_veri_o = ram[i_idx];

   // RAM bekleme sayaci (veri erisimi)
   wire ram_erisim = ram_sec && (d_oku_i || d_yaz_i);
   reg [3:0] say;
   always @(posedge clk_i) begin
      if (!rst_i)            say <= RAM_GECIKME[3:0];
      else if (!ram_erisim)  say <= RAM_GECIKME[3:0];
      else if (say != 0)     say <= say - 4'd1;
      else                   say <= RAM_GECIKME[3:0];   // tamamlandi -> sonraki icin
   end
   wire ram_hazir = (say == 0);

   // ---------------- Cevresel kayitlar ----------------
   reg [63:0] mtime, mtimecmp;
   reg [3:0]  uart_say;
   wire       uart_mesgul = (uart_say != 0);
   assign zaman_kesme_o = (mtime >= mtimecmp);

   reg [31:0] perif_rdata;
   always @* begin
      perif_rdata = 32'b0;
      case (perif_ofs)
         8'h04: perif_rdata = {31'b0, uart_mesgul};
         8'h10: perif_rdata = mtime[31:0];
         8'h14: perif_rdata = mtime[63:32];
         8'h18: perif_rdata = mtimecmp[31:0];
         8'h1C: perif_rdata = mtimecmp[63:32];
         default: perif_rdata = 32'b0;
      endcase
   end

   // ---------------- Okuma muxu + hazir ----------------
   assign d_oku_veri_o = perif_sec ? perif_rdata : ram[d_idx];
   assign d_hazir_o    = perif_sec ? 1'b1 : ram_hazir;   // cevre tek cevrim, RAM beklemeli

   // ---------------- Yazma + sayaclar ----------------
   integer b;
   always @(posedge clk_i) begin
      uart_gecerli_o <= 1'b0;
      if (!rst_i) begin
         mtime    <= 64'b0;
         mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;
         uart_say <= 4'b0; bitti_o <= 1'b0; cikis_kodu_o <= 32'b0; uart_veri_o <= 8'b0;
      end else begin
         mtime <= mtime + 64'd1;
         if (uart_say != 0) uart_say <= uart_say - 4'd1;

         // RAM yazma: yalnizca erisim tamamlaninca (hazir) bir kez
         if (d_yaz_i && ram_sec && ram_hazir)
            for (b=0;b<4;b=b+1) if (d_maske_i[b]) ram[d_idx][b*8 +: 8] <= d_veri_i[b*8 +: 8];

         // Cevresel yazma (tek cevrim)
         if (d_yaz_i && perif_sec) begin
            case (perif_ofs)
               8'h00: begin uart_veri_o <= d_veri_i[7:0]; uart_gecerli_o <= 1'b1; uart_say <= 4'd6; end
               8'h18: mtimecmp[31:0]  <= d_veri_i;
               8'h1C: mtimecmp[63:32] <= d_veri_i;
               8'h20: begin bitti_o <= 1'b1; cikis_kodu_o <= d_veri_i; end
               default: ;
            endcase
         end
      end
   end

endmodule
