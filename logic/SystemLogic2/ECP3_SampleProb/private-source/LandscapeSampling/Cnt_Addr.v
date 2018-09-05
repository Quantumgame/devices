module Cnt_Addr (clk, ce, clr, le, d, q);

parameter bit_addr = 9;

input wire clk, ce, clr, le;
input wire [bit_addr-1:0] d;
output reg [bit_addr-1:0] q;
reg [bit_addr-1:0] q_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		q <= 0;
	end
	else begin
		q <= q_ns;
	end
end

always @(*) begin
	if (le) begin
		q_ns <= d;
	end
	else if (ce) begin
		q_ns <= q + 1;
	end
	else begin
		q_ns <= q;
	end
end

endmodule
