`timescale 1ns/1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_fpu_yuvarlama  -  fpu_temiz statik yuvarlama modlari birim testi
//  RNE/RTZ/RDN/RUP/RMM (+ DYN->RNE) FDIV/FSQRT/FMUL inexact sonuclarda dogrulanir.
//  Beklenen degerler tam-rasyonel + dogru yuvarlama ile (python) uretildi.
// ===========================================================================
module tb_fpu_yuvarlama;
   reg [6:0] f7; reg [2:0] rm; reg [4:0] rs2; reg [31:0] a,b,x;
   wire [31:0] y; wire ti;
   fpu_temiz dut(.funct7_i(f7),.rm_i(rm),.rs2f_i(rs2),.f1_i(a),.f2_i(b),.x1_i(x),
                 .sonuc_o(y),.tamsayi_sonuc_o(ti));

   integer hata=0;
   task chk; input [127:0] ad; input [31:0] bek; begin
      #1; if (y!==bek) begin $display("  HATA: %0s bek=%h alinan=%h",ad,bek,y); hata=hata+1; end
      else $display("  OK  : %0s = %h",ad,y); end
   endtask

   initial begin
      rs2=0; x=0;
      $display("\n===== FPU yuvarlama modlari =====");
      // FDIV 1/3 (inexact) tum modlar
      f7=7'b0001100; a=32'h3F800000; b=32'h40400000;          // 1.0 / 3.0
      rm=3'b000; chk("1/3 RNE",      32'h3EAAAAAB);
      rm=3'b001; chk("1/3 RTZ",      32'h3EAAAAAA);
      rm=3'b010; chk("1/3 RDN",      32'h3EAAAAAA);
      rm=3'b011; chk("1/3 RUP",      32'h3EAAAAAB);
      rm=3'b100; chk("1/3 RMM",      32'h3EAAAAAB);
      rm=3'b111; chk("1/3 DYN->RNE", 32'h3EAAAAAB);
      // FDIV -1/3 : isaret RDN/RUP yonunu ters cevirir
      a=32'hBF800000; b=32'h40400000;                          // -1.0 / 3.0
      rm=3'b000; chk("-1/3 RNE", 32'hBEAAAAAB);
      rm=3'b001; chk("-1/3 RTZ", 32'hBEAAAAAA);
      rm=3'b010; chk("-1/3 RDN", 32'hBEAAAAAB);                // -inf'e: buyukluk artar
      rm=3'b011; chk("-1/3 RUP", 32'hBEAAAAAA);                // +inf'e: sifira dogru
      rm=3'b100; chk("-1/3 RMM", 32'hBEAAAAAB);
      // FSQRT 2 : yalnizca RUP farkli
      f7=7'b0101100; a=32'h40000000;                           // sqrt(2)
      rm=3'b000; chk("sqrt2 RNE", 32'h3FB504F3);
      rm=3'b001; chk("sqrt2 RTZ", 32'h3FB504F3);
      rm=3'b011; chk("sqrt2 RUP", 32'h3FB504F4);
      // FMUL tam sonuc: mod onemsiz
      f7=7'b0001000; a=32'h3F800000; b=32'h40400000;           // 1.0 * 3.0 = 3.0
      rm=3'b001; chk("1*3 RTZ (tam)", 32'h40400000);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
endmodule
