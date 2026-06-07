`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_b  -  RV32B (bit-manipulasyon) uctan uca testi (Faz 9)
//  - ANDN/ORN/XNOR, MIN/MAX/MINU/MAXU, ROL/ROR/RORI,
//    CLZ/CTZ/CPOP/SEXT.B/SEXT.H, SH1/2/3ADD, CLMUL
//  - Cok-cevrimli B birimine handshake ile baglanir; B sonucuna RAW bagimlilik
//  Beklenen degerler Verilog ifadeleriyle hesaplanir (el-kodlama hatasi azaltma).
// ===========================================================================
module tb_cekirdek_b;

   localparam BASE = 32'h8000_0000;
   localparam [31:0] V1 = 32'hF0F0F0F0, V2 = 32'h0F0FFFFF, V3 = 32'h00010000;
   localparam [31:0] V4 = -32'd5, V5 = 32'd10;

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
   cekirdek dut (
      .clk_i(clk), .rst_i(rst), .bel_adres_o(iadr), .bel_buyruk_i(ibuf),
      .veri_adres_o(dadr), .veri_oku_o(doku), .veri_yaz_o(dyaz),
      .veri_yaz_veri_o(dwdata), .veri_maske_o(dmask), .veri_oku_veri_i(drdata), .veri_hazir_i(1'b1)
   );

   function [31:0] clmul; input [31:0] a,b; integer i; begin
      clmul=0; for(i=0;i<32;i=i+1) if(b[i]) clmul=clmul^(a<<i); end endfunction

   integer hata=0, i;
   task ktrl; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin
         if (dut.u_rf.yazmac_r[r] !== bek) begin
            $display("  HATA: %0s (x%0d) beklenen=0x%08h alinan=0x%08h", ad, r, bek, dut.u_rf.yazmac_r[r]);
            hata=hata+1;
         end else
            $display("  OK  : %0s (x%0d) = 0x%08h", ad, r, dut.u_rf.yazmac_r[r]);
      end
   endtask

   initial begin
      for (i=0;i<256;i=i+1) begin imem[i]=32'h00000013; dmem[i]=0; end

      // --- operand kurulumu ---
      imem[ 0]=32'hF0F0F0B7; // lui  x1,0xF0F0F
      imem[ 1]=32'h0F008093; // addi x1,x1,0xF0     x1=0xF0F0F0F0
      imem[ 2]=32'h0F100137; // lui  x2,0x0F100
      imem[ 3]=32'hFFF10113; // addi x2,x2,-1       x2=0x0F0FFFFF
      imem[ 4]=32'h000101B7; // lui  x3,0x10        x3=0x00010000
      imem[ 5]=32'hFFB00213; // addi x4,x0,-5       x4=-5
      imem[ 6]=32'h00A00293; // addi x5,x0,10       x5=10
      // --- B buyruklari ---
      imem[ 7]=32'h4020F333; // andn  x6,x1,x2
      imem[ 8]=32'h4020E3B3; // orn   x7,x1,x2
      imem[ 9]=32'h4020C433; // xnor  x8,x1,x2
      imem[10]=32'h0A5244B3; // min   x9,x4,x5
      imem[11]=32'h0A525533; // max   x10,x4,x5
      imem[12]=32'h0A5265B3; // minu  x11,x4,x5
      imem[13]=32'h0A527633; // maxu  x12,x4,x5
      imem[14]=32'h605096B3; // rol   x13,x1,x5
      imem[15]=32'h6050D733; // ror   x14,x1,x5
      imem[16]=32'h6040D793; // rori  x15,x1,4
      imem[17]=32'h60019813; // clz   x16,x3
      imem[18]=32'h60119893; // ctz   x17,x3
      imem[19]=32'h60209913; // cpop  x18,x1
      imem[20]=32'h60421993; // sext.b x19,x4
      imem[21]=32'h60519A13; // sext.h x20,x3
      imem[22]=32'h2042AAB3; // sh1add x21,x5,x4
      imem[23]=32'h2042CB33; // sh2add x22,x5,x4
      imem[24]=32'h2042EBB3; // sh3add x23,x5,x4
      imem[25]=32'h0A529C33; // clmul x24,x5,x5
      imem[26]=32'h00180C93; // addi  x25,x16,1   (RAW: cok-cevrim clz sonucu)
      imem[27]=32'h0000006F; // jal   x0,0       dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(400) @(posedge clk);

      $display("\n===== RV32B uctan uca: yazmac degerleri =====");
      ktrl("andn",  5'd6,  V1 & ~V2);
      ktrl("orn",   5'd7,  V1 | ~V2);
      ktrl("xnor",  5'd8,  ~(V1 ^ V2));
      ktrl("min",   5'd9,  V4);                 // min(-5,10)=-5
      ktrl("max",   5'd10, V5);                 // 10
      ktrl("minu",  5'd11, V5);                 // 10
      ktrl("maxu",  5'd12, V4);                 // 0xFFFFFFFB
      ktrl("rol",   5'd13, (V1<<10)|(V1>>22));
      ktrl("ror",   5'd14, (V1>>10)|(V1<<22));
      ktrl("rori4", 5'd15, (V1>>4)|(V1<<28));
      ktrl("clz",   5'd16, 32'd15);
      ktrl("ctz",   5'd17, 32'd16);
      ktrl("cpop",  5'd18, 32'd16);
      ktrl("sext.b",5'd19, 32'hFFFFFFFB);
      ktrl("sext.h",5'd20, 32'd0);
      ktrl("sh1add",5'd21, (V5<<1)+V4);         // 15
      ktrl("sh2add",5'd22, (V5<<2)+V4);         // 35
      ktrl("sh3add",5'd23, (V5<<3)+V4);         // 75
      ktrl("clmul", 5'd24, clmul(V5,V5));       // 68
      ktrl("RAW clz+1", 5'd25, 32'd16);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end

   initial begin #300000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
