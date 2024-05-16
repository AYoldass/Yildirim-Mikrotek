`timescale 1ns / 1ps


module tb_bit_manipulasyon_birimi_bitcnt();


    // Parameters
    parameter XLEN = 32;
    parameter BMAT = 0; // Example parameter, adjust if needed

    // Inputs
    reg clk_i;
    reg rst_i;
    reg din_valid_i;
    reg [XLEN-1:0] din_value1_i;
    reg din_instruction_bit3_i;
    reg din_instruction_bit20_i;
    reg din_instruction_bit21_i;
    reg din_instruction_bit22_i;

    // Outputs
    wire din_ready_o;
    wire dout_valid_o;
    wire [XLEN-1:0] dout_result_o;

    bit_manipulasyon_birim_bitcnt #(
        .XLEN(XLEN),
        .BMAT(BMAT)
    ) uut (
        .clk_i(clk_i), 
        .rst_i(rst_i), 
        .din_valid_i(din_valid_i), 
        .din_ready_o(din_ready_o), 
        .din_value1_i(din_value1_i), 
        .din_instruction_bit3_i(din_instruction_bit3_i),
        .din_instruction_bit20_i(din_instruction_bit20_i),
        .din_instruction_bit21_i(din_instruction_bit21_i),
        .din_instruction_bit22_i(din_instruction_bit22_i),
        .dout_valid_o(dout_valid_o), 
        .dout_ready_i(1'b1), 
        .dout_result_o(dout_result_o)
    );

    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i; // 100 MHz clock
    end

    initial begin
        rst_i = 1;
        din_valid_i = 0;
        din_value1_i = 0;
        din_instruction_bit3_i = 0;
        din_instruction_bit20_i = 0;
        din_instruction_bit21_i = 0;
        din_instruction_bit22_i = 0;

        #10;
        rst_i = 0;
        #10;

        // Test Case 1: CLZ
        din_value1_i = 32'hF0000000; // Example input data
        din_instruction_bit20_i = 0;
        din_instruction_bit21_i = 0;
        din_instruction_bit22_i = 0; // CLZ
        din_valid_i = 1;
        #10;
        din_valid_i = 0;

        // Test Case 2: CTZ
        // Set up for CTZ and change din_value1_i as needed
        din_instruction_bit20_i = 1; // CTZ
        // Provide new test input if needed
        din_valid_i = 1;
        #10;
        din_valid_i = 0;

        // Test Case 3: PCNT
        // Set up for PCNT and change din_value1_i as needed
        din_instruction_bit20_i = 0;
        din_instruction_bit21_i = 1; // PCNT
        // Provide new test input if needed
        din_valid_i = 1;
        #10;
        din_valid_i = 0;

         // BMATFLIP test case
        // Reset necessary bits for BMATFLIP
        #10;
        din_value1_i = 32'hAA55AA55; // Example input data for BMATFLIP
        din_instruction_bit20_i = 1; // BMATFLIP requires bit20_i = 1
        din_instruction_bit21_i = 1; // and bit21_i = 1
        din_instruction_bit22_i = 0; // Not used for BMATFLIP
        din_instruction_bit3_i = 0; // bit3_i not used for BMATFLIP
        din_valid_i = 1;
        #10;
        din_valid_i = 0;

        // SEXT.B test case
        // Reset and set up for SEXT.B
        #10;
        din_value1_i = 32'hFF; // Lower byte will be sign-extended
        din_instruction_bit20_i = 0; // SEXT.B requires bit20_i = 0
        din_instruction_bit21_i = 0; // and bit21_i = 0
        din_instruction_bit22_i = 1; // SEXT operations use bit22_i = 1
        din_instruction_bit3_i = 0; // SEXT.B does not use bit3_i
        din_valid_i = 1;
        #10;
        din_valid_i = 0;

        // SEXT.H test case
        // Reset and set up for SEXT.H
        #10;
        din_value1_i = 32'hFFFF; // Lower half-word will be sign-extended
        din_instruction_bit20_i = 1; // SEXT.H requires bit20_i = 1
        din_instruction_bit21_i = 0; // and bit21_i = 0
        din_instruction_bit22_i = 1; // SEXT operations use bit22_i = 1
        din_instruction_bit3_i = 0; // SEXT.H does not use bit3_i
        din_valid_i = 1;
        #10;
        din_valid_i = 0;

        #100;
        $finish;
    end

endmodule

