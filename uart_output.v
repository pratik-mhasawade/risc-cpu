module uart_output (
    input wire clk,
    input wire reset,
    input wire send_enable,
    input wire [7:0] data_in     // From ACC
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Nothing to reset in this simulation
        end else if (send_enable) begin
            $display("UART Output: %d (0x%h)", data_in, data_in);
        end
    end

endmodule
