import ooo_types::*;

module lsu (
    input logic clk,
    input logic rst,

    // Issue interface (from RS)
    input logic issue_en,
    input rs_entry_t issue_entry,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,  // For stores (not used in Phase 3)
    output logic ready,

    // BRAM interface (data memory)
    output logic [31:0] mem_addr,
    output logic mem_en,
    output logic mem_we,         // Write enable (0 for load, 1 for store)
    output logic [31:0] mem_wdata,
    input logic [31:0] mem_rdata,

    // Writeback interface (to PRF)
    output logic wb_en,
    output logic [PHYS_REG_BITS-1:0] wb_prd,
    output logic [31:0] wb_data,

    // Completion interface (to ROB)
    output logic complete_en,
    output logic [ROB_BITS-1:0] complete_tag,

    // Flush
    input logic flush
);

    // LSU has a 2-stage pipeline:
    // Stage 1: Address generation + BRAM address setup
    // Stage 2: BRAM data read + writeback

    typedef struct packed {
        logic valid;
        logic [PHYS_REG_BITS-1:0] prd;
        logic [ROB_BITS-1:0] rob_tag;
        logic reg_write;
        logic is_load;
        logic is_store;
    } lsu_stage1_t;

    typedef struct packed {
        logic valid;
        logic [PHYS_REG_BITS-1:0] prd;
        logic [ROB_BITS-1:0] rob_tag;
        logic reg_write;
        logic [31:0] data;
    } lsu_stage2_t;

    lsu_stage1_t stage1;
    lsu_stage2_t stage2;

    // Compute memory address
    logic [31:0] mem_addr_comb;
    assign mem_addr_comb = rs1_data + issue_entry.immediate;

    // BRAM interface
    // Note: For 2-cycle BRAM access, we need to:
    // Cycle 1: Set address and enable
    // Cycle 2: Read data is available
    assign mem_addr = mem_addr_comb;
    assign mem_en = issue_en || stage1.valid;
    assign mem_we = 1'b0;  // Phase 3: Load only
    assign mem_wdata = 32'd0;

    // Ready when stage1 is empty (can accept new issue)
    // For simplicity, we'll always be ready (assume no structural hazards)
    assign ready = 1'b1;

    // Writeback outputs (from stage2)
    assign wb_en = stage2.valid && stage2.reg_write;
    assign wb_prd = stage2.prd;
    assign wb_data = stage2.data;

    // Completion outputs (from stage2)
    assign complete_en = stage2.valid;
    assign complete_tag = stage2.rob_tag;

    // Pipeline execution
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            // Stage 1
            stage1.valid <= 1'b0;
            stage1.prd <= '0;
            stage1.rob_tag <= '0;
            stage1.reg_write <= 1'b0;
            stage1.is_load <= 1'b0;
            stage1.is_store <= 1'b0;

            // Stage 2
            stage2.valid <= 1'b0;
            stage2.prd <= '0;
            stage2.rob_tag <= '0;
            stage2.reg_write <= 1'b0;
            stage2.data <= 32'd0;
        end
        else begin
            // Stage 1: Address generation
            if (issue_en) begin
                stage1.valid <= 1'b1;
                stage1.prd <= issue_entry.prd;
                stage1.rob_tag <= issue_entry.rob_tag;
                stage1.reg_write <= issue_entry.reg_write;
                stage1.is_load <= issue_entry.mem_read;
                stage1.is_store <= issue_entry.mem_write;
            end
            else begin
                stage1.valid <= 1'b0;
            end

            // Stage 2: BRAM data read
            if (stage1.valid) begin
                stage2.valid <= 1'b1;
                stage2.prd <= stage1.prd;
                stage2.rob_tag <= stage1.rob_tag;
                stage2.reg_write <= stage1.reg_write;
                // BRAM read data is available in this cycle
                stage2.data <= mem_rdata;
            end
            else begin
                stage2.valid <= 1'b0;
            end
        end
    end

endmodule
