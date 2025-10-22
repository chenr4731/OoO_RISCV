module skid_buffer_tb();

logic clk;
logic reset;
logic valid_in;
logic ready_in;
logic [31:0] data_in;
logic valid_out;
logic ready_out;
logic [31:0] data_out;

// Instantiate skid buffer
skid_buffer_struct #(
    .T(logic [31:0])
) dut (.*);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test sequence
initial begin
    $display("=== Testing Skid Buffer ===");
    
    // Initialize
    reset = 1;
    valid_in = 0;
    ready_out = 1;
    data_in = 0;
    
    repeat(2) @(posedge clk);
    reset = 0;
    @(posedge clk);
    
    // Normal flow - data passes through
    $display("\n--- Normal flow (ready consumer) ---");
    for (int i = 0; i < 3; i++) begin
        @(posedge clk);
        valid_in = 1;
        data_in = 32'h100 + i;
        #1;
        $display("Cycle: In=%h, Out=%h, Ready_in=%b, Valid_out=%b", 
                 data_in, data_out, ready_in, valid_out);
    end
    
    valid_in = 0;
    @(posedge clk);
    
    // Test backpressure
    $display("\n--- Backpressure scenario ---");
    valid_in = 1;
    data_in = 32'hDEAD;
    ready_out = 1;
    @(posedge clk);
    #1;
    $display("Send DEAD: Ready_in=%b", ready_in);
    
    // Consumer not ready - should buffer
    data_in = 32'hBEEF;
    ready_out = 0;
    @(posedge clk);
    #1;
    $display("Send BEEF (consumer blocked): Ready_in=%b, Out=%h", 
             ready_in, data_out);
    
    // Try to send more (should not accept)
    data_in = 32'hCAFE;
    @(posedge clk);
    #1;
    $display("Try send CAFE: Ready_in=%b, Out=%h", ready_in, data_out);
    
    // Consumer becomes ready
    ready_out = 1;
    @(posedge clk);
    #1;
    $display("Consumer ready: Ready_in=%b, Out=%h", ready_in, data_out);
    
    @(posedge clk);
    #1;
    $display("Next cycle: Ready_in=%b, Out=%h", ready_in, data_out);
    
    valid_in = 0;
    repeat(2) @(posedge clk);
    
    $display("\n=== Test Complete ===");
    $finish;
end

endmodule