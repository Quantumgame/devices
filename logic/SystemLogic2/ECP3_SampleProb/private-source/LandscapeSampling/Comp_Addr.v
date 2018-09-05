module Comp_Addr (clk, addr, addr_fin, comp_addr);

parameter bit_addr = 9;

input wire clk;
input wire [bit_addr-1:0] addr, addr_fin;
output reg comp_addr;
reg comp_addr_ns;

always @(posedge clk) begin
	comp_addr <= comp_addr_ns;
end

always @(*) begin
	if (addr <= addr_fin) begin
		comp_addr_ns <= 0;
	end
	else begin
		comp_addr_ns <= 1;
	end
end
endmodule
