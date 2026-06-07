`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  fpu_temiz  -  Temiz tek-duyarlikli (binary32) kayan nokta birimi
// ---------------------------------------------------------------------------
//  Depodaki kayan_nokta_birimi.v ve alt modulleri BOZUK (hizalama modulu cift
//  bildirim/coklu surucu icerir; carpma var olmayan enyuksek_sol_bit48'e bagli).
//  Bu yuzden onceki ornege uygun olarak (coz_asamasi/carpma/csr gibi) temiz bir
//  birim yazildi. Kombinasyonel (tek cevrim), yuvarlama = en yakina (ties-to-even).
//
//  Desteklenen islemler (funct7 / rm ile secilir, instr[31:25],[14:12],[24:20]):
//    FADD.S 0000000, FSUB.S 0000100, FMUL.S 0001000,
//    FSGNJ/N/X 0010000 (rm 000/001/010),  FMIN/FMAX 0010100 (rm 000/001),
//    FEQ/FLT/FLE 1010000 (rm 010/001/000) -> tamsayi sonuc,
//    FCVT.W.S/FCVT.WU.S 1100000 (rs2 0/1) -> tamsayi,
//    FMV.X.W 1110000 rm000, FCLASS 1110000 rm001 -> tamsayi,
//    FCVT.S.W/FCVT.S.WU 1101000 (rs2 0/1) <- tamsayi,  FMV.W.X 1111000 <- tamsayi.
//    FDIV.S 0001100, FSQRT.S 0101100 (rs2 0) -> tam-hassas kombinasyonel + RNE.
//  (FMADD/FMSUB/FNMADD/FNMSUB desteklenmez.)  Altnormaller sifira yuvarlanir (basit).
//
//  tamsayi_sonuc_o: sonuc tamsayi yazmac obegine mi (FEQ/FLT/FLE/FCVT.W/FMV.X/FCLASS).
// ===========================================================================

module fpu_temiz (
   input  [6:0]  funct7_i,
   input  [2:0]  rm_i,        // funct3 (islem/yuvarlama secimi)
   input  [4:0]  rs2f_i,      // rs2 alani (FCVT/FMV ayrimi)
   input  [31:0] f1_i,        // f[rs1]
   input  [31:0] f2_i,        // f[rs2]
   input  [31:0] x1_i,        // tamsayi rs1 (FCVT.S.W / FMV.W.X)
   output reg [31:0] sonuc_o,
   output            tamsayi_sonuc_o   // sonuc tamsayi RF'ye mi
);

   // --- ayristirma ---
   wire        s1 = f1_i[31],         s2 = f2_i[31];
   wire [7:0]  e1 = f1_i[30:23],      e2 = f2_i[30:23];
   wire [22:0] m1 = f1_i[22:0],       m2 = f2_i[22:0];

   wire a_nan = (e1==8'hFF) && (m1!=0);
   wire b_nan = (e2==8'hFF) && (m2!=0);
   wire a_inf = (e1==8'hFF) && (m1==0);
   wire b_inf = (e2==8'hFF) && (m2==0);
   wire a_zero= (e1==0) && (m1==0);
   wire b_zero= (e2==0) && (m2==0);

   localparam [31:0] QNAN = 32'h7FC00000;

   // ---- karsilastirma (sirali) : a<b, a==b ----
   //  IEEE: -0==+0. NaN ile karsilastirma yanlis (FEQ/FLT/FLE 0 doner).
   wire mag_lt = ({e1,m1} < {e2,m2});
   wire mag_eq = ({e1,m1} == {e2,m2});
   wire both_zero = a_zero && b_zero;
   reg  flt, feq;
   always @* begin
      feq = both_zero || (!s1 && !s2 && mag_eq) || (s1 && s2 && mag_eq);
      // a < b
      if (both_zero)        flt = 1'b0;
      else if (s1 && !s2)   flt = 1'b1;                 // negatif < pozitif
      else if (!s1 && s2)   flt = 1'b0;
      else if (!s1 && !s2)  flt = mag_lt;               // ikisi pozitif
      else                  flt = !mag_lt && !mag_eq;   // ikisi negatif: buyuk buyukluk = kucuk
   end

   // ======================= FADD / FSUB =======================
   wire sub = funct7_i[2];                 // FSUB ise f2 isaretini ters cevir
   wire        bs = s2 ^ sub;
   wire [7:0]  be = e2;
   wire [22:0] bm = m2;

   //  Hizali mantis semasi (27-bit): {1.23 mantis, guard, round, sticky}.
   //  Lider 1 bit26'da; bit[2:0] = G,R,S. Toplama icin bit27 elde-basligi.
   function [31:0] fadd;
      input        as_, bs_;
      input [7:0]  ae_, be_;
      input [22:0] am_, bm_;
      reg sa, sb; reg [7:0] ea, eb; reg [26:0] ma27, mb27; reg [27:0] sum;
      integer sh, i; reg [8:0] er; reg sbig; reg [22:0] frac; reg lsb,g,rb,st; reg [24:0] mr;
      reg [26:0] lost;
      begin
         if ({ae_,am_} >= {be_,bm_}) begin
            sa=as_; ea=ae_; ma27={(ae_!=0),am_,3'b0}; sb=bs_; eb=be_; mb27={(be_!=0),bm_,3'b0};
         end else begin
            sa=bs_; ea=be_; ma27={(be_!=0),bm_,3'b0}; sb=as_; eb=ae_; mb27={(ae_!=0),am_,3'b0};
         end
         sh = ea - eb;
         if (sh > 27) sh = 27;
         lost  = (sh>=27) ? mb27 : (mb27 & ((27'b1<<sh)-1));
         mb27  = mb27 >> sh;
         if (|lost) mb27[0] = 1'b1;             // sticky
         er = {1'b0, ea};
         sbig = sa;
         if (sa == sb) begin
            sum = {1'b0, ma27} + {1'b0, mb27};
            if (sum[27]) begin                  // elde -> sag kaydir
               st = sum[0]; sum = sum >> 1; sum[0] = sum[0] | st; er = er + 1;
            end
         end else begin
            sum = {1'b0, ma27} - {1'b0, mb27};  // ma>=mb
            i = 0;
            while (sum[26]==1'b0 && (|sum) && i<27) begin sum = sum<<1; er=er-1; i=i+1; end
         end
         lsb=sum[3]; g=sum[2]; rb=sum[1]; st=sum[0];
         mr = {1'b0, sum[26:3]};                // 1 + 24-bit
         if (g && (rb||st||lsb)) begin
            mr = mr + 1;
            if (mr[24]) begin mr = mr>>1; er=er+1; end
         end
         if (sum == 0)        fadd = 32'b0;             // tam iptal -> +0
         else if (er >= 9'hFF) fadd = {sbig, 8'hFF, 23'b0};
         else                  fadd = {sbig, er[7:0], mr[22:0]};
      end
   endfunction

   // ======================= FMUL =======================
   function [31:0] fmul;
      input        as_, bs_;
      input [7:0]  ae_, be_;
      input [22:0] am_, bm_;
      reg sr; reg [9:0] er; reg [23:0] ma, mb; reg [47:0] p;
      reg [22:0] frac; reg guard, round, sticky, lsb; reg [24:0] mr;
      begin
         sr = as_ ^ bs_;
         ma = {(ae_!=0), am_};
         mb = {(be_!=0), bm_};
         p  = ma * mb;                          // 48-bit (1.xx * 1.xx -> 2.46 veya 1.46)
         er = {2'b0, ae_} + {2'b0, be_} - 10'd127;
         if (p[47]) begin                       // 1x.xxx -> normalize sag 1
            er = er + 1;
            frac = p[46:24];
            guard= p[23]; round=p[22]; sticky=|p[21:0]; lsb=p[24];
            mr = {1'b0, p[47:24]};
         end else begin                         // 1.xxx
            frac = p[45:23];
            guard= p[22]; round=p[21]; sticky=|p[20:0]; lsb=p[23];
            mr = {1'b0, p[46:23]};
         end
         if (guard && (round||sticky||lsb)) begin
            mr = mr + 1;
            if (mr[24]) begin mr = mr>>1; er=er+1; end
         end
         if (er[9] || er==0) fmul = {sr, 31'b0};            // altakma -> +/-0
         else if (er >= 10'd255) fmul = {sr, 8'hFF, 23'b0}; // tasma -> inf
         else fmul = {sr, er[7:0], mr[22:0]};
      end
   endfunction

   // ======================= FDIV =======================
   //  Tam-hassas bolme: mantisalar 24-bit; ma/mb*2^27 tamsayi bolme ile bulunur,
   //  normalize edilip yuvarlanir (RNE). Kalan -> sticky.
   function [31:0] fdiv;
      input        as_, bs_;
      input [7:0]  ae_, be_;
      input [22:0] am_, bm_;
      reg sr; reg signed [11:0] er; reg [23:0] ma, mb;
      reg [50:0] dividend; reg [27:0] q; reg [50:0] rem;
      reg st0, g, rb, st, lsb; reg [24:0] mr; reg [23:0] frac24;
      begin
         sr = as_ ^ bs_;
         ma = {(ae_!=0), am_};
         mb = {(be_!=0), bm_};
         dividend = {ma, 27'b0};                 // ma << 27  (ma/mb * 2^27)
         q   = dividend / mb;                     // [2^26, 2^28)
         rem = dividend - q*mb; st0 = |rem;
         if (q[27]) begin                         // oran >= 1 (lider 1 -> bit27)
            er = $signed({4'b0,ae_}) - $signed({4'b0,be_}) + 127;
            frac24 = q[27:4]; g = q[3]; rb = q[2]; st = q[1]|q[0]|st0;
         end else begin                           // oran [0.5,1) (lider 1 -> bit26)
            er = $signed({4'b0,ae_}) - $signed({4'b0,be_}) + 126;
            frac24 = q[26:3]; g = q[2]; rb = q[1]; st = q[0]|st0;
         end
         lsb = frac24[0];
         mr  = {1'b0, frac24};
         if (g && (rb||st||lsb)) begin
            mr = mr + 1;
            if (mr[24]) begin mr = mr>>1; er = er + 1; end
         end
         if (er <= 0)         fdiv = {sr, 31'b0};            // altakma -> +/-0
         else if (er >= 255)  fdiv = {sr, 8'hFF, 23'b0};     // tasma -> +/-inf
         else                 fdiv = {sr, er[7:0], mr[22:0]};
      end
   endfunction

   // ======================= FSQRT =======================
   //  Karekok (yalnizca s=0): tek/cift ussu ayir, mantisi olcekle, tamsayi
   //  karekok (bit-bit digit-recurrence) ile 26-bit sonuc; RNE yuvarla. Kalan -> sticky.
   function [31:0] fsqrt;
      input [31:0] f;
      reg [7:0] e_; reg [23:0] sig; reg signed [11:0] E, resE;
      reg [55:0] rad, a, tsq; reg [27:0] q4, t; integer i;
      reg [24:0] mr; reg [23:0] m24; reg g, rb, st, lsb;
      begin
         e_  = f[30:23]; sig = {(e_!=0), f[22:0]};
         E   = $signed({4'b0,e_}) - 127;
         if (E[0] == 1'b0) begin                  // cift us
            rad  = {32'b0, sig} << 23;
            resE = 127 + (E >>> 1);
         end else begin                           // tek us (mantise 1 bit ekle)
            rad  = {32'b0, sig} << 24;
            resE = 127 + ((E - 1) >>> 1);
         end
         a  = rad << 4;                            // 2 ekstra bit (sonuc = gercek*4)
         q4 = 0;
         for (i = 26; i >= 0; i = i - 1) begin
            t   = q4 | (28'b1 << i);
            tsq = t * t;
            if (tsq <= a) q4 = t;
         end
         st  = ((q4*q4) != a);                     // kalan -> sticky
         m24 = q4[25:2]; g = q4[1]; rb = q4[0]; lsb = m24[0];
         mr  = {1'b0, m24};
         if (g && (rb||st||lsb)) begin
            mr = mr + 1;
            if (mr[24]) begin mr = mr>>1; resE = resE + 1; end
         end
         fsqrt = {1'b0, resE[7:0], mr[22:0]};
      end
   endfunction

   // ======================= FCVT (float<->int) =======================
   // float -> signed int (FCVT.W.S), basit kesme (round-toward-zero)
   function [31:0] f2i;
      input [31:0] f; input isaretli;
      reg s_; reg [7:0] e_; reg [23:0] m_; integer sh; reg [55:0] big; reg [31:0] mag;
      begin
         s_ = f[31]; e_ = f[30:23]; m_ = {(f[30:23]!=0), f[22:0]};
         if (e_ < 127) mag = 0;                       // |f|<1
         else begin
            sh = e_ - 127 - 23;                       // mantis 1.23 -> tamsayi
            big = {32'b0, m_};
            if (sh >= 0) big = big << sh; else big = big >> (-sh);
            mag = big[31:0];
         end
         if (isaretli) f2i = s_ ? (~mag + 1) : mag;
         else          f2i = mag;
      end
   endfunction

   // signed int -> float (FCVT.S.W), round-to-nearest-even
   function [31:0] i2f;
      input [31:0] x; input isaretli;
      reg s_; reg [31:0] mag; integer msb; integer i; reg [7:0] e_; reg [22:0] frac;
      reg [31:0] norm; reg g,r,st; reg [24:0] mr; integer sh;
      begin
         s_ = isaretli ? x[31] : 1'b0;
         mag = (isaretli && x[31]) ? (~x + 1) : x;
         if (mag == 0) i2f = 32'b0;
         else begin
            msb = 31; while (msb>0 && !mag[msb]) msb=msb-1;
            e_ = 127 + msb;
            // mantisi 24-bit'e hizala (lider 1 dahil), yuvarla
            if (msb <= 23) begin
               norm = mag << (23 - msb);
               i2f = {s_, e_, norm[22:0]};
            end else begin
               sh = msb - 23;
               frac = mag >> sh;
               g = mag[sh-1];
               r = (sh>=2) ? mag[sh-2] : 1'b0;
               st = (sh>=3) ? (|(mag & ((32'b1<<(sh-2))-1))) : 1'b0;
               mr = {1'b0, 1'b1, frac};               // 1.frac (25-bit)
               if (g && (r||st||frac[0])) begin
                  mr = mr + 1;
                  if (mr[24]) begin mr = mr>>1; e_=e_+1; end
               end
               i2f = {s_, e_, mr[22:0]};
            end
         end
      end
   endfunction

   // FCLASS
   function [31:0] fclass;
      input [31:0] f;
      reg s_; reg [7:0] e_; reg [22:0] m_;
      begin
         s_=f[31]; e_=f[30:23]; m_=f[22:0];
         fclass = 0;
         if (e_==8'hFF && m_==0)        fclass = s_ ? 32'h1   : 32'h80;   // -/+inf
         else if (e_==8'hFF && m_[22])  fclass = 32'h200;                 // qNaN
         else if (e_==8'hFF)            fclass = 32'h100;                 // sNaN
         else if (e_==0 && m_==0)       fclass = s_ ? 32'h8   : 32'h10;   // -/+0
         else if (e_==0)                fclass = s_ ? 32'h4   : 32'h20;   // -/+ subnormal
         else                           fclass = s_ ? 32'h2   : 32'h40;   // -/+ normal
      end
   endfunction

   // ======================= islem secimi =======================
   wire is_cmp    = (funct7_i == 7'b1010000);
   wire is_f2i    = (funct7_i == 7'b1100000);
   wire is_fmvx   = (funct7_i == 7'b1110000);   // FMV.X.W (rm0) / FCLASS (rm1)
   assign tamsayi_sonuc_o = is_cmp || is_f2i || is_fmvx;

   reg [31:0] r;
   always @* begin
      r = 32'b0;
      case (funct7_i)
         7'b0000000, 7'b0000100: begin   // FADD / FSUB
            if (a_nan||b_nan|| (a_inf&&b_inf&&(s1!=bs))) r = QNAN;
            else if (a_inf) r = f1_i;
            else if (b_inf) r = {bs, 8'hFF, 23'b0};
            else r = fadd(s1, bs, e1, be, m1, bm);
         end
         7'b0001000: begin               // FMUL
            if (a_nan||b_nan||(a_inf&&b_zero)||(b_inf&&a_zero)) r = QNAN;
            else if (a_inf||b_inf) r = {s1^s2, 8'hFF, 23'b0};
            else r = fmul(s1, s2, e1, e2, m1, m2);
         end
         7'b0001100: begin               // FDIV
            if (a_nan||b_nan||(a_zero&&b_zero)||(a_inf&&b_inf)) r = QNAN;
            else if (a_inf || b_zero) r = {s1^s2, 8'hFF, 23'b0};   // inf/x , x/0 -> inf
            else if (b_inf || a_zero) r = {s1^s2, 31'b0};          // x/inf , 0/x -> 0
            else r = fdiv(s1, s2, e1, e2, m1, m2);
         end
         7'b0101100: begin               // FSQRT (rs2=00000)
            if (a_nan)               r = QNAN;
            else if (s1 && !a_zero)  r = QNAN;     // sqrt(negatif) -> NaN
            else if (a_inf||a_zero)  r = f1_i;     // sqrt(+inf)=+inf, sqrt(+/-0)=+/-0
            else r = fsqrt(f1_i);
         end
         7'b0010000: case (rm_i)          // FSGNJ / N / X
            3'b000: r = {s2,        f1_i[30:0]};
            3'b001: r = {~s2,       f1_i[30:0]};
            3'b010: r = {s1^s2,     f1_i[30:0]};
            default:r = {s2,        f1_i[30:0]};
         endcase
         7'b0010100: case (rm_i)          // FMIN / FMAX
            3'b000: r = (a_nan&&b_nan) ? QNAN : a_nan ? f2_i : b_nan ? f1_i : (flt||feq) ? (feq&&!flt&&both_zero ? (s1?f1_i:f2_i) : (flt?f1_i:f2_i)) : f2_i; // FMIN
            3'b001: r = (a_nan&&b_nan) ? QNAN : a_nan ? f2_i : b_nan ? f1_i : (flt) ? f2_i : f1_i; // FMAX
            default:r = f1_i;
         endcase
         7'b1010000: case (rm_i)          // FEQ / FLT / FLE
            3'b010: r = (a_nan||b_nan) ? 32'b0 : {31'b0, feq};            // FEQ
            3'b001: r = (a_nan||b_nan) ? 32'b0 : {31'b0, flt};            // FLT
            3'b000: r = (a_nan||b_nan) ? 32'b0 : {31'b0, (flt||feq)};     // FLE
            default:r = 32'b0;
         endcase
         7'b1100000: r = f2i(f1_i, (rs2f_i==5'b00000));                   // FCVT.W.S / FCVT.WU.S
         7'b1101000: r = i2f(x1_i, (rs2f_i==5'b00000));                   // FCVT.S.W / FCVT.S.WU
         7'b1110000: r = (rm_i==3'b000) ? f1_i : fclass(f1_i);            // FMV.X.W / FCLASS
         7'b1111000: r = x1_i;                                            // FMV.W.X
         default:    r = QNAN;
      endcase
   end
   always @* sonuc_o = r;

endmodule
