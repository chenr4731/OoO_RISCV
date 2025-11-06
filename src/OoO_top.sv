module OoO_top #(
    parameter type T = logic [31:0]
)(
    input logic clk,
    input logic rst
    );
    
    logic [8:0] fetch_to_cache_pc;
    T cache_to_fetch_instr;
    logic ena;
    
    
    
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
    .take_branch(0),
    .branch_loc(0),
    .instr_from_cache(cache_to_fetch_instr),
    .pc_to_cache(fetch_to_cache_pc),
    .instr_to_decode(fetch_to_skid_instr),
    .pc_to_decode(fetch_to_skid_pc),
    .ready(skid_to_fetch_ready),
    .valid(fetch_to_skid_valid)
);

logic skid_to_decode_valid;
logic decode_to_skid_ready;
logic [31:0] skid_to_decode_instr;
logic [8:0] skid_to_decode_pc;
skid_buffer_struct #(.T(logic [31:0])) fetch_decode_skid_buffer_instr(
    .clk(clk),
    .reset(rst),
    .valid_in(fetch_to_skid_valid),
    .ready_in(skid_to_fetch_ready), // Output
    .data_in(fetch_to_skid_instr),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_decode_instr) // Output 
);

skid_buffer_struct #(.T(logic [8:0])) fetch_decode_skid_buffer_pc(
    .clk(clk),
    .reset(rst),
    .valid_in(fetch_to_skid_valid),
    .ready_in(skid_to_fetch_ready), // Output
    .data_in(fetch_to_skid_pc),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_decode_pc) // Output 
);


logic [8:0] decode_to_skid_pc;
logic decode_to_skid_valid;

logic [4:0] decode_to_skid_rs1;
logic [4:0] decode_to_skid_rs2;
logic [4:0] decode_to_skid_rd;
logic decode_to_skid_ALUsrc;
logic decode_to_skid_Branch;
T decode_to_skid_immediate;
logic [1:0] decode_to_skid_ALUOp;
logic decode_to_skid_FUtype;
logic decode_to_skid_Memread;
logic decode_to_skid_Memwrite;
logic decode_to_skid_Regwrite;

decoder instr_decoder(
    .i_instruction(skid_to_decode_instr),
    .i_pc(skid_to_decode_pc),
    .i_valid(skid_to_decode_valid), // From fetch skid buffer
    .i_ready(skid_to_decode_ready), // From execute skid buffer
    .o_ready(decode_to_skid_ready), // Back to fetch skid buffer
    .o_pc(decode_to_skid_pc),
    .o_valid(decode_to_skid_valid),
    .rs1(decode_to_skid_rs1),
    .rs2(decode_to_skid_rs2),
    .rd(decode_to_skid_rd),
    .ALUsrc(decode_to_skid_ALUsrc),
    .Branch(decode_to_skid_Branch),
    .immediate(decode_to_skid_immediate),
    .ALUOp(decode_to_skid_ALUOp),
    .FUtype(decode_to_skid_FUtype),
    .Memread(decode_to_skid_Memread),
    .Memwrite(decode_to_skid_Memwrite),
    .Regwrite(decode_to_skid_Regwrite)
);

logic [4:0] skid_to_execute_rs1;
skid_buffer_struct #(.T(logic [4:0])) decode_rename_skid_buffer_rs1(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_rs1),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_rs1) // Output 
);

logic [4:0] skid_to_execute_rs2;
skid_buffer_struct #(.T(logic [4:0])) decode_rename_skid_buffer_rs2(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_rs2),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_rs2) // Output 
);

logic [4:0] skid_to_execute_rd;
skid_buffer_struct #(.T(logic [4:0])) decode_rename_skid_buffer_rd(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_rd),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_rd) // Output 
);

logic skid_to_execute_ALUsrc;
skid_buffer_struct #(.T(logic)) decode_rename_skid_buffer_ALUsrc(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_ALUsrc),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_ALUsrc) // Output 
);

logic skid_to_execute_Branch;
skid_buffer_struct #(.T(logic)) decode_rename_skid_buffer_Branch(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_Branch),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_Branch) // Output 
);

T skid_to_execute_immediate;
skid_buffer_struct #(.T(T)) decode_rename_skid_buffer_immediate(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_immediate),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_immediate) // Output 
);

logic [1:0] skid_to_execute_ALUOp;
skid_buffer_struct #(.T(logic [1:0])) decode_rename_skid_buffer_ALUOp(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_ALUOp),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_ALUOp) // Output 
);

logic skid_to_execute_FUtype;
skid_buffer_struct #(.T(logic)) decode_rename_skid_buffer_FUtype(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_FUtype),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_FUtype) // Output 
);

logic skid_to_execute_Memread;
skid_buffer_struct #(.T(logic)) decode_rename_skid_buffer_Memread(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_Memread),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_Memread) // Output 
);

logic skid_to_execute_Memwrite;
skid_buffer_struct #(.T(logic)) decode_rename_skid_buffer_Memwrite(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_Memread),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_Memread) // Output 
);

logic skid_to_execute_Regwrite;
skid_buffer_struct #(.T(logic)) decode_rename_skid_buffer_Regwrite(
    .clk(clk),
    .reset(rst),
    .valid_in(decode_to_skid_valid),
    .ready_in(skid_to_decode_ready), // Output
    .data_in(decode_to_skid_Regwrite),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_execute_Regwrite) // Output 
);

endmodule
