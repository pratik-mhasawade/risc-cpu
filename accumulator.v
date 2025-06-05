module accumulator (
    input wire clk,
    input wire reset,
    input wire write_enable,
    input wire [7:0] data_in,     // From ALU
    output reg [7:0] data_out     // To ALU and OUT
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            data_out <= 8'b00000000;
        else if (write_enable)
            data_out <= data_in;
    end

endmodule
