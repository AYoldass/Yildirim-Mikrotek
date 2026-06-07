`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_fcsr  -  FCSR (fflags/frm/fcsr) + dinamik yuvarlama uctan uca
//  - frm CSR'ye yazilir, DYN(rm=111) FP op bu modu kullanir
//  - inexact bolme -> NX, sifira bolme -> DZ; fflags/fcsr okunup dogrulanir
// ===========================================================================
module tb_cekirdek_fcsr;

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
   task ktrl_x; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin if (dut.u_rf.yazmac_r[r]!==bek) begin
         $display("  HATA: %0s (x%0d) bek=0x%08h alinan=0x%08h",ad,r,bek,dut.u_rf.yazmac_r[r]); hata=hata+1;
      end else $display("  OK  : %0s (x%0d) = 0x%08h",ad,r,dut.u_rf.yazmac_r[r]); end
   endtask
   task ktrl_f; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin if (dut.u_frf.yazmac_r[r]!==bek) begin
         $display("  HATA: %0s (f%0d) bek=0x%08h alinan=0x%08h",ad,r,bek,dut.u_frf.yazmac_r[r]); hata=hata+1;
      end else $display("  OK  : %0s (f%0d) = 0x%08h",ad,r,dut.u_frf.yazmac_r[r]); end
   endtask

   initial begin
      for (i=0;i<256;i=i+1) begin imem[i]=32'h00000013; dmem[i]=0; end
      dmem[8'h40] = 32'h3F800000; // mem[0x100] = 1.0
      dmem[8'h41] = 32'h40400000; // mem[0x104] = 3.0
      dmem[8'h42] = 32'h00000000; // mem[0x108] = 0.0

      imem[ 0]=32'h10000093; // addi x1,x0,0x100
      imem[ 1]=32'h0000A087; // flw f1,0(x1)  =1.0
      imem[ 2]=32'h0040A107; // flw f2,4(x1)  =3.0
      imem[ 3]=32'h0020D073; // csrrwi frm,1  (RTZ)
      imem[ 4]=32'h1820F1D3; // fdiv.s f3,f1,f2 DYN -> 1/3 RTZ = 0x3EAAAAAA
      imem[ 5]=32'h001025F3; // csrrs x11,fflags,x0  -> NX=0x01
      imem[ 6]=32'h00205073; // csrrwi frm,0  (RNE)
      imem[ 7]=32'h1820F253; // fdiv.s f4,f1,f2 DYN -> 1/3 RNE = 0x3EAAAAAB
      imem[ 8]=32'h0080A287; // flw f5,8(x1)  =0.0
      imem[ 9]=32'h18508353; // fdiv.s f6,f1,f5 -> 1/0 = +inf (DZ)
      imem[10]=32'h00102673; // csrrs x12,fflags,x0  -> NX|DZ = 0x09
      imem[11]=32'h003026F3; // csrrs x13,fcsr,x0    -> {frm=0, fflags=0x09}
      imem[12]=32'h0000006F; // jal x0,0

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(300) @(posedge clk);

      $display("\n===== FCSR + dinamik yuvarlama uctan uca =====");
      ktrl_f("fdiv DYN=RTZ f3", 5'd3,  32'h3EAAAAAA);
      ktrl_x("fflags NX  x11",  5'd11, 32'h00000001);
      ktrl_f("fdiv DYN=RNE f4", 5'd4,  32'h3EAAAAAB);
      ktrl_f("fdiv 1/0 inf f6", 5'd6,  32'h7F800000);
      ktrl_x("fflags NX|DZ x12",5'd12, 32'h00000009);
      ktrl_x("fcsr        x13", 5'd13, 32'h00000009);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
   initial begin #300000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
