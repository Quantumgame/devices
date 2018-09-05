module Mux_Acc (clk, clr, acc_d, acc_q, a, b, c, acc_mux);

parameter bit_isi = 8, bit_addr_acc = 19;

input wire clk, clr;
input wire [bit_isi-1:0] a, b, c;
input wire [bit_addr_acc-1:0] acc_d, acc_q;
output reg [bit_addr_acc-1:0] acc_mux;
reg [bit_addr_acc-1:0] acc_d_de;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		acc_d_de <= 0;
	end
	else begin
		acc_d_de <= acc_d;
	end
end

always @(*) begin
	if (a == b) begin
		acc_mux <= acc_d;
	end
	else if (a == c) begin
		acc_mux <= acc_d_de;
	end
	else begin
		acc_mux <= acc_q;
	end
end

/*
input wire [bit_isi-1:0] a, b;
input wire [bit_addr_acc-1:0] acc_d, acc_q;
output reg [bit_addr_acc-1:0] acc_mux; 

always @(*) begin
	if (b == a) begin
		acc_mux <= acc_d;
	end
	else begin
		acc_mux <= acc_q;
	end
end
*/
endmodule
