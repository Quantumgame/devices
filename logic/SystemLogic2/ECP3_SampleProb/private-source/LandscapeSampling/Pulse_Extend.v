module Pulse_Extend (clk_main, clr, request, tstamp);

parameter pw = 4, r_main_to_low = 1000;
parameter bit_cnt = $clog2(pw*r_main_to_low);

input wire clk_main, clr, request;
output wire tstamp;
reg ce, ce_ns;
reg [bit_cnt-1:0] cnt, cnt_ns;

always @(posedge clk_main or posedge clr) begin
	if (clr) begin
		ce <= 0;
		cnt <= 0;
	end
	else begin
		ce <= ce_ns;
		cnt <= cnt_ns;
	end
end

assign tstamp = ce;

always @(*) begin
	//// cnt enable
	if (request) begin
		ce_ns <= 1;
	end
	else if (cnt >= pw*r_main_to_low - 1) begin
		ce_ns <= 0;
	end
	else begin
		ce_ns <= ce;
	end
	
	//// cnt range from 0 to pw*r_main_to_low - 1
	if (ce == 1 && cnt < pw*r_main_to_low - 1) begin
		cnt_ns <= cnt + 1;	
	end
	else begin
		cnt_ns <= 0;
	end
end
endmodule