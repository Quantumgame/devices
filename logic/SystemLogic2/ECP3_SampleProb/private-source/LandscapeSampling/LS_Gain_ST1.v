//`include "C:\lscc\diamond\3.6_x64\cae_library\synthesis\verilog\pmi_def.v"
module LS_Gain_ST1 (clk_main, clk_low, rst, request_x, request_z, bit_to_chip);

parameter bit_isi = 8, bit_addr = 9, bit_chip = 6, w1 = 2**14, sb_r_min = 4, pw = 4, r_main_to_low = 1000, g = 1;

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
parameter bit_shi_r = $clog2(bit_addr+1);

input wire clk_low, clk_main, rst, request_x, request_z;
output wire [bit_chip-1:0] bit_to_chip;

//// Controller output wire
wire ae_x, ce_cnt_1x, ce_cnt_2x, 
ce_cnt_3, ce_cnt_4, ce_cnt_w1, ce_cnt_w4, ce_ram, clr_addr_de, 
clr_addr_in_fin, clr_cnt_1x, clr_cnt_2x, 
clr_cnt_3, clr_cnt_4, clr_cnt_w1, clr_cnt_w4, clr_ram_in, clr_ram_zin, 
clr_ram_zout, clr_s_dist_comp, clr_s_func, clr_s_func_de, exp_w1_de1, le, 
sel_addr_z, tstamp_x_de, we_x, we_zin, we_zout;
wire [bit_shi_r-1:0] sb_r; 
wire [bit_w1-1:0] w1_cnt;
wire [bit_w4-1:0] w4_cnt;

//// Other module output wire
wire clk_st1, comp_addr_x, valid, valid_de1, valid_de2, of_x, tstamp_x, tstamp_z;
wire [bit_isi-1:0] addr_zin_r, addr_zin_w, addr_zout, isi_x, isi_x_q, 
isi_z, isi_z_add, isi_z_de1, isi_z_de2, isi_z_de3, isi_z_q, isi_z_q_de1, isi_z_q_de2, isi_z_q_de3;
wire [bit_addr-1:0] addr_x, addr_x_de1, addr_x_de2, addr_x_de3, addr_x_de4, addr_x_fin; 
wire [bit_addr:0] acc_d, acc_q, acc_mux, sum;
wire [bit_addr+bit_chip:0] acc_ex, acc_shi_l, acc_sub;
wire [bit_chip-1:0] acc_shi_r;

Pulse_Extend #(.pw(pw), .r_main_to_low(r_main_to_low)) Pulse_Ex_X (clk_main, rst, request_x, tstamp_x);
//Pulse_Extend #(.pw(pw), .r_main_to_low(r_main_to_low)) Pulse_Ex_Y (clk_main, rst, request_y, tstamp_y);
Pulse_Extend #(.pw(pw-1), .r_main_to_low(r_main_to_low)) Pulse_Ex_Z (clk_main, rst, request_z, tstamp_z);
//// make pw of tstamp_z shorter in order that chip can load the correct bit_to_chip.
//// (clk_main, clr, request, tstamp)

Clk_Gain #(.r_main_to_low(r_main_to_low), .g(g)) Clk_Gain (clk_main, clk_low, rst, exp_w1_de1, tstamp_x, tstamp_x_de, clk_st1);
//// (clk_main, clk_low, clr, tstamp, tstamp_de, clk_st1)

Controller_ST1 #(.bit_isi(bit_isi), .bit_addr(bit_addr), .bit_shi_r(bit_shi_r), .sb_r_min(sb_r_min), .w1(w1), .w4(w4)) 
Controller_ST1 (addr_x, addr_x_de3, addr_zin_w, addr_zout, 
clk_low, clk_main, clk_st1, of_x, rst, sum, tstamp_x, tstamp_z, 
valid_de2, w1_cnt, w4_cnt, 
ae_x, ce_cnt_1x, ce_cnt_2x, ce_cnt_3, 
ce_cnt_4, ce_cnt_w1, ce_cnt_w4, ce_ram, clr_addr_de, 
clr_addr_in_fin, clr_cnt_1x, clr_cnt_2x, 
clr_cnt_3, clr_cnt_4, clr_cnt_w1, clr_cnt_w4, clr_ram_in, clr_ram_zin, 
clr_ram_zout, clr_s_dist_comp, clr_s_func, clr_s_func_de, 
exp_w1_de1, le, sb_r, sel_addr_z, tstamp_x_de, we_x, we_zin, we_zout
);

