module Clk_System (clk_main, clr, clk_rng, clk_low, clk_data_de2, latch);
//// use clk_data_de2 because Bit_Combine module needs a delay clk to fetch correct data.

parameter bit_chip = 6, node = 16, r_main_to_rng = 100, r_data_to_low = 100, lw = 1;
parameter r_main_to_low = r_main_to_rng*32;
//// r_main_to_low has to be an even number.
//// r_main_to_low should be x32 larger than r_main_to_rng because clk_low is x32 slower than clk_rng. 
//// r_data_to_low has to be larger than (bit_chip*node) 
//// lw define the width of latch. 1 unit is represented by the period of clk_data.
parameter r_main_to_data = r_main_to_low/r_data_to_low; 
//// r_main_to_data has to be an even number.
parameter bit_rng = $clog2(r_main_to_rng/2);
parameter bit_low = $clog2(r_main_to_low/2);
parameter bit_data = $clog2(r_main_to_data/2); 
parameter bit_sr = $clog2(r_data_to_low*2);

input wire clk_main, clr;
output reg clk_rng, clk_low, clk_data_de2, latch;
reg clk_data, clk_data_de1, clk_data_ns, clk_low_ns, clk_rng_ns, latch_ns;
reg [bit_rng-1:0] cnt_rng, cnt_rng_ns;
reg [bit_low-1:0] cnt_low, cnt_low_ns;
reg [bit_data-1:0] cnt_data, cnt_data_ns;
reg [bit_sr-1:0] cnt_sr, cnt_sr_ns;

always @(posedge clk_main or posedge clr) begin
	if (clr) begin
		clk_rng <= 1;
		clk_low <= 1;
		clk_data <= 1;
		cnt_rng <= 0;
		cnt_low <= 0;
		cnt_data <= 0;
		cnt_sr <= 0;
		latch <= 0;
		clk_data_de1 <= 1; // or 0???
		clk_data_de2 <= 1; // or 0???
	end
	else begin
		clk_rng <= clk_rng_ns;
		clk_low <= clk_low_ns;
		clk_data <= clk_data_ns;
		cnt_rng <= cnt_rng_ns;
		cnt_low <= cnt_low_ns;
		cnt_data <= cnt_data_ns;
		cnt_sr <= cnt_sr_ns;
		latch <= latch_ns;
		clk_data_de1 <= clk_data;
		clk_data_de2 <= clk_data_de1;
	end
end

always @(*) begin
	//// cnt_rng (counting range from 0 to r_main_to_rng/2 - 1)
	if (cnt_rng >= r_main_to_rng/2 - 1) begin
		cnt_rng_ns <= 0;
	end
	else begin
		cnt_rng_ns <= cnt_rng + 1;
	end
	
	//// clk_rng
	if (cnt_rng >= r_main_to_rng/2 - 1) begin
		clk_rng_ns <= ~clk_rng;
	end
	else begin
		clk_rng_ns <= clk_rng;
	end

	//// cnt_low (counting range from 0 to r_main_to_low/2 - 1)
	if (cnt_low >= r_main_to_low/2 - 1) begin
		cnt_low_ns <= 0;
	end
	else begin
		cnt_low_ns <= cnt_low + 1;
	end
	
	//// clk_low
	if (cnt_low >= r_main_to_low/2 - 1) begin
		clk_low_ns <= ~clk_low;
	end
	else begin
		clk_low_ns <= clk_low;
	end

	//// cnt_data (counting range from 0 to r_main_to_data/2 - 1) 
	if (cnt_data >= r_main_to_data/2 - 1) begin
		cnt_data_ns <= 0;
	end
	else begin
		cnt_data_ns <= cnt_data + 1;
	end
	
	//// cnt_sr (counting range from 0 to r_data_to_low*2 - 1)
	if (cnt_data >= r_main_to_data/2 - 1) begin
		if (cnt_sr >= r_data_to_low*2 - 1) begin
			cnt_sr_ns <= 0;
		end
		else begin
			cnt_sr_ns <= cnt_sr + 1;
		end
	end
	else begin
		cnt_sr_ns <= cnt_sr;
	end
	
	//// clk_data
	if (cnt_data >= r_main_to_data/2 - 1) begin
		if (cnt_sr >= bit_chip*node*2 - 1 && cnt_sr < r_data_to_low*2 - 1) begin
			clk_data_ns <= 0;
		end
		else if (cnt_sr >= r_data_to_low*2 - 1) begin
			clk_data_ns <= 1;
		end
		else begin
			clk_data_ns <= ~clk_data;
		end
	end
	else begin
		clk_data_ns <= clk_data;
	end
	
	//// latch
	if (cnt_data >= r_main_to_data/2 - 1) begin
		if (cnt_sr >= (r_data_to_low - lw)*2 - 1 && cnt_sr < r_data_to_low*2 - 1) begin
			latch_ns <= 1;
		end
		else begin
			latch_ns <= 0;
		end
	end
	else begin
		latch_ns <= latch;
	end
end
endmodule

