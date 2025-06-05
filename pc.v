module pc (
    input wire clk,
    input wire reset,
    input wire pc_write,              // enable jump
    input wire [4:0] new_pc,          // jump address
    output reg [4:0] pc               // current PC value (5-bit for 32 instr.)
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 5'b00000;           // reset PC to 0
        else if (pc_write)
            pc <= new_pc;             // jump to new address
        else
            pc <= pc + 1;             // default: increment
    end

endmodule
