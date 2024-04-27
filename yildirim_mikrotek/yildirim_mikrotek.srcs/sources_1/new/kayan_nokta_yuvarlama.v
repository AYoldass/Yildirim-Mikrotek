`timescale 1ns / 1ps

// Tek duyarlýklý kayan nokta iþlenenleri için yuvarlama modülü.
//
// Bu modül çeþitli kayan nokta iþaretlerini oluþturma kapasitesine sahiptir.
//doðru sonucu çýktý olarak veriyoruz. Oldukça tuhaf "preRound" giriþ formatýnýn nedeni budur.
// Bu modül giriþ deðerinin limiti sýfýr ile 510 üs arasýnda kalmasý gerektiðidir
// bit taþmasý. Bu modülün giriþine kadar olan taþmalarýn önceden uygun þekilde yönetilmesi gerekir.
// deðer, ister sýfýr ister küçük bir deðer olsun (normalleþtirilmemiþ deðerler olarak da adlandýrýlýr).
//
// Yuvarlama büyüsünün yürütülmesi bir saat döngüsü alýr ve kayýt giriþtedir,
// böylece herhangi bir gecikme yükünde herhangi bir yerden saðlanabilir, ancak bunu birleþtirme konusunda dikkatli olun
// çýktýda baþka herhangi bir þey bulunan modül.

`include "riscv_controller.vh"

module kayan_nokta_yuvarlama(
        input wire          clk_i,
        input wire          rst_i,
        input wire          mesgul_i,
        input wire   [34:0] pre_round_i,    // 1 sign + 1 OF exponent + 8 exponent + 23 mantissa + 2 rounding bits
        input wire   [2:0]  rounding_mode_i,     
        
        output wire  [31:0] result_o,         // 1 sign + 8 exponent + 27 mantissa bits
        output wire  [4:0]  flags_o);    // 5 bits NV, DZ, OV, UF, NX


reg  [34:0] register_input;

always@(posedge clk_i or negedge rst_i)
    if(!rst_i) 
        register_input = 35'h0;
    else if(mesgul_i) 
        register_input = pre_round_i;

wire          pre_round_i_sign;
wire   [8:0]  pre_round_i_exponent; // 1 overflow exponent + 8 exponent bits
wire   [24:0] pre_round_i_mantissa; // 23 mantissa + 2 rounding bits

assign pre_round_i_sign     = register_input    [34];
assign pre_round_i_exponent = register_input    [33:25];
assign pre_round_i_mantissa = register_input    [24:0];

// Step 1: Possible rounding outputs.
// Because of the rounding modes and the absolute magnitude mantissa, there's always two possible 
// outcomes. For ease, let's first compute both of them, that includes the possibility of overflowing 
// the mantissa (adding 1 to the exponent) because of the rounding.

wire  [22:0] round_mantissa0;  // 23 mantissa bits                                       Normal output
wire  [22:0] round_mantissa1;  // 23 mantissa bits                                       Output +1
wire  [24:0] round_mantissa2; // 1 overflow mantissa + [1.] + 23 mantissa bits          Output +1
wire  [8:0]  round_exponent0;  // 1 OF exponent + 8 exponent bits                        Normal output
wire  [8:0]  round_exponent1;  // 1 OF exponent + 8 exponent bits                        Output +1
wire         n_zero_exponent;  // '0' when 0 exponent.

assign round_mantissa0   =   pre_round_i_mantissa[24:2];
assign round_exponent0   =   pre_round_i_exponent;
assign n_zero_exponent   =   |pre_round_i_exponent;

assign round_mantissa2   =   {n_zero_exponent, pre_round_i_mantissa[24:2]} + 2'b1;

assign round_mantissa1   =   round_mantissa2[24] ? round_mantissa2[23:1] : round_mantissa2[22:0];
assign round_exponent1   =   pre_round_i_exponent + (round_mantissa2[24] | (round_mantissa2[23] & !n_zero_exponent));



// IEEE 754, 0 sonuçlandýðýnda iþaretin RDN rm dýþýndaki tüm durumlarda pozitif olduðunu belirtir.
// Yalnýzca normal sonucu kontrol ediyoruz çünkü +1 çýkýþý hiçbir zaman 0 olmayacaktýr.
wire   zero0;     // Zero value flag to set correct zero sign for normal outcome.

assign zero0 = !(|{n_zero_exponent, round_mantissa0});


// Step 2: Output selection depending on the rounding mode input and rounding bits.
// Daha net kod için ekstra atama
wire last;  // Last bit mantissa before rounding
wire guard; // "guard" rounding bit
wire round; // "round" rounding bit

