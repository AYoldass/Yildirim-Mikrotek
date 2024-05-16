`timescale 1ns / 1ps


module tb_dallanma_ongorucu();

    reg                       clk_i;
    reg                       rst_i;
    reg   [31:0]              ps_i;
    reg                       ps_gecerli_i;
    wire                      atladi_o;
    wire  [31:0]              ongoru_o;
    reg   [31:0]              yurut_ps_i;
    reg                       yurut_guncelle_i;
    reg                       yurut_atladi_i;
    reg   [31:0]              yurut_atlanan_adres_i;
    reg                       yurut_hatali_tahmin_i;

    dallanma_ongorucu uut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .ps_i(ps_i),
        .ps_gecerli_i(ps_gecerli_i),
        .atladi_o(atladi_o),
        .ongoru_o(ongoru_o),
        .yurut_ps_i(yurut_ps_i),
        .yurut_guncelle_i(yurut_guncelle_i),
        .yurut_atladi_i(yurut_atladi_i),
        .yurut_atlanan_adres_i(yurut_atlanan_adres_i),
        .yurut_hatali_tahmin_i(yurut_hatali_tahmin_i)
    );

    // Clock generation
    always #10 clk_i = !clk_i;

    initial begin
        clk_i                   = 0;
        rst_i                   = 1;
        ps_i                    = 0;
        ps_gecerli_i            = 0;
        yurut_ps_i              = 0;
        yurut_guncelle_i        = 0;
        yurut_atladi_i          = 0;
        yurut_atlanan_adres_i   = 0;
        yurut_hatali_tahmin_i   = 0;

        #100;
        rst_i = 0;
        #20;
        rst_i = 1;
        #20;

        // Case 1: Dallanma tahmin do�ru ve atlama ger�ekle�iyor
        ps_i                    = 32'h0000_0040;
        ps_gecerli_i            = 1;
        yurut_ps_i              = 32'h0000_0040;
        yurut_guncelle_i        = 1;
        yurut_atladi_i          = 1;
        yurut_atlanan_adres_i   = 32'h0000_0080;
        yurut_hatali_tahmin_i   = 0;
        #20;

        // Case 2: Dallanma tahmin do�ru ve atlama ger�ekle�miyor
        ps_i = 32'h0000_0080;
        #20;
        
        // Case 3: Dallanma tahmin yanl��
        ps_i                    = 32'h0000_00C0;
        yurut_ps_i              = 32'h0000_00C0;
        yurut_atladi_i          = 0;
        yurut_hatali_tahmin_i   = 1;
        #20;

        // Case 4: Hatal� dallanma tahmini g�ncelleme
        yurut_guncelle_i = 1;
        #20;

        // Reset and end simulation
        rst_i = 0;
        #20;
        $finish;
    end

endmodule
