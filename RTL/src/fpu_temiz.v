`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  fpu_temiz  -  Temiz tek-duyarlikli (binary32) kayan nokta birimi
// ---------------------------------------------------------------------------
//  Depodaki kayan_nokta_birimi.v ve alt modulleri BOZUK (hizalama modulu cift
//  bildirim/coklu surucu icerir; carpma var olmayan enyuksek_sol_bit48'e bagli).
//  Bu yuzden onceki ornege uygun olarak (coz_asamasi/carpma/csr gibi) temiz bir
//  birim yazildi. Kombinasyonel (tek cevrim). Yuvarlama: rm alanindan (funct3)
//  RNE/RTZ/RDN/RUP/RMM (round_up fonksiyonu); DYN(111) -> frm_i (FCSR.frm).
//  bayrak_o: IEEE istisna bayraklari {NV,DZ,OF,UF,NX} (csr_birimi'nde fflags'e
//  biriktirilir). FCVT.W.S aralik-disi NV basitlestirildi; NX bayragi yok.
//
//  Desteklenen islemler (funct7 / rm ile secilir, instr[31:25],[14:12],[24:20]):
//    FADD.S 0000000, FSUB.S 0000100, FMUL.S 0001000,
//    FSGNJ/N/X 0010000 (rm 000/001/010),  FMIN/FMAX 0010100 (rm 000/001),
//    FEQ/FLT/FLE 1010000 (rm 010/001/000) -> tamsayi sonuc,
//    FCVT.W.S/FCVT.WU.S 1100000 (rs2 0/1) -> tamsayi,
//    FMV.X.W 1110000 rm000, FCLASS 1110000 rm001 -> tamsayi,
//    FCVT.S.W/FCVT.S.WU 1101000 (rs2 0/1) <- tamsayi,  FMV.W.X 1111000 <- tamsayi.
//    FDIV.S 0001100, FSQRT.S 0101100 (rs2 0) -> tam-hassas kombinasyonel.
//    FMADD/FMSUB/FNMSUB/FNMADD (ayri opcode + f[rs3]) -> fma_gecerli_i/fma_op_i/f3_i ile;
//      tam-hassas urun, TEK yuvarlama (genis sabit-nokta akumulator).
//  ALTNORMAL (subnormal) destegi: norm_in (giris normalize, isaretli us) + pack (cikis
//  normal/subnormal gradual-underflow/overflow + yuvarlama) ile FADD/FMUL/FDIV/FSQRT/FMADD.
//
//  tamsayi_sonuc_o: sonuc tamsayi yazmac obegine mi (FEQ/FLT/FLE/FCVT.W/FMV.X/FCLASS).
// ===========================================================================

module fpu_temiz (
   input  [6:0]  funct7_i,
   input  [2:0]  rm_i,        // funct3 (islem/yuvarlama secimi)
   input  [2:0]  frm_i,       // FCSR.frm (rm_i=111 DYN ise kullanilir)
   input  [4:0]  rs2f_i,      // rs2 alani (FCVT/FMV ayrimi)
   input  [31:0] f1_i,        // f[rs1]
   input  [31:0] f2_i,        // f[rs2]
   input  [31:0] f3_i,        // f[rs3] (fused multiply-add ucuncu operand)
   input  [31:0] x1_i,        // tamsayi rs1 (FCVT.S.W / FMV.W.X)
   input         fma_gecerli_i,   // bu buyruk FMADD ailesinden mi
   input  [1:0]  fma_op_i,        // {neg_prod, sub_c} (opcode[3:2])
   output reg [31:0] sonuc_o,
   output            tamsayi_sonuc_o,  // sonuc tamsayi RF'ye mi
   output reg [4:0]  bayrak_o          // fflags {NV,DZ,OF,UF,NX}
);

   // Etkin yuvarlama modu: DYN(111) ise FCSR.frm, aksi halde komut rm alani.
   wire [2:0] erm = (rm_i == 3'b111) ? frm_i : rm_i;
   // Sinyalleyen NaN tespiti (mantis MSB=0 -> sNaN -> NV)
   wire a_snan = (f1_i[30:23]==8'hFF) && (f1_i[22:0]!=0) && !f1_i[22];
   wire b_snan = (f2_i[30:23]==8'hFF) && (f2_i[22:0]!=0) && !f2_i[22];
   // f3 (FMA ucuncu operand) ayristirma
   wire s3     = f3_i[31];
   wire c_nan  = (f3_i[30:23]==8'hFF) && (f3_i[22:0]!=0);
   wire c_inf  = (f3_i[30:23]==8'hFF) && (f3_i[22:0]==0);
   wire c_zero = (f3_i[30:23]==0)     && (f3_i[22:0]==0);
   wire c_snan = c_nan && !f3_i[22];

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

   // ======================= Yuvarlama karari (RNE/RTZ/RDN/RUP/RMM) =======================
   //  g  = guard (LSB'nin hemen altindaki bit), rb = round, st = sticky (g'nin altinda kalan
   //  bitlerin OR'u), lsb = sonucun en dusuk biti, sgn = sonuc isareti.
   //  rm: 000 RNE, 001 RTZ, 010 RDN, 011 RUP, 100 RMM, 111 DYN(->frm yok, RNE varsayilir).
   function round_up;
      input g, rb, st, lsb, sgn;
      input [2:0] rm;
      reg any_below;
      begin
         any_below = g || rb || st;                       // atilan bitlerden biri 1 mi
         case (rm)
            3'b000:  round_up = g && (rb || st || lsb);    // RNE: en yakina, beraberlik->cift
            3'b001:  round_up = 1'b0;                       // RTZ: sifira dogru (kesme)
            3'b010:  round_up = sgn && any_below;           // RDN: -sonsuza
            3'b011:  round_up = !sgn && any_below;          // RUP: +sonsuza
            3'b100:  round_up = g;                          // RMM: en yakina, beraberlik->buyuk buyukluk
            default: round_up = g && (rb || st || lsb);     // DYN ve digerleri -> RNE
         endcase
      end
   endfunction

   // ======================= Altnormal yardimcilari =======================
   //  norm_in: bir operandi (24-bit normalize mantis M, isaretli gercek us E) olarak
   //  ayristirir; deger = M * 2^(E-23). normal: M={1,m},E=e-127. subnormal: m normalize
   //  edilir (E < -126). sifir: M=0,E=0.  Donus: {E[9:0] signed, M[23:0]} (34-bit).
   function [33:0] norm_in;
      input [31:0] f;
      reg [7:0] e_; reg [22:0] m_; reg [23:0] M; reg signed [9:0] E;
      begin
         e_ = f[30:23]; m_ = f[22:0];
         if (e_ == 0) begin
            if (m_ == 0) begin M = 0; E = 0; end           // sifir
            else begin                                      // subnormal
               M = {1'b0, m_};  E = -10'sd126;
               while (!M[23]) begin M = M << 1; E = E - 1; end
            end
         end else begin
            M = {1'b1, m_};  E = $signed({2'b0, e_}) - 10'sd127;  // normal
         end
         norm_in = {E, M};
      end
   endfunction

   //  pack: normalize sonucu (1.f * 2^Eres) f32'ye paketler: normal / subnormal (gradual
   //  underflow) / overflow; rm ile yuvarlar. inx0 = yuvarlama oncesi atilan bit var mi.
   //  Donus {OF,UF,NX,sonuc[31:0]}.
   function [34:0] pack;
      input        sgn;
      input [23:0] M24;          // normalize mantis (bit23=1), 1.f
      input        g0, r0, s0;   // urun/bolme'den gelen guard/round/sticky
      input signed [11:0] Eres;  // yansiz us (deger = M24 * 2^(Eres-23) = 1.f * 2^Eres)
      input [2:0]  rm_;
      reg signed [11:0] E; reg [24:0] mr; reg [23:0] fr; integer rsh, i;
      reg g, rb, st, inx; reg [7:0] bx; reg [23:0] mask;
      begin
         E = Eres;
         if (E + 127 >= 255) begin
            pack = {3'b101, sgn, 8'hFF, 23'b0};                 // overflow -> inf (OF+NX)
         end
         else if (E + 127 >= 1) begin                            // ----- normal -----
            g = g0; rb = r0; st = s0; inx = g|rb|st;
            mr = {1'b0, M24};
            if (round_up(g, rb, st, M24[0], sgn, rm_)) begin
               mr = mr + 1;
               if (mr[24]) begin mr = mr >> 1; E = E + 1; end
            end
            if (E + 127 >= 255) pack = {3'b101, sgn, 8'hFF, 23'b0};
            else begin bx = E + 12'sd127; pack = {2'b00, inx, sgn, bx, mr[22:0]}; end
         end
         else begin                                             // ----- subnormal / underflow -----
            rsh = -(E + 126);                                    // >=1 sag kaydirma
            if (rsh > 24) begin
               // tum mantis LSB altinda: g=0, sticky=tum M24
               g = 1'b0; rb = 1'b0; st = (|M24) | g0 | r0 | s0; fr = 24'b0;
            end else begin
               fr = M24 >> rsh;
               g  = (rsh >= 1) ? M24[rsh-1] : 1'b0;
               rb = (rsh >= 2) ? M24[rsh-2] : 1'b0;
               mask = (rsh >= 3) ? ((24'd1 << (rsh-2)) - 24'd1) : 24'd0;
               st = ((rsh >= 3) ? |(M24 & mask) : 1'b0) | g0 | r0 | s0;
            end
            inx = g | rb | st;
            mr = {1'b0, fr};
            if (round_up(g, rb, st, fr[0], sgn, rm_)) mr = mr + 1;
            // mr[23]=1 ise en kucuk normale yuvarlandi (exp=1); aksi halde subnormal (exp=0)
            pack = {2'b0, (inx ? 1'b1 : 1'b0), sgn, (mr[23] ? 8'd1 : 8'd0), mr[22:0]};
            if (inx) pack[33] = 1'b1;                            // UF (tiny + inexact)
         end
      end
   endfunction

   // ======================= FADD / FSUB =======================
   wire sub = funct7_i[2];                 // FSUB ise f2 isaretini ters cevir
   wire        bs = s2 ^ sub;
   wire [7:0]  be = e2;
   wire [22:0] bm = m2;

   //  Altnormal destekli (norm_in + pack). Hizali mantis 27-bit: {1.23, G,R,S},
   //  lider 1 bit26'da; bit27 elde-basligi.  Donus {OF,UF,NX,sonuc[31:0]}.
   function [34:0] fadd;
      input        as_, bs_;
      input [7:0]  ae_, be_;
      input [22:0] am_, bm_;
      input [2:0]  rm_;
      reg [33:0] na, nb; reg [23:0] Ma, Mb; reg signed [9:0] Ea, Eb;
      reg sb, sbig; reg signed [11:0] Er; reg [26:0] mhi, mlo, lost; reg [27:0] sum;
      integer sh, i; reg g, r0, s0;
      begin
         na = norm_in({as_,ae_,am_}); Ea = $signed(na[33:24]); Ma = na[23:0];
         nb = norm_in({bs_,be_,bm_}); Eb = $signed(nb[33:24]); Mb = nb[23:0];
         if (Ma==0 && Mb==0)
            fadd = {3'b000, ((as_&&bs_) || (rm_==3'b010 && (as_||bs_))), 31'b0}; // 0+0 isaret
         else if (Ma==0) fadd = {3'b000, bs_, be_, bm_};       // 0 + b = b
         else if (Mb==0) fadd = {3'b000, as_, ae_, am_};       // a + 0 = a
         else begin
            if ((Ea > Eb) || (Ea==Eb && Ma>=Mb)) begin
               sbig=as_; Er=Ea; mhi={Ma,3'b0}; sb=bs_; mlo={Mb,3'b0}; sh=Ea-Eb;
            end else begin
               sbig=bs_; Er=Eb; mhi={Mb,3'b0}; sb=as_; mlo={Ma,3'b0}; sh=Eb-Ea;
            end
            if (sh > 27) sh = 27;
            lost = (sh>=27) ? mlo : (mlo & ((27'b1<<sh)-1));
            mlo  = mlo >> sh;
            if (|lost) mlo[0] = 1'b1;                          // sticky
            if (as_ == bs_) begin                              // ayni isaret -> topla
               sum = {1'b0, mhi} + {1'b0, mlo};
               if (sum[27]) begin s0=sum[0]; sum=sum>>1; sum[0]=sum[0]|s0; Er=Er+1; end
            end else begin                                     // farkli isaret -> cikar (mhi>=mlo)
               sum = {1'b0, mhi} - {1'b0, mlo};
               i = 0;
               while (sum[26]==1'b0 && (|sum) && i<27) begin sum=sum<<1; Er=Er-1; i=i+1; end
            end
            if (sum == 0) fadd = {3'b000, (rm_==3'b010), 31'b0};   // tam iptal -> +0 (RDN -0)
            else begin
               g = sum[2]; r0 = sum[1]; s0 = sum[0];
               fadd = pack(sbig, sum[26:3], g, r0, s0, Er, rm_);
            end
         end
      end
   endfunction

   // ======================= FMUL =======================
   //  Altnormal destekli: girisler norm_in ile (subnormal dahil), sonuc pack ile
   //  (normal/subnormal gradual underflow/overflow + yuvarlama).
   function [34:0] fmul;
      input        as_, bs_;
      input [7:0]  ae_, be_;
      input [22:0] am_, bm_;
      input [2:0]  rm_;
      reg sr; reg [33:0] na, nb; reg [23:0] Ma, Mb, M24; reg signed [9:0] Ea, Eb;
      reg [47:0] p; reg signed [11:0] Eres; reg g, r0, s0;
      begin
         sr = as_ ^ bs_;
         na = norm_in({as_, ae_, am_});  Ea = na[33:24]; Ma = na[23:0];
         nb = norm_in({bs_, be_, bm_});  Eb = nb[33:24]; Mb = nb[23:0];
         if (Ma == 0 || Mb == 0) fmul = {3'b000, sr, 31'b0};   // sifir carpani -> +/-0
         else begin
            p = Ma * Mb;                          // [2^46, 2^48)
            if (p[47]) Eres = $signed(Ea) + $signed(Eb) + 12'sd1;
            else begin p = p << 1; Eres = $signed(Ea) + $signed(Eb); end
            M24 = p[47:24]; g = p[23]; r0 = p[22]; s0 = |p[21:0];
            fmul = pack(sr, M24, g, r0, s0, Eres, rm_);
         end
      end
   endfunction

   // ======================= FDIV =======================
   //  Tam-hassas bolme: mantisalar 24-bit; ma/mb*2^27 tamsayi bolme ile bulunur,
   //  normalize edilip yuvarlanir (RNE). Kalan -> sticky.
   function [34:0] fdiv;
      input        as_, bs_;
      input [7:0]  ae_, be_;
      input [22:0] am_, bm_;
      input [2:0]  rm_;
      reg sr; reg [33:0] na, nb; reg [23:0] Ma, Mb, M24; reg signed [9:0] Ea, Eb;
      reg signed [11:0] Eres; reg [50:0] dividend, rem; reg [27:0] q; reg g, r0, s0, st0;
      begin
         sr = as_ ^ bs_;
         na = norm_in({as_,ae_,am_}); Ea = $signed(na[33:24]); Ma = na[23:0];
         nb = norm_in({bs_,be_,bm_}); Eb = $signed(nb[33:24]); Mb = nb[23:0];
         dividend = {Ma, 27'b0};                 // Ma << 27  (Ma/Mb * 2^27)
         q   = dividend / Mb;                     // [2^26, 2^28)
         rem = dividend - q*Mb; st0 = |rem;
         if (q[27]) begin                         // oran >= 1 (lider 1 -> bit27)
            Eres = $signed(Ea) - $signed(Eb);
            M24 = q[27:4]; g = q[3]; r0 = q[2]; s0 = q[1]|q[0]|st0;
         end else begin                           // oran [0.5,1) (lider 1 -> bit26)
            Eres = $signed(Ea) - $signed(Eb) - 12'sd1;
            M24 = q[26:3]; g = q[2]; r0 = q[1]; s0 = q[0]|st0;
         end
         fdiv = pack(sr, M24, g, r0, s0, Eres, rm_);
      end
   endfunction

   // ======================= FSQRT =======================
   //  Karekok (yalnizca s=0): tek/cift ussu ayir, mantisi olcekle, tamsayi
   //  karekok (bit-bit digit-recurrence) ile 26-bit sonuc; RNE yuvarla. Kalan -> sticky.
   function [34:0] fsqrt;
      input [31:0] f;
      input [2:0]  rm_;
      reg [33:0] na; reg [23:0] M, m24; reg signed [11:0] E, resE;
      reg [55:0] rad, a, tsq; reg [27:0] q4, t; integer i;
      reg g, rb, st;
      begin
         na = norm_in(f); E = $signed(na[33:24]); M = na[23:0];  // altnormal -> normalize
         // deger = (M/2^23) * 2^E,  mant in [1,2), us E (isaretli)
         if (E[0] == 1'b0) begin                  // cift us
            rad  = {32'b0, M} << 23;
            resE = E >>> 1;
         end else begin                           // tek us (mantise 1 bit ekle)
            rad  = {32'b0, M} << 24;
            resE = (E - 1) >>> 1;
         end
         a  = rad << 4;                            // 2 ekstra bit (sonuc = gercek*4)
         q4 = 0;
         for (i = 26; i >= 0; i = i - 1) begin
            t   = q4 | (28'b1 << i);
            tsq = t * t;
            if (tsq <= a) q4 = t;
         end
         st  = ((q4*q4) != a);                     // kalan -> sticky
         m24 = q4[25:2]; g = q4[1]; rb = q4[0];
         // sqrt sonucu daima normal araliktadir -> pack normal yolu (isaret 0)
         fsqrt = pack(1'b0, m24, g, rb, st, resE, rm_);
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

   // signed int -> float (FCVT.S.W).  Donus: {OF, UF, NX, sonuc[31:0]} (OF/UF olmaz)
   function [34:0] i2f;
      input [31:0] x; input isaretli; input [2:0] rm_;
      reg s_; reg [31:0] mag; integer msb; integer i; reg [7:0] e_; reg [22:0] frac;
      reg [31:0] norm; reg g,r,st,inx; reg [24:0] mr; integer sh;
      begin
         s_ = isaretli ? x[31] : 1'b0;
         mag = (isaretli && x[31]) ? (~x + 1) : x;
         if (mag == 0) i2f = {3'b000, 32'b0};
         else begin
            msb = 31; while (msb>0 && !mag[msb]) msb=msb-1;
            e_ = 127 + msb;
            // mantisi 24-bit'e hizala (lider 1 dahil), yuvarla
            if (msb <= 23) begin
               norm = mag << (23 - msb);
               i2f = {3'b000, s_, e_, norm[22:0]};      // tam (yuvarlama yok)
            end else begin
               sh = msb - 23;
               frac = mag >> sh;
               g = mag[sh-1];
               r = (sh>=2) ? mag[sh-2] : 1'b0;
               st = (sh>=3) ? (|(mag & ((32'b1<<(sh-2))-1))) : 1'b0;
               inx = g | r | st;
               mr = {1'b0, 1'b1, frac};               // 1.frac (25-bit)
               if (round_up(g, r, st, frac[0], s_, rm_)) begin
                  mr = mr + 1;
                  if (mr[24]) begin mr = mr>>1; e_=e_+1; end
               end
               i2f = {2'b00, inx, s_, e_, mr[22:0]};
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

   // ======================= FMADD ailesi (fused multiply-add) =======================
   //  result = (-1)^np * (a*b) + (-1)^sc * c, TEK yuvarlama (tam-hassas urun).
   //  Genis sabit-nokta akumulator (FW bit) ile a*b (48-bit) ve c (24-bit) ortak
   //  olcekte TAM toplanir; sonra normalize + RNE/rm yuvarlama. (Donanim icin genis
   //  ama dogru; bu kod tabani simulasyon-odakli.)  Donus {OF,UF,NX,sonuc}.
   localparam integer FW = 600;
   function [34:0] fmadd;
      input [31:0] fa, fb, fc;
      input        np, sc_;             // neg_prod, sub_c
      input [2:0]  rm_;
      reg sa,sb,scn; reg [33:0] na,nb,nc; reg signed [9:0] Ea,Eb,Ec;
      reg [23:0] ma,mb,mc; reg [47:0] pm;
      reg psign, csign, rsign; integer pe, ce, refe, i, msb, shamt;
      reg [FW-1:0] pterm, cterm, mag, one, mask; reg [24:0] mr; reg [23:0] frac24;
      reg g, rb, st; integer Er, bias;
      begin
         one = 1;
         sa=fa[31]; sb=fb[31]; scn=fc[31];
         na=norm_in(fa); Ea=$signed(na[33:24]); ma=na[23:0];   // altnormal -> normalize
         nb=norm_in(fb); Eb=$signed(nb[33:24]); mb=nb[23:0];
         nc=norm_in(fc); Ec=$signed(nc[33:24]); mc=nc[23:0];
         pm    = ma*mb;
         psign = sa ^ sb ^ np;
         csign = scn ^ sc_;
         pe    = Ea + Eb - 46;             // urun LSB ussu (pm bit0 = 2^pe)
         ce    = Ec - 23;                  // c LSB ussu (mc bit0 = 2^ce)
         refe  = (pe < ce) ? pe : ce;      // ortak LSB
         pterm = {{(FW-48){1'b0}}, pm} << (pe - refe);
         cterm = {{(FW-24){1'b0}}, mc} << (ce - refe);
         if (psign == csign)        begin mag = pterm + cterm; rsign = psign; end
         else if (pterm >= cterm)   begin mag = pterm - cterm; rsign = psign; end
         else                       begin mag = cterm - pterm; rsign = csign; end
         if (mag == 0) begin
            fmadd = {3'b000, (rm_==3'b010)?32'h80000000:32'h00000000};  // tam iptal -> +0 (RDN -> -0)
         end else begin
            msb = FW-1; while (!mag[msb]) msb = msb - 1;
            Er  = refe + msb;             // sonuc ussu (yansiz): deger = 1.f * 2^Er
            if (msb >= 23) begin
               shamt  = msb - 23;
               frac24 = mag >> shamt;                       // 24-bit (lider 1 = bit23)
               g  = mag[shamt-1];
               rb = (shamt >= 2) ? mag[shamt-2] : 1'b0;
               mask = (one << (shamt-2)) - 1;
               st = (shamt >= 3) ? |(mag & mask) : 1'b0;
            end else begin
               frac24 = mag << (23 - msb);                  // tam (yuvarlama yok)
               g = 1'b0; rb = 1'b0; st = 1'b0;
            end
            // Normal/subnormal/overflow paketleme + yuvarlama (altnormal cikis destekli)
            fmadd = pack(rsign, frac24, g, rb, st, Er[11:0], rm_);
         end
      end
   endfunction

   // ======================= islem secimi =======================
   wire is_cmp    = (funct7_i == 7'b1010000);
   wire is_f2i    = (funct7_i == 7'b1100000);
   wire is_fmvx   = (funct7_i == 7'b1110000);   // FMV.X.W (rm0) / FCLASS (rm1)
   assign tamsayi_sonuc_o = !fma_gecerli_i && (is_cmp || is_f2i || is_fmvx);

   //  Yuvarlama islemleri {OF,UF,NX,sonuc} 35-bit doner; bayrak alanlari [34:32].
   // FMA etkin isaretler (opcode[3]=neg_prod, opcode[2]=sub_c)
   wire        fma_psign = s1 ^ s2 ^ fma_op_i[1];
   wire        fma_csign = s3 ^ fma_op_i[0];
   wire        fma_pinf  = (a_inf && !b_zero) || (b_inf && !a_zero);
   wire        fma_pnan  = (a_inf && b_zero) || (b_inf && a_zero);   // 0*inf -> gecersiz

   reg [31:0] r;
   reg [34:0] w;            // genis (flag'li) sonuc
   reg [4:0]  bayrak;       // {NV, DZ, OF, UF, NX}
   always @* begin
      r = 32'b0;
      w = 35'b0;
      bayrak = 5'b0;
      if (fma_gecerli_i) begin
         // ---- FMADD ailesi ----
         if (a_nan||b_nan||c_nan||fma_pnan) begin
            r = QNAN;
            bayrak[4] = a_snan||b_snan||c_snan||fma_pnan;          // NV
         end
         else if (fma_pinf || c_inf) begin
            if (fma_pinf && c_inf && (fma_psign != fma_csign)) begin
               r = QNAN; bayrak[4] = 1'b1;                         // inf - inf -> NV
            end
            else if (fma_pinf) r = {fma_psign, 8'hFF, 23'b0};
            else               r = {fma_csign, 8'hFF, 23'b0};
         end
         else begin
            w = fmadd(f1_i, f2_i, f3_i, fma_op_i[1], fma_op_i[0], erm);
            r = w[31:0]; bayrak[2:0] = w[34:32];
         end
      end
      else
      case (funct7_i)
         7'b0000000, 7'b0000100: begin   // FADD / FSUB
            if (a_nan||b_nan|| (a_inf&&b_inf&&(s1!=bs))) begin
               r = QNAN;
               bayrak[4] = a_snan || b_snan || (a_inf&&b_inf&&(s1!=bs));  // NV
            end
            else if (a_inf) r = f1_i;
            else if (b_inf) r = {bs, 8'hFF, 23'b0};
            else begin w = fadd(s1, bs, e1, be, m1, bm, erm); r = w[31:0]; bayrak[2:0] = w[34:32]; end
         end
         7'b0001000: begin               // FMUL
            if (a_nan||b_nan||(a_inf&&b_zero)||(b_inf&&a_zero)) begin
               r = QNAN;
               bayrak[4] = a_snan || b_snan || (a_inf&&b_zero) || (b_inf&&a_zero);
            end
            else if (a_inf||b_inf) r = {s1^s2, 8'hFF, 23'b0};
            else begin w = fmul(s1, s2, e1, e2, m1, m2, erm); r = w[31:0]; bayrak[2:0] = w[34:32]; end
         end
         7'b0001100: begin               // FDIV
            if (a_nan||b_nan||(a_zero&&b_zero)||(a_inf&&b_inf)) begin
               r = QNAN;
               bayrak[4] = a_snan || b_snan || (a_zero&&b_zero) || (a_inf&&b_inf);
            end
            else if (a_inf || b_zero) begin
               r = {s1^s2, 8'hFF, 23'b0};                              // inf/x , x/0 -> inf
               bayrak[3] = b_zero && !a_inf;                           // DZ: sonlu/0
            end
            else if (b_inf || a_zero) r = {s1^s2, 31'b0};              // x/inf , 0/x -> 0
            else begin w = fdiv(s1, s2, e1, e2, m1, m2, erm); r = w[31:0]; bayrak[2:0] = w[34:32]; end
         end
         7'b0101100: begin               // FSQRT (rs2=00000)
            if (a_nan)               begin r = QNAN; bayrak[4] = a_snan; end
            else if (s1 && !a_zero)  begin r = QNAN; bayrak[4] = 1'b1; end   // sqrt(negatif) -> NV
            else if (a_inf||a_zero)  r = f1_i;     // sqrt(+inf)=+inf, sqrt(+/-0)=+/-0
            else begin w = fsqrt(f1_i, erm); r = w[31:0]; bayrak[2:0] = w[34:32]; end
         end
         7'b0010000: case (rm_i)          // FSGNJ / N / X  (yuvarlama yok, bayrak yok)
            3'b000: r = {s2,        f1_i[30:0]};
            3'b001: r = {~s2,       f1_i[30:0]};
            3'b010: r = {s1^s2,     f1_i[30:0]};
            default:r = {s2,        f1_i[30:0]};
         endcase
         7'b0010100: begin                // FMIN / FMAX
            case (rm_i)
            3'b000: r = (a_nan&&b_nan) ? QNAN : a_nan ? f2_i : b_nan ? f1_i : (flt||feq) ? (feq&&!flt&&both_zero ? (s1?f1_i:f2_i) : (flt?f1_i:f2_i)) : f2_i; // FMIN
            3'b001: r = (a_nan&&b_nan) ? QNAN : a_nan ? f2_i : b_nan ? f1_i : (flt) ? f2_i : f1_i; // FMAX
            default:r = f1_i;
            endcase
            bayrak[4] = a_snan || b_snan;          // sinyalleyen NaN -> NV
         end
         7'b1010000: begin                // FEQ / FLT / FLE
            case (rm_i)
            3'b010: begin r = (a_nan||b_nan) ? 32'b0 : {31'b0, feq};         // FEQ
                          bayrak[4] = a_snan || b_snan; end                  // sadece sNaN -> NV
            3'b001: begin r = (a_nan||b_nan) ? 32'b0 : {31'b0, flt};         // FLT
                          bayrak[4] = a_nan || b_nan; end                    // her NaN -> NV
            3'b000: begin r = (a_nan||b_nan) ? 32'b0 : {31'b0, (flt||feq)};  // FLE
                          bayrak[4] = a_nan || b_nan; end
            default:r = 32'b0;
            endcase
         end
         7'b1100000: begin                // FCVT.W.S / FCVT.WU.S
            r = f2i(f1_i, (rs2f_i==5'b00000));
            bayrak[4] = a_nan || a_inf;            // NV (aralik-disi doygunluk basitlestirildi)
         end
         7'b1101000: begin                // FCVT.S.W / FCVT.S.WU
            w = i2f(x1_i, (rs2f_i==5'b00000), erm); r = w[31:0]; bayrak[2:0] = w[34:32];
         end
         7'b1110000: r = (rm_i==3'b000) ? f1_i : fclass(f1_i);            // FMV.X.W / FCLASS
         7'b1111000: r = x1_i;                                            // FMV.W.X
         default:    r = QNAN;
      endcase
   end
   always @* sonuc_o   = r;
   always @* bayrak_o  = bayrak;

endmodule
