`timescale 1ns / 1ps
`include "riscv_controller.vh"

module exception_detection (
    input clk_i,
    input rst_i,
    input [31:0] pc_i,
    input [31:0] memory_addr_i,
    
    input  [`OPCODE_WIDTH-1:0] opcode_i,
    input  [`MIKROISLEM_WIDTH-1:0] mikro_islem_i, 
    
    output reg INSTRUCTION_ADDRESS_MISALIGNED,
    output reg INSTRUCTION_ACCESS_FAULT,
    output reg LOAD_ADDRESS_MISALIGNED,
    output reg LOAD_ACCESS_FAULT,
    output reg STORE_ADDRESS_MISALIGNED,
    output reg STORE_ACCESS_FAULT
);

    reg [31:0] pc_reg;
    reg [31:0] memory_addr_reg;
    reg [`OPCODE_WIDTH-1:0] opcode_reg;
    reg [`MIKROISLEM_WIDTH-1:0] mikro_islem_reg;
    
    reg instruction_address_misaligned=0;
    reg instruction_access_fault=0;
    reg load_address_misaligned=0;
    reg load_access_fault=0;
    reg store_address_misaligned=0;
    reg store_access_fault=0;
    
    reg opcode_load;
    reg opcode_store;
    reg opcode_branch;
    reg opcode_jal;
    reg opcode_jalr;
    
    always @(posedge clk_i) begin
        if (rst_i) begin
            pc_reg <= 32'h80000000;
            memory_addr_reg <= 32'h80000000;
            opcode_reg <= 0;
            mikro_islem_reg <= 0;
            opcode_load <= 0;
            opcode_store <= 0;
            opcode_branch <= 0;
            opcode_jal <= 0;
            opcode_jalr <= 0;
            INSTRUCTION_ADDRESS_MISALIGNED <= 0;
            INSTRUCTION_ACCESS_FAULT <= 0;
            LOAD_ADDRESS_MISALIGNED <= 0;
            LOAD_ACCESS_FAULT <= 0;
            STORE_ADDRESS_MISALIGNED <= 0;
            STORE_ACCESS_FAULT <= 0;
        end else begin
            pc_reg <= pc_i;
            memory_addr_reg <= memory_addr_i;
            opcode_reg <= opcode_i;
            mikro_islem_reg <= mikro_islem_i;
            opcode_load <= opcode_i[`LOAD] ? 1 : 0;
            opcode_store <= opcode_i[`STORE] ? 1 : 0;
            opcode_branch <=opcode_i[`BRANCH] ? 1 : 0;
            opcode_jal<= opcode_i[`JAL] ? 1 : 0;
            opcode_jalr<= opcode_i[`JALR] ? 1 : 0;
            INSTRUCTION_ADDRESS_MISALIGNED <= instruction_address_misaligned;
            INSTRUCTION_ACCESS_FAULT <= instruction_access_fault;
            LOAD_ADDRESS_MISALIGNED <= load_address_misaligned;
            LOAD_ACCESS_FAULT <= load_access_fault;
            STORE_ADDRESS_MISALIGNED <= store_address_misaligned;
            STORE_ACCESS_FAULT <= store_access_fault;
        end
    end
    always @* begin

        // Check for misaligned instruction address
        if ((opcode_branch && (pc_reg[1:0] != 2'b00)) || 
            (opcode_jal && (pc_reg[1:0] != 2'b00)) || 
            (opcode_jalr && (pc_reg[1:0] != 2'b00))) begin
            instruction_address_misaligned = 1;
        end

        // Check for instruction access fault
        if (pc_reg < `VALID_MEM_START || pc_reg > `VALID_MEM_END) begin // VALID_MEM_START=32'h80000000 and VALID_MEM_END=32'h80000FFF
            instruction_access_fault = 1;
        end

        // Check for misaligned load address
        if (opcode_load) begin
            if(mikro_islem_reg[`LH])begin // LH (halfword load)
                if (memory_addr_reg[0] != 0) begin
                        load_address_misaligned = 1;
                end
            end
            else if(mikro_islem_reg[`LW])begin // LW (word load)
                 if (memory_addr_reg[1:0] != 2'b00) begin
                        load_address_misaligned = 1;
                 end 
            end        
            else if(mikro_islem_reg[`LHU])begin // LHU (halfword load unsigned)
                if (memory_addr_reg[0] != 0) begin
                        load_address_misaligned = 1;
                end   
            end        
        end

        // Check for load access fault
        if (opcode_load && (memory_addr_reg < `VALID_MEM_START || memory_addr_reg > `VALID_MEM_END)) begin
            load_access_fault = 1;
        end

        // Check for misaligned store address
        if (opcode_store) begin
            if(mikro_islem_reg[`SH])begin // SH (halfword store)
                if (memory_addr_reg[0] != 0) begin
                        store_address_misaligned = 1;
                end   
            end
            else if(mikro_islem_reg[`SW])begin // SW (word store)
                  if (memory_addr_i[1:0] != 2'b00) begin
                        store_address_misaligned = 1;
                  end
            end                     
        end

        // Check for store access fault
        if (opcode_store && (memory_addr_reg < `VALID_MEM_START || memory_addr_reg > `VALID_MEM_END)) begin
            store_access_fault = 1;
        end
    end
endmodule
