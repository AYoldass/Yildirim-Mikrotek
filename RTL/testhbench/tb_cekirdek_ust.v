`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_cekirdek_ust  -  SoC (cekirdek + RAM + cevresel) uctan uca testi (Faz 8)
//  - UART'a "Hi" yazar (durum yoklamasi ile)
//  - Zamanlayici kesmesi: mtvec/mie/mstatus + mtimecmp; handler x20=1, mret
//  - tohost ile sonlandirma (cikis kodu)
//  -> bellek, memory-mapped cevre birimler ve KESME yolu birlikte dogrulanir.
// ===========================================================================
module tb_cekirdek_ust;

   reg clk=0, rst;
   always #5 clk=~clk;

   wire        uart_gecerli;
   wire [7:0]  uart_veri;
   wire        bitti;
   wire [31:0] cikis_kodu;

   cekirdek_ust #(.KELIME(8192), .RAM_GECIKME(2)) dut (
      .clk_i(clk), .rst_i(rst),
      .uart_gecerli_o(uart_gecerli), .uart_veri_o(uart_veri),
      .bitti_o(bitti), .cikis_kodu_o(cikis_kodu)
   );

   // UART cikis yakalama
   reg [7:0] uart_buf [0:63];
   integer   uart_n = 0;
   always @(posedge clk) if (uart_gecerli) begin
      uart_buf[uart_n] = uart_veri; uart_n = uart_n + 1;
   end

   integer hata=0, i;
   initial begin
      for (i=0;i<8192;i=i+1) dut.u_yol.ram[i] = 32'h00000013; // nop dolgu

      // --- Ana program ---
      dut.u_yol.ram[ 0]=32'h100000B7; // lui  x1,0x10000     x1=0x10000000 (perif taban)
      dut.u_yol.ram[ 1]=32'h04800113; // addi x2,x0,0x48     'H'
      dut.u_yol.ram[ 2]=32'h00208023; // sw   x2,0(x1)       UART='H'
      dut.u_yol.ram[ 3]=32'h0040A183; // lw   x3,4(x1)       durum
      dut.u_yol.ram[ 4]=32'hFE019EE3; // bne  x3,x0,-4       mesgulse yokla
      dut.u_yol.ram[ 5]=32'h06900113; // addi x2,x0,0x69     'i'
      dut.u_yol.ram[ 6]=32'h00208023; // sw   x2,0(x1)       UART='i'
      dut.u_yol.ram[ 7]=32'h0040A183; // lw   x3,4(x1)       durum
      dut.u_yol.ram[ 8]=32'hFE019EE3; // bne  x3,x0,-4       yokla
      // --- RAM veri erisimi (BEKLEME-DURUMLU: RAM_GECIKME=2) ---
      dut.u_yol.ram[ 9]=32'h80001237; // lui  x4,0x80001     x4=0x80001000 (RAM veri adresi)
      dut.u_yol.ram[10]=32'h05A00513; // addi x10,x0,0x5A    x10=0x5A
      dut.u_yol.ram[11]=32'h00A22023; // sw   x10,0(x4)      RAM[0x80001000]=0x5A (bekleme)
      dut.u_yol.ram[12]=32'h00022583; // lw   x11,0(x4)      x11=RAM[..]=0x5A (bekleme + RAW)
      // --- zamanlayici kesmesi kurulumu ---
      dut.u_yol.ram[13]=32'h800002B7; // lui  x5,0x80000
      dut.u_yol.ram[14]=32'h0A028293; // addi x5,x5,0xA0     x5=handler=0x800000A0
      dut.u_yol.ram[15]=32'h30529073; // csrrw x0,mtvec,x5
      dut.u_yol.ram[16]=32'h08000313; // addi x6,x0,0x80     MTIE (bit7)
      dut.u_yol.ram[17]=32'h30432073; // csrrs x0,mie,x6      (funct3=010)
      dut.u_yol.ram[18]=32'h00800393; // addi x7,x0,0x8      MIE global (bit3)
      dut.u_yol.ram[19]=32'h3003A073; // csrrs x0,mstatus,x7
      dut.u_yol.ram[20]=32'h0C800413; // addi x8,x0,200      mtimecmp degeri
      dut.u_yol.ram[21]=32'h0000AE23; // sw   x0,0x1C(x1)    mtimecmp_hi=0
      dut.u_yol.ram[22]=32'h0080AC23; // sw   x8,0x18(x1)    mtimecmp_lo=200
      // --- kesme bekle (x20!=0 olana dek don) ---
      dut.u_yol.ram[23]=32'h000A0063; // beq  x20,x0,0       kendine don (kesmeyi bekle)
      dut.u_yol.ram[24]=32'h00100493; // addi x9,x0,1        cikis kodu 1
      dut.u_yol.ram[25]=32'h0290A023; // sw   x9,0x20(x1)    TOHOST=1 -> bitir
      dut.u_yol.ram[26]=32'h0000006F; // jal  x0,0          dur

      // --- Trap handler @ 0x800000A0 (ram[40]) ---
      dut.u_yol.ram[40]=32'h00100A13; // addi x20,x0,1       kesme islendi
      dut.u_yol.ram[41]=32'hFFF00B13; // addi x22,x0,-1      0xFFFFFFFF
      dut.u_yol.ram[42]=32'h0160AE23; // sw   x22,0x1C(x1)   mtimecmp_hi=MAX (kesmeyi kapat)
      dut.u_yol.ram[43]=32'h30200073; // mret

      rst=0; repeat(4) @(negedge clk); rst=1;

      // bitti veya zaman asimi bekle
      i=0;
      while (!bitti && i<5000) begin @(posedge clk); i=i+1; end

      $display("\n===== SoC uctan uca =====");
      // UART
      $write("  UART cikisi: \""); for (i=0;i<uart_n;i=i+1) $write("%c", uart_buf[i]); $display("\" (%0d bayt)", uart_n);
      if (uart_n!==2 || uart_buf[0]!==8'h48 || uart_buf[1]!==8'h69) begin
         $display("  HATA: UART beklenen \"Hi\""); hata=hata+1;
      end else $display("  OK  : UART = \"Hi\"");
      // RAM bekleme-durumlu store/load
      if (dut.u_cekirdek.u_rf.yazmac_r[11] !== 32'h5A) begin
         $display("  HATA: RAM wait-state load x11=0x%08h (bek 0x5A)", dut.u_cekirdek.u_rf.yazmac_r[11]); hata=hata+1;
      end else $display("  OK  : RAM bekleme-durumlu store/load (x11=0x5A)");
      // Kesme islendi mi
      if (dut.u_cekirdek.u_rf.yazmac_r[20] !== 32'd1) begin
         $display("  HATA: kesme islenmedi (x20=%0d)", dut.u_cekirdek.u_rf.yazmac_r[20]); hata=hata+1;
      end else $display("  OK  : zamanlayici kesmesi islendi (x20=1)");
      // Sonlandirma
      if (!bitti) begin $display("  HATA: program bitmedi (zaman asimi)"); hata=hata+1; end
      else if (cikis_kodu!==32'd1) begin $display("  HATA: cikis kodu=%0d (bek 1)", cikis_kodu); hata=hata+1; end
      else $display("  OK  : tohost ile bitti, cikis kodu=1 (%0d cevrim)", i);

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end
   initial begin #200000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
