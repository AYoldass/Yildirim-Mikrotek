`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  veri_yolu_kopru  -  Cekirdek bellek arayuzu  <->  veri_yolu_birimi (bib)
// ---------------------------------------------------------------------------
//  Cekirdegin tutulan-istek + bekleme (mem_hazir) arayuzunu, veri_yolu_birimi'nin
//  transaction'li "bib" protokolune cevirir:
//    - Cekirdek bir bellek erisimi sunar (cek_oku/cek_yaz, tutulur). Kopru, bus
//      bostayken (bellek_hazir) isteği BIR cevrim yayinlar (bib_istek_gecerli).
//    - Tamamlanma: okumada bellek_gecerli darbesi (veri bellek_veri'de); yazmada
//      bus tekrar bostaysa (bellek_hazir). O cevrim cek_hazir=1 -> cekirdek commit.
//  Boylece tek anda tek islem; cekirdek bu sirada buyrugu execute'te dondurur.
// ===========================================================================

module veri_yolu_kopru (
   input             clk_i,
   input             rst_i,

   // Cekirdek tarafi (mem arayuzu)
   input  [31:0]     cek_adres_i,
   input             cek_oku_i,
   input             cek_yaz_i,
   input  [31:0]     cek_veri_i,
   input  [3:0]      cek_maske_i,
   output [31:0]     cek_oku_veri_o,
   output            cek_hazir_o,

   // veri_yolu_birimi "bib" tarafi
   output            bib_istek_gecerli_o,
   output            bib_istek_oku_o,
   output            bib_istek_yaz_o,
   output [31:0]     bib_istek_adres_o,
   output [31:0]     bib_veri_o,
   output [3:0]      bib_istek_maske_o,
   input             bellek_hazir_i,
   input             bellek_gecerli_i,
   input  [31:0]     bellek_veri_i
);

   reg bekliyor;     // istek yayinlandi, tamamlanma bekleniyor
   reg yaz_r;        // yayinlanan islem yazma miydi

   wire cek_op = cek_oku_i || cek_yaz_i;
   wire yayinla = cek_op && !bekliyor && bellek_hazir_i;     // bu cevrim isteği ver
   wire tamam   = bekliyor && (bellek_gecerli_i || (yaz_r && bellek_hazir_i));

   assign bib_istek_gecerli_o = yayinla;
   assign bib_istek_oku_o     = cek_oku_i;
   assign bib_istek_yaz_o     = cek_yaz_i;
   assign bib_istek_adres_o   = cek_adres_i;
   assign bib_veri_o          = cek_veri_i;
   assign bib_istek_maske_o   = cek_maske_i;

   assign cek_hazir_o    = tamam;
   assign cek_oku_veri_o = bellek_veri_i;     // okuma tamamlanmasinda gecerli

   always @(posedge clk_i) begin
      if (!rst_i) begin
         bekliyor <= 1'b0;
         yaz_r    <= 1'b0;
      end else begin
         if (yayinla)     begin bekliyor <= 1'b1; yaz_r <= cek_yaz_i; end
         else if (tamam)  bekliyor <= 1'b0;
      end
   end

endmodule
