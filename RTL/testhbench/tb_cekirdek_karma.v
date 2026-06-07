`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_karma  -  Cok-uzantili entegrasyon testi (Faz 8 ozu)
// ---------------------------------------------------------------------------
//  Tek program; uzantilar-arasi etkilesim/hazard'lari dogrular:
//   - Geriye dallanmali dongu (kareler toplami): MUL + ADD + dallanma ongoru/redirect
//   - DIV (ortalama), B (CPOP), F (FCVT.S.W + FMUL), A (AMOADD), CSR (mcycle)
//   - Yuk/sakla + scoreboard zincirleri (MUL->ADD->branch; DIV->...; FLW yok, FCVT int->f)
//
//  Hesap:  sum_{i=1..5} i*i = 55 ; 55/5 = 11 ; cpop(55)=5 ;
//          (float) 55.0 * 5.0 = 275.0 ; amoadd: 55 + 5 = 60.
// ===========================================================================
module tb_cekirdek_karma;

   localparam BASE = 32'h8000_0000;
   reg clk=0, rst;
   always #5 clk=~clk;

   wire [31:0] iadr;
   reg  [31:0] imem [0:255];
   wire [7:0]  iidx = (iadr-BASE)>>2;
   wire [31:0] ibuf = imem[iidx];

   wire [31:0] dadr, dwdata; wire doku, dyaz; wire [3:0] dmask;
   reg  [31:0] dmem [0:255];
   wire [7:0]  didx = dadr[9:2];
   wire [31:0] drdata = dmem[didx];
   integer b;
   always @(posedge clk)
      if (dyaz) for (b=0;b<4;b=b+1) if (dmask[b]) dmem[didx][b*8 +: 8] <= dwdata[b*8 +: 8];

   cekirdek dut (
      .clk_i(clk), .rst_i(rst), .bel_adres_o(iadr), .bel_buyruk_i(ibuf),
      .veri_adres_o(dadr), .veri_oku_o(doku), .veri_yaz_o(dyaz),
      .veri_yaz_veri_o(dwdata), .veri_maske_o(dmask), .veri_oku_veri_i(drdata), .veri_hazir_i(1'b1)
   );

   integer hata=0, i;
   task kx; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin if (dut.u_rf.yazmac_r[r]!==bek) begin
         $display("  HATA: %0s (x%0d) bek=0x%08h alinan=0x%08h",ad,r,bek,dut.u_rf.yazmac_r[r]); hata=hata+1;
      end else $display("  OK  : %0s (x%0d) = %0d (0x%08h)",ad,r,$signed(dut.u_rf.yazmac_r[r]),dut.u_rf.yazmac_r[r]); end
   endtask
   task kf; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin if (dut.u_frf.yazmac_r[r]!==bek) begin
         $display("  HATA: %0s (f%0d) bek=0x%08h alinan=0x%08h",ad,r,bek,dut.u_frf.yazmac_r[r]); hata=hata+1;
      end else $display("  OK  : %0s (f%0d) = 0x%08h",ad,r,dut.u_frf.yazmac_r[r]); end
   endtask

   initial begin
      for (i=0;i<256;i=i+1) begin imem[i]=32'h00000013; dmem[i]=0; end

      imem[ 0]=32'h00000093; // addi x1,x0,0      sum=0
      imem[ 1]=32'h00100113; // addi x2,x0,1      i=1
      imem[ 2]=32'h00500193; // addi x3,x0,5      N=5
      // dongu (imem[3]):
      imem[ 3]=32'h02210233; // mul  x4,x2,x2     x4=i*i
      imem[ 4]=32'h004080B3; // add  x1,x1,x4     sum+=x4   (RAW: mul sonucu)
      imem[ 5]=32'h00110113; // addi x2,x2,1      i++
      imem[ 6]=32'hFE21DAE3; // bge  x3,x2,-12    while N>=i -> dongu
      // dongu sonu (sum=55, i=6, x4=25)
      imem[ 7]=32'h0230C2B3; // div  x5,x1,x3     55/5=11   (cok-cevrim)
      imem[ 8]=32'h60209313; // cpop x6,x1        popcount(55)=5  (B, cok-cevrim)
      imem[ 9]=32'hD00080D3; // fcvt.s.w f1,x1    55.0
      imem[10]=32'hD0018153; // fcvt.s.w f2,x3    5.0
      imem[11]=32'h102081D3; // fmul.s f3,f1,f2   275.0   (RAW: FCVT sonuclari)
      imem[12]=32'h20000513; // addi x10,x0,0x200 base
      imem[13]=32'h00152023; // sw   x1,0(x10)    mem=55
      imem[14]=32'h003525AF; // amoadd.w x11,x3,(x10)  x11=55; mem=60
      imem[15]=32'h00052603; // lw   x12,0(x10)   x12=60
      imem[16]=32'hB00026F3; // csrrs x13,mcycle,x0  x13>0
      imem[17]=32'h0000006F; // jal x0,0          dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(400) @(posedge clk);

      $display("\n===== Cok-uzantili entegrasyon =====");
      kx("sum(i*i) [I+M+branch]", 5'd1, 32'd55);
      kx("i (dongu sonu)",        5'd2, 32'd6);
      kx("son mul x4",            5'd4, 32'd25);
      kx("div ortalama",          5'd5, 32'd11);
      kx("cpop [B]",              5'd6, 32'd5);
      kf("fcvt 55.0 [F]",         5'd1, 32'h425C0000);
      kf("fcvt 5.0 [F]",          5'd2, 32'h40A00000);
      kf("fmul 275.0 [F]",        5'd3, 32'h43898000);
      kx("amoadd eski [A]",       5'd11,32'd55);
      kx("lw sonra amo",          5'd12,32'd60);

      $display("\n--- mcycle ve bellek ---");
      if (dut.u_rf.yazmac_r[13]===0) begin $display("  HATA: mcycle=0"); hata=hata+1; end
      else $display("  OK  : mcycle (x13) = %0d", dut.u_rf.yazmac_r[13]);
      if (dmem[8'h80]!==32'd60) begin $display("  HATA: mem[0x200]=%0d",dmem[8'h80]); hata=hata+1; end
      else $display("  OK  : mem[0x200] = %0d", dmem[8'h80]);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
   initial begin #300000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
