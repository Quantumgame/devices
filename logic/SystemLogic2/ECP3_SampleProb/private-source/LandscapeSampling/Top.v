`include "C:\lscc\diamond\3.7_x64\cae_library\synthesis\verilog\pmi_def.v"
module Top (clk_main, rst, aer_in, clk_rng, clk_low, clk_data_de2, latch, data_to_chip);

parameter bit_isi = 8, bit_addr = 9, w1 = 2**14, sb_r_min = 4, pw = 4, g_02 = 7, g_03 = 0.33; 
//// for LS_Gain_BT1, bit_g has to <= bit_addr; i.e. g <= 2**bit_addr. 
parameter r_main_to_rng = 100, r_data_to_low = 100, lw = 1;
parameter r_main_to_low = r_main_to_rng*32;
//// r_main_to_low has to be an even number.
//// r_main_to_low should be x32 larger than r_main_to_rng because clk_low is x32 slower than clk_rng.
//// r_data_to_low has to be larger than (bit_chip*node).
//// lw define the width of latch. 1 unit is represented by the period of clk_data.
//// r_main_to_low/r_data_to_low has to be an even number.
parameter bit_chip = 6, node = 16;

input wire clk_main, rst;
input wire [node-1:0] aer_in;
output wire clk_data_de2, clk_low, clk_rng, data_to_chip, latch;
wire [bit_chip*node-1:0] array_to_chip_in, array_to_chip_out;
wire [node-1:0] request_x, request_y, request_z;

Conn_Node #(.node(node))
Conn_Node (aer_in, request_x, request_y, request_z);

Clk_System #(.bit_chip(bit_chip), .node(node), .r_main_to_rng(r_main_to_rng), .r_main_to_low(r_main_to_low), .r_data_to_low(r_data_to_low), .lw(lw)) 
Clk_System (clk_main, rst, clk_rng, clk_low, clk_data_de2, latch);
//// (clk_main, rst, clk_low, clk_data_de2, latch)

LS_Equality #(.bit_isi(bit_isi), .bit_addr(bit_addr), .bit_chip(bit_chip), .w1(w1), .sb_r_min(sb_r_min), .pw(pw), .r_main_to_low(r_main_to_low)) 
LS_00 (clk_main, clk_low, rst, request_x[0], request_y[0], request_z[0], array_to_chip_in[ 1*bit_chip-1: 0*bit_chip]);
//// (clk_main, clk_low, rst, request_x, request_y, request_z, bit_to_chip)

LS_Plus #(.bit_isi(bit_isi), .bit_addr(bit_addr), .bit_chip(bit_chip), .w1(w1), .sb_r_min(sb_r_min), .pw(pw), .r_main_to_low(r_main_to_low)) 
LS_01 (clk_main, clk_low, rst, request_x[1], request_y[1], request_z[1], array_to_chip_in[ 2*bit_chip-1: 1*bit_chip]);
//// (clk_main, clk_low, rst, request_x, request_y, request_z, bit_to_chip)

LS_Gain_BT1 #(.bit_isi(bit_isi), .bit_addr(bit_addr), .bit_chip(bit_chip), .w1(w1), .sb_r_min(sb_r_min), .pw(pw), .r_main_to_low(r_main_to_low), .g(g_02)) 
LS_02 (clk_main, clk_low, rst, request_x[2], request_z[2], array_to_chip_in[ 3*bit_chip-1: 2*bit_chip]);
//// (clk_main, clk_low, rst, request_x, request_z, bit_to_chip)

LS_Gain_ST1 #(.bit_isi(bit_isi), .bit_addr(bit_addr), .bit_chip(bit_chip), .w1(w1), .sb_r_min(sb_r_min), .pw(pw), .r_main_to_low(r_main_to_low), .g(g_03)) 
LS_03 (clk_main, clk_low, rst, request_x[3], request_z[3], array_to_chip_in[ 4*bit_chip-1: 3*bit_chip]);
//// (clk_main, clk_low, rst, request_x, request_z, bit_to_chip)

LS_Pro_v1 #(.bit_isi(bit_isi), .bit_addr(bit_addr), .bit_chip(bit_chip), .w1(w1), .sb_r_min(sb_r_min), .pw(pw), .r_main_to_low(r_main_to_low)) 
LS_04 (clk_main, clk_low, rst, request_z[4], array_to_chip_in[ 5*bit_chip-1: 4*bit_chip]);
//// (clk_main, clk_low, rst, request_z, bit_to_chip)

LS_Pro_v2 #(.bit_isi(bit_isi), .bit_addr(bit_addr), .bit_chip(bit_chip), .w1(w1), .sb_r_min(sb_r_min), .pw(pw), .r_main_to_low(r_main_to_low)) 
LS_05 (clk_main, clk_low, rst, request_z[5], array_to_chip_in[ 6*bit_chip-1: 5*bit_chip]);
//// (clk_main, clk_low, rst, request_z, bit_to_chip)

//assign array_to_chip_in[ 1*bit_chip-1: 0*bit_chip] = 0;
//assign array_to_chip_in[ 2*bit_chip-1: 1*bit_chip] = 0;
//assign array_to_chip_in[ 3*bit_chip-1: 2*bit_chip] = 0;
//assign array_to_chip_in[ 4*bit_chip-1: 3*bit_chip] = 0;
//assign array_to_chip_in[ 5*bit_chip-1: 4*bit_chip] = 0;
//assign array_to_chip_in[ 6*bit_chip-1: 5*bit_chip] = 0;
assign array_to_chip_in[ 7*bit_chip-1: 6*bit_chip] = 0;
assign array_to_chip_in[ 8*bit_chip-1: 7*bit_chip] = 0;
assign array_to_chip_in[ 9*bit_chip-1: 8*bit_chip] = 0;
assign array_to_chip_in[10*bit_chip-1: 9*bit_chip] = 0;
assign array_to_chip_in[11*bit_chip-1:10*bit_chip] = 0;
assign array_to_chip_in[12*bit_chip-1:11*bit_chip] = 0;
assign array_to_chip_in[13*bit_chip-1:12*bit_chip] = 0;
assign array_to_chip_in[14*bit_chip-1:13*bit_chip] = 0;
assign array_to_chip_in[15*bit_chip-1:14*bit_chip] = 0;
assign array_to_chip_in[16*bit_chip-1:15*bit_chip] = 0;

Bit_Reroute #(.bit_chip(bit_chip), .node(node)) Bit_Reroute (array_to_chip_in, array_to_chip_out);
//// (bit_in, bit_out)

Bit_Combine #(.bit_chip(bit_chip), .node(node)) Bit_Combine (clk_main, clk_data_de2, rst, array_to_chip_out, data_to_chip);
//// (clk_main, clk_data_de2, rst, array_to_chip, data_to_chip)

endmodule