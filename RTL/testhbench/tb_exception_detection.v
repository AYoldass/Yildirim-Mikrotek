`timescale 1ns / 1ps
`include "riscv_controller.vh"

module tb_exception_detection();

    reg clk;
    reg rst;
    reg [31:0] pc_i;
    reg [31:0] memory_addr_i;
    reg [`OPCODE_WIDTH-1:0] opcode_i;
    reg [`MIKROISLEM_WIDTH-1:0] mikro_islem_i;

    // Çýkýþlar
    wire INSTRUCTION_ADDRESS_MISALIGNED;
    wire INSTRUCTION_ACCESS_FAULT;
    wire LOAD_ADDRESS_MISALIGNED;
    wire LOAD_ACCESS_FAULT;
    wire STORE_ADDRESS_MISALIGNED;
    wire STORE_ACCESS_FAULT;

    // DUT (Device Under Test) tanýmý
    exception_detection uut (
        .clk_i(clk),
        .rst_i(rst),
        .pc_i(pc_i),
        .memory_addr_i(memory_addr_i),
        .opcode_i(opcode_i),
        .mikro_islem_i(mikro_islem_i),
        .INSTRUCTION_ADDRESS_MISALIGNED(INSTRUCTION_ADDRESS_MISALIGNED),
        .INSTRUCTION_ACCESS_FAULT(INSTRUCTION_ACCESS_FAULT),
        .LOAD_ADDRESS_MISALIGNED(LOAD_ADDRESS_MISALIGNED),
        .LOAD_ACCESS_FAULT(LOAD_ACCESS_FAULT),
        .STORE_ADDRESS_MISALIGNED(STORE_ADDRESS_MISALIGNED),
        .STORE_ACCESS_FAULT(STORE_ACCESS_FAULT)
    );
    
    always begin
        #5 clk = ~clk;
    end

    initial begin
        // Clock ve reset baþlangýcý
        clk = 0;
        rst = 0;

        // Reset iþlemi
        rst = 1;
        #5;
        rst = 0;

        pc_i = 32'h80000000;
        memory_addr_i = 32'h0;
        opcode_i = `OPCODE_WIDTH'b0;
        mikro_islem_i = `MIKROISLEM_WIDTH'b0;
        #100;

        // Test 1: Misaligned Instruction Address
        pc_i = 32'h80000002; // Misaligned address
        opcode_i[`BRANCH]=1;
        #100;

        // Test 2: Instruction Access Fault
        pc_i = 32'h70000000; // Out of valid range
        opcode_i[`BRANCH]=1;
        #100;

        // Test 3: Misaligned Load Address
        pc_i = 32'h80000000; // Valid address
        memory_addr_i = 32'h80000001; // Misaligned address for LH
        opcode_i[`LOAD]=1;
        mikro_islem_i[`LH]=1;
        #100;

        // Test 4: Load Access Fault
        memory_addr_i = 32'h70000000; // Out of valid range
        opcode_i[`LOAD]=1;
        mikro_islem_i[`LW]=1;
        #100;

        // Test 5: Misaligned Store Address
        memory_addr_i = 32'h80000001; // Misaligned address for SH
        opcode_i[`STORE]=1;
        mikro_islem_i[`SH]=1;
        #100;

        // Test 6: Store Access Fault
        memory_addr_i = 32'h70000000; // Out of valid range
        opcode_i[`STORE]=1;
        mikro_islem_i[`SW]=1;
        #100;
      
    end
    

endmodule
