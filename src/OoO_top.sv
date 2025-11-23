import ooo_types::*;

module OoO_top #(
    parameter type T = logic [31:0]
)(
    input logic clk,
    input logic rst
);

    // ========================================================================
    // FETCH STAGE
    // ========================================================================
    logic [8:0] fetch_to_cache_pc;
    T cache_to_fetch_instr;
    logic ena;

    assign ena = 1'b1;  // Always enable cache

    blk_mem_gen_0 icache(
        .addra(fetch_to_cache_pc),
        .clka(clk),
        .douta(cache_to_fetch_instr),
        .ena(ena)
    );

    logic [31:0] fetch_to_skid_instr;
    logic [8:0] fetch_to_skid_pc;
    logic skid_to_fetch_ready;
    logic fetch_to_skid_valid;

    fetch instr_fetch(
        .clk(clk),
        .reset(rst),
        .take_branch(1'b0),           // TODO: Connect to branch resolution
        .branch_loc(32'd0),            // TODO: Connect to branch target
        .instr_from_cache(cache_to_fetch_instr),
        .pc_to_cache(fetch_to_cache_pc),
        .instr_to_decode(fetch_to_skid_instr),
        .pc_to_decode(fetch_to_skid_pc),
        .ready(skid_to_fetch_ready),
        .valid(fetch_to_skid_valid)
    );

    // ========================================================================
    // FETCH → DECODE SKID BUFFERS
    // ========================================================================
    logic skid_to_decode_valid;
    logic decode_to_skid_ready;
    logic [31:0] skid_to_decode_instr;
    logic [8:0] skid_to_decode_pc;

    skid_buffer_struct #(.T(logic [31:0])) fetch_decode_skid_buffer_instr(
        .clk(clk),
        .reset(rst),
        .valid_in(fetch_to_skid_valid),
        .ready_out(skid_to_fetch_ready),
        .data_in(fetch_to_skid_instr),
        .valid_out(skid_to_decode_valid),
        .ready_in(decode_to_skid_ready),
        .data_out(skid_to_decode_instr)
    );

    skid_buffer_struct #(.T(logic [8:0])) fetch_decode_skid_buffer_pc(
        .clk(clk),
        .reset(rst),
        .valid_in(fetch_to_skid_valid),
        .ready_out(),  // Not used
        .data_in(fetch_to_skid_pc),
        .valid_out(),  // Not used
        .ready_in(decode_to_skid_ready),
        .data_out(skid_to_decode_pc)
    );

    // ========================================================================
    // DECODE STAGE
    // ========================================================================
    logic rename_to_decode_ready;
    logic [8:0] decode_to_rename_pc;
    logic decode_to_rename_valid;
    logic [4:0] decode_to_rename_rs1;
    logic [4:0] decode_to_rename_rs2;
    logic [4:0] decode_to_rename_rd;
    logic decode_to_rename_ALUsrc;
    logic decode_to_rename_Branch;
    T decode_to_rename_immediate;
    logic [1:0] decode_to_rename_ALUOp;
    logic [1:0] decode_to_rename_FUtype;
    logic decode_to_rename_Memread;
    logic decode_to_rename_Memwrite;
    logic decode_to_rename_Regwrite;

    decoder instr_decoder(
        .instruction(skid_to_decode_instr),
        .i_pc(skid_to_decode_pc),
        .i_valid(skid_to_decode_valid),
        .i_ready(rename_to_decode_ready),
        .o_ready(decode_to_skid_ready),
        .o_pc(decode_to_rename_pc),
        .o_valid(decode_to_rename_valid),
        .rs1(decode_to_rename_rs1),
        .rs2(decode_to_rename_rs2),
        .rd(decode_to_rename_rd),
        .ALUsrc(decode_to_rename_ALUsrc),
        .Branch(decode_to_rename_Branch),
        .immediate(decode_to_rename_immediate),
        .ALUOp(decode_to_rename_ALUOp),
        .FUtype(decode_to_rename_FUtype),
        .Memread(decode_to_rename_Memread),
        .Memwrite(decode_to_rename_Memwrite),
        .Regwrite(decode_to_rename_Regwrite)
    );

    // ========================================================================
    // DECODE → RENAME SKID BUFFERS
    // ========================================================================
    logic skid_to_rename_valid;
    logic rename_to_skid_ready;
    logic [8:0] skid_to_rename_pc;
    logic [4:0] skid_to_rename_rs1;
    logic [4:0] skid_to_rename_rs2;
    logic [4:0] skid_to_rename_rd;
    logic skid_to_rename_ALUsrc;
    logic skid_to_rename_Branch;
    T skid_to_rename_immediate;
    logic [1:0] skid_to_rename_ALUOp;
    logic [1:0] skid_to_rename_FUtype;
    logic skid_to_rename_Memread;
    logic skid_to_rename_Memwrite;
    logic skid_to_rename_Regwrite;

    skid_buffer_struct #(.T(logic [8:0])) decode_rename_skid_pc(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(rename_to_decode_ready),
        .data_in(decode_to_rename_pc),
        .valid_out(skid_to_rename_valid),
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_pc)
    );

    skid_buffer_struct #(.T(logic [4:0])) decode_rename_skid_rs1(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_rs1),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_rs1)
    );

    skid_buffer_struct #(.T(logic [4:0])) decode_rename_skid_rs2(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_rs2),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_rs2)
    );

    skid_buffer_struct #(.T(logic [4:0])) decode_rename_skid_rd(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_rd),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_rd)
    );

    skid_buffer_struct #(.T(logic)) decode_rename_skid_ALUsrc(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_ALUsrc),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_ALUsrc)
    );

    skid_buffer_struct #(.T(logic)) decode_rename_skid_Branch(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_Branch),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_Branch)
    );

    skid_buffer_struct #(.T(logic [31:0])) decode_rename_skid_immediate(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_immediate),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_immediate)
    );

    skid_buffer_struct #(.T(logic [1:0])) decode_rename_skid_ALUOp(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_ALUOp),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_ALUOp)
    );

    skid_buffer_struct #(.T(logic [1:0])) decode_rename_skid_FUtype(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_FUtype),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_FUtype)
    );

    skid_buffer_struct #(.T(logic)) decode_rename_skid_Memread(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_Memread),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_Memread)
    );

    skid_buffer_struct #(.T(logic)) decode_rename_skid_Memwrite(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_Memwrite),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_Memwrite)
    );

    skid_buffer_struct #(.T(logic)) decode_rename_skid_Regwrite(
        .clk(clk),
        .reset(rst),
        .valid_in(decode_to_rename_valid),
        .ready_out(),  // Not used
        .data_in(decode_to_rename_Regwrite),
        .valid_out(),  // Not used
        .ready_in(rename_to_skid_ready),
        .data_out(skid_to_rename_Regwrite)
    );

    // ========================================================================
    // RENAME STAGE
    // ========================================================================
    renamed_instr_t rename_to_skid_instr;
    logic rename_to_skid_valid;
    logic skid_to_rename_ready;

    // Dispatch → Rename signals
    logic dispatch_mispredict;
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] dispatch_restore_map_table;
    logic [PHYS_REG_BITS-1:0] dispatch_restore_freelist_ptr;
    logic [ROB_BITS-1:0] dispatch_restore_rob_tag;
    logic dispatch_commit_en;
    logic [PHYS_REG_BITS-1:0] dispatch_commit_prd_old;

    // Rename → Dispatch checkpoint signals
    logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] rename_checkpoint_map_table;
    logic [PHYS_REG_BITS-1:0] rename_checkpoint_freelist_ptr;
    logic [ROB_BITS-1:0] rename_checkpoint_rob_tag;

    rename rename_stage(
        .clk(clk),
        .rst(rst),
        .valid_in(skid_to_rename_valid),
        .ready_out(rename_to_skid_ready),
        .pc_in({23'b0, skid_to_rename_pc}),  // Extend to 32 bits
        .rs1_arch(skid_to_rename_rs1),
        .rs2_arch(skid_to_rename_rs2),
        .rd_arch(skid_to_rename_rd),
        .immediate(skid_to_rename_immediate),
        .alu_op(skid_to_rename_ALUOp),
        .fu_type(skid_to_rename_FUtype),
        .alu_src(skid_to_rename_ALUsrc),
        .mem_read(skid_to_rename_Memread),
        .mem_write(skid_to_rename_Memwrite),
        .reg_write(skid_to_rename_Regwrite),
        .is_branch(skid_to_rename_Branch),
        .renamed_instr(rename_to_skid_instr),
        .valid_out(rename_to_skid_valid),
        .ready_in(skid_to_rename_ready),
        .mispredict(dispatch_mispredict),
        .restore_map_table(dispatch_restore_map_table),
        .restore_freelist_ptr(dispatch_restore_freelist_ptr),
        .restore_rob_tag(dispatch_restore_rob_tag),
        .commit_en(dispatch_commit_en),
        .commit_prd_old(dispatch_commit_prd_old),
        .checkpoint_map_table_out(rename_checkpoint_map_table),
        .checkpoint_freelist_ptr_out(rename_checkpoint_freelist_ptr),
        .checkpoint_rob_tag_out(rename_checkpoint_rob_tag)
    );

    // ========================================================================
    // DISPATCH SKID BUFFER
    // ========================================================================
    renamed_instr_t skid_to_dispatch_instr;
    logic skid_to_dispatch_valid;
    logic dispatch_to_skid_ready;

    // Flush skid buffer on mispredict by asserting reset
    logic skid_reset;
    assign skid_reset = rst || dispatch_mispredict;

    skid_buffer_struct #(.T(renamed_instr_t)) rename_dispatch_skid(
        .clk(clk),
        .reset(skid_reset),
        .valid_in(rename_to_skid_valid),
        .ready_out(skid_to_rename_ready),
        .data_in(rename_to_skid_instr),
        .valid_out(skid_to_dispatch_valid),
        .ready_in(dispatch_to_skid_ready),
        .data_out(skid_to_dispatch_instr)
    );

    // ========================================================================
    // DISPATCH STAGE
    // ========================================================================
    logic dispatch_rob_alloc_en;
    logic [ROB_BITS-1:0] dispatch_rob_alloc_tag;
    renamed_instr_t dispatch_rob_alloc_instr;
    logic rob_full;
    logic dispatch_rob_store_checkpoint;

    // Reservation station signals
    logic rs_alu_full, rs_branch_full, rs_lsu_full;
    logic dispatch_alu_en, dispatch_branch_en, dispatch_lsu_en;
    renamed_instr_t dispatch_alu_instr, dispatch_branch_instr, dispatch_lsu_instr;

    dispatch dispatch_stage(
        .clk(clk),
        .rst(rst),
        .instr_in(skid_to_dispatch_instr),
        .valid_in(skid_to_dispatch_valid),
        .ready_out(dispatch_to_skid_ready),
        .rob_alloc_en(dispatch_rob_alloc_en),
        .rob_alloc_tag(dispatch_rob_alloc_tag),
        .rob_alloc_instr(dispatch_rob_alloc_instr),
        .rob_full(rob_full),
        .rob_store_checkpoint(dispatch_rob_store_checkpoint),
        .flush(dispatch_mispredict),
        .rs_alu_full(rs_alu_full),
        .dispatch_alu_en(dispatch_alu_en),
        .dispatch_alu_instr(dispatch_alu_instr),
        .rs_branch_full(rs_branch_full),
        .dispatch_branch_en(dispatch_branch_en),
        .dispatch_branch_instr(dispatch_branch_instr),
        .rs_lsu_full(rs_lsu_full),
        .dispatch_lsu_en(dispatch_lsu_en),
        .dispatch_lsu_instr(dispatch_lsu_instr)
    );

    // ========================================================================
    // REORDER BUFFER (ROB) - COMMIT STAGE
    // ========================================================================
    logic rob_empty;
    logic [4:0] rob_commit_ard;
    logic [PHYS_REG_BITS-1:0] rob_commit_prd;
    logic rob_commit_reg_write;
    logic [31:0] dispatch_mispredict_target;

    rob rob_inst(
        .clk(clk),
        .rst(rst),
        .alloc_en(dispatch_rob_alloc_en),
        .alloc_tag(dispatch_rob_alloc_tag),
        .alloc_instr(dispatch_rob_alloc_instr),
        .full(rob_full),
        .empty(rob_empty),
        .store_checkpoint(dispatch_rob_store_checkpoint),
        .checkpoint_map_table(rename_checkpoint_map_table),
        .checkpoint_freelist_ptr(rename_checkpoint_freelist_ptr),
        .checkpoint_rob_tag(rename_checkpoint_rob_tag),
        .complete_en(1'b0),          // TODO: Connect to execution units
        .complete_tag(4'd0),
        .branch_taken(1'b0),
        .branch_target(32'd0),
        .commit_en(dispatch_commit_en),
        .commit_ard(rob_commit_ard),
        .commit_prd(rob_commit_prd),
        .commit_prd_old(dispatch_commit_prd_old),
        .commit_reg_write(rob_commit_reg_write),
        .mispredict(dispatch_mispredict),
        .mispredict_target(dispatch_mispredict_target),
        .restore_map_table(dispatch_restore_map_table),
        .restore_freelist_ptr(dispatch_restore_freelist_ptr),
        .restore_rob_tag(dispatch_restore_rob_tag)
    );

    // ========================================================================
    // RESERVATION STATIONS
    // ========================================================================
    logic issue_alu_en;
    rs_entry_t issue_alu_entry;
    logic [RS_BITS-1:0] issue_alu_idx;

    logic issue_branch_en;
    rs_entry_t issue_branch_entry;
    logic [RS_BITS-1:0] issue_branch_idx;

    logic issue_lsu_en;
    rs_entry_t issue_lsu_entry;
    logic [RS_BITS-1:0] issue_lsu_idx;

    // Writeback signals (TODO: Connect to execution units)
    logic wb_en;
    logic [PHYS_REG_BITS-1:0] wb_prd;
    assign wb_en = 1'b0;
    assign wb_prd = 7'd0;

    reservation_station #(.RS_SIZE(RS_ALU_SIZE)) rs_alu(
        .clk(clk),
        .rst(rst),
        .dispatch_en(dispatch_alu_en),
        .dispatch_instr(dispatch_alu_instr),
        .full(rs_alu_full),
        .alloc_idx(),
        .alloc_valid(),
        .issue_en(issue_alu_en),
        .issue_entry(issue_alu_entry),
        .issue_idx(issue_alu_idx),
        .eu_ready(1'b1),         // TODO: Connect to ALU execution unit
        .wb_en(wb_en),
        .wb_prd(wb_prd),
        .flush(dispatch_mispredict)
    );

    reservation_station #(.RS_SIZE(RS_BRANCH_SIZE)) rs_branch(
        .clk(clk),
        .rst(rst),
        .dispatch_en(dispatch_branch_en),
        .dispatch_instr(dispatch_branch_instr),
        .full(rs_branch_full),
        .alloc_idx(),
        .alloc_valid(),
        .issue_en(issue_branch_en),
        .issue_entry(issue_branch_entry),
        .issue_idx(issue_branch_idx),
        .eu_ready(1'b1),         // TODO: Connect to Branch execution unit
        .wb_en(wb_en),
        .wb_prd(wb_prd),
        .flush(dispatch_mispredict)
    );

    reservation_station #(.RS_SIZE(RS_LSU_SIZE)) rs_lsu(
        .clk(clk),
        .rst(rst),
        .dispatch_en(dispatch_lsu_en),
        .dispatch_instr(dispatch_lsu_instr),
        .full(rs_lsu_full),
        .alloc_idx(),
        .alloc_valid(),
        .issue_en(issue_lsu_en),
        .issue_entry(issue_lsu_entry),
        .issue_idx(issue_lsu_idx),
        .eu_ready(1'b1),         // TODO: Connect to LSU execution unit
        .wb_en(wb_en),
        .wb_prd(wb_prd),
        .flush(dispatch_mispredict)
    );

    // ========================================================================
    // PHYSICAL REGISTER FILE
    // ========================================================================
    logic [PHYS_REG_BITS-1:0] prf_rs1_alu, prf_rs2_alu;
    logic [PHYS_REG_BITS-1:0] prf_rs1_branch, prf_rs2_branch;
    logic [PHYS_REG_BITS-1:0] prf_rs1_lsu, prf_rs2_lsu;
    logic [31:0] prf_rd1_alu, prf_rd2_alu;
    logic [31:0] prf_rd1_branch, prf_rd2_branch;
    logic [31:0] prf_rd1_lsu, prf_rd2_lsu;

    // Connect read addresses from issued RS entries
    assign prf_rs1_alu = issue_alu_entry.prs1;
    assign prf_rs2_alu = issue_alu_entry.prs2;
    assign prf_rs1_branch = issue_branch_entry.prs1;
    assign prf_rs2_branch = issue_branch_entry.prs2;
    assign prf_rs1_lsu = issue_lsu_entry.prs1;
    assign prf_rs2_lsu = issue_lsu_entry.prs2;

    physical_regfile prf(
        .clk(clk),
        .rst(rst),
        .rs1_alu(prf_rs1_alu),
        .rs2_alu(prf_rs2_alu),
        .rs1_branch(prf_rs1_branch),
        .rs2_branch(prf_rs2_branch),
        .rs1_lsu(prf_rs1_lsu),
        .rs2_lsu(prf_rs2_lsu),
        .rd1_alu(prf_rd1_alu),
        .rd2_alu(prf_rd2_alu),
        .rd1_branch(prf_rd1_branch),
        .rd2_branch(prf_rd2_branch),
        .rd1_lsu(prf_rd1_lsu),
        .rd2_lsu(prf_rd2_lsu),
        .we_alu(1'b0),           // TODO: Connect to ALU writeback
        .wa_alu(7'd0),
        .wd_alu(32'd0),
        .we_branch(1'b0),        // TODO: Connect to Branch writeback
        .wa_branch(7'd0),
        .wd_branch(32'd0),
        .we_lsu(1'b0),           // TODO: Connect to LSU writeback
        .wa_lsu(7'd0),
        .wd_lsu(32'd0)
    );

endmodule
