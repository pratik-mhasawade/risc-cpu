// =============================================================================
// Module      : oc_riscv32i (top)
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// License     : LGPL v2.1
// Description : Top-level single-cycle RV32I processor.
//               Instantiates and connects all datapath and control modules.
//
// Datapath Overview:
//
//   ┌──────────┐    ┌──────────┐    ┌──────────────┐
//   │    PC    │───►│ InstrMem │───►│ Control Unit │
//   └──────────┘    └──────────┘    └──────────────┘
//        ▲                │ instr           │ ctrl signals
//        │                ▼                 ▼
//   ┌────┴─────┐    ┌──────────┐    ┌──────────────┐
//   │  PC mux  │    │ Reg File │◄───│   WB mux     │
//   └──────────┘    └──────────┘    └──────────────┘
//        ▲               │ rs1,rs2         ▲
//        │               ▼                 │
//   ┌────┴─────┐    ┌──────────┐    ┌──────────────┐
//   │ Imm/Br   │    │   ALU    │───►│  Data Mem    │
//   └──────────┘    └──────────┘    └──────────────┘
//
// =============================================================================

`timescale 1ns / 1ps

module oc_riscv32i (
    input  wire clk,
    input  wire reset
);

    // =========================================================================
    // Internal Wires
    // =========================================================================

    // --- Program Counter ---
    wire [31:0] pc;
    wire [31:0] pc_plus4;
    wire [31:0] pc_next;

    // --- Instruction fields ---
    wire [31:0] instruction;
    wire [6:0]  opcode  = instruction[6:0];
    wire [4:0]  rd      = instruction[11:7];
    wire [2:0]  funct3  = instruction[14:12];
    wire [4:0]  rs1     = instruction[19:15];
    wire [4:0]  rs2     = instruction[24:20];
    wire [6:0]  funct7  = instruction[31:25];

    // --- Register File ---
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] rd_data;
    wire        rd_write_en;

    // --- Immediate Generator ---
    wire [31:0] imm;
    wire [2:0]  imm_sel;

    // --- ALU ---
    wire [31:0] alu_operand_a;
    wire [31:0] alu_operand_b;
    wire [31:0] alu_result;
    wire [3:0]  alu_ctrl;
    wire        alu_zero;
    wire        alu_neg;
    wire        alu_ovf;
    wire        alu_src;
    wire        lui_sel;
    wire        auipc_sel;

    // --- Branch ---
    wire        branch;
    wire        branch_taken;
    wire [31:0] branch_target;
    wire [31:0] jal_target;
    wire [31:0] jalr_target;

    // --- Memory ---
    wire        mem_read;
    wire        mem_write;
    wire [2:0]  mem_size;
    wire [31:0] mem_rdata;

    // --- Writeback ---
    wire [1:0]  mem_to_reg;
    wire [1:0]  pc_src;

    // =========================================================================
    // PC Arithmetic
    // =========================================================================
    assign pc_plus4     = pc + 32'd4;
    assign branch_target= pc + imm;                         // B-type: PC + B-imm
    assign jal_target   = pc + imm;                         // J-type: PC + J-imm
    assign jalr_target  = {alu_result[31:1], 1'b0};         // JALR: (rs1+imm)[0]=0

    // =========================================================================
    // PC Next Mux
    //   00 = PC+4  (sequential)
    //   01 = branch target (only if branch_taken)
    //   10 = JAL target
    //   11 = JALR target
    // =========================================================================
    assign pc_next =
        (pc_src == 2'b01 && branch_taken) ? branch_target :
        (pc_src == 2'b10)                 ? jal_target    :
        (pc_src == 2'b11)                 ? jalr_target   :
                                            pc_plus4;

    // =========================================================================
    // ALU Operand Muxes
    //   alu_operand_a: PC (AUIPC), 0 (LUI), or rs1 (default)
    //   alu_operand_b: immediate or rs2
    // =========================================================================
    assign alu_operand_a = auipc_sel ? pc       :
                           lui_sel   ? 32'd0    :
                                       rs1_data;

    assign alu_operand_b = alu_src   ? imm      : rs2_data;

    // =========================================================================
    // Writeback Mux
    //   00 = ALU result
    //   01 = Memory read data
    //   10 = PC + 4 (return address for JAL/JALR)
    // =========================================================================
    assign rd_data   = (mem_to_reg == 2'b01) ? mem_rdata  :
                       (mem_to_reg == 2'b10) ? pc_plus4   :
                                               alu_result;

    assign rd_write_en = rd_write_en_ctrl;      // from control unit

    // =========================================================================
    // Module Instantiations
    // =========================================================================

    // --- Program Counter ---
    program_counter u_pc (
        .clk     (clk),
        .reset   (reset),
        .pc_next (pc_next),
        .pc      (pc)
    );

    // --- Instruction Memory ---
    instr_mem u_imem (
        .addr        (pc),
        .instruction (instruction)
    );

    // --- Control Unit ---
    wire rd_write_en_ctrl;
    control_unit u_ctrl (
        .opcode    (opcode),
        .funct3    (funct3),
        .funct7    (funct7),
        .alu_ctrl  (alu_ctrl),
        .imm_sel   (imm_sel),
        .alu_src   (alu_src),
        .reg_write (rd_write_en_ctrl),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_to_reg(mem_to_reg),
        .pc_src    (pc_src),
        .branch    (branch),
        .mem_size  (mem_size),
        .lui_sel   (lui_sel),
        .auipc_sel (auipc_sel)
    );

    // --- Immediate Generator ---
    imm_gen u_immgen (
        .instruction (instruction),
        .imm_sel     (imm_sel),
        .imm_out     (imm)
    );

    // --- Register File ---
    register_file u_rf (
        .clk        (clk),
        .reset      (reset),
        .rs1_addr   (rs1),
        .rs2_addr   (rs2),
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data),
        .rd_addr    (rd),
        .rd_data    (rd_data),
        .rd_write_en(rd_write_en_ctrl)
    );

    // --- ALU ---
    alu u_alu (
        .operand_a (alu_operand_a),
        .operand_b (alu_operand_b),
        .alu_ctrl  (alu_ctrl),
        .result    (alu_result),
        .zero      (alu_zero),
        .negative  (alu_neg),
        .overflow  (alu_ovf)
    );

    // --- Branch Unit ---
    branch_unit u_branch (
        .funct3        (funct3),
        .zero          (alu_zero),
        .alu_result_lsb(alu_result[0]),
        .branch        (branch),
        .branch_taken  (branch_taken)
    );

    // --- Data Memory ---
    data_mem u_dmem (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .addr       (alu_result),
        .write_data (rs2_data),
        .mem_size   (mem_size),
        .read_data  (mem_rdata)
    );

endmodule
