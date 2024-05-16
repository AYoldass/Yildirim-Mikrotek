`timescale 1ns / 1ps


module tb_bit_manipulasyon_birimi_zba();


// Parameters
parameter XLEN = 32;

// Inputs
reg clk;
reg rst;
reg din_valid;
reg [XLEN-1:0] din_value1, din_value2, din_value3;
reg din_instruction_bit3, din_instruction_bit5, din_instruction_bit12, din_instruction_bit13, din_instruction_bit14, din_instruction_bit25, din_instruction_bit26, din_instruction_bit27, din_instruction_bit30;

// Outputs
wire din_ready;
wire dout_valid;
wire [XLEN-1:0] dout_result;

bit_manipulasyon_birimi_zba #(.XLEN(XLEN)) uut (
    .clk_i(clk), 
    .rst_i(rst), 
    .din_valid_i(din_valid), 
    .din_ready_o(din_ready), 
    .din_value1_i(din_value1), 
    .din_value2_i(din_value2), 
    .din_value3_i(din_value3), 
    .din_instruction_bit3_i(din_instruction_bit3),
    .din_instruction_bit5_i(din_instruction_bit5),
    .din_instruction_bit12_i(din_instruction_bit12),
    .din_instruction_bit13_i(din_instruction_bit13),
    .din_instruction_bit14_i(din_instruction_bit14),
    .din_instruction_bit25_i(din_instruction_bit25),
    .din_instruction_bit26_i(din_instruction_bit26),
    .din_instruction_bit27_i(din_instruction_bit27),
    .din_instruction_bit30_i(din_instruction_bit30),
    .dout_valid_o(dout_valid), 
    .dout_ready_i(1'b1), 
    .dout_result_o(dout_result)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz
end

initial begin
    rst = 1'b1; 
    #10;
    rst = 1'b0; 
    din_valid = 0;
    din_value1 = 0;
    din_value2 = 0;
    din_value3 = 0;
    din_instruction_bit3 = 0;
    din_instruction_bit5 = 0;
    din_instruction_bit12 = 0;
    din_instruction_bit13 = 0;
    din_instruction_bit14 = 0;
    din_instruction_bit25 = 0;
    din_instruction_bit26 = 0;
    din_instruction_bit27 = 0;
    din_instruction_bit30 = 0;
end

initial begin
    #20;
    
    // Test Case 1: SH1ADD
    din_instruction_bit5 = 1; din_instruction_bit13 = 1;
    din_value1 = 32'h00000004; // Example values
    din_value2 = 32'h00000001;
    din_valid = 1;
    #10;
    din_valid = 0;

    // Test Case 2: SH2ADD
    // Reset instruction bits
    din_instruction_bit13 = 0; din_instruction_bit14 = 1;
    din_value1 = 32'h00000002; // New example values
    din_value2 = 32'h00000002;
    din_valid = 1;
    #10;
    din_valid = 0;

    // Test Case 3: SH3ADD
    din_instruction_bit13 = 1;
    din_value1 = 32'h00000001; // New example values
    din_value2 = 32'h00000003;
    din_valid = 1;
    #10;
    din_valid = 0;

    #20;

    // Test Case 4: ADDWU
    din_instruction_bit30 = 0; din_instruction_bit27 = 1; din_instruction_bit26 = 0; din_instruction_bit25 = 1; 
    din_instruction_bit14 = 0; din_instruction_bit13 = 0; din_instruction_bit12 = 0; din_instruction_bit5 = 1; 
    din_instruction_bit3 = 1;
    din_value1 = 32'h0000FFFF; // Example values
    din_value2 = 32'h00000001;
    din_valid = 1;
    #10;
    din_valid = 0;

    // Test Case 5: SUBWU
    din_instruction_bit30 = 1; // Change for SUBWU, rest remains the same as ADDWU setup
    din_value1 = 32'h00010000; // New example values
    din_value2 = 32'h00000001;
    din_valid = 1;
    #10;
    din_valid = 0;

    // Test Case 6: ADDUW
    din_instruction_bit25 = 0; // Change for ADDUW, rest remains the same as ADDWU setup
    din_value1 = 32'h0000FFFF; // Example values, same as ADDWU for comparison
    din_value2 = 32'h00000001;
    din_valid = 1;
    #10;
    din_valid = 0;

    // Test Case 7: SUBUW
    din_instruction_bit30 = 1; // Change for SUBUW, rest remains the same as SUBWU setup
    din_value1 = 32'h00010000; // New example values, same as SUBWU for comparison
    din_value2 = 32'h00000001;
    din_valid = 1;
    #10;
    din_valid = 0;


    #100; 
    $finish;
end

endmodule
