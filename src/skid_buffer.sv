module skid_buffer_struct #(
    parameter type T = logic [31:0]
) (
    input logic       clk,
    input logic       reset,

    // upstream (producer -> skid)
    input logic       valid_in,
    output logic      ready_out,  // Ready signal going back to producer
    input T           data_in,

    // downstream (skid -> consumer)
    output logic      valid_out,
    input logic       ready_in,   // Ready signal from consumer
    output T          data_out
);

T buffer;
logic bypass;



always @(posedge clk) begin
    if (reset) begin
        buffer <= '0;
        bypass <= 1'b1;
    end
    else begin
        if (bypass) begin
            if (valid_in && !ready_in) begin
                buffer <= data_in;
                bypass <= 1'b0;
            end
        end
        else begin
            if (ready_in) begin
                bypass <= 1'b1;
            end
        end
    end
end

assign valid_out = bypass ? valid_in : 1'b1;
assign data_out  = bypass ? data_in  : buffer;
assign ready_out = bypass;


endmodule