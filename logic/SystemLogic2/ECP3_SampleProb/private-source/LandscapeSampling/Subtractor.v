module Subtractor (a, b, c);

parameter bit_addr_sub = 19, bit_chip = 6;

input wire [bit_addr_sub-1+bit_chip:0] a, b;
output reg [bit_addr_sub-1+bit_chip:0] c;

always @(*) begin
	c <= a - b;
end
endmodule