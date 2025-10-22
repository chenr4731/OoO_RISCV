module fifo #(
    parameter type T = logic [31:0],
    parameter DEPTH = 8
) (
    input logic     clk,
    input logic     reset,

    input logic     write_en,
    input T         write_data,
    input logic     read_en,
    output T        read_data,
    output logic    full,
    output logic    empty
);

logic [$clog2(DEPTH) - 1 : 0] read_ptr;
logic [$clog2(DEPTH) - 1 : 0] write_ptr;
logic [$clog2(DEPTH) : 0] count;
T buffer [0:DEPTH-1];

always @(posedge clk) begin
    if (reset) begin
        read_ptr <= '0;
        write_ptr <= '0;
        count <= '0;
    end
    else begin
        if (write_en && !full) begin
            buffer[write_ptr] <= write_data;
            write_ptr <= write_ptr + 1;
            count <= count + 1;
        end
        if (read_en && !empty) begin
            read_data <= buffer[read_ptr];
            read_ptr <= read_ptr + 1;
            count <= count - 1;
        end
    end
end


assign full = count == DEPTH;
assign empty = count == 0;



endmodule
