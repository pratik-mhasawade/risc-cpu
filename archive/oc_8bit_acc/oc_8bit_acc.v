// =============================================================================
//  8-bit Accumulator-Based Processor — Single File
// =============================================================================
//
//  Instruction Format: [7:5] opcode | [4:0] operand
//
//  Opcodes:
//    000 = NOP
//    001 = LOAD  addr  → ACC = RAM[addr]
//    010 = STORE addr  → RAM[addr] = ACC
//    011 = ADD   addr  → ACC = ACC + RAM[addr]
//    100 = SUB   addr  → ACC = ACC - RAM[addr]
//    101 = JMP   addr  → PC = addr
//    110 = JZ    addr  → if (ACC == 0) PC = addr
//    111 = OUT         → print ACC via UART (simulation)
//
// =============================================================================


// -----------------------------------------------------------------------------
// Program Counter (PC)
// -----------------------------------------------------------------------------
module pc (
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_write,   // 1 = jump to new_pc, 0 = increment
    input  wire [4:0]  new_pc,     // jump target address
    output reg  [4:0]  pc_out      // current PC value
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= 5'b00000;
        else if (pc_write)
            pc_out <= new_pc;
        else
            pc_out <= pc_out + 1'b1;
    end
endmodule


// -----------------------------------------------------------------------------
// Instruction ROM  (32 x 8-bit, loaded from "program.mem")
// -----------------------------------------------------------------------------
module instruction_rom (
    input  wire [4:0] addr,
    output wire [7:0] instruction
);
    reg [7:0] rom [0:31];

    initial begin
        $readmemh("program.mem", rom);
    end

    assign instruction = rom[addr];
endmodule


// -----------------------------------------------------------------------------
// Data Memory  (32 x 8-bit, loaded from "data.mem")
//   Synchronous write, synchronous read
// -----------------------------------------------------------------------------
module data_memory (
    input  wire       clk,
    input  wire [4:0] addr,
    input  wire       write_enable,
    input  wire       read_enable,
    input  wire [7:0] write_data,
    output reg  [7:0] read_data
);
    reg [7:0] mem [0:31];

    initial begin
        $readmemh("data.mem", mem);
    end

    // Synchronous read
    always @(posedge clk) begin
        if (read_enable)
            read_data <= mem[addr];
        else
            read_data <= 8'b00000000;
    end

    // Synchronous write
    always @(posedge clk) begin
        if (write_enable)
            mem[addr] <= write_data;
    end
endmodule


// -----------------------------------------------------------------------------
// ALU  (combinational)
//   op 2'b00 = ADD
//   op 2'b01 = SUB
//   op 2'b10 = AND
// -----------------------------------------------------------------------------
module alu (
    input  wire [7:0] a,       // from accumulator
    input  wire [7:0] b,       // from data memory
    input  wire [1:0] op,      // operation select
    output reg  [7:0] result
);
    always @(*) begin
        case (op)
            2'b00:   result = a + b;
            2'b01:   result = a - b;
            2'b10:   result = a & b;
            default: result = 8'b00000000;
        endcase
    end
endmodule


// -----------------------------------------------------------------------------
// Zero Flag Register
//   Latches whether the ALU result was zero on every clock edge.
// -----------------------------------------------------------------------------
module flags (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] alu_result,
    output reg        zero_flag
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            zero_flag <= 1'b0;
        else
            zero_flag <= (alu_result == 8'b00000000);
    end
endmodule


// -----------------------------------------------------------------------------
// Accumulator Register
// -----------------------------------------------------------------------------
module accumulator (
    input  wire       clk,
    input  wire       reset,
    input  wire       write_enable,
    input  wire [7:0] data_in,
    output reg  [7:0] data_out
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            data_out <= 8'b00000000;
        else if (write_enable)
            data_out <= data_in;
    end
endmodule


// -----------------------------------------------------------------------------
// Control FSM  (fully combinational — one-cycle execution)
//
//   load_sel: 1 = ACC gets raw memory value (LOAD)
//             0 = ACC gets ALU result        (ADD / SUB)
// -----------------------------------------------------------------------------
module control_fsm (
    input  wire [7:0] instruction,
    input  wire       zero_flag,

    output reg        load_sel,
    output reg [1:0]  alu_op,
    output reg        acc_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        pc_write,
    output reg        uart_send,
    output reg [4:0]  mem_addr,
    output reg [4:0]  new_pc
);
    wire [2:0] opcode  = instruction[7:5];
    wire [4:0] operand = instruction[4:0];

    always @(*) begin
        // Safe defaults
        load_sel  = 1'b0;
        alu_op    = 2'b00;
        acc_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        pc_write  = 1'b0;
        uart_send = 1'b0;
        mem_addr  = operand;
        new_pc    = operand;

        case (opcode)
            3'b001: begin               // LOAD
                mem_read  = 1'b1;
                acc_write = 1'b1;
                load_sel  = 1'b1;       // ACC ← mem (not ALU result)
            end
            3'b010: begin               // STORE
                mem_write = 1'b1;
            end
            3'b011: begin               // ADD
                mem_read  = 1'b1;
                acc_write = 1'b1;
                alu_op    = 2'b00;
            end
            3'b100: begin               // SUB
                mem_read  = 1'b1;
                acc_write = 1'b1;
                alu_op    = 2'b01;
            end
            3'b101: begin               // JMP
                pc_write  = 1'b1;
            end
            3'b110: begin               // JZ
                if (zero_flag)
                    pc_write = 1'b1;
            end
            3'b111: begin               // OUT
                uart_send = 1'b1;
            end
            default: begin              // NOP / invalid
            end
        endcase
    end
endmodule


// -----------------------------------------------------------------------------
// UART Output  (simulation-only: prints ACC value to console)
// -----------------------------------------------------------------------------
module uart_output (
    input wire       clk,
    input wire       reset,
    input wire       send_enable,
    input wire [7:0] data_in
);
    always @(posedge clk) begin
        if (!reset && send_enable)
            $display("UART OUT: %0d  (0x%02h)", data_in, data_in);
    end
endmodule


// -----------------------------------------------------------------------------
// TOP MODULE — wires everything together
// -----------------------------------------------------------------------------
module top (
    input wire clk,
    input wire reset
);
    // -------------------------------------------------------------------------
    // Internal wires
    // -------------------------------------------------------------------------
    wire [4:0] pc_addr;         // PC → ROM
    wire [7:0] instruction;     // ROM → control FSM

    wire        load_sel;       // control → mux
    wire [1:0]  alu_op;         // control → ALU
    wire        acc_write;      // control → ACC
    wire        mem_read;       // control → data memory
    wire        mem_write;      // control → data memory
    wire        pc_write;       // control → PC
    wire        uart_send;      // control → UART
    wire [4:0]  mem_addr;       // control → data memory
    wire [4:0]  new_pc;         // control → PC

    wire [7:0]  acc_data;       // ACC → ALU / STORE / UART
    wire [7:0]  mem_data;       // data memory → ALU / ACC (via mux)
    wire [7:0]  alu_result;     // ALU → ACC (via mux) / flags
    wire [7:0]  acc_input;      // mux output → ACC
    wire         zero_flag;     // flags → control FSM

    // -------------------------------------------------------------------------
    // Mux: ACC input select
    //   load_sel = 1  →  ACC ← mem_data   (LOAD instruction)
    //   load_sel = 0  →  ACC ← alu_result (ADD / SUB)
    // -------------------------------------------------------------------------
    assign acc_input = load_sel ? mem_data : alu_result;

    // -------------------------------------------------------------------------
    // Module Instantiations
    // -------------------------------------------------------------------------

    pc program_counter (
        .clk      (clk),
        .reset    (reset),
        .pc_write (pc_write),
        .new_pc   (new_pc),
        .pc_out   (pc_addr)
    );

    instruction_rom instr_rom (
        .addr        (pc_addr),
        .instruction (instruction)
    );

    control_fsm ctrl (
        .instruction (instruction),
        .zero_flag   (zero_flag),
        .load_sel    (load_sel),
        .alu_op      (alu_op),
        .acc_write   (acc_write),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .pc_write    (pc_write),
        .uart_send   (uart_send),
        .mem_addr    (mem_addr),
        .new_pc      (new_pc)
    );

    data_memory data_mem (
        .clk          (clk),
        .addr         (mem_addr),
        .write_enable (mem_write),
        .read_enable  (mem_read),
        .write_data   (acc_data),
        .read_data    (mem_data)
    );

    alu alu_unit (
        .a      (acc_data),
        .b      (mem_data),
        .op     (alu_op),
        .result (alu_result)
    );

    flags flag_unit (
        .clk        (clk),
        .reset      (reset),
        .alu_result (alu_result),
        .zero_flag  (zero_flag)
    );

    accumulator acc (
        .clk          (clk),
        .reset        (reset),
        .write_enable (acc_write),
        .data_in      (acc_input),
        .data_out     (acc_data)
    );

    uart_output uart (
        .clk         (clk),
        .reset       (reset),
        .send_enable (uart_send),
        .data_in     (acc_data)
    );

endmodule
