`timescale 1ns/1ps

module fetch_tb;
    logic clk;
    logic reset;
    logic take_branch;
    logic [31:0] branch_loc;
    logic [31:0] instr_from_cache;
    logic [31:0] pc_to_cache;
    logic [31:0] instr_to_decode;
    logic [31:0] pc_to_decode;
    logic ready;
    logic valid;

    // Instantiate fetch module
    fetch dut (
        .clk(clk),
        .reset(reset),
        .take_branch(take_branch),
        .branch_loc(branch_loc),
        .instr_from_cache(instr_from_cache),
        .pc_to_cache(pc_to_cache),
        .instr_to_decode(instr_to_decode),
        .pc_to_decode(pc_to_decode),
        .ready(ready),
        .valid(valid)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        $display("=== Fetch Stage Testbench ===");

        // Initialize signals
        reset = 1;
        take_branch = 0;
        branch_loc = 32'h0;
        instr_from_cache = 32'hDEADBEEF;
        ready = 1;

        // Reset
        #10;
        reset = 0;
        #10;

        // Test 1: Normal sequential fetch
        $display("\n[Test 1] Normal Sequential Fetch");
        instr_from_cache = 32'h12345678;
        #10;
        assert(pc_to_cache == 32'h0) else $error("PC should be 0");
        assert(valid == 1) else $error("Valid should be high after reset");

        #10;
        assert(pc_to_cache == 32'h4) else $error("PC should increment to 4");

        #10;
        assert(pc_to_cache == 32'h8) else $error("PC should increment to 8");

        // Test 2: Stall when ready is low
        $display("\n[Test 2] Stall on Backpressure");
        ready = 0;
        #10;
        logic [31:0] stalled_pc = pc_to_cache;
        #10;
        assert(pc_to_cache == stalled_pc) else $error("PC should not change during stall");

        // Release stall
        ready = 1;
        #10;
        assert(pc_to_cache == stalled_pc + 4) else $error("PC should resume incrementing");

        // Test 3: Branch taken
        $display("\n[Test 3] Branch Taken");
        take_branch = 1;
        branch_loc = 32'h100;
        #10;
        take_branch = 0;
        assert(pc_to_cache == 32'h100) else $error("PC should jump to branch target");

        #10;
        assert(pc_to_cache == 32'h104) else $error("PC should continue from branch target");

        // Test 4: Multiple branches
        $display("\n[Test 4] Multiple Branches");
        take_branch = 1;
        branch_loc = 32'h200;
        #10;
        branch_loc = 32'h300;
        #10;
        take_branch = 0;
        assert(pc_to_cache == 32'h300) else $error("PC should be at second branch target");

        // Test 5: Reset during operation
        $display("\n[Test 5] Reset During Operation");
        #20;
        reset = 1;
        #10;
        reset = 0;
        #10;
        assert(pc_to_cache == 32'h0) else $error("PC should reset to 0");

        $display("\n=== All Fetch Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #1000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
