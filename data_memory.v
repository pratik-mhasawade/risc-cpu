module data_memory (
    input wire clk,
    input wire [4:0] addr,              // 5-bit address (32 bytes)
    input wire write_enable,
    input wire read_enable,
    input wire [7:0] write_data,        // From ACC
    output reg [7:0] read_data          // To ALU
);

    // Memory array: 32 x 8-bit
    reg [7:0] mem [0:31];

    // Read
    always @(*) begin
        if (read_enable)
            read_data = mem[addr];
        else
            read_data = 8'b00000000;
    end

    // Write
    always @(posedge clk) begin
        if (write_enable)
            mem[addr] <= write_data;
    end

endmodule
