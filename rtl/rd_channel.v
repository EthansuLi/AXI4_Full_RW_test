/**************************************************************************\ 
module name : rd_channel
author		: Yuzhe Li
affiliation	: 
FPGA		: Xilinx A7_100-T
DATE		: Jul 7,2024

modify		:
\*************************************************************************/
`timescale 1ns/1ns

module rd_channel#(
	parameter	AXI_ADDR_WIDTH	=	32 ,
	parameter	AXI_DATA_WIDTH	=	128,
	parameter	USER_DATA_WIDTH	=	16 ,
	parameter	AXI_BURST_LEN   = 4096
)(
	// rst & clk
	input									rd_clk				,		 
	input									aclk				,
	input									resetn				,
	
	input									ddr_init_done		,
	// user cfg
		// cmd
	input									user_rd_mode		,	
	input									user_rd_req 		,
	input		[AXI_ADDR_WIDTH -1:0]		user_rd_addr 		,
	input		[12:0]						user_rd_length		,
	input		[AXI_ADDR_WIDTH -1:0]		user_base_addr		,
	input		[AXI_ADDR_WIDTH -1:0]		user_end_addr		,	
	output									user_rd_req_busy	,	// ctrl状态不在idle就是忙
		// data
	output	 	[USER_DATA_WIDTH -1:0]	    user_rd_data		,
	output									user_rd_valid		,
	output									user_rd_last		,
	// axi bus
	output									m_axi_arvalid		,
	input									m_axi_arready		,
	output		[AXI_ADDR_WIDTH -1:0]		m_axi_araddr		,
	output		[11:0]						m_axi_arlen			,
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
	input									m_axi_rresp			,

	// err
	output									rd_cmd_fifo_err		,
	output									rd_data_fifo_err	
);


wire							rd_buffer_ready		;
wire    [AXI_ADDR_WIDTH-1:0]	rd_addr_out			;
wire							rd_req_en			;
wire	[7:0]					rd_burst_length		;

wire	[AXI_ADDR_WIDTH -1:0]	axi_ar_addr			;
wire	[7:0]					axi_ar_burst_len	;
wire							axi_ar_req_en		;
wire							axi_ar_ready		;
wire							axi_r_valid			;
wire	[AXI_DATA_WIDTH -1:0]	axi_r_data			;
wire							axi_r_last			;


//============================= instance ===============================//
rd_ctrl#(
	.AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
	.AXI_DATA_WIDTH (AXI_DATA_WIDTH),
	.AXI_BURST_LEN  (AXI_BURST_LEN )
) u_rd_ctrl (
// clk & rst
	.clk					(rd_clk				),
	.reset_n				(resetn 	 		),		
	.ddr_init_done			(ddr_init_done		),
// to buffer
	.rd_buffer_ready		(rd_buffer_ready	),
	.rd_addr_out			(rd_addr_out		),
	.rd_req_en				(rd_req_en			),
	.rd_burst_length		(rd_burst_length	),
// from uesr
	.user_rd_mode			(user_rd_mode  		),
	.user_rd_req 			(user_rd_req 		),
	.user_rd_addr 			(user_rd_addr 		),
	.user_rd_length 		(user_rd_length 	),
	.user_rd_base_addr		(user_base_addr		),
	.user_rd_end_addr		(user_end_addr		),
	.user_rd_busy 			(user_rd_req_busy	)
);

 rd_buffer #(
	.AXI_DATA_WIDTH  (AXI_DATA_WIDTH  ),
	.AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH  ),
	.USER_DATA_WIDTH (USER_DATA_WIDTH )
) u_rd_buffer(
// clk & reset 
	.clk					(rd_clk				),
	.aclk					(aclk 				),	// axi_clk
	.reset_n				(resetn 			),
// from USER's rd_ctrl
	.rd_req_en				(rd_req_en			),
	.rd_buffer_cmd_ready	(rd_buffer_ready	),
	.rd_addr_in				(rd_addr_out		),
	.rd_burst_length		(rd_burst_length	), // 突发字节数
// communicate with rd_master
	.axi_ar_addr			(axi_ar_addr		),
	.axi_ar_burst_len		(axi_ar_burst_len	),
	.axi_ar_req_en			(axi_ar_req_en		),
	.axi_ar_ready			(axi_ar_ready		),
	.axi_r_valid			(axi_r_valid		),
	.axi_r_data				(axi_r_data			),
	.axi_r_last				(axi_r_last			),
// User data out
	.user_rd_valid			(user_rd_valid		),
	.user_rd_data			(user_rd_data		),
	.user_rd_last			(user_rd_last		),
// err dcc
	.rd_cmd_fifo_err		(rd_cmd_fifo_err	),
	.rd_data_fifo_err		(rd_data_fifo_err	)		
);

 rd_master#(
	.AXI_DATA_WIDTH (AXI_DATA_WIDTH),
	.AXI_ADDR_WIDTH (AXI_ADDR_WIDTH)
) u_rd_master(
	// clk && rst
	.aclk					(aclk 					),
	.reset_n				(resetn 				),
	// from rd_buffer
	.axi_ar_addr			(axi_ar_addr			),
	.axi_ar_req_en			(axi_ar_req_en			),
	.axi_ar_burst_len		(axi_ar_burst_len		),
	.axi_ar_ready			(axi_ar_ready			),
	.axi_r_data				(axi_r_data				),
	.axi_r_valid			(axi_r_valid			),
	.axi_r_last				(axi_r_last				),
	// output axi bus
	.m_axi_arvalid			(m_axi_arvalid			),
	.m_axi_araddr			(m_axi_araddr			),
	.m_axi_arready			(m_axi_arready			),
	.m_axi_arlen			(m_axi_arlen			),
	.m_axi_arid 			(m_axi_arid 			),
	.m_axi_arburst			(m_axi_arburst			),
	.m_axi_arsize			(m_axi_arsize			),
	.m_axi_arport			(m_axi_arport			),
	.m_axi_arqos			(m_axi_arqos			),
	.m_axi_arlock			(m_axi_arlock			),
	.m_axi_arcache			(m_axi_arcache			),
	.m_axi_rid 				(m_axi_rid 				),
	.m_axi_rvalid 			(m_axi_rvalid 			),
	.m_axi_rready 			(m_axi_rready 			),
	.m_axi_rdata			(m_axi_rdata			),
	.m_axi_rlast			(m_axi_rlast			),
	.m_axi_rresp			(m_axi_rresp			)
							
	);




endmodule 