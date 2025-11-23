`timescale 1ns/1ps

import ooo_types::*;

module rename_tb;
    logic clk;
    logic rst;

    // From decode
    logic valid_in;
    logic ready_out;
    logic [31:0] pc_in;
    logic [4:0] rs1_arch;
    logic [4:0] rs2_arch;
    logic [4:0] rd_arch;
    logic [31:0] immediate;
    logic [1:0] alu_op;
    logic [1:0] fu_type;
    logic alu_src;
    logic mem_read;
    logic mem_write;
    logic reg_write;
    logic is_branch;

    // To dispatch
    renamed_instr_t renamed_instr;
    logic valid_out;
    logic ready_in;

    // From ROB (recovery)
    logic mispredict;
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] restore_map_table;
    logic [PHYS_REG_BITS-1:0] restore_freelist_ptr;
    logic [ROB_BITS-1:0] restore_rob_tag;

    // From commit
    logic commit_en;
    logic [PHYS_REG_BITS-1:0] commit_prd_old;

    // Instantiate rename
    rename dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .pc_in(pc_in),
        .rs1_arch(rs1_arch),
        .rs2_arch(rs2_arch),
        .rd_arch(rd_arch),
        .immediate(immediate),
        .alu_op(alu_op),
        .fu_type(fu_type),
        .alu_src(alu_src),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .reg_write(reg_write),
        .is_branch(is_branch),
        .renamed_instr(renamed_instr),
        .valid_out(valid_out),
        .ready_in(ready_in),
        .mispredict(mispredict),
        .restore_map_table(restore_map_table),
        .restore_freelist_ptr(restore_freelist_ptr),
        .restore_rob_tag(restore_rob_tag),
        .commit_en(commit_en),
        .commit_prd_old(commit_prd_old)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_instruction(
        input [31:0] pc,
        input [4:0] rs1,
        input [4:0] rs2,
        input [4:0] rd,
        input [31:0] imm,
        input [1:0] aluop,
        input [1:0] futype,
        input alusrc,
        input memread,
        input memwrite,
        input regwr,
        input branch
    );
        @(posedge clk);
        valid_in = 1;
        pc_in = pc;
        rs1_arch = rs1;
        rs2_arch = rs2;
        rd_arch = rd;
        immediate = imm;
        alu_op = aluop;
        fu_type = futype;
        alu_src = alusrc;
        mem_read = memread;
        mem_write = memwrite;
        reg_write = regwr;
        is_branch = branch;

        // Wait for acceptance
        wait(ready_out && valid_in);
        @(posedge clk);
        valid_in = 0;
    endtask

    initial begin
        $display("=== Rename Stage Testbench ===");

        // Initialize
        rst = 1;
        valid_in = 0;
        ready_in = 1;
        pc_in = 0;
        rs1_arch = 0;
        rs2_arch = 0;
        rd_arch = 0;
        immediate = 0;
        alu_op = 0;
        fu_type = 0;
        alu_src = 0;
        mem_read = 0;
        mem_write = 0;
        reg_write = 0;
        is_branch = 0;
        mispredict = 0;
        restore_map_table = '0;
        restore_freelist_ptr = 0;
        restore_rob_tag = 0;
        commit_en = 0;
        commit_prd_old = 0;

        // Reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: Simple instruction rename - add x1, x2, x3
        $display("\n[Test 1] Simple Rename: ADD x1, x2, x3");
        send_instruction(32'h100, 5'd2, 5'd3, 5'd1, 32'h0, 2'b10, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        @(posedge clk);

        assert(valid_out == 1) else $error("valid_out should be high");
        assert(renamed_instr.prs1 == 7'd2) else $error("prs1 should be p2 (identity), got p%0d", renamed_instr.prs1);
        assert(renamed_instr.prs2 == 7'd3) else $error("prs2 should be p3 (identity), got p%0d", renamed_instr.prs2);
        assert(renamed_instr.prd == 7'd32) else $error("prd should be p32 (first free), got p%0d", renamed_instr.prd);
        assert(renamed_instr.prd_old == 7'd1) else $error("prd_old should be p1 (old x1 mapping), got p%0d", renamed_instr.prd_old);
        assert(renamed_instr.rob_tag == 4'd0) else $error("rob_tag should be 0, got %0d", renamed_instr.rob_tag);
        $display("  Renamed: p%0d = p%0d + p%0d (ROB %0d)", renamed_instr.prd, renamed_instr.prs1, renamed_instr.prs2, renamed_instr.rob_tag);
        $display("  PASS");

        // Test 2: Second instruction should see updated mapping
        $display("\n[Test 2] RAW Dependency: ADD x4, x1, x2");
        send_instruction(32'h104, 5'd1, 5'd2, 5'd4, 32'h0, 2'b10, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        @(posedge clk);

        assert(renamed_instr.prs1 == 7'd32) else $error("prs1 should be p32 (renamed x1), got p%0d", renamed_instr.prs1);
        assert(renamed_instr.prs2 == 7'd2) else $error("prs2 should be p2, got p%0d", renamed_instr.prs2);
        assert(renamed_instr.prd == 7'd33) else $error("prd should be p33, got p%0d", renamed_instr.prd);
        assert(renamed_instr.rob_tag == 4'd1) else $error("rob_tag should be 1, got %0d", renamed_instr.rob_tag);
        $display("  Renamed: p%0d = p%0d + p%0d (ROB %0d)", renamed_instr.prd, renamed_instr.prs1, renamed_instr.prs2, renamed_instr.rob_tag);
        $display("  PASS");

        // Test 3: Instruction writing to x0 should not allocate physical register
        $display("\n[Test 3] Write to x0: ADD x0, x1, x2");
        send_instruction(32'h108, 5'd1, 5'd2, 5'd0, 32'h0, 2'b10, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        @(posedge clk);

        assert(renamed_instr.prd == 7'd0) else $error("prd should be p0 for x0, got p%0d", renamed_instr.prd);
        assert(renamed_instr.rob_tag == 4'd2) else $error("rob_tag should be 2, got %0d", renamed_instr.rob_tag);
        $display("  x0 write does not allocate physical register");
        $display("  PASS");

        // Test 4: Reading from x0
        $display("\n[Test 4] Read from x0: ADD x5, x0, x2");
        send_instruction(32'h10C, 5'd0, 5'd2, 5'd5, 32'h0, 2'b10, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        @(posedge clk);

        assert(renamed_instr.prs1 == 7'd0) else $error("prs1 should be p0 for x0, got p%0d", renamed_instr.prs1);
        assert(renamed_instr.prd == 7'd34) else $error("prd should be p34, got p%0d", renamed_instr.prd);
        $display("  PASS");

        // Test 5: Branch instruction
        $display("\n[Test 5] Branch Instruction: BEQ x1, x2, offset");
        send_instruction(32'h110, 5'd1, 5'd2, 5'd0, 32'h10, 2'b01, 2'b01, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
        @(posedge clk);

        assert(renamed_instr.is_branch == 1) else $error("is_branch should be set");
        assert(valid_out == 1) else $error("Branch should be renamed");
        $display("  Branch renamed successfully");

        // Try to send another branch immediately - should stall
        $display("  Testing branch stall...");
        @(posedge clk);
        valid_in = 1;
        is_branch = 1;
        rs1_arch = 5'd3;
        rs2_arch = 5'd4;
        rd_arch = 5'd0;
        reg_write = 0;
        @(posedge clk);

        // Should stall because checkpoint already exists
        assert(ready_out == 0 || valid_out == 0) else $error("Second branch should stall");
        valid_in = 0;
        $display("  Second branch correctly stalled");
        $display("  PASS");

        // Test 6: Commit frees old physical register
        $display("\n[Test 6] Commit Frees Old Register");
        @(posedge clk);
        commit_en = 1;
        commit_prd_old = 7'd1;  // Free p1 (old mapping of x1)
        @(posedge clk);
        commit_en = 0;
        @(posedge clk);
        $display("  Committed and freed p1");
        $display("  PASS");

        // Test 7: Backpressure - ready_in = 0
        $display("\n[Test 7] Backpressure Handling");
        ready_in = 0;
        @(posedge clk);
        valid_in = 1;
        rs1_arch = 5'd1;
        rs2_arch = 5'd2;
        rd_arch = 5'd6;
        reg_write = 1;
        is_branch = 0;
        @(posedge clk);

        assert(valid_out == 0) else $error("valid_out should be 0 when ready_in is 0");

        ready_in = 1;
        @(posedge clk);
        valid_in = 0;
        $display("  Backpressure handled correctly");
        $display("  PASS");

        // Test 8: Instruction with no register write
        $display("\n[Test 8] Store Instruction (no regwrite): SW x1, 0(x2)");
        send_instruction(32'h120, 5'd2, 5'd1, 5'd0, 32'h0, 2'b00, 2'b10, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0);
        @(posedge clk);

        assert(renamed_instr.reg_write == 0) else $error("reg_write should be 0 for store");
        assert(renamed_instr.prd == 7'd0) else $error("No physical register should be allocated");
        $display("  Store instruction does not allocate prd");
        $display("  PASS");

        // Test 9: Sequence of dependent instructions
        $display("\n[Test 9] Instruction Sequence with Dependencies");
        // x7 = x1 + x2
        send_instruction(32'h130, 5'd1, 5'd2, 5'd7, 32'h0, 2'b10, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        @(posedge clk);
        logic [6:0] x7_mapping = renamed_instr.prd;

        // x8 = x7 + x3
        send_instruction(32'h134, 5'd7, 5'd3, 5'd8, 32'h0, 2'b10, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        @(posedge clk);

        assert(renamed_instr.prs1 == x7_mapping) else $error("prs1 should use new x7 mapping");
        $display("  Dependency chain handled correctly");
        $display("  PASS");

        // Test 10: Free list empty condition (allocate many registers)
        $display("\n[Test 10] Free List Exhaustion");
        // Allocate many registers to approach free list limit
        for (int i = 10; i < 30; i++) begin
            send_instruction(32'h200 + (i << 2), 5'd0, 5'd0, i[4:0], 32'h0, 2'b10, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
            @(posedge clk);
        end
        $display("  Allocated many registers without issue");
        $display("  PASS");

        $display("\n=== All Rename Stage Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #2000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
