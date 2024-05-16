`timescale 1ns / 1ps

module tb_bit_manipulasyon_birimi_crc();



    // Parameters
    parameter XLEN = 32;

    // Inputs
    reg clk_i;
    reg rst_i;
    reg din_valid_i;
    reg [XLEN-1:0] din_value1_i;
    reg din_instruction_bit20_i;
    reg din_instruction_bit21_i;
    reg din_instruction_bit23_i;

    // Outputs
    wire din_ready_o;
    wire dout_valid_o;
    wire [XLEN-1:0] dout_result_o;

    bit_manipulasyon_birimi_crc #(.XLEN(XLEN)) uut (
        .clk_i(clk_i), 
        .rst_i(rst_i), 
        .din_valid_i(din_valid_i), 
        .din_ready_o(din_ready_o), 
        .din_value1_i(din_value1_i), 
        .din_instruction_bit20_i(din_instruction_bit20_i),
        .din_instruction_bit21_i(din_instruction_bit21_i),
        .din_instruction_bit23_i(din_instruction_bit23_i),
        .dout_valid_o(dout_valid_o), 
        .dout_ready_i(1'b1), 
        .dout_result_o(dout_result_o)
    );

    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i; // 100 MHz
    end

    initial begin
        rst_i = 1;
        din_valid_i = 0;
        din_value1_i = 0;
        din_instruction_bit20_i = 0;
        din_instruction_bit21_i = 0;
        din_instruction_bit23_i = 0;

        // Reset pulse
        #10;
        rst_i = 0;
        #10;

        // Test Case 1: CRC with first configuration
        din_value1_i = 32'hFFFFFFFF; 
        din_instruction_bit20_i = 0; 
        din_instruction_bit21_i = 0;
        din_instruction_bit23_i = 0; 
        din_valid_i = 1; 
        #20;
        din_valid_i = 0;

        // Test Case 2: CRC with second configuration (Polynomial 1)
        din_value1_i = 32'hABCD1234; 
        din_instruction_bit20_i = 1;
        din_instruction_bit21_i = 0;
        din_instruction_bit23_i = 0; 
        #10;
        din_valid_i = 1; 
        #20;
        din_valid_i = 0; 

        // Test Case 3: CRC with third configuration (Polynomial 2)
        din_value1_i = 32'h12345678; 
        din_instruction_bit20_i = 0;
        din_instruction_bit21_i = 1;
        din_instruction_bit23_i = 0; 
        #10; 
        din_valid_i = 1; 
        #20;
        din_valid_i = 0; 

        // Test Case 4: CRC with fourth configuration (Polynomial 3)
        din_value1_i = 32'h87654321; 
        din_instruction_bit20_i = 1;
        din_instruction_bit21_i = 1;
        din_instruction_bit23_i = 0; 
        #10; 
        din_valid_i = 1; 
        #20;
        din_valid_i = 0; 

        // Test Case 5: CRC with alternate mode (Polynomial 1, alternate mode)
        din_value1_i = 32'hFEDCBA98; 
        din_instruction_bit20_i = 0;
        din_instruction_bit21_i = 0;
        din_instruction_bit23_i = 1; 
        #10;
        din_valid_i = 1; 
        #20;
        din_valid_i = 0; 

        #100;
        $finish;
    end

endmodule