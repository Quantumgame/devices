module Cnt_ISI (clk, ce, clr, q, of);

parameter bit_isi = 8;

input wire clk, ce, clr;
output reg of;
output reg [bit_isi-1:0] q;
reg of_ns;
reg [bit_isi-1:0] q_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		q <= 0;
		of <= 0;
	end
	else begin
		q <= q_ns;
		of <= of_ns;
	end
end

always @(*) begin
	if (ce) begin
		q_ns <= q + 1;
	end
	else begin
		q_ns <= q;
	end
	
	if (q == 2**bit_isi - 1 && ce) begin
		of_ns <= 1;
	end
	else begin
		of_ns <= of;
	end
end

endmodule
