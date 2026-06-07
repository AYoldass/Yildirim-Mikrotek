`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek  -  Cekirdek UCTAN UCA testi (Faz 3 + Faz 4)
//  - Bagimli buyruk dizisi (RAW hazard -> scoreboard kilidi)
//  - Yukleme/Saklama (LW/SW, LH/LHU/SH, LB/LBU/SB; isaret/sifir genisletme)
//  - Alinan kosullu dallanma (yanlis tahmin -> flush+yonlendir) ve JAL
// ===========================================================================
module tb_cekirdek;

   localparam BASE = 32'h8000_0000;

   reg clk=0, rst;
   always #5 clk=~clk;

   // --- Kombinasyonel buyruk bellegi ---
   wire [31:0] iadr;
   reg  [31:0] imem [0:255];
   wire [7:0]  iidx = (iadr-BASE)>>2;
   wire [31:0] ibuf = imem[iidx];

   // --- Veri bellegi (kombinasyonel okuma, senkron maskeli yazma) ---
   wire [31:0] dadr, dwdata; wire doku, dyaz; wire [3:0] dmask;
   reg  [31:0] dmem [0:255];
   wire [7:0]  didx = dadr[9:2];
   wire [31:0] drdata = dmem[didx];
   integer b;
   always @(posedge clk) begin
      if (dyaz) for (b=0;b<4;b=b+1) if (dmask[b]) dmem[didx][b*8 +: 8] <= dwdata[b*8 +: 8];
   end

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

      // --- BOLUM 1: ALU + hazard ---
      imem[0]  = 32'h00500093; // addi x1,x0,5       x1=5
      imem[1]  = 32'h00A00113; // addi x2,x0,10      x2=10
      imem[2]  = 32'h002081B3; // add  x3,x1,x2      x3=15  (RAW)
      imem[3]  = 32'h40118233; // sub  x4,x3,x1      x4=10  (RAW)
      imem[4]  = 32'h00209293; // slli x5,x1,2       x5=20
      imem[5]  = 32'h00317333; // and  x6,x2,x3      x6=10
      // --- BOLUM 2: dallanma + jal ---
      imem[6]  = 32'h00108463; // beq  x1,x1,+8      alinir -> imem[8]
      imem[7]  = 32'h06300393; // addi x7,x0,99      ATLANMALI (x7=0)
      imem[8]  = 32'h00700413; // addi x8,x0,7       x8=7
      imem[9]  = 32'h008004EF; // jal  x9,+8         x9=link, hedef imem[11]
      imem[10] = 32'h05800513; // addi x10,x0,88     ATLANMALI (x10=0)
      // --- BOLUM 3: yukleme/saklama (x11 taban adres) ---
      imem[11] = 32'h10000593; // addi x11,x0,256    x11=0x100 (data taban)
      imem[12] = 32'h00B5A023; // sw   x11,0(x11)    mem[0x100]=0x100
      imem[13] = 32'h0005A603; // lw   x12,0(x11)    x12=0x100
      imem[14] = 32'h12300693; // addi x13,x0,291    x13=0x123
      imem[15] = 32'h00D59223; // sh   x13,4(x11)    mem[0x104]=0x0123
      imem[16] = 32'h0045D703; // lhu  x14,4(x11)    x14=0x123
      imem[17] = 32'h00459783; // lh   x15,4(x11)    x15=0x123
      imem[18] = 32'hFFF00813; // addi x16,x0,-1     x16=0xFFFFFFFF
      imem[19] = 32'h01058423; // sb   x16,8(x11)    mem[0x108] byte0=0xFF
      imem[20] = 32'h0085C883; // lbu  x17,8(x11)    x17=0xFF (255)
      imem[21] = 32'h00858903; // lb   x18,8(x11)    x18=0xFFFFFFFF (-1)
      imem[22] = 32'h0000006F; // jal  x0,0          dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(250) @(posedge clk);

      $display("\n===== Cekirdek uctan uca: yazmac degerleri =====");
      ktrl("addi",  5'd1,  32'd5);
      ktrl("addi",  5'd2,  32'd10);
      ktrl("add",   5'd3,  32'd15);
      ktrl("sub",   5'd4,  32'd10);
      ktrl("slli",  5'd5,  32'd20);
      ktrl("and",   5'd6,  32'd10);
      ktrl("beq-atlanan", 5'd7, 32'd0);
      ktrl("addi",  5'd8,  32'd7);
      ktrl("jal-link",    5'd9, 32'h80000028);
      ktrl("jal-atlanan", 5'd10, 32'd0);
      ktrl("addi(taban)", 5'd11, 32'h100);
      ktrl("lw",    5'd12, 32'h100);
      ktrl("addi",  5'd13, 32'h123);
      ktrl("lhu",   5'd14, 32'h123);
      ktrl("lh",    5'd15, 32'h123);
      ktrl("addi-1",5'd16, 32'hFFFFFFFF);
      ktrl("lbu",   5'd17, 32'h000000FF);
      ktrl("lb",    5'd18, 32'hFFFFFFFF);

      $display("\n--- veri bellegi ---");
      if (dmem[8'h40] !== 32'h100) begin $display("  HATA: mem[0x100]=0x%08h",dmem[8'h40]); hata=hata+1; end
      else $display("  OK  : mem[0x100]=0x%08h", dmem[8'h40]);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end

   initial begin #100000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
