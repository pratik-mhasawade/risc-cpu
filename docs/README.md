# oc_riscv32i — OpenCores RISC-V RV32I Processor

A clean, synthesizable, fully documented single-cycle 32-bit RISC-V processor
implementing the RV32I base integer ISA. Designed for OpenCores submission and
as a foundation for pipeline and SoC upgrades.

---

## Features

- Full **RV32I base integer ISA** — all 40 instructions
- **32 × 32-bit** general-purpose register file (x0 hardwired to zero)
- **32-bit ALU** — ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- **All branch types** — BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Jumps** — JAL and JALR (function call / return)
- **All load/store widths** — LW, LH, LB, LHU, LBU, SW, SH, SB
- **LUI** and **AUIPC** for 32-bit constant and PC-relative addressing
- Separate **instruction memory** (4 KB ROM) and **data memory** (4 KB RAM)
- **Self-checking testbench** with 20+ directed test cases
- Synthesizable with **Yosys**, **Vivado**, and **Quartus**
- OpenCores coding standard compliant

---

## Repository Structure

```
oc_riscv32i/
├── src/
│   ├── oc_riscv32i.v       # Top-level module (datapath + wiring)
│   ├── program_counter.v   # 32-bit PC with synchronous reset
│   ├── instr_mem.v         # Instruction ROM (4 KB, async read)
│   ├── register_file.v     # 32×32-bit register file (dual read, single write)
│   ├── control_unit.v      # Full RV32I instruction decoder
│   ├── imm_gen.v           # Immediate generator (I/S/B/U/J formats)
│   ├── alu.v               # 32-bit ALU (all RV32I operations + flags)
│   ├── branch_unit.v       # Branch condition evaluator
│   └── data_mem.v          # Data RAM (4 KB, byte/halfword/word access)
├── tb/
│   └── oc_riscv32i_tb.v    # Self-checking testbench
├── mem/
│   ├── program.mem         # Instruction memory init file
│   └── data.mem            # Data memory init file
└── docs/
    ├── README.md           # This file
    ├── STRUCTURE.md        # Module hierarchy and signal descriptions
    └── ISA.md              # Instruction encoding reference
```

---

## Datapath Diagram

```
         ┌─────────────────────────────────────────────────┐
         │                   oc_riscv32i                    │
         │                                                  │
  clk ───►  ┌──────┐    ┌──────────┐    ┌──────────────┐  │
 reset──►   │  PC  │───►│ InstrMem │───►│ Control Unit │  │
         │  └──────┘    └──────────┘    └──────────────┘  │
         │      │            │instr      alu_ctrl imm_sel  │
         │      │            ├──rs1,rs2──►┐    ┌──────┐   │
         │      │            │            │    │ImmGen│   │
         │      │            ▼            │    └──────┘   │
         │      │       ┌─────────┐       │        │imm   │
         │      │       │RegFile  │──rs1──►┌──────┐│      │
         │      │       │32×32bit │──rs2──►│ ALU  ◄┘      │
         │      │       └─────────┘       └──────┘        │
         │      │            ▲ rd_data       │ result      │
         │      │            │               ▼             │
         │      │       ┌────┴────┐     ┌─────────┐       │
         │      │       │ WB Mux  │◄────│ DataMem │       │
         │      │       └─────────┘     └─────────┘       │
         │      │                                          │
         │  ┌───┴────┐  ← branch_target / JAL / JALR      │
         │  │ PC Mux │                                     │
         │  └────────┘                                     │
         └─────────────────────────────────────────────────┘
```

---

## ISA — RV32I Instructions Implemented

### R-type (register-register)
| Instr | Operation            |
|-------|----------------------|
| ADD   | rd = rs1 + rs2       |
| SUB   | rd = rs1 - rs2       |
| AND   | rd = rs1 & rs2       |
| OR    | rd = rs1 \| rs2      |
| XOR   | rd = rs1 ^ rs2       |
| SLL   | rd = rs1 << rs2[4:0] |
| SRL   | rd = rs1 >> rs2[4:0] (logical)  |
| SRA   | rd = rs1 >>> rs2[4:0] (arith.)  |
| SLT   | rd = (rs1 < rs2) signed ? 1 : 0 |
| SLTU  | rd = (rs1 < rs2) unsigned ? 1:0 |

