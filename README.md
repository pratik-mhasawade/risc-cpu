#  8-bit RISC Processor (Verilog HDL)

A custom-designed 8-bit RISC processor built from scratch using Verilog. This CPU demonstrates fundamental computer architecture principles, featuring a modular datapath and FSM-based control logic. Designed for simulation and synthesizable on FPGA platforms like the BASYS-3.

---

##  Key Features

- **Custom ISA**: 3-bit opcode + 5-bit operand
- **Harvard Architecture**: Separate instruction and data memory
- **Modular Design**: Each block is encapsulated and reusable
- **FSM-based Control Unit**: Coordinates all instruction stages
- **UART Output Simulation**: Data printed to terminal on `OUT` instruction
- **Designed for FPGA or RTL Simulation**: Works with tools like Vivado, ModelSim, Icarus Verilog

---

## 🧱 Modules Overview

| Module              | Description                                          |
|---------------------|------------------------------------------------------|
| `top.v`             | Top-level integration module                         |
| `pc.v`              | Program Counter with jump support                    |
| `instruction_rom.v` | ROM for storing test instructions                    |
| `control_fsm.v`     | FSM that decodes instructions and drives control     |
| `alu.v`             | 3-operation ALU (ADD, SUB, AND, OR, NOT)             |
| `accumulator.v`     | Register to hold computation results                 |
| `data_memory.v`     | RAM for data load/store operations                   |
| `uart_output.v`     | Simulated UART output for terminal printing          |

---

## 🛠️ How It Works

1. **Instruction Fetch** from `instruction_rom.v` using `pc.v`.
2. **Control FSM** decodes the opcode and generates control signals.
3. **Operand Read** from memory or immediate.
4. **ALU Execution** based on opcode.
5. **Result Write-back** to `accumulator` or memory.
6. **UART OUT** prints result to terminal when instructed.

---

## 📜 Sample Instruction Set (ISA)

| Opcode (3-bit) | Mnemonic | Operation           |
|----------------|----------|---------------------|
| `000`          | LOAD     | A ← M[addr]         |
| `001`          | STORE    | M[addr] ← A         |
| `010`          | ADD      | A ← A + M[addr]     |
| `011`          | SUB      | A ← A - M[addr]     |
| `100`          | JMP      | PC ← addr           |
| `101`          | JZ       | if A == 0: PC ← addr|
| `111`          | OUT      | UART ← A            |

---

## 🧪 Test & Simulate

### 🔧 Build with Icarus Verilog
```bash
iverilog -o cpu risc_cpu.v testbench.v
vvp cpu
