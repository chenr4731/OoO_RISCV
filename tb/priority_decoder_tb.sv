module priority_decoder_tb();

parameter WIDTH = 8;

logic [WIDTH-1:0] in;
logic [$clog2(WIDTH)-1:0] out;
logic valid;

// Instantiate priority decoder
priority_decoder #(
    .WIDTH(WIDTH)
) dut (.*);

// Test sequence
initial begin
    $display("=== Testing Priority Decoder (WIDTH=%0d) ===\n", WIDTH);
    
    // Test all zeros
    in = 8'b0000_0000;
    #10;
    $display("Input: %b -> Output: %0d, Valid: %b", in, out, valid);
    
    // Test single bits
    $display("\n--- Single bit tests ---");
    for (int i = 0; i < WIDTH; i++) begin
        in = 1 << i;
        #10;
        $display("Input: %b -> Output: %0d, Valid: %b (Expected: %0d)", 
                 in, out, valid, i);
    end
    
    // Test multiple bits (priority)
    $display("\n--- Multiple bit tests ---");
    in = 8'b0000_0011; #10;
    $display("Input: %b -> Output: %0d, Valid: %b", in, out, valid);
    
    in = 8'b0101_0101; #10;
    $display("Input: %b -> Output: %0d, Valid: %b", in, out, valid);
    
    in = 8'b1111_1111; #10;
    $display("Input: %b -> Output: %0d, Valid: %b", in, out, valid);
    
    in = 8'b1000_0001; #10;
    $display("Input: %b -> Output: %0d, Valid: %b", in, out, valid);
    
    in = 8'b0100_1010; #10;
    $display("Input: %b -> Output: %0d, Valid: %b", in, out, valid);
    
    $display("\n=== Test Complete ===");
    $finish;
end

endmodule