`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.05.2024 13:40:35
// Design Name: 
// Module Name: coz_yazmac_oku
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "riscv_controller.vh"

module coz_yazmac_oku(
     input clk_i,
    input rst_i,
    input [31:0] inst_i, //32 bit instruction
    input [31:0] pc_i, //PC value from previous stage
    output reg[31:0] pc_o, //PC value
    output wire[4:0] rs1_addr_o,//address for register source 1
    output reg[4:0] rs1_addr_q_o,//registered address for register source 1
    output wire[4:0] rs2_addr_o, //address for register source 2
    output reg[4:0] rs2_addr_q_o, //registered address for register source 2
    output reg[4:0] rd_addr_o, //address for destination address
    
    input wire [31:0] rd_value_i,     // Rd'nin degeri
    input wire        rd_yazmac_i,           // Rd'ye sonuc yazilacak mi
    
    output reg[31:0] imm_o, //extended value for immediate
    output reg[`MIKROISLEM_WIDTH-1:0] mikro_islem_o, 
    output reg[`OPCODE_WIDTH-1:0] opcode_o, //opcode type
    output reg[`EXCEPTION_WIDTH-1:0] exception_o, //exceptions: illegal inst, ecall, ebreak, mret
    
    input wire clk_en_i, // input clk enable for pipeline stalling of this stage
    output reg clk_en_o, // output clk enable for pipeline stalling of next stage
    input wire stall_i, 
    output reg stall_o, 
    input wire flush_i, 
    output reg flush_o 
    );
    
    assign rs2_addr_o = inst_i[24:20]; 
    assign rs1_addr_o = inst_i[19:15];   
    
    wire[2:0] funct3 = inst_i[14:12];
    wire[2:0] funct7=  inst_i[25];
    wire[6:0] opcode = inst_i[6:2];
    
    reg [14:0] BIRIM_AMB;
    reg [14:0] BIRIM_BIB;
    reg [14:0] BIRIM_DALLANMA;
    reg [14:0] BIRIM_CARPMA;
    reg [14:0] BIRIM_BOLME;
    reg [14:0] BIRIM_FPU;
    reg [14:0] BIRIM_ATOMIC;
    reg [14:0] BIRIM_SYSTEM;
    
    reg amb_en;
    reg carpma_en;
    reg bolme_en;
    reg fpu_en;
    reg atomic_en;
    
    reg[31:0] imm;

    reg system_noncsr = 0;
    reg valid_opcode = 0;
    reg illegal_shift = 0;
    wire stall_bit = stall_o || stall_i; 
    
    wire [31:0] rs1_deger; // okunan 1. yazmac
    wire [31:0] rs2_deger; // okunan 2. yazmac
    
    assign {regwrite,op,regdst, branch, memwrite, memtoreg, jump} = controls;
  
                           
    always @(posedge clk_i) begin
        if(!rst_i) begin
            clk_en_o <= 0;
        end
        else begin
            if(clk_en_i && !stall_bit) begin 
                pc_o       <= pc_i;
                rs1_addr_q_o <= rs1_addr_o;
                rs2_addr_q_o <= rs2_addr_o;
                rd_addr_o  <= inst_i[11:7];
                imm_o      <= imm;
            end
            else if(flush_i && !stall_bit) begin 
                clk_en_o <= 0;
            end
            else if(!stall_bit) begin 
                clk_en_o <= clk_en_i;
            end
            else if(stall_bit && !stall_i) clk_en_o <= 0; 
                                                                    
        end
    end
    
    always @* begin
        opcode_o[`RTYPE]  = opcode == `OPCODE_RTYPE && funct7==1'b0;
        opcode_o[`MUL]    = opcode == `OPCODE_RTYPE && funct7==1'b1;
        opcode_o[`ITYPE]  = opcode == `OPCODE_ITYPE;
        opcode_o[`LOAD]   = opcode == `OPCODE_LOAD;
        opcode_o[`STORE]  = opcode == `OPCODE_STORE;
        opcode_o[`BRANCH] = opcode == `OPCODE_BRANCH;
        opcode_o[`JAL]    = opcode == `OPCODE_JAL;
        opcode_o[`JALR]   = opcode == `OPCODE_JALR;
        opcode_o[`LUI]    = opcode == `OPCODE_LUI;
        opcode_o[`AUIPC]  = opcode == `OPCODE_AUIPC;
        opcode_o[`SYSTEM] = opcode == `OPCODE_SYSTEM;
        opcode_o[`ATOMIC] = opcode == `OPCODE_ATOMIC;
        opcode_o[`FPU]    = opcode == `OPCODE_FPU;
        opcode_o[`FPU_LW] = opcode == `OPCODE_FPU_LW;
        opcode_o[`FPU_SW] = opcode == `OPCODE_FPU_SW;
        opcode_o[`FPU_FMADD] = opcode == `OPCODE_FPU_FMADD;
        opcode_o[`FPU_FMSUB] = opcode == `OPCODE_FPU_FMSUB;
        opcode_o[`FPU_FNMADD] = opcode == `OPCODE_FPU_FNMADD;
        opcode_o[`FPU_FNMSUB] = opcode == `OPCODE_FPU_FNMSUB;
        //opcode_fence  = opcode == `OPCODE_FENCE;
        
        system_noncsr = opcode == `OPCODE_SYSTEM && funct3 == 0 ; //system instruction but not CSR operation
        valid_opcode = (opcode_o[`RTYPE] ||  opcode_o[`MUL]  ||  opcode_o[`ITYPE] ||  opcode_o[`LOAD] ||  opcode_o[`STORE] ||  opcode_o[`BRANCH] ||  opcode_o[`JAL] ||  opcode_o[`JALR] ||  opcode_o[`LUI] ||  opcode_o[`AUIPC] || 
                        opcode_o[`SYSTEM] ||  opcode_o[`ATOMIC] ||  opcode_o[`FPU]||  opcode_o[`FPU_LW]||  opcode_o[`FPU_SW]||  opcode_o[`FPU_FMADD]||  opcode_o[`FPU_FMSUB] ||  opcode_o[`FPU_FNMADD]||  opcode_o[`FPU_FNMSUB] );
        illegal_shift = (opcode_o[`ITYPE] && (BIRIM_AMB[`ALU_SLL] || BIRIM_AMB[`ALU_SRL] || BIRIM_AMB[`ALU_SRA])) && inst_i[25];
       
        exception_o[`ILLEGAL] = !valid_opcode || illegal_shift;
        exception_o[`ECALL] = (system_noncsr && inst_i[21:20]==2'b00)? 1:0;
        exception_o[`EBREAK] = (system_noncsr && inst_i[21:20]==2'b01)? 1:0;              
        exception_o[`MRET] = (system_noncsr && inst_i[21:20]==2'b10)? 1:0;
        
         case(opcode)
        `OPCODE_ITYPE , `OPCODE_LOAD , `OPCODE_JALR: imm = {{20{inst_i[31]}},inst_i[31:20]}; 
                                      `OPCODE_STORE: imm = {{20{inst_i[31]}},inst_i[31:25],inst_i[11:7]};
                                     `OPCODE_BRANCH: imm = {{19{inst_i[31]}},inst_i[31],inst_i[7],inst_i[30:25],inst_i[11:8],1'b0};
                                        `OPCODE_JAL: imm = {{11{inst_i[31]}},inst_i[31],inst_i[19:12],inst_i[20],inst_i[30:21],1'b0};
                        `OPCODE_LUI , `OPCODE_AUIPC: imm = {inst_i[31:12],12'h000};
                     `OPCODE_SYSTEM , `OPCODE_FENCE: imm = {20'b0,inst_i[31:20]};   
                     default: imm = 0;
        endcase
    end
    
     always @* begin
        stall_o = stall_i; 
        flush_o = flush_i; 
      
        if(opcode_o[`RTYPE] || opcode_o[`ITYPE]) begin
            if(opcode_o[`RTYPE]) begin
                BIRIM_AMB[`ALU_TOPLAMA] = (funct3 == `FUNCT3_ADD) ? !inst_i[30] : 0; //add and sub has same o_funct3 code
                BIRIM_AMB[`ALU_CIKARMA] = funct3 == `FUNCT3_ADD ? inst_i[30] : 0;      //differs on i_inst[30]
            end
            else BIRIM_AMB[`ALU_TOPLAMA] = funct3 == `FUNCT3_ADD;
            BIRIM_AMB[`ALU_SLT] = funct3 == `FUNCT3_SLT;
            BIRIM_AMB[`ALU_SLTU] = funct3 == `FUNCT3_SLTU;
            BIRIM_AMB[`ALU_XOR] = funct3 == `FUNCT3_XOR;
            BIRIM_AMB[`ALU_OR] = funct3 == `FUNCT3_OR;
            BIRIM_AMB[`ALU_AND] = funct3 == `FUNCT3_AND;
            BIRIM_AMB[`ALU_SLL] = funct3 == `FUNCT3_SLL;
            BIRIM_AMB[`ALU_SRL] = funct3 == `FUNCT3_SRA ? !inst_i[30]:0; //srl and sra has same o_funct3 code
            BIRIM_AMB[`ALU_SRA] = funct3 == `FUNCT3_SRA ? inst_i[30]:0 ;      //differs on i_inst[30]
        end
        else if(opcode_o[`LOAD] || opcode_o[`STORE]) begin
            if(opcode_o[`LOAD]) begin
                BIRIM_BIB[`LB] = funct3 == `LB;
                BIRIM_BIB[`LH] = funct3 == `LH;
                BIRIM_BIB[`LW] = funct3 == `LW;
                BIRIM_BIB[`LBU] = funct3 == `LBU;
                BIRIM_BIB[`LHU] = funct3 == `LHU;
            end
            else 
               BIRIM_BIB[`SB] = funct3 == `SB;
               BIRIM_BIB[`SH] = funct3 == `SH;
               BIRIM_BIB[`SW] = funct3 == `SW;
        end

        else if(opcode_o[`BRANCH] || opcode_o[`JAL]||opcode_o[`JALR]) begin
           if(opcode_o[`JAL]) begin
                BIRIM_DALLANMA[`JAL] = 1;
            end
           else if(opcode_o[`JALR]) begin
                BIRIM_DALLANMA[`JALR] =1 ;
           end
           else
           BIRIM_DALLANMA[`DAL_EQ] = funct3 == `FUNCT3_EQ;
           BIRIM_DALLANMA[`DAL_NE] = funct3 == `FUNCT3_NEQ;    
           BIRIM_DALLANMA[`DAL_LT] = funct3 == `FUNCT3_LT;
           BIRIM_DALLANMA[`DAL_GE] = funct3 == `FUNCT3_GE;
           BIRIM_DALLANMA[`DAL_LTU] = funct3 == `FUNCT3_LTU;
           BIRIM_DALLANMA[`DAL_GEU]= funct3 == `FUNCT3_GEU;
        end
        else if(opcode_o[`MUL]) begin
            BIRIM_CARPMA[`MUL] = funct3 == `MUL;
            BIRIM_CARPMA[`MULH] = funct3 == `MULH;
            BIRIM_CARPMA[`MULHSU] = funct3 == `MULHSU;
            BIRIM_CARPMA[`MULHU] = funct3 == `MULHU;
            BIRIM_BOLME[`DIV] = funct3 == `DIV;
            BIRIM_BOLME[`DIVU] = funct3 == `DIVU;
            BIRIM_BOLME[`REM] = funct3 == `REM;
            BIRIM_BOLME[`REMU] = funct3 == `REMU; 
        end
        else if(opcode_o[`ATOMIC]) begin
            BIRIM_ATOMIC[`LR_W] = inst_i[31:27] == `LR_W;
            BIRIM_ATOMIC[`SC_W] = inst_i[31:27] == `SC_W;
            BIRIM_ATOMIC[`AMOSWAP_W] = inst_i[31:27] == `AMOSWAP_W;
            BIRIM_ATOMIC[`AMOADD_W] = inst_i[31:27] == `AMOADD_W;
            BIRIM_ATOMIC[`AMOXOR_W] = inst_i[31:27] == `AMOXOR_W;
            BIRIM_ATOMIC[`AMOAND_W] = inst_i[31:27] == `AMOAND_W;
            BIRIM_ATOMIC[`AMOOR_W] = inst_i[31:27] == `AMOOR_W;
            BIRIM_ATOMIC[`AMOMIN_W] = inst_i[31:27] == `AMOMIN_W;
            BIRIM_ATOMIC[`AMOMAX_W] = inst_i[31:27] == `AMOMAX_W;
            BIRIM_ATOMIC[`AMOMINU_W] = inst_i[31:27] == `AMOMINU_W;
            BIRIM_ATOMIC[`AMOMAXU_W] = inst_i[31:27] == `AMOMAXU_W;
        end

        else if(opcode_o[`FPU]||opcode_o[`FPU_LW]|| opcode_o[`FPU_SW]|| opcode_o[`FPU_FMADD]|| opcode_o[`FPU_FMSUB] || opcode_o[`FPU_FNMADD]|| opcode_o[`FPU_FNMSUB]) begin
           BIRIM_FPU[`FPULW] = opcode_o[`FPU_LW]? 1 : 0 ;
           BIRIM_FPU[`FPUSW] = opcode_o[`FPU_SW]? 1 : 0 ;
           BIRIM_FPU[`FPUFMADD] = opcode_o[`FPU_FMADD]? 1 : 0 ;
           BIRIM_FPU[`FPUFMSUB] = opcode_o[`FPU_FMSUB]? 1 : 0 ;
           BIRIM_FPU[`FPUFNMADD] = opcode_o[`FPU_FNMADD]? 1 : 0 ;
           BIRIM_FPU[`FPUFNMSUB] = opcode_o[`FPU_FNMSUB]? 1 : 0 ;
           BIRIM_FPU[`FPUADD] = inst_i[31:25]== `COZ_FPUADD;
           BIRIM_FPU[`FPUSUB] = inst_i[31:25]== `COZ_FPUSUB;    
           BIRIM_FPU[`FPUMUL] = inst_i[31:25]== `COZ_FPUMUL;
           BIRIM_FPU[`FPUDIV] = inst_i[31:25]== `COZ_FPUDIV;
           BIRIM_FPU[`FPUSQRT] = inst_i[31:25]== `COZ_FPUSQRT;
           BIRIM_FPU[`FPUSGNJ] = (inst_i[31:25]== `COZ_FPUSGNJ) && (funct3==3'b000);    
           BIRIM_FPU[`FPUSGNJN] = (inst_i[31:25]== `COZ_FPUSGNJ) && (funct3==3'b001) ;
           BIRIM_FPU[`FPUSGNJX] = (inst_i[31:25]== `COZ_FPUSGNJ) && (funct3==3'b010) ;
           BIRIM_FPU[`FPUMIN] = (inst_i[31:25]== `COZ_FPUMIN) && (funct3==3'b000);
           BIRIM_FPU[`FPUMAX] = (inst_i[31:25]== `COZ_FPUMIN) && (funct3==3'b001);    
           BIRIM_FPU[`FPUCVTW] = (inst_i[31:25]== `COZ_FPUCVTW) && (inst_i[20]==1'b0);
           BIRIM_FPU[`FPUCVTWU] = (inst_i[31:25]== `COZ_FPUCVTW) && (inst_i[20]==1'b1);
           BIRIM_FPU[`FPUMVXW] = (inst_i[31:25]== `COZ_FPUMVXW) && (inst_i[12]==1'b0);
           BIRIM_FPU[`FPUCLASS] = (inst_i[31:25]== `COZ_FPUMVXW) && (inst_i[12]==1'b1);
           BIRIM_FPU[`FPUEQ] = (inst_i[31:25]== `COZ_FPUEQ) && (funct3==3'b010);
           BIRIM_FPU[`FPULT] = (inst_i[31:25]== `COZ_FPUEQ) && (funct3==3'b001);
           BIRIM_FPU[`FPULE] = (inst_i[31:25]== `COZ_FPUEQ) && (funct3==3'b000);
           BIRIM_FPU[`FPUCVTSW] = (inst_i[31:25]== `COZ_FPUCVTSW) && (inst_i[20]==1'b0);
           BIRIM_FPU[`FPUCVTSWU] = (inst_i[31:25]== `COZ_FPUCVTSW) && (inst_i[20]==1'b1);
           BIRIM_FPU[`FPUMVWX] = inst_i[31:25]== `COZ_FPUMVWX;
        end
        else if(opcode_o[`SYSTEM] ) begin
            BIRIM_SYSTEM[`CSRRW] = funct3 == 3'b001;
            BIRIM_SYSTEM[`CSRRS] = funct3 == 3'b010;
            BIRIM_SYSTEM[`CSRRC] = funct3 == 3'b011;
            BIRIM_SYSTEM[`CSRRWI] = funct3 == 3'b101;
            BIRIM_SYSTEM[`CSRRSI] = funct3 == 3'b110;
            BIRIM_SYSTEM[`CSRRCI] = funct3 == 3'b111;
        end
        else BIRIM_AMB[`ALU_TOPLAMA] = 1'b1; //add operation for all remaining instructions
    end
    
    yazmac_obegi yo(
      .clk_i        (clk_i),
      .rst_i        (rst_i),
      .oku_adres1_i   (inst_i[19:15]),
      .oku_adres2_i   (inst_i[24:20]),
      .oku_veri1_o (rs1_deger),
      .oku_veri2_o (rs2_deger),
      .yaz_adres_i    (rd_address_o),
      .yaz_veri_i  (rd_value_i),
      .yaz_gecerli_i   (rd_yazmac_i)
   );

endmodule
