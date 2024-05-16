`timescale 1ns / 1ps

module tb_dallanma_birimi();
    reg [3:0]  islem_kod_i;
    reg [31:0] islem_ps_i;
    reg [31:0] islem_islec_i;
    reg [31:0] islem_anlik_i;
    reg        islem_atladi_i;
    reg        islem_rvc_i;
    reg        alu_esittir_i;
    reg        alu_kucuktur_i;
    reg        alu_kucuktur_isaretsiz_i;

    wire [31:0] g1_ps_o;
    wire        g1_ps_gecerli_o;
    wire [31:0] g2_ps_o;
    wire [31:0] g2_hedef_ps_o;
    wire        g2_guncelle_o;
    wire        g2_atladi_o;
    wire        g2_hatali_tahmin_o;
    wire [31:0] ps_atlamadi_o;

    dallanma_birimi uut (
        .islem_kod_i                    (islem_kod_i),
        .islem_ps_i                     (islem_ps_i),
        .islem_islec_i                  (islem_islec_i),
        .islem_anlik_i                  (islem_anlik_i),
        .islem_atladi_i                 (islem_atladi_i),
        .islem_rvc_i                    (islem_rvc_i),
        .alu_esittir_i                  (alu_esittir_i),
        .alu_kucuktur_i                 (alu_kucuktur_i),
        .alu_kucuktur_isaretsiz_i       (alu_kucuktur_isaretsiz_i),
        .g1_ps_o                        (g1_ps_o),
        .g1_ps_gecerli_o                (g1_ps_gecerli_o),
        .g2_ps_o                        (g2_ps_o),
        .g2_hedef_ps_o                  (g2_hedef_ps_o),
        .g2_guncelle_o                  (g2_guncelle_o),
        .g2_atladi_o                    (g2_atladi_o),
        .g2_hatali_tahmin_o             (g2_hatali_tahmin_o),
        .ps_atlamadi_o                  (ps_atlamadi_o)
    );

    reg [31:0] dummy_sum_result;
    assign toplayici_sonuc_w = dummy_sum_result;

    initial begin
        islem_kod_i              = 0;
        islem_ps_i               = 0;
        islem_islec_i            = 0;
        islem_anlik_i            = 0;
        islem_atladi_i           = 0;
        islem_rvc_i              = 0;
        alu_esittir_i            = 0;
        alu_kucuktur_i           = 0;
        alu_kucuktur_isaretsiz_i = 0;
        dummy_sum_result         = 0;

        #100;
        
/* DAL_NE: ALU'nun eþit olmadýðýný ve dallanmanýn gerçekleþmediðini belirttiði durum.
DAL_LT: ALU'nun birinci operandýn ikinciden küçük olduðunu ve dallanmanýn gerçekleþtiðini belirttiði durum.
DAL_GE: ALU'nun birinci operandýn ikinciden küçük olmadýðýný ve dallanmanýn gerçekleþmediðini belirttiði durum.
DAL_LTU: ALU'nun birinci operandýn ikinciden iþaretsiz olarak küçük olduðunu ve dallanmanýn gerçekleþtiðini belirttiði durum.
DAL_GEU: ALU'nun birinci operandýn ikinciden iþaretsiz olarak büyük veya eþit olduðunu ve dallanmanýn gerçekleþtiðini belirttiði durum.
DAL_JAL: Koþulsuz zýplama (jump and link) iþlemi.
DAL_JALR: Kayýt içerisindeki adrese koþulsuz zýplama (jump and link register) iþlemi.
*/

        // Test `DAL_EQ` when ALU says values are equal and branch is taken
        islem_kod_i = `DAL_EQ;
        islem_ps_i = 32'h00400000;
        islem_islec_i = 32'h00000004;
        islem_anlik_i = 32'h00400004;
        alu_esittir_i = 1; // ALU says values are equal
        islem_atladi_i = 1; // Branch is taken
        dummy_sum_result = islem_ps_i + islem_islec_i; 
        #10;

                // Test `DAL_NE` when ALU says values are not equal and branch is not taken
        islem_kod_i = `DAL_NE;
        islem_ps_i = 32'h00400000;
        islem_islec_i = 32'h00000008;
        islem_anlik_i = 32'h00400008;
        alu_esittir_i = 0; // ALU says values are not equal
        islem_atladi_i = 0; 
        dummy_sum_result = islem_ps_i + islem_islec_i; 
        #10;

        // Test `DAL_LT` when ALU says less than and branch is taken
        islem_kod_i = `DAL_LT;
        islem_ps_i = 32'h00400000;
        islem_islec_i = 32'hFFFFFFFC; // -4 in two's complement
        islem_anlik_i = 32'h003FFFFC;
        alu_kucuktur_i = 1; // ALU says first operand is less than second
        islem_atladi_i = 1; 
        dummy_sum_result = islem_ps_i + islem_islec_i; 
        #10;

        // Test `DAL_GE` when ALU says not less than and branch is not taken
        islem_kod_i = `DAL_GE;
        islem_ps_i = 32'h00400000;
        islem_islec_i = 32'h00000010;
        islem_anlik_i = 32'h00400010;
        alu_kucuktur_i = 0; // ALU says first operand is not less than second
        islem_atladi_i = 0; 
        dummy_sum_result = islem_ps_i + islem_islec_i; 
        #10;

        // Test `DAL_LTU` when ALU says less than unsigned and branch is taken
        islem_kod_i = `DAL_LTU;
        islem_ps_i = 32'h00400000;
        islem_islec_i = 32'h00000004;
        islem_anlik_i = 32'h00400004;
        alu_kucuktur_isaretsiz_i = 1; // ALU says first operand is less than second, unsigned
        islem_atladi_i = 1; 
        dummy_sum_result = islem_ps_i + islem_islec_i; 
        #10;

        // Test `DAL_GEU` when ALU says greater than or equal unsigned and branch is taken
        islem_kod_i = `DAL_GEU;
        islem_ps_i = 32'h00400000;
        islem_islec_i = 32'h00000004;
        islem_anlik_i = 32'h00400004;
        alu_kucuktur_isaretsiz_i = 0; // ALU says first operand is greater or equal, unsigned
        islem_atladi_i = 1;
        dummy_sum_result = islem_ps_i + islem_islec_i; 
        #10;

        // Test `DAL_JAL` unconditional jump
        islem_kod_i = `DAL_JAL;
        islem_ps_i = 32'h00400000;
        islem_islec_i = 32'h00000020; // Jump address offset
        islem_anlik_i = 32'h00400020; // Expected jump address
        // No ALU comparison needed, jump is unconditional
        islem_atladi_i = 1; 
        dummy_sum_result = islem_ps_i + islem_islec_i; 
        #10;

        // Test `DAL_JALR` unconditional jump with register
        islem_kod_i = `DAL_JALR;
        islem_ps_i = 32'h00400000;
        islem_islec_i = 32'h00000020; // Jump address offset
        islem_anlik_i = 32'h00400020; // Register contents with jump target
        // No ALU comparison needed, jump is unconditional
        islem_atladi_i = 1; // Unconditional jump
        dummy_sum_result = islem_ps_i + islem_islec_i; 
        #10;

        #100;
        $finish;
    end

endmodule
