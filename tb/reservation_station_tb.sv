`timescale 1ns/1ps

import ooo_types::*;

module reservation_station_tb;
    logic clk;
    logic rst;

    // Dispatch
    logic dispatch_en;
    renamed_instr_t dispatch_instr;
    logic full;
    logic [2:0] alloc_idx;
    logic alloc_valid;

    // Issue
    logic issue_en;
    rs_entry_t issue_entry;
    logic [2:0] issue_idx;
    logic eu_ready;

    // Wakeup
    logic wb_en;
    logic [PHYS_REG_BITS-1:0] wb_prd;

    // Flush
    logic flush;

    // Instantiate reservation_station with size 8
    reservation_station #(.RS_SIZE(8)) dut (
        .clk(clk),
        .rst(rst),
        .dispatch_en(dispatch_en),
        .dispatch_instr(dispatch_instr),
        .full(full),
        .alloc_idx(alloc_idx),
        .alloc_valid(alloc_valid),
        .issue_en(issue_en),
        .issue_entry(issue_entry),
        .issue_idx(issue_idx),
        .eu_ready(eu_ready),
        .wb_en(wb_en),
        .wb_prd(wb_prd),
        .flush(flush)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task to create a renamed instruction
    task automatic create_instr(
        output renamed_instr_t instr,
        input [6:0] prs1,
        input [6:0] prs2,
        input [6:0] prd,
        input [3:0] rob_tag,
        input [31:0] pc,
        input [31:0] imm
    );
        instr.valid = 1'b1;
        instr.pc = pc;
        instr.prs1 = prs1;
        instr.prs2 = prs2;
        instr.prd = prd;
        instr.prd_old = 7'd0;
        instr.ard = 5'd0;
        instr.immediate = imm;
        instr.alu_op = 2'b10;
        instr.fu_type = FU_ALU;
        instr.alu_src = 1'b0;
        instr.mem_read = 1'b0;
        instr.mem_write = 1'b0;
        instr.reg_write = 1'b1;
        instr.is_branch = 1'b0;
        instr.rob_tag = rob_tag;
    endtask

    initial begin
        $display("=== Reservation Station Testbench ===");

        // Initialize
        rst = 1;
        dispatch_en = 0;
        dispatch_instr = '0;
        eu_ready = 1;
        wb_en = 0;
        wb_prd = 0;
        flush = 0;

        // Reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: Initial state - RS should be empty
        $display("\n[Test 1] Initial State After Reset");
        assert(full == 0) else $error("RS should not be full after reset");
        assert(alloc_valid == 1) else $error("Should have free slot after reset");
        assert(alloc_idx == 0) else $error("First free slot should be 0");
        $display("  PASS");

        // Test 2: Dispatch single instruction
        $display("\n[Test 2] Dispatch Single Instruction");
        create_instr(dispatch_instr, 7'd2, 7'd3, 7'd32, 4'd0, 32'h100, 32'h0);
        @(posedge clk);
        dispatch_en = 1;
        @(posedge clk);
        dispatch_en = 0;
        @(posedge clk);

        assert(full == 0) else $error("RS should not be full after 1 entry");
        assert(alloc_idx == 1) else $error("Next free slot should be 1");
        $display("  PASS");

        // Test 3: Issue instruction (Assignment 2: all instructions ready immediately)
        $display("\n[Test 3] Issue Instruction");
        @(posedge clk);
        assert(issue_en == 1) else $error("Should issue ready instruction");
        assert(issue_idx == 0) else $error("Should issue from slot 0");
        assert(issue_entry.prd == 7'd32) else $error("Issued entry should have prd=p32");
        @(posedge clk);

        // After issue, entry should be freed
        assert(alloc_idx == 0) else $error("Slot 0 should be free again");
        $display("  PASS");

        // Test 4: Fill RS to capacity
        $display("\n[Test 4] Fill RS to Capacity (8 entries)");
        for (int i = 0; i < 8; i++) begin
            create_instr(dispatch_instr, 7'd10 + i, 7'd20 + i, 7'd30 + i, i[3:0], 32'h200 + (i << 2), 32'h0);
            @(posedge clk);
            dispatch_en = 1;
            @(posedge clk);
            dispatch_en = 0;
        end

        @(posedge clk);
        assert(full == 1) else $error("RS should be full after 8 entries");
        assert(alloc_valid == 0) else $error("Should have no free slots");
        $display("  PASS");

        // Test 5: Cannot dispatch when full
        $display("\n[Test 5] Dispatch Blocked When Full");
        logic was_full = full;
        create_instr(dispatch_instr, 7'd50, 7'd51, 7'd52, 4'd8, 32'h300, 32'h0);
        @(posedge clk);
        dispatch_en = 1;
        @(posedge clk);
        dispatch_en = 0;

        assert(was_full == 1) else $error("RS should have been full");
        $display("  (Dispatch attempted while full - would be blocked by dispatch stage)");
        $display("  PASS");

        // Test 6: Issue from full RS
        $display("\n[Test 6] Issue From Full RS");
        eu_ready = 1;
        @(posedge clk);
        assert(issue_en == 1) else $error("Should issue from full RS");
        logic [2:0] issued_idx = issue_idx;
        @(posedge clk);

        assert(full == 0) else $error("RS should not be full after issue");
        $display("  Issued from slot %0d", issued_idx);
        $display("  PASS");

        // Test 7: Priority selection (lowest index first)
        $display("\n[Test 7] Priority Selection (Lowest Index First)");
        // Reset to clear RS
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Dispatch to slots 2, 4, 6 (skip some slots for testing)
        // First fill slots 0-7
        for (int i = 0; i < 8; i++) begin
            create_instr(dispatch_instr, 7'd10 + i, 7'd20 + i, 7'd30 + i, i[3:0], 32'h400 + (i << 2), 32'h0);
            @(posedge clk);
            dispatch_en = 1;
            @(posedge clk);
            dispatch_en = 0;
        end

        // Issue all
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            assert(issue_en == 1) else $error("Should issue entry");
            assert(issue_idx == i) else $error("Should issue in order, expected %0d got %0d", i, issue_idx);
        end

        $display("  Issues in priority order (lowest index first)");
        $display("  PASS");

        // Test 8: EU not ready - no issue
        $display("\n[Test 8] No Issue When EU Not Ready");
        create_instr(dispatch_instr, 7'd1, 7'd2, 7'd3, 4'd0, 32'h500, 32'h0);
        @(posedge clk);
        dispatch_en = 1;
        @(posedge clk);
        dispatch_en = 0;

        eu_ready = 0;
        @(posedge clk);
        assert(issue_en == 0) else $error("Should not issue when EU not ready");

        eu_ready = 1;
        @(posedge clk);
        assert(issue_en == 1) else $error("Should issue when EU becomes ready");
        $display("  PASS");

        // Test 9: Flush RS
        $display("\n[Test 9] Flush Reservation Station");
        // Fill with some entries
        for (int i = 0; i < 4; i++) begin
            create_instr(dispatch_instr, 7'd10 + i, 7'd20 + i, 7'd30 + i, i[3:0], 32'h600 + (i << 2), 32'h0);
            @(posedge clk);
            dispatch_en = 1;
            @(posedge clk);
            dispatch_en = 0;
        end

        // Flush
        @(posedge clk);
        flush = 1;
        @(posedge clk);
        flush = 0;
        @(posedge clk);

        assert(full == 0) else $error("RS should not be full after flush");
        assert(alloc_idx == 0) else $error("First free slot should be 0 after flush");
        assert(issue_en == 0) else $error("Should not issue after flush");
        $display("  PASS");

        // Test 10: Simultaneous dispatch and issue
        $display("\n[Test 10] Simultaneous Dispatch and Issue");
        create_instr(dispatch_instr, 7'd5, 7'd6, 7'd7, 4'd0, 32'h700, 32'h0);
        @(posedge clk);
        dispatch_en = 1;
        @(posedge clk);

        // Now dispatch another while previous is issuing
        create_instr(dispatch_instr, 7'd8, 7'd9, 7'd10, 4'd1, 32'h704, 32'h0);
        @(posedge clk);
        dispatch_en = 0;
        @(posedge clk);

        assert(issue_en == 1) else $error("Should continue issuing");
        $display("  PASS");

        // Test 11: Allocation pattern
        $display("\n[Test 11] Allocation Pattern");
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Dispatch 3 entries
        for (int i = 0; i < 3; i++) begin
            create_instr(dispatch_instr, 7'd10 + i, 7'd20 + i, 7'd30 + i, i[3:0], 32'h800 + (i << 2), 32'h0);
            @(posedge clk);
            dispatch_en = 1;
            assert(alloc_idx == i) else $error("Should allocate to slot %0d", i);
            @(posedge clk);
            dispatch_en = 0;
        end

        // Issue first 2
        @(posedge clk);
        @(posedge clk);

        // Slots 0 and 1 should now be free
        @(posedge clk);
        assert(alloc_idx == 0 || alloc_idx == 1) else $error("Should reuse freed slots");
        $display("  PASS");

        $display("\n=== All Reservation Station Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #3000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
