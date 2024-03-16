`timescale 1ns / 1ps

module tb_bolme();

    reg         clk_i;
    reg         rst_i;
    reg         istek_i;
    reg         sign_i;
    reg [31:0]  bolunen_i;
    reg [31:0]  bolen_i;

    wire [31:0] bolum_o;
    wire [31:0] kalan_o;
    wire        result_ready_o;

    bolme_birimi uut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .istek_i(istek_i),
        .sign_i(sign_i),
        .bolunen_i(bolunen_i),
        .bolen_i(bolen_i),
        .bolum_o(bolum_o),
        .kalan_o(kalan_o),
        .result_ready_o(result_ready_o)
    );

    always #5 clk_i = ~clk_i;

    initial begin
        clk_i = 0;
        rst_i = 1;
        istek_i = 0;
        sign_i = 0;
        bolunen_i = 0;
        bolen_i = 0;

        // Sistemi s�f�rla
        #10;
        rst_i = 0;
        #10;
        rst_i = 1;
        #10;

        // Test 1: ��aretsiz b�lme
        bolunen_i = 32'd50;
        bolen_i = 32'd3;
        sign_i = 0; // ��aretsiz
        istek_i = 1; // ��lemi ba�lat
        #10;
        istek_i = 0; // �stek sinyalini kapat

        // ��lem bitene kadar bekle
        while(!result_ready_o) #10;

        // Test 2: ��aretli b�lme
        #20; // �nceki i�lemin tamamen bitmesi i�in ek bekleme s�resi
        bolunen_i = -32'd50; // ��aretli b�lme i�in negatif say�
        bolen_i = 32'd3;
        sign_i = 1; // ��aretli
        istek_i = 1; // ��lemi ba�lat
        #10;
        istek_i = 0; // �stek sinyalini kapat

        // ��lem bitene kadar bekle
        while(!result_ready_o) #10;

        // Testler tamamland�
        $finish;
    end

endmodule
