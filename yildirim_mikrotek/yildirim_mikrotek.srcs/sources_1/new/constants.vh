//------Sentez Parametreleri------
// `define VCU108
`define NEXYS
// `define SPIKE_DIFF
// `define LOG_COMMITS
// `define OPENLANE
`define USE_MUL_PIPE

//-----------Diger----------------
`define HIGH 1'b1
`define LOW  1'b0

`define VERI_BIT        32
`define VERI_BYTE       (`VERI_BIT / 8)
`define BUYRUK_BIT      32
`define PS_BIT          32
`define N_YAZMAC        32
`define YAZMAC_BIT      5
`define CSR_ADRES_BIT   12

// `define SPI_SEAMLESS    
`define SPI_IS_MSB      1'b1

// !!! DDB <> Yazmac Oku ve DDB <> Geri Yaz icin assert(VERI_BIT == MXLEN) !!!
`define XLEN            32
`define MXLEN           32

`define TL_OP_GET          4
`define TL_OP_ACK          0
`define TL_OP_ACK_DATA     1
`define TL_OP_PUT_FULL     0
`define TL_OP_PUT_PART     1

`define TL_A_MASK       16:9
`define TL_A_PARAM      8:7
`define TL_A_SRC        6
`define TL_A_SZ         5:3
`define TL_A_OP         2:0

`define TL_D_SIZE       10:8
`define TL_D_PARAM      7:6
`define TL_D_SRC        5
`define TL_D_SZ         4:3
`define TL_D_OP         2:0

`define TL_A_BITS       27
`define TL_D_BITS       11

`define TL_REQ_A_GET    17'b11111111_00_0_101_100
`define TL_REQ_A_PUTF   17'b11111111_00_0_101_000
`define TL_REQ_A_PUTP   17'b11111111_00_0_101_001

//-----------Bellek---------------
`define ADRES_BIT           32
`define BELLEK_BASLANGIC    32'h4000_0000
`define BELLEK_BOYUT        32'h0004_0000

