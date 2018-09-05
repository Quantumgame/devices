//// module Shifter_R_Uni
module Shifter_R_Uni (in, out);

parameter bit_addr_shi = 19, bit_chip = 6, a = 3;

input wire [bit_addr_shi-1+bit_chip:0] in;
output reg [bit_chip-1:0] out;

always @(*) begin
	out <= in[a+bit_chip-1:a] + in[a-1];
end
endmodule

//// module Shifter_R
module Shifter_R (clk, clr, sb_r, in, out);

parameter bit_addr_shi = 19, bit_chip = 6, bit_shi_r = 5, sb_r_min = 3;

input wire clk, clr;
input wire [bit_shi_r-1:0] sb_r;
input wire [bit_addr_shi-1+bit_chip:0] in;
output reg [bit_chip-1:0] out;
reg [bit_chip-1:0] out_ns;

wire [bit_chip-1:0] out_uni[bit_addr_shi-1:sb_r_min]; 

always @(posedge clk or posedge clr) begin
	if (clr) begin
		out <= 0;
	end
	else begin
		out <= out_ns;
	end
end

genvar a;
generate
for (a = sb_r_min; a <= bit_addr_shi-1; a = a + 1) begin
	Shifter_R_Uni #(.bit_addr_shi(bit_addr_shi), .bit_chip(bit_chip), .a(a)) Shifter_R_Uni (in, out_uni[a]);
end
endgenerate

always @(*) begin
	if (sb_r >= sb_r_min) begin
		out_ns <= out_uni[sb_r];
	end
	else begin
		out_ns <= 0;
	end
/*
	case (sb_r)
	5'd 3: begin if (in[ 2]) begin out_ns <= in[ 3+bit_chip-1: 3] + 1; end else begin out_ns <= in[ 3+bit_chip-1: 3]; end end
	5'd 4: begin if (in[ 3]) begin out_ns <= in[ 4+bit_chip-1: 4] + 1; end else begin out_ns <= in[ 4+bit_chip-1: 4]; end end
	5'd 5: begin if (in[ 4]) begin out_ns <= in[ 5+bit_chip-1: 5] + 1; end else begin out_ns <= in[ 5+bit_chip-1: 5]; end end
	5'd 6: begin if (in[ 5]) begin out_ns <= in[ 6+bit_chip-1: 6] + 1; end else begin out_ns <= in[ 6+bit_chip-1: 6]; end end
	5'd 7: begin if (in[ 6]) begin out_ns <= in[ 7+bit_chip-1: 7] + 1; end else begin out_ns <= in[ 7+bit_chip-1: 7]; end end
	5'd 8: begin if (in[ 7]) begin out_ns <= in[ 8+bit_chip-1: 8] + 1; end else begin out_ns <= in[ 8+bit_chip-1: 8]; end end
	5'd 9: begin if (in[ 8]) begin out_ns <= in[ 9+bit_chip-1: 9] + 1; end else begin out_ns <= in[ 9+bit_chip-1: 9]; end end
	5'd10: begin if (in[ 9]) begin out_ns <= in[10+bit_chip-1:10] + 1; end else begin out_ns <= in[10+bit_chip-1:10]; end end
	5'd11: begin if (in[10]) begin out_ns <= in[11+bit_chip-1:11] + 1; end else begin out_ns <= in[11+bit_chip-1:11]; end end
	5'd12: begin if (in[11]) begin out_ns <= in[12+bit_chip-1:12] + 1; end else begin out_ns <= in[12+bit_chip-1:12]; end end
//	5'd13: begin if (in[12]) begin out_ns <= in[13+bit_chip-1:13] + 1; end else begin out_ns <= in[13+bit_chip-1:13]; end end
//	5'd14: begin if (in[13]) begin out_ns <= in[14+bit_chip-1:14] + 1; end else begin out_ns <= in[14+bit_chip-1:14]; end end
//	5'd15: begin if (in[14]) begin out_ns <= in[15+bit_chip-1:15] + 1; end else begin out_ns <= in[15+bit_chip-1:15]; end end
//	5'd16: begin if (in[15]) begin out_ns <= in[16+bit_chip-1:16] + 1; end else begin out_ns <= in[16+bit_chip-1:16]; end end
//	5'd17: begin if (in[16]) begin out_ns <= in[17+bit_chip-1:17] + 1; end else begin out_ns <= in[17+bit_chip-1:17]; end end
//	5'd18: begin if (in[17]) begin out_ns <= in[18+bit_chip-1:18] + 1; end else begin out_ns <= in[18+bit_chip-1:18]; end end
	default: out_ns <= out;
	endcase
*/
end
endmodule
