/**************************************************************************\ 
module name : AMDA : package_gen
author		: Yuzhe Li 
FPGA		: Xilinx A7_100-T
DATE		: DEC 9,2024

modify		:
\*************************************************************************/
`timescale 1ns/1ps
module package_gen(
	// clk && rst
	input								clk				,
	input								resetn			,
	input								user_wr_trig	,
	// user wr
	output		[44 : 0]				user_wr_cmd		,
	output								user_cmd_wen	,
	output	reg	[63 : 0] 				user_wr_data	,	
	output								user_wr_en	
);

localparam	IDLE 	= 4'b0001;
localparam	REQ 	= 4'b0010;
localparam	DATA_EN = 4'b0100;
localparam	END 	= 4'b1000;

reg [3:0] state;
reg [3:0] next_state;

reg	[31:0] data_cnt ;
reg	[31:0] user_addr;

// FSM
always@(posedge clk or negedge resetn) begin
	if(~resetn)
		state <= IDLE;
	else
		state <= next_state;
end
always@(*) begin
	case(state)
		IDLE	:	next_state <= (user_wr_trig)? REQ : IDLE ;
		REQ		: 	next_state <= DATA_EN ;
		DATA_EN	:	next_state <= (data_cnt == 'd1023)? END : DATA_EN;
		END 	: 	next_state <= IDLE;
		default : 	next_state <= state;
	endcase
end
// cmd
always@(posedge clk or negedge resetn) begin
	if(~resetn)
		user_addr <= 'd0;
	else if(state == REQ)
		user_addr <= user_addr + 8192;
	else 
		user_addr <= user_addr ;
end

// data
always@(posedge clk or negedge resetn) begin
	if(~resetn)
		data_cnt <= 'd0;
	else if(data_cnt == 'd1023)
		data_cnt <= 'd0;
	else if(user_wr_en)
		data_cnt <= data_cnt + 'd1;
end

always@(posedge clk or negedge resetn) begin
	if(~resetn)
		user_wr_data <= 'd0;
	else if(user_wr_en)
		user_wr_data <= user_wr_data + 'd1;
end

assign user_cmd_wen = state == REQ;
assign user_wr_en = state == DATA_EN;
assign user_wr_cmd = {13'h400, user_addr};

endmodule