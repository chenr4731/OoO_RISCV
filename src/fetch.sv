module  fetch#(
    parameter type T = logic [31:0]
) (
    input logic     clk,
    input logic     reset,

    input logic     take_branch,
    input T         branch_loc,

    input T         instr_from_cache,
    output T        pc_to_cache,
    
    output T        instr_to_decode,
    output T        pc_to_decode,

    input logic     ready,
    output logic    valid
);

T pc_reg;
T pc_next_def;
logic stall;
logic valid_reg;

assign stall = !ready && !valid_reg;

assign pc_next_def = pc_reg + 4; // Default case, need to add offset later
assign pc_to_to_cache = pc_reg;
assign pc_to_decode = pc_reg;
assign instr_to_decode = instr_from_cache;

assign valid = valid_reg; // Need to double check when this is set

always_ff @(posedge clk) begin
    if (reset) begin
        pc_reg <= 'b0;
        valid_reg <= 1'b0;
    end
    else begin
        if (stall) begin
            pc_reg <= pc_reg;
            valid_reg <= valid_reg;
        end
        else begin
            if (take_branch) begin
                pc_reg <= branch_loc;
                valid_reg <= 1'b1;
            end
            else begin
                pc_reg <= pc_next_def;
                valid_reg <= 1'b1;
            end
        end
    end
end

endmodule