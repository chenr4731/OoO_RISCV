import ooo_types::*;

module rob_tag_allocator (
    input logic clk,
    input logic rst,

    // Allocate new tag
    input logic alloc_en,
    output logic [ROB_BITS-1:0] alloc_tag,

    // Checkpoint for branch
    input logic checkpoint_en,
    output logic [ROB_BITS-1:0] checkpoint_tag,

    // Recovery
    input logic restore_en,
    input logic [ROB_BITS-1:0] restore_tag
);

    logic [ROB_BITS-1:0] tag_counter;

    assign alloc_tag = tag_counter;
    assign checkpoint_tag = tag_counter;

    always_ff @(posedge clk) begin
        if (rst) begin
            tag_counter <= 4'd0;
        end
        else if (restore_en) begin
            tag_counter <= restore_tag;
        end
        else if (alloc_en) begin
            tag_counter <= tag_counter + 1;  // Wraps at 16
        end
    end

endmodule
