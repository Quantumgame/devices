module Shifter_L (clk, clr, acc_q, acc_shi_l);

parameter bit_addr_shi = 19, bit_chip = 6;

input wire clk, clr;
input wire [bit_addr_shi-1:0] acc_q;
output reg [bit_addr_shi-1+bit_chip:0] acc_shi_l;
reg [bit_addr_shi-1+bit_chip:0] acc_shi_l_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		acc_shi_l <= 0;
	end
	else begin
		acc_shi_l <= acc_shi_l_ns;
	end
end

always @(*) begin
	acc_shi_l_ns[bit_chip-1:0] <= 0;
	acc_shi_l_ns[bit_addr_shi-1+bit_chip:bit_chip] <= acc_q;
end
endmodule