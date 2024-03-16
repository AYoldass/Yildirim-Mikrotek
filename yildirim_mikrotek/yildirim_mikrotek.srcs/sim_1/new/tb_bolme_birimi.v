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

        // Sistemi sýfýrla
        #10;
        rst_i = 0;
        #10;
        rst_i = 1;
        #10;

        // Test 1: Ýþaretsiz bölme
        bolunen_i = 32'd50;
        bolen_i = 32'd3;
        sign_i = 0; // Ýþaretsiz
        istek_i = 1; // Ýþlemi baþlat
        #10;
        istek_i = 0; // Ýstek sinyalini kapat

        // Ýþlem bitene kadar bekle
        while(!result_ready_o) #10;

        // Test 2: Ýþaretli bölme
        #20; // Önceki iþlemin tamamen bitmesi için ek bekleme süresi
        bolunen_i = -32'd50; // Ýþaretli bölme için negatif sayý
        bolen_i = 32'd3;
        sign_i = 1; // Ýþaretli
        istek_i = 1; // Ýþlemi baþlat
        #10;
        istek_i = 0; // Ýstek sinyalini kapat

        // Ýþlem bitene kadar bekle
        while(!result_ready_o) #10;

        // Testler tamamlandý
        $finish;
    end

endmodule
