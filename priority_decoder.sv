module priority_decoder
#(
    parameter WIDTH = 4
) (
    input wire [WIDTH-1 : 0] in,
    output logic [$clog2(WIDTH)-1 : 0] out,
    output logic valid
);

always_comb begin
    for (int i = WIDTH - 1; i >= 0; i--) begin
        if (in[i] == 1'b1) begin
            out = i;
            valid = 1'b1;
            break;
        end
        else begin
            valid = 1'b0;
            out = '0;
        end
    end
end
endmodule