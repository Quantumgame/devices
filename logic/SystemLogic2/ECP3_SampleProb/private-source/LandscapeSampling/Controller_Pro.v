module Controller_Pro (clk_low, clk_main, rst, tstamp_z, w1_cnt, w4_cnt, 
ce_cnt_4, ce_cnt_w1, ce_cnt_w4, ce_ram, clr_cnt_4, clr_cnt_w1, clr_cnt_w4, clr_ram_zout, we_zout);

parameter bit_isi = 8, bit_addr = 9, sb_r_min = 3, w1 = 2**14;

parameter integer w4 = 1 + (2**bit_isi + 3) + (2**(bit_addr*2) + 4*(bit_addr*2 - sb_r_min + 1)) + 
(bit_addr*2 - sb_r_min + 1) + ((2**bit_isi + 3)*(bit_addr*2 - sb_r_min + 1)) + 
(2**bit_isi + 2**bit_addr) + 1;
parameter bit_w1 = $clog2(w1);
parameter bit_w4 = $clog2(w4);
parameter s_initial = 3'd0, s_isi_rec = 3'd1, s_idle = 3'd7;

input wire clk_low, clk_main, rst, tstamp_z;
input wire [bit_w1-1:0] w1_cnt;
input wire [bit_w4-1:0] w4_cnt;

output reg ce_cnt_4, ce_cnt_w1, ce_cnt_w4, clr_cnt_4, clr_cnt_w1, clr_cnt_w4, clr_ram_zout, we_zout;
output wire ce_ram;

reg clk_low_de, exp_w1, exp_w4;
reg [2:0] cs, ns;

//// sequential
always @(posedge clk_main or posedge rst) begin
	if (rst) begin
		cs <= s_initial;
	end
	else begin
		cs <= ns;
		clk_low_de <= clk_low;
	end
end

//// combinational state machine
always @(*) begin
	case(cs)
	s_initial: begin
		ns <= s_isi_rec;
	end
	
	s_isi_rec: begin
		if (exp_w1) begin
			ns <= s_idle;
		end
		else begin
			ns <= s_isi_rec;
		end
	end

	s_idle: begin
		if (exp_w4 && clk_low == 1 && clk_low_de == 0) begin
			ns <= s_isi_rec;
		end
		else begin
			ns <= s_idle;
		end
	end
	
	default: begin
		ns <= s_isi_rec;
	end
	endcase
end

//// combinational controlling signal
assign	ce_ram = 1;

always @(*) begin
	case(cs)
	s_initial: begin
		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 0;
		clr_cnt_w4 <= 1;

		//// Cnt_4
		ce_cnt_4 <= 0;
		clr_cnt_4 <= 1;
		
		//// RAM_zout
		clr_ram_zout <= 1;
		we_zout <= 0;
	end

	s_isi_rec: begin
		if (clk_low == 1 && clk_low_de == 0) begin
			//// Cnt_w1, Cnt_w4
			ce_cnt_w1 <= 1;
			clr_cnt_w1 <= 0;
			ce_cnt_w4 <= 0;
			clr_cnt_w4 <= 1;

			//// Cnt_4
			ce_cnt_4 <= 1;
			clr_cnt_4 <= tstamp_z;
			
			//// RAM_zout
			clr_ram_zout <= 0;
			we_zout <= 0;
		end
		else begin
			//// Cnt_w1, Cnt_w4
			ce_cnt_w1 <= 0;
			clr_cnt_w1 <= 0;
			ce_cnt_w4 <= 0;
			clr_cnt_w4 <= 1;

			//// Cnt_4
			ce_cnt_4 <= 0;
			clr_cnt_4 <= 0;
			
			//// RAM_zout
			clr_ram_zout <= 0;
			we_zout <= 0;
		end
	end
	
	s_idle: begin
		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 1;
		clr_cnt_w4 <= 0;

		//// Cnt_4
		ce_cnt_4 <= 0;
		clr_cnt_4 <= 1;
		
		//// RAM_zout
		clr_ram_zout <= 1;
		we_zout <= 0;
	end
	
	default: begin
		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 0;
		clr_cnt_w4 <= 1;

		//// Cnt_4
		ce_cnt_4 <= 0;
		clr_cnt_4 <= 1;
		
		//// RAM_zout
		clr_ram_zout <= 1;
		we_zout <= 0;
	end
	endcase
end

always @(*) begin
	case(cs)
	s_initial: begin
		exp_w1 <= 0;
		exp_w4 <= 0;
	end
	
	s_isi_rec: begin
		if (w1_cnt >= w1) begin
			exp_w1 <= 1;
		end
		else begin
			exp_w1 <= 0;
		end
		exp_w4 <= 0;
	end

	s_idle: begin
		exp_w1 <= 1;
		if (w4_cnt >= w4) begin
			exp_w4 <= 1;
		end
		else begin
			exp_w4 <= 0;
		end
	end
	
	default: begin
		exp_w1 <= 0;
		exp_w4 <= 0;
	end
	endcase
end
endmodule
