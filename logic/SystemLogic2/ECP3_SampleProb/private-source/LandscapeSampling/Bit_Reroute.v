//// module Bit_Reroute_Uni
module Bit_Reroute_Uni(bit_in, bit_out);

input wire bit_in;
output wire bit_out;

assign bit_out = bit_in;
endmodule

//// module Bit_Reroute
module Bit_Reroute (array_in, array_out);

parameter bit_chip = 6, node = 16;
input wire [bit_chip*node-1:0] array_in;
output wire [bit_chip*node-1:0] array_out;

genvar a, b;
generate
	for (a = 1; a <= node; a = a + 1) begin
		for (b = 1; b <= bit_chip; b = b + 1) begin
			Bit_Reroute_Uni Bit_Reroute_Uni (array_in[a*bit_chip-b], array_out[(a-1)*bit_chip+b-1]);
			//Bit_Reroute_Uni #(.a(a), .b(b)) Bit_Reroute_Uni (array_in[a*(bit_chip)-1:(a-1)*bit_chip], array_out[a*(bit_chip)-1:(a-1)*bit_chip]);
		end
	end
endgenerate
endmodule