// =============================================================================
// Module      : control_unit
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : Main control unit. Decodes RV32I opcodes and generates all
//               datapath control signals for the single-cycle implementation.
//               Fully combinational — no latches, all outputs have defaults.
//
// RV32I Opcodes (instr[6:0]):
//   0110011 = R-type  (ADD, SUB, SLL, SRL, SRA, AND, OR, XOR, SLT, SLTU)
//   0010011 = I-type  (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
//   0000011 = Load    (LW, LH, LB, LHU, LBU)
//   0100011 = Store   (SW, SH, SB)
//   1100011 = Branch  (BEQ, BNE, BLT, BGE, BLTU, BGEU)
//   1101111 = JAL
//   1100111 = JALR
//   0110111 = LUI
//   0010111 = AUIPC
//   1110011 = SYSTEM  (ECALL, EBREAK — NOP in this implementation)
// =============================================================================

module control_unit (
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,

    output reg  [3:0]  alu_ctrl,
    output reg  [2:0]  imm_sel,
    output reg         alu_src,
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  mem_to_reg,     // 00=ALU, 01=Mem, 10=PC+4
    output reg  [1:0]  pc_src,         // 00=PC+4, 01=Branch, 10=JAL, 11=JALR
    output reg         branch,
    output reg  [2:0]  mem_size,
    output reg         lui_sel,
    output reg         auipc_sel
);

    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_ITYPE  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_SYSTEM = 7'b1110011;

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;

    always @(*) begin
        // Safe defaults (NOP)
        alu_ctrl   = ALU_ADD;
        imm_sel    = 3'b000;
        alu_src    = 1'b0;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 2'b00;
        pc_src     = 2'b00;
        branch     = 1'b0;
        mem_size   = funct3;
        lui_sel    = 1'b0;
        auipc_sel  = 1'b0;

        case (opcode)
            OP_RTYPE: begin
                reg_write  = 1'b1;
                alu_src    = 1'b0;
                mem_to_reg = 2'b00;
                case ({funct7, funct3})
                    10'b0000000_000: alu_ctrl = ALU_ADD;
                    10'b0100000_000: alu_ctrl = ALU_SUB;
                    10'b0000000_001: alu_ctrl = ALU_SLL;
                    10'b0000000_010: alu_ctrl = ALU_SLT;
                    10'b0000000_011: alu_ctrl = ALU_SLTU;
                    10'b0000000_100: alu_ctrl = ALU_XOR;
                    10'b0000000_101: alu_ctrl = ALU_SRL;
                    10'b0100000_101: alu_ctrl = ALU_SRA;
                    10'b0000000_110: alu_ctrl = ALU_OR;
                    10'b0000000_111: alu_ctrl = ALU_AND;
                    default:         alu_ctrl = ALU_ADD;
                endcase
            end

            OP_ITYPE: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                imm_sel    = 3'b000;
                mem_to_reg = 2'b00;
                case (funct3)
                    3'b000: alu_ctrl = ALU_ADD;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b110: alu_ctrl = ALU_OR;
                    3'b111: alu_ctrl = ALU_AND;
                    3'b001: alu_ctrl = ALU_SLL;
                    3'b101: alu_ctrl = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_src    = 1'b1;
                imm_sel    = 3'b000;
                alu_ctrl   = ALU_ADD;
                mem_to_reg = 2'b01;
            end

            OP_STORE: begin
                mem_write  = 1'b1;
                alu_src    = 1'b1;
                imm_sel    = 3'b001;
                alu_ctrl   = ALU_ADD;
            end

            OP_BRANCH: begin
                branch     = 1'b1;
                imm_sel    = 3'b010;
                alu_src    = 1'b0;
                pc_src     = 2'b01;
                case (funct3)
                    3'b000: alu_ctrl = ALU_SUB;     // BEQ
                    3'b001: alu_ctrl = ALU_SUB;     // BNE
                    3'b100: alu_ctrl = ALU_SLT;     // BLT
                    3'b101: alu_ctrl = ALU_SLT;     // BGE
                    3'b110: alu_ctrl = ALU_SLTU;    // BLTU
                    3'b111: alu_ctrl = ALU_SLTU;    // BGEU
                    default: alu_ctrl = ALU_SUB;
                endcase
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                imm_sel    = 3'b100;
                pc_src     = 2'b10;
                mem_to_reg = 2'b10;
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                imm_sel    = 3'b000;
                alu_ctrl   = ALU_ADD;
                pc_src     = 2'b11;
                mem_to_reg = 2'b10;
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                imm_sel    = 3'b011;
                alu_ctrl   = ALU_LUI;
                mem_to_reg = 2'b00;
                lui_sel    = 1'b1;
            end

            OP_AUIPC: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                imm_sel    = 3'b011;
                alu_ctrl   = ALU_ADD;
                mem_to_reg = 2'b00;
                auipc_sel  = 1'b1;
            end

            OP_SYSTEM: begin
                // ECALL/EBREAK — NOP; extend for CSR support in Phase 6
            end

            default: begin /* NOP */ end
        endcase
    end

endmodule
