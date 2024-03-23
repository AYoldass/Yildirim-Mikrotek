`timescale 1ns / 1ps
// Kayan Noktalý 32 bit tek duyarlýklý ALU, FADD/FSUB'u uygulayabilir,
// FMUL/FDIV, FSQRT ve FMIN-MAX iþlemleri. Ayný zamanda yeteneðini de içerir
// kayan noktalý birleþtirmeli çarpma toplama talimatlarýnýn gerçekleþtirilmesi F[N]MADD/F[N]MSUB
// R4 tipi talimat formatý kullanýldýðýnda. (WIP, yalnýzca FADD/FSUB uygulandý)


`include "riscv_controller.vh"


module kayan_nokta_birimi(
input wire          clk_i,
input wire          rst_i,

input wire  [31:0]  value1_i,
input wire  [31:0]  value2_i,
input wire  [31:0]  value3_i,

input wire  [5:0]   FPU_operation_i, // Operation selector.
input wire  [2:0]   rounding_mode_i,    // Rounding mode bits from the FCSR or instruction.
input wire          start_i,


output reg   [31:0] result_o,
output wire  [4:0]  flags_o, // Exception flags.
output reg          mesgul_o);


   // Multi-cycle operation on-going flag.
reg                NV, DZ, OF, UF, NX; // iNValid operation, Divide by Zero, OverFlow,
assign flags_o =  {NV, DZ, OF, UF, NX};// UnderFlow, iNeXact.

wire            birim_mesgul;
reg             toplama_cikarma_mesgul;
reg             carpma_mesgul;
reg             yuvarlama_mesgul;
wire            bolme_mesgul;
wire  [34:0]    Fadd_Fsub_result;
wire  [34:0]    Fmult_result;
wire  [34:0]    Fdiv_result;
wire  [4:0]     Fmult_flags;
wire  [4:0]     Fdiv_flags;
reg   [34:0]    pre_round;  // 1 sign + 9 exp (1+8) + 25 mantissa (23+2)
wire  [31:0]    round_result; // 1 sign + 8 exp + 23 mantissa
wire  [4:0]     round_flags;


kayan_nokta_toplama_cikarma_birimi AddSub(
         .clk_i         ( clk_i                     ),
         .rst_i         ( rst_i                     ),
         .mesgul_i      ( toplama_cikarma_mesgul    ),
         .value1_i      ( value1_i                  ), 
         .value2_i      ( value2_i                  ),
         .SubFlag_i     ( FPU_operation_i[0]        ), 
         .result_o      ( Fadd_Fsub_result          )
         );

kayan_nokta_carpma_birimi Mul(
         .clk_i          ( clk_i            ),
         .rst_i          ( rst_i            ),
         .mesgul_i       ( carpma_mesgul    ),
         .value1_i       ( value1_i         ), 
         .value2_i       ( value2_i         ),
         .result_o       ( Fmult_result     )
         );

kayan_nokta_yuvarlama round(
         .clk_i                ( clk_i              ),
         .rst_i                ( rst_i              ),
         .mesgul_i             ( yuvarlama_mesgul   ),
         .pre_round_i          ( pre_round          ), // 1 sign + 1 OF exponent + 8 exponent + 23 mantissa + 2 rounding bits
         .rounding_mode_i      ( rounding_mode_i    ),
         .result_o             ( round_result       ),
         .flags_o              ( round_flags        )
         );

// Gelecekteki uygulama için
//assign Fmult_result = 32'b0;
assign Fdiv_result  =   32'b0;
assign Fmult_flags  =   5'b0;
assign Fdiv_flags   =   5'b0;
assign bolme_mesgul =   1'b0; // Connect to the busy signal from the DIV module.


// Giriþ kablolarý. value1, FSQRT iþleminde kullanýlmaz (0 olmalýdýr). 
//value3 yalnýzca R4 tipi talimat kullanýldýðýnda kullanýlýr (aksi takdirde 0).
wire               value1_sign,     value2_sign,     value3_sign;  // sign bit.
wire        [7:0]  value1_exponent, value2_exponent, value3_exponent;  // exponent byte.
wire        [22:0] value1_mantissa, value2_mantissa, value3_mantissa;  // mantissa bits.

assign value1_sign          =   value1_i[31];
assign value1_exponent      =   value1_i[30:23];
assign value1_mantissa      =   value1_i[22:0];
assign value2_sign          =   value2_i[31];
assign value2_exponent      =   value2_i[30:23];
assign value2_mantissa      =   value2_i[22:0];
assign value3_sign          =   value3_i[31];
assign value3_exponent      =   value3_i[30:23];
assign value3_mantissa      =   value3_i[22:0];


// Özel giriþ durumlarý flagleri
wire zero_value1,        zero_value2,        zero_value3;            // Zero RS1, RS2, RS3
wire NaN_value1,         NaN_value2,         NaN_value3;            // NaN RS1, RS2, RS3
wire infinity_value1,    infinity_value2,    infinity_value3;      // Infinity RS1, RS2, RS3
wire FF_exponent_value1, FF_exponent_value2, FF_exponent_value3;
wire anything_M_value1,  anything_M_value2,  anything_M_value3;

assign FF_exponent_value1     =     value1_exponent == 8'hFF;
assign FF_exponent_value2     =     value2_exponent == 8'hFF;
assign FF_exponent_value3     =     value3_exponent == 8'hFF;

assign anything_M_value1      =     |value1_mantissa;
assign anything_M_value2      =     |value2_mantissa;
assign anything_M_value3      =     |value3_mantissa;

