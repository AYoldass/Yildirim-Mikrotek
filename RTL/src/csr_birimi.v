`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  csr_birimi  -  M-kip CSR + Trap birimi  (sema B, temiz)
// ---------------------------------------------------------------------------
//  Yurut asamasinda calisir (execute = writeback modeli). Iki gorevi var:
//   1) CSR oku/yaz buyruklari (CSRRW/CSRRS/CSRRC + immediate turevleri):
//        - csr_oku_o  = CSR'nin ESKI degeri (rd'ye yazilir)
//        - posedge'de CSR yeni degerine guncellenir (op'a gore)
//   2) Trap/dönüş: ECALL/EBREAK/illegal -> mtvec'e tuzak; MRET -> mepc'e dönüş.
//        - trap_o yukselince ust modul getir'i yonlendirir + ardisik duzeni bosaltir
//          (dallanma yanlis-tahmini ile ayni mekanizma).
//
//  CSR'ler: misa, mstatus(MIE/MPIE/MPP), mie, mip, mtvec, mscratch, mepc,
//           mcause, mtval, mcycle(+h), minstret(+h), mcountinhibit.
//
//  Kesme girisleri (dis/zaman/yazilim) destekli ama bu fazda ust modulde 0'a
//  baglanir (kesme kaynagi yok); senkron istisnalar + mret tam test edilir.
//
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module csr_birimi #(
   parameter [31:0] RESET_MTVEC = 32'h8000_0000
)(
   input              clk_i,
   input              rst_i,

   // --- Yurut'tan: bu cevrim execute'taki buyruk gecerli mi ---
   input              gecerli_i,

   // --- CSR oku/yaz buyrugu (BIRIM_CSR) ---
   input              csr_mi_i,          // bu buyruk CSR oku/yaz
   input   [2:0]      funct3_i,          // CSRRW/S/C/(I)
   input   [11:0]     csr_adres_i,       // buyruk[31:20]
   input   [31:0]     rs1_deger_i,       // CSRRW/S/C kaynagi
   input   [4:0]      zimm_i,            // buyruk[19:15] (immediate turevleri)

   // --- Sistem/trap kontrolu ---
   input   [2:0]      sys_i,             // SYS_YOK/ECALL/EBREAK/MRET/ILLEGAL
   input   [31:0]     pc_i,              // execute'taki buyrugun PC'si

   // --- Kesme kaynaklari (bu fazda 0) ---
   input              dis_kesme_i,
   input              zaman_kesme_i,
   input              yazilim_kesme_i,

   // --- FCSR (kayan nokta) ---
   input   [4:0]      fp_bayrak_i,       // FPU istisna bayraklari {NV,DZ,OF,UF,NX}
   input              fp_bayrak_yaz_i,   // bu cevrim FP islemi emekli oldu -> bayrak biriktir
   output  [2:0]      frm_o,             // FCSR.frm -> FPU (DYN yuvarlama)

   // --- Cikislar ---
   output  [31:0]     csr_oku_o,         // CSR eski degeri -> rd
   output             trap_o,            // yonlendir + bosalt
   output             tuzak_o,           // tuzak girisi (exception/interrupt): commit bastir
   output  [31:0]     trap_hedef_o       // hedef PC (mtvec / mepc)
);

   // mcause kodlari (header makrolari cakistigindan acik degerler)
   localparam [3:0] SEBEP_ILLEGAL   = 4'd2;   // illegal instruction
   localparam [3:0] SEBEP_EBREAK    = 4'd3;   // breakpoint
   localparam [3:0] SEBEP_ECALL_M   = 4'd11;  // environment call from M-mode
   localparam [3:0] SEBEP_DIS_KESME = 4'd11;  // machine external interrupt
   localparam [3:0] SEBEP_YAZ_KESME = 4'd3;   // machine software interrupt
   localparam [3:0] SEBEP_ZAM_KESME = 4'd7;   // machine timer interrupt

   // ---------------- CSR durum kayitlari ----------------
   reg        mstatus_mie, mstatus_mpie;
   reg [1:0]  mstatus_mpp;
   reg        mie_meie, mie_mtie, mie_msie;
   reg        mip_meip, mip_mtip, mip_msip;
   reg [29:0] mtvec_base;
   reg [1:0]  mtvec_mode;
   reg [31:0] mscratch, mepc, mtval;
   reg        mcause_intbit;
   reg [3:0]  mcause_code;
   reg [63:0] mcycle, minstret;
   reg        mcountinhibit_cy, mcountinhibit_ir;
   reg [4:0]  fflags;          // {NV,DZ,OF,UF,NX}
   reg [2:0]  frm;             // yuvarlama modu
   assign     frm_o = frm;

   // ---------------- Okuma (eski deger) ----------------
   reg [31:0] csr_data;
   always @* begin
      csr_data = 32'b0;
      case (csr_adres_i)
         `MISA:    begin csr_data[8]=1'b1; csr_data[31:30]=2'b01; end
         `MSTATUS: begin csr_data[3]=mstatus_mie; csr_data[7]=mstatus_mpie;
                         csr_data[12:11]=mstatus_mpp; end
         `MIE:     begin csr_data[3]=mie_msie; csr_data[7]=mie_mtie; csr_data[11]=mie_meie; end
         `MIP:     begin csr_data[3]=mip_msip; csr_data[7]=mip_mtip; csr_data[11]=mip_meip; end
         `MTVEC:   csr_data = {mtvec_base, mtvec_mode};
         `MSCRATCH:csr_data = mscratch;
         `MEPC:    csr_data = mepc;
         `MCAUSE:  begin csr_data[31]=mcause_intbit; csr_data[3:0]=mcause_code; end
         `MTVAL:   csr_data = mtval;
         `MCYCLE:  csr_data = mcycle[31:0];
         `MCYCLEH: csr_data = mcycle[63:32];
         `MINSTRET:csr_data = minstret[31:0];
         `MINSTRETH:csr_data= minstret[63:32];
         `MCOUNTINHIBIT: begin csr_data[0]=mcountinhibit_cy; csr_data[2]=mcountinhibit_ir; end
         `FFLAGS:  csr_data[4:0] = fflags;
         `FRM:     csr_data[2:0] = frm;
         `FCSR:    begin csr_data[4:0] = fflags; csr_data[7:5] = frm; end
         default:  csr_data = 32'b0;
      endcase
   end
   assign csr_oku_o = csr_data;

   // ---------------- Yeni deger (yazilacak) ----------------
   wire [31:0] zimm_w = {27'b0, zimm_i};
   wire [31:0] kaynak = funct3_i[2] ? zimm_w : rs1_deger_i;  // immediate mi?
   reg  [31:0] csr_in;
   reg         csr_yaz;     // CSR guncellenecek mi
   always @* begin
      csr_in  = csr_data;
      csr_yaz = 1'b0;
      if (csr_mi_i && gecerli_i) begin
         case (funct3_i[1:0])
            2'b01: begin csr_in = kaynak;             csr_yaz = 1'b1; end          // RW/RWI
            2'b10: begin csr_in = csr_data |  kaynak; csr_yaz = (kaynak != 0); end // RS/RSI
            2'b11: begin csr_in = csr_data & ~kaynak; csr_yaz = (kaynak != 0); end // RC/RCI
            default: begin csr_in = csr_data;         csr_yaz = 1'b0; end
         endcase
      end
   end

   // ---------------- Trap / dönüş tespiti ----------------
   wire is_ecall   = gecerli_i && (sys_i == `SYS_ECALL);
   wire is_ebreak  = gecerli_i && (sys_i == `SYS_EBREAK);
   wire is_illegal = gecerli_i && (sys_i == `SYS_ILLEGAL);
   wire is_mret    = gecerli_i && (sys_i == `SYS_MRET);

   wire dis_pending = mstatus_mie && mie_meie && mip_meip;
   wire zam_pending = mstatus_mie && mie_mtie && mip_mtip;
   wire yaz_pending = mstatus_mie && mie_msie && mip_msip;
   wire kesme_var   = dis_pending || zam_pending || yaz_pending;

   wire istisna_var = is_ecall || is_ebreak || is_illegal;
   wire tuzaga_git  = istisna_var || kesme_var;

   assign trap_o       = tuzaga_git || is_mret;
   assign tuzak_o      = tuzaga_git;   // exception/interrupt -> mevcut buyrugu squash
   wire [31:0] mtvec_hedef = {mtvec_base, 2'b00};   // direct mode
   assign trap_hedef_o = is_mret ? mepc : mtvec_hedef;

   // Sonraki mcause
   reg [3:0] sonraki_kod; reg sonraki_int;
   always @* begin
      sonraki_kod = mcause_code; sonraki_int = mcause_intbit;
      if      (dis_pending) begin sonraki_kod=SEBEP_DIS_KESME; sonraki_int=1; end
      else if (yaz_pending) begin sonraki_kod=SEBEP_YAZ_KESME; sonraki_int=1; end
      else if (zam_pending) begin sonraki_kod=SEBEP_ZAM_KESME; sonraki_int=1; end
      else if (is_illegal)  begin sonraki_kod=SEBEP_ILLEGAL;   sonraki_int=0; end
      else if (is_ecall)    begin sonraki_kod=SEBEP_ECALL_M;   sonraki_int=0; end
      else if (is_ebreak)   begin sonraki_kod=SEBEP_EBREAK;    sonraki_int=0; end
   end

   // Buyruk emekli oldu mu (minstret) — tuzak alan buyruk emekli sayilmaz.
   wire emekli = gecerli_i && !tuzaga_git;

   // ---------------- Durum guncelleme ----------------
   always @(posedge clk_i) begin
      if (!rst_i) begin
         mstatus_mie<=0; mstatus_mpie<=0; mstatus_mpp<=2'b11;
         mie_meie<=0; mie_mtie<=0; mie_msie<=0;
         mip_meip<=0; mip_mtip<=0; mip_msip<=0;
         mtvec_base<=RESET_MTVEC[31:2]; mtvec_mode<=RESET_MTVEC[1:0];
         mscratch<=0; mepc<=0; mtval<=0;
         mcause_intbit<=0; mcause_code<=0;
         mcycle<=0; minstret<=0;
         mcountinhibit_cy<=0; mcountinhibit_ir<=0;
         fflags<=5'b0; frm<=3'b0;
      end
      else begin
         // Sayaclar
         if (!mcountinhibit_cy) mcycle   <= mcycle + 64'd1;
         if (!mcountinhibit_ir && emekli) minstret <= minstret + 64'd1;

         // Kesme bekleme bitleri (kaynaklardan)
         mip_meip <= dis_kesme_i;
         mip_mtip <= zaman_kesme_i;
         mip_msip <= yazilim_kesme_i;

         // Acik CSR yazmasi (CSRRW/S/C)
         if (csr_yaz) begin
            case (csr_adres_i)
               `MSTATUS: begin mstatus_mie<=csr_in[3]; mstatus_mpie<=csr_in[7];
                               mstatus_mpp<=csr_in[12:11]; end
               `MIE:     begin mie_msie<=csr_in[3]; mie_mtie<=csr_in[7]; mie_meie<=csr_in[11]; end
               `MTVEC:   begin mtvec_base<=csr_in[31:2]; mtvec_mode<=csr_in[1:0]; end
               `MSCRATCH:mscratch<=csr_in;
               `MEPC:    mepc<={csr_in[31:2],2'b00};
               `MCAUSE:  begin mcause_intbit<=csr_in[31]; mcause_code<=csr_in[3:0]; end
               `MTVAL:   mtval<=csr_in;
               `MCYCLE:  mcycle[31:0]<=csr_in;
               `MCYCLEH: mcycle[63:32]<=csr_in;
               `MINSTRET:minstret[31:0]<=csr_in;
               `MINSTRETH:minstret[63:32]<=csr_in;
               `MCOUNTINHIBIT: begin mcountinhibit_cy<=csr_in[0]; mcountinhibit_ir<=csr_in[2]; end
               `FFLAGS:  fflags <= csr_in[4:0];
               `FRM:     frm    <= csr_in[2:0];
               `FCSR:    begin fflags <= csr_in[4:0]; frm <= csr_in[7:5]; end
               default: ;
            endcase
         end

         // FP istisna bayrak biriktirme (CSR yazma ile ayni cevrimde olamaz: farkli buyruklar)
         if (fp_bayrak_yaz_i) fflags <= fflags | fp_bayrak_i;

         // Tuzak girisi (acik yazmadan sonra; tuzak onceliklidir)
         if (tuzaga_git) begin
            mepc          <= pc_i;
            mcause_code   <= sonraki_kod;
            mcause_intbit <= sonraki_int;
            mstatus_mpie  <= mstatus_mie;
            mstatus_mie   <= 1'b0;
            mstatus_mpp   <= 2'b11;
         end
         else if (is_mret) begin
            mstatus_mie  <= mstatus_mpie;
            mstatus_mpie <= 1'b1;
            mstatus_mpp  <= 2'b11;
         end
      end
   end

endmodule