Cnt #(.bit_io(bit_w1)) Cnt_W1 (clk_main, ce_cnt_w1, clr_cnt_w1, w1_cnt);
Cnt #(.bit_io(bit_w4)) Cnt_W4 (clk_main, ce_cnt_w4, clr_cnt_w4, w4_cnt);
//// (clk, ce, clr, q)

Cnt_ISI #(.bit_isi(bit_isi)) Cnt_1X (clk_main, ce_cnt_1x, clr_cnt_1x, isi_x, of_x);
//Cnt_ISI #(.bit_isi(bit_isi)) Cnt_1Y (clk_main, ce_cnt_1y, clr_cnt_1y, isi_y, of_y);
//// (clk, ce, clr, q)

Cnt_Addr #(.bit_addr(bit_addr)) Cnt_2X (clk_main, ce_cnt_2x, clr_cnt_2x, le, addr_x_de4, addr_x);
//Cnt_Addr #(.bit_addr(bit_g)) Cnt_2Y (clk_main, ce_cnt_2y, clr_cnt_2y, le, addr_y_de4, addr_y);
//// (clk, ce, clr, le, d, q)

Delay #(.bit_de(bit_addr)) De1_Addr_X (clk_main, clr_addr_de, addr_x, addr_x_de1);
Delay #(.bit_de(bit_addr)) De2_Addr_X (clk_main, clr_addr_de, addr_x_de1, addr_x_de2);
Delay #(.bit_de(bit_addr)) De3_Addr_X (clk_main, clr_addr_de, addr_x_de2, addr_x_de3);
Delay #(.bit_de(bit_addr)) De4_Addr_X (clk_main, clr_addr_de, addr_x_de3, addr_x_de4);

//Delay #(.bit_de(bit_g)) De1_Addr_Y (clk_main, clr_addr_de, addr_y, addr_y_de1);
//Delay #(.bit_de(bit_g)) De2_Addr_Y (clk_main, clr_addr_de, addr_y_de1, addr_y_de2);
//Delay #(.bit_de(bit_g)) De3_Addr_Y (clk_main, clr_addr_de, addr_y_de2, addr_y_de3);
//Delay #(.bit_de(bit_g)) De4_Addr_Y (clk_main, clr_addr_de, addr_y_de3, addr_y_de4);
//// (clk, clr, d, q)

Addr_In_Fin #(.bit_addr(bit_addr)) Addr_X_Fin(clk_main, clr_addr_in_fin, addr_x, ae_x, exp_w1_de1, addr_x_fin);
//Addr_In_Fin #(.bit_addr(bit_addr)) Addr_Y_Fin(clk_main, clr_addr_in_fin, addr_y, ae_y, exp_w1_de1, addr_y_fin);
//// (clk, clr, addr, ae, exp_w1_de1, addr_fin)
//assign addr_y_fin = g - 1;

pmi_ram_dq #(.pmi_addr_depth(2**bit_addr), .pmi_addr_width(bit_addr), .pmi_data_width(bit_isi), .pmi_regmode("noreg"), .pmi_optimization("area")) 
RAM_X (.Clock(clk_main), .ClockEn(ce_ram), .Reset(clr_ram_in), .WE(we_x), .Address(addr_x), .Data(isi_x), .Q(isi_x_q));

//Delay #(.bit_de(bit_g)) RAM_Y (clk_main, clr_ram_in, addr_y, isi_y_q); 
//// no need memory for y. put a delay instead.

Comp_Addr #(.bit_addr(bit_addr)) Comp_Addr_X (clk_main, addr_x, addr_x_fin, comp_addr_x);
//Comp_Addr #(.bit_addr(bit_g)) Comp_Addr_Y (clk_main, addr_y, addr_y_fin, comp_addr_y);
//// (clk, addr, addr_fin, comp_addr)

Gain_ST1 #(.bit_isi(bit_isi)) Gain_ST1 (clk_main, clr_s_func_de, isi_x_q, comp_addr_x, isi_z, valid);
//// (clk, clr, isi_x, isi_y, comp_addr_x, comp_addr_y, isi_z, valid)

