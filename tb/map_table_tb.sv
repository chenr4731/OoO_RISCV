`timescale 1ns/1ps

import ooo_types::*;

module map_table_tb;
    logic clk;
    logic rst;

    // Lookup ports
    logic [4:0] rs1_arch;
    logic [4:0] rs2_arch;
    logic [PHYS_REG_BITS-1:0] rs1_phys;
    logic [PHYS_REG_BITS-1:0] rs2_phys;

    // Update port
    logic wr_en;
    logic [4:0] rd_arch;
    logic [PHYS_REG_BITS-1:0] rd_phys;
    logic [PHYS_REG_BITS-1:0] rd_phys_old;

    // Checkpoint
    logic checkpoint_en;
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] checkpoint_table;

    // Recovery
    logic restore_en;
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] restore_table;

    // Instantiate map_table
    map_table dut (
        .clk(clk),
        .rst(rst),
        .rs1_arch(rs1_arch),
        .rs2_arch(rs2_arch),
        .rs1_phys(rs1_phys),
        .rs2_phys(rs2_phys),
        .wr_en(wr_en),
        .rd_arch(rd_arch),
        .rd_phys(rd_phys),
        .rd_phys_old(rd_phys_old),
        .checkpoint_en(checkpoint_en),
        .checkpoint_table(checkpoint_table),
        .restore_en(restore_en),
        .restore_table(restore_table)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== Map Table Testbench ===");

        // Initialize
        rst = 1;
        wr_en = 0;
        checkpoint_en = 0;
        restore_en = 0;
        rs1_arch = 0;
        rs2_arch = 0;
        rd_arch = 0;
        rd_phys = 0;
        restore_table = '0;

        // Reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: Verify identity mapping after reset
        $display("\n[Test 1] Identity Mapping After Reset");
        for (int i = 0; i < NUM_ARCH_REGS; i++) begin
            rs1_arch = i[4:0];
            #1;
            assert(rs1_phys == i[PHYS_REG_BITS-1:0])
                else $error("x%0d should map to p%0d, got p%0d", i, i, rs1_phys);
        end
        $display("  PASS");

        // Test 2: x0 always maps to p0
        $display("\n[Test 2] x0 Always Maps to p0");
        rs1_arch = 0;
        rs2_arch = 0;
        #1;
        assert(rs1_phys == 7'd0) else $error("x0 should always map to p0");
        assert(rs2_phys == 7'd0) else $error("x0 should always map to p0");
        $display("  PASS");

        // Test 3: Update mapping for x1
        $display("\n[Test 3] Update Mapping x1 -> p32");
        @(posedge clk);
        wr_en = 1;
        rd_arch = 5'd1;
        rd_phys = 7'd32;
        @(posedge clk);
        wr_en = 0;

        // Verify old mapping was captured
        assert(rd_phys_old == 7'd1) else $error("Old mapping should be p1, got p%0d", rd_phys_old);

        // Verify new mapping
        rs1_arch = 5'd1;
        #1;
        assert(rs1_phys == 7'd32) else $error("x1 should map to p32, got p%0d", rs1_phys);
        $display("  PASS");

        // Test 4: Multiple updates
        $display("\n[Test 4] Multiple Updates");
        @(posedge clk);
        wr_en = 1;
        rd_arch = 5'd2;
        rd_phys = 7'd50;
        @(posedge clk);

        rd_arch = 5'd3;
        rd_phys = 7'd51;
        @(posedge clk);
        wr_en = 0;

        rs1_arch = 5'd2;
        rs2_arch = 5'd3;
        #1;
        assert(rs1_phys == 7'd50) else $error("x2 should map to p50");
        assert(rs2_phys == 7'd51) else $error("x3 should map to p51");
        $display("  PASS");

        // Test 5: Cannot update x0
        $display("\n[Test 5] x0 Mapping is Immutable");
        @(posedge clk);
        wr_en = 1;
        rd_arch = 5'd0;
        rd_phys = 7'd99;
        @(posedge clk);
        wr_en = 0;

        rs1_arch = 5'd0;
        #1;
        assert(rs1_phys == 7'd0) else $error("x0 should still map to p0");
        $display("  PASS");

        // Test 6: Checkpoint functionality
        $display("\n[Test 6] Checkpoint Creation");
        @(posedge clk);
        // Create some state
        wr_en = 1;
        rd_arch = 5'd4;
        rd_phys = 7'd60;
        @(posedge clk);
        wr_en = 0;

        // Take checkpoint
        checkpoint_en = 1;
        @(posedge clk);
        checkpoint_en = 0;

        // Verify checkpoint captures current state
        assert(checkpoint_table[4] == 7'd60) else $error("Checkpoint should have x4->p60");
        assert(checkpoint_table[1] == 7'd32) else $error("Checkpoint should have x1->p32");
        $display("  PASS");

        // Test 7: Update after checkpoint
        $display("\n[Test 7] Updates After Checkpoint");
        @(posedge clk);
        wr_en = 1;
        rd_arch = 5'd5;
        rd_phys = 7'd70;
        @(posedge clk);

        rd_arch = 5'd4;
        rd_phys = 7'd71;
        @(posedge clk);
        wr_en = 0;

        rs1_arch = 5'd5;
        rs2_arch = 5'd4;
        #1;
        assert(rs1_phys == 7'd70) else $error("x5 should map to p70");
        assert(rs2_phys == 7'd71) else $error("x4 should map to p71");
        $display("  PASS");

        // Test 8: Restore from checkpoint
        $display("\n[Test 8] Restore From Checkpoint");
        restore_table = checkpoint_table;
        @(posedge clk);
        restore_en = 1;
        @(posedge clk);
        restore_en = 0;

        // Verify state is restored
        rs1_arch = 5'd4;
        rs2_arch = 5'd5;
        #1;
        assert(rs1_phys == 7'd60) else $error("x4 should be restored to p60, got p%0d", rs1_phys);
        assert(rs2_phys == 7'd5) else $error("x5 should be restored to p5 (identity), got p%0d", rs2_phys);
        $display("  PASS");

        // Test 9: Simultaneous read ports
        $display("\n[Test 9] Simultaneous Dual Reads");
        rs1_arch = 5'd1;
        rs2_arch = 5'd2;
        #1;
        assert(rs1_phys == 7'd32) else $error("Simultaneous read rs1 failed");
        assert(rs2_phys == 7'd50) else $error("Simultaneous read rs2 failed");
        $display("  PASS");

        // Test 10: Read old mapping combinationally
        $display("\n[Test 10] Combinational Old Mapping Read");
        rd_arch = 5'd1;
        #1;
        assert(rd_phys_old == 7'd32) else $error("Old mapping should be p32, got p%0d", rd_phys_old);
        $display("  PASS");

        $display("\n=== All Map Table Tests Passed ===\n");
        $finish;
    end

    // Timeout
    initial begin
        #1000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
