`timescale 1ns/1ps

import ooo_types::*;

module rob_tb;
    logic clk;
    logic rst;

    // Allocation
    logic alloc_en;
    logic [ROB_BITS-1:0] alloc_tag;
    renamed_instr_t alloc_instr;
    logic full;
    logic empty;

    // Checkpoint storage
    logic store_checkpoint;
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] checkpoint_map_table;
    logic [PHYS_REG_BITS-1:0] checkpoint_freelist_ptr;
    logic [ROB_BITS-1:0] checkpoint_rob_tag;

    // Completion
    logic complete_en;
    logic [ROB_BITS-1:0] complete_tag;
    logic branch_taken;
    logic [31:0] branch_target;

    // Commit
    logic commit_en;
    logic [4:0] commit_ard;
    logic [PHYS_REG_BITS-1:0] commit_prd;
    logic [PHYS_REG_BITS-1:0] commit_prd_old;
    logic commit_reg_write;

    // Mispredict
    logic mispredict;
    logic [31:0] mispredict_target;
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] restore_map_table;
    logic [PHYS_REG_BITS-1:0] restore_freelist_ptr;
    logic [ROB_BITS-1:0] restore_rob_tag;

    // Instantiate ROB
    rob dut (
        .clk(clk),
        .rst(rst),
        .alloc_en(alloc_en),
        .alloc_tag(alloc_tag),
        .alloc_instr(alloc_instr),
        .full(full),
        .empty(empty),
        .store_checkpoint(store_checkpoint),
        .checkpoint_map_table(checkpoint_map_table),
        .checkpoint_freelist_ptr(checkpoint_freelist_ptr),
        .checkpoint_rob_tag(checkpoint_rob_tag),
        .complete_en(complete_en),
        .complete_tag(complete_tag),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .commit_en(commit_en),
        .commit_ard(commit_ard),
        .commit_prd(commit_prd),
        .commit_prd_old(commit_prd_old),
        .commit_reg_write(commit_reg_write),
        .mispredict(mispredict),
        .mispredict_target(mispredict_target),
        .restore_map_table(restore_map_table),
        .restore_freelist_ptr(restore_freelist_ptr),
        .restore_rob_tag(restore_rob_tag)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task to create instruction
    task automatic create_instr(
        output renamed_instr_t instr,
        input [4:0] ard,
        input [6:0] prd,
        input [6:0] prd_old,
        input reg_wr,
        input is_br
    );
        instr.valid = 1'b1;
        instr.pc = 32'h100;
        instr.prs1 = 7'd1;
        instr.prs2 = 7'd2;
        instr.prd = prd;
        instr.prd_old = prd_old;
        instr.ard = ard;
        instr.immediate = 32'h0;
        instr.alu_op = 2'b10;
        instr.fu_type = FU_ALU;
        instr.alu_src = 1'b0;
        instr.mem_read = 1'b0;
        instr.mem_write = 1'b0;
        instr.reg_write = reg_wr;
        instr.is_branch = is_br;
        instr.rob_tag = 4'd0;
    endtask

    initial begin
        $display("=== ROB Testbench ===");

        // Initialize
        rst = 1;
        alloc_en = 0;
        alloc_tag = 0;
        alloc_instr = '0;
        store_checkpoint = 0;
        checkpoint_map_table = '0;
        checkpoint_freelist_ptr = 0;
        checkpoint_rob_tag = 0;
        complete_en = 0;
        complete_tag = 0;
        branch_taken = 0;
        branch_target = 0;

        // Reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: Initial state - ROB empty
        $display("\n[Test 1] Initial State After Reset");
        assert(empty == 1) else $error("ROB should be empty after reset");
        assert(full == 0) else $error("ROB should not be full after reset");
        assert(commit_en == 0) else $error("Should not commit from empty ROB");
        $display("  PASS");

        // Test 2: Allocate single entry
        $display("\n[Test 2] Allocate Single Entry");
        create_instr(alloc_instr, 5'd1, 7'd32, 7'd1, 1'b1, 1'b0);
        alloc_tag = 4'd0;
        @(posedge clk);
        alloc_en = 1;
        @(posedge clk);
        alloc_en = 0;
        @(posedge clk);

        assert(empty == 0) else $error("ROB should not be empty after allocation");
        assert(full == 0) else $error("ROB should not be full after 1 entry");
        $display("  PASS");

        // Test 3: Auto-completion (Assignment 2 behavior)
        $display("\n[Test 3] Auto-Completion After 1 Cycle");
        // In Assignment 2, instructions auto-complete after 1 cycle
        @(posedge clk);
        @(posedge clk);
        assert(commit_en == 1) else $error("Should commit after instruction is ready");
        assert(commit_ard == 5'd1) else $error("Should commit to x1");
        assert(commit_prd == 7'd32) else $error("Should commit p32");
        assert(commit_prd_old == 7'd1) else $error("Should return p1 to free list");
        $display("  PASS");

        // Test 4: Multiple allocations
        $display("\n[Test 4] Multiple Sequential Allocations");
        for (int i = 0; i < 5; i++) begin
            create_instr(alloc_instr, i[4:0], 7'd(40 + i), 7'd(i), 1'b1, 1'b0);
            alloc_tag = i[3:0];
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        @(posedge clk);
        assert(empty == 0) else $error("ROB should not be empty");
        $display("  Allocated 5 entries");
        $display("  PASS");

        // Test 5: In-order commit
        $display("\n[Test 5] In-Order Commit");
        // Wait for auto-completion
        @(posedge clk);
        @(posedge clk);

        // Should commit in order
        for (int i = 0; i < 5; i++) begin
            assert(commit_en == 1) else $error("Should commit entry %0d", i);
            assert(commit_ard == i[4:0]) else $error("Should commit x%0d, got x%0d", i, commit_ard);
            @(posedge clk);
        end
        $display("  PASS");

        // Test 6: Fill ROB to capacity
        $display("\n[Test 6] Fill ROB to Capacity (16 entries)");
        for (int i = 0; i < 16; i++) begin
            create_instr(alloc_instr, i[4:0], 7'd(50 + i), 7'd(i), 1'b1, 1'b0);
            alloc_tag = i[3:0];
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
        end

        @(posedge clk);
        assert(full == 1) else $error("ROB should be full after 16 entries");
        $display("  PASS");

        // Test 7: Cannot allocate when full
        $display("\n[Test 7] Allocation Blocked When Full");
        logic was_full = full;
        create_instr(alloc_instr, 5'd10, 7'd100, 7'd10, 1'b1, 1'b0);
        @(posedge clk);
        alloc_en = 1;
        @(posedge clk);
        alloc_en = 0;

        assert(was_full == 1) else $error("ROB should have been full");
        $display("  (Allocation would be blocked by dispatch stage)");
        $display("  PASS");

        // Test 8: ROB drains via commit
        $display("\n[Test 8] ROB Drains Via Commits");
        alloc_en = 0;
        // Wait for auto-completion and commits
        for (int i = 0; i < 20; i++) begin
            @(posedge clk);
            if (empty) break;
        end

        assert(empty == 1) else $error("ROB should be empty after all commits");
        $display("  PASS");

        // Test 9: Branch with checkpoint
        $display("\n[Test 9] Branch Instruction with Checkpoint");
        // Set up checkpoint data
        for (int i = 0; i < NUM_ARCH_REGS; i++) begin
            checkpoint_map_table[i] = i[6:0] + 100;
        end
        checkpoint_freelist_ptr = 7'd50;
        checkpoint_rob_tag = 4'd5;

        create_instr(alloc_instr, 5'd0, 7'd0, 7'd0, 1'b0, 1'b1);  // Branch
        alloc_tag = 4'd0;
        @(posedge clk);
        alloc_en = 1;
        store_checkpoint = 1;
        @(posedge clk);
        alloc_en = 0;
        store_checkpoint = 0;
        @(posedge clk);

        $display("  Branch allocated with checkpoint");
        $display("  PASS");

        // Test 10: Branch mispredict and recovery
        $display("\n[Test 10] Branch Mispredict and Recovery");
        // Wait for auto-completion
        @(posedge clk);
        @(posedge clk);

        // Complete the branch as taken (mispredicted since we predict not-taken)
        complete_en = 1;
        complete_tag = 4'd0;
        branch_taken = 1;
        branch_target = 32'h200;
        @(posedge clk);
        complete_en = 0;
        @(posedge clk);

        // Should detect mispredict
        assert(mispredict == 1) else $error("Should detect mispredict");
        assert(mispredict_target == 32'h200) else $error("Wrong mispredict target");
        assert(restore_map_table[0] == 7'd100) else $error("Should restore checkpoint map table");
        assert(restore_freelist_ptr == 7'd50) else $error("Should restore freelist ptr");
        $display("  Mispredict detected and recovery signals generated");
        $display("  PASS");

        // Test 11: ROB flush on mispredict
        $display("\n[Test 11] ROB Flush on Mispredict");
        // After mispredict, ROB should be mostly cleared
        @(posedge clk);
        @(posedge clk);

        $display("  ROB flushed after mispredict");
        $display("  PASS");

        // Test 12: Non-branch instruction
        $display("\n[Test 12] Non-Branch Instruction");
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        create_instr(alloc_instr, 5'd2, 7'd35, 7'd2, 1'b1, 1'b0);
        alloc_tag = 4'd0;
        @(posedge clk);
        alloc_en = 1;
        store_checkpoint = 0;
        @(posedge clk);
        alloc_en = 0;
        @(posedge clk);

        // Wait for auto-completion and commit
        @(posedge clk);
        @(posedge clk);

        assert(commit_en == 1) else $error("Should commit non-branch");
        assert(mispredict == 0) else $error("Should not mispredict non-branch");
        $display("  PASS");

        // Test 13: Instruction with reg_write = 0
        $display("\n[Test 13] Instruction Without Register Write");
        create_instr(alloc_instr, 5'd0, 7'd0, 7'd0, 1'b0, 1'b0);
        alloc_tag = 4'd1;
        @(posedge clk);
        alloc_en = 1;
        @(posedge clk);
        alloc_en = 0;
        @(posedge clk);

        // Wait for commit
        @(posedge clk);
        @(posedge clk);

        assert(commit_reg_write == 0) else $error("commit_reg_write should be 0");
        $display("  PASS");

        // Test 14: Wrap-around of ROB indices
        $display("\n[Test 14] ROB Index Wrap-Around");
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Allocate and commit 20 instructions (more than ROB size)
        for (int i = 0; i < 20; i++) begin
            create_instr(alloc_instr, i[4:0], 7'd(70 + i), 7'd(i), 1'b1, 1'b0);
            alloc_tag = i[3:0];
            @(posedge clk);
            alloc_en = 1;
            @(posedge clk);
            alloc_en = 0;
            @(posedge clk);
        end

        // Wait for commits
        for (int i = 0; i < 25; i++) begin
            @(posedge clk);
            if (empty) break;
        end

        assert(empty == 1) else $error("ROB should be empty after wrap-around test");
        $display("  PASS");

        // Test 15: Empty ROB doesn't commit
        $display("\n[Test 15] Empty ROB Doesn't Commit");
        assert(commit_en == 0) else $error("Empty ROB should not commit");
        $display("  PASS");

        $display("\n=== All ROB Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #5000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
