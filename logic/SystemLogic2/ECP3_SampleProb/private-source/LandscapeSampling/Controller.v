module Controller (addr_x, addr_x_de3, addr_y, addr_y_de3, addr_zin_w, addr_zout, 
clk_low, clk_main, of_x, of_y, rst, sum, tstamp_x, tstamp_y, tstamp_z, 
valid_de2, w1_cnt, w4_cnt,
ae_x, ae_y, ce_cnt_1x, ce_cnt_1y, ce_cnt_2x, ce_cnt_2y, ce_cnt_3, 
ce_cnt_4, ce_cnt_w1, ce_cnt_w4, ce_ram, clr_addr_de, 
clr_addr_in_fin, clr_cnt_1x, clr_cnt_1y, clr_cnt_2x, clr_cnt_2y, 
clr_cnt_3, clr_cnt_4, clr_cnt_w1, clr_cnt_w4, clr_ram_in, clr_ram_zin, 
clr_ram_zout, clr_s_dist_comp, clr_s_func, clr_s_func_de, 
exp_w1_de1, le, sb_r, sel_addr_z, we_x, we_y, we_zin, we_zout
);

parameter bit_isi = 8, bit_addr = 9, sb_r_min = 3, w1 = 2**14;

parameter integer w4 = 1 + (2**bit_isi + 3) + (2**(bit_addr*2) + 4*(bit_addr*2 - sb_r_min + 1)) + 
(bit_addr*2 - sb_r_min + 1) + ((2**bit_isi + 3)*(bit_addr*2 - sb_r_min + 1)) + 
(2**bit_isi + 2**bit_addr) + 1;
parameter bit_w1 = $clog2(w1);
parameter bit_w4 = $clog2(w4);
parameter bit_shi_r = $clog2(bit_addr*2+1);
parameter isi_max = 2**bit_isi - 1, addr_max = 2**bit_addr - 1;
parameter s_initial = 3'd0, s_isi_rec = 3'd1, s_clr_cnt2 = 3'd2, s_func = 3'd3, 
s_rev_cnt2 = 3'd4, s_dist_comp = 3'd5, s_clr_ram = 3'd6, s_idle = 3'd7;

integer ind;

input wire clk_low, clk_main, of_x, of_y, rst, tstamp_x, tstamp_y, tstamp_z, valid_de2;
input wire [bit_isi-1:0] addr_zin_w, addr_zout;
input wire [bit_addr-1:0] addr_x, addr_x_de3, addr_y, addr_y_de3;
input wire [bit_w1-1:0] w1_cnt;
input wire [bit_w4-1:0] w4_cnt;
input wire [bit_addr*2:0] sum;

output reg [bit_shi_r-1:0] sb_r; 
output reg ae_x, ae_y, ce_cnt_1x, ce_cnt_1y, ce_cnt_2x, ce_cnt_2y, 
ce_cnt_3, ce_cnt_4, ce_cnt_w1, ce_cnt_w4, clr_addr_de, 
clr_addr_in_fin, clr_cnt_1x, clr_cnt_1y, clr_cnt_2x, clr_cnt_2y, 
clr_cnt_3, clr_cnt_4, clr_cnt_w1, clr_cnt_w4, clr_ram_in, clr_ram_zin, 
clr_ram_zout, clr_s_dist_comp, clr_s_func, clr_s_func_de, exp_w1_de1, le, 
sel_addr_z, we_x, we_y, we_zin, we_zout;
output wire ce_ram;

reg clk_low_de, exp_w1, exp_w2, exp_w2_ns, exp_w3, exp_w4, 
exp_w5, exp_w5_x, exp_w5_x_ns, exp_w5_zin, exp_w5_zin_ns, se, se_de1, 
tstamp_x_de, tstamp_x_de_ns, tstamp_y_de, tstamp_y_de_ns;
reg [2:0] cs, ns;
reg [bit_shi_r-1:0] sb_r_ns;

