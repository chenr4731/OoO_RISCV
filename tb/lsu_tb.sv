import ooo_types::*;

module lsu_tb();
    logic clk;
    logic rst;

    // Issue interface
    logic issue_en;
    rs_entry_t issue_entry;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic ready;

    // BRAM interface
    logic [31:0] mem_addr;
    logic mem_en;
    logic mem_we;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;

    // Writeback interface
    logic wb_en;
    logic [PHYS_REG_BITS-1:0] wb_prd;
    logic [31:0] wb_data;

    // Completion interface
    logic complete_en;
    logic [ROB_BITS-1:0] complete_tag;

    // Flush
    logic flush;

    // Simple memory model
    logic [31:0] memory [0:255];

    always_ff @(posedge clk) begin
        if (mem_en) begin
            if (mem_we) begin
                memory[mem_addr[9:2]] <= mem_wdata;
            end
            mem_rdata <= memory[mem_addr[9:2]];
        end
    end

    // Instantiate LSU
    lsu dut (
        .clk(clk),
        .rst(rst),
        .issue_en(issue_en),
        .issue_entry(issue_entry),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .ready(ready),
        .mem_addr(mem_addr),
        .mem_en(mem_en),
        .mem_we(mem_we),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
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
        $display("=== LSU Testbench ===");

        // Initialize memory
        for (int i = 0; i < 256; i++) begin
            memory[i] = i * 10;
        end

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

        // Test 1: Load from address 0
        $display("\nTest 1: Load from address 0");
        issue_en = 1;
        issue_entry.mem_read = 1;
        issue_entry.mem_write = 0;
        issue_entry.immediate = 32'd0;  // Offset
        issue_entry.prd = 7'd10;
        issue_entry.rob_tag = 4'd0;
        issue_entry.reg_write = 1;
        rs1_data = 32'd0;               // Base address
        rs2_data = 32'd999;             // Not used for load
        @(posedge clk);
        issue_en = 0;

        // Wait for 2 cycles (LSU pipeline)
        @(posedge clk);
        @(posedge clk);

        if (wb_en && wb_data == 32'd0 && wb_prd == 7'd10) begin
            $display("PASS: Load data = %0d", wb_data);
        end else begin
            $display("FAIL: Expected 0, got %0d", wb_data);
        end

        // Test 2: Load from address 4
        $display("\nTest 2: Load from address 4 (word index 1)");
        issue_en = 1;
        issue_entry.mem_read = 1;
        issue_entry.mem_write = 0;
        issue_entry.immediate = 32'd4;  // Offset
        issue_entry.prd = 7'd11;
        issue_entry.rob_tag = 4'd1;
        issue_entry.reg_write = 1;
        rs1_data = 32'd0;               // Base address
        @(posedge clk);
        issue_en = 0;

        @(posedge clk);
        @(posedge clk);

        if (wb_en && wb_data == 32'd10 && wb_prd == 7'd11) begin
            $display("PASS: Load data = %0d", wb_data);
        end else begin
            $display("FAIL: Expected 10, got %0d", wb_data);
        end

        // Test 3: Load with base + offset
        $display("\nTest 3: Load from base=0x100 + offset=0x8 (word index 66)");
        issue_en = 1;
        issue_entry.mem_read = 1;
        issue_entry.mem_write = 0;
        issue_entry.immediate = 32'h8;  // Offset
        issue_entry.prd = 7'd12;
        issue_entry.rob_tag = 4'd2;
        issue_entry.reg_write = 1;
        rs1_data = 32'h100;             // Base address
        @(posedge clk);
        issue_en = 0;

        @(posedge clk);
        @(posedge clk);

        if (wb_en && wb_data == 32'd660 && wb_prd == 7'd12) begin
            $display("PASS: Load data = %0d", wb_data);
        end else begin
            $display("FAIL: Expected 660, got %0d", wb_data);
        end

        // Test 4: Back-to-back loads
        $display("\nTest 4: Back-to-back loads");
        issue_en = 1;
        issue_entry.mem_read = 1;
        issue_entry.immediate = 32'd0;
        issue_entry.prd = 7'd20;
        issue_entry.rob_tag = 4'd3;
        issue_entry.reg_write = 1;
        rs1_data = 32'd8;
        @(posedge clk);

        issue_entry.immediate = 32'd4;
        issue_entry.prd = 7'd21;
        issue_entry.rob_tag = 4'd4;
        rs1_data = 32'd8;
        @(posedge clk);
        issue_en = 0;

        @(posedge clk);
        if (wb_en && wb_data == 32'd20) begin
            $display("PASS: First load data = %0d", wb_data);
        end

        @(posedge clk);
        if (wb_en && wb_data == 32'd30) begin
            $display("PASS: Second load data = %0d", wb_data);
        end

        // Test 5: Flush during execution
        $display("\nTest 5: Flush during LSU pipeline");
        issue_en = 1;
        issue_entry.mem_read = 1;
        issue_entry.immediate = 32'd0;
        issue_entry.prd = 7'd30;
        issue_entry.rob_tag = 4'd5;
        issue_entry.reg_write = 1;
        rs1_data = 32'd0;
        @(posedge clk);
        issue_en = 0;
        flush = 1;
        @(posedge clk);
        flush = 0;

        @(posedge clk);
        if (!wb_en && !complete_en) begin
            $display("PASS: Flush cleared LSU pipeline");
        end else begin
            $display("FAIL: Flush did not clear pipeline");
        end

        @(posedge clk);
        $display("\n=== LSU Testbench Complete ===");
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (issue_en) begin
            $display("  [ISSUE] addr=%0h (base=%0h + offset=%0h)",
                     rs1_data + issue_entry.immediate, rs1_data, issue_entry.immediate);
        end
        if (wb_en) begin
            $display("  [WB] prd=%0d, data=%0d (0x%0h)", wb_prd, wb_data, wb_data);
        end
        if (complete_en) begin
            $display("  [COMPLETE] rob_tag=%0d", complete_tag);
        end
    end

endmodule
