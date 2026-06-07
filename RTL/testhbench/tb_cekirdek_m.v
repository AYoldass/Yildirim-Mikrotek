`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_m  -  RV32M uctan uca testi
//  - CARPMA: MUL / MULH / MULHU / MULHSU (kombinasyonel, 1 cevrim)
//  - BOLME : DIV / DIVU / REM / REMU (cok-cevrimli ~18 cevrim, mesgul stall)
//  - Cok-cevrimli bolme sonucuna RAW bagimlilik (mesgul + scoreboard kilidi)
//  - Ardisik (back-to-back) bolmeler; isaretli; sifira bolme/mod
// ===========================================================================
module tb_cekirdek_m;

   localparam BASE = 32'h8000_0000;

   reg clk=0, rst;
   always #5 clk=~clk;

   // --- Kombinasyonel buyruk bellegi ---
   wire [31:0] iadr;
   reg  [31:0] imem [0:255];
   wire [7:0]  iidx = (iadr-BASE)>>2;
   wire [31:0] ibuf = imem[iidx];

   // --- Veri bellegi (bu test kullanmiyor; baglanti icin) ---
   wire [31:0] dadr, dwdata; wire doku, dyaz; wire [3:0] dmask;
   reg  [31:0] dmem [0:255];
   wire [7:0]  didx = dadr[9:2];
   wire [31:0] drdata = dmem[didx];
   integer b;
   always @(posedge clk)
      if (dyaz) for (b=0;b<4;b=b+1) if (dmask[b]) dmem[didx][b*8 +: 8] <= dwdata[b*8 +: 8];

   cekirdek dut (
      .clk_i(clk), .rst_i(rst),
      .bel_adres_o(iadr), .bel_buyruk_i(ibuf),
      .veri_adres_o(dadr), .veri_oku_o(doku), .veri_yaz_o(dyaz),
      .veri_yaz_veri_o(dwdata), .veri_maske_o(dmask), .veri_oku_veri_i(drdata), .veri_hazir_i(1'b1)
   );

   integer hata=0, i;
   task ktrl; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin
         if (dut.u_rf.yazmac_r[r] !== bek) begin
            $display("  HATA: %0s (x%0d) beklenen=0x%08h alinan=0x%08h", ad, r, bek, dut.u_rf.yazmac_r[r]);
            hata=hata+1;
         end else
            $display("  OK  : %0s (x%0d) = %0d (0x%08h)", ad, r, $signed(dut.u_rf.yazmac_r[r]), dut.u_rf.yazmac_r[r]);
      end
   endtask

   initial begin
      for (i=0;i<256;i=i+1) begin imem[i]=32'h00000013; dmem[i]=0; end

      imem[ 0] = 32'h00700093; // addi  x1,x0,7        x1=7
      imem[ 1] = 32'h00600113; // addi  x2,x0,6        x2=6
      imem[ 2] = 32'h022081B3; // mul   x3,x1,x2       x3=42
      imem[ 3] = 32'h001182B3; // add   x5,x3,x1       x5=49  (RAW: carpma sonucu)
      imem[ 4] = 32'hFFF00313; // addi  x6,x0,-1       x6=0xFFFFFFFF
      imem[ 5] = 32'h02631433; // mulh  x8,x6,x6       x8=0          ((-1)*(-1))>>32
      imem[ 6] = 32'h026334B3; // mulhu x9,x6,x6       x9=0xFFFFFFFE (uxu)>>32
      imem[ 7] = 32'h02132533; // mulhsu x10,x6,x1     x10=0xFFFFFFFF (-1 s * 7 u)>>32
      imem[ 8] = 32'h0211C5B3; // div   x11,x3,x1      x11=6   (cok-cevrim)
      imem[ 9] = 32'h00158613; // addi  x12,x11,1      x12=7   (RAW: cok-cevrim bolme sonucu)
      imem[10] = 32'h0220E6B3; // rem   x13,x1,x2      x13=1   (7 % 6)
      imem[11] = 32'h02135733; // divu  x14,x6,x1      x14=613566756 (0xFFFFFFFF / 7)
      imem[12] = 32'h021377B3; // remu  x15,x6,x1      x15=3   (0xFFFFFFFF % 7)
      imem[13] = 32'h0211C833; // div   x16,x3,x1      x16=6
      imem[14] = 32'h021748B3; // div   x17,x14,x1     x17=87652393 (ardisik cok-cevrim, RAW)
      imem[15] = 32'h0200D933; // divu  x18,x1,x0      x18=0xFFFFFFFF (sifira bolme)
      imem[16] = 32'h0200E9B3; // rem   x19,x1,x0      x19=7  (sifira mod -> bolunen)
      imem[17] = 32'h40300B33; // sub   x22,x0,x3      x22=-42
      imem[18] = 32'h021B4BB3; // div   x23,x22,x1     x23=-6  (isaretli)
      imem[19] = 32'h02136C33; // rem   x24,x6,x1      x24=-1  (-1 % 7, isaret bolunenden)
      imem[20] = 32'h0000006F; // jal   x0,0          dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(600) @(posedge clk);

      $display("\n===== RV32M uctan uca: yazmac degerleri =====");
      ktrl("mul",     5'd3,  32'd42);
      ktrl("add(RAW)",5'd5,  32'd49);
      ktrl("mulh",    5'd8,  32'd0);
      ktrl("mulhu",   5'd9,  32'hFFFFFFFE);
      ktrl("mulhsu",  5'd10, 32'hFFFFFFFF);
      ktrl("div",     5'd11, 32'd6);
      ktrl("addi(RAW-div)", 5'd12, 32'd7);
      ktrl("rem",     5'd13, 32'd1);
      ktrl("divu",    5'd14, 32'd613566756);
      ktrl("remu",    5'd15, 32'd3);
      ktrl("div2",    5'd16, 32'd6);
      ktrl("div(RAW-div)", 5'd17, 32'd87652393);
      ktrl("divu/0",  5'd18, 32'hFFFFFFFF);
      ktrl("rem/0",   5'd19, 32'd7);
      ktrl("sub",     5'd22, -32'd42);
      ktrl("div(isaretli)", 5'd23, -32'd6);
      ktrl("rem(isaretli)", 5'd24, 32'hFFFFFFFF);
      ktrl("x0",      5'd0,  32'd0);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end

   initial begin #200000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
