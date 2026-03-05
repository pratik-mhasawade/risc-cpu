// =============================================================================
// Module      : imm_gen
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : Immediate value generator for all RV32I instruction formats.
//               Extracts and sign-extends the immediate field from the
//               instruction word based on the instruction format type.
//
// RV32I Instruction Formats:
//
//  R-type: [31:25]funct7 | [24:20]rs2 | [19:15]rs1 | [14:12]funct3 | [11:7]rd  | [6:0]opcode
//  I-type: [31:20]imm[11:0]            | [19:15]rs1 | [14:12]funct3 | [11:7]rd  | [6:0]opcode
//  S-type: [31:25]imm[11:5]| [24:20]rs2| [19:15]rs1 | [14:12]funct3 |[11:7]imm[4:0]|[6:0]opcode
//  B-type: [31]imm[12]|[30:25]imm[10:5]|[24:20]rs2|[19:15]rs1|[14:12]funct3|[11:8]imm[4:1]|[7]imm[11]|[6:0]opcode
//  U-type: [31:12]imm[31:12]                                           | [11:7]rd  | [6:0]opcode
//  J-type: [31]imm[20]|[30:21]imm[10:1]|[20]imm[11]|[19:12]imm[19:12]| [11:7]rd  | [6:0]opcode
//
// imm_sel encoding:
//   3'b000 = I-type    3'b001 = S-type    3'b010 = B-type
//   3'b011 = U-type    3'b100 = J-type
// =============================================================================

module imm_gen (
    input  wire [31:0] instruction,
    input  wire [2:0]  imm_sel,         // format selector from control unit

    output reg  [31:0] imm_out          // sign-extended immediate
);

    always @(*) begin
        case (imm_sel)
            // ------------------------------------------------------------------
            // I-type: sign-extend instr[31:20]
            // Used by: ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI,
            //          LW, LH, LB, LHU, LBU, JALR
            // ------------------------------------------------------------------
            3'b000: imm_out = {{20{instruction[31]}}, instruction[31:20]};

            // ------------------------------------------------------------------
            // S-type: sign-extend {instr[31:25], instr[11:7]}
            // Used by: SW, SH, SB
            // ------------------------------------------------------------------
            3'b001: imm_out = {{20{instruction[31]}},
                               instruction[31:25],
                               instruction[11:7]};

            // ------------------------------------------------------------------
            // B-type: sign-extend branch offset (multiple scattered bits)
            // Used by: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // Note: result is byte offset, bit[0] always 0
            // ------------------------------------------------------------------
            3'b010: imm_out = {{19{instruction[31]}},
                               instruction[31],
                               instruction[7],
                               instruction[30:25],
                               instruction[11:8],
                               1'b0};

            // ------------------------------------------------------------------
            // U-type: {instr[31:12], 12'b0}
            // Used by: LUI, AUIPC
            // ------------------------------------------------------------------
            3'b011: imm_out = {instruction[31:12], 12'b0};

            // ------------------------------------------------------------------
            // J-type: sign-extend jump offset
            // Used by: JAL
            // Note: result is byte offset, bit[0] always 0
            // ------------------------------------------------------------------
            3'b100: imm_out = {{11{instruction[31]}},
                               instruction[31],
                               instruction[19:12],
                               instruction[20],
                               instruction[30:21],
                               1'b0};

            default: imm_out = 32'd0;
        endcase
    end

endmodule
