`timescale 1ns/1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_fpu_yuvarlama  -  fpu_temiz yuvarlama modlari + FCSR istisna bayraklari
//  - Statik modlar RNE/RTZ/RDN/RUP/RMM (FDIV/FSQRT inexact)
//  - DYN(111): frm_i girisi kullanilir
//  - bayrak_o {NV,DZ,OF,UF,NX}: inexact / sifira bolme / gecersiz islem
//  Beklenen degerler tam-rasyonel + dogru yuvarlama ile uretildi.
// ===========================================================================
module tb_fpu_yuvarlama;
   reg [6:0] f7; reg [2:0] rm, frm; reg [4:0] rs2; reg [31:0] a,b,x;
   wire [31:0] y; wire ti; wire [4:0] bayrak;
   fpu_temiz dut(.funct7_i(f7),.rm_i(rm),.frm_i(frm),.rs2f_i(rs2),.f1_i(a),.f2_i(b),.x1_i(x),
                 .sonuc_o(y),.tamsayi_sonuc_o(ti),.bayrak_o(bayrak));

   integer hata=0;
   task chk; input [127:0] ad; input [31:0] bek; begin
      #1; if (y!==bek) begin $display("  HATA: %0s bek=%h alinan=%h",ad,bek,y); hata=hata+1; end
      else $display("  OK  : %0s = %h",ad,y); end
   endtask
   task chkb; input [127:0] ad; input [31:0] bek; input [4:0] bbek; begin
      #1; if (y!==bek || bayrak!==bbek) begin
         $display("  HATA: %0s bek=%h/fl%b alinan=%h/fl%b",ad,bek,bbek,y,bayrak); hata=hata+1; end
      else $display("  OK  : %0s = %h fl=%b",ad,y,bayrak); end
   endtask

   initial begin
      rs2=0; x=0; frm=3'b000;
      $display("\n===== FPU yuvarlama modlari =====");
      // FDIV 1/3 (inexact) tum modlar
      f7=7'b0001100; a=32'h3F800000; b=32'h40400000;          // 1.0 / 3.0
      rm=3'b000; chk("1/3 RNE",      32'h3EAAAAAB);
      rm=3'b001; chk("1/3 RTZ",      32'h3EAAAAAA);
      rm=3'b010; chk("1/3 RDN",      32'h3EAAAAAA);
      rm=3'b011; chk("1/3 RUP",      32'h3EAAAAAB);
      rm=3'b100; chk("1/3 RMM",      32'h3EAAAAAB);
      // FDIV -1/3 : isaret RDN/RUP yonunu ters cevirir
      a=32'hBF800000; b=32'h40400000;                          // -1.0 / 3.0
      rm=3'b000; chk("-1/3 RNE", 32'hBEAAAAAB);
      rm=3'b010; chk("-1/3 RDN", 32'hBEAAAAAB);
      rm=3'b011; chk("-1/3 RUP", 32'hBEAAAAAA);
      // FSQRT 2 : yalnizca RUP farkli
      f7=7'b0101100; a=32'h40000000;
      rm=3'b000; chk("sqrt2 RNE", 32'h3FB504F3);
      rm=3'b011; chk("sqrt2 RUP", 32'h3FB504F4);

      $display("\n===== DYN (rm=111 -> frm) =====");
      f7=7'b0001100; a=32'h3F800000; b=32'h40400000; rm=3'b111;  // 1/3, DYN
      frm=3'b001; chk("1/3 DYN=RTZ", 32'h3EAAAAAA);
      frm=3'b011; chk("1/3 DYN=RUP", 32'h3EAAAAAB);
      frm=3'b000; chk("1/3 DYN=RNE", 32'h3EAAAAAB);

      $display("\n===== Istisna bayraklari {NV,DZ,OF,UF,NX} =====");
      rm=3'b000;
      // inexact -> NX
      f7=7'b0001100; a=32'h3F800000; b=32'h40400000; chkb("1/3 NX",   32'h3EAAAAAB, 5'b00001);
      // tam bolme -> bayrak yok
      a=32'h40C00000; b=32'h40000000;                chkb("6/2 tam",  32'h40400000, 5'b00000);
      // sifira bolme (sonlu/0) -> DZ + inf
      a=32'h3F800000; b=32'h00000000;                chkb("1/0 DZ",   32'h7F800000, 5'b01000);
      // 0/0 -> NV (gecersiz) + qNaN
      a=32'h00000000; b=32'h00000000;                chkb("0/0 NV",   32'h7FC00000, 5'b10000);
      // sqrt(-4) -> NV + qNaN
      f7=7'b0101100; a=32'hC0800000;                 chkb("sqrt-4 NV",32'h7FC00000, 5'b10000);
      // sqrt(2) -> NX
      a=32'h40000000;                                chkb("sqrt2 NX", 32'h3FB504F3, 5'b00001);
      // FMUL tam -> bayrak yok
      f7=7'b0001000; a=32'h3F800000; b=32'h40400000; chkb("1*3 tam",  32'h40400000, 5'b00000);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
endmodule
