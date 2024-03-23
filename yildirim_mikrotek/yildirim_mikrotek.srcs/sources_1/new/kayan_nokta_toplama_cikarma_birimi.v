`timescale 1ns / 1ps
// Kayan Noktal� 32 bit tek duyarl�kl� ADD/SUB i�lem mod�l�.

`include "riscv_controller.vh"

module kayan_nokta_toplama_cikarma_birimi(
                    input wire         clk_i,
                    input wire         rst_i,
                    input wire         mesgul_i,
                    input wire  [31:0] value1_i,
                    input wire  [31:0] value2_i,
                    input wire         SubFlag_i, // Subtract signal operation.
                    
                    output wire [34:0] result_o);


// Ad�m 1: �s hizalamas�
// Toplama veya ��karma s�ras�nda her iki i�lenenin de farkl� �sleri olabilece�i g�z �n�ne al�nd���nda
// i�lemde en y�ksek �s ge�erli olur, dolay�s�yla en d���k �s de�i�tirilmelidir
// �ss� en y�ksek �sle e�le�ecek �ekilde y�kseltmek i�in mantis;
// FP mantis format�n�n gizli [1.]'ini ve yuvarlama bitlerini dikkate al�n.

wire [35:0] value1_align, value2_align;       // aligned operands
wire        value1_s, value2_s; // 1 sign bit
wire  [7:0] value1_e, value2_e; // 8 esponent bits
wire [26:0] value1_m, value2_m; // 1 [1.], 23 mantissa + 3 rounding bits

kayan_nokta_hizalama_birimi align(
     .a_hizala_i    ( value1_i     ), 
     .b_hizala_i    ( value2_i     ), 
     .a_hizali_o   ( value1_align ), 
     .b_hizali_o   ( value2_align )
     );

assign value1_s = value1_align[35];
assign value1_e = value1_align[34:27];
assign value1_m = value1_align[26:0];
assign value2_s = value2_align[35]^SubFlag_i; // FP doesn't use 2'C for negatives
assign value2_e = value2_align[34:27];
assign value2_m = value2_align[26:0];


// Ad�m 2: �al��t�rma
// FP format� 2'C negatif say�larla oynamaz ancak b�y�kl�k format�n� kullan�r
// mantis ve i�aret biti olarak, ��karma i�lemlerini d�zg�n bir �ekilde ger�ekle�tirmek i�in,
// B�Y�K - k���k performans� ger�ekle�tirmek i�in hangi hizalanm�� mantisin en b�y�k oldu�unu bulmak gerekir.
// Bu �ekilde sonu� her zaman b�y�kl�k a��s�ndan do�rudur ve bit i�areti
// i�aret bitinden hangisinin daha b�y�k oldu�u elde edilir. Bu tasar�m detay�n�n �zel bir anlam� olabilir.
// her iki i�lenenin ayn� b�y�kl�kte fakat farkl� olmas� durumunda davran��
// bit i�areti, hangisinin de�er1_i veya de�er2_i oldu�una ba�l� olarak sonu� +0 veya -0 olabilir. Bu
// yuvarlama ad�m�nda y�netilir.

wire         res_s;
wire  [7:0]  res_e;
wire  [27:0] res_m; // 1 overflow mantissa + 1 [1.] + 23 mantissa + 3 rounding bits
wire  [27:0] a_m; // a >= b between value1 and value2 mantissas
wire  [27:0] b_m; // a >= b between value1 and value2 mantissas
wire         value1mGEvalue2m; //value1 mantissa greater than or equal to value2 mantissa
wire         add1Exponent; // Increment exponent once if is overflow or [1.] depending on exponent.

assign value1mGEvalue2m =   value1_m >= value2_m;
assign a_m              =   {1'b0,  value1mGEvalue2m ? value1_m : value2_m};
assign b_m              =   {1'b0, !value1mGEvalue2m ? value1_m : value2_m};
assign res_m            =   (value1_s == value2_s)   ? a_m + b_m  // Same sign -> add mantissas
                                                     : a_m - b_m; // Diff sign -> high - low mantissa
                                                     
assign res_e            =   value1_e; // value1_e should be equal to value2_e
assign res_s            =   value1mGEvalue2m ? value1_s : value2_s;

 // �al��ma s�kl���n� art�rmak i�in kaydedilen ad�m 2'nin ��k���.
reg  [36:0] rs_out_reg; // 1 sign + 8 exponent + 1 overflow mantissa + 1 [1.] + 23 mantissa + 3 rounding bits

always@(posedge clk_i or negedge rst_i)
    if(!rst_i) 
        rs_out_reg = 37'h0;
    else rs_out_reg = {res_s, res_e, res_m};


// Ad�m 3: ��lem sonras� hizalama
// Hem toplama hem de ��karma i�lemleri mantisin '1' MSB'sini hareket ettirmi� olabilir,
// bu nedenle yeniden hizalama yap�lmas� ve bunu �sse eklememiz veya ��karmam�z gerekiyor.
// Ayr�ca yuvarlama bitlerinin koruma biti konumu VEYA ile g�ncellenir.
// �nceki koruma ve yap��kan bitler.

wire  [26:0] prePostalign_m;    // 1 overflow mantissa + 1 [1.] + 23 mantissa + 2 rounding bits
wire  [4:0]  MSBOneBitPosition; // Highest '1' bit on the resulted mantissa.

assign prePostalign_m = {rs_out_reg[27:2], |rs_out_reg[1:0]};

enyuksek_sol_bit28 hl28u({1'b0, prePostalign_m}, MSBOneBitPosition);

wire         Postalign_s;
wire  [8:0]  Postalign_e; // 1 overflow exponent + 8 exponent bits
wire  [24:0] Postalign_m; // 23 mantissa + 2 rounding bits
wire  [7:0]  shifts;
wire  [7:0]  Lshifts;
wire         zeroMantissa; // Flag of 0 mantissa.
wire         notEnoughExponent; // FP value goes subnormal.

assign Postalign_s       =   rs_out_reg[36];
assign zeroMantissa      =   rs_out_reg[27:0] == 28'b0;
assign shifts            =   8'd25 - MSBOneBitPosition;
assign notEnoughExponent =   shifts > rs_out_reg[35:28];
assign Lshifts           =   notEnoughExponent ? rs_out_reg[35:28] : shifts;
assign Postalign_e       =   zeroMantissa ? 9'b0 : 
                             prePostalign_m[26] ? rs_out_reg[35:28] + 8'b1
                                                : rs_out_reg[35:28] - Lshifts + (rs_out_reg[35:28] == 8'b0 & prePostalign_m[25]);
assign Postalign_m       =   prePostalign_m[26] ? {prePostalign_m[25:2], |prePostalign_m[1:0]}
                                                : prePostalign_m[24:0] << ((Postalign_e == 9'b0 & Lshifts != 8'b0) 
                                                ? Lshifts - 8'b1 : Lshifts);

assign result_o = {Postalign_s, Postalign_e, Postalign_m}; // 1 + 9 + 25 bits

endmodule