module decoder#(
    parameter type T = logic [31:0]
    parameter [6:0]
) (
    input T         instruction,
    input T         i_pc,
    input logic     i_valid,

    input logic i_ready,

    // Back to fetch skid buffer
    output T        o_ready,

    // To rename stage skid buffer
    output T        o_pc,
    output logic o_valid,
    

    // Add more signals here as needed
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [4:0] rd,
    output logic ALUsrc,
    output logic Branch,
    output T immediate,
    output logic [1:0] ALUOp,
    output logic FUtype, // 0 for Addition or 1 for memory
    output logic Memread,
    output logic Memwrite,
    output logic Regwrite
);


assign o_valid = i_valid;
assign o_ready = i_ready;
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

assign ALUsrc = (instruction[6:0] == OPC_IMM || 
                    instruction[6:0] == OPC_LOAD || 
                    instruction[6:0] == OPC_STORE ||
                    instruction[6:0] == OPC_JALR);

assign Branch = (instruction[6:0] == OPC_JALR || instruction[6:0] == OPC_BRANCH);

assign Memread = instruction[6:0] == OPC_LOAD; // Read when opcode is OPC_LOAD
assign Memwrite = instruction[6:0] == OPC_STORE; // Write to memory when need to store
assign Regwrite = (instruction[6:0] == OPC_LOAD) || 
                    (instruction[6:0] == OPC_REG) || 
                    (instruction[6:0] == OPC_IMM) || 
                    (instruction[6:0] == OPC_JALR); // Write to register file when these opcodes are seen

assign FUtype = (OPC_STORE || OPC_LOAD);

// Determine ALUOp
always_comb begin
    case(instruction[6:0])
        OPC_IMM: ALUOp = 2'b11;
        OPC_BRANCH: ALUOp = 2'b01;
        OPC_REG: ALUOp = 2'b10;
        default: ALUOp = 2'b00;
    endcase
end

// Immediate Generator
always_comb begin
    case (instruction[6:0])
        OPC_LUI: begin // U-Type Immediate
            immediate = {instruction[31:12], 12'b0};
        end
        OPC_JALR, OPC_LOAD, OPC_IMM: begin // I-Type Immediate
            immediate = {{20{instruction[31]}}, instruction[31:20]};
        end
        OPC_STORE: begin // S-Type Immediate
            immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        end
        OPC_BRANCH: begin // B-Type Immediate
            immediate = {{20{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        end
        default: begin
            // Default catches unlisted opcodes (like JAL/AUIPC if not explicitly added)
            immediate = 32'b0;
        end
    endcase
end






endmodule