//// sequential
always @(posedge clk_main or posedge rst) begin
	if (rst) begin
		cs <= s_initial;
	end
	else begin
		cs <= ns;
		clk_low_de <= clk_low;
		tstamp_x_de <= tstamp_x_de_ns;
		tstamp_y_de <= tstamp_y_de_ns;
		clr_s_func_de <= clr_s_func;
		sb_r <= sb_r_ns;
		se_de1 <= se;
		exp_w1_de1 <= exp_w1;
		exp_w2 <= exp_w2_ns;
		exp_w5_x <= exp_w5_x_ns;
		exp_w5_zin <= exp_w5_zin_ns;
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
			ns <= s_clr_cnt2;
		end
		else begin
			ns <= s_isi_rec;
		end
	end

	s_clr_cnt2: begin
		ns <= s_dist_comp;
	end
	
	s_func: begin
		if (se || exp_w2) begin
			ns <= s_rev_cnt2;
		end
		else begin
			ns <= s_func;
		end
	end
	
	s_rev_cnt2: begin
		if (se_de1) begin
			ns <= s_dist_comp;
		end
		else begin
			ns <= s_clr_ram;
		end
	end
	
	s_dist_comp: begin
		if (exp_w2 && exp_w3) begin
			ns <= s_clr_ram;
		end
		else if (!exp_w2 && exp_w3) begin
			ns <= s_func;
		end
		else begin
			ns <= s_dist_comp;
		end
	end
	
	s_clr_ram: begin
		if (exp_w5) begin
			ns <= s_idle;
		end
		else begin
			ns <= s_clr_ram;
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
	endcase
end

//// combinational controlling signal
assign	ce_ram = 1;

