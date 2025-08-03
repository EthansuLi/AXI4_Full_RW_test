/**************************************************************************\ 
module name : ADMA TOP
author		: Yuzhe Li
affiliation	: 

DATE		: NOV 23,2024

modify		:
\*************************************************************************/
`timescale 1ns / 1ns

module adma_v1#(
	parameter	AXI_DATA_WIDTH  = 64	,
	parameter	AXI_ADDR_WIDTH  = 32	,
	parameter	USER_DATA_WIDTH	= 64	,// 读写位宽相同
	parameter	AXI_BURST_LEN   = 4096
)
(
	// clk && rst
	input									clk					,	// 读写同步用系统时钟
	input									aclk				,
	input									resetn				,

	input									ddr_init_done		,
	// user cfg wr
	input									user_wr_mode		,
	input									user_wr_en			,
	input									user_wr_last		,
	input		[USER_DATA_WIDTH -1:0]		user_wr_data		,
	input		[AXI_ADDR_WIDTH -1:0]		user_wr_addr	,
	input		[12:0]						user_wr_length	,
	input		[AXI_ADDR_WIDTH -1 :0]		user_wr_base_addr	,
	input		[AXI_ADDR_WIDTH -1 :0]		user_wr_end_addr	,
	// user cf rd
		// cmd
	input									user_rd_mode		,
	input									user_rd_req 		,
	input		[AXI_ADDR_WIDTH -1:0]		user_rd_addr 		,
	input		[12:0]						user_rd_length		,
	input		[AXI_ADDR_WIDTH -1:0]		user_rd_base_addr	,
	input		[AXI_ADDR_WIDTH -1:0]		user_rd_end_addr	,	
	output									user_rd_req_busy	,	// ctrl状态不在idle就是忙
		// data
	output	 	[USER_DATA_WIDTH -1:0]	    user_rd_data		,
	output									user_rd_valid		,
	output									user_rd_last		,

	// AXI_signal
	output 	                        		m_axi_awvalid   	,
	input  	                        		m_axi_awready   	,
	output 	 [AXI_ADDR_WIDTH-1:0]   		m_axi_awaddr    	,
	output 	 [3:0]                  		m_axi_awid      	,
	output 	 [7:0]                  		m_axi_awlen     	,
	output 	 [1:0]                  		m_axi_awburst   	,
	output 	 [2:0]                  		m_axi_awsize    	,
	output 	 [2:0]                  		m_axi_awport    	,
	output 	 [3:0]                  		m_axi_awqos     	,
	output 	                        		m_axi_awlock    	,
	output 	 [3:0]                  		m_axi_awcache   	,
				
	output 	                        		m_axi_wvalid    	,
	input  	                        		m_axi_wready    	,
	output 	 [AXI_DATA_WIDTH-1:0]   		m_axi_wdata     	,
	output 	 [AXI_DATA_WIDTH/8-1:0] 		m_axi_wstrb     	,
	output 	                        		m_axi_wlast     	,
			
	input      [3:0]                  		m_axi_bid       	,
	input      [1:0]                  		m_axi_bresp     	,
	input                             		m_axi_bvalid    	,
	output                            		m_axi_bready    	,
	output									m_axi_arvalid		,
	input									m_axi_arready		,
	output		[AXI_ADDR_WIDTH -1:0]		m_axi_araddr		,
	output		[7:0]						m_axi_arlen			,
	output		[3:0]						m_axi_arid 			,
	output		[1:0]						m_axi_arburst		,
	output		[2:0]						m_axi_arsize		,
	output		[2:0]						m_axi_arport		,
	output		[3:0]						m_axi_arqos			,
	output									m_axi_arlock		,
	output		[3:0]						m_axi_arcache		,

	input		[3:0]						m_axi_rid 			,
	input									m_axi_rvalid 		,
	output									m_axi_rready 		,
	input		[AXI_DATA_WIDTH	-1:0]		m_axi_rdata			,
	input									m_axi_rlast			,
	input									m_axi_rresp			
);

// err
wire wcmd_fifo_err;
wire wdata_fifo_err;
wire rcmd_fifo_err;
wire rdata_fifo_err;



wr_channel#(
	.AXI_ADDR_WIDTH	 (AXI_ADDR_WIDTH	),
	.AXI_DATA_WIDTH	 (AXI_DATA_WIDTH	),
	.USER_DATA_WIDTH (USER_DATA_WIDTH 	),
	.AXI_BURST_LEN 	 (AXI_BURST_LEN 	)
) u_wr_channel(
	// reset & clk
	.wr_clk			 (clk 				),
	.axi_clk		 (aclk 				),
	.resetn			 (resetn 			),
	.ddr_init_done	 (ddr_init_done	    ),
	// user signal
	.user_wr_mode	 (user_wr_mode 		),
	.user_wr_en		 (user_wr_en		),
	.user_wr_last 	 (user_wr_last 		),
	.user_wr_data	 (user_wr_data	 	),
	.user_wr_addr 	 (user_wr_addr 		),
	.user_wr_length  (user_wr_length 	),
	.user_base_addr	 (user_wr_base_addr	),
	.user_end_addr	 (user_wr_end_addr	),
	// AXI_signal
	.m_axi_awvalid   (m_axi_awvalid   	),
	.m_axi_awready   (m_axi_awready   	),
	.m_axi_awaddr    (m_axi_awaddr    	),
	.m_axi_awid      (m_axi_awid      	),
	.m_axi_awlen     (m_axi_awlen     	),
	.m_axi_awburst   (m_axi_awburst   	),
	.m_axi_awsize    (m_axi_awsize    	),
	.m_axi_awport    (m_axi_awport    	),
	.m_axi_awqos     (m_axi_awqos     	),
	.m_axi_awlock    (m_axi_awlock    	),
	.m_axi_awcache   (m_axi_awcache   	),
				
	.m_axi_wvalid    (m_axi_wvalid      ),
	.m_axi_wready    (m_axi_wready      ),
	.m_axi_wdata     (m_axi_wdata       ),
	.m_axi_wstrb     (m_axi_wstrb       ),
	.m_axi_wlast     (m_axi_wlast       ),
			
	.m_axi_bid       (m_axi_bid         ),
	.m_axi_bresp     (m_axi_bresp       ),
	.m_axi_bvalid    (m_axi_bvalid      ),
	.m_axi_bready    (m_axi_bready      ),     		

	// err
	.cmd_fifo_err	 (wcmd_fifo_err 	),
	.data_fifo_err   (wdata_fifo_err 	)
);

 rd_channel#(
	.AXI_ADDR_WIDTH	 (AXI_ADDR_WIDTH  ),
	.AXI_DATA_WIDTH	 (AXI_DATA_WIDTH  ),
	.USER_DATA_WIDTH (USER_DATA_WIDTH ),
	.AXI_BURST_LEN   (AXI_BURST_LEN   )
) u_rd_channel(
	// rst & clk
	.rd_clk				(clk 				),		 
	.aclk				(aclk 				),
	.resetn				(resetn				),
	.ddr_init_done		(ddr_init_done		),
	// user cfg
		// cmd
	.user_rd_mode		(user_rd_mode		),
	.user_rd_req		(user_rd_req		),
	.user_rd_addr 		(user_rd_addr 		),
	.user_rd_length 	(user_rd_length 	),
	.user_base_addr		(user_rd_base_addr	),
	.user_end_addr		(user_rd_end_addr 	),
	.user_rd_req_busy	(user_rd_req_busy	),
		// data
	.user_rd_data		(user_rd_data		),
	.user_rd_valid		(user_rd_valid		),
	.user_rd_last		(user_rd_last		),
	// axi bus
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
	.m_axi_rresp		(m_axi_rresp		),
	// err
	.rd_cmd_fifo_err	(rcmd_fifo_err		),
	.rd_data_fifo_err	(rdata_fifo_err		)
);

endmodule
