module Delay (clk, clr, d, q);

parameter bit_de = 8;

input wire clk, clr;
input wire [bit_de-1:0] d;
output reg [bit_de-1:0] q;
reg [bit_de-1:0] q_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		q <= 0;
	end
	else begin
		q <= q_ns;
	end
end

always @(*) begin
	q_ns <= d;
end
endmodule