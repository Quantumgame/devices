module Acc (clk, clr, acc_old, valid_de1, acc_new);

parameter bit_addr_acc = 19;

input wire clk, clr, valid_de1;
input wire [bit_addr_acc-1:0] acc_old;
output reg [bit_addr_acc-1:0] acc_new;
reg [bit_addr_acc-1:0] acc_new_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		acc_new <= 0;
	end
	else begin
		acc_new <= acc_new_ns;
	end	
end

always @(*) begin
	if (valid_de1) begin
		acc_new_ns <= acc_old + 1;
	end
	else begin
		acc_new_ns <= acc_old;
	end
end
endmodule