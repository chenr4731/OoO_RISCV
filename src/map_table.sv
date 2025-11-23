import ooo_types::*;

module map_table (
    input logic clk,
    input logic rst,

    // Lookup ports (combinational reads)
    input logic [4:0] rs1_arch,
    input logic [4:0] rs2_arch,
    output logic [PHYS_REG_BITS-1:0] rs1_phys,
    output logic [PHYS_REG_BITS-1:0] rs2_phys,

    // Update port (rename writes new mapping)
    input logic wr_en,
    input logic [4:0] rd_arch,
    input logic [PHYS_REG_BITS-1:0] rd_phys,
    output logic [PHYS_REG_BITS-1:0] rd_phys_old,  // Previous mapping

    // Checkpoint for branch speculation
    input logic checkpoint_en,
    output logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] checkpoint_table,

    // Recovery from mispredict
    input logic restore_en,
    input logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] restore_table
);

    // Map table storage: architectural register -> physical register
    logic [PHYS_REG_BITS-1:0] map [0:NUM_ARCH_REGS-1];

    // Combinational reads for source registers
    // x0 always maps to p0 (hardwired to 0 in PRF)
    assign rs1_phys = (rs1_arch == 5'd0) ? 7'd0 : map[rs1_arch];
    assign rs2_phys = (rs2_arch == 5'd0) ? 7'd0 : map[rs2_arch];

    // Read old mapping before update (combinational)
    assign rd_phys_old = (rd_arch == 5'd0) ? 7'd0 : map[rd_arch];

    // Checkpoint: export entire map table
    always_comb begin
        for (int i = 0; i < NUM_ARCH_REGS; i++) begin
            checkpoint_table[i] = map[i];
        end
    end

    // Sequential write and restore
    always_ff @(posedge clk) begin
        if (rst) begin
            // Initialize with identity mapping: x0->p0, x1->p1, ..., x31->p31
            for (int i = 0; i < NUM_ARCH_REGS; i++) begin
                map[i] <= i[PHYS_REG_BITS-1:0];
            end
        end
        else if (restore_en) begin
            // Restore from checkpoint on mispredict
            for (int i = 0; i < NUM_ARCH_REGS; i++) begin
                map[i] <= restore_table[i];
            end
        end
        else if (wr_en && rd_arch != 5'd0) begin
            // Don't update x0 mapping (always p0)
            map[rd_arch] <= rd_phys;
        end
    end

endmodule
