`timescale 1ns / 1ps

`include "riscv_controller.vh"

module aritmetik_mantik_birimi(
   input  wire [ 3:0] kontrol_i,// kontrol_i sinyalleri
   input  wire [31:0] value1_i,
   input  wire [31:0] value2_i,
   output wire [31:0] result_o
);

   wire [31:0] result_xor;
   wire [31:0] result_or;
   wire [31:0] result_and;
   wire [31:0] result_sll;
   wire [31:0] result_srl;
   wire [31:0] result_sra;
   wire [31:0] result_slt;
   wire [31:0] result_sltu;
   
   wire [32:0] value1_top = (kontrol_i == `ALU_CIKARMA) ? { value1_i,1'b1} : {value1_i,1'b0};
   wire [32:0] value2_top = (kontrol_i == `ALU_CIKARMA) ? {~value2_i,1'b1} : {value2_i,1'b0};
   wire [32:0] result_top;
   wire elde_cla = (kontrol_i == `ALU_CIKARMA);
   
   `ifdef FPGA
      assign result_top = value2_top + value1_top;
   `else
      toplayici_birim`GATE sklanksy_toplayici(
         .a_in(deger1_top),
         .b_in(deger2_top),
         .sum (result_top)
      );
   `endif
   
   assign result_xor  = value1_i   ^   value2_i;
   assign result_or   = value1_i   |   value2_i;
   assign result_and  = value1_i   &   value2_i;
   assign result_sll  = value1_i   <<  value2_i[4:0];
   assign result_srl  = value1_i   >>  value2_i[4:0];
   assign result_sra  = $signed(value1_i) >>>  value2_i[4:0];
   assign result_slt  = ($signed(value1_i) < $signed(value2_i)) ? 32'b1 : 32'b0;
   assign result_sltu = ( (value1_i) < (value2_i)) ? 32'b1 : 32'b0;
   
   assign result_o = (kontrol_i == `ALU_CIKARMA) | (kontrol_i == `ALU_TOPLAMA) ? result_top[32:1] :
                     (kontrol_i == `ALU_XOR)                                   ? result_xor :
                     (kontrol_i == `ALU_OR)                                    ? result_or  :
                     (kontrol_i == `ALU_AND)                                   ? result_and :
                     (kontrol_i == `ALU_SLL)                                   ? result_sll :
                     (kontrol_i == `ALU_SRL)                                   ? result_srl :
                     (kontrol_i == `ALU_SRA)                                   ? result_sra :
                     (kontrol_i == `ALU_SLT)                                   ? result_slt :
                     (kontrol_i == `ALU_SLTU)                                  ? result_sltu:
                     (kontrol_i == `ALU_GECIR)                                 ? value2_i  :
                                                                               32'bx;

endmodule