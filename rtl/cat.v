/**************************************************************************\ 
module name : AMDA : cat
author		: Yuzhe Li 
FPGA		: Xilinx A7_100-T
DATE		: DEC 9,2024

modify		:
\*************************************************************************/
`timescale 1ns/1ps
module cat#(
	parameter AXI_ADDR_WIDTH = 32,
	parameter AXI_DATA_WIDTH = 64
)(
	// clk & rst
	input								clk				,
	input								aclk			, 
	input								resetn			,
	input								ddr_init_done	,
	// user_cfg
	input	[AXI_ADDR_WIDTH +12-1:0]	user_wr_cmd		,
	input								user_cmd_wen	,
	input								user_wr_en		,
	input	[AXI_DATA_WIDTH -1:0]		user_wr_data	,
	// to adma
	output	wire						cat_wr_en		, // fifo_dout_data_vld
	output	reg [AXI_DATA_WIDTH -1:0] 	cat_wr_data		,
	output	reg 						cat_data_last	,	
	output	reg	[AXI_ADDR_WIDTH -1:0]	cat_addr_out	,
	output	wire [12:0]					cat_length		,
	output 	reg							wbuffer_busy	
	);

	reg [AXI_ADDR_WIDTH -1:0] user_wr_base_addr 	;
	reg [12:0]				  user_wr_data_length 	;
	reg [8:0]				  package_cnt 			;
	reg [2:0]				  intr_cnt				; // 拆包计数，到零间隔拉高cat_vld
	reg						  user_data_last		;
	reg [12:0]				  cat_cnt				; // 剩余包计数，last && 剩余包0,拉低fifo读使能
	// fifo signal
	reg 	 	fifo_ren		;
	wire 		fifo_rempty 	;
	wire		fifo_wfull		;
	wire [64:0] fifo_din		;
	wire [64:0]	fifo_dout 		;	
	wire [12:0] fifo_data_count ;
// wr
	// cmd
	always@(posedge clk or negedge resetn) begin
		if(~resetn) begin
			user_wr_base_addr   <= 'd0 ;
			user_wr_data_length <= 'd0 ;
		end
		else if(user_cmd_wen) begin
			user_wr_base_addr 	<= user_wr_cmd[AXI_ADDR_WIDTH -1:0]; 
			user_wr_data_length <= user_wr_cmd[AXI_ADDR_WIDTH +12-1 : AXI_ADDR_WIDTH];
		end // hold
	end
	
	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			cat_addr_out <= 'd0;
		else if(fifo_ren && cat_data_last)
			cat_addr_out <= cat_addr_out + 'd2048;
		else if(~fifo_rempty)
			cat_addr_out <= user_wr_base_addr;
		else
			cat_addr_out <= cat_addr_out;
	end

	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			cat_cnt <= 'd0;
		else if(cat_cnt <= 'd0)
			cat_cnt <= 'd0;
		else if(fifo_ren && cat_data_last)
			cat_cnt <= cat_cnt - 'd1;
		else if(~fifo_rempty)
			cat_cnt <= user_wr_data_length / 256 - 1;
		else
			cat_cnt <= cat_cnt;
	end
	
	// data
	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			package_cnt <= 'd0;
		else if(package_cnt == 'd255 && user_wr_en)
			package_cnt <= 'd0;
		else if(user_wr_en)
			package_cnt <= package_cnt + 'd1;
		else
			package_cnt <= package_cnt ;
	end

	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			user_data_last <= 1'b0;
		else if(user_wr_en && package_cnt == 'd255)
			user_data_last <= 1'b1;
		else
			user_data_last <= 1'b0;
	end

	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			intr_cnt <= 'd0;
		else if(~fifo_rempty && cat_data_last && intr_cnt == 'd3)
			intr_cnt <= 'd0;
		else if(~fifo_rempty && cat_data_last)
			intr_cnt <= intr_cnt + 'd1;
		else if(fifo_rempty)
			intr_cnt <= 'd0;
		else
			intr_cnt <= intr_cnt;
	end

	always@(posedge clk or negedge resetn) begin
		if(~resetn)
			fifo_ren <= 1'b0;
		else if(fifo_rempty)
			fifo_ren <= 1'b0;
		else if(~fifo_rempty && cat_data_last && (intr_cnt == 'd3 || cat_cnt == 'd0))
			fifo_ren <= 1'b0;
		else if(~fifo_rempty && intr_cnt == 'd0)
			fifo_ren <= 1'b1;
		else
			fifo_ren <= fifo_ren ;
	end
	// dout
	always@(posedge clk or negedge resetn) begin
		if(~resetn) begin
			cat_wr_data 	<= 'd0;
			cat_data_last 	<= 1'b0;
		end
		else begin
			cat_wr_data		<= fifo_dout[AXI_DATA_WIDTH -1:0];
			cat_data_last	<= fifo_dout[64];
		end
	end


assign fifo_din = {user_data_last , user_wr_data};
assign cat_length = 13'hff;
assign cat_wr_en = fifo_ren;

always@(posedge clk or negedge resetn) begin
	if(~resetn)
		wbuffer_busy <= 1'b0;
	else if(fifo_data_count > 'd4000)
		wbuffer_busy <= 1'b1;
	else
		wbuffer_busy <= 1'b0;
end


fifo_w65xd4096 cat_fifo (
  .clk			(clk 				),                // input wire clk
  .srst			(~resetn 			),              // input wire srst
  .din 			(fifo_din 			),                // input wire [64 : 0] din
  .wr_en 		(user_wr_en 		),            // input wire wr_en
  .rd_en 		(fifo_ren			),            // input wire rd_en
  .dout 		(fifo_dout 			),              // output wire [64 : 0] dout
  .full 		(fifo_wfull 		),              // output wire full
  .empty 		(fifo_rempty		),            // output wire empty
  .data_count 	(fifo_data_count 	)  // output wire [12 : 0] data_count
);
endmodule