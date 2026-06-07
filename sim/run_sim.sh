#!/usr/bin/env bash
# ===========================================================================
#  run_sim.sh  -  Yildirim Mikrotek Icarus Verilog regresyon kosturucusu
# ---------------------------------------------------------------------------
#  Kullanim:
#     ./sim/run_sim.sh              # tum kayitli testleri kostur
#     ./sim/run_sim.sh getir        # adinda "getir" gecen testleri kostur
#
#  Yeni test eklemek icin asagidaki TESTLER dizisine bir satir ekleyin:
#     "ad | testbench | kaynak1 kaynak2 ..."
#
#  Not: Bazi modullerde ornek adlari Verilog-2005 ile uyumludur; standart
#  olarak -g2012 kullaniyoruz (getir alt sistemi bununla derlenir).
# ===========================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/RTL/src"
TB="$ROOT/RTL/testhbench"
HDR="$ROOT/RTL/header"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

IVERILOG="${IVERILOG:-iverilog}"
STD="${STD:--g2012}"

# ad | testbench | kaynaklar
GETIR="$SRC/getir_altsistem.v $SRC/getir_asama1.v $SRC/getir_asama2.v $SRC/dallanma_ongorucu.v"
COZ="$SRC/coz_asamasi.v $SRC/yazmac_obegi.v"
CEKIRDEK="$SRC/cekirdek.v $SRC/getir_basit.v $SRC/dallanma_ongorucu.v $SRC/coz_asamasi.v \
$SRC/yazmac_obegi.v $SRC/yurut_asamasi.v $SRC/aritmetik_mantik_birimi.v $SRC/dallanma_birimi.v \
$SRC/toplayici_birim.v $SRC/bellek_islem_birimi.v $SRC/bolme_birimi.v $SRC/csr_birimi.v \
$SRC/sikistirilmis_cozucu.v $SRC/atomik_birim.v \
$SRC/bit_manipulasyon_birimi.v $SRC/bit_manipulasyon_birim_bitcnt.v $SRC/bit_manipulasyon_birimi_zbc.v \
$SRC/bit_manipulasyon_birimi_crc.v $SRC/bit_manipulasyon_birimi_zbs.v $SRC/bit_manipulasyon_birimi_zba.v \
$SRC/fpu_temiz.v $SRC/fp_yazmac_obegi.v"
SOC="$SRC/cekirdek_ust.v $SRC/sistem_yolu.v $CEKIRDEK"
SOCVY="$SRC/soc_veriyolu.v $SRC/veri_yolu_kopru.v $SRC/veri_yolu_birimi.v $SRC/port_bellek.v $CEKIRDEK"
SOCL1="$SRC/soc_l1.v $SRC/veri_yolu_kopru.v $SRC/veri_yolu_birimi.v $SRC/veri_onbellegi_denetleyici.v \
$SRC/l1_sram.v $SRC/ana_bellek.v $CEKIRDEK"
TESTLER=(
  "getir_altsistem | $TB/tb_getir_altsistem.v | $GETIR"
  "coz_asamasi     | $TB/tb_coz_asamasi.v     | $COZ"
  "getir_coz       | $TB/tb_getir_coz.v       | $GETIR $COZ"
  "cekirdek        | $TB/tb_cekirdek.v        | $CEKIRDEK"
  "cekirdek_m      | $TB/tb_cekirdek_m.v      | $CEKIRDEK"
  "cekirdek_csr    | $TB/tb_cekirdek_csr.v    | $CEKIRDEK"
  "cekirdek_rvc    | $TB/tb_cekirdek_rvc.v    | $CEKIRDEK"
  "cekirdek_a      | $TB/tb_cekirdek_a.v      | $CEKIRDEK"
  "cekirdek_b      | $TB/tb_cekirdek_b.v      | $CEKIRDEK"
  "cekirdek_f      | $TB/tb_cekirdek_f.v      | $CEKIRDEK"
  "cekirdek_fdiv   | $TB/tb_cekirdek_fdiv.v   | $CEKIRDEK"
  "fpu_yuvarlama   | $TB/tb_fpu_yuvarlama.v   | $SRC/fpu_temiz.v"
  "cekirdek_fcsr   | $TB/tb_cekirdek_fcsr.v   | $CEKIRDEK"
  "fpu_fma         | $TB/tb_fpu_fma.v         | $SRC/fpu_temiz.v"
  "fpu_altnormal   | $TB/tb_fpu_altnormal.v   | $SRC/fpu_temiz.v"
  "cekirdek_fma    | $TB/tb_cekirdek_fma.v    | $CEKIRDEK"
  "cekirdek_karma  | $TB/tb_cekirdek_karma.v  | $CEKIRDEK"
  "cekirdek_ust    | $TB/tb_cekirdek_ust.v    | $SOC"
  "soc_veriyolu    | $TB/tb_soc_veriyolu.v    | $SOCVY"
  "soc_l1          | $TB/tb_soc_l1.v          | $SOCL1"
)

filtre="${1:-}"
gecen=0; kalan=0; toplam=0

for satir in "${TESTLER[@]}"; do
  ad="$(echo "$satir"   | cut -d'|' -f1 | xargs)"
  tb="$(echo "$satir"   | cut -d'|' -f2 | xargs)"
  kayn="$(echo "$satir" | cut -d'|' -f3)"
  [ -n "$filtre" ] && [[ "$ad" != *"$filtre"* ]] && continue
  toplam=$((toplam+1))

  vvp_out="$WORK/$ad.vvp"
  if ! $IVERILOG $STD -I "$HDR" -o "$vvp_out" $tb $kayn > "$WORK/$ad.clog" 2>&1; then
    echo "[DERLEME HATASI] $ad"; sed 's/^/    /' "$WORK/$ad.clog"; kalan=$((kalan+1)); continue
  fi

  log="$WORK/$ad.log"
  timeout 30 vvp "$vvp_out" > "$log" 2>&1
  if grep -q "TUM TESTLER BASARILI\|TUM TESTLER BA" "$log"; then
    echo "[GECTI ] $ad"; gecen=$((gecen+1))
  elif grep -qi "HATA\|FAIL\|ERROR" "$log"; then
    echo "[KALDI ] $ad"; sed 's/^/    /' "$log" | tail -20; kalan=$((kalan+1))
  else
    echo "[? ] $ad (kendi-denetimli degil; cikti asagida)"; sed 's/^/    /' "$log" | tail -5
  fi
done

echo "------------------------------------------------------------"
echo "Toplam: $toplam   Gecen: $gecen   Kalan: $kalan"
[ "$kalan" -eq 0 ]
