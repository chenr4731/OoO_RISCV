`timescale 1ns/1ps

import ooo_types::*;

module physical_regfile_tb;
    logic clk;
    logic rst;

    // Read ports (6 total)
    logic [PHYS_REG_BITS-1:0] rs1_alu;
    logic [PHYS_REG_BITS-1:0] rs2_alu;
    logic [PHYS_REG_BITS-1:0] rs1_branch;
    logic [PHYS_REG_BITS-1:0] rs2_branch;
    logic [PHYS_REG_BITS-1:0] rs1_lsu;
    logic [PHYS_REG_BITS-1:0] rs2_lsu;

    logic [31:0] rd1_alu;
    logic [31:0] rd2_alu;
    logic [31:0] rd1_branch;
    logic [31:0] rd2_branch;
    logic [31:0] rd1_lsu;
    logic [31:0] rd2_lsu;

    // Write ports (3 total)
    logic we_alu;
    logic [PHYS_REG_BITS-1:0] wa_alu;
    logic [31:0] wd_alu;

    logic we_branch;
    logic [PHYS_REG_BITS-1:0] wa_branch;
    logic [31:0] wd_branch;

    logic we_lsu;
    logic [PHYS_REG_BITS-1:0] wa_lsu;
    logic [31:0] wd_lsu;

    // Instantiate physical_regfile
    physical_regfile dut (
        .clk(clk),
        .rst(rst),
        .rs1_alu(rs1_alu),
        .rs2_alu(rs2_alu),
        .rs1_branch(rs1_branch),
        .rs2_branch(rs2_branch),
        .rs1_lsu(rs1_lsu),
        .rs2_lsu(rs2_lsu),
        .rd1_alu(rd1_alu),
        .rd2_alu(rd2_alu),
        .rd1_branch(rd1_branch),
        .rd2_branch(rd2_branch),
        .rd1_lsu(rd1_lsu),
        .rd2_lsu(rd2_lsu),
        .we_alu(we_alu),
        .wa_alu(wa_alu),
        .wd_alu(wd_alu),
        .we_branch(we_branch),
        .wa_branch(wa_branch),
        .wd_branch(wd_branch),
        .we_lsu(we_lsu),
        .wa_lsu(wa_lsu),
        .wd_lsu(wd_lsu)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== Physical Register File Testbench ===");

        // Initialize
        rst = 1;
        rs1_alu = 0;
        rs2_alu = 0;
        rs1_branch = 0;
        rs2_branch = 0;
        rs1_lsu = 0;
        rs2_lsu = 0;
        we_alu = 0;
        wa_alu = 0;
        wd_alu = 0;
        we_branch = 0;
        wa_branch = 0;
        wd_branch = 0;
        we_lsu = 0;
        wa_lsu = 0;
        wd_lsu = 0;

        // Reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: All registers initialized to 0
        $display("\n[Test 1] All Registers Initialized to 0");
        for (int i = 0; i < NUM_PHYS_REGS; i++) begin
            rs1_alu = i[6:0];
            #1;
            assert(rd1_alu == 32'h0) else $error("p%0d should be 0, got 0x%08h", i, rd1_alu);
        end
        $display("  PASS");

        // Test 2: Write to ALU port
        $display("\n[Test 2] Write Via ALU Port");
        @(posedge clk);
        we_alu = 1;
        wa_alu = 7'd10;
        wd_alu = 32'hDEADBEEF;
        @(posedge clk);
        we_alu = 0;

        rs1_alu = 7'd10;
        #1;
        assert(rd1_alu == 32'hDEADBEEF) else $error("p10 should be 0xDEADBEEF");
        $display("  PASS");

        // Test 3: Write to Branch port
        $display("\n[Test 3] Write Via Branch Port");
        @(posedge clk);
        we_branch = 1;
        wa_branch = 7'd20;
        wd_branch = 32'hCAFEBABE;
        @(posedge clk);
        we_branch = 0;

        rs1_branch = 7'd20;
        #1;
        assert(rd1_branch == 32'hCAFEBABE) else $error("p20 should be 0xCAFEBABE");
        $display("  PASS");

        // Test 4: Write to LSU port
        $display("\n[Test 4] Write Via LSU Port");
        @(posedge clk);
        we_lsu = 1;
        wa_lsu = 7'd30;
        wd_lsu = 32'h12345678;
        @(posedge clk);
        we_lsu = 0;

        rs1_lsu = 7'd30;
        #1;
        assert(rd1_lsu == 32'h12345678) else $error("p30 should be 0x12345678");
        $display("  PASS");

        // Test 5: p0 always reads as 0
        $display("\n[Test 5] p0 Always Reads as 0");
        @(posedge clk);
        we_alu = 1;
        wa_alu = 7'd0;
        wd_alu = 32'hFFFFFFFF;
        @(posedge clk);
        we_alu = 0;

        rs1_alu = 7'd0;
        #1;
        assert(rd1_alu == 32'h0) else $error("p0 should always be 0");
        $display("  PASS");

        // Test 6: Simultaneous reads from all ports
        $display("\n[Test 6] Simultaneous Reads from All 6 Ports");
        // Write to different registers
        @(posedge clk);
        we_alu = 1; wa_alu = 7'd40; wd_alu = 32'h11111111;
        we_branch = 1; wa_branch = 7'd41; wd_branch = 32'h22222222;
        we_lsu = 1; wa_lsu = 7'd42; wd_lsu = 32'h33333333;
        @(posedge clk);
        we_alu = 0; we_branch = 0; we_lsu = 0;

        // Read simultaneously
        rs1_alu = 7'd40;
        rs2_alu = 7'd41;
        rs1_branch = 7'd42;
        rs2_branch = 7'd40;
        rs1_lsu = 7'd41;
        rs2_lsu = 7'd42;
        #1;

        assert(rd1_alu == 32'h11111111) else $error("ALU port 1 read failed");
        assert(rd2_alu == 32'h22222222) else $error("ALU port 2 read failed");
        assert(rd1_branch == 32'h33333333) else $error("Branch port 1 read failed");
        assert(rd2_branch == 32'h11111111) else $error("Branch port 2 read failed");
        assert(rd1_lsu == 32'h22222222) else $error("LSU port 1 read failed");
        assert(rd2_lsu == 32'h33333333) else $error("LSU port 2 read failed");
        $display("  PASS");

        // Test 7: Write conflict - ALU has priority
        $display("\n[Test 7] Write Conflict - ALU Priority");
        @(posedge clk);
        we_alu = 1; wa_alu = 7'd50; wd_alu = 32'hAAAAAAAA;
        we_branch = 1; wa_branch = 7'd50; wd_branch = 32'hBBBBBBBB;
        we_lsu = 1; wa_lsu = 7'd50; wd_lsu = 32'hCCCCCCCC;
        @(posedge clk);
        we_alu = 0; we_branch = 0; we_lsu = 0;

        rs1_alu = 7'd50;
        #1;
        assert(rd1_alu == 32'hAAAAAAAA) else $error("ALU write should have priority, got 0x%08h", rd1_alu);
        $display("  PASS");

        // Test 8: Write conflict - Branch priority over LSU
        $display("\n[Test 8] Write Conflict - Branch > LSU");
        @(posedge clk);
        we_branch = 1; wa_branch = 7'd51; wd_branch = 32'hBBBBBBBB;
        we_lsu = 1; wa_lsu = 7'd51; wd_lsu = 32'hCCCCCCCC;
        @(posedge clk);
        we_branch = 0; we_lsu = 0;

        rs1_alu = 7'd51;
        #1;
        assert(rd1_alu == 32'hBBBBBBBB) else $error("Branch write should have priority over LSU");
        $display("  PASS");

        // Test 9: Sequential writes to same register
        $display("\n[Test 9] Sequential Writes to Same Register");
        @(posedge clk);
        we_alu = 1; wa_alu = 7'd60; wd_alu = 32'h00000001;
        @(posedge clk);
        wd_alu = 32'h00000002;
        @(posedge clk);
        wd_alu = 32'h00000003;
        @(posedge clk);
        we_alu = 0;

        rs1_alu = 7'd60;
        #1;
        assert(rd1_alu == 32'h00000003) else $error("Should have latest write value");
        $display("  PASS");

        // Test 10: Read-write in same cycle (old value should be read)
        $display("\n[Test 10] Read-Write Same Cycle (Reads Old Value)");
        @(posedge clk);
        we_alu = 1; wa_alu = 7'd70; wd_alu = 32'h99999999;
        @(posedge clk);
        we_alu = 0;

        // Read old value
        rs1_alu = 7'd70;
        #1;
        logic [31:0] old_val = rd1_alu;

        // Write new value while reading
        @(posedge clk);
        we_alu = 1; wa_alu = 7'd70; wd_alu = 32'h88888888;
        rs1_alu = 7'd70;
        #1;

        // Should read old value (before clock edge)
        assert(rd1_alu == old_val) else $error("Should read old value in same cycle");
        @(posedge clk);
        we_alu = 0;

        // After clock edge, should read new value
        #1;
        assert(rd1_alu == 32'h88888888) else $error("Should read new value after clock edge");
        $display("  PASS");

        // Test 11: Write to all 128 registers
        $display("\n[Test 11] Write to All 128 Registers");
        for (int i = 1; i < NUM_PHYS_REGS; i++) begin
            @(posedge clk);
            we_alu = 1;
            wa_alu = i[6:0];
            wd_alu = i;
            @(posedge clk);
            we_alu = 0;
        end

        // Verify all writes
        for (int i = 1; i < NUM_PHYS_REGS; i++) begin
            rs1_alu = i[6:0];
            #1;
            assert(rd1_alu == i) else $error("p%0d should be %0d, got %0d", i, i, rd1_alu);
        end
        $display("  PASS");

        // Test 12: Reset clears all registers
        $display("\n[Test 12] Reset Clears All Registers");
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        for (int i = 0; i < 10; i++) begin
            rs1_alu = i[6:0];
            #1;
            assert(rd1_alu == 32'h0) else $error("p%0d should be 0 after reset", i);
        end
        $display("  PASS");

        // Test 13: p0 remains 0 even after other writes
        $display("\n[Test 13] p0 Protection After Multiple Operations");
        @(posedge clk);
        we_alu = 1; wa_alu = 7'd1; wd_alu = 32'h11111111;
        we_branch = 1; wa_branch = 7'd2; wd_branch = 32'h22222222;
        @(posedge clk);
        we_alu = 0; we_branch = 0;

        rs1_alu = 7'd0;
        #1;
        assert(rd1_alu == 32'h0) else $error("p0 should still be 0");
        $display("  PASS");

        $display("\n=== All Physical Register File Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #3000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
