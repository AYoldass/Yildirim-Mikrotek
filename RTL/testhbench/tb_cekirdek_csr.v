`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_csr  -  CSR + Trap (Faz 5) uctan uca testi
//  - CSR oku/yaz: CSRRW/CSRRS (eski deger -> rd, yeni deger -> CSR)
//  - mtvec ayarlama, mscratch yaz/oku
//  - ECALL -> mtvec'teki handler'a tuzak (mepc=ecall PC, mcause=11)
//  - Handler: mcause/mepc oku, mepc+=4 yaz, MRET ile geri don
//  - mcycle sayaci calisiyor mu
// ===========================================================================
module tb_cekirdek_csr;

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
            $display("  OK  : %0s (x%0d) = 0x%08h", ad, r, dut.u_rf.yazmac_r[r]);
      end
   endtask

   initial begin
      for (i=0;i<256;i=i+1) begin imem[i]=32'h00000013; dmem[i]=0; end

      // --- Ana program ---
      imem[ 0] = 32'h800000B7; // lui   x1,0x80000     x1=0x80000000
      imem[ 1] = 32'h08008093; // addi  x1,x1,0x80     x1=0x80000080 (handler)
      imem[ 2] = 32'h30509073; // csrrw x0,mtvec,x1     mtvec=0x80000080
      imem[ 3] = 32'h11100293; // addi  x5,x0,0x111     x5=0x111
      imem[ 4] = 32'h34029373; // csrrw x6,mscratch,x5  mscratch=0x111, x6=eski(0)
      imem[ 5] = 32'h340023F3; // csrrs x7,mscratch,x0  x7=mscratch=0x111
      imem[ 6] = 32'h00000073; // ecall                 tuzak; mepc=0x80000018; mcause=11
      imem[ 7] = 32'h05500513; // addi  x10,x0,0x55      x10=0x55 (mret donusu sonrasi)
      imem[ 8] = 32'h06600593; // addi  x11,x0,0x66      x11=0x66
      imem[ 9] = 32'hB0002CF3; // csrrs x25,mcycle,x0    x25=mcycle (>0)
      imem[10] = 32'h0000006F; // jal   x0,0            dur

      // --- Trap handler @ 0x80000080 (imem[32]) ---
      imem[32] = 32'h34202A73; // csrrs x20,mcause,x0    x20=11
      imem[33] = 32'h34102AF3; // csrrs x21,mepc,x0      x21=0x80000018
      imem[34] = 32'h004A8A93; // addi  x21,x21,4        x21=0x8000001C
      imem[35] = 32'h341A9073; // csrrw x0,mepc,x21      mepc=0x8000001C
      imem[36] = 32'h30200073; // mret                   geri don -> imem[7]

      rst=0; repeat(4) @(negedge clk); rst=1;
      repeat(300) @(posedge clk);

      $display("\n===== CSR/Trap uctan uca: yazmac degerleri =====");
      ktrl("lui+addi (handler adr)", 5'd1,  32'h80000080);
      ktrl("addi x5",               5'd5,  32'h00000111);
      ktrl("csrrw eski mscratch",   5'd6,  32'h00000000);
      ktrl("csrrs yeni mscratch",   5'd7,  32'h00000111);
      ktrl("ecall sonrasi x10",     5'd10, 32'h00000055);
      ktrl("ecall sonrasi x11",     5'd11, 32'h00000066);
      ktrl("handler mcause",        5'd20, 32'd11);
      ktrl("handler mepc",          5'd21, 32'h8000001C);

      $display("\n--- mcycle sayaci ---");
      if (dut.u_rf.yazmac_r[25] === 32'd0) begin
         $display("  HATA: mcycle (x25) = 0 (saymadi)"); hata=hata+1;
      end else
         $display("  OK  : mcycle (x25) = %0d (>0)", dut.u_rf.yazmac_r[25]);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end

   initial begin #200000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
