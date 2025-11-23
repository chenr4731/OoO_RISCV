import ooo_types::*;

module rob (
    input logic clk,
    input logic rst,

    // Allocation (from dispatch)
    input logic alloc_en,
    input logic [ROB_BITS-1:0] alloc_tag,
    input renamed_instr_t alloc_instr,
    output logic full,
    output logic empty,

    // Checkpoint storage (from rename)
    input logic store_checkpoint,
    input logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] checkpoint_map_table,
    input logic [PHYS_REG_BITS-1:0] checkpoint_freelist_ptr,
    input logic [ROB_BITS-1:0] checkpoint_rob_tag,

    // Completion (from execution units - placeholder for future)
    input logic complete_en,
    input logic [ROB_BITS-1:0] complete_tag,
    input logic branch_taken,        // For branches
    input logic [31:0] branch_target,

    // Commit (head of ROB)
    output logic commit_en,
    output logic [4:0] commit_ard,
    output logic [PHYS_REG_BITS-1:0] commit_prd,
    output logic [PHYS_REG_BITS-1:0] commit_prd_old,
    output logic commit_reg_write,

    // Mispredict detection and recovery
    output logic mispredict,
    output logic [31:0] mispredict_target,
    output logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] restore_map_table,
    output logic [PHYS_REG_BITS-1:0] restore_freelist_ptr,
    output logic [ROB_BITS-1:0] restore_rob_tag
);

    // ROB entry storage
    rob_entry_t rob_entries [0:ROB_SIZE-1];

    // Circular buffer pointers
    logic [ROB_BITS-1:0] head_ptr;  // Oldest instruction (commit point)
    logic [ROB_BITS-1:0] tail_ptr;  // Next allocation slot
    logic [ROB_BITS:0] count;       // Number of valid entries (5 bits for 0-16)

    assign full = (count == ROB_SIZE);
    assign empty = (count == 0);

    // Commit logic: commit head if it's valid and ready
    assign commit_en = !empty && rob_entries[head_ptr].valid &&
                       rob_entries[head_ptr].ready && !mispredict;

    assign commit_ard = rob_entries[head_ptr].ard;
    assign commit_prd = rob_entries[head_ptr].prd;
    assign commit_prd_old = rob_entries[head_ptr].prd_old;
    assign commit_reg_write = rob_entries[head_ptr].reg_write;

    // Mispredict detection (simplified: always predict not-taken)
    logic is_mispredicted;
    assign is_mispredicted = commit_en &&
                            rob_entries[head_ptr].is_branch &&
                            rob_entries[head_ptr].branch_taken;  // Predicted not-taken, but was taken

    assign mispredict = is_mispredicted;
    assign mispredict_target = rob_entries[head_ptr].branch_target;

    // Restore checkpoint from mispredicted branch
    assign restore_map_table = rob_entries[head_ptr].checkpoint_map_table;
    assign restore_freelist_ptr = rob_entries[head_ptr].checkpoint_freelist_ptr;
    assign restore_rob_tag = rob_entries[head_ptr].checkpoint_rob_tag;

    // ROB management
    always_ff @(posedge clk) begin
        if (rst) begin
            head_ptr <= 4'd0;
            tail_ptr <= 4'd0;
            count <= 5'd0;
            for (int i = 0; i < ROB_SIZE; i++) begin
                rob_entries[i].valid <= 1'b0;
                rob_entries[i].ready <= 1'b0;
                rob_entries[i].has_checkpoint <= 1'b0;
            end
        end
        else begin
            // Allocation
            if (alloc_en && !full) begin
                rob_entries[tail_ptr].valid <= 1'b1;
                rob_entries[tail_ptr].ready <= 1'b0;  // Not complete yet
                rob_entries[tail_ptr].ard <= alloc_instr.ard;
                rob_entries[tail_ptr].prd <= alloc_instr.prd;
                rob_entries[tail_ptr].prd_old <= alloc_instr.prd_old;
                rob_entries[tail_ptr].reg_write <= alloc_instr.reg_write;
                rob_entries[tail_ptr].is_branch <= alloc_instr.is_branch;
                rob_entries[tail_ptr].branch_taken <= 1'b0;
                rob_entries[tail_ptr].branch_mispredict <= 1'b0;
                rob_entries[tail_ptr].branch_target <= 32'd0;
                rob_entries[tail_ptr].has_checkpoint <= 1'b0;

                // Store checkpoint if this is a branch
                if (store_checkpoint && alloc_instr.is_branch) begin
                    rob_entries[tail_ptr].has_checkpoint <= 1'b1;
                    rob_entries[tail_ptr].checkpoint_map_table <= checkpoint_map_table;
                    rob_entries[tail_ptr].checkpoint_freelist_ptr <= checkpoint_freelist_ptr;
                    rob_entries[tail_ptr].checkpoint_rob_tag <= checkpoint_rob_tag;
                end

                tail_ptr <= tail_ptr + 1;
                count <= count + 1;
            end

            // Completion (placeholder - will be connected to execution units later)
            if (complete_en) begin
                rob_entries[complete_tag].ready <= 1'b1;
                if (rob_entries[complete_tag].is_branch) begin
                    rob_entries[complete_tag].branch_taken <= branch_taken;
                    rob_entries[complete_tag].branch_target <= branch_target;
                end
            end

            // Commit
            if (commit_en && !mispredict) begin
                rob_entries[head_ptr].valid <= 1'b0;
                head_ptr <= head_ptr + 1;
                count <= count - 1;
            end

            // Flush on mispredict
            if (mispredict) begin
                // Invalidate all entries after the mispredicted branch
                // Keep only the branch itself, commit it, then flush pipeline
                for (int i = 0; i < ROB_SIZE; i++) begin
                    if (i != head_ptr) begin
                        rob_entries[i].valid <= 1'b0;
                    end
                end
                // Reset tail to head+1 (everything flushed)
                tail_ptr <= head_ptr + 1;
                count <= 1;  // Only the mispredicted branch remains

                // Mark branch as committed
                rob_entries[head_ptr].valid <= 1'b0;
                head_ptr <= head_ptr + 1;
                count <= 5'd0;
            end
        end
    end

    // For Assignment 2: Mark all instructions as ready immediately (no execution)
    // This will be removed in later assignments when we have actual execution units
    always_ff @(posedge clk) begin
        if (!rst) begin
            for (int i = 0; i < ROB_SIZE; i++) begin
                if (rob_entries[i].valid && !rob_entries[i].ready) begin
                    // Auto-complete after 1 cycle (for testing only)
                    rob_entries[i].ready <= 1'b1;
                end
            end
        end
    end

endmodule
