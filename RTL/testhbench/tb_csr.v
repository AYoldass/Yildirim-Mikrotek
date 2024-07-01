`timescale 1ns / 1ps


module tb_csr();
      // Testbench signals
    reg clk;
    reg rst;
    reg external_interrupt_i;
    reg software_interrupt_i;
    reg timer_interrupt_i;
    reg is_inst_illegal_i;
    reg is_ecall_i;
    reg is_ebreak_i;
    reg is_mret_i;
    reg is_load_addr_misaligned_i;
    reg is_store_addr_misaligned_i;
    reg is_inst_addr_misaligned_i;
    reg is_inst_access_fault_i;
    reg is_load_access_fault_i;
    reg csr_enable;
    reg [31:0] value_i;
    reg [`MIKROISLEM_WIDTH-1:0] mikro_islem_i;
    reg [11:0] csr_index_i;
    reg [31:0] imm_i;
    reg [31:0] rs1_i;
    reg [31:0] pc_i;
    reg writeback_change_pc;
    reg minstret_inc_i;
    reg ce_i;
    reg durdur_i;
    
    wire [31:0] csr_out_o;
    wire [31:0] return_address_o;
    wire [31:0] trap_address_o;
    wire go_to_trap_q_o;
    wire return_from_trap_q_o;

    // Instantiate the CSR module
    csr #(.TRAP_ADDRESS(32'h00000004)) dut (
        .clk(clk),
        .rst(rst),
        .external_interrupt_i(external_interrupt_i),
        .software_interrupt_i(software_interrupt_i),
        .timer_interrupt_i(timer_interrupt_i),
        .is_inst_illegal_i(is_inst_illegal_i),
        .is_ecall_i(is_ecall_i),
        .is_ebreak_i(is_ebreak_i),
        .is_mret_i(is_mret_i),
        .is_load_addr_misaligned_i(is_load_addr_misaligned_i),
        .is_store_addr_misaligned_i(is_store_addr_misaligned_i),
        .is_inst_addr_misaligned_i(is_inst_addr_misaligned_i),
        .is_inst_access_fault_i(is_inst_access_fault_i),
        .is_load_access_fault_i(is_load_access_fault_i),
        .csr_enable(csr_enable),
        .value_i(value_i),
        .mikro_islem_i(mikro_islem_i),
        .csr_index_i(csr_index_i),
        .imm_i(imm_i),
        .rs1_i(rs1_i),
        .csr_out_o(csr_out_o),
        .pc_i(pc_i),
        .writeback_change_pc(writeback_change_pc),
        .return_address_o(return_address_o),
        .trap_address_o(trap_address_o),
        .go_to_trap_q_o(go_to_trap_q_o),
        .return_from_trap_q_o(return_from_trap_q_o),
        .minstret_inc_i(minstret_inc_i),
        .ce_i(ce_i),
        .durdur_i(durdur_i)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
               // Initialize Inputs
        clk = 0;
        rst = 1;
        external_interrupt_i = 0;
        software_interrupt_i = 0;
        timer_interrupt_i = 0;
        is_inst_illegal_i = 0;
        is_ecall_i = 0;
        is_ebreak_i = 0;
        is_mret_i = 0;
        is_load_addr_misaligned_i = 0;
        is_store_addr_misaligned_i = 0;
        is_inst_addr_misaligned_i = 0;
        is_inst_access_fault_i = 0;
        is_load_access_fault_i = 0;
        csr_enable = 0;
        value_i = 0;
        mikro_islem_i = 0;
        csr_index_i = 0;
        imm_i = 0;
        rs1_i = 0;
        pc_i = 0;
        writeback_change_pc = 0;
        minstret_inc_i = 0;
        ce_i = 0;
        durdur_i = 0;

        // Reset the CSR module
        #10 rst = 0;
        #10 rst = 1;
        
        #10 durdur_i = 1;
        #10 durdur_i = 0;
        #10 ce_i = 1;  
      
            
        #10 csr_enable = 1;
            external_interrupt_i = 1;
            csr_index_i = `MCAUSE;
            mikro_islem_i = 5'b00000;
            pc_i=32'h12;
            rs1_i = 32'h00000008; // Write value to MSTATUS register
            imm_i = 32'h01;
            value_i=32'h05;
    

    end
    
endmodule
