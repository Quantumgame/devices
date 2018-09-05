module Addr_In_Fin (clk, clr, addr, ae, exp_w1_de1, addr_fin);

parameter bit_addr = 9;

input wire clk, clr, ae, exp_w1_de1;
input wire [bit_addr-1:0] addr;
output reg [bit_addr-1:0] addr_fin;
reg [bit_addr-1:0] addr_fin_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		addr_fin <= 0;
	end
	else begin
		addr_fin <= addr_fin_ns;
	end
end

always @(*) begin
	if (ae && !exp_w1_de1 && addr_fin < addr) begin
		addr_fin_ns <= addr;
	end
	else begin
		addr_fin_ns <= addr_fin;
	end
end
endmodule