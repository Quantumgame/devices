module Clk_Gain (clk_main, clk_low, clr, exp_w1_de1, tstamp, tstamp_de, clk_gain);
//// clk_gain can be smaller or larger than clk_low
//// clk_gain is reset if exp_w1_de1 is high in order to have a correct waveform 
//// when s_isi_rec comes back again. exp_w1 can also be used.

parameter r_main_to_low = 1000, g = 1;
parameter integer r_main_to_gain_h = r_main_to_low*1.0/g/2;
parameter r_main_to_gain = r_main_to_gain_h*2;
//// round off (r_main_to_low*1.0/g/2), and then double it. to ensure r_main_to_gain is an even number.
parameter bit_cnt = $clog2(r_main_to_gain/2);

input wire clk_main, clk_low, clr, exp_w1_de1, tstamp, tstamp_de;
output reg clk_gain;
reg clk_low_de, clk_gain_ns;
reg [bit_cnt-1:0] cnt, cnt_ns;

always @(posedge clk_main or posedge clr) begin
	if (clr) begin
		cnt <= 0;
		clk_gain <= 0;
		clk_low_de <= 1; //or 0 ????
	end
	else begin
		cnt <= cnt_ns;	
		clk_gain <= clk_gain_ns;
		clk_low_de <= clk_low;
	end
end

always @(*) begin
	//// cnt
	//// during the rising edge of clk_low, reset cnt
	if (exp_w1_de1) begin
		cnt_ns <= 0;
	end
	else if (clk_low == 1 && clk_low_de == 0 && tstamp == 1 && tstamp_de == 0) begin
		cnt_ns <= 0;
	end
	//// during the refractory, maintain reset value 
	else if (tstamp_de == 1) begin
		cnt_ns <= cnt;
	end
	//// out of two cases above, act like a normal counter.
	else if (cnt >= r_main_to_gain/2 -1) begin
		cnt_ns <= 0;
	end
	else begin
		cnt_ns <= cnt + 1;
	end
	
	//// clk_gain
	if (exp_w1_de1) begin
		clk_gain_ns <= 0;
	end
	else if (clk_low == 1 && clk_low_de == 0 && tstamp == 0 && tstamp_de == 1) begin 
		clk_gain_ns <= 1;
	end
	else if (clk_low == 1 && clk_low_de == 0 && tstamp == 1 && tstamp_de == 0) begin
		clk_gain_ns <= 0;
	end
	else if (cnt >= r_main_to_gain/2 -1) begin
		clk_gain_ns <= ~clk_gain;
	end
	else begin
		clk_gain_ns <= clk_gain;
	end
end
endmodule
