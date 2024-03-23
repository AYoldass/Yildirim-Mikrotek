`timescale 1ns / 1ps

module tb_kayan_nokta_birimi();

 // Inputs
    reg clk;
    reg rst;
    reg [31:0] value1;
    reg [31:0] value2;
    reg [31:0] value3;
    reg [5:0] FPU_operation;
    reg [2:0] rounding_mode;
    reg start;
    
    // Outputs
    wire [31:0] result;
    wire [4:0] flags;
    wire mesgul;

    // Instantiate the FPU unit
    kayan_nokta_birimi dut (
        .clk_i              (clk),
        .rst_i              (rst),
        .value1_i           (value1),
        .value2_i           (value2),
        .value3_i           (value3),
        .FPU_operation_i    (FPU_operation),
        .rounding_mode_i    (rounding_mode),
        .start_i            (start),
        .result_o           (result),
        .flags_o            (flags),
        .mesgul_o           (mesgul)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Reset generation
    initial begin
        rst = 1;
        #10 rst = 0;
    end

    // Test cases
    initial begin
        // Test case 1: FADD
        value1 = 32'b01000000001100000000000000000000; // 3.0
        value2 = 32'b01000000001000000000000000000000; // 2.0
        value3 = 32'b00000000000000000000000000000000; // Unused for FADD
        FPU_operation = 6'b000000; // FADD
        rounding_mode = 3'b000; // Round to nearest
        start = 1;
        #20;
        start = 0;
        // Expected result: 5.0 (binary: 01000000010100000000000000000000)
        if (result !== 32'b01000000010100000000000000000000) $display("Test case 1 failed!");

        // Test case 2: FSUB
        value1 = 32'b01000000001100000000000000000000; // 3.0
        value2 = 32'b01000000001000000000000000000000; // 2.0
        value3 = 32'b00000000000000000000000000000000; // Unused for FSUB
        FPU_operation = 6'b000001; // FSUB
        rounding_mode = 3'b000; // Round to nearest
        start = 1;
        #20;
        start = 0;
        // Expected result: 1.0 (binary: 01000000000100000000000000000000)
        if (result !== 32'b01000000000100000000000000000000) $display("Test case 2 failed!");

        // Test case 3: FMUL
        value1 = 32'b01000000001100000000000000000000; // 3.0
        value2 = 32'b01000000001000000000000000000000; // 2.0
        value3 = 32'b00000000000000000000000000000000; // Unused for FMUL
        FPU_operation = 6'b000010; // FMUL
        rounding_mode = 3'b000; // Round to nearest
        start = 1;
        #20;
        start = 0;
        // Expected result: 6.0 (binary: 01000000010000000000000000000000)
        if (result !== 32'b01000000010000000000000000000000) $display("Test case 3 failed!");

        // Test case 4: FDIV
        value1 = 32'b01000000010000000000000000000000; // 4.0
        value2 = 32'b01000000001000000000000000000000; // 2.0
        value3 = 32'b00000000000000000000000000000000; // Unused for FDIV
        FPU_operation = 6'b000011; // FDIV
        rounding_mode = 3'b000; // Round to nearest
        start = 1;
        #20;
        start = 0;
        // Expected result: 2.0 (binary: 01000000000000000000000000000000)
        if (result !== 32'b01000000000000000000000000000000) $display("Test case 4 failed!");

        // Test case 5: Invalid operation
        value1 = 32'b01000000001100000000000000000000; // 3.0
        value2 = 32'b01000000001000000000000000000000; // 2.0
        value3 = 32'b00000000000000000000000000000000; // Unused for invalid operation
        FPU_operation = 6'b111111; // Invalid operation
        rounding_mode = 3'b000; // Round to nearest
        start = 1;
        #20;
        start = 0;
        // Expected result: xx
        if (result !== 32'bx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx) $display("Test case 5 failed!");

        // More test cases can be added as needed
    end

endmodule