always @(*) begin
	case(cs)
	s_initial: begin
		//// Internal
		tstamp_x_de_ns <= 1;
		tstamp_y_de_ns <= 1;
		
		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 0;
		clr_cnt_w4 <= 1;

		//// Cnt_1x, Cnt_1y
		ce_cnt_1x <= 0;
		clr_cnt_1x <= 1;
		ce_cnt_1y <= 0;
		clr_cnt_1y <= 1;
		
		//// Cnt_2x, Cnt_2y
		ce_cnt_2x <= 0;
		clr_cnt_2x <= 1;
		ce_cnt_2y <= 0;
		clr_cnt_2y <= 1;
		le <= 0;
		
		//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
		//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
		clr_addr_de <= 1;

		//// Addr_x_fin, Addr_y_fin
		clr_addr_in_fin <= 1;
		ae_x <= 0;
		ae_y <= 0;
		
		//// RAM_x, RAM_y
		clr_ram_in <= 1;
		we_x <= 0;
		we_y <= 0;
		
		//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
		clr_s_func <= 1;
		
		//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
		sel_addr_z <= 0;
		
		//// RAM_zin
		we_zin <= 0;
		clr_ram_zin <= 1;
		
		//// Cnt_3
		ce_cnt_3 <= 0;
		clr_cnt_3 <= 1;
		se <= 0;
		sb_r_ns <= 0;
		
		//// Cnt_4
		ce_cnt_4 <= 0;
		clr_cnt_4 <= 1;
		
		//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
		clr_s_dist_comp <= 1;
		
		//// RAM_zout
		clr_ram_zout <= 1;
		we_zout <= 0;
	end

	s_isi_rec: begin
		if (clk_low == 1 && clk_low_de == 0) begin
			//// Internal
			tstamp_x_de_ns <= tstamp_x;
			tstamp_y_de_ns <= tstamp_y;

			//// Cnt_w1, Cnt_w4
			ce_cnt_w1 <= 1;
			clr_cnt_w1 <= 0;
			ce_cnt_w4 <= 0;
			clr_cnt_w4 <= 1;

			//// Cnt_1x, Cnt_1y
			if ((tstamp_x == 0 && tstamp_x_de == 1)||(tstamp_x == 0 && tstamp_x_de == 0)) begin
				ce_cnt_1x <= 1;
			end
			else begin
				ce_cnt_1x <= 0;
			end
			
			if (tstamp_x == 1 && tstamp_x_de == 1) begin
				clr_cnt_1x <= 1;
			end
			else begin
				clr_cnt_1x <= 0;
			end
			
			if ((tstamp_y == 0 && tstamp_y_de == 1)||(tstamp_y == 0 && tstamp_y_de == 0)) begin
				ce_cnt_1y <= 1;
			end
			else begin
				ce_cnt_1y <= 0;
			end

			if (tstamp_y == 1 && tstamp_y_de == 1) begin
				clr_cnt_1y <= 1;
			end
			else begin
				clr_cnt_1y <= 0;
			end

			//// Cnt_2x, Cnt_2y
			if (tstamp_x == 1 && tstamp_x_de == 0 && !of_x) begin
				ce_cnt_2x <= 1;
			end
			else begin
				ce_cnt_2x <= 0;
			end
			clr_cnt_2x <= 0;

			if (tstamp_y == 1 && tstamp_y_de == 0 && !of_y) begin
				ce_cnt_2y <= 1;
			end
			else begin
				ce_cnt_2y <= 0;
			end
			clr_cnt_2y <= 0;

			le <= 0;

			//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
			//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
			clr_addr_de <= 1;

			//// Addr_x_fin, Addr_y_fin
			clr_addr_in_fin <= 0;
			
			if (tstamp_x == 1 && tstamp_x_de == 0 && !of_x) begin
				ae_x <= 1;
			end
			else begin
				ae_x <= 0;
			end

			if (tstamp_y == 1 && tstamp_y_de == 0 && !of_y) begin
				ae_y <= 1;
			end
			else begin
				ae_y <= 0;
			end

			//// RAM_x, RAM_y
			clr_ram_in <= 0;
			
			if (tstamp_x == 1 && tstamp_x_de == 0 && !of_x) begin
				we_x <= 1;
			end
			else begin
				we_x <= 0;
			end
			
			if (tstamp_y == 1 && tstamp_y_de == 0 && !of_y) begin
				we_y <= 1;
			end
			else begin
				we_y <= 0;
			end
			
			//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
			clr_s_func <= 1;
			
			//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
			sel_addr_z <= 0;
			
			//// RAM_zin
			we_zin <= 0;
			clr_ram_zin <= 1;
			
			//// Cnt_3
			ce_cnt_3 <= 0;
			clr_cnt_3 <= 1;
			se <= 0;
			sb_r_ns <= 0;
			
			//// Cnt_4
			ce_cnt_4 <= 1;
			clr_cnt_4 <= tstamp_z;
			
			//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
			clr_s_dist_comp <= 1;
			
			//// RAM_zout
			clr_ram_zout <= 0;
			we_zout <= 0;
		end
		else begin
			//// Internal
			tstamp_x_de_ns <= tstamp_x_de;
			tstamp_y_de_ns <= tstamp_y_de;

			//// Cnt_w1, Cnt_w4
			ce_cnt_w1 <= 0;
			clr_cnt_w1 <= 0;
			ce_cnt_w4 <= 0;
			clr_cnt_w4 <= 1;

			//// Cnt_1x, Cnt_1y
			ce_cnt_1x <= 0;
			clr_cnt_1x <= 0;
			ce_cnt_1y <= 0;
			clr_cnt_1y <= 0;

			//// Cnt_2x, Cnt_2y
			ce_cnt_2x <= 0;
			clr_cnt_2x <= 0;
			ce_cnt_2y <= 0;
			clr_cnt_2y <= 0;
			le <= 0;

			//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
			//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
			clr_addr_de <= 1;

			//// Addr_x_fin, Addr_y_fin
			clr_addr_in_fin <= 0;
			ae_x <= 0;
			ae_y <= 0;

			//// RAM_x, RAM_y
			clr_ram_in <= 0;
			we_x <= 0;
			we_y <= 0;
			
			//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
			clr_s_func <= 1;
			
			//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
			sel_addr_z <= 0;
			
			//// RAM_zin
			we_zin <= 0;
			clr_ram_zin <= 1;
			
			//// Cnt_3
			ce_cnt_3 <= 0;
			clr_cnt_3 <= 1;
			se <= 0;
			sb_r_ns <= 0;
			
			//// Cnt_4
			ce_cnt_4 <= 0;
			clr_cnt_4 <= 0;
			
			//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
			clr_s_dist_comp <= 1;
			
			//// RAM_zout
			clr_ram_zout <= 0;
			we_zout <= 0;
		end
	end
	
	s_clr_cnt2: begin
		//// Internal
		tstamp_x_de_ns <= tstamp_x;
		tstamp_y_de_ns <= tstamp_y;

		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 1;
		clr_cnt_w4 <= 0;

		//// Cnt_1x, Cnt_1y
		ce_cnt_1x <= 0;
		clr_cnt_1x <= 1;
		ce_cnt_1y <= 0;
		clr_cnt_1y <= 1;
		
		//// Cnt_2x, Cnt_2y
		ce_cnt_2x <= 0;
		clr_cnt_2x <= 1;
		ce_cnt_2y <= 0;
		clr_cnt_2y <= 1;
		le <= 0;
		
		//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
		//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
		clr_addr_de <= 1;

		//// Addr_x_fin, Addr_y_fin
		clr_addr_in_fin <= 0;
		ae_x <= 0;
		ae_y <= 0;
		
		//// RAM_x, RAM_y
		clr_ram_in <= 0;
		we_x <= 0;
		we_y <= 0;
		
		//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
		clr_s_func <= 1;
		
		//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
		sel_addr_z <= 1;
		
		//// RAM_zin
		we_zin <= 0;
		clr_ram_zin <= 0;
		
		//// Cnt_3
		ce_cnt_3 <= 0;
		clr_cnt_3 <= 0;
		se <= 0;
		sb_r_ns <= 0;
		
		//// Cnt_4
		ce_cnt_4 <= 0;
		clr_cnt_4 <= 1;
		
		//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
		clr_s_dist_comp <= 1;
		
		//// RAM_zout
		clr_ram_zout <= 1;
		we_zout <= 0;
	end
	
	s_func: begin
		//// Internal
		tstamp_x_de_ns <= tstamp_x;
		tstamp_y_de_ns <= tstamp_y;

		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 1;
		clr_cnt_w4 <= 0;

		//// Cnt_1x, Cnt_1y
		ce_cnt_1x <= 0;
		clr_cnt_1x <= 1;
		ce_cnt_1y <= 0;
		clr_cnt_1y <= 1;
		
		//// Cnt_2x, Cnt_2y
		if (addr_y == addr_max) begin
			ce_cnt_2x <= 1;
		end
		else begin
			ce_cnt_2x <= 0;
		end
		clr_cnt_2x <= 0;
		ce_cnt_2y <= 1;
		clr_cnt_2y <= 0;
		le <= 0;

		//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
		//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
		clr_addr_de <= 0;

		//// Addr_x_fin, Addr_y_fin
		clr_addr_in_fin <= 0;
		ae_x <= 0;
		ae_y <= 0;
		
		//// RAM_x, RAM_y
		clr_ram_in <= 0;
		we_x <= 0;
		we_y <= 0;
		
		//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
		clr_s_func <= 0;
		
		//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
		sel_addr_z <= 0;
		
		//// RAM_zin
		we_zin <= valid_de2;
		clr_ram_zin <= 0;
		
		//// Cnt_3
		ce_cnt_3 <= valid_de2;
		clr_cnt_3 <= 0;
		
		se <= 0;
		sb_r_ns <= 0;
		for (ind = sb_r_min; ind < bit_addr*2 + 1; ind = ind + 1 ) begin
			if (sum == 2**ind - 1 && valid_de2 == 1) begin
				se <= 1;
				sb_r_ns <= ind;
			end
		end
