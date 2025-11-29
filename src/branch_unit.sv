import ooo_types::*;

module branch_unit (
    input logic clk,
    input logic rst,

    // Issue interface (from RS)
    input logic issue_en,
    input rs_entry_t issue_entry,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    output logic ready,

    // Writeback interface (to PRF) - for JALR which writes PC+4
    output logic wb_en,
    output logic [PHYS_REG_BITS-1:0] wb_prd,
    output logic [31:0] wb_data,

    // Completion interface (to ROB)
    output logic complete_en,
    output logic [ROB_BITS-1:0] complete_tag,
    output logic branch_taken,
    output logic [31:0] branch_target,

    // Misprediction flag (for pipeline flush - to be used in Phase 4)
    output logic mispredict,
    output logic [31:0] mispredict_target,

    // Flush
    input logic flush
);

    // Branch funct3 encodings (from RISC-V spec)
    localparam FUNCT3_BEQ  = 3'b000;
    localparam FUNCT3_BNE  = 3'b001;
    localparam FUNCT3_BLT  = 3'b100;
    localparam FUNCT3_BGE  = 3'b101;
    localparam FUNCT3_BLTU = 3'b110;
    localparam FUNCT3_BGEU = 3'b111;

    // ALUOp encodings (from decoder.sv)
    localparam ALU_JALR   = 2'b00;
    localparam ALU_BRANCH = 2'b01;

    // Pipeline register for 1-cycle execution
    typedef struct packed {
        logic valid;
        logic [PHYS_REG_BITS-1:0] prd;
        logic [ROB_BITS-1:0] rob_tag;
        logic reg_write;
        logic [31:0] result;
        logic taken;
        logic [31:0] target;
        logic is_mispredict;
    } branch_pipe_t;

    branch_pipe_t pipe;

    // Combinational branch computation
    logic branch_taken_comb;
    logic [31:0] branch_target_comb;
    logic [31:0] funct3;
    logic is_jalr;
    logic is_branch;

    assign is_jalr = (issue_entry.alu_op == ALU_JALR);
    assign is_branch = (issue_entry.alu_op == ALU_BRANCH);

    // Extract funct3 from immediate (decoder stores full immediate, need to extract from original)
    // For branches, we need funct3 from the original instruction
    // Since we don't have access to original instruction, we'll use alu_op to distinguish
    // For now, we'll use the lower bits of immediate to infer branch type
    // This is a simplification - in a real design, we'd pass funct3 explicitly

    // Compute branch condition
    always_comb begin
        if (is_jalr) begin
            // JALR: always taken
            branch_taken_comb = 1'b1;
            branch_target_comb = (rs1_data + issue_entry.immediate) & ~32'b1; // Clear LSB
        end
        else if (is_branch) begin
            // Conditional branch - use immediate[2:0] as funct3 placeholder
            // In actual implementation, funct3 should be passed through RS entry
            funct3 = issue_entry.immediate[2:0];

            case (funct3)
                FUNCT3_BEQ:  branch_taken_comb = (rs1_data == rs2_data);
                FUNCT3_BNE:  branch_taken_comb = (rs1_data != rs2_data);
                FUNCT3_BLT:  branch_taken_comb = ($signed(rs1_data) < $signed(rs2_data));
                FUNCT3_BGE:  branch_taken_comb = ($signed(rs1_data) >= $signed(rs2_data));
                FUNCT3_BLTU: branch_taken_comb = (rs1_data < rs2_data);
                FUNCT3_BGEU: branch_taken_comb = (rs1_data >= rs2_data);
                default:     branch_taken_comb = 1'b0;
            endcase

            // Branch target: PC + immediate (immediate already has LSB cleared)
            branch_target_comb = issue_entry.pc + issue_entry.immediate;
        end
        else begin
            branch_taken_comb = 1'b0;
            branch_target_comb = 32'd0;
        end
    end

    // Always ready to accept new instructions (1 cycle latency)
    assign ready = 1'b1;

    // Writeback outputs (for JALR - writes PC+4 to rd)
    assign wb_en = pipe.valid && pipe.reg_write;
    assign wb_prd = pipe.prd;
    assign wb_data = pipe.result; // PC+4 for JALR

    // Completion outputs
    assign complete_en = pipe.valid;
    assign complete_tag = pipe.rob_tag;
    assign branch_taken = pipe.taken;
    assign branch_target = pipe.target;

    // Misprediction detection (assume always predict not-taken)
    // Misprediction occurs when branch is taken
    assign mispredict = pipe.valid && pipe.is_mispredict;
    assign mispredict_target = pipe.target;

    // Pipeline execution
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            pipe.valid <= 1'b0;
            pipe.prd <= '0;
            pipe.rob_tag <= '0;
            pipe.reg_write <= 1'b0;
            pipe.result <= 32'd0;
            pipe.taken <= 1'b0;
            pipe.target <= 32'd0;
            pipe.is_mispredict <= 1'b0;
        end
        else begin
            if (issue_en) begin
                pipe.valid <= 1'b1;
                pipe.prd <= issue_entry.prd;
                pipe.rob_tag <= issue_entry.rob_tag;
                pipe.reg_write <= issue_entry.reg_write;
                pipe.result <= issue_entry.pc + 4; // PC+4 for JALR
                pipe.taken <= branch_taken_comb;
                pipe.target <= branch_target_comb;
                // Mispredict if branch is taken (we predict not-taken)
                pipe.is_mispredict <= branch_taken_comb;
            end
            else begin
                pipe.valid <= 1'b0;
            end
        end
    end

endmodule
