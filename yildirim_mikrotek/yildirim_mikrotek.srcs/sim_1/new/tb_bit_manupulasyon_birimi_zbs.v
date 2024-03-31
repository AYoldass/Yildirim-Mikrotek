`timescale 1ns / 1ps


module tb_bit_manupulasyon_birimi_zbs();


    reg clk_i, rst_i;
    reg din_valid_i;
    reg [31:0] din_value1_i, din_value2_i, din_value3_i;
    reg din_instruction_bit3_i, din_instruction_bit13_i, din_instruction_bit14_i;
    reg din_instruction_bit26_i, din_instruction_bit27_i, din_instruction_bit29_i, din_instruction_bit30_i;
    wire din_ready_o, dout_valid_o;
    wire [31:0] dout_result_o;

    bit_manupulasyon_birimi_zbs #(
        .XLEN(32),
        .SBOP(1),
        .BFP(1)
    ) uut (
        .clk_i(clk_i),          
        .rst_i(rst_i),        
        .din_valid_i(din_valid_i),      
        .din_ready_o(din_ready_o),      
        .din_value1_i(din_value1_i),       
        .din_value2_i(din_value2_i),       
        .din_value3_i(din_value3_i),       
        .din_instruction_bit3_i(din_instruction_bit3_i),      
        .din_instruction_bit13_i(din_instruction_bit13_i),     
        .din_instruction_bit14_i(din_instruction_bit14_i),    
        .din_instruction_bit26_i(din_instruction_bit26_i),    
        .din_instruction_bit27_i(din_instruction_bit27_i),     
        .din_instruction_bit29_i(din_instruction_bit29_i),    
        .din_instruction_bit30_i(din_instruction_bit30_i),     
        .dout_valid_o(dout_valid_o),     
        .dout_ready_i(1'b1),     
        .dout_result_o(dout_result_o)         
    );

    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    initial begin
        rst_i = 1;
        #10;
        rst_i = 0;
        #20;

        // Initialize inputs to default values
        din_value1_i = 0;
        din_value2_i = 0;
        din_value3_i = 0;
        din_instruction_bit3_i = 0;
        din_instruction_bit13_i = 0;
        din_instruction_bit14_i = 0;
        din_instruction_bit26_i = 0;
        din_instruction_bit27_i = 0;
        din_instruction_bit29_i = 0;
        din_instruction_bit30_i = 0;

        // Example test case for SLL operation
        perform_test(32'h00000001, 32'h00000002, 32'h00000000, 0, 0, 0, 0, 0, 0, 0, "Test SLL");

        // BSET Test - Set bit position 2 of 0b0000 (should result in 0b0100)
         perform_test(32'h00000004, 32'h00000002, 32'h00000000, 0, 0, 0, 0, 1, 1, 0, "BSET Test");

        // BINV Test - Invert bit position 2 of 0b0100 (should result in 0b0000)
        perform_test(32'h00000004, 32'h00000002, 32'h00000000, 0, 0, 0, 0, 1, 1, 1, "BINV Test");

        // BEXT Test - Extract bit position 2 of 0b0100 (should result in 0b0001)
        perform_test(32'h00000004, 32'h00000002, 32'h00000000, 0, 0, 1, 0, 1, 0, 1, "BEXT Test");

        // BCLR Test - Clear bit position 2 of 0b0100 (should result in 0b0000)
        perform_test(32'h00000004, 32'h00000002, 32'h00000000, 0, 0, 0, 0, 1, 0, 1, "BCLR Test");
        
         // BSETI Test - Set bit position indicated by immediate value
        perform_test(32'h00000000, 2, 32'h00000000, 1, 0, 0, 0, 1, 1, 0, "BSETI Test"); // Set bit 2

         // BINVI Test - Invert bit position indicated by immediate value
        perform_test(32'h00000004, 2, 32'h00000000, 1, 0, 0, 0, 1, 1, 1, "BINVI Test"); // Invert bit 2

        // BEXTI Test - Extract bit at position indicated by immediate value
        perform_test(32'h00000004, 2, 32'h00000000, 1, 0, 1, 0, 1, 0, 1, "BEXTI Test"); // Extract bit 2

        // BCLRI Test - Clear bit position indicated by immediate value
        perform_test(32'h00000004, 2, 32'h00000000, 1, 0, 0, 0, 1, 0, 1, "BCLRI Test"); // Clear bit 2
        
        #100;
        $finish;
    end

    task perform_test;
        input [31:0] value1;
        input [31:0] value2;
        input [31:0] value3;
        input bit3, bit13, bit14, bit26, bit27, bit29, bit30;
        input [256*8:1] testname; // Test name for logging
        begin
            $display("Starting %s", testname);
            din_valid_i = 1;
            din_value1_i = value1;
            din_value2_i = value2;
            din_value3_i = value3;
            din_instruction_bit3_i = bit3;
            din_instruction_bit13_i = bit13;
            din_instruction_bit14_i = bit14;
            din_instruction_bit26_i = bit26;
            din_instruction_bit27_i = bit27;
            din_instruction_bit29_i = bit29;
            din_instruction_bit30_i = bit30;
            #10; // Simulate a clock cycle for setup
            din_valid_i = 0;
            wait(dout_valid_o); // Wait for the module to process the input
            #10; // Simulate a clock cycle for hold
            $display("%s Result: %h", testname, dout_result_o);
        end
    endtask

endmodule