module top (
    input wire clk,
    input wire reset
);

    // Wires to connect modules
    wire [4:0] pc;
    wire [7:0] instruction;
    wire [7:0] acc_data;
    wire [7:0] mem_data;

    wire [1:0] alu_op;
    wire acc_write;
    wire mem_read;
    wire mem_write;
    wire pc_write;
    wire uart_send;
    wire [4:0] mem_addr;
    wire [4:0] new_pc;

    wire [7:0] alu_result;

    // PC module: program counter
    pc program_counter (
        .clk(clk),
        .reset(reset),
        .pc_write(pc_write),
        .new_pc(new_pc),
        .pc(pc)
    );

    // Instruction ROM
    instruction_rom instr_rom (
        .addr(pc),
        .instruction(instruction)
    );

    // Control FSM
    control_fsm ctrl_fsm (
        .clk(clk),
        .reset(reset),
        .instruction(instruction),
        .acc_data(acc_data),
        .alu_op(alu_op),
        .acc_write(acc_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .pc_write(pc_write),
        .uart_send(uart_send),
        .mem_addr(mem_addr),
        .new_pc(new_pc)
    );

    // Data Memory
    data_memory data_mem (
        .clk(clk),
        .addr(mem_addr),
        .write_enable(mem_write),
        .read_enable(mem_read),
        .write_data(acc_data),
        .read_data(mem_data)
    );

    // ALU
    alu alu_unit (
        .a(acc_data),
        .b(mem_data),
        .op(alu_op),
        .result(alu_result)
    );

    // Accumulator
    accumulator acc (
        .clk(clk),
        .reset(reset),
        .write_enable(acc_write),
        .data_in(alu_result),
        .data_out(acc_data)
    );

    // UART Output
    uart_output uart (
        .clk(clk),
        .reset(reset),
        .send_enable(uart_send),
        .data_in(acc_data)
    );

endmodule
