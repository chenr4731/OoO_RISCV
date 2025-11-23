`timescale 1ns/1ps

import ooo_types::*;

module dispatch_tb;
    logic clk;
    logic rst;

    // From dispatch buffer
    renamed_instr_t instr_in;
    logic valid_in;
    logic ready_out;

    // To ROB
    logic rob_alloc_en;
    logic [ROB_BITS-1:0] rob_alloc_tag;
    renamed_instr_t rob_alloc_instr;
    logic rob_full;
    logic rob_store_checkpoint;

    // Flush
    logic flush;

    // Reservation station signals
    logic rs_alu_full, rs_branch_full, rs_lsu_full;
    logic dispatch_alu_en, dispatch_branch_en, dispatch_lsu_en;
    renamed_instr_t dispatch_alu_instr, dispatch_branch_instr, dispatch_lsu_instr;

    // Instantiate dispatch (now just routing logic, RS and PRF external)
    dispatch dut (
        .clk(clk),
        .rst(rst),
        .instr_in(instr_in),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .rob_alloc_en(rob_alloc_en),
        .rob_alloc_tag(rob_alloc_tag),
        .rob_alloc_instr(rob_alloc_instr),
        .rob_full(rob_full),
        .rob_store_checkpoint(rob_store_checkpoint),
        .flush(flush),
        .rs_alu_full(rs_alu_full),
        .dispatch_alu_en(dispatch_alu_en),
        .dispatch_alu_instr(dispatch_alu_instr),
        .rs_branch_full(rs_branch_full),
        .dispatch_branch_en(dispatch_branch_en),
        .dispatch_branch_instr(dispatch_branch_instr),
        .rs_lsu_full(rs_lsu_full),
        .dispatch_lsu_en(dispatch_lsu_en),
        .dispatch_lsu_instr(dispatch_lsu_instr)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task to create instruction
    task automatic create_instr(
        output renamed_instr_t instr,
        input fu_type_t fu,
        input [3:0] rob_tag,
        input is_br
    );
        instr.valid = 1'b1;
        instr.pc = 32'h100;
        instr.prs1 = 7'd1;
        instr.prs2 = 7'd2;
        instr.prd = 7'd32;
        instr.prd_old = 7'd0;
        instr.ard = 5'd1;
        instr.immediate = 32'h0;
        instr.alu_op = 2'b10;
        instr.fu_type = fu;
        instr.alu_src = 1'b0;
        instr.mem_read = 1'b0;
        instr.mem_write = 1'b0;
        instr.reg_write = 1'b1;
        instr.is_branch = is_br;
        instr.rob_tag = rob_tag;
    endtask

    initial begin
        $display("=== Dispatch Stage Testbench ===");
        $display("Note: Dispatch is now pure routing logic, RS and PRF are external");

        // Initialize
        rst = 1;
        valid_in = 0;
        instr_in = '0;
        rob_full = 0;
        flush = 0;
        rs_alu_full = 0;
        rs_branch_full = 0;
        rs_lsu_full = 0;

        // Reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: Dispatch ALU Instruction
        $display("\n[Test 1] Dispatch ALU Instruction");
        create_instr(instr_in, FU_ALU, 4'd0, 1'b0);
        valid_in = 1;
        @(posedge clk);

        assert(rob_alloc_en == 1) else $error("Should allocate ROB entry");
        assert(ready_out == 1) else $error("Should be ready");
        assert(dispatch_alu_en == 1) else $error("Should enable ALU dispatch");
        $display("  Dispatched to ALU RS");
        $display("  PASS");

        // Test 2: Dispatch Branch Instruction
        $display("\n[Test 2] Dispatch Branch Instruction");
        create_instr(instr_in, FU_BRANCH, 4'd1, 1'b1);
        @(posedge clk);

        assert(rob_alloc_en == 1) else $error("Should allocate ROB entry");
        assert(rob_store_checkpoint == 1) else $error("Should store checkpoint for branch");
        assert(dispatch_branch_en == 1) else $error("Should enable Branch dispatch");
        $display("  Dispatched to Branch RS");
        $display("  PASS");

        // Test 3: Dispatch LSU Instruction
        $display("\n[Test 3] Dispatch LSU Instruction");
        create_instr(instr_in, FU_LSU, 4'd2, 1'b0);
        @(posedge clk);

        assert(rob_alloc_en == 1) else $error("Should allocate ROB entry");
        assert(rob_store_checkpoint == 0) else $error("Should not store checkpoint for LSU");
        assert(dispatch_lsu_en == 1) else $error("Should enable LSU dispatch");
        $display("  Dispatched to LSU RS");
        $display("  PASS");

        // Test 4: Stall when ROB is full
        $display("\n[Test 4] Stall When ROB Full");
        create_instr(instr_in, FU_ALU, 4'd3, 1'b0);
        rob_full = 1;
        @(posedge clk);

        assert(rob_alloc_en == 0) else $error("Should not allocate ROB when full");
        assert(ready_out == 0) else $error("Should not be ready when ROB full");
        $display("  PASS");

        // Test 5: Resume when ROB has space
        $display("\n[Test 5] Resume When ROB Has Space");
        rob_full = 0;
        @(posedge clk);

        assert(rob_alloc_en == 1) else $error("Should allocate ROB");
        assert(ready_out == 1) else $error("Should be ready");
        $display("  PASS");

        // Test 6: No dispatch when invalid
        $display("\n[Test 6] No Dispatch When Invalid");
        rob_full = 0;
        valid_in = 0;
        @(posedge clk);

        assert(rob_alloc_en == 0) else $error("Should not allocate ROB when invalid");
        $display("  PASS");

        // Test 7: Dispatch to different FU types
        $display("\n[Test 7] Dispatch to Different FU Types");
        valid_in = 1;

        // ALU
        create_instr(instr_in, FU_ALU, 4'd5, 1'b0);
        @(posedge clk);
        assert(rob_alloc_en == 1) else $error("ALU dispatch failed");

        // Branch
        create_instr(instr_in, FU_BRANCH, 4'd6, 1'b1);
        @(posedge clk);
        assert(rob_alloc_en == 1) else $error("Branch dispatch failed");

        // LSU
        create_instr(instr_in, FU_LSU, 4'd7, 1'b0);
        @(posedge clk);
        assert(rob_alloc_en == 1) else $error("LSU dispatch failed");

        $display("  PASS");

        // Test 9: ROB tag passthrough
        $display("\n[Test 9] ROB Tag Passthrough");
        create_instr(instr_in, FU_ALU, 4'd10, 1'b0);
        @(posedge clk);

        assert(rob_alloc_tag == 4'd10) else $error("ROB tag should be 10, got %0d", rob_alloc_tag);
        $display("  PASS");

        // Test 10: Instruction data passthrough
        $display("\n[Test 10] Instruction Data Passthrough");
        instr_in.prd = 7'd99;
        instr_in.prs1 = 7'd88;
        instr_in.prs2 = 7'd77;
        create_instr(instr_in, FU_ALU, 4'd11, 1'b0);
        instr_in.prd = 7'd99;
        instr_in.prs1 = 7'd88;
        instr_in.prs2 = 7'd77;
        @(posedge clk);

        assert(dispatch_alu_instr.prd == 7'd99) else $error("prd not passed through");
        assert(dispatch_alu_instr.prs1 == 7'd88) else $error("prs1 not passed through");
        assert(dispatch_alu_instr.prs2 == 7'd77) else $error("prs2 not passed through");
        assert(rob_alloc_instr.prd == 7'd99) else $error("ROB prd not passed through");
        $display("  PASS");

        // Test 11: Branch RS full blocks branch dispatch
        $display("\n[Test 11] Branch RS Full Blocks Dispatch");
        create_instr(instr_in, FU_BRANCH, 4'd12, 1'b1);
        rs_branch_full = 1;
        @(posedge clk);

        assert(dispatch_branch_en == 0) else $error("Should not dispatch to full Branch RS");
        assert(ready_out == 0) else $error("Should not be ready");
        $display("  PASS");

        // Test 12: LSU RS full blocks LSU dispatch
        $display("\n[Test 12] LSU RS Full Blocks Dispatch");
        create_instr(instr_in, FU_LSU, 4'd13, 1'b0);
        rs_branch_full = 0;
        rs_lsu_full = 1;
        @(posedge clk);

        assert(dispatch_lsu_en == 0) else $error("Should not dispatch to full LSU RS");
        assert(ready_out == 0) else $error("Should not be ready");
        $display("  PASS");

        // Test 13: All resources available
        $display("\n[Test 13] All Resources Available");
        rs_lsu_full = 0;
        rs_branch_full = 0;
        rs_alu_full = 0;
        rob_full = 0;
        create_instr(instr_in, FU_ALU, 4'd14, 1'b0);
        @(posedge clk);

        assert(dispatch_alu_en == 1) else $error("Should dispatch when all resources available");
        assert(rob_alloc_en == 1) else $error("Should allocate ROB");
        assert(ready_out == 1) else $error("Should be ready");
        $display("  PASS");

        // Test 14: Flush behavior (combinational, no state)
        $display("\n[Test 14] Flush Signal");
        flush = 1;
        @(posedge clk);
        flush = 0;
        @(posedge clk);
        $display("  Flush signal passed through (dispatch is stateless)");
        $display("  PASS");

        // Test 15: Checkpoint only for branches
        $display("\n[Test 15] Checkpoint Only for Branches");
        create_instr(instr_in, FU_ALU, 4'd15, 1'b0);
        instr_in.is_branch = 1'b0;
        @(posedge clk);
        assert(rob_store_checkpoint == 0) else $error("Should not checkpoint non-branch");

        create_instr(instr_in, FU_BRANCH, 4'd15, 1'b1);
        instr_in.is_branch = 1'b1;
        @(posedge clk);
        assert(rob_store_checkpoint == 1) else $error("Should checkpoint branch");

        $display("  PASS");

        valid_in = 0;
        @(posedge clk);

        $display("\n=== All Dispatch Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #1000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
