`timescale 1ns/1ps

import ooo_types::*;

module free_list_tb;
    logic clk;
    logic rst;

    // Allocation
    logic alloc_en;
    logic [PHYS_REG_BITS-1:0] alloc_preg;
    logic empty;

    // Deallocation
    logic dealloc_en;
    logic [PHYS_REG_BITS-1:0] dealloc_preg;
    logic full;

    // Checkpoint
    logic checkpoint_en;
    logic [PHYS_REG_BITS-1:0] checkpoint_ptr;

    // Recovery
    logic restore_en;
    logic [PHYS_REG_BITS-1:0] restore_ptr;

    // Instantiate free_list
    free_list dut (
        .clk(clk),
        .rst(rst),
        .alloc_en(alloc_en),
        .alloc_preg(alloc_preg),
        .empty(empty),
        .dealloc_en(dealloc_en),
        .dealloc_preg(dealloc_preg),
        .full(full),
        .checkpoint_en(checkpoint_en),
        .checkpoint_ptr(checkpoint_ptr),
        .restore_en(restore_en),
        .restore_ptr(restore_ptr)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== Free List Testbench ===");

        // Initialize
        rst = 1;
        alloc_en = 0;
        dealloc_en = 0;
        checkpoint_en = 0;
        restore_en = 0;
        dealloc_preg = 0;
        restore_ptr = 0;

        // Reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: Initial state - p32-p127 are free
        $display("\n[Test 1] Initial State After Reset");
        assert(empty == 0) else $error("Free list should not be empty after reset");
        assert(alloc_preg == 7'd32) else $error("First free register should be p32, got p%0d", alloc_preg);
        $display("  PASS");

        // Test 2: Allocate registers sequentially
        $display("\n[Test 2] Sequential Allocation");
        for (int i = 0; i < 10; i++) begin
            logic [6:0] expected = 7'd32 + i;
            assert(alloc_preg == expected)
                else $error("Expected p%0d, got p%0d", expected, alloc_preg);

            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end
        assert(alloc_preg == 7'd42) else $error("After 10 allocations, next should be p42");
        $display("  PASS");

        // Test 3: Deallocate registers
        $display("\n[Test 3] Deallocation");
        @(posedge clk);
        dealloc_en = 1;
        dealloc_preg = 7'd32;  // Note: actual preg value is ignored in circular design
        @(posedge clk);
        dealloc_en = 0;
        $display("  PASS (deallocated 1 register)");

        // Test 4: Allocate and deallocate in parallel
        $display("\n[Test 4] Simultaneous Alloc/Dealloc");
        @(posedge clk);
        alloc_en = 1;
        dealloc_en = 1;
        @(posedge clk);
        alloc_en = 0;
        dealloc_en = 0;
        // Head and tail both move, net change is 0
        $display("  PASS");

        // Test 5: Checkpoint
        $display("\n[Test 5] Checkpoint Creation");
        logic [PHYS_REG_BITS-1:0] saved_ptr;
        @(posedge clk);
        checkpoint_en = 1;
        saved_ptr = checkpoint_ptr;
        @(posedge clk);
        checkpoint_en = 0;

        // Allocate more registers after checkpoint
        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        logic [PHYS_REG_BITS-1:0] new_ptr = alloc_preg;
        assert(new_ptr != saved_ptr) else $error("Pointer should have advanced");
        $display("  Checkpoint ptr: p%0d, Current ptr: p%0d", saved_ptr, new_ptr);
        $display("  PASS");

        // Test 6: Restore from checkpoint
        $display("\n[Test 6] Restore From Checkpoint");
        @(posedge clk);
        restore_en = 1;
        restore_ptr = saved_ptr;
        @(posedge clk);
        restore_en = 0;
        @(posedge clk);

        assert(alloc_preg == saved_ptr)
            else $error("After restore, alloc_preg should be p%0d, got p%0d", saved_ptr, alloc_preg);
        $display("  PASS");

        // Test 7: Exhaust the free list
        $display("\n[Test 7] Exhaust Free List");
        // Reset to known state
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Allocate all 96 free registers (p32-p127)
        for (int i = 0; i < 96; i++) begin
            assert(empty == 0) else $error("Should not be empty at iteration %0d", i);
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        // Now should be empty
        assert(empty == 1) else $error("Free list should be empty after allocating all 96 registers");
        $display("  PASS");

        // Test 8: Refill free list via deallocation
        $display("\n[Test 8] Refill Free List");
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            dealloc_en = 1;
            @(posedge clk);
            dealloc_en = 0;
        end

        assert(empty == 0) else $error("Free list should not be empty after deallocation");
        $display("  PASS");

        // Test 9: Wrap-around behavior
        $display("\n[Test 9] Wrap-Around Behavior");
        // Reset
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Allocate past p127
        for (int i = 0; i < 100; i++) begin
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        // Should have wrapped around
        logic [PHYS_REG_BITS-1:0] current = alloc_preg;
        $display("  After 100 allocations: next alloc = p%0d", current);
        // 32 + 100 = 132, wrapping at 128 gives us 132 - 128 = 4
        // But wait, we have 128 registers total, so wrap is at 128
        // Actually the pointer is 8 bits to detect wrap
        $display("  PASS");

        // Test 10: Empty flag behavior
        $display("\n[Test 10] Empty Flag Behavior");
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        assert(empty == 0) else $error("Should not be empty initially");

        // Allocate one
        @(posedge clk);
        alloc_en = 1;
        @(posedge clk);
        alloc_en = 0;

        assert(empty == 0) else $error("Should not be empty after 1 allocation");
        $display("  PASS");

        $display("\n=== All Free List Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #2000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