/*
		case ({sum, valid_de2})
			{13'b               111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd 3; end
			{13'b              1111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd 4; end
			{13'b             11111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd 5; end
			{13'b            111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd 6; end
			{13'b           1111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd 7; end
			{13'b          11111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd 8; end
			{13'b         111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd 9; end
			{13'b        1111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd10; end
			{13'b       11111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd11; end
			{13'b      111111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd12; end
//			{19'b     1111111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd13; end
//			{19'b    11111111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd14; end
//			{19'b   111111111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd15; end
//			{19'b  1111111111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd16; end
//			{19'b 11111111111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd17; end
//			{19'b111111111111111111, 1'b1}: begin se <= 1; sb_r_ns <= 5'd18; end
			default: begin se <= 0; sb_r_ns <= 5'd0; end
		endcase
*/
		//// Cnt_4
		ce_cnt_4 <= 0;
		clr_cnt_4 <= 1;
		
		//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
		clr_s_dist_comp <= 1;

		//// RAM_zout
		clr_ram_zout <= 1;
		we_zout <= 0;
	end
	
	s_rev_cnt2: begin		
		//// Internal
		tstamp_x_de_ns <= tstamp_x;
		tstamp_y_de_ns <= tstamp_y;

		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 1;
		clr_cnt_w4 <= 0;

		//// Cnt_1x, Cnt_1y
		ce_cnt_1x <= 0;
		clr_cnt_1x <= 1;
		ce_cnt_1y <= 0;
		clr_cnt_1y <= 1;
		
		//// Cnt_2x, Cnt_2y
		ce_cnt_2x <= 0;
		clr_cnt_2x <= 0;
		ce_cnt_2y <= 0;
		clr_cnt_2y <= 0;
		le <= 1;
		
		//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
		//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
		clr_addr_de <= 0;

		//// Addr_x_fin, Addr_y_fin
		clr_addr_in_fin <= 0;
		ae_x <= 0;
		ae_y <= 0;
		
		//// RAM_x, RAM_y
		clr_ram_in <= 0;
		we_x <= 0;
		we_y <= 0;
		
		//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
		clr_s_func <= 1;
		
		//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
		sel_addr_z <= 1;
		
		//// RAM_zin
		we_zin <= 0;
		clr_ram_zin <= 0;
		
		//// Cnt_3
		ce_cnt_3 <= 0;
		clr_cnt_3 <= 0;
		se <= 1;
		sb_r_ns <= sb_r;
		
		//// Cnt_4
		ce_cnt_4 <= 0;
		clr_cnt_4 <= 1;
		
		//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
		clr_s_dist_comp <= 1;
		
		//// RAM_zout
		clr_ram_zout <= 1;
		we_zout <= 0;
	end
	
	s_dist_comp: begin
		//// Internal
		tstamp_x_de_ns <= tstamp_x;
		tstamp_y_de_ns <= tstamp_y;

		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 1;
		clr_cnt_w4 <= 0;

		//// Cnt_1x, Cnt_1y
		ce_cnt_1x <= 0;
		clr_cnt_1x <= 1;
		ce_cnt_1y <= 0;
		clr_cnt_1y <= 1;
		
		//// Cnt_2x, Cnt_2y
		ce_cnt_2x <= 0;
		clr_cnt_2x <= 0;
		ce_cnt_2y <= 0;
		clr_cnt_2y <= 0;
		le <= 0;

		//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
		//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
		clr_addr_de <= 1;

		//// Addr_x_fin, Addr_y_fin
		clr_addr_in_fin <= 0;
		ae_x <= 0;
		ae_y <= 0;
		
		//// RAM_x, RAM_y
		clr_ram_in <= 0;
		we_x <= 0;
		we_y <= 0;
		
		//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
		clr_s_func <= 1;
		
		//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
		sel_addr_z <= 1;		

		//// RAM_zin
		we_zin <= 0;
		clr_ram_zin <= 0;
		
		//// Cnt_3
		ce_cnt_3 <= 0;
		clr_cnt_3 <= 0;
		se <= 0;
		sb_r_ns <= sb_r;
		
		//// Cnt_4
		ce_cnt_4 <= 1;
		clr_cnt_4 <= 0;
		
		//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
		clr_s_dist_comp <= 0;

		//// RAM_zout
		clr_ram_zout <= 0;
		we_zout <= 1; //// bit_to_chip will maintain previous value, so still 0.
		
	end
	
	s_clr_ram: begin
		//// Internal
		tstamp_x_de_ns <= 1;
		tstamp_y_de_ns <= 1;

		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 1;
		clr_cnt_w4 <= 0;

		//// Cnt_1x, Cnt_1y
		ce_cnt_1x <= 0;
		clr_cnt_1x <= 1;
		ce_cnt_1y <= 0;
		clr_cnt_1y <= 1;
		
		//// Cnt_2x, Cnt_2y
		ce_cnt_2x <= 1;
		clr_cnt_2x <= 0;
		ce_cnt_2y <= 1;
		clr_cnt_2y <= 0;
		le <= 0;
		
		//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
		//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
		clr_addr_de <= 1;

		//// Addr_x_fin, Addr_y_fin
		clr_addr_in_fin <= 1;
		ae_x <= 0;
		ae_y <= 0;
		
		//// RAM_x, RAM_y
		clr_ram_in <= 0;
		we_x <= 1;
		we_y <= 1;
		
		//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
		clr_s_func <= 1;
		
		//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
		sel_addr_z <= 1;
		
		//// RAM_zin
		we_zin <= 1;
		clr_ram_zin <= 0;
		
		//// Cnt_3
		ce_cnt_3 <= 0;
		clr_cnt_3 <= 1;
		se <= 0;
		sb_r_ns <= 0;
		
		//// Cnt_4
		ce_cnt_4 <= 1;
		clr_cnt_4 <= 0;
		
		//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
		clr_s_dist_comp <= 1;
		
		//// RAM_zout
		clr_ram_zout <= 1;
		we_zout <= 0;
	end

	s_idle: begin
		//// Internal
		tstamp_x_de_ns <= 1;
		tstamp_y_de_ns <= 1;

		//// Cnt_w1, Cnt_w4
		ce_cnt_w1 <= 0;
		clr_cnt_w1 <= 1;
		ce_cnt_w4 <= 1;
		clr_cnt_w4 <= 0;

		//// Cnt_1x, Cnt_1y
		ce_cnt_1x <= 0;
		clr_cnt_1x <= 1;
		ce_cnt_1y <= 0;
		clr_cnt_1y <= 1;
		
		//// Cnt_2x, Cnt_2y
		ce_cnt_2x <= 0;
		clr_cnt_2x <= 1;
		ce_cnt_2y <= 0;
		clr_cnt_2y <= 1;
		le <= 0;
		
		//// De1_addr_x, De2_addr_x, De3_addr_x, De4_addr_x, 
		//// De1_addr_y, De2_addr_y, De3_addr_y, De4_addr_y
		clr_addr_de <= 1;

		//// Addr_x_fin, Addr_y_fin
		clr_addr_in_fin <= 1;
		ae_x <= 0;
		ae_y <= 0;
		
		//// RAM_x, RAM_y
		clr_ram_in <= 1;
		we_x <= 0;
		we_y <= 0;
		
		//// Function, De1_isi_z, De2_isi_z, De1_valid, De2_valid, Acc
		clr_s_func <= 1;
		
		//// Mux_addr_zin_r, Mux_addr_zin_w, Mux_addr_zout
		sel_addr_z <= 0;
		
		//// RAM_zin
		we_zin <= 0;
		clr_ram_zin <= 1;
		
		//// Cnt_3
		ce_cnt_3 <= 0;
		clr_cnt_3 <= 1;
		se <= 0;
		sb_r_ns <= 0;
		
		//// Cnt_4
		ce_cnt_4 <= 0;
		clr_cnt_4 <= 1;
		
		//// Shi_l & Shi_r, Bit_ex, De1_isi_z_q, De2_isi_z_q, De3_isi_z_q, De4_isi_z_q
		clr_s_dist_comp <= 1;
		
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
		exp_w2_ns <= 0;
		exp_w3 <= 0;
		exp_w4 <= 0;
		exp_w5_x_ns <= 0;
		exp_w5_zin_ns <= 0;
	end
	
	s_isi_rec: begin
		if (w1_cnt >= w1) begin
			exp_w1 <= 1;
		end
		else begin
			exp_w1 <= 0;
		end
		exp_w2_ns <= 0;
		exp_w3 <= 0;
		exp_w4 <= 0;
		exp_w5_x_ns <= 0;
		exp_w5_zin_ns <= 0;
	end

	s_clr_cnt2: begin
		exp_w1 <= 1;
		exp_w2_ns <= 0;
		exp_w3 <= 0;

		if (w4_cnt >= w4) begin
			exp_w4 <= 1;
		end
		else begin
			exp_w4 <= 0;
		end

		exp_w5_x_ns <= 0;
		exp_w5_zin_ns <= 0;
	end
	
	s_func: begin
		exp_w1 <= 1;
		if (addr_y_de3 >= addr_max && addr_x_de3 >= addr_max) begin
			exp_w2_ns <= 1;
		end
		else begin
			exp_w2_ns <= exp_w2; //// cannot assign 0 because next cs (de4) still in s_func. 
		end
		exp_w3 <= 0;

		if (w4_cnt >= w4) begin
			exp_w4 <= 1;
		end
		else begin
			exp_w4 <= 0;
		end

		exp_w5_x_ns <= 0;
		exp_w5_zin_ns <= 0;
	end
	
	s_rev_cnt2: begin
		exp_w1 <= 1;
		exp_w2_ns <= exp_w2;
		exp_w3 <= 0;

		if (w4_cnt >= w4) begin
			exp_w4 <= 1;
		end
		else begin
			exp_w4 <= 0;
		end

		exp_w5_x_ns <= 0;
		exp_w5_zin_ns <= 0;
	end
	
	s_dist_comp: begin
		exp_w1 <= 1;
		exp_w2_ns <= exp_w2;
		if (addr_zout >= isi_max) begin
			exp_w3 <= 1;
		end
		else begin
			exp_w3 <= 0;
		end

		if (w4_cnt >= w4) begin
			exp_w4 <= 1;
		end
		else begin
			exp_w4 <= 0;
		end

		exp_w5_x_ns <= 0;
		exp_w5_zin_ns <= 0;
	end
	
	s_clr_ram: begin
		exp_w1 <= 1;
		exp_w2_ns <= exp_w2;
		exp_w3 <= 1;

		if (w4_cnt >= w4) begin
			exp_w4 <= 1;
		end
		else begin
			exp_w4 <= 0;
		end

		if (addr_x >= addr_max) begin
			exp_w5_x_ns <= 1;
		end
		else begin
			exp_w5_x_ns <= exp_w5_x;
		end
		
		if (addr_zin_w >= isi_max) begin
			exp_w5_zin_ns <= 1;
		end
		else begin
			exp_w5_zin_ns <= exp_w5_zin;
		end
	end
	
	s_idle: begin
		exp_w1 <= 1;
		exp_w2_ns <= exp_w2;
		exp_w3 <= 1;
		
		if (w4_cnt >= w4) begin
			exp_w4 <= 1;
		end
		else begin
			exp_w4 <= 0;
		end
		
		exp_w5_x_ns <= exp_w5_x;
		exp_w5_zin_ns <= exp_w5_zin;
	end
	endcase
	
	if (exp_w5_x && exp_w5_zin) begin
		exp_w5 <= 1;
	end
	else begin
		exp_w5 <= 0;
	end
end
endmodule
