`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_rvc  -  RVC (sikistirilmis) uctan uca testi (Faz 7)
//  - Half-word granuler buyruk bellegi (2-byte hizali getir, straddle dahil)
//  - Sikistirilmis kodlamalar alanlardan uretilir (dogrulanmis cozucunun tersi)
//  - Kapsam: c.li/addi/mv/add, c.sub/xor/or/and, c.slli/srli/srai/andi,
//            c.swsp/lwsp/sw/lw, c.j/jal(link)/beqz/bnez, 32-bit straddle karisimi
// ===========================================================================
module tb_cekirdek_rvc;

   localparam BASE = 32'h8000_0000;

   reg clk=0, rst;
   always #5 clk=~clk;

   // --- Half-word granuler buyruk bellegi ---
   wire [31:0] iadr;
   reg  [15:0] hmem [0:1023];
   wire [9:0]  hidx = (iadr-BASE) >> 1;            // 2-byte hizali indeks
   wire [31:0] ibuf = {hmem[hidx+1], hmem[hidx]};  // byte adresinden 32 bit

   // --- Veri bellegi ---
   wire [31:0] dadr, dwdata; wire doku, dyaz; wire [3:0] dmask;
   reg  [31:0] dmem [0:1023];
   wire [9:0]  didx = dadr[11:2];
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

   // ---------------- Sikistirilmis kodlama ureticileri (cozucunun tersi) -------
   // rp: 3-bit kisitli yazmac (x8+rp)
   function [15:0] cli;  input [4:0] rd; input [5:0] im;
      cli  = {3'b010, im[5], rd, im[4:0], 2'b01}; endfunction
   function [15:0] caddi;input [4:0] rd; input [5:0] im;
      caddi= {3'b000, im[5], rd, im[4:0], 2'b01}; endfunction
   function [15:0] cmv;  input [4:0] rd; input [4:0] rs2;
      cmv  = {3'b100, 1'b0, rd, rs2, 2'b10}; endfunction
   function [15:0] cadd; input [4:0] rd; input [4:0] rs2;
      cadd = {3'b100, 1'b1, rd, rs2, 2'b10}; endfunction
   function [15:0] cslli;input [4:0] rd; input [4:0] sh;
      cslli= {3'b000, 1'b0, rd, sh, 2'b10}; endfunction
   function [15:0] csrli;input [2:0] rp; input [4:0] sh;
      csrli= {3'b100, 1'b0, 2'b00, rp, sh, 2'b01}; endfunction
   function [15:0] csrai;input [2:0] rp; input [4:0] sh;
      csrai= {3'b100, 1'b0, 2'b01, rp, sh, 2'b01}; endfunction
   function [15:0] candi;input [2:0] rp; input [5:0] im;
      candi= {3'b100, im[5], 2'b10, rp, im[4:0], 2'b01}; endfunction
   function [15:0] csub; input [2:0] rd; input [2:0] rs2;
      csub = {3'b100, 1'b0, 2'b11, rd, 2'b00, rs2, 2'b01}; endfunction
   function [15:0] cxor; input [2:0] rd; input [2:0] rs2;
      cxor = {3'b100, 1'b0, 2'b11, rd, 2'b01, rs2, 2'b01}; endfunction
   function [15:0] cor;  input [2:0] rd; input [2:0] rs2;
      cor  = {3'b100, 1'b0, 2'b11, rd, 2'b10, rs2, 2'b01}; endfunction
   function [15:0] cand; input [2:0] rd; input [2:0] rs2;
      cand = {3'b100, 1'b0, 2'b11, rd, 2'b11, rs2, 2'b01}; endfunction
   function [15:0] cswsp;input [4:0] rs2; input [7:0] off; // off[7:2] anlamli
      cswsp= {3'b110, off[5:2], off[7:6], rs2, 2'b10}; endfunction
   function [15:0] clwsp;input [4:0] rd; input [7:0] off;
      clwsp= {3'b010, off[5], rd, off[4:2], off[7:6], 2'b10}; endfunction
   function [15:0] csw;  input [2:0] rs2; input [2:0] rs1; input [6:0] off;
      csw  = {3'b110, off[5:3], rs1, off[2], off[6], rs2, 2'b00}; endfunction
   function [15:0] clw;  input [2:0] rd; input [2:0] rs1; input [6:0] off;
      clw  = {3'b010, off[5:3], rs1, off[2], off[6], rd, 2'b00}; endfunction
   function [15:0] cj;   input signed [11:0] o;
      cj   = {3'b101, o[11], o[4], o[9:8], o[10], o[6], o[7], o[3:1], o[5], 2'b01}; endfunction
   function [15:0] cjal; input signed [11:0] o;
      cjal = {3'b001, o[11], o[4], o[9:8], o[10], o[6], o[7], o[3:1], o[5], 2'b01}; endfunction
   function [15:0] cbeqz;input [2:0] rp; input signed [8:0] o;
      cbeqz= {3'b110, o[8], o[4:3], rp, o[7:6], o[2:1], o[5], 2'b01}; endfunction
   function [15:0] cbnez;input [2:0] rp; input signed [8:0] o;
      cbnez= {3'b111, o[8], o[4:3], rp, o[7:6], o[2:1], o[5], 2'b01}; endfunction

   integer hp;
   task e16; input [15:0] v; begin hmem[hp]=v; hp=hp+1; end endtask
   task e32; input [31:0] v; begin hmem[hp]=v[15:0]; hmem[hp+1]=v[31:16]; hp=hp+2; end endtask

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
      for (i=0;i<1024;i=i+1) begin hmem[i]=16'h0001; dmem[i]=0; end // c.nop dolgu
      hp = 0;
      e16(cli (5'd8,  6'sd10));         // 0  c.li  x8,10
      e16(cli (5'd9,  6'sd20));         // 1  c.li  x9,20
      e16(cmv (5'd10,5'd8));            // 2  c.mv  x10,x8   ->10
      e16(cadd(5'd10,5'd9));            // 3  c.add x10,x9   ->30
      e16(caddi(5'd10,6'sd1));          // 4  c.addi x10,1   ->31  (byte 0x08)
      e32(32'h06450593);                // 5  addi x11,x10,100 ->131  (byte 0x0A: STRADDLE)
      e16(csub(3'd2,3'd1));             // 7  c.sub x10,x9   ->11
      e16(cand(3'd2,3'd0));             // 8  c.and x10,x8   ->10
      e16(cor (3'd3,3'd1));             // 9  c.or  x11,x9   ->151
      e16(cxor(3'd3,3'd0));             //10  c.xor x11,x8   ->157
      e16(cli (5'd12,6'sd7));           //11  c.li  x12,7
      e16(cslli(5'd12,5'd2));           //12  c.slli x12,2   ->28
      e16(csrli(3'd4,5'd1));            //13  c.srli x12,1   ->14
      e16(candi(3'd4,6'sd12));          //14  c.andi x12,12  ->12
      e16(cli (5'd13,-6'sd8));          //15  c.li  x13,-8
      e16(csrai(3'd5,5'd1));            //16  c.srai x13,1   ->-4
      e16(cli (5'd2,6'sd1));            //17  c.li  x2,1
      e16(cslli(5'd2,5'd8));            //18  c.slli x2,8     ->256
      e16(cswsp(5'd12,8'd0));           //19  c.swsp x12,0    mem[0x100]=12
      e16(clwsp(5'd14,8'd0));           //20  c.lwsp x14,0    x14=12
      e16(cli (5'd15,6'sd1));           //21  c.li  x15,1
      e16(cslli(5'd15,5'd9));           //22  c.slli x15,9    ->512=0x200
      e16(csw (3'd0,3'd7,7'd0));        //23  c.sw  x8,0(x15)  mem[0x200]=10
      e16(clw (3'd1,3'd7,7'd0));        //24  c.lw  x9,0(x15)  x9=10
      e16(cj  (12'sd4));                //25  c.j +4 -> h27
      e16(cli (5'd5,6'sd31));           //26  (atlanmali)
      e16(cli (5'd5,-6'sd22));          //27  c.li x5,-22  hedef
      e16(cjal(12'sd4));                //28  c.jal +4 -> h30 ; x1=link
      e16(cli (5'd6,6'sd31));           //29  (atlanmali)
      e16(cli (5'd6,6'sd17));           //30  c.li x6,17  hedef
      e16(cli (5'd14,6'sd0));           //31  c.li x14,0
      e16(cbeqz(3'd6,9'sd4));           //32  c.beqz x14,+4 -> h34 (alinir)
      e16(cli (5'd7,6'sd31));           //33  (atlanmali)
      e16(cli (5'd7,-6'sd31));          //34  c.li x7,-31  hedef
      e16(cbnez(3'd0,9'sd4));           //35  c.bnez x8,+4 -> h37 (alinir)
      e16(cli (5'd4,6'sd1));            //36  (atlanmali)
      e16(cli (5'd4,6'sd2));            //37  c.li x4,2  hedef
      e16(cj  (12'sd0));                //38  c.j 0  (kendine = dur)

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(400) @(posedge clk);

      // jal link byte adresi: h28 -> BASE + 2*28 = 0x80000038, +2 (rvc) = 0x8000003A
      $display("\n===== RVC uctan uca: yazmac degerleri =====");
      ktrl("c.add/mv x10",  5'd10, 32'd10);
      ktrl("addi straddle x11", 5'd11, 32'd157);  // 131|20=151, ^10=157
      ktrl("c.andi x12",    5'd12, 32'd12);
      ktrl("c.srai x13",    5'd13, -32'd4);
      ktrl("c.lwsp/cli x14",5'd14, 32'd0);
      ktrl("c.slli x15",    5'd15, 32'h200);
      ktrl("c.li x2(sp)",   5'd2,  32'h100);
      ktrl("c.lw x9",       5'd9,  32'd10);
      ktrl("c.j hedef x5",  5'd5,  -32'd22);
      ktrl("c.jal link x1", 5'd1,  32'h8000003A);
      ktrl("c.jal hedef x6",5'd6,  32'd17);
      ktrl("c.beqz hedef x7",5'd7, -32'd31);
      ktrl("c.bnez hedef x4",5'd4, 32'd2);

      $display("\n--- veri bellegi ---");
      if (dmem[10'h040] !== 32'd12) begin $display("  HATA: mem[0x100]=0x%08h",dmem[10'h040]); hata=hata+1; end
      else $display("  OK  : mem[0x100]=%0d", dmem[10'h040]);
      if (dmem[10'h080] !== 32'd10) begin $display("  HATA: mem[0x200]=0x%08h",dmem[10'h080]); hata=hata+1; end
      else $display("  OK  : mem[0x200]=%0d", dmem[10'h080]);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end

   initial begin #300000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
