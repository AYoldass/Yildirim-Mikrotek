`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_a  -  RV32A (atomik) uctan uca testi (Faz 6)
//  - AMO*: AMOADD/SWAP/OR/AND/MIN/MAX (eski deger -> rd, sonuc -> bellek)
//  - LR.W / SC.W: rezervasyon, basarili SC (rd=0) ve rezervasyonsuz SC (rd=1)
//  - Her adimda bellek evrimi dogrulanir
// ===========================================================================
module tb_cekirdek_a;

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

      imem[ 0] = 32'h10000513; // addi x10,x0,0x100      base=0x100
      imem[ 1] = 32'h06400593; // addi x11,x0,100        x11=100
      imem[ 2] = 32'h00B52023; // sw   x11,0(x10)        mem=100
      imem[ 3] = 32'h00B5262F; // amoadd.w  x12,x11,(x10) x12=100; mem=200
      imem[ 4] = 32'h08B526AF; // amoswap.w x13,x11,(x10) x13=200; mem=100
      imem[ 5] = 32'h00F00813; // addi x16,x0,0x0F       x16=15
      imem[ 6] = 32'h4105272F; // amoor.w   x14,x16,(x10) x14=100; mem=111
      imem[ 7] = 32'h610527AF; // amoand.w  x15,x16,(x10) x15=111; mem=15
      imem[ 8] = 32'h00052883; // lw   x17,0(x10)        x17=15
      imem[ 9] = 32'h1005292F; // lr.w x18,(x10)         x18=15; rezerve
      imem[10] = 32'h04D00993; // addi x19,x0,77         x19=77
      imem[11] = 32'h19352A2F; // sc.w x20,x19,(x10)     basari: mem=77, x20=0
      imem[12] = 32'h00052A83; // lw   x21,0(x10)        x21=77
      imem[13] = 32'h18B52B2F; // sc.w x22,x11,(x10)     rezervasyon yok: x22=1, mem=77
      imem[14] = 32'h00052B83; // lw   x23,0(x10)        x23=77
      imem[15] = 32'hFFB00C13; // addi x24,x0,-5         x24=-5
      imem[16] = 32'h81852CAF; // amomin.w  x25,x24,(x10) x25=77; mem=-5
      imem[17] = 32'hA0B52D2F; // amomax.w  x26,x11,(x10) x26=-5; mem=100
      imem[18] = 32'h00052D83; // lw   x27,0(x10)        x27=100
      imem[19] = 32'h0000006F; // jal  x0,0             dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(200) @(posedge clk);

      $display("\n===== RV32A uctan uca: yazmac degerleri =====");
      ktrl("amoadd  eski",  5'd12, 32'd100);
      ktrl("amoswap eski",  5'd13, 32'd200);
      ktrl("amoor   eski",  5'd14, 32'd100);
      ktrl("amoand  eski",  5'd15, 32'd111);
      ktrl("lw sonra and",  5'd17, 32'd15);
      ktrl("lr.w",          5'd18, 32'd15);
      ktrl("sc.w basari",   5'd20, 32'd0);
      ktrl("lw sonra sc",   5'd21, 32'd77);
      ktrl("sc.w basarisiz",5'd22, 32'd1);
      ktrl("lw sc sonrasi", 5'd23, 32'd77);
      ktrl("amomin eski",   5'd25, 32'd77);
      ktrl("amomax eski",   5'd26, -32'd5);
      ktrl("lw son",        5'd27, 32'd100);

      $display("\n--- veri bellegi (mem[0x100]) ---");
      if (dmem[8'h40] !== 32'd100) begin $display("  HATA: mem[0x100]=0x%08h",dmem[8'h40]); hata=hata+1; end
      else $display("  OK  : mem[0x100]=%0d", dmem[8'h40]);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end

   initial begin #200000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
