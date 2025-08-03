/**************************************************************************\ 
module name : AMDA : wr_ctrl
author		: Yuzhe Li
DATE		: AUG 4,2024

modify		:
\*************************************************************************/

`timescale 1ns/1ns
module wr_ctrl #(
	parameter	USER_DATA_WIDTH 	=	16	,
	parameter	AXI_ADDR_WIDTH		=	32	,
	parameter	AXI_DATA_WIDTH		=	128 ,
	parameter	AXI_BURST_LEN		=   4096
)(
	// clk & reset
	input								clk				,	// user wr clk
	input								resetn			,
	
	input								ddr_init_done	,
	// from user
	input								user_wr_mode	,
	input								user_wr_en		,
	input								user_wr_last	,
	input		[USER_DATA_WIDTH -1:0]	user_wr_data	,
	input		[AXI_ADDR_WIDTH -1:0]	user_wr_addr	,
	input		[12:0]					user_wr_length	, // 4096 -> 12bit
	input		[AXI_ADDR_WIDTH -1:0]	user_base_addr	,
	input       [AXI_ADDR_WIDTH -1:0]	user_end_addr	,
	// communicate with buffer
	output	reg	[AXI_DATA_WIDTH -1:0]	wr_data_out		,
	output	reg							wr_data_valid	,
	output	reg							wr_data_last	,
	output	reg							wr_req_en		,
	output	reg	[AXI_ADDR_WIDTH -1:0]	wr_addr_out		,
	output	reg	[7:0]					wr_burst_len	// axi总线上的突发数据个数/包长
);

/********************************************************************\ 
							parameter
\********************************************************************/
	localparam	MAX_WR_CNT = AXI_DATA_WIDTH / USER_DATA_WIDTH;
	localparam  AXI_BURST_CNT = AXI_BURST_LEN / (AXI_DATA_WIDTH / 8);
/********************************************************************\ 
							reg
\********************************************************************/
	// sync (* dont_touch ="true" *)
	(* dont_touch ="true" *)reg	resetn_d0;
	(* dont_touch ="true" *)reg	resetn_d1;
	(* dont_touch ="true" *)reg	resetn_sync;
	
	reg	ddr_init_done_d0;
	reg ddr_init_done_d1;
	reg ddr_init_done_en;
	
	reg	[USER_DATA_WIDTH -1:0] user_wr_data_d;
	reg						  user_wr_en_d  ;
	reg	[AXI_ADDR_WIDTH -1:0] user_wr_addr_d;
	reg	[12:0]				  user_wr_length_d;
	reg						  user_wr_last_d;					
	// data cnt
	reg [$clog2(MAX_WR_CNT)-1 : 0] wr_cnt;
	reg	[7 : 0] burst_cnt;

/********************************************************************\ 
							timeseq
\********************************************************************/
	// sync
	always @(posedge clk) begin
		resetn_d0 	<= resetn	;
		resetn_d1 	<= resetn_d0;
		resetn_sync <= resetn_d1;
	end
	always @(posedge clk) begin
		ddr_init_done_d0 <= ddr_init_done;
		ddr_init_done_d1 <= ddr_init_done_d0;
		ddr_init_done_en <= ddr_init_done_d1;
	end
	
	always @(posedge clk) begin
		if(ddr_init_done_en) begin
			user_wr_en_d 		<= user_wr_en 		;
			user_wr_data_d 		<= user_wr_data 	;
			user_wr_last_d 		<= user_wr_last 	;
			user_wr_addr_d 		<= user_wr_addr 	;
			user_wr_length_d 	<= user_wr_length 	;
		end
		else begin
			user_wr_en_d 		<= user_wr_en_d 	;
			user_wr_data_d 		<= user_wr_data_d	;
			user_wr_last_d 		<= user_wr_last_d	;
			user_wr_addr_d 		<= user_wr_addr_d	;
			user_wr_length_d 	<= user_wr_length_d	;
		end
	end
	// cmd

	// data cnt
	always @(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			wr_cnt <= 'd0;
		else if(user_wr_last_d && user_wr_mode)
			wr_cnt <= 'd0;
		else if(user_wr_en_d && wr_cnt == MAX_WR_CNT - 1)
			wr_cnt <= 'd0;
		else if(user_wr_en_d)
			wr_cnt <= wr_cnt + 'd1;
		else
			wr_cnt <= wr_cnt;
	end
	
	always @(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			burst_cnt <= 'd0;
		else if(user_wr_last_d && user_wr_mode)
			burst_cnt <= 'd0;
		else if(user_wr_en_d && burst_cnt == AXI_BURST_CNT - 1 && wr_cnt == MAX_WR_CNT - 1)
			burst_cnt <= 'd0;
		else if(user_wr_en_d && wr_cnt == MAX_WR_CNT - 1)
			burst_cnt <= burst_cnt + 'd1;
		else
			burst_cnt <= burst_cnt;
	end
	// output
	always @(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			wr_data_valid <= 1'b0;
		else if(user_wr_en_d && wr_cnt == MAX_WR_CNT - 1)
			wr_data_valid <= 1'b1;
		else
			wr_data_valid <= 1'b0;
	end
	always @(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			wr_data_out <= 'd0;
		else if(user_wr_en_d) begin
			if(AXI_DATA_WIDTH != USER_DATA_WIDTH)
				wr_data_out <= {user_wr_data_d, wr_data_out[AXI_DATA_WIDTH -1 : USER_DATA_WIDTH]};
			else
				wr_data_out <= user_wr_data_d;
		end
	end
	always @(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			wr_data_valid <= 1'b0;
		else if(user_wr_en_d && wr_cnt == MAX_WR_CNT - 1)
			wr_data_valid <= 1'b1;
		else
			wr_data_valid <= 1'b0;
	end
	always @(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			wr_data_last <= 1'b0;
		else if(user_wr_last_d && user_wr_mode)
			wr_data_last <= 1'b1;
		else if(user_wr_en_d && wr_cnt == MAX_WR_CNT - 1 && burst_cnt ==  AXI_BURST_CNT - 1 && ~user_wr_mode)
			wr_data_last <= 1'b1;
		else
			wr_data_last <= 1'b0;
	end
	// addr
	always @(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			wr_addr_out <= user_base_addr;
		else if(user_wr_last_d && user_wr_mode)
			wr_addr_out <= user_wr_addr_d;
		else if(wr_req_en && wr_addr_out >= user_end_addr - AXI_BURST_LEN && ~user_wr_mode)
			wr_addr_out <= user_base_addr;
		else if(wr_req_en && ~user_wr_mode)
			wr_addr_out <= wr_addr_out + AXI_BURST_LEN;
	end

	always@(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			wr_req_en <= 1'b0;
		else if(wr_cnt == MAX_WR_CNT -1 && burst_cnt == AXI_BURST_CNT -1 && user_wr_en_d && ~user_wr_mode)
			wr_req_en <= 1'b1;
		else if(user_wr_last_d && user_wr_mode)
			wr_req_en <= 1'b1;
		else
			wr_req_en <= 1'b0;
	end

	always@(posedge clk or negedge resetn_sync) begin
		if(~resetn_sync)
			wr_burst_len <= 'd0;
		else if(~user_wr_mode)
			wr_burst_len <= AXI_BURST_CNT -1;
		else if(user_wr_mode && user_wr_en_d)
			wr_burst_len <= user_wr_length_d / (AXI_DATA_WIDTH /8)-1;
		else
			wr_burst_len <= wr_burst_len;
	end
/********************************************************************\ 
							assign
\********************************************************************/
	// assign wr_req_en 	= wr_data_last;
	// assign wr_burst_len = AXI_BURST_CNT - 1;
endmodule

