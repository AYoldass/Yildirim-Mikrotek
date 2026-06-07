`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_fdiv  -  RV32F FDIV.S / FSQRT.S uctan uca testi
//  fpu_temiz'e eklenen kombinasyonel bolme/karekok'un cekirdek uzerinden
//  (decode yonlendirme + F scoreboard RAW + f-regfile geri-yazma) dogrulanmasi.
// ===========================================================================
module tb_cekirdek_fdiv;

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
      begin
         if (dut.u_frf.yazmac_r[r] !== bek) begin
            $display("  HATA: %0s (f%0d) beklenen=0x%08h alinan=0x%08h", ad, r, bek, dut.u_frf.yazmac_r[r]); hata=hata+1;
         end else $display("  OK  : %0s (f%0d) = 0x%08h", ad, r, dut.u_frf.yazmac_r[r]);
      end
   endtask

   initial begin
      for (i=0;i<256;i=i+1) begin imem[i]=32'h00000013; dmem[i]=0; end
      dmem[8'h40] = 32'h40000000; // mem[0x100] = 2.0
      dmem[8'h41] = 32'h41800000; // mem[0x104] = 16.0

      imem[ 0]=32'h10000093; // addi x1,x0,0x100
      imem[ 1]=32'h0000A087; // flw f1,0(x1)        f1=2.0
      imem[ 2]=32'h0040A107; // flw f2,4(x1)        f2=16.0
      imem[ 3]=32'h181101D3; // fdiv.s f3,f2,f1     f3=16/2=8.0  (RAW: FLW sonuclari)
      imem[ 4]=32'h58010253; // fsqrt.s f4,f2       f4=sqrt(16)=4.0
      imem[ 5]=32'h580082D3; // fsqrt.s f5,f1       f5=sqrt(2)=1.4142 (RNE)
      imem[ 6]=32'h18208353; // fdiv.s f6,f1,f2     f6=2/16=0.125
      imem[ 7]=32'h580183D3; // fsqrt.s f7,f3       f7=sqrt(8)=2.8284 (RAW: fdiv sonucu f3)
      imem[ 8]=32'h0000006F; // jal x0,0           dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(300) @(posedge clk);

      $display("\n===== RV32F FDIV / FSQRT uctan uca =====");
      ktrl_f("flw   f1",      5'd1, 32'h40000000); // 2.0
      ktrl_f("flw   f2",      5'd2, 32'h41800000); // 16.0
      ktrl_f("fdiv  f3=16/2", 5'd3, 32'h41000000); // 8.0
      ktrl_f("fsqrt f4=sq16", 5'd4, 32'h40800000); // 4.0
      ktrl_f("fsqrt f5=sq2",  5'd5, 32'h3FB504F3); // 1.41421356
      ktrl_f("fdiv  f6=2/16", 5'd6, 32'h3E000000); // 0.125
      ktrl_f("fsqrt f7=sq8",  5'd7, 32'h403504F3); // 2.82842712 (RAW f3)

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
   initial begin #300000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
