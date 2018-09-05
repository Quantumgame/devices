//`include "C:\lscc\diamond\3.6_x64\cae_library\synthesis\verilog\pmi_def.v"
module LS_Pro_v1 (clk_main, clk_low, rst, request_z, bit_to_chip);

parameter bit_isi = 8, bit_addr = 9, bit_chip = 6, w1 = 2**14, sb_r_min = 4, pw = 4, r_main_to_low = 1000;
parameter integer w4 = 1 + (2**bit_isi + 3) + (2**(bit_addr*2) + 4*(bit_addr*2 - sb_r_min + 1)) + 
(bit_addr*2 - sb_r_min + 1) + ((2**bit_isi + 3)*(bit_addr*2 - sb_r_min + 1)) + 
(2**bit_isi + 2**bit_addr) + 1;
//// total clk numbers require: 
//// s_clr (= 1) + 
//// s_dist_comp (the memory length + 3 delays) + 
//// s_func (exhausted comparison of addr + counting back 4 once sum is equal to 2**sb_r) + 
//// s_rev_cnt2 (the times that sum is equal to 2**sb_r) + 
//// s_dist_comp (the times that sum is equal to 2**sb_r. each amounts to the memory length + 3 delays) + 
//// s_clr_ram (considering both isi and addr memory length because we don't know which is larger)
//// s_idle (= 1)
parameter bit_w1 = $clog2(w1);
parameter bit_w4 = $clog2(w4);

input wire clk_low, clk_main, rst, request_z;
output wire [bit_chip-1:0] bit_to_chip;

//// Controller output wire
wire ce_cnt_4, ce_cnt_w1, ce_cnt_w4, ce_ram, clr_cnt_4, clr_cnt_w1, clr_cnt_w4, clr_ram_zout, we_zout;
wire [bit_chip-1:0] acc_shi_r;
wire [bit_w1-1:0] w1_cnt;
wire [bit_w4-1:0] w4_cnt;

//// Other module output wire
wire tstamp_z;
wire [bit_isi-1:0] addr_zout, isi_z_q;

Pulse_Extend #(.pw(pw-1), .r_main_to_low(r_main_to_low)) Pulse_Ex_Z (clk_main, rst, request_z, tstamp_z);
//// (clk_main, clr, request, tstamp)

Controller_Pro #(.bit_isi(bit_isi), .bit_addr(bit_addr), .sb_r_min(sb_r_min), .w1(w1), .w4(w4))
Controller_Pro (clk_low, clk_main, rst, tstamp_z, w1_cnt, w4_cnt, 
ce_cnt_4, ce_cnt_w1, ce_cnt_w4, ce_ram, clr_cnt_4, clr_cnt_w1, clr_cnt_w4, clr_ram_zout, we_zout);

Cnt #(.bit_io(bit_w1)) Cnt_W1 (clk_main, ce_cnt_w1, clr_cnt_w1, w1_cnt);
Cnt #(.bit_io(bit_w4)) Cnt_W4 (clk_main, ce_cnt_w4, clr_cnt_w4, w4_cnt);
//// (clk, ce, clr, q)

Cnt #(.bit_io(bit_isi)) Cnt_4 (clk_main, ce_cnt_4, clr_cnt_4, isi_z_q);
//// (clk, ce, clr, q)

assign addr_zout = isi_z_q + 1;

assign acc_shi_r = 0;

RAM_Pro_v1 RAM_Zout (clk_main, ce_ram, clr_ram_zout, we_zout, addr_zout, acc_shi_r, bit_to_chip);
//// (Clock, ClockEn, Reset, WE, Address, Data, Q)

//pmi_ram_dq #(.pmi_addr_depth(2**bit_isi), .pmi_addr_width(bit_isi), .pmi_data_width(bit_chip), .pmi_regmode("noreg"), .pmi_optimization("area"), .pmi_init_file("../Pro.mem")/*, .pmi_init_file_format("binary")*/) 
//RAM_Zout (.Clock(clk_main), .ClockEn(ce_ram), .Reset(clr_ram_zout), .WE(we_zout), .Address(addr_zout), .Data(acc_shi_r), .Q(bit_to_chip));

endmodule
