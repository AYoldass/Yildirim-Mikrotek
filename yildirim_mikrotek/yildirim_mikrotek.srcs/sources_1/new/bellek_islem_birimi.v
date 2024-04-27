`timescale 1ns / 1ps

`include "riscv_controller.vh"

module bellek_islem_birimi(
   input                        clk_i,
   input                        rst_i,
   
   // Buyruk türüne göre maske oluþturur, Okuma mý yazma mý yapýlacaðýný söyler
   input   [3:0]                buyruk_secim_i,
   input   [31:0]               rd_i,
   input   [31:0]               rs2_i,

   output  [31:0]               veri_o,
   output  [3:0]                maske_o,
   output                       oku_o,
   output                       yaz_o
);

reg [31:0]  veri_cmb;
reg [3 :0]  maske_cmb;
reg         oku_cmb;
reg         yaz_cmb;

localparam OP_NOP  = 0;
localparam OP_BYTE = 1;
localparam OP_HALF = 2;
localparam OP_WORD = 3;

function [4:0] maske_sec (
   input [2:0]                 boyut_w,   
   input [31:0]                rd_w
);
begin
   maske_sec = {4{1'b0}};
   case(boyut_w)
      OP_NOP   : maske_sec = 0;
      OP_BYTE  : maske_sec = 8'b0001 << rd_w[1:0];
      OP_HALF  : maske_sec = 8'b0011 << rd_w[1:0];
      OP_WORD  : maske_sec = 8'b1111;
   endcase
end
endfunction

function [31:0] veri_kaydir (
   input [31:0] rd_w,
   input [31:0] rs2_w
);
begin
   veri_kaydir = rs2_w << (rd_w[1:0] * 8);
end
endfunction

always @* begin
   veri_cmb = rs2_i;
   // 16 VE 8 BÝT lOAD YAPARKEN REGISTERIN EN ANLAMLI BYTELARINA YAZILMIÞTIR, BELLEÐE STORE YAPARKEN VERÝ ÖBEÐÝNÝN EN ANLAMLI BYTLEARINA YAZILDI 
   case(buyruk_secim_i)
      // Load Buyruklarý
      `BIB_LW: begin // 32 Bit Okur
         maske_cmb  = maske_sec(OP_WORD, rd_i); 
         oku_cmb    = 1;
         yaz_cmb    = 0;         
      end
      // 16 Bit Okur, sign-extend edip rd'ye yazar
      `BIB_LH: begin 
         maske_cmb  = maske_sec(OP_HALF, rd_i); 
         oku_cmb    = 1;
         yaz_cmb    = 0; 
      end
      // 16 Bit Okur, zero-extend edip rd'ye yazar
      `BIB_LHU: begin 
         maske_cmb  = maske_sec(OP_HALF, rd_i); 
         oku_cmb    = 1;
         yaz_cmb    = 0;          
      end
      // 8 Bit Okur, sign-extend edip rd'ye yazar
      `BIB_LB: begin 
         maske_cmb  = maske_sec(OP_BYTE, rd_i); 
         oku_cmb    = 1;
         yaz_cmb    = 0;           
      end
      // 8 Bit Okur, zero-extend edip rd'ye yazar
      `BIB_LBU: begin 
         maske_cmb  = maske_sec(OP_BYTE, rd_i); 
         oku_cmb    = 1;
         yaz_cmb    = 0;       
      end
      // Store Buyruklarý
      `BIB_SW: begin // 32 Bit Store'lar
         maske_cmb  = maske_sec(OP_WORD, rd_i); 
         veri_cmb   = rs2_i; // 
         oku_cmb    = 0;
         yaz_cmb    = 1;     
      end
      // 16 Bit Store'lar
      `BIB_SH: begin 
         maske_cmb  = maske_sec(OP_HALF, rd_i);
         veri_cmb   = veri_kaydir(rd_i, rs2_i); 
         oku_cmb    = 0;
         yaz_cmb    = 1;          
      end
      `BIB_SB: begin // 8 Bit Store'lar
         maske_cmb  = maske_sec(OP_BYTE, rd_i);
         veri_cmb   = veri_kaydir(rd_i, rs2_i); 
         oku_cmb    = 0;
         yaz_cmb    = 1;          
      end
      default: begin
         maske_cmb  = maske_sec(OP_NOP, rd_i);
         veri_cmb   = 0;
         oku_cmb    = 0;
         yaz_cmb    = 0;  
      end
   endcase
end

assign veri_o   = veri_cmb;
assign maske_o  = maske_cmb;
assign oku_o    = oku_cmb;
assign yaz_o    = yaz_cmb;



endmodule