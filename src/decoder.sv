module decoder#(
    parameter type T = logic [31:0]
    parameter [6:0]
) (
    input T         instruction,
    input T         i_pc,
    input logic     i_valid,

    input logic i_ready,

    output T        o_pc,
    output T        o_ready,

    // Add more signals here as needed
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [4:0] rd,
    output logic ALUsrc,
    output logic Branch,
    output T immediate,
    output [1:0] PCsrc


);

// OPCODES
localparam OPC_LUI    = 7'b0110111;
localparam OPC_JALR   = 7'b1100111;
localparam OPC_BRANCH = 7'b1100011;
localparam OPC_LOAD   = 7'b0000011;
localparam OPC_STORE  = 7'b0100011;
localparam OPC_IMM = 7'b0010011;
localparam OPC_REG     = 7'b0110011;


assign o_pc = i_pc;
assign rs1 = instruction[19:15];
assign rs2 = instruction[24:20];
assign rd = instruction[11:7];

assign opcode = instruction[6:0];

assign ALUsrc = (opcode == OPC_IMM || 
                    opcode == OPC_LOAD || 
                    opcode == OPC_STORE ||
                    opcode == OPC_JALR);

assign Branch = (opcode == OPC_JALR || opcode == OPC_BRANCH);

assign Memread = opcode == OPC_LOAD; // Read when opcode is OPC_LOAD
assign Memwrite = opcode == OPC_STORE; // Write to memory when need to store
assign Regwrite = (opcode == OPC_LOAD) || 
                    (opcode == OPC_REG) || 
                    (opcode == OPC_IMM) || 
                    (opcode == OPC_JALR); // Write to register file when these opcodes are seen
assign PCsrc = //Choose from JALR, BRANCH, or PC + 4


// Determine ALUOp
always_comb begin
end

// Immediate Generator
always_comb begin
end






endmodule
