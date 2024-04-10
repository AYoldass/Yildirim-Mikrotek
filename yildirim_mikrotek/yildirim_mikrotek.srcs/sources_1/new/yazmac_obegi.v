`timescale 1ns / 1ps


module yazmac_obegi #(
   parameter STACKADDR = 32'h40000000
)(
   input  wire clk_i,
   input  wire rst_i,
   // okuma arayuzu
   input  wire [ 4:0] read1_adr_i, // rs1
   input  wire [ 4:0] read2_adr_i, // rs2
   output wire [31:0] read1_value_o,
   output wire [31:0] read2_value_o,
   // yazma arayuzu
   input  wire [ 4:0] write_adr_i, // hy
   input  wire [31:0] write_value_i,
   input  wire        write_i
);

   reg [31:0] register[31:0];

   assign read1_value_o = register[read1_adr_i];
   assign read2_value_o = register[read2_adr_i];

   always@(posedge clk_i) begin
      if(write_i && (write_adr_i != 0)) begin
         register[write_adr_i] <=  write_value_i;
      end
      if(rst_i) begin
         register[0] = 0;
         register[2] = STACKADDR;
      end
   end
endmodule