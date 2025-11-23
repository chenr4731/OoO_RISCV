# Out-of-Order RISC-V Processor Testbenches

This directory contains comprehensive testbenches for all components of the OoO RISC-V processor design.

## Testbench Overview

### Component-Level Testbenches

#### 1. **Fetch Stage** (`fetch_tb.sv`)
- Tests instruction fetch from cache
- Verifies PC increment behavior
- Tests branch handling
- Validates backpressure/stall behavior

#### 2. **Decoder** (`decoder_tb.sv`)
- Tests all RISC-V instruction types (R, I, S, B, U)
- Verifies immediate generation
- Tests control signal generation (ALUsrc, Branch, Memread, Memwrite, Regwrite)
- Validates FU type routing (ALU, Branch, LSU)
- Tests valid/ready handshaking

#### 3. **Map Table** (`map_table_tb.sv`)
- Tests identity mapping initialization (x0→p0, x1→p1, etc.)
- Verifies register renaming updates
- Tests checkpoint creation and restoration
- Validates x0 immutability
- Tests dual-read port simultaneous access

#### 4. **Free List** (`free_list_tb.sv`)
- Tests initial state (p32-p127 free)
- Verifies sequential allocation
- Tests deallocation and recycling
- Validates checkpoint/restore functionality
- Tests wrap-around behavior
- Verifies empty/full flags

#### 5. **ROB Tag Allocator** (`rob_tag_allocator_tb.sv`)
- Tests sequential tag allocation
- Verifies wrap-around at ROB_SIZE (16)
- Tests checkpoint creation
- Validates restoration on mispredict

#### 6. **Rename Stage** (`rename_tb.sv`)
- Tests complete register renaming flow
- Verifies RAW dependency handling
- Tests x0 special handling
- Validates branch checkpointing
- Tests backpressure handling
- Verifies free list allocation

#### 7. **Reservation Station** (`reservation_station_tb.sv`)
- Tests allocation to RS entries
- Verifies priority-based issue (lowest index first)
- Tests full/empty conditions
- Validates flush behavior
- Tests simultaneous dispatch/issue

#### 8. **Physical Register File** (`physical_regfile_tb.sv`)
- Tests 6 read ports (2 per FU)
- Tests 3 write ports (1 per FU)
- Verifies write priority (ALU > Branch > LSU)
- Tests p0 hardwired to zero
- Validates simultaneous reads/writes
- Tests all 128 registers

#### 9. **Dispatch Stage** (`dispatch_tb.sv`)
- Tests routing to correct RS based on FU type
- Verifies ROB allocation
- Tests stall conditions (RS full, ROB full)
- Validates checkpoint signal for branches
- Tests backpressure propagation

#### 10. **Reorder Buffer (ROB)** (`rob_tb.sv`)
- Tests in-order commit
- Verifies checkpoint storage for branches
- Tests mispredict detection and recovery
- Validates auto-completion (Assignment 2)
- Tests circular buffer wrap-around
- Verifies flush on mispredict

### Integration Testbench

#### **OoO_top** (`OoO_top_tb.sv`)
- **Full pipeline integration test** covering:
  - Fetch → [Skid] → Decode → [Skid] → Rename → [Skid] → Dispatch → RS/ROB
- Monitors all pipeline stages and skid buffers
- Verifies data flow through all three skid buffer stages
- Tests backpressure propagation across pipeline
- Validates resource utilization
- Checks for deadlock conditions
- Tests extended operation (100+ cycles)

### Utility Module Testbenches (Pre-existing)

- `circular_buffer_tb.sv` - Tests circular buffer implementation
- `fifo_tb.sv` - Tests FIFO queue
- `priority_decoder_tb.sv` - Tests priority decoder
- `skid_buffer_tb.sv` - Tests skid buffer flow control

## Running Testbenches

### Using Vivado Simulator (xsim)

