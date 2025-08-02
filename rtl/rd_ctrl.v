// -----------------------------------------------------------------------------
// Author : Yuzheli
// File   : rd_ctrl.v
// -----------------------------------------------------------------------------
module rd_ctrl#(
	parameter	AXI_ADDR_WIDTH = 32	,
	parameter	AXI_DATA_WIDTH	= 128,
	parameter 	AXI_BURST_LEN  = 4096
)(
// clk & rst
	input								clk					,
	input								reset_n				,		
	input								ddr_init_done		,
// to buffer
	input								rd_buffer_ready		,
	output reg	[AXI_ADDR_WIDTH -1:0]	rd_addr_out			,
	output reg							rd_req_en			,
	output reg	[7:0]					rd_burst_length		,
// from uesr
	input								user_rd_mode		,
	input								user_rd_req			,
	input		[AXI_ADDR_WIDTH -1:0]	user_rd_addr 		,
	input		[12:0]					user_rd_length		,
	input		[AXI_ADDR_WIDTH -1:0]	user_rd_base_addr	,
	input		[AXI_ADDR_WIDTH -1:0]	user_rd_end_addr	,
	output								user_rd_busy		
);
//============================ parameter ===============================//
// fsm 独热码
localparam	IDLE = 3'b001;
localparam  REQ  = 3'b010;
localparam  END  = 3'b100;

localparam	AXI_BURST_CNT = AXI_BURST_LEN / (AXI_DATA_WIDTH / 8);
//============================ reg & wire ==============================//
// async
(* dont_touch ="true" *)reg resetn_async0;
(* dont_touch ="true" *)reg resetn_async1;
(* dont_touch ="true" *)reg resetn_async;

(* dont_touch ="true" *)reg ddr_init_done_d0;
(* dont_touch ="true" *)reg ddr_init_done_d1;
(* dont_touch ="true" *)reg ddr_init_done_en;

reg [2:0] state;
reg [2:0] next_state;

reg user_rd_req_d0;
reg user_rd_req_d1; // 捕获用户读请求上升沿

wire rd_req_rise;
reg rd_req_trig;

reg [AXI_ADDR_WIDTH -1:0] user_rd_addr_d;
reg [12:0]				 user_rd_length_d;
//============================== timeseq ===============================//
//async 异步释放
always @(posedge clk) begin
	if(~reset_n) begin
		resetn_async0 <= 1'b0;
		resetn_async1 <= 1'b0; 
		resetn_async  <= 1'b0; 
	end  
	else begin
		resetn_async0 <= reset_n;
		resetn_async1 <= resetn_async0;
		resetn_async  <= resetn_async1;
	end
end

always @(posedge clk) begin
	ddr_init_done_d0 <= ddr_init_done;
	ddr_init_done_d1 <= ddr_init_done_d0;
	ddr_init_done_en <= ddr_init_done_d1;
end

always@(posedge clk) begin
	user_rd_req_d0 <= user_rd_req;
	user_rd_req_d1 <= user_rd_req_d0;
end

always @(posedge clk) begin
	if(ddr_init_done_en)
		rd_req_trig <= rd_req_rise;
	else
		rd_req_trig <= 1'b0;
end

always@(posedge clk) begin
	if(rd_req_rise) begin
		user_rd_addr_d <= user_rd_addr;
		user_rd_length_d <= user_rd_length;
	end
	else begin
		user_rd_addr_d <= user_rd_addr_d;
		user_rd_length_d <= user_rd_length_d;
	end 
end

always @(posedge clk or negedge resetn_async) begin
	if(~resetn_async)
		rd_req_en <= 1'b0;
	else if(rd_req_en && rd_buffer_ready)
		rd_req_en <= 1'b0;
	else if(state == REQ)
		rd_req_en <= 1'b1;
	else
		rd_req_en <= rd_req_en;
end
// user_addr
always @(posedge clk or negedge resetn_async) begin
	if(~resetn_async)
		rd_addr_out <= user_rd_base_addr;
	else if(rd_req_trig && user_rd_mode)
		rd_addr_out <= user_rd_addr_d;
	else if(rd_req_en && rd_buffer_ready && rd_addr_out >= user_rd_end_addr - AXI_BURST_LEN && ~user_rd_mode)
		 rd_addr_out <= user_rd_base_addr;
	else if(rd_req_en && rd_buffer_ready && ~user_rd_mode)
		rd_addr_out <= rd_addr_out + AXI_BURST_LEN;
end

always@(posedge clk or negedge resetn_async) begin
	if(~resetn_async)
		rd_burst_length <= 'd0;
	else if(~user_rd_mode)
		rd_burst_length <= AXI_BURST_CNT -1;
	else if(rd_req_trig && user_rd_mode)
		rd_burst_length <= user_rd_length_d /(AXI_DATA_WIDTH /8)-1;
	else
		rd_burst_length <= rd_burst_length;
end


// fsm
always @(posedge clk or negedge resetn_async) begin
	if(~resetn_async)
		state <= IDLE;
	else 
		state <= next_state;
end 
always @(*) begin
	case(state)
		IDLE : next_state <= (rd_req_trig)? REQ : IDLE;
		REQ  : next_state <= (rd_req_en && rd_buffer_ready)? END : REQ;
		END  : next_state <= IDLE;
		default : next_state <= state;
	endcase
end
//============================= output =================================//
assign user_rd_busy = state != IDLE;
assign rd_req_rise = user_rd_req_d0 && ~user_rd_req_d1;
// assign rd_burst_length = AXI_BURST_CNT - 1;

endmodule