Delay #(.bit_de(bit_isi)) De1_ISI_Z (clk_main, clr_s_func, isi_z, isi_z_de1);
Delay #(.bit_de(bit_isi)) De2_ISI_Z (clk_main, clr_s_func, isi_z_de1, isi_z_de2);
Delay #(.bit_de(bit_isi)) De3_ISI_Z (clk_main, clr_s_func, isi_z_de2, isi_z_de3);
Delay #(.bit_de(1)) De1_Valid (clk_main, clr_s_func, valid, valid_de1);
Delay #(.bit_de(1)) De2_Valid (clk_main, clr_s_func, valid_de1, valid_de2);
//// (clk, clr, d, q)

Mux_Addr_Z #(.bit_isi(bit_isi)) Mux_Addr_Zin_W (isi_z_de2, isi_z_q_de3, sel_addr_z, addr_zin_w);
//// (in_0, in_1, sel, out)

Acc #(.bit_addr_acc(bit_addr+1)) Acc (clk_main, clr_s_func, acc_mux, valid_de1, acc_d);
//// (clk, clr, acc_old, valid_de1, acc_new)

Mux_Acc #(.bit_isi(bit_isi), .bit_addr_acc(bit_addr+1)) Mux_Acc (clk_main, clr_s_func, acc_d, acc_q, isi_z_de1, isi_z_de2, isi_z_de3, acc_mux);
//// (clk, clr, acc_d, acc_q, a, b, c, acc_mux)

Mux_Addr_Z #(.bit_isi(bit_isi)) Mux_Addr_Zin_R (isi_z, isi_z_q, sel_addr_z, addr_zin_r);
//// (in_0, in_1, sel, out)

RAM_06b_08b_DP RAM_Zin (addr_zin_w, addr_zin_r, acc_d, we_zin, clk_main, ce_ram, clr_ram_zin, clk_main, ce_ram, acc_q);
//// RAM_(bit_addr+1)_(bit_isi)_DP
//// (WrAddress, RdAddress, Data, WE, RdClock, RdClockEn, Reset, WrClock, WrClockEn, Q)

Cnt #(.bit_io(bit_addr+1)) Cnt_3 (clk_main, ce_cnt_3, clr_cnt_3, sum);
//// (clk, ce, clr, q)

Cnt #(.bit_io(bit_isi)) Cnt_4 (clk_main, ce_cnt_4, clr_cnt_4, isi_z_q);
//// (clk, ce, clr, q)

Shifter_L #(.bit_addr_shi(bit_addr+1), .bit_chip(bit_chip)) Shi_L (clk_main, clr_s_dist_comp, acc_q, acc_shi_l);
//// (clk, clr, acc_q, acc_shi_l)

Bit_Extend #(.bit_addr_ex(bit_addr+1), .bit_chip(bit_chip)) Bit_Extend (clk_main, clr_s_dist_comp, acc_q, acc_ex);
//// (clk, clr, in, out)

Subtractor #(.bit_addr_sub(bit_addr+1), .bit_chip(bit_chip)) Sub (acc_shi_l, acc_ex, acc_sub);
//// (a, b, c)

Shifter_R #(.bit_addr_shi(bit_addr+1), .bit_chip(bit_chip), .bit_shi_r(bit_shi_r), .sb_r_min(sb_r_min)) Shi_R (clk_main, clr_s_dist_comp, sb_r, acc_sub, acc_shi_r);
//// (clk, clr, sb_r, in, out)

Delay #(.bit_de(bit_isi)) De1_ISI_Z_Q (clk_main, clr_cnt_4, isi_z_q, isi_z_q_de1);
Delay #(.bit_de(bit_isi)) De2_ISI_Z_Q (clk_main, clr_cnt_4, isi_z_q_de1, isi_z_q_de2);
Delay #(.bit_de(bit_isi)) De3_ISI_Z_Q (clk_main, clr_cnt_4, isi_z_q_de2, isi_z_q_de3);
//// (clk, clr, d, q)

assign isi_z_add = isi_z_q + 1;

Mux_Addr_Z #(.bit_isi(bit_isi)) Mux_Addr_Zout (isi_z_add, isi_z_q_de3, sel_addr_z, addr_zout);
//// (in_0, in_1, sel, out)

pmi_ram_dq #(.pmi_addr_depth(2**bit_isi), .pmi_addr_width(bit_isi), .pmi_data_width(bit_chip), .pmi_regmode("noreg"), .pmi_optimization("area")) 
RAM_Zout (.Clock(clk_main), .ClockEn(ce_ram), .Reset(clr_ram_zout), .WE(we_zout), .Address(addr_zout), .Data(acc_shi_r), .Q(bit_to_chip));

endmodule