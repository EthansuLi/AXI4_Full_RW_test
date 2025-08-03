/**************************************************************************\ 
module name : ADMA : wr_buffer
author		: Yuzhe Li ||  
affiliation	: 

DATE		: Jul 7,2024

modify		:
\*************************************************************************/
`timescale 1ns/1ns
module wr_buffer#(
	parameter	AXI_ADDR_WIDTH = 32	,
	parameter	AXI_DATA_WIDTH = 128
)(
	// clk & reset
	input								wr_clk			,
	input								axi_clk			,
	input								resetn			,
	// from wr ctrl
	input		[AXI_DATA_WIDTH-1:0]	wr_data_in		,
	input								wr_data_valid	,
	input								wr_data_last	,
	input								wr_req_en		, // cmd_wr_en
	input		[AXI_ADDR_WIDTH-1:0]	wr_addr_in		,
	input		[7:0]					wr_burst_len	,
	// communicate with wr master
	output	reg							axi_aw_req_en	,
	input								axi_aw_ready	,
	output	reg	[AXI_ADDR_WIDTH-1:0]	axi_aw_addr		,
	output	reg	[7:0]					axi_aw_burst_len,
	output	reg							axi_w_valid		,
	input								axi_w_ready		,
	output	reg	[AXI_DATA_WIDTH-1:0]	axi_w_data		,
	output	reg							axi_w_last		,
	// err 
	output	reg							err_wcmd_fifo	,
	output	reg							err_wdata_fifo
);
/********************************************************************\ 
								parameter
\********************************************************************/
	// fsm
	localparam	WR_IDLE		= 4'b0001	;
	localparam	WR_REQ 		= 4'b0010	;
	localparam	WR_DATA_EN	= 4'b0100	;
	localparam	WR_END		= 4'b1000	;
/********************************************************************\ 
								reg
\********************************************************************/	
	// sync (* dont_touch ="true" *)
	(* dont_touch ="true" *)reg	resetn_d0;
	(* dont_touch ="true" *)reg	resetn_d1;
	(* dont_touch ="true" *)reg	rstn_sync;
	(* dont_touch ="true" *)reg	a_resetn_d0;
	(* dont_touch ="true" *)reg	a_resetn_d1;
	(* dont_touch ="true" *)reg	a_rstn_sync;
	// fsm
	reg [3:0] state		;
	reg [3:0] next_state;
	// cmd fifo
	reg			cmd_wr_en	;
	reg	[39:0]	cmd_din		;	
	// data_fifo
	reg			data_wr_en;
	
/********************************************************************\ 
								wire
\********************************************************************/	
	// cmd fifo
	wire		cmd_rd_en		;
	wire [39:0] cmd_dout 		;
	wire		cmd_full		;	
	wire		cmd_rempty		;	
	wire [3:0]	rd_cmd_count	;	
	wire [3:0]	wr_cmd_count	;	
	// data fifo
	wire		data_rd_en	    ;
	wire		data_full		;
	wire		data_rempty	    ;
	wire [9:0]	rd_data_count   ;
	wire [9:0]	wr_data_count   ;
	
/********************************************************************\ 
								timeseq
\********************************************************************/
	// sync
	always @(posedge wr_clk) begin
		resetn_d0 	<= resetn	;
		resetn_d1 	<= resetn_d0;
		rstn_sync   <= resetn_d1;
	end
	always @(posedge axi_clk) begin
		a_resetn_d0 	<= resetn	;
		a_resetn_d1 	<= a_resetn_d0;
		a_rstn_sync     <= a_resetn_d1;
	end
	// cmd fifo
	always @(posedge wr_clk or negedge rstn_sync) begin
		if(~rstn_sync) begin
			cmd_wr_en <= 1'b0;
			cmd_din	  <= 'd0;
		end
		else if(wr_req_en) begin
			cmd_wr_en <= 1'b1		;
			cmd_din   <= {wr_burst_len, wr_addr_in};
		end
		else begin
			cmd_wr_en <= 1'b0	;
			cmd_din   <= cmd_din;
		end
	end
	// output
	always @(posedge axi_clk or negedge a_rstn_sync) begin
		if(~a_rstn_sync)
			axi_aw_req_en <= 1'b0;
		else if(axi_aw_req_en && axi_aw_ready)
			axi_aw_req_en <= 1'b0;
		else if(state == WR_REQ)
			axi_aw_req_en <= 1'b1;
		else
			axi_aw_req_en <= axi_aw_req_en;
	end
	// cmd_dout
	always @(*) begin
		if(~a_rstn_sync) begin
			axi_aw_addr 	<= 'd0;
			axi_aw_burst_len<= 'd0;
		end
		else if(cmd_rd_en) begin
			axi_aw_addr 	 <= cmd_dout[31:0];
			axi_aw_burst_len <= cmd_dout[39:32];
		end
		else begin
			axi_aw_addr 	 <= axi_aw_addr 	;
		    axi_aw_burst_len <= axi_aw_burst_len;
		end
	end
	
/********************************************************************\ 
								FSM
\********************************************************************/
	always @(posedge axi_clk or negedge a_rstn_sync) begin
		if(~a_rstn_sync)
			state <= WR_IDLE	;
		else
			state <= next_state	;
	end
	always @(*) begin
		case(state)
			WR_IDLE		:	next_state = (~cmd_rempty)? WR_REQ : WR_IDLE;
			WR_REQ		:	next_state = (axi_aw_req_en && axi_aw_ready)?	WR_DATA_EN : WR_REQ;
			WR_DATA_EN 	:	next_state = (axi_w_valid && axi_w_ready && axi_w_last)?	WR_END : WR_DATA_EN;
			WR_END		:	next_state = WR_IDLE;
			default 	: 	next_state = state;
		endcase
	end
/********************************************************************\ 
								assign
\********************************************************************/
	assign cmd_rd_en = axi_aw_req_en && axi_aw_ready;
	
/********************************************************************\ 
								instance
\********************************************************************/
	fifo_w40xd16 cmd_fifo (
	.rst			(~rstn_sync		),  // input wire rst
	.wr_clk			(wr_clk			),  // input wire wr_clk
	.rd_clk			(axi_clk		),  // input wire rd_clk
	.din			(cmd_din		),  // input wire [39 : 0] din
	.wr_en			(cmd_wr_en		),  // input wire wr_en
	.rd_en			(cmd_rd_en		),  // input wire rd_en
	.dout			(cmd_dout		),  // output wire [39 : 0] dout
	.full			(cmd_full		),  // output wire full
	.empty			(cmd_rempty		),  // output wire empty
	.rd_data_count	(rd_cmd_count	),  // output wire [3 : 0] rd_data_count
	.wr_data_count	(wr_cmd_count	)   // output wire [3 : 0] wr_data_count
);
	
/********************************************************************\ 
								generate ... if ...
\********************************************************************/	
	generate 
		if(AXI_DATA_WIDTH == 128) begin	
			wire [143:0]	data_dout	;	
			reg  [143:0]	data_din	;
			// data_wr_en
			always @(posedge wr_clk or negedge rstn_sync) begin
				if(~rstn_sync) begin
					data_wr_en <= 1'b0;
					data_din   <= 'd0;
				end
				else if(wr_data_valid) begin
					data_wr_en <= 1'b1;
					data_din   <= {{15{1'b0}}, wr_data_last, wr_data_in};
				end
				else begin
					data_wr_en <= 1'b0 ;
				    data_din   <= data_din   ;
				end
			end
			// output
			always @(posedge axi_clk or negedge a_rstn_sync) begin
				if(~a_rstn_sync)
					axi_w_valid <= 1'b0;
				else if(axi_aw_req_en && axi_aw_ready)
					axi_w_valid <= 1'b1;
				else if(axi_w_valid && axi_w_ready && axi_w_last)
					axi_w_valid <= 1'b0;
				else
					axi_w_valid <= axi_w_valid;
			end
			
			always @(*) begin
				if(~a_rstn_sync) begin
					axi_w_data <= 'd0;
					axi_w_last <= 1'b0;
				end
				else if(data_rd_en) begin
					axi_w_data <= data_dout[127:0];
					axi_w_last <= data_dout[128];
				end
				else begin
					axi_w_data <= 'd0;
				    axi_w_last <= 1'b0;
				end
			end
	 
			assign data_rd_en = state == WR_DATA_EN && axi_w_valid && axi_w_ready;
			
	fifo_w144xd512 data_fifo (
	.rst			(~rstn_sync		),  // input wire rst
	.wr_clk			(wr_clk			),  // input wire wr_clk
	.rd_clk			(axi_clk		),  // input wire rd_clk
	.din			(data_din		),  // input wire [144 : 0] din
	.wr_en			(data_wr_en		),  // input wire wr_en
	.rd_en			(data_rd_en		),  // input wire rd_en
	.dout			(data_dout		),  // output wire [144 : 0] dout
	.full			(data_full		),  // output wire full
	.empty			(data_rempty	),  // output wire empty
	.rd_data_count	(rd_data_count	),  // output wire [9 : 0] rd_data_count
	.wr_data_count	(wr_data_count	)   // output wire [9 : 0] wr_data_count
);	
		end
		else if(AXI_DATA_WIDTH == 256) begin
			wire [287:0]	data_dout	;	
			reg  [287:0]	data_din	;
			// data_wr_en
			always @(posedge wr_clk or negedge rstn_sync) begin
				if(~rstn_sync) begin
					data_wr_en <= 1'b0;
					data_din   <= 'd0;
				end
				else if(wr_data_valid) begin
					data_wr_en <= 1'b1;
					data_din   <= {{31{1'b0}}, wr_data_last, wr_data_in};
				end
				else begin
					data_wr_en <= 1'b0 ;
				    data_din   <= data_din   ;
				end
			end
			// output
			always @(posedge axi_clk or negedge a_rstn_sync) begin
				if(~a_rstn_sync)
					axi_w_valid <= 1'b0;
				else if(axi_aw_req_en && axi_aw_ready)
					axi_w_valid <= 1'b1;
				else if(axi_w_valid && axi_w_ready && axi_w_last)
					axi_w_valid <= 1'b0;
				else
					axi_w_valid <= axi_w_valid;
			end
			
			always @(*) begin
				if(~a_rstn_sync) begin
					axi_w_data <= 'd0;
					axi_w_last <= 1'b0;
				end
				else if(data_rd_en) begin
					axi_w_data <= data_dout[255:0];
					axi_w_last <= data_dout[256];
				end
				else begin
					axi_w_data <= 'd0;
				    axi_w_last <= 1'b0;
				end
			end
	 
			assign data_rd_en = state == WR_DATA_EN && axi_w_valid && axi_w_ready;
			
	fifo_w288xd512 data_fifo (
	.rst			(~rstn_sync		),  // input wire rst
	.wr_clk			(wr_clk			),  // input wire wr_clk
	.rd_clk			(axi_clk		),  // input wire rd_clk
	.din			(data_din		),  // input wire [144 : 0] din
	.wr_en			(data_wr_en		),  // input wire wr_en
	.rd_en			(data_rd_en		),  // input wire rd_en
	.dout			(data_dout		),  // output wire [144 : 0] dout
	.full			(data_full		),  // output wire full
	.empty			(data_rempty	),  // output wire empty
	.rd_data_count	(rd_data_count	),  // output wire [9 : 0] rd_data_count
	.wr_data_count	(wr_data_count	)   // output wire [9 : 0] wr_data_count
);	
		end
	else if(AXI_DATA_WIDTH == 64) begin
		wire [71:0]	data_dout	;	
		reg  [71:0]	data_din	;
		// data_wr_en
		always @(posedge wr_clk or negedge rstn_sync) begin
			if(~rstn_sync) begin
				data_wr_en <= 1'b0;
				data_din   <= 'd0;
			end
			else if(wr_data_valid) begin
				data_wr_en <= 1'b1;
				data_din   <= {{7{1'b0}}, wr_data_last, wr_data_in};
			end
			else begin
				data_wr_en <= 1'b0 ;
			    data_din   <= data_din   ;
			end
		end
		// output
		always @(posedge axi_clk or negedge a_rstn_sync) begin
			if(~a_rstn_sync)
				axi_w_valid <= 1'b0;
			else if(axi_aw_req_en && axi_aw_ready)
				axi_w_valid <= 1'b1;
			else if(axi_w_valid && axi_w_ready && axi_w_last)
				axi_w_valid <= 1'b0;
			else
				axi_w_valid <= axi_w_valid;
		end
		
		always @(*) begin
			if(~a_rstn_sync) begin
				axi_w_data <= 'd0;
				axi_w_last <= 1'b0;
			end
			else if(data_rd_en) begin
				axi_w_data <= data_dout[63:0];
				axi_w_last <= data_dout[64];
			end
			else begin
				axi_w_data <= 'd0;
			    axi_w_last <= 1'b0;
			end
		end
 
		assign data_rd_en = state == WR_DATA_EN && axi_w_valid && axi_w_ready;
			
	fifo_w72xd512 data_fifo (
	.rst			(~rstn_sync		),  // input wire rst
	.wr_clk			(wr_clk			),  // input wire wr_clk
	.rd_clk			(axi_clk		),  // input wire rd_clk
	.din			(data_din		),  // input wire [144 : 0] din
	.wr_en			(data_wr_en		),  // input wire wr_en
	.rd_en			(data_rd_en		),  // input wire rd_en
	.dout			(data_dout		),  // output wire [144 : 0] dout
	.full			(data_full		),  // output wire full
	.empty			(data_rempty	),  // output wire empty
	.rd_data_count	(rd_data_count	),  // output wire [9 : 0] rd_data_count
	.wr_data_count	(wr_data_count	)   // output wire [9 : 0] wr_data_count
);	
		end
	
	// err
	always @(posedge axi_clk or negedge a_rstn_sync) begin
		if(~a_rstn_sync)
			err_wcmd_fifo <= 1'b0;
		else if(cmd_full && cmd_wr_en)
			err_wcmd_fifo <= 1'b1;
		else
			err_wcmd_fifo <= 1'b0;
	end
	always @(posedge axi_clk or negedge a_rstn_sync) begin
		if(~a_rstn_sync)
			err_wdata_fifo <= 1'b0;
		else if(data_full && data_wr_en)
			err_wdata_fifo <= 1'b1;
		else
			err_wdata_fifo <= 1'b0;
	end
	endgenerate

endmodule
