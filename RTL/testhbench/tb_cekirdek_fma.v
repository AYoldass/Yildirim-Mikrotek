`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_fma  -  RV32F fused multiply-add (FMADD/FMSUB/FNMSUB/FNMADD)
//  Cekirdek uzerinden: 3. f-operand (rs3) okuma + F scoreboard RAW + tek yuvarlama.
//  Son test (a*a-1) TEK yuvarlamayi kanitlar: fused=0x3A000400, cift-yuvarlama
//  ise 0x3D000000 verirdi.
// ===========================================================================
module tb_cekirdek_fma;

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
   task ktrl_f; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin if (dut.u_frf.yazmac_r[r]!==bek) begin
         $display("  HATA: %0s (f%0d) bek=0x%08h alinan=0x%08h",ad,r,bek,dut.u_frf.yazmac_r[r]); hata=hata+1;
      end else $display("  OK  : %0s (f%0d) = 0x%08h",ad,r,dut.u_frf.yazmac_r[r]); end
   endtask

   initial begin
      for (i=0;i<256;i=i+1) begin imem[i]=32'h00000013; dmem[i]=0; end
      dmem[8'h40] = 32'h40000000; // mem[0x100] = 2.0
      dmem[8'h41] = 32'h40400000; // mem[0x104] = 3.0
      dmem[8'h42] = 32'h3F800000; // mem[0x108] = 1.0
      dmem[8'h43] = 32'h3F800800; // mem[0x10C] = 1+2^-12 (fused ayirici)

      imem[ 0]=32'h10000093; // addi x1,x0,0x100
      imem[ 1]=32'h0000A087; // flw f1,0(x1)  =2.0
      imem[ 2]=32'h0040A107; // flw f2,4(x1)  =3.0
      imem[ 3]=32'h0080A187; // flw f3,8(x1)  =1.0
      imem[ 4]=32'h18208243; // fmadd  f4,f1,f2,f3 = 2*3+1   = 7.0   (RAW: flw sonuclari)
      imem[ 5]=32'h182082C7; // fmsub  f5,f1,f2,f3 = 2*3-1   = 5.0
      imem[ 6]=32'h1820834B; // fnmsub f6,f1,f2,f3 = -(2*3)+1= -5.0
      imem[ 7]=32'h182083CF; // fnmadd f7,f1,f2,f3 = -(2*3)-1= -7.0
      imem[ 8]=32'h00C0A407; // flw f8,12(x1) =1+2^-12
      imem[ 9]=32'h18840547; // fmsub  f10,f8,f8,f3 = a*a-1 (TEK yuvarlama, RAW: f8)
      imem[10]=32'h0000006F; // jal x0,0

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(300) @(posedge clk);

      $display("\n===== RV32F fused multiply-add uctan uca =====");
      ktrl_f("fmadd  f4 = 7.0",  5'd4,  32'h40E00000);
      ktrl_f("fmsub  f5 = 5.0",  5'd5,  32'h40A00000);
      ktrl_f("fnmsub f6 = -5.0", 5'd6,  32'hC0A00000);
      ktrl_f("fnmadd f7 = -7.0", 5'd7,  32'hC0E00000);
      ktrl_f("fmsub  f10 a*a-1 (tek yuvarlama)", 5'd10, 32'h3A000400);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
   initial begin #300000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
