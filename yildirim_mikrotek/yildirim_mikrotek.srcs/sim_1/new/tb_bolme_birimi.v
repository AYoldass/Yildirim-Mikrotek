`timescale 1ns / 1ps

module tb_bolme();

   // Inputs
    reg clk_i;
    reg rst_i;
    reg [3:0] islev_kodu_i;
    reg [31:0] value1_i;
    reg [31:0] value2_i;
    reg islem_gecerli_i;

    // Outputs
    wire bolum_gecerli_o;
    wire [31:0] bolum_o;

    // Instantiate the Unit Under Test (UUT)
    bolme_birimi uut (
        .clk_i(clk_i), 
        .rst_i(rst_i), 
        .islev_kodu_i(islev_kodu_i), 
        .value1_i(value1_i), 
        .value2_i(value2_i), 
        .islem_gecerli_i(islem_gecerli_i), 
        .bolum_gecerli_o(bolum_gecerli_o), 
        .bolum_o(bolum_o)
    );

    // Clock generation
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    // Reset and test scenario
    initial begin
        // Initialize inputs
        rst_i = 1;
        islev_kodu_i = 0;
        value1_i = 0;
        value2_i = 0;
        islem_gecerli_i = 0;

        // Apply reset
        #10;
        rst_i = 0;
        #10;
        rst_i = 1;
        #10;

        // Test cases start here

        // Test DIV operation with positive numbers
        islev_kodu_i = 4'h1; // DIV
        value1_i = 32'd100;
        value2_i = 32'd5;
        islem_gecerli_i = 1;
        #10; islem_gecerli_i = 0;
        #100;

        // Test DIVU operation with unsigned numbers
        islev_kodu_i = 4'h2; // DIVU
        value1_i = 32'd150;
        value2_i = 32'd7;
        islem_gecerli_i = 1;
        #10; islem_gecerli_i = 0;
        #100;

        // Test REM operation with positive and negative
        islev_kodu_i = 4'h4; // REM
        value1_i = -32'd200;
        value2_i = 32'd50;
        islem_gecerli_i = 1;
        #10; islem_gecerli_i = 0;
        #100;

        // Test REMU operation with unsigned numbers
        islev_kodu_i = 4'h8; // REMU
        value1_i = 32'd43;
        value2_i = 32'd6;
        islem_gecerli_i = 1;
        #10; islem_gecerli_i = 0;
        #100;

        // Test division by zero and special cases
        islev_kodu_i = 4'h1; // DIV
        value1_i = 32'd10;
        value2_i = 32'd0;
        islem_gecerli_i = 1;
        #10; islem_gecerli_i = 0;
        #100;

        // End of simulation
        $finish;
    end

endmodule
