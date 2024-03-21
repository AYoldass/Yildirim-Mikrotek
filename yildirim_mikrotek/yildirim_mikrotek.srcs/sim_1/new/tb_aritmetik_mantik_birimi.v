`timescale 1ns / 1ps

`include "riscv_controller.vh"

module tb_aritmetik_mantik_birimi();

    reg [3:0] kontrol_i;
    reg [31:0] value1_i;
    reg [31:0] value2_i;

    wire [31:0] result_o;

    aritmetik_mantik_birimi alu (
        .kontrol_i(kontrol_i),
        .value1_i(value1_i),
        .value2_i(value2_i),
        .result_o(result_o)	
    );
    
    initial begin
        
        kontrol_i=`ALU_TOPLAMA ;
        value1_i=32'd40;
        value2_i=32'd30;
        #10;
        if(result_o==32'd70) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_CIKARMA ;
        value1_i=32'd40;
        value2_i=32'd30;
        #10;
        if(result_o==32'd10) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_XOR;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'hff0f_0f0f;
        #10;
        if(result_o==32'h0fff_ffff) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_OR;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'hff0f_0f0f;
        #10;
        if(result_o==32'hffff_ffff) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_AND;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'hff0f_0f0f;
        #10;
        if(result_o==32'hf000_0000) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_SLL;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'h0000_0004;
        #10;
        if(result_o==32'h0f0f_0f00) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_SRL;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'h0000_0004;
        #10;
        if(result_o==32'h0f0f_0f0f) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_SRA;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'h0000_0004;
        #10;
        if(result_o==32'hff0f_0f0f) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_SLT;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'h0000_0004;
        #10;
        if(result_o==32'h0000_0001) $display("passed"); else $display("FAILED!: %d",result_o);
        
        kontrol_i=`ALU_SLTU;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'h0000_0004;
        #10;
        if(result_o==32'h0000_0000) $display("passed"); else $display("FAILED!: %d",result_o);

        kontrol_i=`ALU_GECIR;
        value1_i=32'hf0f0_f0f0;
        value2_i=32'h0000_0004;
        #10;
        if(result_o==32'h0000_0004) $display("passed"); else $display("FAILED!: %d",result_o);
        
    end


endmodule