module Plus (clk, clr, isi_x, isi_y, comp_addr_x, comp_addr_y, isi_z, valid);

parameter bit_isi = 8;

input wire clk, clr, comp_addr_x, comp_addr_y;
input wire [bit_isi-1:0] isi_x, isi_y;
output reg [bit_isi-1:0] isi_z;
output reg valid;

wire [bit_isi:0] s;
reg [bit_isi-1:0] isi_z_ns;
reg valid_ns;

//// sequential
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

assign s = isi_x + isi_y;

//// combinational
always @(*) begin
	if (s <= 2**bit_isi-1) begin
		isi_z_ns <= s;
	end
	else begin
		isi_z_ns <= isi_z;
	end
	//// isi_z == 0 never happens. 
	//// this is necessary for avoiding the case that isi_z_de2 = isi_z = 0 in the beginning 
	//// and that Mux_acc will choose the wrong value acc_d instead of acc_q.
	if (s <= 2**bit_isi-1 && !comp_addr_x && !comp_addr_y) begin
		valid_ns <= 1;
	end
	else begin
		valid_ns <= 0;
	end
end
endmodule
