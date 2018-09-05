module Bit_Combine (clk_main, clk_data, clr, array_to_chip, data_to_chip);

parameter bit_chip = 6, node = 16;
parameter bit_cnt_sr = $clog2(bit_chip*node);

input wire clk_main, clk_data, clr;
input wire [bit_chip*node-1:0] array_to_chip;
output reg data_to_chip;
reg clk_data_de, data_to_chip_ns;
reg [bit_cnt_sr-1:0] cnt_sr, cnt_sr_ns;

always @(posedge clk_main or posedge clr) begin
	if (clr) begin
		cnt_sr <= 0;
		data_to_chip <= 0;
		clk_data_de <= 0;
	end
	else begin
		cnt_sr <= cnt_sr_ns;
		data_to_chip <= data_to_chip_ns;
		clk_data_de <= clk_data;
	end	
end

always @(*) begin
	//// cnt_sr
	if (clk_data == 1 && clk_data_de == 0 && cnt_sr >= bit_chip*node - 1) begin
		cnt_sr_ns <= 0;
	end
	else if (clk_data == 1 && clk_data_de == 0 && cnt_sr < bit_chip*node - 1) begin
		cnt_sr_ns <= cnt_sr + 1;
	end
	else begin
		cnt_sr_ns <= cnt_sr;
	end
	
	//// data_to_chip assignment
	if (clk_data == 1 && clk_data_de == 0) begin
		data_to_chip_ns <= array_to_chip[cnt_sr];
		//// 1st node comes first && MSB loads first.
	end
	else begin
		data_to_chip_ns <= data_to_chip;
	end
end
endmodule