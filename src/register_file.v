// =============================================================================
// Module      : register_file
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : 32 x 32-bit general-purpose register file
//               - R0 (x0) is hardwired to zero (reads always return 0,
//                 writes are silently discarded) — RV32I spec §2.1
//               - Dual asynchronous read ports (rs1, rs2)
//               - Single synchronous write port (rd), write on posedge clk
//               - Synchronous reset clears all registers to 0
// =============================================================================

module register_file (
    input  wire        clk,
    input  wire        reset,

    // Read ports (asynchronous — combinational)
    input  wire [4:0]  rs1_addr,        // source register 1 address
    input  wire [4:0]  rs2_addr,        // source register 2 address
    output wire [31:0] rs1_data,        // source register 1 data
    output wire [31:0] rs2_data,        // source register 2 data

    // Write port (synchronous)
    input  wire [4:0]  rd_addr,         // destination register address
    input  wire [31:0] rd_data,         // data to write
    input  wire        rd_write_en      // write enable
);

    // -------------------------------------------------------------------------
    // Register Array — 32 registers × 32 bits
    // -------------------------------------------------------------------------
    reg [31:0] regs [1:31];     // regs[0] omitted — always zero

    // -------------------------------------------------------------------------
    // Synchronous Write (with reset)
    // -------------------------------------------------------------------------
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 1; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (rd_write_en && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end

    // -------------------------------------------------------------------------
    // Asynchronous Read — x0 always returns 0
    // -------------------------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

endmodule
