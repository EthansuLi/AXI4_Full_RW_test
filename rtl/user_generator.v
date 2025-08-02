`timescale 1ns/1ps
module user_generator#(
	parameter AXI_ADDR_WIDTH = 32,
	parameter USER_DATA_WIDTH = 16
)(
	// clk & rst
	input									clk				,
	input									resetn			,
	// user wr
	input									wr_trig			,
	output		 							user_cmd_wen	,
	output		[AXI_ADDR_WIDTH +11:0]		user_wr_cmd		,
	output									user_wr_en		,
	output	reg	[USER_DATA_WIDTH -1:0]		user_wr_data	,
	// user rd
	input									rd_trig			,
	output		[AXI_ADDR_WIDTH +11:0]		user_rd_cmd		,
	output	reg								user_cmd_ren	
);

localparam	IDLE 		= 4'b0001	;
localparam	WCMD 		= 4'b0010	;
localparam	WR_DATA_EN	= 4'b0100	;
localparam	WR_END		= 4'b1000	;

localparam	PACKAGE_LEN = 1024;
localparam	AXI_BLEN	= PACKAGE_LEN * (USER_DATA_WIDTH / 8);

reg  [3:0] 	state;
reg	 [3:0]	next_state;
reg	 [AXI_ADDR_WIDTH -1:0]	user_waddr	;
reg	 [AXI_ADDR_WIDTH -1:0]	user_raddr	;
//============================ write ==============================//
// FSM
always@(posedge clk or negedge resetn) begin
	if(~resetn)
		state <= IDLE;
	else 
		state <= next_state;
end
always@(*) begin
	if(~resetn)
		next_state <= IDLE;
	else begin
		case(state)
			IDLE		:	next_state = (wr_trig)? WCMD : IDLE;
			WCMD 		:	next_state = WR_DATA_EN;
			WR_DATA_EN	:	next_state = (user_wr_data == PACKAGE_LEN -1)? WR_END : WR_DATA_EN;
			WR_END		:	next_state = IDLE;
			default : next_state = state;
		endcase
	end
end

always@(posedge clk or negedge resetn) begin
	if(~resetn)
		user_waddr <= 'd0;
	else if(wr_trig)
		user_waddr <= user_waddr + AXI_BLEN;
end

assign user_cmd_wen = state == WCMD;
assign user_wr_cmd	= (user_cmd_wen)? {8'h400, user_waddr} : 0 ;
assign user_wr_en   = state == WR_DATA_EN;

always@(posedge clk or negedge resetn) begin
	if(~resetn)
		user_wr_data <= 'd0;
	else if((user_wr_data < PACKAGE_LEN -1 || user_wr_data < 2*PACKAGE_LEN -1) && user_wr_en)
		user_wr_data <= user_wr_data + 1;
	else
		user_wr_data <= user_wr_data	;
end

//============================ read  ==============================//
always@(posedge clk or negedge resetn) begin
	if(~resetn) begin
		user_cmd_ren<= 1'b0;
	end
	else if(rd_trig) begin
		user_cmd_ren<= 1'b1;
	end
	else begin
		user_cmd_ren<= 1'b0;
	end

end

always@(posedge clk or negedge resetn) begin
	if(~resetn)
		user_raddr <= 'd0;
	else if(rd_trig)
		user_raddr <= user_raddr + AXI_BLEN;
end
assign user_rd_cmd = (user_cmd_ren)? {8'h400, user_raddr} : 'd0;
endmodule