`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_f  -  RV32F (kayan nokta) uctan uca testi (Faz 9)
//  - FLW/FSW (bellek <-> f-reg), FADD/FSUB/FMUL (FLW sonucuna RAW = F scoreboard)
//  - FEQ/FLT, FCVT.W.S / FCVT.S.W, FMV.X.W, FSGNJN, FMIN
// ===========================================================================
module tb_cekirdek_f;

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
      begin
         if (dut.u_rf.yazmac_r[r] !== bek) begin
            $display("  HATA: %0s (x%0d) beklenen=0x%08h alinan=0x%08h", ad, r, bek, dut.u_rf.yazmac_r[r]); hata=hata+1;
         end else $display("  OK  : %0s (x%0d) = 0x%08h", ad, r, dut.u_rf.yazmac_r[r]);
      end
   endtask
   task ktrl_f; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin
         if (dut.u_frf.yazmac_r[r] !== bek) begin
            $display("  HATA: %0s (f%0d) beklenen=0x%08h alinan=0x%08h", ad, r, bek, dut.u_frf.yazmac_r[r]); hata=hata+1;
         end else $display("  OK  : %0s (f%0d) = 0x%08h", ad, r, dut.u_frf.yazmac_r[r]);
      end
   endtask

   initial begin
      for (i=0;i<256;i=i+1) begin imem[i]=32'h00000013; dmem[i]=0; end
      dmem[8'h40] = 32'h3FC00000; // mem[0x100] = 1.5
      dmem[8'h41] = 32'h40100000; // mem[0x104] = 2.25

      imem[ 0]=32'h10000093; // addi x1,x0,0x100
      imem[ 1]=32'h0000A107; // flw  f2,0(x1)        f2=1.5
      imem[ 2]=32'h0040A187; // flw  f3,4(x1)        f3=2.25
      imem[ 3]=32'h00310253; // fadd.s f4,f2,f3      f4=3.75  (RAW: FLW sonuclari)
      imem[ 4]=32'h103102D3; // fmul.s f5,f2,f3      f5=3.375
      imem[ 5]=32'h08218353; // fsub.s f6,f3,f2      f6=0.75
      imem[ 6]=32'h0040A427; // fsw  f4,8(x1)        mem[0x108]=3.75
      imem[ 7]=32'h0050A627; // fsw  f5,12(x1)       mem[0x10C]=3.375
      imem[ 8]=32'hA0212553; // feq.s x10,f2,f2      x10=1
      imem[ 9]=32'hA03115D3; // flt.s x11,f2,f3      x11=1
      imem[10]=32'hC0020653; // fcvt.w.s x12,f4      x12=3
      imem[11]=32'hD00083D3; // fcvt.s.w f7,x1       f7=256.0
      imem[12]=32'hE00106D3; // fmv.x.w x13,f2       x13=0x3FC00000
      imem[13]=32'h20311453; // fsgnjn.s f8,f2,f3    f8=-1.5
      imem[14]=32'h282304D3; // fmin.s f9,f6,f2      f9=0.75
      imem[15]=32'h0000006F; // jal x0,0            dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(300) @(posedge clk);

      $display("\n===== RV32F uctan uca =====");
      ktrl_f("flw f2",     5'd2,  32'h3FC00000);
      ktrl_f("flw f3",     5'd3,  32'h40100000);
      ktrl_f("fadd f4",    5'd4,  32'h40700000); // 3.75
      ktrl_f("fmul f5",    5'd5,  32'h40580000); // 3.375
      ktrl_f("fsub f6",    5'd6,  32'h3F400000); // 0.75
      ktrl_x("feq x10",    5'd10, 32'd1);
      ktrl_x("flt x11",    5'd11, 32'd1);
      ktrl_x("fcvt.w.s x12",5'd12,32'd3);
      ktrl_f("fcvt.s.w f7",5'd7,  32'h43800000); // 256.0
      ktrl_x("fmv.x.w x13",5'd13, 32'h3FC00000);
      ktrl_f("fsgnjn f8",  5'd8,  32'hBFC00000); // -1.5
      ktrl_f("fmin f9",    5'd9,  32'h3F400000); // 0.75

      $display("\n--- veri bellegi ---");
      if (dmem[8'h42]!==32'h40700000) begin $display("  HATA: mem[0x108]=0x%08h",dmem[8'h42]); hata=hata+1; end
      else $display("  OK  : mem[0x108]=0x%08h (3.75)", dmem[8'h42]);
      if (dmem[8'h43]!==32'h40580000) begin $display("  HATA: mem[0x10C]=0x%08h",dmem[8'h43]); hata=hata+1; end
      else $display("  OK  : mem[0x10C]=0x%08h (3.375)", dmem[8'h43]);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
   initial begin #300000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