### I-type (immediate)
| Instr | Operation             |
|-------|-----------------------|
| ADDI  | rd = rs1 + sext(imm)  |
| ANDI  | rd = rs1 & sext(imm)  |
| ORI   | rd = rs1 \| sext(imm) |
| XORI  | rd = rs1 ^ sext(imm)  |
| SLTI  | rd = signed compare   |
| SLTIU | rd = unsigned compare |
| SLLI  | rd = rs1 << imm[4:0]  |
| SRLI  | rd = rs1 >> imm[4:0]  |
| SRAI  | rd = rs1 >>> imm[4:0] |

### Load / Store
| Instr | Operation                            |
|-------|--------------------------------------|
| LW    | rd = Mem[rs1+imm] (32-bit)           |
| LH    | rd = sext(Mem[rs1+imm][15:0])        |
| LB    | rd = sext(Mem[rs1+imm][7:0])         |
| LHU   | rd = zext(Mem[rs1+imm][15:0])        |
| LBU   | rd = zext(Mem[rs1+imm][7:0])         |
| SW    | Mem[rs1+imm] = rs2 (32-bit)          |
| SH    | Mem[rs1+imm][15:0] = rs2[15:0]       |
| SB    | Mem[rs1+imm][7:0] = rs2[7:0]         |

### Branch / Jump
| Instr | Condition                  |
|-------|----------------------------|
| BEQ   | branch if rs1 == rs2       |
| BNE   | branch if rs1 != rs2       |
| BLT   | branch if rs1 < rs2 (signed)|
| BGE   | branch if rs1 >= rs2 (signed)|
| BLTU  | branch if rs1 < rs2 (unsigned)|
| BGEU  | branch if rs1 >= rs2 (unsigned)|
| JAL   | rd = PC+4; PC += imm       |
| JALR  | rd = PC+4; PC = (rs1+imm)&~1 |

### Upper Immediate
| Instr | Operation                  |
|-------|----------------------------|
| LUI   | rd = {imm[19:0], 12'b0}    |
| AUIPC | rd = PC + {imm[19:0],12'b0}|

---

## Simulation

### Prerequisites
- [Icarus Verilog](https://github.com/steveicarus/iverilog) (free, open source)
- [GTKWave](http://gtkwave.sourceforge.net/) (waveform viewer)

### Run Testbench
```bash
# Compile
iverilog -o sim \
  src/oc_riscv32i.v \
  src/program_counter.v \
  src/instr_mem.v \
  src/register_file.v \
  src/control_unit.v \
  src/imm_gen.v \
  src/alu.v \
  src/branch_unit.v \
  src/data_mem.v \
  tb/oc_riscv32i_tb.v

# Simulate
vvp sim

# View waveforms
gtkwave tb/oc_riscv32i_tb.vcd
```

### Expected Output
```
================================================================
  oc_riscv32i — RV32I Single-Cycle Processor Testbench
================================================================

--- Arithmetic ---
  PASS [ADDI    ] x1 = 0x0000000a
  PASS [ADD     ] x4 = 0x0000001e
  PASS [SUB     ] x5 = 0x0000000a
...
================================================================
  Results: 20 PASSED | 0 FAILED
  *** ALL TESTS PASSED — PROCESSOR VERIFIED ***
================================================================
```

---

## Synthesis (FPGA)

### Yosys (open source)
```bash
yosys -p "synth -top oc_riscv32i; write_json synth.json" src/*.v
```

### Xilinx Vivado
1. Create new RTL project
2. Add all files from `src/` as design sources
3. Set `oc_riscv32i` as the top module
4. Target: Artix-7 (xc7a35t) — expected Fmax ~80 MHz

---

## Upgrade Roadmap

| Phase | Feature                        | Status      |
|-------|--------------------------------|-------------|
| ✅ 1  | 32-bit datapath                | Complete    |
| ✅ 2  | 32-register file               | Complete    |
| ✅ 3  | Full RV32I ISA                 | Complete    |
| 🔲 4  | 5-stage pipeline + hazards     | Next        |
| 🔲 5  | L1 I-Cache + D-Cache           | Planned     |
| 🔲 6  | Interrupt/Exception handling   | Planned     |
| 🔲 7  | Wishbone SoC bus               | Planned     |
| 🔲 8  | MMU + Virtual Memory           | Planned     |

---

## License
LGPL v2.1 — Free to use, modify, and distribute with attribution.

## Author
pratik-mhasawade — OpenCores contributor
