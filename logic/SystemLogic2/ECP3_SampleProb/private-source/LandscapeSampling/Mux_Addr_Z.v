module Mux_Addr_Z (in_0, in_1, sel, out);

parameter bit_isi = 8;

input wire [bit_isi-1:0] in_0, in_1;
input wire sel;
output reg [bit_isi-1:0] out; 

always @(*) begin
	if (sel) begin
		out <= in_1;
	end
	else begin
		out <= in_0;
	end
end
endmodule
