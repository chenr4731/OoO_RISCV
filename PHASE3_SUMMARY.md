# Phase 3 Implementation Summary

## Overview
Phase 3 implements the execute, writeback, and commit stages of the out-of-order RISC-V processor. This completes the core datapath, enabling instructions to flow from fetch through execution to commit.

## Implemented Components

### 1. Execution Units

#### ALU ([src/alu.sv](src/alu.sv))
- **Latency**: 1 cycle
- **Operations**: ADD, SUB, AND, OR
- **Features**:
  - Supports both register-register and register-immediate operations
  - Pipeline register for 1-cycle execution
  - Writeback to PRF and completion to ROB
  - Flush support for pipeline recovery

#### Branch Unit ([src/branch_unit.sv](src/branch_unit.sv))
- **Latency**: 1 cycle
- **Operations**: BEQ, BNE, BLT, BGE, BLTU, BGEU, JALR
- **Features**:
  - Computes branch condition (taken/not-taken)
  - Calculates branch target address
  - Generates misprediction flag (assumes always predict not-taken)
  - Writes PC+4 to PRF for JALR instructions
  - Completion includes branch outcome and target

#### LSU ([src/lsu.sv](src/lsu.sv))
- **Latency**: 2 cycles (address generation + BRAM access)
- **Operations**: Load only (stores not implemented)
- **Features**:
  - Two-stage pipeline: address generation, then data read
  - BRAM interface with enable, write-enable, address, and data signals
  - Writeback load data to PRF
  - Completion to ROB

### 2. Register File Integration

**Physical Register File** already had 6 read ports (2 per FU) and 3 write ports (1 per FU):
- Read ports provide operands to execution units (read-after-issue)
- Write ports receive writeback data from all FUs
- Write priority: ALU > Branch > LSU (to handle conflicts)

### 3. Wakeup Logic

**Reservation Stations** ([src/reservation_station.sv](src/reservation_station.sv)):
- Updated to track individual operand readiness (prs1_ready, prs2_ready)
- Accept writeback broadcasts from all 3 FUs (ALU, Branch, LSU)
- Wakeup logic checks all valid RS entries and marks operands ready when matching register is written
- Instruction becomes ready when both operands are ready

**Current Simplification**: All operands assumed ready at dispatch (full dependency tracking deferred to later)

### 4. Writeback Stage

**Features**:
- Each FU broadcasts writeback independently to:
  - Physical Register File (update register value)
  - All Reservation Stations (wakeup dependent instructions)
- Out-of-order writeback (instructions complete in execution order, not program order)
- Each FU has dedicated write port to PRF

### 5. Commit Stage

**ROB Commit Logic** ([src/rob.sv](src/rob.sv)):
- In-order commit from ROB head
- No backpressure (always ready to accept commits)
- Broadcasts commit to rename stage for:
  - Freeing old physical registers (prd_old)
  - Updating architectural state
- Removed auto-complete logic (now uses real execution units)

### 6. Top-Level Integration

**OoO_top.sv** updates:
- Instantiated all 3 execution units
- Connected register reads from PRF to execution units
- Connected writeback from execution units to PRF and RSs
- Connected completion from execution units to ROB
- Added data memory (simple array for simulation, BRAM for synthesis)
- Added ROB completion arbitration (priority: ALU > Branch > LSU)

## Data Flow

```
Issue → Register Read → Execute → Writeback → Commit
                                      ↓
                                  Wakeup RS
```

1. **Issue**: RS issues ready instruction to execution unit
2. **Register Read**: Execution unit reads operands from PRF
3. **Execute**: Execution unit computes result (1-2 cycles)
4. **Writeback**:
   - Write result to PRF
   - Broadcast to all RSs for wakeup
   - Complete to ROB
5. **Commit**: ROB commits instruction in-order, updates rename stage

## Memory Architecture

### Instruction Memory
- Xilinx Block Memory Generator IP (blk_mem_gen_0)
- 9-bit address, 32-bit data
- 1-cycle read latency

### Data Memory (Phase 3)
- Simple logic array in OoO_top.sv (512 words)
- 2-cycle read latency (matches BRAM behavior)
- Should be replaced with Xilinx BRAM IP for synthesis

## Testbenches

Created comprehensive testbenches for all new modules:

1. **[tb/alu_tb.sv](tb/alu_tb.sv)**:
   - Tests all ALU operations (ADD, SUB, AND, OR)
   - Tests immediate vs register operands
   - Tests flush behavior

2. **[tb/branch_unit_tb.sv](tb/branch_unit_tb.sv)**:
   - Tests all branch conditions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
   - Tests JALR with PC+4 writeback
   - Tests misprediction detection
   - Tests flush behavior

3. **[tb/lsu_tb.sv](tb/lsu_tb.sv)**:
   - Tests load with various addresses
   - Tests base + offset addressing
   - Tests back-to-back loads
   - Tests flush behavior

## Known Limitations

1. **Branch funct3**: Uses immediate[2:0] as placeholder; should pass funct3 explicitly through RS
2. **Operand readiness**: Assumes all operands ready at dispatch; needs proper ready bit tracking
3. **Pipeline recovery**: Misprediction flag generated but recovery not implemented (Phase 4)
4. **Store instructions**: Not implemented in LSU
5. **Multiple completions**: Priority arbitration may lose simultaneous completions; needs proper handling
6. **Branch prediction**: Always predicts not-taken; no connection to fetch stage yet

## Next Steps (Phase 4)

Phase 4 will implement:
- Pipeline flush and recovery on misprediction
- Restore rename state from checkpoint
- Connect branch resolution to fetch stage
- Implement proper store instructions
- Add comprehensive ready bit tracking for dependencies

## Files Modified

### New Files
- src/alu.sv
- src/branch_unit.sv
- src/lsu.sv
- tb/alu_tb.sv
- tb/branch_unit_tb.sv
- tb/lsu_tb.sv

### Modified Files
- src/ooo_types.sv (added prs1_ready, prs2_ready to rs_entry_t)
- src/reservation_station.sv (added wakeup logic with multiple WB sources)
- src/rob.sv (removed auto-complete logic)
- src/OoO_top.sv (integrated execution units, writeback, completion)
- CLAUDE.md (updated documentation)

## Testing

To run the testbenches:
```bash
# ALU testbench
xvlog src/ooo_types.sv src/alu.sv tb/alu_tb.sv
xelab alu_tb -debug typical
xsim alu_tb -runall

# Branch unit testbench
xvlog src/ooo_types.sv src/branch_unit.sv tb/branch_unit_tb.sv
xelab branch_unit_tb -debug typical
xsim branch_unit_tb -runall

# LSU testbench
xvlog src/ooo_types.sv src/lsu.sv tb/lsu_tb.sv
xelab lsu_tb -debug typical
xsim lsu_tb -runall
```

See [tb/README.md](tb/README.md) for more detailed testing instructions.
