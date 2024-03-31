`timescale 1ns / 1ps


module tb_bit_manipulasyon_birimi_zbc();

    // Inputs
    reg clk_i;
    reg rst_i;
    reg din_valid_i;
    reg [31:0] din_value1_i;
    reg [31:0] din_value2_i;
    reg din_instruction_bit3_i;
    reg din_instruction_bit12_i;
    reg din_instruction_bit13_i;
    reg dout_ready_i;

    // Outputs
    wire din_ready_o;
    wire dout_valid_o;
    wire [31:0] dout_result_o;

    // Instantiate the Unit Under Test (UUT)
    bit_manipulasyon_birimi_zbc uut (
        .clk_i(clk_i), 
        .rst_i(rst_i), 
        .din_valid_i(din_valid_i), 
        .din_ready_o(din_ready_o), 
        .din_value1_i(din_value1_i), 
        .din_value2_i(din_value2_i), 
        .din_instruction_bit3_i(din_instruction_bit3_i), 
        .din_instruction_bit12_i(din_instruction_bit12_i), 
        .din_instruction_bit13_i(din_instruction_bit13_i), 
        .dout_valid_o(dout_valid_o), 
        .dout_ready_i(dout_ready_i), 
        .dout_result_o(dout_result_o)
    );

    // Clock generation
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i; // 100MHz clock
    end

    // Reset the design
    initial begin
        rst_i = 1;
        #100; // Wait 100ns for global reset
        rst_i = 0;
    end

    // Apply test cases
    initial begin
        // Initialize inputs
        din_valid_i = 0;
        din_value1_i = 0;
        din_value2_i = 0;
        din_instruction_bit3_i = 0;
        din_instruction_bit12_i = 0;
        din_instruction_bit13_i = 0;
        dout_ready_i = 1;

        // Wait for reset to complete
        #100;

        // Test different scenarios
        test_scenario(32'hFFFF0000, 32'h0000FFFF, 0, 1, 0, "Edge case 1");
        test_scenario(32'h12345678, 32'h87654321, 0, 0, 1, "Edge case 2");
        test_scenario(32'hABCDEF01, 32'h10FEDCBA, 1, 1, 0, "Random case 1");
        test_scenario(32'hF0F0F0F0, 32'h0F0F0F0F, 1, 0, 1, "Pattern case 1");
        test_scenario(32'h0, 32'hFFFFFFFF, 0, 1, 1, "Zero case 1");

        // Add more test scenarios as needed

        // Complete the simulation
        #50;
        $finish;
    end

    task test_scenario;
        input [31:0] value1;
        input [31:0] value2;
        input bit3, bit12, bit13;
        input [255:0] test_name; // A descriptive name for the test case
        begin
            $display("Starting test: %s", test_name);
            din_valid_i = 1;
            din_value1_i = value1;
            din_value2_i = value2;
            din_instruction_bit3_i = bit3;
            din_instruction_bit12_i = bit12;
            din_instruction_bit13_i = bit13;
            #10; // Wait for the operation to be accepted
            din_valid_i = 0;

            // Wait for result
            while (!dout_valid_o) #10;

            $display("Result for %s: %h", test_name, dout_result_o);
            #20; // Wait a bit before the next test
        end
    endtask

endmodule