`timescale 1ns / 1ps
`include "riscv_controller.vh"

// ===========================================================================
//  tb_coz_asamasi  -  Coz (Decode) asamasi kendi-denetimli testi
//  RV32I + RV32M buyruklarinin sema-B mikroislem alanlarina, anlik (imm) ve
//  operand secimine dogru cozulup cozulmedigini dogrular.
// ===========================================================================
module tb_coz_asamasi;

   reg         clk_i = 0;
   reg         rst_i;
   reg  [31:0] buyruk, ps;
   reg         gecerli, atladi;
   reg  [4:0]  wb_adres;
   reg  [31:0] wb_veri;
   reg  [3:0]  wb_etiket;
   reg         wb_gecerli;
   reg         durdur, bosalt;

   wire [31:0] yps, yd1, yd2, yrs2, yimm, ybuyruk;
   wire [`MI_BIT-1:0] ymi;
   wire [4:0]  yrd, yrs1a, yrs2a;
   wire        ygec, yatl;

   integer hata = 0;

   // Harici yazmac obegi (RF artik coz disinda)
   wire [4:0]  oku_a1, oku_a2;
   wire [31:0] rs1d, rs2d;
   coz_asamasi dut (
      .clk_i(clk_i), .rst_i(rst_i),
      .coz_buyruk_i(buyruk), .coz_buyruk_ps_i(ps),
      .coz_buyruk_gecerli_i(gecerli), .coz_buyruk_atladi_i(atladi),
      .oku_adres1_o(oku_a1), .oku_adres2_o(oku_a2),
      .rs1_deger_i(rs1d), .rs2_deger_i(rs2d),
      .rs1_kullanilir_o(), .rs2_kullanilir_o(),
      .rezerve_adres_o(), .rezerve_etiket_o(), .rezerve_gecerli_o(),
      .durdur_i(durdur), .bosalt_i(bosalt),
      .yurut_ps_o(yps), .yurut_deger1_o(yd1), .yurut_deger2_o(yd2),
      .yurut_rs2_deger_o(yrs2), .yurut_imm_o(yimm), .yurut_mikroislem_o(ymi),
      .yurut_rd_adres_o(yrd), .yurut_rs1_adres_o(yrs1a), .yurut_rs2_adres_o(yrs2a),
      .yurut_etiket_o(), .yurut_buyruk_o(ybuyruk),
      .yurut_gecerli_o(ygec), .yurut_atladi_o(yatl)
   );

   yazmac_obegi rf (
      .clk_i(clk_i), .rst_i(rst_i),
      .oku_adres1_i(oku_a1), .oku_adres2_i(oku_a2),
      .oku_veri1_o(rs1d), .oku_veri1_gecerli_o(), .oku_veri1_etiket_o(),
      .oku_veri2_o(rs2d), .oku_veri2_gecerli_o(), .oku_veri2_etiket_o(),
      .yaz_veri_i(wb_veri), .yaz_adres_i(wb_adres),
      .yaz_etiket_i(wb_etiket), .yaz_gecerli_i(wb_gecerli),
      .etiket_i(4'b0), .etiket_adres_i(5'b0), .etiket_gecerli_i(1'b0)
   );

   always #5 clk_i = ~clk_i;

   // mikroislem alan cikaricilari
   `define F_BIRIM   ymi[`BIRIM]
   `define F_ALU     ymi[`ALU]
   `define F_OPND    ymi[`OPERAND]
   `define F_YAZ     ymi[`YAZMAC]
   `define F_GY      ymi[`GERIYAZ]
   `define F_DAL     ymi[`DAL]
   `define F_BIB     ymi[`BIB]
   `define F_CARP    ymi[`CARPMA]
   `define F_BOLME   ymi[`BOLME]

   task yazmac_yaz;  // RF'ye deger yaz (etiket 0 -> gecerli olur)
      input [4:0] a; input [31:0] d;
      begin
         @(negedge clk_i);
         wb_adres=a; wb_veri=d; wb_etiket=0; wb_gecerli=1;
         @(negedge clk_i);
         wb_gecerli=0;
      end
   endtask

   // Bir buyrugu coz ve bir cevrim sonra kayitli ciktilari dogrula.
   task coz;
      input [31:0] b; input [31:0] p;
      begin
         @(negedge clk_i);
         buyruk=b; ps=p; gecerli=1; atladi=0; durdur=0; bosalt=0;
         @(posedge clk_i); #1;
      end
   endtask

   task kontrol; // beklenen == alinan
      input [127:0] ad; input [31:0] beklenen; input [31:0] alinan;
      begin
         if (beklenen !== alinan) begin
            $display("  HATA: %0s beklenen=0x%08h alinan=0x%08h", ad, beklenen, alinan);
            hata = hata + 1;
         end else
            $display("  OK  : %0s = 0x%08h", ad, alinan);
      end
   endtask

   initial begin
      rst_i=0; buyruk=0; ps=0; gecerli=0; atladi=0; durdur=0; bosalt=0;
      wb_adres=0; wb_veri=0; wb_etiket=0; wb_gecerli=0;
      repeat(3) @(negedge clk_i);
      rst_i=1;

      // Operand testleri icin x1=100, x2=200 yaz
      yazmac_yaz(5'd1, 32'd100);
      yazmac_yaz(5'd2, 32'd200);

      $display("\n===== RV32I/M coz dogrulamasi =====");

      // 1) addi x1,x0,5
      coz(32'h00500093, 32'h80000000);
      $display("[addi x1,x0,5]");
      kontrol("BIRIM",  `BIRIM_ALU,     `F_BIRIM);
      kontrol("ALU",    `ALU_TOPLAMA,   `F_ALU);
      kontrol("OPERAND",`OPERAND_IMM,   `F_OPND);
      kontrol("YAZMAC", `YAZMAC_YAZ,    `F_YAZ);
      kontrol("rd",     5'd1,           yrd);
      kontrol("imm",    32'd5,          yimm);
      kontrol("deger2", 32'd5,          yd2);

      // 2) add x3,x1,x2
      coz(32'h002081B3, 32'h80000004);
      $display("[add x3,x1,x2]");
      kontrol("BIRIM",  `BIRIM_ALU,     `F_BIRIM);
      kontrol("ALU",    `ALU_TOPLAMA,   `F_ALU);
      kontrol("OPERAND",`OPERAND_REG,   `F_OPND);
      kontrol("rd",     5'd3,           yrd);
      kontrol("rs1",    5'd1,           yrs1a);
      kontrol("rs2",    5'd2,           yrs2a);
      kontrol("deger1", 32'd100,        yd1);
      kontrol("deger2", 32'd200,        yd2);

      // 3) sub x3,x1,x2
      coz(32'h402081B3, 32'h80000008);
      $display("[sub x3,x1,x2]");
      kontrol("ALU",    `ALU_CIKARMA,   `F_ALU);

      // 4) lw x5,8(x6)
      coz(32'h00832283, 32'h8000000C);
      $display("[lw x5,8(x6)]");
      kontrol("BIRIM",  `BIRIM_BIB,     `F_BIRIM);
      kontrol("BIB",    `BIB_LW,        `F_BIB);
      kontrol("OPERAND",`OPERAND_IMM,   `F_OPND);
      kontrol("imm",    32'd8,          yimm);
      kontrol("rd",     5'd5,           yrd);

      // 5) sw x7,12(x8)
      coz(32'h00742623, 32'h80000010);
      $display("[sw x7,12(x8)]");
      kontrol("BIRIM",  `BIRIM_BIB,     `F_BIRIM);
      kontrol("BIB",    `BIB_SW,        `F_BIB);
      kontrol("YAZMAC", `YAZMAC_YAZMA,  `F_YAZ);
      kontrol("imm",    32'd12,         yimm);
      kontrol("rs2",    5'd7,           yrs2a);

      // 6) beq x1,x2,8
      coz(32'h00208463, 32'h80000014);
      $display("[beq x1,x2,8]");
      kontrol("BIRIM",  `BIRIM_DALLANMA,`F_BIRIM);
      kontrol("DAL",    `DAL_EQ,        `F_DAL);
      kontrol("YAZMAC", `YAZMAC_YAZMA,  `F_YAZ);
      kontrol("imm",    32'd8,          yimm);

      // 7) lui x9,0x12345
      coz(32'h123454B7, 32'h80000018);
      $display("[lui x9,0x12345]");
      kontrol("ALU",    `ALU_GECIR,     `F_ALU);
      kontrol("OPERAND",`OPERAND_IMM,   `F_OPND);
      kontrol("imm",    32'h12345000,   yimm);
      kontrol("rd",     5'd9,           yrd);

      // 8) auipc x10,0x1
      coz(32'h00001517, 32'h80000020);
      $display("[auipc x10,0x1]");
      kontrol("OPERAND",`OPERAND_PCIMM, `F_OPND);
      kontrol("imm",    32'h00001000,   yimm);
      kontrol("deger1", 32'h80000020,   yd1);   // op1 = PS
      kontrol("deger2", 32'h00001000,   yd2);   // op2 = imm

      // 9) jal x1,4
      coz(32'h004000EF, 32'h80000024);
      $display("[jal x1,4]");
      kontrol("BIRIM",  `BIRIM_DALLANMA,`F_BIRIM);
      kontrol("DAL",    `DAL_JAL,       `F_DAL);
      kontrol("GERIYAZ",`GERIYAZ_KAYNAK_PC, `F_GY);
      kontrol("OPERAND",`OPERAND_PCIMM, `F_OPND);
      kontrol("imm",    32'd4,          yimm);

      // 10) mul x3,x1,x2
      coz(32'h022081B3, 32'h80000028);
      $display("[mul x3,x1,x2]");
      kontrol("BIRIM",  `BIRIM_CARPMA,  `F_BIRIM);
      kontrol("CARPMA", `CARPMA_MUL,    `F_CARP);
      kontrol("GERIYAZ",`GERIYAZ_KAYNAK_CARP, `F_GY);

      // 11) div x3,x1,x2
      coz(32'h0220C1B3, 32'h8000002C);
      $display("[div x3,x1,x2]");
      kontrol("BIRIM",  `BIRIM_BOLME,   `F_BIRIM);
      kontrol("BOLME",  `BOLME_DIV,     `F_BOLME);

      // 12) Kabarcik: gecerli=0 -> yurut_gecerli_o dusmeli
      @(negedge clk_i); gecerli=0; @(posedge clk_i); #1;
      $display("[kabarcik]");
      kontrol("gecerli",32'd0,          {31'b0,ygec});

      $display("\n==================================================");
      if (hata==0) $display("  SONUC: TUM TESTLER BASARILI");
      else         $display("  SONUC: %0d HATA bulundu", hata);
      $display("==================================================\n");
      $finish;
   end

   initial begin #20000; $display("ZAMAN ASIMI!"); $finish; end
endmodule
