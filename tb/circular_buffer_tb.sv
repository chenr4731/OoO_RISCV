module circular_buffer_tb();

logic clk;
logic reset;
logic write_en;
logic [31:0] write_data;
logic read_en;
logic [31:0] read_data;
logic full;
logic empty;

// Instantiate circular_buffer
circular_buffer #(
    .T(logic [31:0]),
    .DEPTH(4)
) dut (.*);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test sequence
initial begin
    $display("=== Testing Circular Buffer v1 (Wrapping Pointer) ===");
    
    // Initialize
    reset = 1;
    write_en = 0;
    read_en = 0;
    write_data = 0;
    
    repeat(2) @(posedge clk);
    reset = 0;
    @(posedge clk);
    
    // Write data until full
    $display("\n--- Writing data ---");
    for (int i = 0; i < 5; i++) begin
        @(posedge clk);
        write_en = 1;
        write_data = 32'hA0 + i;
        $display("Write: %h, Full: %b, Empty: %b", write_data, full, empty);
    end
    
    write_en = 0;
    @(posedge clk);
    
    // Read data until empty
    $display("\n--- Reading data ---");
    for (int i = 0; i < 5; i++) begin
        @(posedge clk);
        read_en = 1;
        $display("Read: %h, Full: %b, Empty: %b", read_data, full, empty);
    end
    
    read_en = 0;
    @(posedge clk);
    
    // Simultaneous read/write
    $display("\n--- Simultaneous operations ---");
    write_en = 1;
    write_data = 32'hBEEF;
    @(posedge clk);
    
    write_en = 1;
    read_en = 1;
    write_data = 32'hCAFE;
    @(posedge clk);
    $display("After simultaneous R/W - Full: %b, Empty: %b", full, empty);
    
    write_en = 0;
    read_en = 0;
    repeat(2) @(posedge clk);
    
    $display("\n=== Test Complete ===");
    $finish;
end

endmodule