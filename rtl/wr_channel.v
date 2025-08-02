/**************************************************************************\ 
module name : ADMA : wr_channel
author		: Yuzhe Li ||  liyuzhe5
affiliation	: SEU -ESE --display && visualization lab || 
			  Hikvision, Research Institute, circuit department 
FPGA		: Xilinx A7_100-T
DATE		: Jul 7,2024

modify		:
\*************************************************************************/
`timescale 1ns/1ns

module wr_channel#(
	parameter	AXI_ADDR_WIDTH	=	32 ,
	parameter	AXI_DATA_WIDTH	=	128,
	parameter	USER_DATA_WIDTH	=	16 ,
	parameter   AXI_BURST_LEN   = 4096
)(
	// reset & clk
	input									wr_clk			,
	input									axi_clk			,
	input									resetn			,
	
	input									ddr_init_done	,
	// user signal
	input									user_wr_mode	,
	input									user_wr_en		,
	input									user_wr_last	,
	input		[USER_DATA_WIDTH-1:0]		user_wr_data	,
	input		[AXI_ADDR_WIDTH -1:0]		user_wr_addr	,
	input		[12:0]						user_wr_length	,	
	input		[AXI_ADDR_WIDTH -1:0]		user_base_addr	,
	input		[AXI_ADDR_WIDTH -1:0]		user_end_addr	,
	// AXI_signal
	output 	                        		m_axi_awvalid   ,
	input  	                        		m_axi_awready   ,
	output 	 [AXI_ADDR_WIDTH-1:0]   		m_axi_awaddr    ,
	output 	 [3:0]                  		m_axi_awid      ,
	output 	 [7:0]                  		m_axi_awlen     ,
	output 	 [1:0]                  		m_axi_awburst   ,
	output 	 [2:0]                  		m_axi_awsize    ,
	output 	 [2:0]                  		m_axi_awport    ,
	output 	 [3:0]                  		m_axi_awqos     ,
	output 	                        		m_axi_awlock    ,
	output 	 [3:0]                  		m_axi_awcache   ,
				
	output 	                        		m_axi_wvalid    ,
	input  	                        		m_axi_wready    ,
	output 	 [AXI_DATA_WIDTH-1:0]   		m_axi_wdata     ,
	output 	 [AXI_DATA_WIDTH/8-1:0] 		m_axi_wstrb     ,
	output 	                        		m_axi_wlast     ,
			
	input      [3:0]                  		m_axi_bid       ,
	input      [1:0]                  		m_axi_bresp     ,
	input                             		m_axi_bvalid    ,
	output                            		m_axi_bready    ,

	// err
	output									cmd_fifo_err	,
	output									data_fifo_err
);

wire												wr_req_en		;		
wire												wr_data_valid	;
wire	[AXI_ADDR_WIDTH-1:0]						wr_addr_out		;
wire	[AXI_DATA_WIDTH-1:0]						wr_data_out		;
wire	[7:0]	    								wr_burst_len	;
wire												wr_data_last    ;


wire	[AXI_ADDR_WIDTH-1:0]						axi_aw_addr		;	
wire												axi_aw_req_en	;	
wire												axi_aw_ready	;	
wire	[7:0]										axi_aw_burst_len;	
wire	[AXI_DATA_WIDTH-1:0]						axi_w_data		;	
wire												axi_w_valid		;	
wire												axi_w_ready		;	
wire												axi_w_last		;	




wr_ctrl#(
	.USER_DATA_WIDTH	(USER_DATA_WIDTH), 
	.AXI_DATA_WIDTH     (AXI_DATA_WIDTH	),
	.AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH	),
	.AXI_BURST_LEN 		(AXI_BURST_LEN  )
	) u_wr_ctrl(
	.clk				(wr_clk			),		
	.resetn				(resetn			),
	.ddr_init_done		(ddr_init_done	),
	
	.user_wr_mode		(user_wr_mode	),
	.user_wr_en			(user_wr_en		),
	.user_wr_last 		(user_wr_last	),
	.user_wr_data		(user_wr_data	),
	.user_wr_addr		(user_wr_addr	),
	.user_wr_length		(user_wr_length	),
	.user_base_addr		(user_base_addr	),
	.user_end_addr		(user_end_addr	),					

	.wr_data_out		(wr_data_out	),	
	.wr_data_valid		(wr_data_valid	),
	.wr_data_last   	(wr_data_last   ),
	.wr_req_en			(wr_req_en		),
	.wr_addr_out		(wr_addr_out	),
	.wr_burst_len		(wr_burst_len	)
	);
	
wr_buffer#(
	.AXI_DATA_WIDTH (AXI_DATA_WIDTH),
	.AXI_ADDR_WIDTH (AXI_ADDR_WIDTH)
) u_wr_buffer(
	// clk
	.wr_clk				(wr_clk				),								
	.axi_clk			(axi_clk			),
	.resetn				(resetn				),
	// from user wr_ctr	                     
	.wr_data_in	    	(wr_data_out    	),	
	.wr_data_valid	   	(wr_data_valid	   	),
	.wr_data_last    	(wr_data_last   	),
	.wr_req_en			(wr_req_en			),
	.wr_addr_in	    	(wr_addr_out    	),
	.wr_burst_len    	(wr_burst_len   	),
	// commuicate with wr_buffer	         
	.axi_aw_req_en		(axi_aw_req_en		),
	.axi_aw_ready		(axi_aw_ready		),
	.axi_aw_addr		(axi_aw_addr		),
	.axi_aw_burst_len	(axi_aw_burst_len	),
		                 	                 
	.axi_w_valid		(axi_w_valid		),
	.axi_w_ready		(axi_w_ready		),
	.axi_w_data			(axi_w_data			),
	.axi_w_last			(axi_w_last			),
	// err             
	.err_wcmd_fifo		(cmd_fifo_err		),
	.err_wdata_fifo     (data_fifo_err      )
);	


wr_master #(
	.AXI_DATA_WIDTH    (AXI_DATA_WIDTH),
	.AXI_ADDR_WIDTH    (AXI_ADDR_WIDTH)	
) u_wr_master(
	
	.axi_clk           (axi_clk			),
	.reset             (resetn 			),

    /*-------------wr_buffer模块交互信号-------------*/
 	.axi_aw_req_en     (axi_aw_req_en   ), //表示AXI4写请求
 	.axi_aw_ready      (axi_aw_ready    ), //axi_aw_req_en 和axi_aw_ready同时为高，开启一次AXI4写传输
 	.axi_aw_burst_len  (axi_aw_burst_len),
 	.axi_aw_addr       (axi_aw_addr     ),
                        
 	.axi_w_valid       (axi_w_valid     ),
 	.axi_w_ready       (axi_w_ready     ),
 	.axi_w_data        (axi_w_data      ),
 	.axi_w_last        (axi_w_last      ),

    /*-------------AXI写通道端口信号---------------------*/
 	.m_axi_awvalid     (m_axi_awvalid	),
 	.m_axi_awready     (m_axi_awready	),
 	.m_axi_awaddr      (m_axi_awaddr 	),
 	.m_axi_awid        (m_axi_awid   	),
 	.m_axi_awlen       (m_axi_awlen  	),
 	.m_axi_awburst     (m_axi_awburst	),
 	.m_axi_awsize      (m_axi_awsize 	),
 	.m_axi_awport      (m_axi_awport 	),
 	.m_axi_awqos       (m_axi_awqos  	),
 	.m_axi_awlock      (m_axi_awlock 	),
 	.m_axi_awcache     (m_axi_awcache	),

 	.m_axi_wvalid      (m_axi_wvalid),
 	.m_axi_wready      (m_axi_wready),
 	.m_axi_wdata       (m_axi_wdata ),
 	.m_axi_wstrb       (m_axi_wstrb ),   	
 	.m_axi_wlast       (m_axi_wlast ), 

    .m_axi_bid         (m_axi_bid    ),
    .m_axi_bresp       (m_axi_bresp  ),
    .m_axi_bvalid      (m_axi_bvalid ),
    .m_axi_bready      (m_axi_bready )
    );

endmodule