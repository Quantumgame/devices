module Bit_Extend (clk, clr, in, out);

parameter bit_addr_ex = 19, bit_chip = 6;

input wire clk, clr;
input wire [bit_addr_ex-1:0] in;
output reg [bit_addr_ex-1+bit_chip:0] out;
reg [bit_addr_ex-1+bit_chip:0] out_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		out <= 0;
	end
	else begin
		out <= out_ns;
	end
end

always @(*) begin
	out_ns[bit_addr_ex-1:0] <= in;
	out_ns[bit_addr_ex-1+bit_chip:bit_addr_ex] <= 6'b000000;
end
endmodule