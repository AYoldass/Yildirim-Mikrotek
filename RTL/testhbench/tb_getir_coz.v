`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_getir_coz  -  Getir alt sistemi + Coz asamasi ENTEGRASYON testi
//  Bellekteki sirali program getir->coz boru hattindan gectiginde, coz
//  cikisinda (yurut_*) buyruklarin DOGRU SIRADA ve dogru PS ile gorunmesi
//  beklenir. Ayrica ilk birkac buyrugun temel cozumu de denetlenir.
// ===========================================================================
module tb_getir_coz;

   localparam BASE = 32'h8000_0000;

   reg clk=0, rst;
   always #5 clk=~clk;

   // L1 buyruk arayuzu (1 cevrim gecikmeli model)
   wire [31:0] l1b_adr; wire l1b_istek_v; reg l1b_istek_rdy=1;
   reg  [31:0] l1b_buyruk; reg l1b_buyruk_v=0; wire l1b_buyruk_rdy;
   reg  [31:0] mem [0:255];
   wire [7:0]  idx = (l1b_adr-BASE)>>2;
   always @(posedge clk) begin
      if (l1b_istek_v && l1b_istek_rdy) begin l1b_buyruk<=mem[idx]; l1b_buyruk_v<=1; end
      else l1b_buyruk_v<=0;
   end

   // getir -> coz
   wire [31:0] g_buyruk, g_ps; wire g_gecerli, g_atladi;

   getir_altsistem u_getir (
      .clk_i(clk), .rst_i(rst),
      .l1b_istek_adres_o(l1b_adr), .l1b_istek_gecerli_o(l1b_istek_v), .l1b_istek_hazir_i(l1b_istek_rdy),
      .l1b_buyruk_i(l1b_buyruk), .l1b_buyruk_gecerli_i(l1b_buyruk_v), .l1b_buyruk_hazir_o(l1b_buyruk_rdy),
      .coz_buyruk_o(g_buyruk), .coz_buyruk_ps_o(g_ps),
      .coz_buyruk_gecerli_o(g_gecerli), .coz_buyruk_atladi_o(g_atladi),
      .yurut_ps_i(32'b0), .yurut_hedef_ps_i(32'b0), .yurut_guncelle_i(1'b0),
      .yurut_atladi_i(1'b0), .yurut_hatali_tahmin_i(1'b0),
      .yurut_yonlendir_gecerli_i(1'b0), .yurut_yonlendir_ps_i(32'b0),
      .cek_duraklat_i(1'b0), .cek_bosalt_i(1'b0)
   );

   wire [31:0] yps, yd1, yd2, yrs2, yimm, ybuyruk;
   wire [`MI_BIT-1:0] ymi;
   wire [4:0] yrd, yrs1a, yrs2a;
   wire ygec, yatl;

   wire [4:0] oku_a1, oku_a2;
   wire [31:0] rs1d, rs2d;
   coz_asamasi u_coz (
      .clk_i(clk), .rst_i(rst),
      .coz_buyruk_i(g_buyruk), .coz_buyruk_ps_i(g_ps),
      .coz_buyruk_gecerli_i(g_gecerli), .coz_buyruk_atladi_i(g_atladi),
      .oku_adres1_o(oku_a1), .oku_adres2_o(oku_a2),
      .rs1_deger_i(rs1d), .rs2_deger_i(rs2d),
      .rs1_kullanilir_o(), .rs2_kullanilir_o(),
      .rezerve_adres_o(), .rezerve_etiket_o(), .rezerve_gecerli_o(),
      .durdur_i(1'b0), .bosalt_i(1'b0),
      .yurut_ps_o(yps), .yurut_deger1_o(yd1), .yurut_deger2_o(yd2),
      .yurut_rs2_deger_o(yrs2), .yurut_imm_o(yimm), .yurut_mikroislem_o(ymi),
      .yurut_rd_adres_o(yrd), .yurut_rs1_adres_o(yrs1a), .yurut_rs2_adres_o(yrs2a),
      .yurut_etiket_o(), .yurut_buyruk_o(ybuyruk),
      .yurut_gecerli_o(ygec), .yurut_atladi_o(yatl)
   );

   yazmac_obegi rf (
      .clk_i(clk), .rst_i(rst),
      .oku_adres1_i(oku_a1), .oku_adres2_i(oku_a2),
      .oku_veri1_o(rs1d), .oku_veri1_gecerli_o(), .oku_veri1_etiket_o(),
      .oku_veri2_o(rs2d), .oku_veri2_gecerli_o(), .oku_veri2_etiket_o(),
      .yaz_veri_i(32'b0), .yaz_adres_i(5'b0), .yaz_etiket_i(4'b0), .yaz_gecerli_i(1'b0),
      .etiket_i(4'b0), .etiket_adres_i(5'b0), .etiket_gecerli_i(1'b0)
   );

   integer hata=0, i, alinan;
   reg [31:0] beklenen_ps;

   initial begin
      for (i=0;i<256;i=i+1) mem[i]=32'h00000013; // nop (addi x0,x0,0)
      // Sirali program (addi x{1..8})
      mem[0]=32'h00100093; mem[1]=32'h00200113; mem[2]=32'h00300193; mem[3]=32'h00400213;
      mem[4]=32'h00500293; mem[5]=32'h00600313; mem[6]=32'h00700393; mem[7]=32'h00800413;

      rst=0; repeat(4) @(negedge clk); rst=1;

      $display("\n===== Getir + Coz entegrasyonu: sirali akis =====");
      beklenen_ps = BASE; alinan = 0;
      while (alinan < 8) begin
         @(posedge clk); #1;
         if (ygec) begin
            if (yps !== beklenen_ps) begin
               $display("  HATA: #%0d PS beklenen=0x%08h alinan=0x%08h", alinan, beklenen_ps, yps);
               hata=hata+1;
            end else if (ybuyruk !== mem[(beklenen_ps-BASE)>>2]) begin
               $display("  HATA: PS=0x%08h buyruk beklenen=0x%08h alinan=0x%08h",
                        beklenen_ps, mem[(beklenen_ps-BASE)>>2], ybuyruk);
               hata=hata+1;
            end else begin
               $display("  OK  : #%0d PS=0x%08h buyruk=0x%08h rd=%0d imm=%0d (BIRIM=%0d)",
                        alinan, yps, ybuyruk, yrd, yimm, ymi[`BIRIM]);
               // addi x{N},x0,N -> rd=N, imm=N, BIRIM=ALU
               if (yrd !== (alinan+1)) begin $display("    HATA rd!=%0d", alinan+1); hata=hata+1; end
               if (yimm !== (alinan+1)) begin $display("    HATA imm!=%0d", alinan+1); hata=hata+1; end
               if (ymi[`BIRIM] !== `BIRIM_ALU) begin $display("    HATA BIRIM!=ALU"); hata=hata+1; end
            end
            beklenen_ps = beklenen_ps + 4;
            alinan = alinan + 1;
         end
      end

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end

   initial begin #50000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
