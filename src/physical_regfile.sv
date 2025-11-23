import ooo_types::*;

module physical_regfile (
    input logic clk,
    input logic rst,

    // Read ports (combinational) - 6 total (2 per FU)
    input logic [PHYS_REG_BITS-1:0] rs1_alu,
    input logic [PHYS_REG_BITS-1:0] rs2_alu,
    input logic [PHYS_REG_BITS-1:0] rs1_branch,
    input logic [PHYS_REG_BITS-1:0] rs2_branch,
    input logic [PHYS_REG_BITS-1:0] rs1_lsu,
    input logic [PHYS_REG_BITS-1:0] rs2_lsu,

    output logic [31:0] rd1_alu,
    output logic [31:0] rd2_alu,
    output logic [31:0] rd1_branch,
    output logic [31:0] rd2_branch,
    output logic [31:0] rd1_lsu,
    output logic [31:0] rd2_lsu,

    // Write ports (sequential) - 3 total (1 per FU)
    input logic we_alu,
    input logic [PHYS_REG_BITS-1:0] wa_alu,
    input logic [31:0] wd_alu,

    input logic we_branch,
    input logic [PHYS_REG_BITS-1:0] wa_branch,
    input logic [31:0] wd_branch,

    input logic we_lsu,
    input logic [PHYS_REG_BITS-1:0] wa_lsu,
    input logic [31:0] wd_lsu
);

    // Storage array: 128 physical registers
    logic [31:0] registers [0:NUM_PHYS_REGS-1];

    // Combinational reads (6 read ports)
    assign rd1_alu = registers[rs1_alu];
    assign rd2_alu = registers[rs2_alu];
    assign rd1_branch = registers[rs1_branch];
    assign rd2_branch = registers[rs2_branch];
    assign rd1_lsu = registers[rs1_lsu];
    assign rd2_lsu = registers[rs2_lsu];

    // Sequential writes (3 write ports with priority: ALU > Branch > LSU)
    always_ff @(posedge clk) begin
        if (rst) begin
            // Initialize all registers to 0
            for (int i = 0; i < NUM_PHYS_REGS; i++) begin
                registers[i] <= 32'd0;
            end
        end
        else begin
            // p0 is always 0 (for x0)
            registers[0] <= 32'd0;

            // Write port 1: ALU
            if (we_alu && wa_alu != 7'd0) begin
                registers[wa_alu] <= wd_alu;
            end

            // Write port 2: Branch
            if (we_branch && wa_branch != 7'd0) begin
                // Check for conflicts with ALU write
                if (!(we_alu && wa_alu == wa_branch)) begin
                    registers[wa_branch] <= wd_branch;
                end
            end

            // Write port 3: LSU
            if (we_lsu && wa_lsu != 7'd0) begin
                // Check for conflicts with ALU and Branch writes
                if (!(we_alu && wa_alu == wa_lsu) &&
                    !(we_branch && wa_branch == wa_lsu)) begin
                    registers[wa_lsu] <= wd_lsu;
                end
            end
        end
    end

endmodule
