// =============================================================================
// Module      : data_mem
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : Data memory, 1024 x 32-bit words (4 KB).
//               Supports byte (LB/SB), halfword (LH/SH), and word (LW/SW)
//               accesses with sign extension on reads (LB, LH).
//               Unsigned variants (LBU, LHU) zero-extend instead.
//               Synchronous write, synchronous read (1-cycle latency).
//               Initialized from "mem/data.mem".
//
// mem_size (funct3) encoding — mirrors RV32I funct3:
//   3'b000 = LB  / SB   (byte,     sign-extended)
//   3'b001 = LH  / SH   (halfword, sign-extended)
//   3'b010 = LW  / SW   (word)
//   3'b100 = LBU        (byte,     zero-extended)
//   3'b101 = LHU        (halfword, zero-extended)
//
// Memory map: 0x00002000 – 0x00002FFF (4 KB data space)
// =============================================================================

module data_mem (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,            // byte address
    input  wire [31:0] write_data,      // data from rs2
    input  wire [2:0]  mem_size,        // access size / sign control

    output reg  [31:0] read_data        // data to writeback mux
);

    // -------------------------------------------------------------------------
    // Memory array — byte-addressable via 4 byte lanes
    // -------------------------------------------------------------------------
    reg [7:0] mem_b0 [0:1023];          // byte lane 0 (bits  7:0)
    reg [7:0] mem_b1 [0:1023];          // byte lane 1 (bits 15:8)
    reg [7:0] mem_b2 [0:1023];          // byte lane 2 (bits 23:16)
    reg [7:0] mem_b3 [0:1023];          // byte lane 3 (bits 31:24)

    wire [9:0] word_addr = addr[11:2];  // word index
    wire [1:0] byte_off  = addr[1:0];   // byte offset within word

    // Full word assembled from byte lanes
    wire [31:0] word_data = {mem_b3[word_addr],
                             mem_b2[word_addr],
                             mem_b1[word_addr],
                             mem_b0[word_addr]};

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            mem_b0[i] = 8'h00;
            mem_b1[i] = 8'h00;
            mem_b2[i] = 8'h00;
            mem_b3[i] = 8'h00;
        end
        $readmemh("mem/data.mem", mem_b0);   // load byte-interleaved data
    end

    // -------------------------------------------------------------------------
    // Synchronous Write — byte-enable based on mem_size and byte_off
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (mem_write) begin
            case (mem_size)
                3'b000: begin   // SB — store 1 byte
                    case (byte_off)
                        2'b00: mem_b0[word_addr] <= write_data[7:0];
                        2'b01: mem_b1[word_addr] <= write_data[7:0];
                        2'b10: mem_b2[word_addr] <= write_data[7:0];
                        2'b11: mem_b3[word_addr] <= write_data[7:0];
                    endcase
                end
                3'b001: begin   // SH — store 2 bytes (halfword-aligned)
                    case (byte_off)
                        2'b00: begin
                            mem_b0[word_addr] <= write_data[7:0];
                            mem_b1[word_addr] <= write_data[15:8];
                        end
                        2'b10: begin
                            mem_b2[word_addr] <= write_data[7:0];
                            mem_b3[word_addr] <= write_data[15:8];
                        end
                        default: begin /* misaligned — ignore in Phase 1 */ end
                    endcase
                end
                3'b010: begin   // SW — store full word (word-aligned)
                    mem_b0[word_addr] <= write_data[7:0];
                    mem_b1[word_addr] <= write_data[15:8];
                    mem_b2[word_addr] <= write_data[23:16];
                    mem_b3[word_addr] <= write_data[31:24];
                end
                default: begin /* invalid size */ end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Synchronous Read with sign/zero extension
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (mem_read) begin
            case (mem_size)
                3'b000: begin   // LB — sign-extended byte
                    case (byte_off)
                        2'b00: read_data <= {{24{mem_b0[word_addr][7]}}, mem_b0[word_addr]};
                        2'b01: read_data <= {{24{mem_b1[word_addr][7]}}, mem_b1[word_addr]};
                        2'b10: read_data <= {{24{mem_b2[word_addr][7]}}, mem_b2[word_addr]};
                        2'b11: read_data <= {{24{mem_b3[word_addr][7]}}, mem_b3[word_addr]};
                    endcase
                end
                3'b001: begin   // LH — sign-extended halfword
                    case (byte_off)
                        2'b00: read_data <= {{16{mem_b1[word_addr][7]}},
                                             mem_b1[word_addr], mem_b0[word_addr]};
                        2'b10: read_data <= {{16{mem_b3[word_addr][7]}},
                                             mem_b3[word_addr], mem_b2[word_addr]};
                        default: read_data <= 32'd0;
                    endcase
                end
                3'b010: read_data <= word_data;                       // LW
                3'b100: begin   // LBU — zero-extended byte
                    case (byte_off)
                        2'b00: read_data <= {24'd0, mem_b0[word_addr]};
                        2'b01: read_data <= {24'd0, mem_b1[word_addr]};
                        2'b10: read_data <= {24'd0, mem_b2[word_addr]};
                        2'b11: read_data <= {24'd0, mem_b3[word_addr]};
                    endcase
                end
                3'b101: begin   // LHU — zero-extended halfword
                    case (byte_off)
                        2'b00: read_data <= {16'd0, mem_b1[word_addr], mem_b0[word_addr]};
                        2'b10: read_data <= {16'd0, mem_b3[word_addr], mem_b2[word_addr]};
                        default: read_data <= 32'd0;
                    endcase
                end
                default: read_data <= 32'd0;
            endcase
        end else begin
            read_data <= 32'd0;
        end
    end

endmodule