```bash
# Compile a single testbench
xvlog -sv src/ooo_types.sv src/<module>.sv tb/<module>_tb.sv
xelab <module>_tb -debug typical
xsim <module>_tb -runall

# Example: Run fetch testbench
xvlog -sv src/fetch.sv tb/fetch_tb.sv
xelab fetch_tb -debug typical
xsim fetch_tb -runall
```

### Using ModelSim

```bash
# Compile and run
vlib work
vlog -sv +incdir+src src/ooo_types.sv src/<module>.sv tb/<module>_tb.sv
vsim -c <module>_tb -do "run -all; quit"

# Example: Run decoder testbench
vlog -sv +incdir+src src/decoder.sv tb/decoder_tb.sv
vsim -c decoder_tb -do "run -all; quit"
```

### Using Verilator (for lint checking and C++ simulation)

```bash
verilator --lint-only -Wall -Wno-fatal --top-module <module>_tb \
  +incdir+src src/ooo_types.sv src/<module>.sv tb/<module>_tb.sv
```

## Testbench Organization

Each testbench follows a consistent structure:

1. **Initialization** - Reset and default signal values
2. **Test Cases** - Numbered tests with clear descriptions
3. **Assertions** - Inline verification with error messages
4. **Pass/Fail Reporting** - Clear indication of test results
5. **Timeout Protection** - Prevents infinite simulation

## Expected Outputs

All testbenches use `assert` statements to verify correct behavior. A successful run will show:

```
=== <Module> Testbench ===

[Test 1] <Test Description>
  PASS

[Test 2] <Test Description>
  PASS

...

=== All <Module> Tests Passed ===
```

## Current Design State (Assignment 2)

The testbenches are designed for the current implementation state:

- ✅ **Fetch, Decode, Rename, Dispatch** - Fully implemented
- ✅ **Map Table, Free List, ROB Tag Allocator** - Fully functional
- ✅ **Reservation Stations** - Allocation and issue working
- ✅ **ROB** - Allocation and commit working
- ✅ **Physical Register File** - All ports functional
- ⚠️ **Execution Units** - Not yet implemented (auto-complete for testing)
- ⚠️ **Data Dependency Tracking** - RS marks all instructions ready immediately

## Notes

1. **Instruction Cache**: The OoO_top testbench may require adjustment depending on how the Xilinx Block RAM IP is configured for initialization.

2. **Pipeline Depth**: The pipeline now includes skid buffers at three locations:
   - Between Fetch and Decode
   - Between Decode and Rename (newly added)
   - Between Rename and Dispatch

   This adds pipeline register stages for proper flow control and backpressure handling.

3. **Auto-completion**: In the current design, instructions automatically complete after 1 cycle in the ROB for testing purposes. This behavior is implemented in rob.sv lines 153-162.

4. **No Data Dependencies**: Reservation stations currently mark all instructions as ready immediately (reservation_station.sv line 93).

5. **Timing**: All testbenches use a 10ns clock period (5ns high, 5ns low).

6. **Waveforms**: The OoO_top_tb generates a VCD file for waveform viewing:
   ```bash
   gtkwave OoO_top_tb.vcd
   ```

## Troubleshooting

### Common Issues

1. **Missing ooo_types package**: Ensure `src/ooo_types.sv` is compiled first
2. **Xilinx IP dependencies**: OoO_top_tb requires Xilinx Block Memory Generator IP
3. **Simulation timeout**: Increase timeout value in testbench if needed
4. **Assertion failures**: Check the error message for specific signal/value mismatches

## Test Coverage

The testbenches provide comprehensive coverage of:

- ✅ Normal operation paths
- ✅ Backpressure and stall conditions
- ✅ Edge cases (wrap-around, full/empty conditions)
- ✅ Reset behavior
- ✅ Checkpoint/restore mechanisms
- ✅ Priority and conflict resolution
- ✅ Valid/ready handshaking protocols
- ✅ Integration across pipeline stages

## Future Enhancements

When execution units are added, testbenches will need updates for:

- Actual execution results verification
- Data dependency tracking in RS
- Proper wakeup logic
- Branch resolution and mispredict handling
