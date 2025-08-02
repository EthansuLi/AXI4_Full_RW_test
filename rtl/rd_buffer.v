/**************************************************************************\ 
module name : ADMA : rd_buffer
author		: Yuzhe Li
affiliation	: SEU
FPGA		: Xilinx A7_100-T
DATE		: 11 ,2024

modify		:
\*************************************************************************/
`timescale 1ns/1ns

module rd_buffer #(
	parameter	AXI_DATA_WIDTH 	= 128	,
	parameter	AXI_ADDR_WIDTH 	= 32	,
	parameter	USER_DATA_WIDTH = 64
)(
// clk & reset 
	input							 	clk					,
	input							 	aclk				,	// axi_clk
	input							 	reset_n				,
// from USER's rd_ctrl
	input							 	rd_req_en			,
	output	reg							rd_buffer_cmd_ready	,
	input		[AXI_ADDR_WIDTH	-1:0]	rd_addr_in			,
	input		[7:0]					rd_burst_length		, // 突发字节数
// communicate with rd_master
	output	reg	[AXI_ADDR_WIDTH -1:0]	axi_ar_addr			,
	output	reg	[7:0]					axi_ar_burst_len	,
	output	reg							axi_ar_req_en		,
	input								axi_ar_ready		,

	input								axi_r_valid			,
	input		[AXI_DATA_WIDTH -1:0]	axi_r_data			,
	input								axi_r_last			,
// User data out
	output	reg							user_rd_valid		,
	output	reg	[USER_DATA_WIDTH -1:0]	user_rd_data		,
	output	reg							user_rd_last		,
// err dcc
	output	reg							rd_cmd_fifo_err		,
	output	reg							rd_data_fifo_err			
);
//============================ parameter ===============================//
// fsm
localparam	IDLE 		= 4'b0001;
localparam	RD_REQ 		= 4'b0010;
localparam	RD_DATA_EN 	= 4'b0100;
localparam	RD_DATA_END = 4'b1000;

// p2s && s2p
localparam  RD_DW_SPCNT = AXI_DATA_WIDTH / USER_DATA_WIDTH	;
//=========================== reg && wire ==============================//
// async
(* dont_touch ="true" *)reg		resetn_d0	;
(* dont_touch ="true" *)reg		resetn_d1	;
(* dont_touch ="true" *)reg		resetn      ;

(* dont_touch ="true" *)reg		aresetn_d0	;
(* dont_touch ="true" *)reg		aresetn_d1	;
(* dont_touch ="true" *)reg		aresetn   	;
// fsm
reg [3:0] state;
reg [3:0] next_state ;
// VIP signal
wire rd_data_buf_ready; // 数据fifo满了，禁止发送写cmd->状态禁止跳转到 RD_CMD
reg data_buf_wready ; // axi写入读数据准备信号
// cmd fifo ctrl
reg				cmd_fifo_wen 	;
reg	 [39:0]		cmd_fifo_din	;
wire			cmd_fifo_ren	;
wire [39:0]		cmd_fifo_dout	;
wire			cmd_fifo_wfull	;
wire			cmd_fifo_rempty	;
wire [4:0]		cmd_fifo_wcnt	;
wire [4:0]      cmd_fifo_rcnt	;

// data fifo ctrl
reg 		 data_fifo_wen		;
wire		 data_fifo_ren		;
wire         data_fifo_wfull	;
wire		 data_fifo_rempty	;
reg			 rd_data_fifo_last	;
// user_s2p
reg 		rd_data_flag;
reg [$clog2(RD_DW_SPCNT) -1:0] 	rd_sp_cnt	;
reg	[AXI_DATA_WIDTH - 1:0] data_fifo_sp_dout; // 移位中转寄存器
//============================ time sequ ===============================//
// async
always @(posedge clk or negedge reset_n) begin
	if(~reset_n) begin
		resetn_d0 <= 1'b0;
		resetn_d1 <= 1'b0;
		resetn    <= 1'b0;
	end
	else begin
		resetn_d0 <= reset_n;
		resetn_d1 <= resetn_d0;
		resetn    <= resetn_d1;
	end
end
always @(posedge aclk or negedge reset_n) begin
	if(~reset_n) begin
		aresetn_d0 <= 1'b0;
		aresetn_d1 <= 1'b0;
		aresetn    <= 1'b0;
	end
	else begin
		aresetn_d0 <= reset_n;
		aresetn_d1 <= resetn_d0;
		aresetn    <= resetn_d1;
	end
end

always @(posedge clk or negedge resetn) begin
	if(~resetn)
		rd_buffer_cmd_ready <= 1'b0;
	else if(cmd_fifo_wcnt <= 'd12)
		rd_buffer_cmd_ready <= 1'b1;
	else
		rd_buffer_cmd_ready <= 1'b0;
end
// cmd_ctrl
always @(posedge clk or negedge resetn) begin
	if(~resetn) begin
		cmd_fifo_wen <= 1'b0;
		cmd_fifo_din <= 'd0;
	end
	else if(rd_req_en && rd_buffer_cmd_ready) begin
		cmd_fifo_wen <= 1'b1;
		cmd_fifo_din <= {rd_burst_length, rd_addr_in};
	end
	else begin
		cmd_fifo_wen <= 1'b0;
		cmd_fifo_din <= cmd_fifo_din;
	end
end

assign cmd_fifo_ren = axi_ar_req_en && axi_ar_ready;	// fwft: cmd dout
// axi
always @(posedge aclk or negedge aresetn) begin
	if(~aresetn)
		axi_ar_req_en <= 1'b0;
	else if(axi_ar_req_en && axi_ar_ready)
		axi_ar_req_en <= 1'b0;
	else if(state == RD_REQ)
		axi_ar_req_en <= 1'b1;
	else
		axi_ar_req_en <= axi_ar_req_en;
end

always @(*) begin
	if(~aresetn) begin
		axi_ar_addr 	 = 'd0;
		axi_ar_burst_len = 'd0;
	end
	else begin
		axi_ar_addr		 = cmd_fifo_dout[AXI_ADDR_WIDTH -1:0];
		axi_ar_burst_len = cmd_fifo_dout[39:32];
	end
end

// data ctrl


//=============================== fsm ==================================//
always @(posedge aclk or negedge aresetn) begin
	if(~aresetn)
		state <= IDLE;
	else
		state <= next_state;
end

always @(*) begin
	case(state)
		IDLE 		:	next_state <= (rd_buffer_cmd_ready && ~cmd_fifo_rempty)? RD_REQ : IDLE;
		RD_REQ 		:	next_state <= (axi_ar_req_en && axi_ar_ready)? RD_DATA_EN : RD_REQ;
		RD_DATA_EN 	:	next_state <= (axi_r_valid && axi_r_last)? RD_DATA_EN : RD_DATA_END;
		RD_DATA_END :	next_state <= IDLE;
		default : next_state <= state;
	endcase
end

//============================== assign  ================================//
assign data_fifo_ren = (~data_fifo_rempty) && (~rd_data_flag); 


//============================= instance ===============================//

fifo_w40xd16 cmd_fifo (
  .rst 				(~resetn 		),  // input wire rst
  .wr_clk 			(clk 			),  // input wire wr_clk
  .rd_clk 			(aclk 			),  // input wire rd_clk
  .din 				(cmd_fifo_din 	),  // input wire [39 : 0] din
  .wr_en 			(cmd_fifo_wen 	),  // input wire wr_en
  .rd_en  			(cmd_fifo_ren 	),  // input wire rd_en
  .dout 			(cmd_fifo_dout 	),  // output wire [39 : 0] dout
  .full 			(cmd_fifo_wfull ),  // output wire full
  .empty 			(cmd_fifo_rempty),  // output wire empty
  .rd_data_count	(cmd_fifo_wcnt 	),  // output wire [4 : 0] rd_data_count
  .wr_data_count 	(cmd_fifo_rcnt	)   // output wire [4 : 0] wr_data_count
);
//======================= generate ... if ... ==========================//
generate
if (AXI_DATA_WIDTH == 128) 
begin
	
	reg [143:0] data_fifo_din		;
	wire [143:0] data_fifo_dout		;
	wire [9:0]   data_fifo_wcnt		;
	wire [9:0]   data_fifo_rcnt		;
	
	always@(posedge aclk or negedge aresetn) begin
		if(~aresetn) begin
			data_fifo_wen <= 1'b0;
			data_fifo_din <= 'd0;
		end
		else begin
			data_fifo_wen <= axi_r_valid;
			data_fifo_din <= {15'h0, axi_r_last, axi_r_data};
		end
	end
	
	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			data_fifo_sp_dout <= 'd0;
		else if(data_fifo_ren)
			data_fifo_sp_dout <= data_fifo_dout[127:0];
		else if(rd_data_flag)
			data_fifo_sp_dout <= data_fifo_sp_dout >> USER_DATA_WIDTH ;
		else
			data_fifo_sp_dout <= data_fifo_sp_dout;
	end
	
	// 移位结束再拉低 fifo读出的axi_r_last , 便于拉低user_rd_last
	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			rd_data_fifo_last <= 1'b0;
		else if(rd_data_flag && rd_sp_cnt == RD_DW_SPCNT -1)
			rd_data_fifo_last <= 1'b0;
		else if(data_fifo_ren && data_fifo_dout[128])
			rd_data_fifo_last <= 1'b1;
		else
			rd_data_fifo_last <= rd_data_fifo_last;
	end
	
	always@(posedge aclk or negedge aresetn) begin
		if(~aresetn)
			data_buf_wready <= 1'b0;
		else if(data_fifo_wcnt <= 'd256)
			data_buf_wready <= 1'b1;
		else
			data_buf_wready <= 1'b0;
	end
	
	fifo_w144xd512 data_fifo (
	  .rst 				(~aresetn 			),  // input wire rst
	  .wr_clk 			(aclk 				),  // input wire wr_clk
	  .rd_clk 			(clk 				),  // input wire rd_clk
	  .din 				(data_fifo_din 		),  // input wire [143 : 0] din
	  .wr_en 			(data_fifo_wen 		),  // input wire wr_en
	  .rd_en  			(data_fifo_ren 		),  // input wire rd_en
	  .dout 			(data_fifo_dout 	),  // output wire [39 : 0] dout
	  .full 			(data_fifo_wfull 	),  // output wire full
	  .empty 			(data_fifo_rempty 	),  // output wire empty
	  .rd_data_count	(data_fifo_wcnt 	),  // output wire [9 : 0] rd_data_count
	  .wr_data_count 	(data_fifo_rcnt		)   // output wire [9 : 0] wr_data_count
	);

end
else if(AXI_DATA_WIDTH == 256) 
begin
	
	reg [287:0] data_fifo_din		;
	wire [287:0] data_fifo_dout		;
	wire [9:0]   data_fifo_wcnt		;
	wire [9:0]   data_fifo_rcnt		;
	
	always@(posedge aclk or negedge aresetn) begin
		if(~aresetn) begin
			data_fifo_wen <= 1'b0;
			data_fifo_din <= 'd0;
		end
		else begin
			data_fifo_wen <= axi_r_valid;
			data_fifo_din <= {31'h0, axi_r_last, axi_r_data};
		end
	end
	
	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			data_fifo_sp_dout <= 'd0;
		else if(data_fifo_ren)
			data_fifo_sp_dout <= data_fifo_dout[255:0];
		else if(rd_data_flag)
			data_fifo_sp_dout <= data_fifo_sp_dout >> USER_DATA_WIDTH ;
		else
			data_fifo_sp_dout <= data_fifo_sp_dout;
	end
	
	// 移位结束再拉低 fifo读出的axi_r_last , 便于拉低user_rd_last
	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			rd_data_fifo_last <= 1'b0;
		else if(rd_data_flag && rd_sp_cnt == RD_DW_SPCNT -1)
			rd_data_fifo_last <= 1'b0;
		else if(data_fifo_ren && data_fifo_dout[256])
			rd_data_fifo_last <= 1'b1;
		else
			rd_data_fifo_last <= rd_data_fifo_last;
	end
	
	always@(posedge aclk or negedge aresetn) begin
		if(~aresetn)
			data_buf_wready <= 1'b0;
		else if(data_fifo_wcnt <= 'd384)
			data_buf_wready <= 1'b1;
		else
			data_buf_wready <= 1'b0;
	end
	
	fifo_w288xd512 data_fifo (
	  .rst 				(~aresetn 			),  // input wire rst
	  .wr_clk 			(aclk 				),  // input wire wr_clk
	  .rd_clk 			(clk 				),  // input wire rd_clk
	  .din 				(data_fifo_din 		),  // input wire [287 : 0] din
	  .wr_en 			(data_fifo_wen 		),  // input wire wr_en
	  .rd_en  			(data_fifo_ren 		),  // input wire rd_en
	  .dout 			(data_fifo_dout 	),  // output wire [287 : 0] dout
	  .full 			(data_fifo_wfull 	),  // output wire full
	  .empty 			(data_fifo_rempty 	),  // output wire empty
	  .rd_data_count	(data_fifo_wcnt 	),  // output wire [9 : 0] rd_data_count
	  .wr_data_count 	(data_fifo_rcnt		)   // output wire [9 : 0] wr_data_count
	);
end
else if(AXI_DATA_WIDTH == 64) 
begin
	
	reg [71:0] data_fifo_din		;
	wire [71:0] data_fifo_dout		;
	wire [9:0]   data_fifo_wcnt		;
	wire [9:0]   data_fifo_rcnt		;
	
	always@(posedge aclk or negedge aresetn) begin
		if(~aresetn) begin
			data_fifo_wen <= 1'b0;
			data_fifo_din <= 'd0;
		end
		else begin
			data_fifo_wen <= axi_r_valid;
			data_fifo_din <= {7'h0, axi_r_last, axi_r_data};
		end
	end
	
	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			data_fifo_sp_dout <= 'd0;
		else if(data_fifo_ren)
			data_fifo_sp_dout <= data_fifo_dout[63:0];
		else if(rd_data_flag)
			data_fifo_sp_dout <= data_fifo_sp_dout >> USER_DATA_WIDTH ;
		else
			data_fifo_sp_dout <= data_fifo_sp_dout;
	end
	
	// 移位结束再拉低 fifo读出的axi_r_last , 便于拉低user_rd_last
	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			rd_data_fifo_last <= 1'b0;
		else if(rd_data_flag && rd_sp_cnt == RD_DW_SPCNT -1)
			rd_data_fifo_last <= 1'b0;
		else if(data_fifo_ren && data_fifo_dout[64])
			rd_data_fifo_last <= 1'b1;
		else
			rd_data_fifo_last <= rd_data_fifo_last;
	end
	
	always@(posedge aclk or negedge aresetn) begin
		if(~aresetn)
			data_buf_wready <= 1'b0;
		else if(data_fifo_wcnt <= 'd256)
			data_buf_wready <= 1'b1;
		else
			data_buf_wready <= 1'b0;
	end
	
	fifo_w72xd512 data_fifo (
	  .rst 				(~aresetn 			),  // input wire rst
	  .wr_clk 			(aclk 				),  // input wire wr_clk
	  .rd_clk 			(clk 				),  // input wire rd_clk
	  .din 				(data_fifo_din 		),  // input wire [71: 0] din
	  .wr_en 			(data_fifo_wen 		),  // input wire wr_en
	  .rd_en  			(data_fifo_ren 		),  // input wire rd_en
	  .dout 			(data_fifo_dout 	),  // output wire [71 : 0] dout
	  .full 			(data_fifo_wfull 	),  // output wire full
	  .empty 			(data_fifo_rempty 	),  // output wire empty
	  .rd_data_count	(data_fifo_wcnt 	),  // output wire [9 : 0] rd_data_count
	  .wr_data_count 	(data_fifo_rcnt		)   // output wire [9 : 0] wr_data_count
	);
end
	
endgenerate

// user s2p
always@(posedge clk or negedge resetn) begin
	if(~resetn)
		rd_sp_cnt <= 'd0;
	else if(rd_data_flag && rd_sp_cnt == RD_DW_SPCNT - 1)
		rd_sp_cnt <= 'd0;
	else if(rd_data_flag)
		rd_sp_cnt <= rd_sp_cnt + 'd1;
	else
		rd_sp_cnt <= rd_sp_cnt;
end

always@(posedge clk or negedge resetn) begin
	if(~resetn)
		rd_data_flag <= 1'b0;
	else if(rd_data_flag && rd_sp_cnt == RD_DW_SPCNT -1)
		rd_data_flag <= 1'b0;
	else if(data_fifo_ren)
		rd_data_flag <= 1'b1;
	else
		rd_data_flag <= rd_data_flag;
end
// data/valid && last
always@(posedge clk or negedge resetn)
begin
	if(~resetn)
		user_rd_valid <= 1'b0;
	else if(rd_data_flag)
		user_rd_valid <= 1'b1;
	else
		user_rd_valid <= 1'b0;
end

always@(posedge clk or negedge resetn)
begin
	if(~resetn)
		user_rd_data <= 'd0;
	else if(rd_data_flag)
		user_rd_data <= data_fifo_sp_dout[USER_DATA_WIDTH -1:0];
	else
		user_rd_data <= 'd0;
end

always @(posedge clk or negedge resetn) 
begin 
	if(~resetn)
		user_rd_last <= 1'b0;
	else if(rd_data_fifo_last && rd_sp_cnt == RD_DW_SPCNT -1)
		user_rd_last <= 1'b1;
	else
		user_rd_last <= 1'b0;
end

// err
	always @(posedge aclk or negedge aresetn) begin
		if(~aresetn)
			rd_cmd_fifo_err <= 1'b0;
		else if(cmd_fifo_wfull && cmd_fifo_wen)
			rd_cmd_fifo_err <= 1'b1;
		else
			rd_cmd_fifo_err <= 1'b0;
	end
	always @(posedge aclk or negedge aresetn) begin
		if(~aresetn)
			rd_data_fifo_err <= 1'b0;
		else if(data_fifo_wfull && data_fifo_wen)
			rd_data_fifo_err <= 1'b1;
		else
			rd_data_fifo_err <= 1'b0;
	end

endmodule