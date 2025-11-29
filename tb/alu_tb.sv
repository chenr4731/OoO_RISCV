import ooo_types::*;

module alu_tb();
    logic clk;
    logic rst;

    // Issue interface
    logic issue_en;
    rs_entry_t issue_entry;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic ready;

    // Writeback interface
    logic wb_en;
    logic [PHYS_REG_BITS-1:0] wb_prd;
    logic [31:0] wb_data;

    // Completion interface
    logic complete_en;
    logic [ROB_BITS-1:0] complete_tag;

    // Flush
    logic flush;

    // Instantiate ALU
    alu dut (
        .clk(clk),
        .rst(rst),
        .issue_en(issue_en),
        .issue_entry(issue_entry),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .ready(ready),
        .wb_en(wb_en),
        .wb_prd(wb_prd),
        .wb_data(wb_data),
        .complete_en(complete_en),
        .complete_tag(complete_tag),
        .flush(flush)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        $display("=== ALU Testbench ===");

        // Initialize
        rst = 1;
        issue_en = 0;
        flush = 0;
        issue_entry = '0;
        rs1_data = 32'd0;
        rs2_data = 32'd0;

        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: ADD operation (rs1 + rs2)
        $display("\nTest 1: ADD 10 + 20 = 30");
        issue_en = 1;
        issue_entry.alu_op = 2'b00; // ADD
        issue_entry.alu_src = 0;    // Use rs2
        issue_entry.prd = 7'd10;
        issue_entry.rob_tag = 4'd0;
        issue_entry.reg_write = 1;
        rs1_data = 32'd10;
        rs2_data = 32'd20;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (wb_en && wb_data == 32'd30 && wb_prd == 7'd10) begin
            $display("PASS: ADD result = %0d", wb_data);
        end else begin
            $display("FAIL: Expected 30, got %0d", wb_data);
        end

        // Test 2: SUB operation (rs1 - rs2)
        $display("\nTest 2: SUB 50 - 30 = 20");
        issue_en = 1;
        issue_entry.alu_op = 2'b01; // SUB
        issue_entry.alu_src = 0;    // Use rs2
        issue_entry.prd = 7'd11;
        issue_entry.rob_tag = 4'd1;
        issue_entry.reg_write = 1;
        rs1_data = 32'd50;
        rs2_data = 32'd30;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (wb_en && wb_data == 32'd20 && wb_prd == 7'd11) begin
            $display("PASS: SUB result = %0d", wb_data);
        end else begin
            $display("FAIL: Expected 20, got %0d", wb_data);
        end

        // Test 3: AND operation
        $display("\nTest 3: AND 0xFF0F & 0x0F0F = 0x0F0F");
        issue_en = 1;
        issue_entry.alu_op = 2'b10; // AND
        issue_entry.alu_src = 0;    // Use rs2
        issue_entry.prd = 7'd12;
        issue_entry.rob_tag = 4'd2;
        issue_entry.reg_write = 1;
        rs1_data = 32'hFF0F;
        rs2_data = 32'h0F0F;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (wb_en && wb_data == 32'h0F0F && wb_prd == 7'd12) begin
            $display("PASS: AND result = 0x%0h", wb_data);
        end else begin
            $display("FAIL: Expected 0x0F0F, got 0x%0h", wb_data);
        end

        // Test 4: OR operation
        $display("\nTest 4: OR 0xF000 | 0x000F = 0xF00F");
        issue_en = 1;
        issue_entry.alu_op = 2'b11; // OR
        issue_entry.alu_src = 0;    // Use rs2
        issue_entry.prd = 7'd13;
        issue_entry.rob_tag = 4'd3;
        issue_entry.reg_write = 1;
        rs1_data = 32'hF000;
        rs2_data = 32'h000F;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (wb_en && wb_data == 32'hF00F && wb_prd == 7'd13) begin
            $display("PASS: OR result = 0x%0h", wb_data);
        end else begin
            $display("FAIL: Expected 0xF00F, got 0x%0h", wb_data);
        end

        // Test 5: ADD with immediate
        $display("\nTest 5: ADDI 100 + 50 = 150");
        issue_en = 1;
        issue_entry.alu_op = 2'b00; // ADD
        issue_entry.alu_src = 1;    // Use immediate
        issue_entry.immediate = 32'd50;
        issue_entry.prd = 7'd14;
        issue_entry.rob_tag = 4'd4;
        issue_entry.reg_write = 1;
        rs1_data = 32'd100;
        rs2_data = 32'd999; // Should be ignored
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (wb_en && wb_data == 32'd150 && wb_prd == 7'd14) begin
            $display("PASS: ADDI result = %0d", wb_data);
        end else begin
            $display("FAIL: Expected 150, got %0d", wb_data);
        end

        // Test 6: Flush
        $display("\nTest 6: Flush during execution");
        issue_en = 1;
        issue_entry.alu_op = 2'b00; // ADD
        issue_entry.alu_src = 0;
        issue_entry.prd = 7'd15;
        issue_entry.rob_tag = 4'd5;
        issue_entry.reg_write = 1;
        rs1_data = 32'd10;
        rs2_data = 32'd20;
        @(posedge clk);
        issue_en = 0;
        flush = 1;
        @(posedge clk);
        flush = 0;

        if (!wb_en && !complete_en) begin
            $display("PASS: Flush cleared pipeline");
        end else begin
            $display("FAIL: Flush did not clear pipeline");
        end

        @(posedge clk);
        $display("\n=== ALU Testbench Complete ===");
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (wb_en) begin
            $display("  [WB] prd=%0d, data=0x%0h", wb_prd, wb_data);
        end
        if (complete_en) begin
            $display("  [COMPLETE] rob_tag=%0d", complete_tag);
        end
    end

endmodule
