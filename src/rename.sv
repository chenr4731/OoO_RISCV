import ooo_types::*;

module rename (
    input logic clk,
    input logic rst,

    // From decode (through skid buffer)
    input logic valid_in,
    output logic ready_out,
    input logic [31:0] pc_in,
    input logic [4:0] rs1_arch,
    input logic [4:0] rs2_arch,
    input logic [4:0] rd_arch,
    input logic [31:0] immediate,
    input logic [1:0] alu_op,
    input logic [1:0] fu_type,
    input logic alu_src,
    input logic mem_read,
    input logic mem_write,
    input logic reg_write,
    input logic is_branch,

    // To skid buffer
    output renamed_instr_t renamed_instr,
    output logic valid_out,
    input logic ready_in,

    // From ROB (for recovery)
    input logic mispredict,
    input logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] restore_map_table,
    input logic [PHYS_REG_BITS-1:0] restore_freelist_ptr,
    input logic [ROB_BITS-1:0] restore_rob_tag,

    // From commit (to free old mappings)
    input logic commit_en,
    input logic [PHYS_REG_BITS-1:0] commit_prd_old,

    // Checkpoint outputs (to ROB via dispatch)
    output logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] checkpoint_map_table_out,
    output logic [PHYS_REG_BITS-1:0] checkpoint_freelist_ptr_out,
    output logic [ROB_BITS-1:0] checkpoint_rob_tag_out
);

    // Signals from sub-modules
    logic [PHYS_REG_BITS-1:0] prs1, prs2, prd, prd_old;
    logic [PHYS_REG_BITS-1:0] alloc_preg;
    logic freelist_empty, freelist_full;
    logic [ROB_BITS-1:0] alloc_rob_tag;

    // Map table signals
    logic map_wr_en;
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] checkpoint_map_table;
    logic map_checkpoint_en;
    logic map_restore_en;

    // Free list signals
    logic freelist_alloc_en;
    logic freelist_dealloc_en;
    logic freelist_checkpoint_en;
    logic [PHYS_REG_BITS-1:0] checkpoint_freelist_ptr;
    logic freelist_restore_en;

    // ROB tag allocator signals
    logic rob_tag_alloc_en;
    logic rob_tag_checkpoint_en;
    logic [ROB_BITS-1:0] checkpoint_rob_tag;
    logic rob_tag_restore_en;

    // Checkpoint storage (for branch speculation)
    logic checkpoint_valid;
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] saved_checkpoint_map_table;
    logic [PHYS_REG_BITS-1:0] saved_checkpoint_freelist_ptr;
    logic [ROB_BITS-1:0] saved_checkpoint_rob_tag;

    // Instantiate map table
    map_table map_table_inst (
        .clk(clk),
        .rst(rst),
        .rs1_arch(rs1_arch),
        .rs2_arch(rs2_arch),
        .rs1_phys(prs1),
        .rs2_phys(prs2),
        .wr_en(map_wr_en),
        .rd_arch(rd_arch),
        .rd_phys(prd),
        .rd_phys_old(prd_old),
        .checkpoint_en(map_checkpoint_en),
        .checkpoint_table(checkpoint_map_table),
        .restore_en(map_restore_en),
        .restore_table(restore_map_table)
    );

    // Instantiate free list
    free_list free_list_inst (
        .clk(clk),
        .rst(rst),
        .alloc_en(freelist_alloc_en),
        .alloc_preg(alloc_preg),
        .empty(freelist_empty),
        .dealloc_en(freelist_dealloc_en),
        .dealloc_preg(commit_prd_old),
        .full(freelist_full),
        .checkpoint_en(freelist_checkpoint_en),
        .checkpoint_ptr(checkpoint_freelist_ptr),
        .restore_en(freelist_restore_en),
        .restore_ptr(restore_freelist_ptr)
    );

    // Instantiate ROB tag allocator
    rob_tag_allocator rob_tag_alloc_inst (
        .clk(clk),
        .rst(rst),
        .alloc_en(rob_tag_alloc_en),
        .alloc_tag(alloc_rob_tag),
        .checkpoint_en(rob_tag_checkpoint_en),
        .checkpoint_tag(checkpoint_rob_tag),
        .restore_en(rob_tag_restore_en),
        .restore_tag(restore_rob_tag)
    );

    // Determine if we can rename this instruction
    logic can_rename;
    logic need_alloc_prd;  // Only allocate if rd != x0 and reg_write

    assign need_alloc_prd = (rd_arch != 5'd0) && reg_write;
    assign can_rename = valid_in && ready_in &&
                       (!need_alloc_prd || !freelist_empty) &&
                       !(is_branch && checkpoint_valid);  // Stall if checkpoint exists

    // Control signals for sub-modules
    assign map_wr_en = can_rename && need_alloc_prd;
    assign freelist_alloc_en = can_rename && need_alloc_prd;
    assign freelist_dealloc_en = commit_en;
    assign rob_tag_alloc_en = can_rename;

    // Checkpoint creation (only for branches)
    assign map_checkpoint_en = can_rename && is_branch;
    assign freelist_checkpoint_en = can_rename && is_branch;
    assign rob_tag_checkpoint_en = can_rename && is_branch;

    // Restore on mispredict
    assign map_restore_en = mispredict;
    assign freelist_restore_en = mispredict;
    assign rob_tag_restore_en = mispredict;

    // Physical destination register
    assign prd = need_alloc_prd ? alloc_preg : 7'd0;

    // Build renamed instruction
    always_comb begin
        renamed_instr.valid = valid_in;
        renamed_instr.pc = pc_in;
        renamed_instr.prs1 = prs1;
        renamed_instr.prs2 = prs2;
        renamed_instr.prd = prd;
        renamed_instr.prd_old = prd_old;
        renamed_instr.ard = rd_arch;
        renamed_instr.immediate = immediate;
        renamed_instr.alu_op = alu_op;
        renamed_instr.fu_type = fu_type_t'(fu_type);
        renamed_instr.alu_src = alu_src;
        renamed_instr.mem_read = mem_read;
        renamed_instr.mem_write = mem_write;
        renamed_instr.reg_write = reg_write;
        renamed_instr.is_branch = is_branch;
        renamed_instr.rob_tag = alloc_rob_tag;
    end

    // Output control
    assign valid_out = can_rename;
    assign ready_out = can_rename || !valid_in;

    // Checkpoint outputs
    assign checkpoint_map_table_out = checkpoint_map_table;
    assign checkpoint_freelist_ptr_out = checkpoint_freelist_ptr;
    assign checkpoint_rob_tag_out = checkpoint_rob_tag;

    // Checkpoint management
    always_ff @(posedge clk) begin
        if (rst || mispredict) begin
            checkpoint_valid <= 1'b0;
        end
        else if (can_rename && is_branch) begin
            // Create checkpoint for branch
            checkpoint_valid <= 1'b1;
            saved_checkpoint_map_table <= checkpoint_map_table;
            saved_checkpoint_freelist_ptr <= checkpoint_freelist_ptr;
            saved_checkpoint_rob_tag <= checkpoint_rob_tag;
        end
        else if (commit_en && checkpoint_valid) begin
            // Clear checkpoint when oldest instruction commits
            // (This is simplified - should check if committing instruction is the branch)
            checkpoint_valid <= 1'b0;
        end
    end

endmodule
