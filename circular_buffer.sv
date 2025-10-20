module circular_buffer #(
    parameter type T = logic [31:0],
    parameter DEPTH = 8
) (
    input logic clk,
    input logic reset,

    input logic write_en,
    input T write_data,
    input logic read_en,
    output T read_data,
    output logic full,
    output logic empty
);

logic [T-1:0] buffer [0:DEPTH-1];
logic [$clog2(DEPTH) : 0] read_ptr;
logic [$clog2(DEPTH) : 0] write_ptr;


always @(posedge clk) begin
    if (reset) begin
        read_ptr <= '0;
        write_ptr <= '0;
    end
    else begin
        if (write_en && !full) begin
            buffer[write_ptr[$clog2(DEPTH)-1:0]] <= write_data;
            write_ptr <= write_ptr + 1;
        end
        if (read_en && !empty) begin
            read_data <= buffer[read_ptr[$clog2(DEPTH)-1:0]];
            read_ptr <= read_ptr + 1;
        end
    end
end


assign full = write_ptr[$clog2(DEPTH)] != read_ptr[$clog2(DEPTH)] && 
              write_ptr[$clog2(DEPTH)-1:0] == read_ptr[$clog2(DEPTH)-1:0];
assign empty = write_ptr == read_ptr;



endmodule