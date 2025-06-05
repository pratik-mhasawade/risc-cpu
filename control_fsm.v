module control_fsm (
    input wire clk,
    input wire reset,
    input wire [7:0] instruction,       // From instruction ROM
    input wire [7:0] acc_data,          // From accumulator (for JZ decision)

    output reg [1:0] alu_op,            // To ALU
    output reg acc_write,               // Load ACC
    output reg mem_read,                // Enable RAM read
    output reg mem_write,              // Enable RAM write
    output reg pc_write,               // Enable PC jump
    output reg uart_send,              // Enable UART output
    output reg [4:0] mem_addr,         // RAM address
    output reg [4:0] new_pc            // Jump target
);

    // FSM states (for simplicity, 1-stage execution per instruction)
    reg [2:0] opcode;
    reg [4:0] operand;

    always @(*) begin
        // Default values
        alu_op      = 2'b00;
        acc_write   = 0;
        mem_read    = 0;
        mem_write   = 0;
        pc_write    = 0;
        uart_send   = 0;
        mem_addr    = 5'b00000;
        new_pc      = 5'b00000;

        opcode  = instruction[7:5];
        operand = instruction[4:0];
        mem_addr = operand;
        new_pc   = operand;

        case (opcode)
            3'b001: begin // LOAD
                mem_read  = 1;
                acc_write = 1;
            end
            3'b010: begin // STORE
                mem_write = 1;
            end
            3'b011: begin // ADD
                mem_read  = 1;
                acc_write = 1;
                alu_op    = 2'b00;
            end
            3'b100: begin // SUB
                mem_read  = 1;
                acc_write = 1;
                alu_op    = 2'b01;
            end
            3'b101: begin // JMP
                pc_write  = 1;
            end
            3'b110: begin // JZ
                if (acc_data == 8'b00000000)
                    pc_write = 1;
            end
            3'b111: begin // OUT
                uart_send = 1;
            end
            default: begin
                // NOP or invalid instruction
            end
        endcase
    end

endmodule
