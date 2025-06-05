module alu (
    input wire [7:0] a,         // ACC value
    input wire [7:0] b,         // Operand value from memory
    input wire [1:0] op,        // ALU operation selector
    output reg [7:0] result     // ALU result
);

    // ALU operations
    // 00: ADD
    // 01: SUB
    // 10: AND

    always @(*) begin
        case (op)
            2'b00: result = a + b;       // ADD
            2'b01: result = a - b;       // SUB
            2'b10: result = a & b;       // AND
            default: result = 8'b00000000;
        endcase
    end

endmodule
