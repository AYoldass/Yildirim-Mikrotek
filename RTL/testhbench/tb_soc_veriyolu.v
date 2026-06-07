`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_soc_veriyolu  -  GERCEK veri_yolu_birimi ile SoC testi
//  Veri erisimleri (yuk/sakla) depodaki veri_yolu_birimi uzerinden cok-cevrimli
//  yapilir; cekirdek wait-state (mem_bekle) ile dogru calisir.
//  Yuk sonucuna RAW bagimlilik (bus gecikmesi + scoreboard) dahil.
// ===========================================================================
module tb_soc_veriyolu;

   reg clk=0, rst;
   always #5 clk=~clk;

   soc_veriyolu #(.KELIME(8192)) dut (.clk_i(clk), .rst_i(rst));

   integer hata=0, i;
   task kx; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin if (dut.u_cekirdek.u_rf.yazmac_r[r]!==bek) begin
         $display("  HATA: %0s (x%0d) bek=%0d alinan=%0d",ad,r,bek,dut.u_cekirdek.u_rf.yazmac_r[r]); hata=hata+1;
      end else $display("  OK  : %0s (x%0d) = %0d",ad,r,dut.u_cekirdek.u_rf.yazmac_r[r]); end
   endtask

   initial begin
      for (i=0;i<8192;i=i+1) dut.u_ram.ram[i] = 32'h00000013;

      dut.u_ram.ram[ 0]=32'h800000B7; // lui  x1,0x80000
      dut.u_ram.ram[ 1]=32'h40008093; // addi x1,x1,0x400   x1=0x80000400 (veri tabani)
      dut.u_ram.ram[ 2]=32'h06F00113; // addi x2,x0,111
      dut.u_ram.ram[ 3]=32'h0020A023; // sw   x2,0(x1)       mem[0x400]=111
      dut.u_ram.ram[ 4]=32'h0000A183; // lw   x3,0(x1)       x3=111 (RAW bus uzerinden)
      dut.u_ram.ram[ 5]=32'h00118213; // addi x4,x3,1        x4=112
      dut.u_ram.ram[ 6]=32'h0040A223; // sw   x4,4(x1)       mem[0x404]=112
      dut.u_ram.ram[ 7]=32'h0040A283; // lw   x5,4(x1)       x5=112
      dut.u_ram.ram[ 8]=32'h00009303; // lh   x6,0(x1)       x6=111
      dut.u_ram.ram[ 9]=32'h0040C383; // lbu  x7,4(x1)       x7=112
      dut.u_ram.ram[10]=32'h0000A503; // lw   x10,0(x1)      x10=111
      dut.u_ram.ram[11]=32'h0040A583; // lw   x11,4(x1)      x11=112
      dut.u_ram.ram[12]=32'h00B504B3; // add  x9,x10,x11     x9=223
      dut.u_ram.ram[13]=32'h0000006F; // jal  x0,0          dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(300) @(posedge clk);

      $display("\n===== Gercek veri_yolu_birimi ile SoC =====");
      kx("lw x3 (RAW)",  5'd3, 32'd111);
      kx("addi x4",      5'd4, 32'd112);
      kx("lw x5",        5'd5, 32'd112);
      kx("lh x6",        5'd6, 32'd111);
      kx("lbu x7",       5'd7, 32'd112);
      kx("add x9 (toplam)",5'd9,32'd223);

      $display("\n--- veri bellegi (port_bellek) ---");
      if (dut.u_ram.ram[256]!==32'd111) begin $display("  HATA: mem[0x400]=%0d",dut.u_ram.ram[256]); hata=hata+1; end
      else $display("  OK  : mem[0x400]=111");
      if (dut.u_ram.ram[257]!==32'd112) begin $display("  HATA: mem[0x404]=%0d",dut.u_ram.ram[257]); hata=hata+1; end
      else $display("  OK  : mem[0x404]=112");

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
   initial begin #200000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
