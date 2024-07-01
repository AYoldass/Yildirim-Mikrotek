`timescale 1ns / 1ps
`include "riscv_controller.vh"



module writeback(
    input wire [7:0] birim_enable_i, 
    input wire[31:0] data_load_i, //data to be loaded to base reg
    input wire[31:0] csr_out_i, //CSR value to be loaded to basereg
    
    input wire [`OPCODE_WIDTH-1:0] opcode_i,
    input wire [31:0] imm_i,
    
    input wire wr_rd_i, //write rd to basereg if enabled (from previous stage)
    output reg wr_rd_o, //write rd to the base reg if enabled
    
    input wire[4:0] rd_addr_i, //address for destination register (from previous stage)
    output reg[4:0] rd_addr_o, //address for destination register
    
    input wire[31:0] rd_i, //value to be written back to destination register (from previous stage)
    output reg[31:0] rd_o, //value to be written back to destination register
    
    // PC Control
    input wire[31:0] pc_i, // pc value (from previous stage)
    output reg[31:0] next_pc_o, //new pc value
    output reg change_pc_o, //high if PC needs to jump
    
    input wire go_to_trap_i, //high before going to trap (if exception/interrupt detected)
    input wire return_from_trap_i, //high before returning from trap (via mret)
    input wire[31:0] return_address_i, //mepc CSR
    input wire[31:0] trap_address_i, //mtvec CSR
    
    input wire ce_i, // input clk enable for pipeline stalling of this stage
    output reg stall_o, //informs pipeline to stall
    output reg flush_o //flush previous stages

    );
     wire opcode_load= opcode_i[`LOAD] ? 1 : 0;
     wire opcode_system= opcode_i[`SYSTEM] ? 1 : 0;
     wire opcode_jal= opcode_i[`JAL] ? 1 : 0;
     wire opcode_jalr= opcode_i[`JALR] ? 1 : 0;
     wire csr_enable = birim_enable_i[`BIRIM_CSR];
    
     always @* begin
        stall_o = 0; //stall when this stage needs wait time
        flush_o = 0; //flush this stage along with previous stages when changing PC
        wr_rd_o = wr_rd_i && ce_i && !stall_o;
        rd_addr_o = rd_addr_i;
        rd_o = 0;
        next_pc_o = 0;
        change_pc_o = 0;

        if(go_to_trap_i) begin
            change_pc_o = 1; //change PC only when ce of this stage is high (change_pc_o is valid)
            next_pc_o = trap_address_i;  //interrupt or exception detected so go to trap address (mtvec value)
            flush_o = ce_i;
            wr_rd_o = 0;
        end
        
        else if(return_from_trap_i) begin
            change_pc_o = 1; //change PC only when ce of this stage is high (change_pc_o is valid)
             next_pc_o = return_address_i; //return from trap via mret (mepc value)
             flush_o = ce_i;
             wr_rd_o = 0;
        end
        
        else begin 
            if(opcode_load) rd_o = data_load_i; 
            else if(csr_enable) begin // CSR write
                rd_o = csr_out_i; 
            end
            else if(opcode_jal || opcode_jalr) begin
                rd_o = pc_i + 4; 
                next_pc_o = opcode_jal ? pc_i + imm_i :( rd_i+imm_i& ~32'b1); // Calculate next PC for JAL or JALR
                change_pc_o = 1;
                flush_o = ce_i;
              
            end
            else rd_o = rd_i; 
        end
        
    end
endmodule
