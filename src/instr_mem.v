// =============================================================================
// Module      : instr_mem
// Project     : oc_riscv32i — OpenCores RISC-V RV32I Processor
// Author      : pratik-mhasawade
// Description : Instruction memory (ROM), 1024 x 32-bit words (4 KB).
//               Asynchronous read — instruction available same cycle as addr.
//               Initialized from "mem/program.mem" (hex, word-addressed).
//               Only instr[31:2] used as address (word-aligned access).
//
// Memory map : 0x00000000 – 0x00000FFF (4 KB instruction space)
// =============================================================================

module instr_mem (
    input  wire [31:0] addr,            // byte address from PC
    output wire [31:0] instruction      // 32-bit instruction word
);

    reg [31:0] rom [0:1023];            // 1K words = 4 KB

    initial begin
        $readmemh("mem/program.mem", rom);
    end

    // Word-aligned: use addr[11:2] as word index, ignore byte offset addr[1:0]
    assign instruction = rom[addr[11:2]];

endmodule
