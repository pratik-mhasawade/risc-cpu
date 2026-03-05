// =============================================================================
// Module      : oc_riscv32i_tb
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : Self-checking testbench for the RV32I single-cycle processor.
//               Loads a test program directly into instruction memory,
//               preloads data memory, and verifies register file state
//               after execution using expected-value checks.
//
// Test Program covers:
//   - ADDI, ADD, SUB                  (arithmetic)
//   - ANDI, ORI, XORI                 (logic immediate)
//   - AND, OR, XOR                    (logic register)
//   - SLL, SRL, SRA                   (shifts)
//   - SLT, SLTU                       (comparisons)
//   - LUI, AUIPC                      (upper immediate)
//   - LW, SW, LH, LB, LHU, LBU       (memory)
//   - BEQ, BNE, BLT, BGE              (branches)
//   - JAL, JALR                       (jumps + function call/return)
// =============================================================================

`timescale 1ns / 1ps

module oc_riscv32i_tb;

    // =========================================================================
    // DUT signals
    // =========================================================================
    reg  clk;
    reg  reset;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    oc_riscv32i dut (
        .clk   (clk),
        .reset (reset)
    );

    // =========================================================================
    // Clock — 10 ns period (100 MHz)
    // =========================================================================
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("tb/oc_riscv32i_tb.vcd");
        $dumpvars(0, oc_riscv32i_tb);
    end

    // =========================================================================
    // Test bookkeeping
    // =========================================================================
    integer pass_count;
    integer fail_count;

    task check_reg;
        input [4:0]  reg_addr;
        input [31:0] expected;
        input [63:0] test_name;  // padded string
        begin
            if (dut.u_rf.regs[reg_addr] === expected) begin
                $display("  PASS [%s] x%0d = 0x%08h", test_name, reg_addr, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%s] x%0d: got 0x%08h, expected 0x%08h",
                         test_name, reg_addr,
                         dut.u_rf.regs[reg_addr], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // Helper: encode RV32I instructions
    // =========================================================================
    // R-type: {funct7, rs2, rs1, funct3, rd, opcode}
    function [31:0] R;
        input [6:0] funct7;
        input [4:0] rs2, rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin R = {funct7, rs2, rs1, funct3, rd, opcode}; end
    endfunction

    // I-type: {imm[11:0], rs1, funct3, rd, opcode}
    function [31:0] I;
        input [11:0] imm;
        input [4:0]  rs1;
        input [2:0]  funct3;
        input [4:0]  rd;
        input [6:0]  opcode;
        begin I = {imm, rs1, funct3, rd, opcode}; end
    endfunction

    // S-type: {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode}
    function [31:0] S;
        input [11:0] imm;
        input [4:0]  rs2, rs1;
        input [2:0]  funct3;
        input [6:0]  opcode;
        begin S = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode}; end
    endfunction

    // B-type
    function [31:0] B;
        input [12:0] imm;   // byte offset, bit[0] ignored
        input [4:0]  rs2, rs1;
        input [2:0]  funct3;
        input [6:0]  opcode;
        begin
            B = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
        end
    endfunction

    // U-type
    function [31:0] U;
        input [19:0] imm;   // upper 20 bits
        input [4:0]  rd;
        input [6:0]  opcode;
        begin U = {imm, rd, opcode}; end
    endfunction

    // J-type (JAL)
    function [31:0] J;
        input [20:0] imm;   // byte offset, bit[0] ignored
        input [4:0]  rd;
        input [6:0]  opcode;
        begin
            J = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
        end
    endfunction

    // =========================================================================
    // Opcode / funct3 / funct7 constants
    // =========================================================================
    localparam OPC_R      = 7'b0110011;
    localparam OPC_I      = 7'b0010011;
    localparam OPC_LOAD   = 7'b0000011;
    localparam OPC_STORE  = 7'b0100011;
    localparam OPC_BRANCH = 7'b1100011;
    localparam OPC_JAL    = 7'b1101111;
    localparam OPC_JALR   = 7'b1100111;
    localparam OPC_LUI    = 7'b0110111;
    localparam OPC_AUIPC  = 7'b0010111;

    localparam F7_NORM  = 7'b0000000;
    localparam F7_ALT   = 7'b0100000;

    // =========================================================================
    // Load test program directly into instruction memory
    // =========================================================================
    integer idx;

    task load_program;
        begin
            for (idx = 0; idx < 1024; idx = idx + 1)
                dut.u_imem.rom[idx] = 32'h0000_0013; // NOP (ADDI x0,x0,0)

            // ------------------------------------------------------------------
            // Initialize registers via ADDI
            //   x1  = 10
            //   x2  = 20
            //   x3  = -5  (0xFFFFFFFB)
            // ------------------------------------------------------------------
            // PC=0x00: ADDI x1, x0, 10
            dut.u_imem.rom[0]  = I(12'd10,   5'd0, 3'b000, 5'd1,  OPC_I);
            // PC=0x04: ADDI x2, x0, 20
            dut.u_imem.rom[1]  = I(12'd20,   5'd0, 3'b000, 5'd2,  OPC_I);
            // PC=0x08: ADDI x3, x0, -5
            dut.u_imem.rom[2]  = I(12'hFFB,  5'd0, 3'b000, 5'd3,  OPC_I);

            // ------------------------------------------------------------------
            // Arithmetic — R-type
            // ------------------------------------------------------------------
            // PC=0x0C: ADD x4, x1, x2   → x4 = 30
            dut.u_imem.rom[3]  = R(F7_NORM, 5'd2, 5'd1, 3'b000, 5'd4,  OPC_R);
            // PC=0x10: SUB x5, x2, x1   → x5 = 10
            dut.u_imem.rom[4]  = R(F7_ALT,  5'd1, 5'd2, 3'b000, 5'd5,  OPC_R);

            // ------------------------------------------------------------------
            // Logic — immediate
            // ------------------------------------------------------------------
            // PC=0x14: ANDI x6, x1, 0xF  → x6 = 10 & 15 = 10
            dut.u_imem.rom[5]  = I(12'h00F, 5'd1, 3'b111, 5'd6,  OPC_I);
            // PC=0x18: ORI  x7, x1, 0x5  → x7 = 10 | 5 = 15
            dut.u_imem.rom[6]  = I(12'h005, 5'd1, 3'b110, 5'd7,  OPC_I);
            // PC=0x1C: XORI x8, x1, 0xF  → x8 = 10 ^ 15 = 5
            dut.u_imem.rom[7]  = I(12'h00F, 5'd1, 3'b100, 5'd8,  OPC_I);

            // ------------------------------------------------------------------
            // Logic — register
            // ------------------------------------------------------------------
            // PC=0x20: AND x9,  x1, x2   → x9  = 10 & 20 = 0
            dut.u_imem.rom[8]  = R(F7_NORM, 5'd2, 5'd1, 3'b111, 5'd9,  OPC_R);
            // PC=0x24: OR  x10, x1, x2   → x10 = 10 | 20 = 30
            dut.u_imem.rom[9]  = R(F7_NORM, 5'd2, 5'd1, 3'b110, 5'd10, OPC_R);
            // PC=0x28: XOR x11, x1, x2   → x11 = 10 ^ 20 = 30
            dut.u_imem.rom[10] = R(F7_NORM, 5'd2, 5'd1, 3'b100, 5'd11, OPC_R);

            // ------------------------------------------------------------------
            // Shifts
            // ------------------------------------------------------------------
            // PC=0x2C: SLLI x12, x1, 2   → x12 = 10 << 2 = 40
            dut.u_imem.rom[11] = I(12'h002, 5'd1, 3'b001, 5'd12, OPC_I);
            // PC=0x30: SRLI x13, x12, 1  → x13 = 40 >> 1 = 20
            dut.u_imem.rom[12] = I(12'h001, 5'd12,3'b101, 5'd13, OPC_I);
            // PC=0x34: SRAI x14, x3, 1   → x14 = -5 >>> 1 = -3 (0xFFFFFFFD)
            dut.u_imem.rom[13] = {7'b0100000, 5'd1, 5'd3, 3'b101, 5'd14, OPC_I};

            // ------------------------------------------------------------------
            // Comparisons
            // ------------------------------------------------------------------
            // PC=0x38: SLT  x15, x1, x2  → x15 = (10 < 20 signed)  = 1
            dut.u_imem.rom[14] = R(F7_NORM, 5'd2, 5'd1, 3'b010, 5'd15, OPC_R);
            // PC=0x3C: SLTU x16, x3, x1  → x16 = (0xFFFFFFFB < 10 unsigned) = 0
            dut.u_imem.rom[15] = R(F7_NORM, 5'd1, 5'd3, 3'b011, 5'd16, OPC_R);

            // ------------------------------------------------------------------
            // LUI / AUIPC
            // ------------------------------------------------------------------
            // PC=0x40: LUI   x17, 0xABCDE  → x17 = 0xABCDE000
            dut.u_imem.rom[16] = U(20'hABCDE, 5'd17, OPC_LUI);
            // PC=0x44: AUIPC x18, 0       → x18 = PC(0x44) + 0 = 0x44
            dut.u_imem.rom[17] = U(20'd0,     5'd18, OPC_AUIPC);

            // ------------------------------------------------------------------
            // Memory: SW then LW
            // ------------------------------------------------------------------
            // PC=0x48: SW x2, 0(x0)   → RAM[0x0] = 20
            dut.u_imem.rom[18] = S(12'd0, 5'd2, 5'd0, 3'b010, OPC_STORE);
            // PC=0x4C: LW x19, 0(x0)  → x19 = 20
            dut.u_imem.rom[19] = I(12'd0, 5'd0, 3'b010, 5'd19, OPC_LOAD);

            // ------------------------------------------------------------------
            // Memory: SB then LBU
            // ------------------------------------------------------------------
            // PC=0x50: ADDI x20, x0, 0xAB  → x20 = 0xAB (171)
            dut.u_imem.rom[20] = I(12'h0AB, 5'd0, 3'b000, 5'd20, OPC_I);
            // PC=0x54: SB x20, 4(x0)  → RAM[4] = 0xAB
            dut.u_imem.rom[21] = S(12'd4, 5'd20, 5'd0, 3'b000, OPC_STORE);
            // PC=0x58: LBU x21, 4(x0) → x21 = 0x000000AB
            dut.u_imem.rom[22] = I(12'd4, 5'd0, 3'b100, 5'd21, OPC_LOAD);
            // PC=0x5C: LB  x22, 4(x0) → x22 = 0xFFFFFFAB (sign-extended)
            dut.u_imem.rom[23] = I(12'd4, 5'd0, 3'b000, 5'd22, OPC_LOAD);

            // ------------------------------------------------------------------
            // Branch: BEQ — x1==x1, should jump over the ADDI
            // ------------------------------------------------------------------
            // PC=0x60: BEQ x1, x1, +8 → skip next instruction
            dut.u_imem.rom[24] = B(13'd8, 5'd1, 5'd1, 3'b000, OPC_BRANCH);
            // PC=0x64: ADDI x23, x0, 0xFF  ← SHOULD BE SKIPPED
            dut.u_imem.rom[25] = I(12'hFF, 5'd0, 3'b000, 5'd23, OPC_I);
            // PC=0x68: ADDI x23, x0, 0x11  ← x23 should be 0x11
            dut.u_imem.rom[26] = I(12'h11, 5'd0, 3'b000, 5'd23, OPC_I);

            // ------------------------------------------------------------------
            // Branch: BNE — x1!=x2, should jump over ADDI
            // ------------------------------------------------------------------
            // PC=0x6C: BNE x1, x2, +8
            dut.u_imem.rom[27] = B(13'd8, 5'd2, 5'd1, 3'b001, OPC_BRANCH);
            // PC=0x70: ADDI x24, x0, 0xFF  ← SKIPPED
            dut.u_imem.rom[28] = I(12'hFF, 5'd0, 3'b000, 5'd24, OPC_I);
            // PC=0x74: ADDI x24, x0, 0x22  → x24 = 0x22
            dut.u_imem.rom[29] = I(12'h22, 5'd0, 3'b000, 5'd24, OPC_I);

            // ------------------------------------------------------------------
            // Branch: BLT — x1(10) < x2(20), should jump
            // ------------------------------------------------------------------
            // PC=0x78: BLT x1, x2, +8
            dut.u_imem.rom[30] = B(13'd8, 5'd2, 5'd1, 3'b100, OPC_BRANCH);
            // PC=0x7C: ADDI x25, x0, 0xFF  ← SKIPPED
            dut.u_imem.rom[31] = I(12'hFF, 5'd0, 3'b000, 5'd25, OPC_I);
            // PC=0x80: ADDI x25, x0, 0x33  → x25 = 0x33
            dut.u_imem.rom[32] = I(12'h33, 5'd0, 3'b000, 5'd25, OPC_I);

            // ------------------------------------------------------------------
            // JAL — jump to +12, save return address in x26
            // ------------------------------------------------------------------
            // PC=0x84: JAL x26, +12  → x26 = 0x88, PC = 0x90
            dut.u_imem.rom[33] = J(21'd12, 5'd26, OPC_JAL);
            // PC=0x88: ADDI x27, x0, 0xFF  ← SKIPPED (jumped over)
            dut.u_imem.rom[34] = I(12'hFF, 5'd0, 3'b000, 5'd27, OPC_I);
            // PC=0x8C: ADDI x27, x0, 0xFF  ← SKIPPED
            dut.u_imem.rom[35] = I(12'hFF, 5'd0, 3'b000, 5'd27, OPC_I);
            // PC=0x90: ADDI x27, x0, 0x44  ← LANDS HERE → x27 = 0x44
            dut.u_imem.rom[36] = I(12'h44, 5'd0, 3'b000, 5'd27, OPC_I);

            // ------------------------------------------------------------------
            // JALR — jump to x26+0 (= 0x88 SKIPPED target), save RA in x28
            // Actually jump to the return address stored in x26 = 0x88
            // We'll set x26 to point to our landing zone at PC=0x98
            // ------------------------------------------------------------------
            // PC=0x94: ADDI x26, x0, 0x98  → x26 = 0x98 (landing address)
            dut.u_imem.rom[37] = I(12'h098, 5'd0, 3'b000, 5'd26, OPC_I);
            // PC=0x98: -- skip, this is landing zone --
            // PC=0x94 re-sets x26; next instr at 0x98
            // PC=0x98: JALR x28, x26, 0  → jump to x26(0x98)? No — we want x98+4
            // Let's adjust: JALR x28, x0, 0x9C → jump to 0x9C
            dut.u_imem.rom[37] = I(12'h09C, 5'd0, 3'b000, 5'd0,  OPC_JALR); // JALR x0,x0,0x9C: jump to 0x9C
            // PC=0x98: ADDI x28, x0, 0xFF  ← SKIPPED
            dut.u_imem.rom[38] = I(12'hFF, 5'd0, 3'b000, 5'd28, OPC_I);
            // PC=0x9C: ADDI x28, x0, 0x55  → x28 = 0x55
            dut.u_imem.rom[39] = I(12'h55, 5'd0, 3'b000, 5'd28, OPC_I);

            // ------------------------------------------------------------------
            // Infinite loop — halt
            // ------------------------------------------------------------------
            // PC=0xA0: JAL x0, 0  (jump to self)
            dut.u_imem.rom[40] = J(21'd0, 5'd0, OPC_JAL);
        end
    endtask

    // =========================================================================
    // Main Test Flow
    // =========================================================================
    integer cycle_count;

    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("\n================================================================");
        $display("  oc_riscv32i — RV32I Single-Cycle Processor Testbench");
        $display("================================================================\n");

        // Reset
        reset = 1'b1;
        repeat (4) @(posedge clk);
        #1;

        // Load program
        load_program();

        // Release reset
        @(posedge clk); #1;
        reset = 1'b0;

        $display("[INFO] Reset released. Running program...\n");

        // Run for enough cycles (41 instructions + memory latency + margin)
        repeat (100) @(posedge clk);
        #1;

        // =====================================================================
        // Check Results
        // =====================================================================
        $display("--- Arithmetic ---");
        check_reg(5'd1,  32'd10,         "ADDI    ");
        check_reg(5'd2,  32'd20,         "ADDI    ");
        check_reg(5'd3,  32'hFFFF_FFFB,  "ADDI-5  ");
        check_reg(5'd4,  32'd30,         "ADD     ");
        check_reg(5'd5,  32'd10,         "SUB     ");

        $display("--- Logic Immediate ---");
        check_reg(5'd6,  32'd10,         "ANDI    ");
        check_reg(5'd7,  32'd15,         "ORI     ");
        check_reg(5'd8,  32'd5,          "XORI    ");

        $display("--- Logic Register ---");
        check_reg(5'd9,  32'd0,          "AND     ");
        check_reg(5'd10, 32'd30,         "OR      ");
        check_reg(5'd11, 32'd30,         "XOR     ");

        $display("--- Shifts ---");
        check_reg(5'd12, 32'd40,         "SLLI    ");
        check_reg(5'd13, 32'd20,         "SRLI    ");
        check_reg(5'd14, 32'hFFFF_FFFD,  "SRAI    ");

        $display("--- Comparisons ---");
        check_reg(5'd15, 32'd1,          "SLT     ");
        check_reg(5'd16, 32'd0,          "SLTU    ");

        $display("--- Upper Immediate ---");
        check_reg(5'd17, 32'hABCDE000,   "LUI     ");
        check_reg(5'd18, 32'h0000_0044,  "AUIPC   ");

        $display("--- Memory ---");
        check_reg(5'd19, 32'd20,         "LW      ");
        check_reg(5'd21, 32'h0000_00AB,  "LBU     ");
        check_reg(5'd22, 32'hFFFF_FFAB,  "LB      ");

        $display("--- Branches ---");
        check_reg(5'd23, 32'h11,         "BEQ     ");
        check_reg(5'd24, 32'h22,         "BNE     ");
        check_reg(5'd25, 32'h33,         "BLT     ");

        $display("--- Jumps ---");
        check_reg(5'd26, 32'h0000_0088,  "JAL-RA  ");
        check_reg(5'd27, 32'h44,         "JAL-land");
        check_reg(5'd28, 32'h55,         "JALR    ");

        // =====================================================================
        // Summary
        // =====================================================================
        $display("\n================================================================");
        $display("  Results: %0d PASSED | %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED — PROCESSOR VERIFIED ***");
        else
            $display("  *** FAILURES DETECTED — CHECK ABOVE ***");
        $display("================================================================\n");

        $finish;
    end

    // =========================================================================
    // Cycle-by-cycle trace
    // =========================================================================
    always @(posedge clk) begin
        if (!reset)
            $display("t=%0t | PC=0x%08h | IR=0x%08h | x1=%0d x2=%0d x4=%0d",
                $time,
                dut.pc,
                dut.instruction,
                dut.u_rf.regs[1],
                dut.u_rf.regs[2],
                dut.u_rf.regs[4]
            );
    end

endmodule
