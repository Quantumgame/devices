module Conn_Node (aer_in, request_x, request_y, request_z);

parameter node = 16;

input wire [node-1:0] aer_in; //// aer receiver output as the input
output wire [node-1:0] request_x, request_y, request_z;

assign request_z = aer_in;

assign request_x[0] = aer_in[4];
assign request_y[0] = aer_in[5];

assign request_x[1] = aer_in[4];
assign request_y[1] = aer_in[5];

assign request_x[2] = aer_in[4];
assign request_y[2] = 0;

assign request_x[3] = aer_in[4];
assign request_y[3] = 0;

assign request_x[4] = 0;
assign request_y[4] = 0;

assign request_x[5] = 0;
assign request_y[5] = 0;

assign request_x[6] = 0;
assign request_y[6] = 0;

assign request_x[7] = 0;
assign request_y[7] = 0;

assign request_x[8] = 0;
assign request_y[8] = 0;

assign request_x[9] = 0;
assign request_y[9] = 0;

assign request_x[10] = 0;
assign request_y[10] = 0;

assign request_x[11] = 0;
assign request_y[11] = 0;

assign request_x[12] = 0;
assign request_y[12] = 0;

assign request_x[13] = 0;
assign request_y[13] = 0;

assign request_x[14] = 0;
assign request_y[14] = 0;

assign request_x[15] = 0;
assign request_y[15] = 0;

endmodule