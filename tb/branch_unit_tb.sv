import ooo_types::*;

module branch_unit_tb();
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
    logic branch_taken;
    logic [31:0] branch_target;

    // Misprediction
    logic mispredict;
    logic [31:0] mispredict_target;

    // Flush
    logic flush;

    // Instantiate Branch Unit
    branch_unit dut (
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
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .mispredict(mispredict),
        .mispredict_target(mispredict_target),
        .flush(flush)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        $display("=== Branch Unit Testbench ===");

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

        // Test 1: BEQ - Equal (taken)
        $display("\nTest 1: BEQ 10 == 10 (taken)");
        issue_en = 1;
        issue_entry.alu_op = 2'b01;     // BRANCH
        issue_entry.immediate = 32'h000; // funct3=000 (BEQ) in lower bits
        issue_entry.pc = 32'h1000;
        issue_entry.prd = 7'd0;
        issue_entry.rob_tag = 4'd0;
        issue_entry.reg_write = 0;
        rs1_data = 32'd10;
        rs2_data = 32'd10;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (branch_taken && mispredict) begin
            $display("PASS: BEQ taken, mispredict detected");
        end else begin
            $display("FAIL: BEQ should be taken");
        end

        // Test 2: BEQ - Not equal (not taken)
        $display("\nTest 2: BEQ 10 != 20 (not taken)");
        issue_en = 1;
        issue_entry.alu_op = 2'b01;     // BRANCH
        issue_entry.immediate = 32'h000; // funct3=000 (BEQ)
        issue_entry.pc = 32'h1004;
        issue_entry.rob_tag = 4'd1;
        rs1_data = 32'd10;
        rs2_data = 32'd20;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (!branch_taken && !mispredict) begin
            $display("PASS: BEQ not taken, no mispredict");
        end else begin
            $display("FAIL: BEQ should not be taken");
        end

        // Test 3: BNE - Not equal (taken)
        $display("\nTest 3: BNE 10 != 20 (taken)");
        issue_en = 1;
        issue_entry.alu_op = 2'b01;     // BRANCH
        issue_entry.immediate = 32'h001; // funct3=001 (BNE)
        issue_entry.pc = 32'h1008;
        issue_entry.rob_tag = 4'd2;
        rs1_data = 32'd10;
        rs2_data = 32'd20;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (branch_taken && mispredict) begin
            $display("PASS: BNE taken, mispredict detected");
        end else begin
            $display("FAIL: BNE should be taken");
        end

        // Test 4: BLT - Less than (taken)
        $display("\nTest 4: BLT -5 < 10 (taken)");
        issue_en = 1;
        issue_entry.alu_op = 2'b01;     // BRANCH
        issue_entry.immediate = 32'h104; // funct3=100 (BLT), offset=0x100
        issue_entry.pc = 32'h100C;
        issue_entry.rob_tag = 4'd3;
        rs1_data = 32'hFFFFFFFB; // -5
        rs2_data = 32'd10;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (branch_taken && mispredict) begin
            $display("PASS: BLT taken, mispredict detected");
            $display("  Target: 0x%0h", branch_target);
        end else begin
            $display("FAIL: BLT should be taken");
        end

        // Test 5: BGE - Greater or equal (taken)
        $display("\nTest 5: BGE 20 >= 10 (taken)");
        issue_en = 1;
        issue_entry.alu_op = 2'b01;     // BRANCH
        issue_entry.immediate = 32'h205; // funct3=101 (BGE), offset=0x200
        issue_entry.pc = 32'h1010;
        issue_entry.rob_tag = 4'd4;
        rs1_data = 32'd20;
        rs2_data = 32'd10;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (branch_taken && mispredict) begin
            $display("PASS: BGE taken, mispredict detected");
        end else begin
            $display("FAIL: BGE should be taken");
        end

        // Test 6: JALR (always taken)
        $display("\nTest 6: JALR to base+offset");
        issue_en = 1;
        issue_entry.alu_op = 2'b00;     // JALR
        issue_entry.immediate = 32'd4;  // Offset
        issue_entry.pc = 32'h1014;
        issue_entry.prd = 7'd20;
        issue_entry.rob_tag = 4'd5;
        issue_entry.reg_write = 1;      // JALR writes PC+4
        rs1_data = 32'h2000;            // Base address
        rs2_data = 32'd0;
        @(posedge clk);
        issue_en = 0;
        @(posedge clk);

        if (branch_taken && wb_en && wb_data == 32'h1018) begin
            $display("PASS: JALR taken, PC+4 written");
            $display("  Target: 0x%0h, PC+4: 0x%0h", branch_target, wb_data);
        end else begin
            $display("FAIL: JALR incorrect");
        end

        // Test 7: Flush
        $display("\nTest 7: Flush during execution");
        issue_en = 1;
        issue_entry.alu_op = 2'b01;
        issue_entry.immediate = 32'h000;
        issue_entry.pc = 32'h1018;
        issue_entry.rob_tag = 4'd6;
        rs1_data = 32'd10;
        rs2_data = 32'd10;
        @(posedge clk);
        issue_en = 0;
        flush = 1;
        @(posedge clk);
        flush = 0;

        if (!complete_en && !mispredict) begin
            $display("PASS: Flush cleared pipeline");
        end else begin
            $display("FAIL: Flush did not clear pipeline");
        end

        @(posedge clk);
        $display("\n=== Branch Unit Testbench Complete ===");
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (complete_en) begin
            $display("  [COMPLETE] rob_tag=%0d, taken=%0b, target=0x%0h",
                     complete_tag, branch_taken, branch_target);
        end
        if (mispredict) begin
            $display("  [MISPREDICT] target=0x%0h", mispredict_target);
        end
        if (wb_en) begin
            $display("  [WB] prd=%0d, data=0x%0h", wb_prd, wb_data);
        end
    end

endmodule
