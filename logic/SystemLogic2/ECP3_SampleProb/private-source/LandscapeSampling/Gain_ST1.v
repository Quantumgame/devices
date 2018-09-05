module Gain_ST1 (clk, clr, isi_x, comp_addr_x, isi_z, valid);

parameter bit_isi = 8;

input wire clk, clr, comp_addr_x;
input wire [bit_isi-1:0] isi_x;
output reg [bit_isi-1:0] isi_z;
output reg valid;

reg [bit_isi-1:0] isi_z_ns;
reg valid_ns;

always @(posedge clk or posedge clr) begin
	if (clr) begin
		isi_z <= 0;
		valid <= 0;
	end
	else begin
		isi_z <= isi_z_ns;
		valid <= valid_ns;
	end
end

always @(*) begin
	isi_z_ns <= isi_x;
	if (!comp_addr_x) begin
		valid_ns <= 1;
	end		
	else begin
		valid_ns <= 0;
	end
end
endmodule
