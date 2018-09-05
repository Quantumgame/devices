module Gain_BT1 (clk, clr, isi_x, isi_y, comp_addr_x, comp_addr_y, isi_z, valid);

parameter bit_isi = 8, g = 7;
parameter bit_g = $clog2(g);

input wire clk, clr, comp_addr_x, comp_addr_y;
input wire [bit_isi-1:0] isi_x;
input wire [bit_g-1:0] isi_y;
output reg [bit_isi-1:0] isi_z;
output reg valid;

wire [bit_isi+bit_g-1:0] s;
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

assign s = (isi_x - 1)*g + 1 + isi_y; 
//// s might be negative when isi_x = 0. It happens when comp_addr_x = 1.

always @(*) begin
	if (s <= 2**bit_isi-1) begin
		isi_z_ns <= s;
	end
	else begin
		isi_z_ns <= isi_z;
	end
	
	if (s <= 2**bit_isi - 1 && !comp_addr_x && !comp_addr_y) begin
		valid_ns <= 1;
	end
	else begin
		valid_ns <= 0;
	end	
end
endmodule
