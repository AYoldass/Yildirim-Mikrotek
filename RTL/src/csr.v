`timescale 1ns / 1ps
`include "riscv_controller.vh"


module csr#(
     parameter TRAP_ADDRESS = 0
    )(
     input wire clk,
     input wire rst,

    input wire external_interrupt_i, //interrupt from external source
    input wire software_interrupt_i, //interrupt from software (inter-processor interrupt)
    input wire timer_interrupt_i, //interrupt from timer

    input wire is_inst_illegal_i, //illegal instruction
    input wire is_ecall_i, //ecall instruction
    input wire is_ebreak_i, //ebreak instruction
    input wire is_mret_i, //mret (return from trap) instruction
    input wire is_load_addr_misaligned_i,
    input wire is_store_addr_misaligned_i,
    input wire is_inst_addr_misaligned_i,
    input wire is_inst_access_fault_i,
    input wire is_load_access_fault_i,

    input wire csr_enable, // birim_enable_o[7]
    input wire[31:0] value_i, 
    
    input wire [`MIKROISLEM_WIDTH-1:0] mikro_islem_i,

    input wire[11:0] csr_index_i, // immediate value from decoder
    input wire[31:0] imm_i, //unsigned immediate for immediate type of CSR instruction (new value to be stored to CSR)
    input wire[31:0] rs1_i, //Source register 1 value (new value to be stored to CSR)
    output reg[31:0] csr_out_o, //CSR value to be loaded to basereg

    input wire[31:0] pc_i, //Program Counter 
    input wire writeback_change_pc, // if writeback will issue change_pc 
    
    output reg[31:0] return_address_o, //mepc CSR
    output reg[31:0] trap_address_o, //mtvec CSR
    output reg go_to_trap_q_o, // before going to trap (if exception/interrupt detected)
    output reg return_from_trap_q_o, // before returning from trap 
    input wire minstret_inc_i, //increment minstret after executing an instruction

    input wire ce_i, 
    input wire durdur_i 
);
    
   
    
    reg[31:0] csr_in; 
    reg[31:0] csr_data; 
    //wire csr_enable = opcode_system && funct3_i!=0 && ce_i && !writeback_change_pc; 
    reg go_to_trap; 
    reg return_from_trap; 
    reg external_interrupt_pending; 
    reg software_interrupt_pending;
    reg timer_interrupt_pending;
    reg is_interrupt;
    reg is_exception;
    reg is_trap;
    wire durdur =durdur_i;

    reg mstatus_mie; //Machine Interrupt Enable
    reg mstatus_mpie; //Machine Previous Interrupt Enable
    reg[1:0] mstatus_mpp; //MPP
    reg mie_meie; //machine external interrupt enable
    reg mie_mtie; //machine timer interrupt enable
    reg mie_msie; //machine software interrupt enable
    reg[29:0] mtvec_base; //address of pc_i after returning from interrupt (via MRET)
    reg[1:0] mtvec_mode; //vector mode addressing 
    reg[31:0] mscratch; //dedicated for use by machine code
    reg[31:0] mepc; //machine exception pc_i (address of interrupted instruction)
    reg mcause_intbit; //interrupt(1) or exception(0)
    reg[3:0] mcause_code; //indicates event that caused the trap
    reg[31:0] mtval; //exception-specific infotmation to assist software in handling trap
    reg mip_meip; //machine external interrupt pending
    reg mip_mtip; //machine timer interrupt pending
    reg mip_msip; //machine software interrupt pending
    reg[63:0] mcycle; //counts number of i_clk cycle executed by core
    reg[63:0] minstret; //counts number instructions retired/executed by core
    reg mcountinhibit_cy; //controls increment of mcycle
    reg mcountinhibit_ir; //controls increment of minstret
    
    
    
    always @(posedge clk) begin
        if(!rst) begin
            go_to_trap_q_o <= 0;
            return_from_trap_q_o <= 0;        
            mstatus_mie <= 0;
            mstatus_mpie <= 0;
            mstatus_mpp <= 2'b11; // PRIV MACHINE MODE
            mie_meie <= 0;
            mie_mtie <= 0;
            mie_msie <= 0;
            mtvec_base <= TRAP_ADDRESS[31:2];
            mtvec_mode <= TRAP_ADDRESS[1:0];
            mscratch <= 0;
            mepc <= 0;
            mcause_intbit <= 0;
            mcause_code <= 0;
            mtval <= 0;
            mip_meip <= 0;
            mip_meip <= 0;
            mip_msip <= 0;
            mcycle <= 0;
            minstret <= 0;
            mcountinhibit_cy <= 0;
            mcountinhibit_ir <= 0;
        end
        else if(!durdur) begin
            if(csr_index_i == `MSTATUS && csr_enable) begin 
                mstatus_mie <= csr_in[3];
                mstatus_mpie <= csr_in[7];
            end
            else begin
                if(go_to_trap && !go_to_trap_q_o) begin
                    mstatus_mie <= 0; 
                    mstatus_mpie <= mstatus_mie; 
                    mstatus_mpp <= 2'b11;
                end
                else if(return_from_trap) begin
                    mstatus_mie <= mstatus_mpie; 
                    mstatus_mpie <= 1;
                    mstatus_mpp <= 2'b11;
                end
            end
            if(csr_index_i == `MIE && csr_enable) begin   
                mie_msie <= csr_in[3]; 
                mie_mtie <= csr_in[7]; 
                mie_meie <= csr_in[11]; 
            end  
            if(csr_index_i == `MTVEC && csr_enable) begin
                mtvec_base <= csr_in[31:2];
                mtvec_mode <= csr_in[1:0]; 
            end
            if(csr_index_i == `MSCRATCH && csr_enable) begin
                mscratch <= csr_in;
            end

            if(csr_index_i == `MEPC && csr_enable) begin 
                mepc <= {csr_in[31:2],2'b00};
            end
            if(go_to_trap && !go_to_trap_q_o) mepc <= pc_i; 
            
            if(csr_index_i == `MCAUSE && csr_enable) begin
               mcause_intbit <= csr_in[31];
               mcause_code <= csr_in[3:0];         
            end
            if(go_to_trap && !go_to_trap_q_o) begin
                if(external_interrupt_pending) begin 
                    mcause_code <= `MACHINE_EXTERNAL_INTERRUPT; 
                    mcause_intbit <= 1;
                end
                else if(software_interrupt_pending) begin
                    mcause_code <= `MACHINE_SOFTWARE_INTERRUPT; 
                    mcause_intbit <= 1;
                end
                else if(timer_interrupt_pending) begin 
                    mcause_code <= `MACHINE_TIMER_INTERRUPT; 
                    mcause_intbit <= 1;
                end
                else if(is_inst_illegal_i) begin
                    mcause_code <= `ILLEGAL_INSTRUCTION;
                    mcause_intbit <= 0 ;
                end
                else if(is_inst_addr_misaligned_i) begin
                    mcause_code <= `INSTRUCTION_ADDRESS_MISALIGNED;
                    mcause_intbit <= 0;
                end
                else if(is_ecall_i) begin 
                    mcause_code <= `ECALL;
                    mcause_intbit <= 0;
                end
                else if(is_ebreak_i) begin
                    mcause_code <= `EBREAK;
                    mcause_intbit <= 0;
                end
                else if(is_load_addr_misaligned_i) begin
                    mcause_code <= `LOAD_ADDRESS_MISALIGNED;
                    mcause_intbit <= 0;
                end
                else if(is_store_addr_misaligned_i) begin
                    mcause_code <= `STORE_ADDRESS_MISALIGNED;
                    mcause_intbit <= 0;
                end
                else if(is_inst_access_fault_i) begin
                    mcause_code <= `INSTRUCTION_ACCESS_FAULT;
                    mcause_intbit <= 0;
                end
                 else if(is_load_access_fault_i) begin
                    mcause_code <= `LOAD_ACCESS_FAULT;
                    mcause_intbit <= 0;
                end
            end
            
            if(csr_index_i == `MTVAL && csr_enable) begin
                mtval <= csr_in;
            end

            if(go_to_trap && !go_to_trap_q_o) begin
                if(is_load_addr_misaligned_i || is_store_addr_misaligned_i) mtval <= value_i;
            end           
          
            if(csr_index_i == `MCYCLE && csr_enable) begin
                mcycle[31:0] <= csr_in; 
            end
           
            if(csr_index_i == `MCYCLEH && csr_enable) begin
                mcycle[63:32] <= csr_in; 
            end
            mcycle <= mcountinhibit_cy? mcycle : mcycle + 1; //increments mcycle every clock cycle
       
            mip_msip <= software_interrupt_i;
            mip_mtip <= timer_interrupt_i;
            mip_meip <= external_interrupt_i;
                 
            if(csr_index_i == `MINSTRET && csr_enable) begin
                minstret[31:0] <= csr_in; 
            end
         
            if(csr_index_i == `MINSTRETH && csr_enable) begin
                minstret[63:32] <= csr_in; 
            end
             minstret <= mcountinhibit_ir? minstret : minstret + {63'b0,(minstret_inc_i && !go_to_trap_q_o && !return_from_trap_q_o)}; //increment minstret every instruction
 
            if(csr_index_i == `MCOUNTINHIBIT && csr_enable) begin
                mcountinhibit_cy <= csr_in[0];
                mcountinhibit_ir <= csr_in[2];
            end
             if(ce_i) begin
                 go_to_trap_q_o <= go_to_trap;
                 return_from_trap_q_o <= return_from_trap;
                 return_address_o <= mepc;
                 
                 if(mtvec_mode[1] && is_interrupt) trap_address_o <= {mtvec_base,2'b00} + {28'b0,mcause_code<<2};
                 else trap_address_o <= {mtvec_base,2'b00};
                                  
                 csr_out_o <= csr_data;
              end
              else begin 
                go_to_trap_q_o <= 0;
                return_from_trap_q_o <= 0;
              end
        end
        else begin
            mcycle <= mcountinhibit_cy? mcycle : mcycle + 1; //increments mcycle every clock cycle
            minstret <= mcountinhibit_ir? minstret : minstret + {63'b0,(minstret_inc_i && !go_to_trap_q_o && !return_from_trap_q_o)}; //increment minstret every instruction
        end
    end

   always @* begin
        external_interrupt_pending = 0;
        software_interrupt_pending = 0;
        timer_interrupt_pending = 0;
        is_interrupt = 0;
        is_exception = 0;
        is_trap = 0;
        go_to_trap = 0;
        return_from_trap = 0;
        
        if(ce_i) begin
             external_interrupt_pending =  mstatus_mie && mie_meie && (mip_meip); //machine_interrupt_enable + machine_external_interrupt_enable + machine_external_interrupt_pending 
             software_interrupt_pending = mstatus_mie && mie_msie && mip_msip;  //machine_interrupt_enable + machine_software_interrupt_enable + machine_software_interrupt_pending 
             timer_interrupt_pending = mstatus_mie && mie_mtie && mip_mtip; //machine_interrupt_enable + machine_timer_interrupt_enable + machine_timer_interrupt_pending
             
             is_interrupt = external_interrupt_pending || software_interrupt_pending || timer_interrupt_pending;
             is_exception = (is_inst_illegal_i || is_inst_addr_misaligned_i || is_ecall_i || is_ebreak_i || is_load_addr_misaligned_i || is_store_addr_misaligned_i || is_inst_access_fault_i || is_load_access_fault_i) && !writeback_change_pc;
             is_trap = is_interrupt || is_exception;
             go_to_trap = is_trap; //a trap is taken, save pc_i, and go to trap address
             return_from_trap = is_mret_i; // return from trap, go back to saved pc_i
             
         end         
         
        csr_data = 0;
        csr_in = 0;
        case(csr_index_i)         
              `MSTATUS: begin 
                        csr_data[3] = mstatus_mie;
                        csr_data[7] = mstatus_mpie;
                        csr_data[12:11] = mstatus_mpp; 
                       end
                       
                 `MISA: begin 
                        csr_data[8] = 1'b1; //RV32I/64I/128I base ISA 
                        csr_data[31:30] = 2'b01; //Base 32
                       end
                       
                  `MIE: begin //MIE (interrupt enable bits)
                        csr_data[3] = mie_msie;
                        csr_data[7] = mie_mtie;
                        csr_data[11] = mie_meie;
                       end
                       
                `MTVEC: begin 
                        csr_data = {mtvec_base,mtvec_mode};
                       end
                       
             `MSCRATCH: begin 
                        csr_data = mscratch;
                       end
                       
                 `MEPC: begin 
                        csr_data = mepc; 
                       end
                       
               `MCAUSE: begin 
                        csr_data[31] = mcause_intbit; 
                        csr_data[3:0] = mcause_code;
                       end
                       
                `MTVAL: begin 
                        csr_data = mtval;
                       end
                
                  `MIP: begin 
                        csr_data[3] = mip_msip;
                        csr_data[7] = mip_mtip;
                        csr_data[11] = mip_meip;
                       end
                       
               `MCYCLE: begin 
                        csr_data = mcycle[31:0];
                       end
                       
               `MCYCLEH: begin 
                        csr_data = mcycle[63:32];
                       end
           
             `MINSTRET: begin
                        csr_data = minstret[31:0];
                       end
                       
            `MINSTRETH: begin     
                        csr_data = minstret[63:32];
                       end
                       
        `MCOUNTINHIBIT: begin 
                        csr_data[0] = mcountinhibit_cy;
                        csr_data[2] = mcountinhibit_ir;
                       end
                       
              default: csr_data = 0;
        endcase
              
        if(mikro_islem_i[`CSRRW]) //CSR read-write
            csr_in = rs1_i;
        else if(mikro_islem_i[`CSRRS]) //CSR read-set
            csr_in = csr_data | rs1_i;     
        else if(mikro_islem_i[`CSRRC]) //CSR read-clear
            csr_in = csr_data & (~rs1_i);     
        else if(mikro_islem_i[`CSRRWI]) //csr read-write immediate
            csr_in = imm_i;    
        else if(mikro_islem_i[`CSRRSI]) //csr read-set immediate
            csr_in = csr_data | imm_i;
        else if(mikro_islem_i[`CSRRCI]) //csr read-clear immediate
            csr_in = csr_data & (~imm_i);
        else
            csr_in=0;
   end
endmodule
