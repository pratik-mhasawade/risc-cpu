// =============================================================================
//  Testbench for 8-bit Accumulator-Based Processor
// =============================================================================
//
//  Test Program (written into instruction ROM in-memory):
//
//    Addr | Hex  | Mnemonic       | Description
//    -----|------|----------------|--------------------------------------------
//    0    | 20   | LOAD  0        | ACC = RAM[0]       (ACC = 0x0A = 10)
//    1    | 61   | ADD   1        | ACC = ACC + RAM[1] (ACC = 10 + 5 = 15)
//    2    | E0   | OUT            | Print ACC (expect 15)
//    3    | 82   | SUB   2        | ACC = ACC - RAM[2] (ACC = 15 - 3 = 12)
//    4    | E0   | OUT            | Print ACC (expect 12)
//    5    | 43   | STORE 3        | RAM[3] = ACC       (RAM[3] = 12)
//    6    | 20   | LOAD  0        | ACC = RAM[0]       (ACC = 10)
//    7    | 83   | SUB   3        | ACC = 10 - 12 = -2 (0xFE, non-zero)
//    8    | C0A  | JZ    10       | Skip (zero_flag=0, ACC != 0)
//    9    | E0   | OUT            | Print ACC (expect 0xFE = 254)
//    10   | 20   | LOAD  0        | ACC = RAM[0]       (ACC = 10)
//    11   | 84   | SUB   4        | ACC = 10 - 10 = 0  (zero_flag set)
//    12   | CF   | JZ    15       | Jump to 15         (zero_flag=1)
//    13   | E0   | OUT            | SKIPPED (should not print)
//    14   | E0   | OUT            | SKIPPED (should not print)
//    15   | A0F  | JMP    0       | Jump back to 0 (infinite loop guard)
//
//  Data Memory Preloaded:
//    RAM[0] = 0x0A  (10)
//    RAM[1] = 0x05  (5)
//    RAM[2] = 0x03  (3)
//    RAM[3] = 0x00  (will be written by STORE)
//    RAM[4] = 0x0A  (10, for zero-result SUB test)
//
//  Expected UART Outputs (in order):
//    OUT 1: 15   (0x0F)  — after ADD
//    OUT 2: 12   (0x0C)  — after SUB
//    OUT 3: 254  (0xFE)  — after negative SUB (JZ NOT taken)
//    OUT 4: -- none --   — JZ IS taken, OUT at 13/14 skipped
//
// =============================================================================

