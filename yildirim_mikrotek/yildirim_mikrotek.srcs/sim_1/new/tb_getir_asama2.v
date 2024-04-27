`timescale 1ns / 1ps


module tb_getir_asama2();

    reg                       clk_i;
    reg                       rst_i;
    reg                       g1_istek_yapildi_i;
    reg   [31:0]              g1_ps_i;
    reg                       g1_ps_gecerli_i;
    wire                      g1_ps_hazir_o;
    wire  [31:0]              g1_dallanma_ps_o;
    wire                      g1_dallanma_gecerli_o;
    reg   [31:0]              yurut_ps_i;
    reg   [31:0]              yurut_hedef_ps_i;
    reg                       yurut_guncelle_i;
    reg                       yurut_atladi_i;
    reg                       yurut_hatali_tahmin_i;
    reg   [31:0]              l1b_buyruk_i;
    reg                       l1b_buyruk_gecerli_i;
    wire                      l1b_buyruk_hazir_o;
    wire  [31:0]              coz_buyruk_o;
    wire  [31:0]              coz_buyruk_ps_o;
    wire                      coz_buyruk_gecerli_o;
    wire                      coz_buyruk_atladi_o;
    reg                       cek_bosalt_i;
    reg                       cek_duraklat_i;

    getir_asama2 uut (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .g1_istek_yapildi_i     (g1_istek_yapildi_i),
        .g1_ps_i                (g1_ps_i),
        .g1_ps_gecerli_i        (g1_ps_gecerli_i),
        .g1_ps_hazir_o          (g1_ps_hazir_o),
        .g1_dallanma_ps_o       (g1_dallanma_ps_o),
        .g1_dallanma_gecerli_o  (g1_dallanma_gecerli_o),
        .yurut_ps_i             (yurut_ps_i),
        .yurut_hedef_ps_i       (yurut_hedef_ps_i),
        .yurut_guncelle_i       (yurut_guncelle_i),
        .yurut_atladi_i         (yurut_atladi_i),
        .yurut_hatali_tahmin_i  (yurut_hatali_tahmin_i),
        .l1b_buyruk_i           (l1b_buyruk_i),
        .l1b_buyruk_gecerli_i   (l1b_buyruk_gecerli_i),
        .l1b_buyruk_hazir_o     (l1b_buyruk_hazir_o),
        .coz_buyruk_o           (coz_buyruk_o),
        .coz_buyruk_ps_o        (coz_buyruk_ps_o),
        .coz_buyruk_gecerli_o   (coz_buyruk_gecerli_o),
        .coz_buyruk_atladi_o    (coz_buyruk_atladi_o),
        .cek_bosalt_i           (cek_bosalt_i),
        .cek_duraklat_i         (cek_duraklat_i)
    );

    always #5 clk_i = (clk_i === 1'b0);

    initial begin
        clk_i                   = 0;
        rst_i                   = 1;
        g1_istek_yapildi_i      = 0;
        g1_ps_i                 = 0;
        g1_ps_gecerli_i         = 0;
        yurut_ps_i              = 0;
        yurut_hedef_ps_i        = 0;
        yurut_guncelle_i        = 0;
        yurut_atladi_i          = 0;
        yurut_hatali_tahmin_i   = 0;
        l1b_buyruk_i            = 32'h0000_0000;
        l1b_buyruk_gecerli_i    = 0;
        cek_bosalt_i            = 0;
        cek_duraklat_i          = 0;

        #100;
        rst_i = 0;
        #20;

        // Case 1: Basic instruction fetch
        g1_ps_i                 = 32'h0000_1000;
        g1_ps_gecerli_i         = 1;
        l1b_buyruk_i            = 32'h1234_5678;
        l1b_buyruk_gecerli_i    = 1;
        #10;
        g1_istek_yapildi_i      = 1;
        #10;

        // Case 2: Branch prediction with jump
        yurut_ps_i              = 32'h0000_1000;
        yurut_hedef_ps_i        = 32'h0000_2000;
        yurut_guncelle_i        = 1;
        yurut_atladi_i          = 1;
        #20;

        // Case 3: Halt for debugging
        cek_duraklat_i = 1;
        #20;
        cek_duraklat_i = 0;

        // Case 4: Flush pipeline on misprediction
        yurut_hatali_tahmin_i = 1;
        #20;

        $finish;
    end

endmodule
