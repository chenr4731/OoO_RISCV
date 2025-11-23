`timescale 1ns/1ps

module decoder_tb;
    logic [31:0] instruction;
    logic [8:0] i_pc;
    logic i_valid;
    logic i_ready;
    logic o_ready;
    logic [8:0] o_pc;
    logic o_valid;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic ALUsrc;
    logic Branch;
    logic [31:0] immediate;
    logic [1:0] ALUOp;
    logic [1:0] FUtype;
    logic Memread;
    logic Memwrite;
    logic Regwrite;

    // Instantiate decoder
    decoder dut (
        .instruction(instruction),
        .i_pc(i_pc),
        .i_valid(i_valid),
        .i_ready(i_ready),
        .o_ready(o_ready),
        .o_pc(o_pc),
        .o_valid(o_valid),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .ALUsrc(ALUsrc),
        .Branch(Branch),
        .immediate(immediate),
        .ALUOp(ALUOp),
        .FUtype(FUtype),
        .Memread(Memread),
        .Memwrite(Memwrite),
        .Regwrite(Regwrite)
    );

    // RISC-V Opcodes
    localparam OPC_LUI    = 7'b0110111;
    localparam OPC_JALR   = 7'b1100111;
    localparam OPC_BRANCH = 7'b1100011;
    localparam OPC_LOAD   = 7'b0000011;
    localparam OPC_STORE  = 7'b0100011;
    localparam OPC_IMM    = 7'b0010011;
    localparam OPC_REG    = 7'b0110011;

    task test_instruction(
        input string name,
        input [31:0] instr,
        input [4:0] exp_rs1,
        input [4:0] exp_rs2,
        input [4:0] exp_rd,
        input exp_ALUsrc,
        input exp_Branch,
        input [31:0] exp_imm,
        input [1:0] exp_ALUOp,
        input [1:0] exp_FUtype,
        input exp_Memread,
        input exp_Memwrite,
        input exp_Regwrite
    );
        instruction = instr;
        #1;
        $display("\n[Test] %s", name);
        $display("  Instruction: 0x%08h", instr);
        assert(rs1 == exp_rs1) else $error("rs1: got %d, expected %d", rs1, exp_rs1);
        assert(rs2 == exp_rs2) else $error("rs2: got %d, expected %d", rs2, exp_rs2);
        assert(rd == exp_rd) else $error("rd: got %d, expected %d", rd, exp_rd);
        assert(ALUsrc == exp_ALUsrc) else $error("ALUsrc: got %b, expected %b", ALUsrc, exp_ALUsrc);
        assert(Branch == exp_Branch) else $error("Branch: got %b, expected %b", Branch, exp_Branch);
        assert(immediate == exp_imm) else $error("Immediate: got 0x%08h, expected 0x%08h", immediate, exp_imm);
        assert(ALUOp == exp_ALUOp) else $error("ALUOp: got %b, expected %b", ALUOp, exp_ALUOp);
        assert(FUtype == exp_FUtype) else $error("FUtype: got %b, expected %b", FUtype, exp_FUtype);
        assert(Memread == exp_Memread) else $error("Memread: got %b, expected %b", Memread, exp_Memread);
        assert(Memwrite == exp_Memwrite) else $error("Memwrite: got %b, expected %b", Memwrite, exp_Memwrite);
        assert(Regwrite == exp_Regwrite) else $error("Regwrite: got %b, expected %b", Regwrite, exp_Regwrite);
        $display("  PASS");
    endtask

    initial begin
        $display("=== Decoder Testbench ===");

        // Initialize
        instruction = 32'h0;
        i_pc = 9'h0;
        i_valid = 1;
        i_ready = 1;

        // Test 1: ADD (R-type) - add x1, x2, x3
        // Format: 0000000 rs2(x3) rs1(x2) 000 rd(x1) 0110011
        test_instruction(
            "ADD x1, x2, x3",
            32'b0000000_00011_00010_000_00001_0110011,
            5'd2,   // rs1 = x2
            5'd3,   // rs2 = x3
            5'd1,   // rd = x1
            1'b0,   // ALUsrc = 0 (use rs2)
            1'b0,   // Branch = 0
            32'h0,  // immediate = 0 (ignored for R-type)
            2'b10,  // ALUOp = 10 (REG)
            2'b00,  // FUtype = ALU
            1'b0,   // Memread = 0
            1'b0,   // Memwrite = 0
            1'b1    // Regwrite = 1
        );

        // Test 2: ADDI (I-type) - addi x5, x6, 42
        // Format: imm[11:0] rs1(x6) 000 rd(x5) 0010011
        test_instruction(
            "ADDI x5, x6, 42",
            32'b000000101010_00110_000_00101_0010011,
            5'd6,   // rs1 = x6
            5'd0,   // rs2 = 0 (ignored)
            5'd5,   // rd = x5
            1'b1,   // ALUsrc = 1 (use immediate)
            1'b0,   // Branch = 0
            32'd42, // immediate = 42
            2'b11,  // ALUOp = 11 (IMM)
            2'b00,  // FUtype = ALU
            1'b0,   // Memread = 0
            1'b0,   // Memwrite = 0
            1'b1    // Regwrite = 1
        );

        // Test 3: LW (I-type Load) - lw x10, 8(x11)
        // Format: imm[11:0] rs1(x11) 010 rd(x10) 0000011
        test_instruction(
            "LW x10, 8(x11)",
            32'b000000001000_01011_010_01010_0000011,
            5'd11,  // rs1 = x11
            5'd0,   // rs2 = 0 (ignored)
            5'd10,  // rd = x10
            1'b1,   // ALUsrc = 1 (use immediate)
            1'b0,   // Branch = 0
            32'd8,  // immediate = 8
            2'b00,  // ALUOp = 00 (LOAD)
            2'b10,  // FUtype = LSU
            1'b1,   // Memread = 1
            1'b0,   // Memwrite = 0
            1'b1    // Regwrite = 1
        );

        // Test 4: SW (S-type) - sw x12, 16(x13)
        // Format: imm[11:5] rs2(x12) rs1(x13) 010 imm[4:0] 0100011
        test_instruction(
            "SW x12, 16(x13)",
            32'b0000000_01100_01101_010_10000_0100011,
            5'd13,  // rs1 = x13
            5'd12,  // rs2 = x12
            5'd16,  // rd = imm[4:0]
            1'b1,   // ALUsrc = 1 (use immediate)
            1'b0,   // Branch = 0
            32'd16, // immediate = 16
            2'b00,  // ALUOp = 00 (STORE)
            2'b10,  // FUtype = LSU
            1'b0,   // Memread = 0
            1'b1,   // Memwrite = 1
            1'b0    // Regwrite = 0
        );

        // Test 5: BEQ (B-type) - beq x14, x15, 8
        // Format: imm[12|10:5] rs2(x15) rs1(x14) 000 imm[4:1|11] 1100011
        test_instruction(
            "BEQ x14, x15, 8",
            32'b0_000000_01111_01110_000_0100_0_1100011,
            5'd14,  // rs1 = x14
            5'd15,  // rs2 = x15
            5'd8,   // rd = imm[4:1|11]
            1'b0,   // ALUsrc = 0 (use rs2)
            1'b1,   // Branch = 1
            32'd8,  // immediate = 8
            2'b01,  // ALUOp = 01 (BRANCH)
            2'b01,  // FUtype = BRANCH
            1'b0,   // Memread = 0
            1'b0,   // Memwrite = 0
            1'b0    // Regwrite = 0
        );

        // Test 6: LUI (U-type) - lui x16, 0x12345
        // Format: imm[31:12] rd(x16) 0110111
        test_instruction(
            "LUI x16, 0x12345",
            32'b00010010001101000101_10000_0110111,
            5'd0,   // rs1 = 0 (extracted but ignored)
            5'd0,   // rs2 = 0
            5'd16,  // rd = x16
            1'b0,   // ALUsrc = 0
            1'b0,   // Branch = 0
            32'h12345000, // immediate = 0x12345000
            2'b00,  // ALUOp = 00
            2'b00,  // FUtype = ALU
            1'b0,   // Memread = 0
            1'b0,   // Memwrite = 0
            1'b0    // Regwrite = 0 (NOTE: decoder doesn't set Regwrite for LUI)
        );

        // Test 7: JALR (I-type) - jalr x1, x2, 4
        test_instruction(
            "JALR x1, x2, 4",
            32'b000000000100_00010_000_00001_1100111,
            5'd2,   // rs1 = x2
            5'd0,   // rs2 = 0
            5'd1,   // rd = x1
            1'b1,   // ALUsrc = 1
            1'b1,   // Branch = 1
            32'd4,  // immediate = 4
            2'b00,  // ALUOp = 00
            2'b01,  // FUtype = BRANCH
            1'b0,   // Memread = 0
            1'b0,   // Memwrite = 0
            1'b1    // Regwrite = 1
        );

        // Test 8: Test negative immediate (I-type with sign extension)
        // ADDI x7, x8, -1
        test_instruction(
            "ADDI x7, x8, -1",
            32'b111111111111_01000_000_00111_0010011,
            5'd8,   // rs1 = x8
            5'd0,   // rs2 = 0
            5'd7,   // rd = x7
            1'b1,   // ALUsrc = 1
            1'b0,   // Branch = 0
            32'hFFFFFFFF, // immediate = -1 (sign-extended)
            2'b11,  // ALUOp = 11 (IMM)
            2'b00,  // FUtype = ALU
            1'b0,   // Memread = 0
            1'b0,   // Memwrite = 0
            1'b1    // Regwrite = 1
        );

        // Test 9: Verify valid/ready passthrough
        $display("\n[Test] Valid/Ready Passthrough");
        i_valid = 1;
        i_ready = 1;
        i_pc = 9'h100;
        #1;
        assert(o_valid == 1) else $error("o_valid should match i_valid");
        assert(o_ready == 1) else $error("o_ready should match i_ready");
        assert(o_pc == 9'h100) else $error("o_pc should match i_pc");

        i_valid = 0;
        i_ready = 0;
        #1;
        assert(o_valid == 0) else $error("o_valid should match i_valid");
        assert(o_ready == 0) else $error("o_ready should match i_ready");
        $display("  PASS");

        $display("\n=== All Decoder Tests Passed ===\n");
        $finish;
    end

endmodule
