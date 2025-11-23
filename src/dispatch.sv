import ooo_types::*;

module dispatch (
    input logic clk,
    input logic rst,

    // From rename→dispatch skid buffer
    input renamed_instr_t instr_in,
    input logic valid_in,
    output logic ready_out,

    // ROB interface
    output logic rob_alloc_en,
    output logic [ROB_BITS-1:0] rob_alloc_tag,
    output renamed_instr_t rob_alloc_instr,
    input logic rob_full,
    output logic rob_store_checkpoint,

    // Flush signal
    input logic flush,

    // Reservation station interfaces
    input logic rs_alu_full,
    output logic dispatch_alu_en,
    output renamed_instr_t dispatch_alu_instr,

    input logic rs_branch_full,
    output logic dispatch_branch_en,
    output renamed_instr_t dispatch_branch_instr,

    input logic rs_lsu_full,
    output logic dispatch_lsu_en,
    output renamed_instr_t dispatch_lsu_instr
);

    // ========================================================================
    // Internal Signals - Dispatch Logic
    // ========================================================================
    logic target_rs_full;
    logic can_dispatch;

    // ========================================================================
    // Dispatch Routing Logic
    // ========================================================================
    always_comb begin
        // Default: no dispatch
        dispatch_alu_en = 1'b0;
        dispatch_branch_en = 1'b0;
        dispatch_lsu_en = 1'b0;
        target_rs_full = 1'b1;

        if (valid_in) begin
            case (instr_in.fu_type)
                FU_ALU: begin
                    target_rs_full = rs_alu_full;
                    dispatch_alu_en = !rs_alu_full && !rob_full;
                end
                FU_BRANCH: begin
                    target_rs_full = rs_branch_full;
                    dispatch_branch_en = !rs_branch_full && !rob_full;
                end
                FU_LSU: begin
                    target_rs_full = rs_lsu_full;
                    dispatch_lsu_en = !rs_lsu_full && !rob_full;
                end
                default: begin
                    target_rs_full = 1'b1;
                end
            endcase
        end
    end

    // Can dispatch if target RS and ROB both have space
    assign can_dispatch = valid_in && !target_rs_full && !rob_full;

    // Backpressure to skid buffer
    assign ready_out = !target_rs_full && !rob_full;

    // ROB allocation (happens in parallel with RS allocation)
    assign rob_alloc_en = can_dispatch;
    assign rob_alloc_tag = instr_in.rob_tag;
    assign rob_alloc_instr = instr_in;

    // Pass checkpoint signal to ROB
    assign rob_store_checkpoint = can_dispatch && instr_in.is_branch;

    // Broadcast instruction to all RS (each will only accept if dispatch_*_en is high)
    assign dispatch_alu_instr = instr_in;
    assign dispatch_branch_instr = instr_in;
    assign dispatch_lsu_instr = instr_in;

endmodule
