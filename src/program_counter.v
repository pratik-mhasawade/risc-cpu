// =============================================================================
// Module      : program_counter
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : 32-bit program counter with synchronous reset.
//               PC always increments by 4 (word-aligned).
//               On branch/jump, next_pc is loaded from the PC mux in top.
//
//   pc_next sources (selected in top.v):
//     00 = PC + 4       (sequential)
//     01 = Branch target (PC + B-imm, only if branch_taken)
//     10 = JAL target   (PC + J-imm)
//     11 = JALR target  (rs1 + I-imm, bit[0] cleared per spec)
// =============================================================================

module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] pc_next,         // next PC value (from mux in top)
    output reg  [31:0] pc              // current PC
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 32'h0000_0000;        // reset vector — address 0
        else
            pc <= pc_next;
    end

endmodule
