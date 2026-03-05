// =============================================================================
// Module      : alu
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : 32-bit Arithmetic Logic Unit
//               Supports all RV32I ALU operations, driven by alu_ctrl
//               from the decode/control stage.
//
// ALU Control Encoding (4-bit):
//   0000 = ADD        0001 = SUB
//   0010 = AND        0011 = OR
//   0100 = XOR        0101 = SLL  (shift left logical)
//   0110 = SRL  (shift right logical)
//   0111 = SRA  (shift right arithmetic)
//   1000 = SLT  (set less than, signed)
//   1001 = SLTU (set less than, unsigned)
//   1010 = LUI passthrough (operand b passed directly)
//
// Outputs:
//   result     : 32-bit computation result
//   zero       : 1 if result == 0 (used by branch logic)
//   negative   : result[31] (sign bit, used by BLT/BGE)
//   overflow   : signed overflow flag (ADD/SUB)
// =============================================================================

module alu (
    input  wire [31:0] operand_a,       // rs1 data or PC
    input  wire [31:0] operand_b,       // rs2 data or immediate
    input  wire [3:0]  alu_ctrl,        // operation select

    output reg  [31:0] result,          // computation result
    output wire        zero,            // result == 0
    output wire        negative,        // result[31]
    output wire        overflow         // signed overflow (ADD/SUB only)
);

    // -------------------------------------------------------------------------
    // Intermediate signals
    // -------------------------------------------------------------------------
    wire [31:0] add_result  = operand_a + operand_b;
    wire [31:0] sub_result  = operand_a - operand_b;
    wire [4:0]  shamt       = operand_b[4:0];   // shift amount (lower 5 bits)

    // -------------------------------------------------------------------------
    // ALU Operation
    // -------------------------------------------------------------------------
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = add_result;                           // ADD
            4'b0001: result = sub_result;                           // SUB
            4'b0010: result = operand_a & operand_b;                // AND
            4'b0011: result = operand_a | operand_b;                // OR
            4'b0100: result = operand_a ^ operand_b;                // XOR
            4'b0101: result = operand_a << shamt;                   // SLL
            4'b0110: result = operand_a >> shamt;                   // SRL
            4'b0111: result = $signed(operand_a) >>> shamt;         // SRA
            4'b1000: result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0; // SLT
            4'b1001: result = (operand_a < operand_b)               ? 32'd1 : 32'd0;     // SLTU
            4'b1010: result = operand_b;                            // LUI passthrough
            default: result = 32'd0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Flag outputs
    // -------------------------------------------------------------------------
    assign zero     = (result == 32'd0);
    assign negative = result[31];

    // Overflow: same sign inputs, different sign output
    assign overflow = (alu_ctrl == 4'b0000) ?
                        (~operand_a[31] & ~operand_b[31] &  result[31]) |
                        ( operand_a[31] &  operand_b[31] & ~result[31]) :
                      (alu_ctrl == 4'b0001) ?
                        (~operand_a[31] &  operand_b[31] &  result[31]) |
                        ( operand_a[31] & ~operand_b[31] & ~result[31]) :
                        1'b0;

endmodule
