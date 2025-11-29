import ooo_types::*;

module reservation_station #(
    parameter RS_SIZE = 8
) (
    input logic clk,
    input logic rst,

    // Dispatch (allocate entry)
    input logic dispatch_en,
    input renamed_instr_t dispatch_instr,
    output logic full,
    output logic [$clog2(RS_SIZE)-1:0] alloc_idx,
    output logic alloc_valid,

    // Issue to execution unit
    output logic issue_en,
    output rs_entry_t issue_entry,
    output logic [$clog2(RS_SIZE)-1:0] issue_idx,
    input logic eu_ready,

    // Wakeup (from writeback - multiple sources)
    input logic wb_en_alu,
    input logic [PHYS_REG_BITS-1:0] wb_prd_alu,
    input logic wb_en_branch,
    input logic [PHYS_REG_BITS-1:0] wb_prd_branch,
    input logic wb_en_lsu,
    input logic [PHYS_REG_BITS-1:0] wb_prd_lsu,

    // Flush
    input logic flush
);

    // Entry storage
    rs_entry_t entries [0:RS_SIZE-1];

    // Generate valid bitmap for priority decoder
    logic [RS_SIZE-1:0] valid_bitmap;
    logic [RS_SIZE-1:0] free_bitmap;
    logic [RS_SIZE-1:0] ready_bitmap;

    genvar i;
    generate
        for (i = 0; i < RS_SIZE; i++) begin : gen_bitmaps
            assign valid_bitmap[i] = entries[i].valid;
            assign free_bitmap[i] = ~entries[i].valid;
            assign ready_bitmap[i] = entries[i].valid && entries[i].ready;
        end
    endgenerate

    // Priority decoder for allocation (find first free slot)
    priority_decoder #(.WIDTH(RS_SIZE)) alloc_pd (
        .in(free_bitmap),
        .out(alloc_idx),
        .valid(alloc_valid)
    );

    assign full = ~alloc_valid;

    // Priority decoder for issue (find first ready instruction)
    logic issue_valid_internal;
    priority_decoder #(.WIDTH(RS_SIZE)) issue_pd (
        .in(ready_bitmap),
        .out(issue_idx),
        .valid(issue_valid_internal)
    );

    assign issue_en = issue_valid_internal && eu_ready;
    assign issue_entry = entries[issue_idx];

    // RS Entry Management
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            for (int j = 0; j < RS_SIZE; j++) begin
                entries[j].valid <= 1'b0;
                entries[j].ready <= 1'b0;
                entries[j].prs1_ready <= 1'b0;
                entries[j].prs2_ready <= 1'b0;
            end
        end
        else begin
            // Dispatch: allocate new entry
            if (dispatch_en && alloc_valid) begin
                entries[alloc_idx].valid <= 1'b1;
                entries[alloc_idx].prs1 <= dispatch_instr.prs1;
                entries[alloc_idx].prs2 <= dispatch_instr.prs2;
                entries[alloc_idx].prd <= dispatch_instr.prd;
                entries[alloc_idx].immediate <= dispatch_instr.immediate;
                entries[alloc_idx].alu_op <= dispatch_instr.alu_op;
                entries[alloc_idx].alu_src <= dispatch_instr.alu_src;
                entries[alloc_idx].mem_read <= dispatch_instr.mem_read;
                entries[alloc_idx].mem_write <= dispatch_instr.mem_write;
                entries[alloc_idx].reg_write <= dispatch_instr.reg_write;
                entries[alloc_idx].rob_tag <= dispatch_instr.rob_tag;
                entries[alloc_idx].pc <= dispatch_instr.pc;

                // For Phase 3: Assume all operands are ready at dispatch
                // (In a full implementation, we would check a ready bit table)
                entries[alloc_idx].prs1_ready <= 1'b1;
                entries[alloc_idx].prs2_ready <= 1'b1;
                entries[alloc_idx].ready <= 1'b1;
            end

            // Issue: deallocate entry
            if (issue_en) begin
                entries[issue_idx].valid <= 1'b0;
            end

            // Wakeup logic: Check all valid entries and mark operands ready
            for (int j = 0; j < RS_SIZE; j++) begin
                if (entries[j].valid && !entries[j].ready) begin
                    // Check if prs1 is ready
                    if (!entries[j].prs1_ready) begin
                        if ((wb_en_alu && entries[j].prs1 == wb_prd_alu) ||
                            (wb_en_branch && entries[j].prs1 == wb_prd_branch) ||
                            (wb_en_lsu && entries[j].prs1 == wb_prd_lsu)) begin
                            entries[j].prs1_ready <= 1'b1;
                        end
                    end

                    // Check if prs2 is ready
                    if (!entries[j].prs2_ready) begin
                        if ((wb_en_alu && entries[j].prs2 == wb_prd_alu) ||
                            (wb_en_branch && entries[j].prs2 == wb_prd_branch) ||
                            (wb_en_lsu && entries[j].prs2 == wb_prd_lsu)) begin
                            entries[j].prs2_ready <= 1'b1;
                        end
                    end

                    // Mark instruction ready if both operands are ready
                    if ((entries[j].prs1_ready || !entries[j].prs1_ready) &&
                        (entries[j].prs2_ready || !entries[j].prs2_ready)) begin
                        entries[j].ready <= (entries[j].prs1_ready && entries[j].prs2_ready);
                    end
                end
            end
        end
    end

endmodule
