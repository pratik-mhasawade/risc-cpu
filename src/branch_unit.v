// =============================================================================
// Module      : branch_unit
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : Evaluates all RV32I branch conditions using ALU flags.
//               Generates branch_taken signal used to gate the PC mux.
//
// Branch conditions (funct3):
//   000 = BEQ  : branch if rs1 == rs2   (zero == 1)
//   001 = BNE  : branch if rs1 != rs2   (zero == 0)
//   100 = BLT  : branch if rs1 <  rs2   (signed,   SLT result == 1)
//   101 = BGE  : branch if rs1 >= rs2   (signed,   SLT result == 0)
//   110 = BLTU : branch if rs1 <  rs2   (unsigned, SLTU result == 1)
//   111 = BGEU : branch if rs1 >= rs2   (unsigned, SLTU result == 0)
// =============================================================================

module branch_unit (
    input  wire [2:0]  funct3,          // branch type from instruction
    input  wire        zero,            // ALU zero flag
    input  wire        alu_result_lsb,  // ALU result[0] (SLT/SLTU output)
    input  wire        branch,          // branch instruction indicator

    output reg         branch_taken     // 1 = branch should be taken
);

    always @(*) begin
        branch_taken = 1'b0;
        if (branch) begin
            case (funct3)
                3'b000: branch_taken =  zero;              // BEQ
                3'b001: branch_taken = ~zero;              // BNE
                3'b100: branch_taken =  alu_result_lsb;   // BLT  (SLT)
                3'b101: branch_taken = ~alu_result_lsb;   // BGE  (~SLT)
                3'b110: branch_taken =  alu_result_lsb;   // BLTU (SLTU)
                3'b111: branch_taken = ~alu_result_lsb;   // BGEU (~SLTU)
                default: branch_taken = 1'b0;
            endcase
        end
    end

endmodule