assign zero_value1          =   {value1_exponent, value1_mantissa}      ==   31'b0;  
assign zero_value2          =   {value2_exponent, value2_mantissa}      ==   31'b0;
assign zero_value3          =   {value3_exponent, value3_mantissa}      ==   31'b0;
assign NaN_value1           =   FF_exponent_value1 & anything_M_value1;
assign NaN_value2           =   FF_exponent_value2 & anything_M_value2;
assign NaN_value3           =   FF_exponent_value3 & anything_M_value3;
assign infinity_value1      =   FF_exponent_value1 & !anything_M_value1;
assign infinity_value2      =   FF_exponent_value2 & !anything_M_value2;
assign infinity_value3      =   FF_exponent_value3 & !anything_M_value3;


wire value12NaN;   // value1 and value2 NaN.
wire value12PNInf; // value1 and value2 infinite with different sign.
wire value12ZInf;  // value1 and value2 contain zero and infinite.
wire value12Z;     // value1 and value2 are zero.
wire value12Inf;   // value1 and value2 are infinite.
wire value12Sign;  // value1 and value2 signed multiplied/divided.

assign value12NaN   = NaN_value1 | NaN_value2;
assign value12PNInf = infinity_value1 & infinity_value2 & (value1_sign != (value2_sign^FPU_operation_i[0])); // Fixed for ADD/SUB op.
assign value12ZInf  = (zero_value1 & infinity_value2) | (zero_value2 & infinity_value1);
assign value12Z     = zero_value1 & zero_value2;
assign value12Inf   = infinity_value1 & infinity_value2;
assign value12Sign  = value1_sign ^ value2_sign;


// Operation selector.
always @(*) begin
result_o             =  32'b0;
pre_round            =  35'b0;
{NV, DZ, OF, UF, NX} = 5'b0;
{mesgul_o, yuvarlama_mesgul, toplama_cikarma_mesgul, carpma_mesgul} = 4'b0;

case(FPU_operation_i)
 `FPU_FADD, `FPU_FSUB:
 
 begin
  if(value12NaN | value12PNInf) begin // Check NaN input or inf-inf
   result_o = 32'h7FC00000; // qNaN
   NV  = 1'b1;
  end else if(infinity_value1 | infinity_value2) // Check inf input
   result_o = infinity_value1 ? value1_i : {value2_sign^FPU_operation_i[0], value2_i[30:0]};
  else begin
   pre_round            = Fadd_Fsub_result;
   result_o             = round_result;
   {NV, DZ, OF, UF, NX} = round_flags & {5{!birim_mesgul}}; // To avoid signaling flags during operation.
   {mesgul_o, yuvarlama_mesgul, toplama_cikarma_mesgul} = {3{birim_mesgul}};
 end end
 
 `FPU_FMUL:
 begin
  if(value12NaN | value12ZInf) begin
   result_o = 32'h7FC00000; // qNaN
   NV  = 1'b1;
  end else if(infinity_value1 | infinity_value2)
   result_o = {value12Sign, 31'h7F800000}; // Inf with proper sign.
  else begin
   pre_round            = Fmult_result;
   result_o             = round_result;
   {NV, DZ, OF, UF, NX} = round_flags & {5{!birim_mesgul}}; // To avoid signaling flags during operation.
   {mesgul_o, yuvarlama_mesgul, carpma_mesgul} = {3{birim_mesgul}};
 end end
 
 `FPU_FDIV:
 begin
  if(value12NaN | value12Z | value12Inf) begin // Check NaN input, 0 by 0 or both inf inputs
   result_o = 32'h7FC00000; // qNaN
   NV  = 1'b1;
  end else if(infinity_value1 | infinity_value2 | zero_value1 | zero_value2) begin // Check inf and zero inputs
   result_o = {value12Sign, infinity_value1 | zero_value2 ? 31'h7F800000 : 31'b0}; // inf/x = x/0 = inf
   DZ  = zero_value2;                                             // 0/x = x/inf = 0
  end else begin
   pre_round            = Fdiv_result;
   result_o             = round_result;
   {NV, DZ, OF, UF, NX} = Fdiv_flags & {5{!bolme_mesgul}}; // To avoid signaling flags during operation.
 end end
 
 default: ; //ZEDBOARD'in gerektirdiði varsayýlan deðer

endcase
end

// Çok döngülü durdurucu. Ýþleme baðlý olarak bir baþlangýç sayaç deðeri ayarlar ve bunu her saat döngüsünde azaltýr.
// Tek çevrim modunda çalýþmak için yukarýdaki OP'de "mesgul_o = birim_mesgul" ayarlamayýn. 2 döngü OP için ayarlayýn ancak "sayaç = 0" koyun.
// Daha yüksek çevrim OP için, X-2'ye bir baþlangýç sayaç deðeri ayarlayýn. Örneðin ADD/SUB OP 3 cc alýr, ardýndan sayaç 1 ile baþlatýlýr.
reg   [3:0] counter; // Multi-cycle operation counter.

always@(posedge clk_i or negedge rst_i)
      if(!rst_i)   
        counter = 0;
    else if(|counter) 
        counter = counter - 2'b1;
    else if(start_i)  
    case(FPU_operation_i)
 `FPU_FADD, `FPU_FSUB   :               counter = 1; // Total = 3 cc (ALLIGN1/ADD/SUB + ALLIGN2 + ROUND).
 `FPU_FMUL              :               counter = 1; // Total = 3 cc (MUL + ALLIGN3 + ROUND).
 default: counter = 0;
 endcase

assign birim_mesgul = (|counter) | &{start_i, 1'b1}; // Ýþlemin gecikmesi tek bir saat döngüsü olduðunda '1'in yerinde deðiþiklik, !(FPU_operation_i == `singleCycleOp)

endmodule