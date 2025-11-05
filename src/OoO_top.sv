module OoO_top #(
    parameter type T = logic [31:0]
)(
    input logic clk,
    input logic rst
    );
    
    logic [8:0] fetch_to_cache_pc;
    logic [31:0] cache_to_fetch_instr;
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
skid_buffer_struct fetch_decode_skid_buffer_instr(
    .clk(clk),
    .reset(rst),
    .valid_in(fetch_to_skid_valid),
    .ready_in(skid_to_fetch_ready), // Output
    .data_in(fetch_to_skid_instr),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_decode_instr) // Output 
);

skid_buffer_struct fetch_decode_skid_buffer_pc(
    .clk(clk),
    .reset(rst),
    .valid_in(fetch_to_skid_valid),
    .ready_in(skid_to_fetch_ready), // Output
    .data_in(fetch_to_skid_pc),
    
    .valid_out(skid_to_decode_valid), // Output
    .ready_out(decode_to_skid_ready),
    .data_out(skid_to_decode_pc) // Output 
);


skid_buffer_struct skid2(
    .clk(clk),
    .reset(rst),
    .valid_in(),
    .ready_in(), // Output
    .data_in(),
    
    .valid_out(), // Output
    .ready_out(),
    .data_out() // Output 
);



always @(posedge clk) begin
    addra <= addra + 4;
end










endmodule
