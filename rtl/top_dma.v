/**************************************************************************\ 
module name : top_dma
author		: Yuzhe Li
affiliation	: 
FPGA		: Xilinx A7_100-T
DATE		: Jul 7,2024

modify		: SIM / VERDI
\*************************************************************************/
`timescale 1ns/1ps
`define SIM_DMA

module top_dma#(
	parameter	AXI_DATA_WIDTH  = 128	,
	parameter	AXI_ADDR_WIDTH  = 32	,
	parameter	USER_DATA_WIDTH	= 16	, // 读写位宽相同
	parameter	AXI_BURST_LEN   = 4096
)(
	// clk && rst
	input									clk					,	// 读写同步用系统时钟
	input									aclk				,
	input									resetn				,
	input									ddr_init_done

);

wire								user_wr_en			;
wire	[USER_DATA_WIDTH -1:0]		user_wr_data		;
wire	[AXI_ADDR_WIDTH -1:0]		user_wr_end_addr	;
wire	[AXI_ADDR_WIDTH -1:0]		user_wr_base_addr	;
wire	[AXI_ADDR_WIDTH -1:0]		user_rd_end_addr	;
wire	[AXI_ADDR_WIDTH -1:0]		user_rd_base_addr	;
wire								user_rd_req 		;
wire								user_rd_req_busy	;
wire	[USER_DATA_WIDTH -1:0]	    user_rd_data		;
wire								user_rd_valid		;
wire								user_rd_last		;
wire	           		    		m_axi_awvalid   	;
wire					    		m_axi_awready   	;
wire	[AXI_ADDR_WIDTH-1:0]   		m_axi_awaddr    	;
wire	[3:0]                  		m_axi_awid      	;
wire	[7:0]                  		m_axi_awlen     	;
wire	[1:0]                  		m_axi_awburst   	;
wire	[2:0]                  		m_axi_awsize    	;
wire	[2:0]                  		m_axi_awport    	;
wire	[3:0]                  		m_axi_awqos     	;
wire								m_axi_awlock    	;
wire	[3:0]                  		m_axi_awcache   	;
wire						  		m_axi_wvalid    	;
wire	                    		m_axi_wready    	;
wire	[AXI_DATA_WIDTH -1:0]   	m_axi_wdata     	;
wire	[AXI_DATA_WIDTH /8-1:0] 	m_axi_wstrb     	;
wire		                		m_axi_wlast     	;
wire	[3:0]                  		m_axi_bid       	;
wire	[1:0]                  		m_axi_bresp     	;
wire	                       		m_axi_bvalid    	;
wire	                       		m_axi_bready    	;
wire								m_axi_arvalid		;
wire								m_axi_arready		;
wire	[AXI_ADDR_WIDTH -1:0]		m_axi_araddr		;
wire	[7:0]						m_axi_arlen			;
wire	[3:0]						m_axi_arid 			;
wire	[1:0]						m_axi_arburst		;
wire	[2:0]						m_axi_arsize		;
wire	[2:0]						m_axi_arport		;
wire	[3:0]						m_axi_arqos			;
wire								m_axi_arlock		;
wire	[3:0]						m_axi_arcache		;
wire	[3:0]						m_axi_rid 			;
wire								m_axi_rvalid 		;
wire								m_axi_rready 		;
wire	[AXI_DATA_WIDTH	-1:0]		m_axi_rdata			;
wire								m_axi_rlast			;
wire								m_axi_rresp			;

wire		 				 user_wr_last   ;
wire [12:0]	 				 user_wr_length ;
wire [AXI_ADDR_WIDTH -1:0]	 user_wr_addr   ;
wire [AXI_ADDR_WIDTH -1:0]	 user_rd_addr   ;
wire [12:0]	   				 user_rd_length ;    





reg aresetn_d0;
reg aresetn_d1;
reg aresetn;
always@(posedge aclk or negedge resetn) begin
	if(~resetn) begin
		aresetn_d0	<= 1'b0;
		aresetn_d1	<= 1'b0;
		aresetn 	<= 1'b0;
	end
	else begin
		aresetn_d0	<= resetn;
		aresetn_d1	<= aresetn_d0;
		aresetn 	<= aresetn_d1;
	end

