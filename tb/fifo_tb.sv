module fifo_tb();

logic clk;
logic reset;
logic write_en;
logic [31:0] write_data;
logic read_en;
logic [31:0] read_data;
logic full;
logic empty;

// Instantiate FIFO
fifo #(
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
    $display("=== Testing FIFO v2 (Counter-based) ===");
    
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
        write_data = 32'h10 + i;
        $display("Write: %h, Full: %b, Empty: %b", write_data, full, empty);
    end
    
    write_en = 0;
    @(posedge clk);
    
    // Read half the data
    $display("\n--- Reading partial data ---");
    for (int i = 0; i < 2; i++) begin
        @(posedge clk);
        read_en = 1;
        $display("Read: %h, Full: %b, Empty: %b", read_data, full, empty);
    end
    
    read_en = 0;
    @(posedge clk);
    
    // Write more data
    $display("\n--- Writing more data ---");
    for (int i = 0; i < 3; i++) begin
        @(posedge clk);
        write_en = 1;
        write_data = 32'h20 + i;
        $display("Write: %h, Full: %b, Empty: %b", write_data, full, empty);
    end
    
    write_en = 0;
    @(posedge clk);
    
    // Drain FIFO
    $display("\n--- Draining FIFO ---");
    read_en = 1;
    repeat(6) begin
        @(posedge clk);
        $display("Read: %h, Full: %b, Empty: %b", read_data, full, empty);
    end
    
    read_en = 0;
    repeat(2) @(posedge clk);
    
    $display("\n=== Test Complete ===");
    $finish;
end

endmodule