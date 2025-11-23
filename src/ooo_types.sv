package ooo_types;
    // Global Parameters
    parameter NUM_ARCH_REGS = 32;      // RV32I architectural registers
    parameter NUM_PHYS_REGS = 128;     // Physical register file size
    parameter PHYS_REG_BITS = $clog2(NUM_PHYS_REGS); // 7 bits
    parameter ROB_SIZE = 16;
    parameter ROB_BITS = $clog2(ROB_SIZE); // 4 bits
    parameter RS_ALU_SIZE = 8;
    parameter RS_BRANCH_SIZE = 8;
    parameter RS_LSU_SIZE = 8;
    parameter RS_BITS = 3; // Max of $clog2(8) for all RS

    // Functional Unit Types
    typedef enum logic [1:0] {
        FU_ALU    = 2'b00,
        FU_BRANCH = 2'b01,
        FU_LSU    = 2'b10
    } fu_type_t;

    // Renamed Instruction (output of Rename stage)
    typedef struct packed {
        logic valid;
        logic [31:0] pc;
        logic [PHYS_REG_BITS-1:0] prs1;      // Physical src 1
        logic [PHYS_REG_BITS-1:0] prs2;      // Physical src 2
        logic [PHYS_REG_BITS-1:0] prd;       // Physical dest
        logic [PHYS_REG_BITS-1:0] prd_old;   // Old physical dest (for recovery)
        logic [4:0] ard;                      // Architectural dest (for ROB)
        logic [31:0] immediate;
        logic [1:0] alu_op;
        fu_type_t fu_type;
        logic alu_src;                        // Use immediate vs rs2
        logic mem_read;
        logic mem_write;
        logic reg_write;
        logic is_branch;
        logic [ROB_BITS-1:0] rob_tag;
    } renamed_instr_t;

    // Reservation Station Entry
    typedef struct packed {
        logic valid;                          // Slot occupied
        logic ready;                          // Both operands ready
        logic [PHYS_REG_BITS-1:0] prs1;
        logic [PHYS_REG_BITS-1:0] prs2;
        logic [PHYS_REG_BITS-1:0] prd;
        logic [31:0] immediate;
        logic [1:0] alu_op;
        logic alu_src;
        logic mem_read;
        logic mem_write;
        logic reg_write;
        logic [ROB_BITS-1:0] rob_tag;
        logic [31:0] pc;
    } rs_entry_t;

    // ROB Entry
    typedef struct packed {
        logic valid;                          // Entry allocated
        logic ready;                          // Instruction completed execution
        logic [4:0] ard;                      // Architectural dest register
        logic [PHYS_REG_BITS-1:0] prd;       // Physical dest register
        logic [PHYS_REG_BITS-1:0] prd_old;   // Old mapping (for freelist)
        logic reg_write;                      // Will write to regfile
        logic is_branch;
        logic branch_taken;                   // Branch outcome
        logic branch_mispredict;              // Misprediction flag
        logic [31:0] branch_target;          // Correct branch target
        // Checkpoint data (only valid if has_checkpoint)
        logic has_checkpoint;
        logic [NUM_ARCH_REGS-1:0][PHYS_REG_BITS-1:0] checkpoint_map_table;
        logic [PHYS_REG_BITS-1:0] checkpoint_freelist_ptr;
        logic [ROB_BITS-1:0] checkpoint_rob_tag;
    } rob_entry_t;

endpackage