//-----------Adres Aralýklarý-----------
`define UART_BASE_ADDR      32'h2000_0000
`define UART_MASK_ADDR      32'h0000_000f
`define SPI_BASE_ADDR       32'h2001_0000
`define SPI_MASK_ADDR       32'h0000_00ff
`define RAM_BASE_ADDR       32'h4000_0000
`define RAM_BASE            32'h4000_0000
`define RAM_MASK_ADDR       32'h0007_ffff
`define TIMER_BASE_ADDR     32'h3000_0000
`define TIMER_MASK_ADDR     32'h0000_000f
`define PWM_BASE_ADDR       32'h2002_0000
`define PWM_MASK_ADDR       32'h0000_00ff

//-------Önbellek Denetleyiciler----------
`define L1_BLOK_BIT 32    
`define L1B_SATIR   256
`define L1B_YOL     2  
`define L1V_SATIR   256
`define L1V_YOL     2
`define L1_BOYUT    (`L1_BLOK_BIT * `L1B_SATIR * `L1B_YOL) + (`L1_BLOK_BIT * `L1V_SATIR * `L1V_YOL) // Teknofest 2022-2023 icin 4KB olmali
`define L1_ONBELLEK_GECIKME 1 // Denetleyici gecikmesi degil, SRAM/BRAM gecikmesi

`define ADRES_OZEL_DAGITIM
`define ADRES_BUYRUK_OZEL_BIT 0
`define ADRES_VERI_OZEL_BIT   0
`define ADRES_BYTE_BIT      2 // Veriyi byte adreslemek icin gereken bit
`define ADRES_BYTE_OFFSET   0 // ADRES_BYTE ilk bitine erismek icin gereken kaydirma
`define ADRES_SATIR_BIT     8 // Satirlari indexlemek icin gereken bit
`define ADRES_SATIR_OFFSET  (`ADRES_BYTE_OFFSET + `ADRES_BYTE_BIT) // ADRES_SATIR ilk bitine erismek icin gereken kaydirma
`define ADRES_ETIKET_BIT    (`ADRES_BIT - `ADRES_SATIR_BIT - `ADRES_BYTE_BIT) // Adresin kalan kismi
`define ADRES_ETIKET_OFFSET (`ADRES_SATIR_OFFSET + `ADRES_SATIR_BIT) // Adresin kalan kismi

`define L1_BLOK_BYTE (`L1_BLOK_BIT / 8)

// ----Yardýmcý Tanýmlamalar----
`define ALL_ONES_256        256'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF
`define ALL_ONES_128        128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF
`define ALL_ONES_64          64'hFFFF_FFFF_FFFF_FFFF
`define ALL_ONES_32          32'hFFFF_FFFF

// ----Maskeleme Ýçin Yardýmcý Tanýmlar----
`define NOP_MASKE           4'b0000  // Böyle mi olmalý ?

`define BYTE_MAKSE_0        4'b0001
`define BYTE_MAKSE_1        4'b0010
`define BYTE_MAKSE_2        4'b0100
`define BYTE_MAKSE_3        4'b1000

`define HALF_WORD_MASKE_0   4'b0011
`define HALF_WORD_MASKE_1   4'b0110  // Bu eriþimi yapabildiðiniz varsaydýk
`define HALF_WORD_MASKE_2   4'b1100

`define WORD_MASKE          4'b1111

// ----UART Denetleyici Tanimlamalar----
`define UART_CTRL_REG        8'h00
`define UART_STATUS_REG      8'h04
`define UART_RDATA_REG       8'h08
`define UART_WDATA_REG       8'h0c
`define UART_TXN_SIZE        8


//----Dallanma Öngörücü Tanimlamalar----
`define BTB_SATIR_SAYISI         32
`define BTB_PS_BIT               5
`define BTB_SATIR_BOYUT          (`PS_BIT - `BTB_PS_BIT) + 1 + `PS_BIT
`define BHT_SATIR_SAYISI         32
`define BHT_PS_BIT               5
`define DALLANMA_TAHMIN_BIT      2 // ilerde çift kutuplu yapýlabilir
`define BHT_SATIR_BOYUT          (`PS_BIT - `BHT_PS_BIT) + `DALLANMA_TAHMIN_BIT
`define GENEL_GECMIS_YAZMACI_BIT 5
`define BTB_VALID_BITI           `BTB_SATIR_BOYUT-1 // en anlamlý biti
`define GGY_SAYAC_BIT            3



// Buyruk Bilgisi
`define VALID_BIT       1
`define VALID_PTR       0
`define VALID           0

`define RVC_BIT         1
`define RVC_PTR         `VALID_PTR + `VALID_BIT
`define RVC             `RVC_PTR +: `RVC_BIT

`define PC_BIT          32
`define PC_PTR          `RVC_PTR + `RVC_BIT
`define PC              `PC_PTR +: `PC_BIT

`define TAG_BIT         4
`define TAG_PTR         `PC_PTR + `PC_BIT
`define TAG             `TAG_PTR +: `TAG_BIT

// RD yazmac adresi
`define RD_ADDR_BIT     5
`define RD_ADDR_PTR     `TAG_PTR + `TAG_BIT
`define RD_ADDR         `RD_ADDR_PTR +: `RD_ADDR_BIT

// RD'ye yazma yapilacagini belirten flag
`define RD_ALLOC_BIT    1
`define RD_ALLOC_PTR    `RD_ADDR_PTR + `RD_ADDR_BIT
`define RD_ALLOC        `RD_ALLOC_PTR +: `RD_ALLOC_BIT

// RS2'den okuma yapilacagini belirten flag
`define RS2_EN_BIT      1
`define RS2_EN_PTR      (`RD_ALLOC_PTR + `RD_ALLOC_BIT)
`define RS2_EN          `RS2_EN_PTR +: `RS2_EN_BIT

// RS1'den okuma yapilacagini belirten flag
`define RS1_EN_BIT      1
`define RS1_EN_PTR      (`RS2_EN_PTR + `RS2_EN_BIT)
`define RS1_EN          `RS1_EN_PTR +: `RS1_EN_BIT

// Islecler (Simdilik 4 tane lazim sanirim? Islec iletmek gerekirse genisletilebilir)
`define RD_BIT          32
`define RD_PTR          (`RS1_EN_PTR + `RS1_EN_BIT)
`define RD              `RD_PTR +: `RD_BIT

`define IMM_BIT         32
`define IMM_PTR         (`RD_PTR + `RD_BIT)
`define IMM             `IMM_PTR +: `IMM_BIT

`define RS2_BIT         32
`define RS2_PTR         (`IMM_PTR + `IMM_BIT)
`define RS2             `RS2_PTR +: `RS2_BIT

`define RS1_BIT         32
`define RS1_PTR         (`RS2_PTR + `RS2_BIT)
`define RS1             `RS1_PTR +: `RS1_BIT 

`define CSR_BIT         32
`define CSR_PTR         (`RS1_PTR + `RS1_BIT)
`define CSR             `CSR_PTR +: `CSR_BIT

`define CSR_ADDR_BIT    12
`define CSR_ADDR_PTR    (`CSR_PTR + `CSR_BIT)
`define CSR_ADDR        `CSR_ADDR_PTR +: `CSR_ADDR_BIT

`define CSR_ALLOC_BIT   1
`define CSR_ALLOC_PTR   (`CSR_ADDR_PTR + `CSR_ADDR_BIT)
`define CSR_ALLOC       `CSR_ALLOC_PTR +: `CSR_ALLOC_BIT

`define CSR_EN_BIT      1
`define CSR_EN_PTR      (`CSR_ALLOC_PTR + `CSR_ALLOC_BIT)
`define CSR_EN          `CSR_EN_PTR +: `CSR_EN_BIT

// Aritmetik Mantik Birimi
`define AMB_NOP         0
`define AMB_ADD         1
`define AMB_SUB         2
`define AMB_DIV         3
`define AMB_MUL         4
`define AMB_AND         5
`define AMB_OR          6
`define AMB_XOR         7
`define AMB_SLL         8
`define AMB_SRL         9
`define AMB_SRA         10
`define AMB_SLT         11
`define AMB_SLTU        12
`define AMB_HMDST       13
`define AMB_PKG         14
`define AMB_RVRS        15
`define AMB_SLADD       16
`define AMB_CNTZ        17
`define AMB_CNTP        18
`define AMB_MULH        19
`define AMB_MULHSU      20
`define AMB_MULHU       21
`define AMB_DIVU        22
`define AMB_REM         23
`define AMB_REMU        24

`define AMB_OP_NOP      0
`define AMB_OP_RS1      1
`define AMB_OP_RS2      2
`define AMB_OP_IMM      3
`define AMB_OP_CSR      4
`define AMB_OP_PC       5

`define AMB_OP_BIT      3

// Islecler hangi veriler olmali?
`define AMB_OP2_BIT     `AMB_OP_BIT
`define AMB_OP2_PTR     (`CSR_EN_PTR + `CSR_EN_BIT)
`define AMB_OP2         `AMB_OP2_PTR +: `AMB_OP2_BIT

`define AMB_OP1_BIT     `AMB_OP_BIT
`define AMB_OP1_PTR     (`AMB_OP2_PTR + `AMB_OP2_BIT)
`define AMB_OP1         `AMB_OP1_PTR +: `AMB_OP1_BIT

`define AMB_BIT         5
`define AMB_PTR         (`AMB_OP1_PTR + `AMB_OP1_BIT)
`define AMB             `AMB_PTR +: `AMB_BIT

// Yazilacak veri secimi
`define YAZ_NOP         0
`define YAZ_AMB         1
`define YAZ_IS1         2
`define YAZ_DAL         3
`define YAZ_CSR         4
`define YAZ_BEL         5
`define YAZ_YZB         6

`define YAZ_BIT         3
`define YAZ_PTR         (`AMB_PTR + `AMB_BIT)
`define YAZ             `YAZ_PTR +: `YAZ_BIT

// Dallanma Birimi
`define DAL_NOP             0
`define DAL_BEQ             1
`define DAL_BNE             2
`define DAL_BLT             3
`define DAL_JAL             4
`define DAL_JALR            5
`define DAL_BGE             6
`define DAL_BLTU            7
`define DAL_BGEU            8
`define DAL_CJAL            9
`define DAL_CJALR           10

`define DAL_BIT             4
`define DAL_PTR             (`YAZ_PTR + `YAZ_BIT)
`define DAL                 `DAL_PTR +: `DAL_BIT

`define TAKEN_BIT           1
`define TAKEN_PTR           (`DAL_PTR + `DAL_BIT)
`define TAKEN               `TAKEN_PTR +: `TAKEN_BIT

// Bellek Islemleri
`define BEL_NOP             0
`define BEL_LW              1
`define BEL_LH              2
`define BEL_LHU             3
`define BEL_LB              4
`define BEL_LBU             5
`define BEL_SW              6
`define BEL_SH              7
`define BEL_SB              8

`define BEL_BIT             4   //seçim için kullanýlacak
`define BEL_PTR             (`TAKEN_PTR + `TAKEN_BIT)
`define BEL                 `BEL_PTR +: `BEL_BIT

`define EXC_CODE_IAM            0   // Instruction Address Misaligned
`define EXC_CODE_IS             1   // Illegal Instruction
`define EXC_CODE_LAM            4   // Load Address Misaligned
`define EXC_CODE_SAM            6   // Store Address Misaligned
`define EXC_CODE_MRET           11  // Environment call from M-mode

`define EXC_CODE_BIT            5

// CSR Islemleri
`define CSR_NOP             0
`define CSR_RW              1
`define CSR_RS              2
`define CSR_RC              3
`define CSR_MRET            4

`define CSR_OP_BIT          4 // CSR_OP berbat bir isim, AMB_OP1'deki OPerand ile buradaki CSR_OPeration kisaltmasi ayristirilmali
`define CSR_OP_PTR          (`BEL_PTR + `BEL_BIT)
`define CSR_OP              `CSR_OP_PTR +: `CSR_OP_BIT



//!!! TODO: HER ASAMA ICIN MIKROISLEM TANIMLARI (COZ_UOP, YURUT_UOP...) YAPILMALI, BU SAYEDE UOP YAZMACLARI KUCULTULEBILIR !!!