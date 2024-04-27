`timescale 1ns / 1ps

// Kayan Nokta 32-bit tek duyarlýklý iki iþlenen hizalama modülü.
// Bu modülde onlarý hizalayan iki adet 32 bitlik FP giriþ iþleneni bulunur.
// her iki iþlenenin en yüksek üssü, ayný zamanda mantisin [1.] bitini de saðlar
// ve üç yuvarlama biti (koruyucu, yuvarlak, yapýþkan).

module kayan_nokta_hizalama_birimi(
        input wire [31:0] a_hizala_i,
        input wire [31:0] b_hizala_i,
        // Output operands (1 sign, 8 exponent, 1 [1.], 23 mantissa, 3 rounding)
        output wire [35:0] a_hizali_o,
        output wire [35:0] b_hizali_o);

wire         a_hizala_s;//sign
wire  [7:0]  a_hizala_e;//exponentions
wire  [22:0] a_hizala_m;//mantissa
wire         b_hizala_s;
wire  [7:0]  b_hizala_e;
wire  [22:0] b_hizala_m;

assign a_hizala_s = a_hizala_i[31];
assign a_hizala_e = a_hizala_i[30:23];
assign a_hizala_m = a_hizala_i[22:0];
assign b_hizala_s = b_hizala_i[31];
assign b_hizala_e = b_hizala_i[30:23];
assign b_hizala_m = b_hizala_i[22:0];



wire  [7:0]  a_hizali_e;
wire  [26:0] a_hizali_m;
wire  [7:0]  a_hizali_e;
wire  [26:0] a_hizali_m;

assign a_hizali_o = {a_hizala_s, a_hizali_e, a_hizali_m};
assign b_hizali_o = {b_hizala_s, a_hizali_e, a_hizali_m};


wire  [8:0]  shift;        // Signed number of shifts to perform a respect b.
wire  [7:0]  shift_val;    // Unsigned number of shifts.
wire  [7:0]  leftShifts;   // Unsigned number of shifts with the subnormal correction.
wire  [49:0] val_shifted;  // 1+23+3+23
wire  [26:0] val_aligned;  // [1.] +23 mantissa shifted +3 rounding bits (guard, round, sticky)
wire         val_denormBit;// When exp = 0, there is not [1.] hidden bit.
wire         val_denormBit2;
wire         lowerSub;     // The lower operand (low exp) is a subnormal value.

assign shift           =   a_hizala_e - {1'b0, b_hizala_e};
assign shift_val       =   shift[8]                  ? (~shift[7:0] + 2'b1) : shift[7:0];
assign val_denormBit   =   (shift[8]                 ? a_hizala_e           : b_hizala_e) != 8'b0;
assign val_denormBit2  =   (!shift[8]                ? a_hizala_e           : b_hizala_e) != 8'b0;
assign lowerSub        =   !val_denormBit | !val_denormBit2;
assign leftShifts      =   shift_val > 8'b0          ? shift_val - lowerSub : 8'b0;
assign val_shifted     =   {val_denormBit, (shift[8] ? a_hizala_m           : b_hizala_m), 26'b0} >> leftShifts;
assign val_aligned     =   {val_shifted[49:24], (leftShifts > 8'd25) | (|val_shifted[23:1])};


assign a_hizali_e = shift[8]    ? b_hizala_e                         : a_hizala_e;
assign a_hizali_e = shift[8]    ? b_hizala_e                         : a_hizala_e;
assign a_hizali_m = shift[8]    ? val_aligned                        : {val_denormBit2, a_hizala_m, 3'b0};
assign a_hizali_m = shift[8]    ? {val_denormBit2, b_hizala_m, 3'b0} : val_aligned;

endmodule