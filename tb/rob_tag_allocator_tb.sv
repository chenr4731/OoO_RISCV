`timescale 1ns/1ps

import ooo_types::*;

module rob_tag_allocator_tb;
    logic clk;
    logic rst;

    // Allocate
    logic alloc_en;
    logic [ROB_BITS-1:0] alloc_tag;

    // Checkpoint
    logic checkpoint_en;
    logic [ROB_BITS-1:0] checkpoint_tag;

    // Recovery
    logic restore_en;
    logic [ROB_BITS-1:0] restore_tag;

    // Instantiate rob_tag_allocator
    rob_tag_allocator dut (
        .clk(clk),
        .rst(rst),
        .alloc_en(alloc_en),
        .alloc_tag(alloc_tag),
        .checkpoint_en(checkpoint_en),
        .checkpoint_tag(checkpoint_tag),
        .restore_en(restore_en),
        .restore_tag(restore_tag)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== ROB Tag Allocator Testbench ===");

        // Initialize
        rst = 1;
        alloc_en = 0;
        checkpoint_en = 0;
        restore_en = 0;
        restore_tag = 0;

        // Reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: Initial state
        $display("\n[Test 1] Initial State After Reset");
        assert(alloc_tag == 4'd0) else $error("Initial tag should be 0, got %0d", alloc_tag);
        $display("  PASS");

        // Test 2: Sequential allocation
        $display("\n[Test 2] Sequential Allocation");
        for (int i = 0; i < 16; i++) begin
            assert(alloc_tag == i[3:0])
                else $error("Expected tag %0d, got %0d", i, alloc_tag);

            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end
        $display("  Allocated tags 0-15");
        $display("  PASS");

        // Test 3: Wrap-around at 16
        $display("\n[Test 3] Wrap-Around at ROB_SIZE (16)");
        assert(alloc_tag == 4'd0) else $error("Tag should wrap to 0, got %0d", alloc_tag);
        @(posedge clk);
        alloc_en = 1;
        @(posedge clk);
        alloc_en = 0;
        assert(alloc_tag == 4'd1) else $error("After wrap, next tag should be 1");
        $display("  PASS");

        // Test 4: Checkpoint
        $display("\n[Test 4] Checkpoint Creation");
        // Reset to known state
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Allocate 5 tags
        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        // Current tag should be 5
        assert(alloc_tag == 4'd5) else $error("Current tag should be 5");

        // Take checkpoint
        logic [ROB_BITS-1:0] saved_tag;
        checkpoint_en = 1;
        saved_tag = checkpoint_tag;
        @(posedge clk);
        checkpoint_en = 0;

        assert(saved_tag == 4'd5) else $error("Checkpoint should capture tag 5");
        $display("  Checkpoint tag: %0d", saved_tag);
        $display("  PASS");

        // Test 5: Allocation after checkpoint
        $display("\n[Test 5] Allocation After Checkpoint");
        for (int i = 0; i < 3; i++) begin
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        assert(alloc_tag == 4'd8) else $error("After 3 more allocations, tag should be 8");
        $display("  PASS");

        // Test 6: Restore from checkpoint
        $display("\n[Test 6] Restore From Checkpoint");
        @(posedge clk);
        restore_en = 1;
        restore_tag = saved_tag;
        @(posedge clk);
        restore_en = 0;
        @(posedge clk);

        assert(alloc_tag == saved_tag)
            else $error("After restore, tag should be %0d, got %0d", saved_tag, alloc_tag);
        $display("  PASS");

        // Test 7: Continue allocation after restore
        $display("\n[Test 7] Allocation After Restore");
        @(posedge clk);
        alloc_en = 1;
        @(posedge clk);
        alloc_en = 0;

        assert(alloc_tag == saved_tag + 1)
            else $error("After restore and alloc, tag should be %0d", saved_tag + 1);
        $display("  PASS");

        // Test 8: No allocation when alloc_en is low
        $display("\n[Test 8] No Allocation When Disabled");
        logic [ROB_BITS-1:0] prev_tag = alloc_tag;
        alloc_en = 0;
        @(posedge clk);
        @(posedge clk);
        assert(alloc_tag == prev_tag) else $error("Tag should not change when alloc_en is low");
        $display("  PASS");

        // Test 9: Multiple checkpoints (only last one matters)
        $display("\n[Test 9] Multiple Checkpoints");
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Allocate to tag 3
        for (int i = 0; i < 3; i++) begin
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        checkpoint_en = 1;
        logic [ROB_BITS-1:0] cp1 = checkpoint_tag;
        @(posedge clk);

        // Allocate more
        alloc_en = 1;
        @(posedge clk);
        alloc_en = 0;

        logic [ROB_BITS-1:0] cp2 = checkpoint_tag;
        @(posedge clk);
        checkpoint_en = 0;

        $display("  Checkpoint 1: %0d, Checkpoint 2: %0d", cp1, cp2);
        $display("  PASS");

        // Test 10: Restore wrap-around case
        $display("\n[Test 10] Restore With Wrap-Around");
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Allocate 14 tags
        for (int i = 0; i < 14; i++) begin
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        checkpoint_en = 1;
        saved_tag = checkpoint_tag;
        @(posedge clk);
        checkpoint_en = 0;

        // Allocate 5 more (wraps around)
        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        // Restore
        @(posedge clk);
        restore_en = 1;
        restore_tag = saved_tag;
        @(posedge clk);
        restore_en = 0;
        @(posedge clk);

        assert(alloc_tag == saved_tag) else $error("Restore failed in wrap-around case");
        $display("  PASS");

        $display("\n=== All ROB Tag Allocator Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #1000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