`timescale 1ns / 1ps

module processor_tb;

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------
    reg clk;
    reg reset;

    // -------------------------------------------------------------------------
    // Instantiate DUT
    // -------------------------------------------------------------------------
    top dut (
        .clk   (clk),
        .reset (reset)
    );

    // -------------------------------------------------------------------------
    // Clock Generation — 10 ns period (100 MHz)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Preload Instruction ROM
    // -------------------------------------------------------------------------
    task load_program;
        integer i;
        begin
            // Clear ROM first
            for (i = 0; i < 32; i = i + 1)
                dut.instr_rom.rom[i] = 8'h00;

            // --- Program ---
            // LOAD  addr[4:0] → opcode 001 → bits[7:5]=001
            // ADD   addr      → opcode 011 → bits[7:5]=011
            // SUB   addr      → opcode 100 → bits[7:5]=100
            // STORE addr      → opcode 010 → bits[7:5]=010
            // JMP   addr      → opcode 101 → bits[7:5]=101
            // JZ    addr      → opcode 110 → bits[7:5]=110
            // OUT             → opcode 111 → bits[7:5]=111
            //
            // Encoding: {opcode[2:0], operand[4:0]}

            dut.instr_rom.rom[0]  = 8'b001_00000; // LOAD  0    → 0x20
            dut.instr_rom.rom[1]  = 8'b011_00001; // ADD   1    → 0x61
            dut.instr_rom.rom[2]  = 8'b111_00000; // OUT        → 0xE0
            dut.instr_rom.rom[3]  = 8'b100_00010; // SUB   2    → 0x82
            dut.instr_rom.rom[4]  = 8'b111_00000; // OUT        → 0xE0
            dut.instr_rom.rom[5]  = 8'b010_00011; // STORE 3    → 0x43
            dut.instr_rom.rom[6]  = 8'b001_00000; // LOAD  0    → 0x20
            dut.instr_rom.rom[7]  = 8'b100_00011; // SUB   3    → 0x83
            dut.instr_rom.rom[8]  = 8'b110_01010; // JZ    10   → 0xCA
            dut.instr_rom.rom[9]  = 8'b111_00000; // OUT        → 0xE0
            dut.instr_rom.rom[10] = 8'b001_00000; // LOAD  0    → 0x20
            dut.instr_rom.rom[11] = 8'b100_00100; // SUB   4    → 0x84
            dut.instr_rom.rom[12] = 8'b110_01111; // JZ    15   → 0xCF
            dut.instr_rom.rom[13] = 8'b111_00000; // OUT (skip) → 0xE0
            dut.instr_rom.rom[14] = 8'b111_00000; // OUT (skip) → 0xE0
            dut.instr_rom.rom[15] = 8'b101_00000; // JMP   0    → 0xA0
        end
    endtask

    // -------------------------------------------------------------------------
    // Preload Data Memory
    // -------------------------------------------------------------------------
    task load_data;
        integer i;
        begin
            for (i = 0; i < 32; i = i + 1)
                dut.data_mem.mem[i] = 8'h00;

            dut.data_mem.mem[0] = 8'h0A;  // 10
            dut.data_mem.mem[1] = 8'h05;  // 5
            dut.data_mem.mem[2] = 8'h03;  // 3
            dut.data_mem.mem[3] = 8'h00;  // placeholder (written by STORE)
            dut.data_mem.mem[4] = 8'h0A;  // 10 (used for zero-result test)
        end
    endtask

    // -------------------------------------------------------------------------
    // Checker — tracks expected UART outputs
    // -------------------------------------------------------------------------
    integer uart_count;
    reg [7:0] expected_uart [0:2];
    reg test_failed;

    // Monitor UART output by watching uart_send + acc_data
    always @(posedge clk) begin
        if (!reset && dut.uart_send) begin
            $display("[Cycle %0t] UART OUT #%0d: %0d (0x%02h)",
                     $time, uart_count, dut.acc_data, dut.acc_data);

            if (uart_count < 3) begin
                if (dut.acc_data !== expected_uart[uart_count]) begin
                    $display("  *** FAIL: Expected %0d (0x%02h), got %0d (0x%02h)",
                             expected_uart[uart_count], expected_uart[uart_count],
                             dut.acc_data, dut.acc_data);
                    test_failed = 1;
                end else begin
                    $display("  PASS");
                end
            end
            uart_count = uart_count + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Waveform Dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("processor_tb.vcd");
        $dumpvars(0, processor_tb);
    end

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    integer cycle;

    initial begin
        // Setup
        test_failed = 0;
        uart_count  = 0;

        expected_uart[0] = 8'd15;   // OUT after ADD:  10 + 5 = 15
        expected_uart[1] = 8'd12;   // OUT after SUB:  15 - 3 = 12
        expected_uart[2] = 8'hFE;   // OUT after SUB:  10 - 12 = -2 (0xFE), JZ not taken

        // -------------------------------------------------------------------
        // TEST 1: Reset behaviour
        // -------------------------------------------------------------------
        $display("\n============================================================");
        $display("  8-bit Accumulator Processor Testbench");
        $display("============================================================\n");
        $display("[TEST 1] Reset check");

        reset = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        if (dut.program_counter.pc_out !== 5'd0)
            $display("  *** FAIL: PC not 0 after reset (got %0d)", dut.program_counter.pc_out);
        else
            $display("  PASS: PC = 0 after reset");

        if (dut.acc.data_out !== 8'd0)
            $display("  *** FAIL: ACC not 0 after reset (got %0d)", dut.acc.data_out);
        else
            $display("  PASS: ACC = 0 after reset");

        // -------------------------------------------------------------------
        // Load program and data into memory
        // -------------------------------------------------------------------
        load_program();
        load_data();

        // -------------------------------------------------------------------
        // TEST 2–6: Run through the program
        // -------------------------------------------------------------------
        $display("\n[TEST 2-6] Running program — watching UART outputs\n");

        reset = 0;

        // Run for enough cycles to fully execute all instructions
        // (16 instructions × 2 cycles per read + margin = ~60 cycles)
        for (cycle = 0; cycle < 60; cycle = cycle + 1)
            @(posedge clk);

        // -------------------------------------------------------------------
        // TEST 7: STORE verification — RAM[3] should now hold 12
        // -------------------------------------------------------------------
        $display("\n[TEST 7] STORE check — RAM[3] should be 12 (0x0C)");
        if (dut.data_mem.mem[3] === 8'h0C)
            $display("  PASS: RAM[3] = 0x%02h", dut.data_mem.mem[3]);
        else begin
            $display("  *** FAIL: RAM[3] = 0x%02h (expected 0x0C)", dut.data_mem.mem[3]);
            test_failed = 1;
        end

        // -------------------------------------------------------------------
        // TEST 8: JZ (not taken) — uart_count must be at least 3 by now
        // -------------------------------------------------------------------
        $display("\n[TEST 8] JZ not-taken check — OUT at address 9 must have fired");
        if (uart_count >= 3)
            $display("  PASS: %0d UART outputs observed (JZ not taken correctly)", uart_count);
        else begin
            $display("  *** FAIL: Only %0d UART outputs (expected >= 3)", uart_count);
            test_failed = 1;
        end

        // -------------------------------------------------------------------
        // TEST 9: JZ (taken) — OUT at addresses 13 and 14 must be skipped
        //   uart_count should be exactly 3 (no extra prints after JZ taken)
        // -------------------------------------------------------------------
        $display("\n[TEST 9] JZ taken check — OUT at addresses 13/14 must be SKIPPED");
        if (uart_count === 3)
            $display("  PASS: UART count = 3 (no spurious output after JZ)");
        else begin
            $display("  *** FAIL: UART count = %0d (expected exactly 3)", uart_count);
            test_failed = 1;
        end

        // -------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------
        $display("\n============================================================");
        if (!test_failed)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED — see above");
        $display("============================================================\n");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Cycle-by-cycle monitor (optional debug trace)
    // -------------------------------------------------------------------------
    initial begin
        $display("Time  | PC | Instr | ACC  | ZF | alu_op | ctrl signals");
        $display("------|----+-------+------+----+--------+----------------------");
        forever begin
            @(posedge clk); #1;
            if (!reset)
                $display("%5t | %2d | 0x%02h  | 0x%02h | %b  |  %2b    | wr=%b mr=%b mw=%b pw=%b uart=%b",
                    $time,
                    dut.program_counter.pc_out,
                    dut.instruction,
                    dut.acc_data,
                    dut.zero_flag,
                    dut.alu_op,
                    dut.acc_write,
                    dut.mem_read,
                    dut.mem_write,
                    dut.pc_write,
                    dut.uart_send
                );
        end
    end

endmodule
