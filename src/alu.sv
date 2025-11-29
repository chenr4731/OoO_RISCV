import ooo_types::*;

module alu (
    input logic clk,
    input logic rst,

    // Issue interface (from RS)
    input logic issue_en,
    input rs_entry_t issue_entry,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    output logic ready,

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

    // ALU operations (matching decoder.sv ALUOp encoding)
    localparam ALU_ADD  = 2'b00;
    localparam ALU_SUB  = 2'b01;
    localparam ALU_AND  = 2'b10;
    localparam ALU_OR   = 2'b11;

    // Pipeline register for 1-cycle execution
    typedef struct packed {
        logic valid;
        logic [PHYS_REG_BITS-1:0] prd;
        logic [ROB_BITS-1:0] rob_tag;
        logic reg_write;
        logic [31:0] result;
    } alu_pipe_t;

    alu_pipe_t pipe;

    // Combinational ALU computation
    logic [31:0] alu_result;
    logic [31:0] operand2;

    // Select second operand: rs2 or immediate
    assign operand2 = issue_entry.alu_src ? issue_entry.immediate : rs2_data;

    always_comb begin
        case (issue_entry.alu_op)
            ALU_ADD:  alu_result = rs1_data + operand2;
            ALU_SUB:  alu_result = rs1_data - operand2;
            ALU_AND:  alu_result = rs1_data & operand2;
            ALU_OR:   alu_result = rs1_data | operand2;
            default:  alu_result = 32'd0;
        endcase
    end

    // Always ready to accept new instructions (1 cycle latency)
    assign ready = 1'b1;

    // Writeback outputs (from pipeline register)
    assign wb_en = pipe.valid && pipe.reg_write;
    assign wb_prd = pipe.prd;
    assign wb_data = pipe.result;

    // Completion outputs (from pipeline register)
    assign complete_en = pipe.valid;
    assign complete_tag = pipe.rob_tag;

    // Pipeline execution
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            pipe.valid <= 1'b0;
            pipe.prd <= '0;
            pipe.rob_tag <= '0;
            pipe.reg_write <= 1'b0;
            pipe.result <= 32'd0;
        end
        else begin
            if (issue_en) begin
                pipe.valid <= 1'b1;
                pipe.prd <= issue_entry.prd;
                pipe.rob_tag <= issue_entry.rob_tag;
                pipe.reg_write <= issue_entry.reg_write;
                pipe.result <= alu_result;
            end
            else begin
                pipe.valid <= 1'b0;
            end
        end
    end

endmodule
