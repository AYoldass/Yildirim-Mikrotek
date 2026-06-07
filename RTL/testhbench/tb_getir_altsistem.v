`timescale 1ns / 1ps

// ===========================================================================
//  tb_getir_altsistem  -  getir_altsistem (Getir + Dallanma Ongorucu) testi
// ---------------------------------------------------------------------------
//  Iki asamali dogrulama:
//    FAZ 1 : Duz (sequential) buyruk getirme. Coz asamasina teslim edilen
//            buyruklarin PS sirasi 0x80000000'dan baslayip 4'er artmali ve
//            icerik bellekle birebir eslesmelidir.
//    FAZ 2 : Dallanma ongorucu egitimi. PS=0x80000010'daki dal "atlar" olarak
//            egitilir (hedef 0x80000000). Egitim sonrasi getir bu PS'e
//            ulastiginda ongorucu "atladi" demeli ve getiri 0x80000000'a geri
//            yonlendirmeli (dongu olusmali).
//
//  rst_i AKTIF-DUSUK'tur: 0 = reset, 1 = calisma.
// ===========================================================================

module tb_getir_altsistem;

   localparam BASE = 32'h8000_0000;

   reg            clk_i;
   reg            rst_i;

   // L1 buyruk arayuzu
   wire [31:0]    l1b_istek_adres_o;
   wire           l1b_istek_gecerli_o;
   reg            l1b_istek_hazir_i;
   reg  [31:0]    l1b_buyruk_i;
   reg            l1b_buyruk_gecerli_i;
   wire           l1b_buyruk_hazir_o;

   // Coz arayuzu
   wire [31:0]    coz_buyruk_o;
   wire [31:0]    coz_buyruk_ps_o;
   wire           coz_buyruk_gecerli_o;
   wire           coz_buyruk_atladi_o;

   // Yurut geri beslemesi
   reg  [31:0]    yurut_ps_i;
   reg  [31:0]    yurut_hedef_ps_i;
   reg            yurut_guncelle_i;
   reg            yurut_atladi_i;
   reg            yurut_hatali_tahmin_i;
   reg            yurut_yonlendir_gecerli_i;
   reg  [31:0]    yurut_yonlendir_ps_i;

   reg            cek_duraklat_i;
   reg            cek_bosalt_i;

   integer        hata_sayisi;

   // -------------------- Buyruk bellegi modeli -------------------- //
   //  256 word, 1 cevrim gecikmeli, her zaman hazir.
   reg [31:0] bellek [0:255];

   wire [7:0] istek_indeks_w = (l1b_istek_adres_o - BASE) >> 2;

   always @(posedge clk_i) begin
      if (l1b_istek_gecerli_o && l1b_istek_hazir_i) begin
         l1b_buyruk_i         <= bellek[istek_indeks_w];
         l1b_buyruk_gecerli_i <= 1'b1;
      end else begin
         l1b_buyruk_gecerli_i <= 1'b0;
      end
   end

   // -------------------- DUT -------------------- //
   getir_altsistem dut (
      .clk_i                     ( clk_i                     ),
      .rst_i                     ( rst_i                     ),
      .l1b_istek_adres_o         ( l1b_istek_adres_o         ),
      .l1b_istek_gecerli_o       ( l1b_istek_gecerli_o       ),
      .l1b_istek_hazir_i         ( l1b_istek_hazir_i         ),
      .l1b_buyruk_i              ( l1b_buyruk_i              ),
      .l1b_buyruk_gecerli_i      ( l1b_buyruk_gecerli_i      ),
      .l1b_buyruk_hazir_o        ( l1b_buyruk_hazir_o        ),
      .coz_buyruk_o              ( coz_buyruk_o              ),
      .coz_buyruk_ps_o           ( coz_buyruk_ps_o           ),
      .coz_buyruk_gecerli_o      ( coz_buyruk_gecerli_o      ),
      .coz_buyruk_atladi_o       ( coz_buyruk_atladi_o       ),
      .yurut_ps_i                ( yurut_ps_i                ),
      .yurut_hedef_ps_i          ( yurut_hedef_ps_i          ),
      .yurut_guncelle_i          ( yurut_guncelle_i          ),
      .yurut_atladi_i            ( yurut_atladi_i            ),
      .yurut_hatali_tahmin_i     ( yurut_hatali_tahmin_i     ),
      .yurut_yonlendir_gecerli_i ( yurut_yonlendir_gecerli_i ),
      .yurut_yonlendir_ps_i      ( yurut_yonlendir_ps_i      ),
      .cek_duraklat_i            ( cek_duraklat_i            ),
      .cek_bosalt_i              ( cek_bosalt_i              )
   );

   // -------------------- Saat -------------------- //
   initial clk_i = 0;
   always #5 clk_i = ~clk_i;

   // -------------------- Yardimcilar -------------------- //
   integer i;
   task bellek_yukle;
      begin
         // Sirali ADDI buyruklari: addi xN, x0, N  (N=1..8), gerisi NOP.
         bellek[0] = 32'h00100093; // addi x1,x0,1   @0x80000000
         bellek[1] = 32'h00200113; // addi x2,x0,2   @0x80000004
         bellek[2] = 32'h00300193; // addi x3,x0,3   @0x80000008
         bellek[3] = 32'h00400213; // addi x4,x0,4   @0x8000000C
         bellek[4] = 32'h00500293; // addi x5,x0,5   @0x80000010
         bellek[5] = 32'h00600313; // addi x6,x0,6   @0x80000014
         bellek[6] = 32'h00700393; // addi x7,x0,7   @0x80000018
         bellek[7] = 32'h00800413; // addi x8,x0,8   @0x8000001C
         for (i = 8; i < 256; i = i + 1)
            bellek[i] = 32'h00000013; // nop
      end
   endtask

   // Ongorucu egitimi: tek bir "atladi" guncellemesi uygula.
   task egit_atladi;
      input [31:0] dal_ps;
      input [31:0] hedef_ps;
      begin
         @(negedge clk_i);
         yurut_ps_i            = dal_ps;
         yurut_hedef_ps_i      = hedef_ps;
         yurut_atladi_i        = 1'b1;
         yurut_guncelle_i      = 1'b1;
         yurut_hatali_tahmin_i = 1'b0;
         @(negedge clk_i);
         yurut_guncelle_i      = 1'b0;
         yurut_atladi_i        = 1'b0;
      end
   endtask

   // -------------------- Faz 1 sonuc toplama -------------------- //
   reg [31:0] beklenen_ps;
   integer    teslim_sayisi;

   // -------------------- Test akisi -------------------- //
   initial begin
      hata_sayisi               = 0;
      l1b_istek_hazir_i         = 1'b1;
      l1b_buyruk_i              = 32'h0;
      l1b_buyruk_gecerli_i      = 1'b0;
      yurut_ps_i                = 32'h0;
      yurut_hedef_ps_i          = 32'h0;
      yurut_guncelle_i          = 1'b0;
      yurut_atladi_i            = 1'b0;
      yurut_hatali_tahmin_i     = 1'b0;
      yurut_yonlendir_gecerli_i = 1'b0;
      yurut_yonlendir_ps_i      = 32'h0;
      cek_duraklat_i            = 1'b0;
      cek_bosalt_i              = 1'b0;
      bellek_yukle;

      // ---- Reset ----
      rst_i = 1'b0;
      repeat (4) @(negedge clk_i);
      rst_i = 1'b1;

      // ================= FAZ 1 : Sirali getirme ================= //
      $display("\n===== FAZ 1: Sirali (sequential) buyruk getirme =====");
      beklenen_ps   = BASE;
      teslim_sayisi = 0;
      // Ilk 8 teslim edilen buyrugu denetle.
      while (teslim_sayisi < 8) begin
         @(posedge clk_i);
         #1;
         if (coz_buyruk_gecerli_o) begin
            if (coz_buyruk_ps_o !== beklenen_ps) begin
               $display("  HATA: teslim #%0d PS beklenen=0x%08h alinan=0x%08h",
                        teslim_sayisi, beklenen_ps, coz_buyruk_ps_o);
               hata_sayisi = hata_sayisi + 1;
            end else if (coz_buyruk_o !== bellek[(beklenen_ps-BASE)>>2]) begin
               $display("  HATA: PS=0x%08h buyruk beklenen=0x%08h alinan=0x%08h",
                        beklenen_ps, bellek[(beklenen_ps-BASE)>>2], coz_buyruk_o);
               hata_sayisi = hata_sayisi + 1;
            end else begin
               $display("  OK  : teslim #%0d  PS=0x%08h  buyruk=0x%08h",
                        teslim_sayisi, coz_buyruk_ps_o, coz_buyruk_o);
            end
            beklenen_ps   = beklenen_ps + 4;
            teslim_sayisi = teslim_sayisi + 1;
         end
      end

      // ================= FAZ 2 : Dallanma ongorusu ================= //
      $display("\n===== FAZ 2: Dallanma ongorucu egitimi ve yonlendirme =====");
      // Yeniden reset (ongorucu tablolari temizlensin, getir bastan baslasin).
      rst_i          = 1'b0;
      cek_duraklat_i = 1'b1;          // getiri dondur, ongorucu egitilirken ilerlemesin
      repeat (4) @(negedge clk_i);
      rst_i = 1'b1;

      // PS=0x80000010 dalini "atlar" (hedef 0x80000000) olarak yeterince egit.
      // Genel Gecmis Yazmaci 0x1F'e doysun ve BHT sayaci GUCLU_ATLAR'a ulassin.
      for (i = 0; i < 12; i = i + 1)
         egit_atladi(32'h8000_0010, 32'h8000_0000);

      // Getiri serbest birak.
      @(negedge clk_i);
      cek_duraklat_i = 1'b0;

      // Teslim akisini izle: 0x10'a ulasinca atladi=1 ve sonrasinda 0x00'a donus.
      begin : faz2_izle
         integer cevrim;
         reg     ondolanmadi_gordum;   // 0x10'da atladi gordumu
         reg     donus_gordum;         // sonrasinda 0x00'a donus
         reg     onceki_0x10;
         ondolanmadi_gordum = 1'b0;
         donus_gordum       = 1'b0;
         onceki_0x10        = 1'b0;
         for (cevrim = 0; cevrim < 200; cevrim = cevrim + 1) begin
            @(posedge clk_i);
            #1;
            if (coz_buyruk_gecerli_o) begin
               $display("  teslim PS=0x%08h  buyruk=0x%08h  atladi=%b",
                        coz_buyruk_ps_o, coz_buyruk_o, coz_buyruk_atladi_o);
               if (coz_buyruk_ps_o == 32'h8000_0010 && coz_buyruk_atladi_o) begin
                  ondolanmadi_gordum = 1'b1;
                  onceki_0x10        = 1'b1;
               end else if (onceki_0x10 && coz_buyruk_ps_o == 32'h8000_0000) begin
                  donus_gordum = 1'b1;
                  onceki_0x10  = 1'b0;
               end else if (coz_buyruk_ps_o != 32'h8000_0010) begin
                  onceki_0x10  = 1'b0;
               end
            end
            if (ondolanmadi_gordum && donus_gordum)
               cevrim = 200; // erken cik
         end
         if (!ondolanmadi_gordum) begin
            $display("  HATA: PS=0x80000010'da ongorucu 'atladi' uretmedi.");
            hata_sayisi = hata_sayisi + 1;
         end else begin
            $display("  OK  : PS=0x80000010'da ongorucu 'atladi' uretti.");
         end
         if (!donus_gordum) begin
            $display("  HATA: Atlama sonrasi getir 0x80000000'a yonlenmedi.");
            hata_sayisi = hata_sayisi + 1;
         end else begin
            $display("  OK  : Atlama sonrasi getir 0x80000000'a yonlendi (dongu).");
         end
      end

      // ---- Ozet ----
      $display("\n==================================================");
      if (hata_sayisi == 0)
         $display("  SONUC: TUM TESTLER BASARILI ✓");
      else
         $display("  SONUC: %0d HATA bulundu ✗", hata_sayisi);
      $display("==================================================\n");
      $finish;
   end

   // Guvenlik: simulasyon takilirsa zaman asimi.
   initial begin
      #50000;
      $display("ZAMAN ASIMI! Simulasyon takildi.");
      $finish;
   end

endmodule
