module instruction_rom (
    input wire [4:0] addr,         // 5-bit address supports 32 instructions
    output reg [7:0] instruction   // 8-bit instruction output
);

    always @(*) begin
        case (addr)
            // Format: {opcode[7:5], operand[4:0]}
            
            // Example program:
            5'd0: instruction = 8'b001_00001; // LOAD  0x01
            5'd1: instruction = 8'b011_00010; // ADD   0x02
            5'd2: instruction = 8'b100_00011; // SUB   0x03
            5'd3: instruction = 8'b010_00100; // STORE 0x04
            5'd4: instruction = 8'b111_00000; // OUT
            5'd5: instruction = 8'b101_00000; // JMP   0x00 (loop)
            
            // Fill the rest with NOPs or zeros
            default: instruction = 8'b000_00000;
        endcase
    end

endmodule
