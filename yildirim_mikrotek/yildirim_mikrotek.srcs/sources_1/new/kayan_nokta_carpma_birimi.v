`timescale 1ns / 1ps

`include "riscv_controller.vh"

module kayan_nokta_carpma_birimi(
        input  wire        clk_i,
        input  wire        rst_i,
        input  wire        mesgul_i,
        input  wire [31:0] value1_i,
        input  wire [31:0] value2_i,
        
        output wire [34:0] result_o);
        

// Step 1: Mantissa carpimi. (First clock cycle)
reg  [47:0] mult_mantissa;   // F * F = E1 -> 24 bits * 24 bits operands = 48 bit operand (XX.XXX...)

always@(posedge clk_i or negedge rst_i)
 if(!rst_i) 
    mult_mantissa = 48'b0;
 else if(mesgul_i) 
    mult_mantissa = {|value1_i[30:23], value1_i[22:0]} * {|value2_i[30:23], value2_i[22:0]};



// Step 2: Exponent toplami. (First clock cycle)
reg   [9:0] mult_exponent; // 1 exponent underflow + 1 exponent overflow + 8 exponent bits

always@(posedge clk_i or negedge rst_i)
 if(!rst_i) 
    mult_exponent = 10'h0;
 else if(mesgul_i) 
    mult_exponent = value1_i[30:23] + value2_i[30:23] - 10'h7F; // -127 because single precision exponent bias.



// Step 3: Exponent update with product mantissa bit position. (Second clock cycle)
wire signed [9:0]  u_e;                     // 1 exponent underflow + 1 exponent overflow + 8 exponent bits
wire        [5:0]  bit_position;            // Leftmost high bit position of the product mantissa (unsigned)
wire               lower_underFlow;        // Flag indicating a negative exponent which shift can only result on underflow.
wire        [46:0] u_m;                    // 47 mantissa bits (.XXX...)

enyuksek_sol_bit48 hlb48u (mult_mantissa, bit_position);

assign u_e = mult_exponent + bit_position - 10'd46;
assign lower_underFlow = u_e < -46;

assign u_m = mult_mantissa[47] ?  mult_mantissa[46:0] // If exponent is negative, shift a modulus exponent value. Otherwise, shift just the
                               : {mult_mantissa[45:0], 1'b0} << (u_e[9] ? -u_e 
                               :  6'd46 - bit_position); // necessary to set the proper format (.XXX...).



// Step 4: Mantissa update through shifting and final exponent update. (Second clock cycle)
wire         result_sign;                    // 1 sign bit
wire  [8:0]  result_exponent;               // 1 exponent overflow + 8 exponent bits
wire  [24:0] result_mantissa;               // 23 mantissa + 2 rounding bits
wire         zero_mantissa;            // zero mantissa flag -> zero result.

assign zero_mantissa = ~|mult_mantissa;
// Sonuç sýfýrsa veya üs negatifse üs sýfýrdýr ancak mantissa kaydýrýlarak yönetilebilir.
assign result_exponent   =    |{zero_mantissa, u_e[9]} ? 9'b0
                                                  : u_e[8:0];
assign result_mantissa   =    zero_mantissa            ? 25'b0
                                                  : {u_m[46:23], |u_m[22:0]};

assign result_sign       =   value1_i[31] ^ value2_i[31]; // Keep computing sign even if it's zero, to preserve correct sign in case where the +1 rounding output is selected.

// Toplam UF'de, yüksek yuvarlama bitlerine sahip bir 0 sonucu göndermek için çýktýyý ele geçirin; bu, yuvarlama bloðunun bir sonraki saat döngüsünde UF sinyali vermesini saðlayacaktýr.
assign result_o     =   lower_underFlow           ? {result_sign, 9'b0, 25'b1}
                                                  : {result_sign, result_exponent, result_mantissa};

endmodule