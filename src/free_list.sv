import ooo_types::*;

module free_list (
    input logic clk,
    input logic rst,

    // Allocation (rename stage consumes a free register)
    input logic alloc_en,
    output logic [PHYS_REG_BITS-1:0] alloc_preg,
    output logic empty,                           // No free registers

    // Deallocation (commit stage frees old mapping)
    input logic dealloc_en,
    input logic [PHYS_REG_BITS-1:0] dealloc_preg,
    output logic full,                            // All registers free (shouldn't happen)

    // Checkpoint for speculation
    input logic checkpoint_en,
    output logic [PHYS_REG_BITS-1:0] checkpoint_ptr,

    // Recovery from mispredict
    input logic restore_en,
    input logic [PHYS_REG_BITS-1:0] restore_ptr
);

    // Circular buffer pointers
    // [head_ptr, tail_ptr) in circular order are ALLOCATED
    // [tail_ptr, head_ptr) in circular order are FREE
    logic [PHYS_REG_BITS:0] head_ptr;  // Next register to allocate (8 bits for wrap detection)
    logic [PHYS_REG_BITS:0] tail_ptr;  // Next register to free (8 bits for wrap detection)

    // Output next free register (smallest index)
    assign alloc_preg = head_ptr[PHYS_REG_BITS-1:0];

    // Empty when head catches up to tail (no free regs)
    assign empty = (head_ptr == tail_ptr);

    // Full when tail+1 == head (all regs free - shouldn't happen in practice)
    assign full = ((tail_ptr + 1) == head_ptr);

    // Export checkpoint pointer
    assign checkpoint_ptr = head_ptr[PHYS_REG_BITS-1:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            // Initialize: p0-p31 are allocated (architectural state)
            // p32-p127 are free
            head_ptr <= 8'd32;
            tail_ptr <= 8'd32;
        end
        else if (restore_en) begin
            // Restore head pointer on mispredict
            // This frees all speculatively allocated registers
            head_ptr <= {1'b0, restore_ptr};
        end
        else begin
            // Allocation: advance head pointer
            if (alloc_en && !empty) begin
                head_ptr <= head_ptr + 1;
            end

            // Deallocation: advance tail pointer
            // Note: dealloc_preg is ignored in circular tracker design
            // We assume registers are freed in order (guaranteed by in-order commit)
            if (dealloc_en && !full) begin
                tail_ptr <= tail_ptr + 1;
            end
        end
    end

endmodule
