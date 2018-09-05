module Cnt (clk, ce, clr, q);

parameter bit_io = 14;

input wire clk, ce, clr;
output reg [bit_io-1:0] q;
reg [bit_io-1:0] q_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		q <= 0;
	end
	else begin
		q <= q_ns;
	end
end

always @(*) begin
	if (ce) begin
		q_ns <= q + 1;
	end
	else begin
		q_ns <= q;
	end
end

endmodule
