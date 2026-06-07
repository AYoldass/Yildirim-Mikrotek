`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_soc_l1  -  L1 veri onbellekli SoC testi (tam bellek hiyerarsisi)
//  Veri 0x4000_0000 bolgesinde (onbelleklenebilir). Senaryo:
//   - store/load: miss->allocate, hit
//   - ayni satira 3. tag -> EVICTION (kirli yol write-back) + yeniden getir
//  cekirdek -> kopru -> veri_yolu_birimi -> L1 -> {l1_sram, ana_bellek}
// ===========================================================================
module tb_soc_l1;

   reg clk=0, rst;
   always #5 clk=~clk;

   soc_l1 #(.IKELIME(1024), .DKELIME(8192)) dut (.clk_i(clk), .rst_i(rst));

   integer hata=0, i;
   task kx; input [127:0] ad; input [4:0] r; input [31:0] bek;
      begin if (dut.u_cekirdek.u_rf.yazmac_r[r]!==bek) begin
         $display("  HATA: %0s (x%0d) bek=0x%02h alinan=0x%08h",ad,r,bek,dut.u_cekirdek.u_rf.yazmac_r[r]); hata=hata+1;
      end else $display("  OK  : %0s (x%0d) = 0x%02h",ad,r,dut.u_cekirdek.u_rf.yazmac_r[r]); end
   endtask

   initial begin
      for (i=0;i<1024;i=i+1) dut.ibellek[i] = 32'h00000013;

      dut.ibellek[ 0]=32'h400000B7; // lui  x1,0x40000     x1=0x40000000 (onbelleklenebilir veri)
      dut.ibellek[ 1]=32'h0AA00113; // addi x2,x0,0xAA
      dut.ibellek[ 2]=32'h0020A023; // sw   x2,0(x1)       mem[0]=0xAA   (line0 miss->alloc)
      dut.ibellek[ 3]=32'h0BB00393; // addi x7,x0,0xBB
      dut.ibellek[ 4]=32'h0070A223; // sw   x7,4(x1)       mem[4]=0xBB   (line1 alloc)
      dut.ibellek[ 5]=32'h0000A183; // lw   x3,0(x1)       x3=0xAA (hit)
      dut.ibellek[ 6]=32'h0040A203; // lw   x4,4(x1)       x4=0xBB (hit)
      dut.ibellek[ 7]=32'h40008493; // addi x9,x1,0x400    x9=0x40000400
      dut.ibellek[ 8]=32'h0CC00413; // addi x8,x0,0xCC
      dut.ibellek[ 9]=32'h0084A023; // sw   x8,0(x9)       mem[0x400]=0xCC (line0 tag2->way1)
      dut.ibellek[10]=32'h40048593; // addi x11,x9,0x400   x11=0x40000800
      dut.ibellek[11]=32'h0DD00513; // addi x10,x0,0xDD
      dut.ibellek[12]=32'h00A5A023; // sw   x10,0(x11)     mem[0x800]=0xDD (line0 tag3->EVICT+writeback)
      dut.ibellek[13]=32'h0000A283; // lw   x5,0(x1)       x5=0xAA (evict->refetch)
      dut.ibellek[14]=32'h0005A303; // lw   x6,0(x11)      x6=0xDD
      dut.ibellek[15]=32'h0000006F; // jal  x0,0          dur

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(600) @(posedge clk);

      $display("\n===== L1 onbellekli SoC =====");
      kx("lw hit x3",        5'd3, 32'hAA);
      kx("lw hit x4",        5'd4, 32'hBB);
      kx("lw evict-refetch x5", 5'd5, 32'hAA);
      kx("lw x6",            5'd6, 32'hDD);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
   initial begin #200000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