end

 adma_v1#(
	.AXI_DATA_WIDTH  (AXI_DATA_WIDTH 	),
	.AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH 	),
	.USER_DATA_WIDTH (USER_DATA_WIDTH 	),// 读写位宽相同,
	.AXI_BURST_LEN   (AXI_BURST_LEN     )
) u_adma_v1(
	// clk && rst
	.clk				(clk				),	// 读写同步用系统时钟
	.aclk				(aclk 				),
	.resetn				(resetn				),

	.ddr_init_done		(ddr_init_done 		),
	// user cfg wr
	.user_wr_mode  		(1),
	.user_wr_en			(user_wr_en			),
	.user_wr_last 		(user_wr_last 		),
	.user_wr_data		(user_wr_data		),
	.user_wr_addr 		(user_wr_addr		),
	.user_wr_length 	(user_wr_length		),
	.user_wr_base_addr	(0					),
	.user_wr_end_addr	(32'h00014000		),
	// user cf rd
		// cmd
	.user_rd_mode		(1			 		),
	.user_rd_req 		(user_rd_req 		),
	.user_rd_addr 		(user_rd_addr 		),
	.user_rd_length 	(user_rd_length 	),
	.user_rd_base_addr	(0					),
	.user_rd_end_addr	(32'h00014000		),	
	.user_rd_req_busy	(user_rd_req_busy 	),	// ctrl状态不在idle就是忙
		// data
	.user_rd_data		(user_rd_data		),
	.user_rd_valid		(user_rd_valid		),
	.user_rd_last		(user_rd_last		),

	// AXI_signal
	.m_axi_awvalid   	(m_axi_awvalid   	),
	.m_axi_awready   	(m_axi_awready   	),
	.m_axi_awaddr    	(m_axi_awaddr    	),
	.m_axi_awid      	(m_axi_awid      	),
	.m_axi_awlen     	(m_axi_awlen     	),
	.m_axi_awburst   	(m_axi_awburst   	),
	.m_axi_awsize    	(m_axi_awsize    	),
	.m_axi_awport    	(m_axi_awport    	),
	.m_axi_awqos     	(m_axi_awqos     	),
	.m_axi_awlock    	(m_axi_awlock    	),
	.m_axi_awcache   	(m_axi_awcache   	),
				
	.m_axi_wvalid    	(m_axi_wvalid    	),
	.m_axi_wready    	(m_axi_wready    	),
	.m_axi_wdata     	(m_axi_wdata     	),
	.m_axi_wstrb     	(m_axi_wstrb     	),
	.m_axi_wlast     	(m_axi_wlast     	),
			
	.m_axi_bid       	(m_axi_bid       	),
	.m_axi_bresp     	(m_axi_bresp     	),
	.m_axi_bvalid    	(m_axi_bvalid    	),
	.m_axi_bready    	(m_axi_bready    	),
	.m_axi_arvalid		(m_axi_arvalid		),
	.m_axi_arready		(m_axi_arready		),
	.m_axi_araddr		(m_axi_araddr		),
	.m_axi_arlen		(m_axi_arlen		),
	.m_axi_arid 		(m_axi_arid 		),
	.m_axi_arburst		(m_axi_arburst		),
	.m_axi_arsize		(m_axi_arsize		),
	.m_axi_arport		(m_axi_arport		),
	.m_axi_arqos		(m_axi_arqos		),
	.m_axi_arlock		(m_axi_arlock		),
	.m_axi_arcache		(m_axi_arcache		),

	.m_axi_rid 			(m_axi_rid 			),
	.m_axi_rvalid 		(m_axi_rvalid 		),
	.m_axi_rready 		(m_axi_rready 		),
	.m_axi_rdata		(m_axi_rdata		),
	.m_axi_rlast		(m_axi_rlast		),
	.m_axi_rresp		(m_axi_rresp		)	
);
/*
user_req_generate #(
	.USER_WR_DATA_WIDTH (USER_DATA_WIDTH)
 ) u_user_generator(
	// clk & rst
	.wr_clk			(clk			),
	.rd_clk			(clk 			),
	.reset			(~resetn		),
	.axi_clk 		(aclk 			),
	.m_axi_wlast 	(m_axi_wlast 	),
	.user_wr_en 	(user_wr_en		),
	.user_wr_data   (user_wr_data 	),
	.user_rd_req    (user_rd_req 	)
);
*/
user_req_generate_v2 #(
	.USER_WR_DATA_WIDTH    (USER_DATA_WIDTH),
	.AXI_ADDR_WIDTH  	   (AXI_ADDR_WIDTH )
) u_user_generator(
	.wr_clk         (clk 		 	),
	.rd_clk         (clk 		 	),
	.reset          (~resetn 	 	),
    .axi_clk        (aclk 		 	),
    .m_axi_wlast    (m_axi_wlast 	),
	.user_wr_en     (user_wr_en 	),
	.user_wr_last   (user_wr_last   ),
	.user_wr_length (user_wr_length ),
	.user_wr_addr   (user_wr_addr   ),                            
	.user_wr_data   (user_wr_data   ),
	.user_rd_req    (user_rd_req    ),
    .user_rd_addr   (user_rd_addr   ),
    .user_rd_length (user_rd_length )     
    );
`ifdef SIM_DMA
blk_mem_gen_0 u_bram (
  .rsta_busy			(rsta_busy 		),          // output wire rsta_busy
  .rstb_busy			(rstb_busy 		),          // output wire rstb_busy
  .s_aclk				(aclk 			),                // input wire s_aclk
  .s_aresetn			(aresetn 		),          // input wire s_aresetn
  .s_axi_awid 			(m_axi_awid 	),        // input wire [3 : 0] s_axi_awid
  .s_axi_awaddr 		(m_axi_awaddr	),    // input wire [31 : 0] s_axi_awaddr
  .s_axi_awlen 			(m_axi_awlen	),      // input wire [7 : 0] s_axi_awlen
  .s_axi_awsize 		(m_axi_awsize	),    // input wire [2 : 0] s_axi_awsize
  .s_axi_awburst 		(m_axi_awburst	),  // input wire [1 : 0] s_axi_awburst
  .s_axi_awvalid 		(m_axi_awvalid	),  // input wire s_axi_awvalid
  .s_axi_awready 		(m_axi_awready	),  // output wire s_axi_awready
  .s_axi_wdata 			(m_axi_wdata	),      // input wire [127 : 0] s_axi_wdata
  .s_axi_wstrb 			(m_axi_wstrb	),      // input wire [15 : 0] s_axi_wstrb
  .s_axi_wlast 			(m_axi_wlast	),      // input wire s_axi_wlast
  .s_axi_wvalid 		(m_axi_wvalid 	),    // input wire s_axi_wvalid
  .s_axi_wready 		(m_axi_wready 	),    // output wire s_axi_wready
  .s_axi_bid 			(m_axi_bid 		),          // output wire [3 : 0] s_axi_bid
  .s_axi_bresp 			(m_axi_bresp 	),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid 		(m_axi_bvalid 	),    // output wire s_axi_bvalid
  .s_axi_bready 		(m_axi_bready 	),    // input wire s_axi_bready
  .s_axi_arid 			(m_axi_arid 	),        // input wire [3 : 0] s_axi_arid
  .s_axi_araddr 		(m_axi_araddr 	),    // input wire [31 : 0] s_axi_araddr
  .s_axi_arlen 			(m_axi_arlen 	),      // input wire [7 : 0] s_axi_arlen
  .s_axi_arsize 		(m_axi_arsize 	),    // input wire [2 : 0] s_axi_arsize
  .s_axi_arburst 		(m_axi_arburst 	),  // input wire [1 : 0] s_axi_arburst
  .s_axi_arvalid 		(m_axi_arvalid	),  // input wire s_axi_arvalid
  .s_axi_arready 		(m_axi_arready 	),  // output wire s_axi_arready
  .s_axi_rid 			(m_axi_rid 		),          // output wire [3 : 0] s_axi_rid
  .s_axi_rdata 			(m_axi_rdata 	),      // output wire [127 : 0] s_axi_rdata
  .s_axi_rresp 			(m_axi_rresp 	),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rlast 			(m_axi_rlast 	),      // output wire s_axi_rlast
  .s_axi_rvalid 		(m_axi_rvalid 	),    // output wire s_axi_rvalid
  .s_axi_rready 		(m_axi_rready 	)    // input wire s_axi_rready
);
`endif
endmodule