assign last  = pre_round_i_mantissa[2];
assign guard = pre_round_i_mantissa[1];
assign round = pre_round_i_mantissa[0];

reg         post_round_sign;
reg  [8:0]  post_round_exponent;
reg  [22:0] post_round_mantissa;
reg         result_sign;
reg  [7:0]  result_exponent;
reg  [22:0] result_mantissa;

always @(*)
begin
// Varsayýlan çýkýþ deðeri qNaN.
 post_round_sign        =   1'b0;
 post_round_exponent    =   9'hFF;
 post_round_mantissa    =   23'h400000;

/* Floating Rounding Mode bits
  FRM_RNE = 3'b000; // Round to Nearest, ties to Even
  FRM_RTZ = 3'b001; // Rounds towards Zero
  FRM_RDN = 3'b010; // Rounds Down (towards -inf)
  FRM_RUP = 3'b011; // Rounds Up (towards +inf)
  FRM_RMM = 3'b100; // Round to Nearest, ties to Max Magnitude 
*/

case(rounding_mode_i)
 `FRM_RNE: begin // Round to Nearest, ties to Even
        if(&{last, guard} | &{guard, round})
        begin
          post_round_sign = pre_round_i_sign;
          post_round_mantissa = round_mantissa1;
          post_round_exponent = round_exponent1;
        end else begin
          post_round_sign = zero0 ? 1'b0 : pre_round_i_sign;
          post_round_mantissa = round_mantissa0;
          post_round_exponent = round_exponent0;
        end
      end

  `FRM_RTZ: begin // Round Towards Zero
        post_round_sign = zero0 ? 1'b0 : pre_round_i_sign;
        post_round_mantissa = round_mantissa0;
        post_round_exponent = round_exponent0;
      end

  `FRM_RDN: begin // Round DowN (towards neg infinity)
        if(pre_round_i_sign & (guard | round))
        begin
          post_round_sign = pre_round_i_sign;
          post_round_mantissa = round_mantissa1;
          post_round_exponent = round_exponent1;
        end else begin
          post_round_sign = zero0 ? 1'b1 : pre_round_i_sign;
          post_round_mantissa = round_mantissa0;
          post_round_exponent = round_exponent0;
        end
      end
      
  `FRM_RUP: begin // Round UP (towards pos infinity)
        if(!pre_round_i_sign & (guard | round))
        begin
          post_round_sign = pre_round_i_sign;
          post_round_mantissa = round_mantissa1;
          post_round_exponent = round_exponent1;
        end else begin
          post_round_sign = zero0 ? 1'b0 : pre_round_i_sign;
          post_round_mantissa = round_mantissa0;
          post_round_exponent = round_exponent0;
        end
      end

 `FRM_RMM: begin // Round to Nearest, ties to Max Magnitude
        if(guard)
        begin
          post_round_sign = pre_round_i_sign;
          post_round_mantissa = round_mantissa1;
          post_round_exponent = round_exponent1;
        end else begin
          post_round_sign = zero0 ? 1'b0 : pre_round_i_sign;
          post_round_mantissa = round_mantissa0;
          post_round_exponent = round_exponent0;
        end
      end

  default: ; //default required by Quartus II 13.1

endcase
end


// Step 3: flags and output management
/*
    iNValid --> NV
    Div by Zero --> DZ
    OverFlow --> OF
    UnderFlow --> UF
    iNeXact --> NX   
*/
wire NV, DZ, OF, UF, NX;

assign NV   =   rounding_mode_i == 3'b101 | rounding_mode_i == 3'b110 | rounding_mode_i == 3'b111; // Invalid rounding modes
assign DZ   =   1'b0;
assign OF   =   post_round_exponent >= 9'h0FF;
assign UF   =   (post_round_exponent == 9'h0) & NX; // subnormal value (0 exponent) and inexact (lower than representable)
assign NX   =   guard | round | OF;


// Çýkýþ yönetimi
always @(*)
begin
  if(NV) begin // Quiet NaN when invalid operation
    result_sign     =   1'b0;
    result_exponent =   8'hFF;
    result_mantissa =   23'h400000;
  end else if(OF) begin // Inf
    result_sign      =  post_round_sign;
    result_exponent  =  8'hFF;
    result_mantissa  =  23'b0;
  end else begin 
    result_sign      =  post_round_sign;
    result_exponent  =  post_round_exponent[7:0];
    result_mantissa  =  post_round_mantissa;
  end
end

assign result_o     = {result_sign, result_exponent, result_mantissa};
assign flags_o    = {NV, DZ, OF, UF, NX};

endmodule
