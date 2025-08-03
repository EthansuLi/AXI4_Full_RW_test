/**************************************************************************\ 
module name : ADMA : wr_master
author		: Yuzhe Li
DATE		: Jul 7,2024

modify		:
\*************************************************************************/
`timescale 1ns/1ns
module wr_master#(
	parameter	AXI_ADDR_WIDTH = 32,
	parameter	AXI_DATA_WIDTH = 128
)(
	input                             axi_clk           ,
	input                             reset             ,

    /*------------------- from wr_buffer ---------------------*/
 	input                             axi_aw_req_en     , 
 	output reg                        axi_aw_ready      , 
	input      [7:0]                  axi_aw_burst_len  ,
 	input      [AXI_ADDR_WIDTH-1:0]   axi_aw_addr       ,

 	input                             axi_w_valid       ,
 	output reg                        axi_w_ready       ,
 	input      [AXI_DATA_WIDTH-1:0]   axi_w_data        ,
 	input                             axi_w_last        ,

    /*-------------------- AXI signal ------------------------*/
 	output reg                        m_axi_awvalid     ,
 	input                             m_axi_awready     ,
 	output reg [AXI_ADDR_WIDTH-1:0]   m_axi_awaddr      ,
 	output reg [3:0]                  m_axi_awid        ,
 	output reg [7:0]                  m_axi_awlen       ,
 	output reg [1:0]                  m_axi_awburst     ,
 	output reg [2:0]                  m_axi_awsize      ,
 	output reg [2:0]                  m_axi_awport      ,
 	output reg [3:0]                  m_axi_awqos       ,
 	output reg                        m_axi_awlock      ,
 	output reg [3:0]                  m_axi_awcache     ,

 	output reg                        m_axi_wvalid      ,
 	input                             m_axi_wready      ,
 	output reg [AXI_DATA_WIDTH-1:0]   m_axi_wdata       ,
 	output reg [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb       ,   	
 	output reg                        m_axi_wlast       , 

    input      [3:0]                  m_axi_bid         ,
    input      [1:0]                  m_axi_bresp       ,
    input                             m_axi_bvalid      ,
    output                            m_axi_bready      
);
/********************************************************************\ 
								parameter
\********************************************************************/	
	localparam WR_IDLE		= 4'b0001;
	localparam WR_REQ		= 4'b0010;
	localparam WR_DATA_EN	= 4'b0100;
	localparam WR_END		= 4'b1000;
/********************************************************************\ 
								reg
\********************************************************************/	
	// fsm
	reg	[3:0] state		;
	reg [3:0] next_state;
	// sync
	(* dont_touch ="true" *)reg	a_rst_sync_d0	;
	(* dont_touch ="true" *)reg	a_rst_sync_d1	;
	(* dont_touch ="true" *)reg	a_rst_sync	 	;
	

/********************************************************************\ 
								modify
\********************************************************************/	

/********************************************************************\ 
								time seq
\********************************************************************/	
	// sync
	always @(posedge axi_clk) begin
		a_rst_sync_d0 <= reset;
		a_rst_sync_d1 <= a_rst_sync_d0;
		a_rst_sync	  <= a_rst_sync_d1;
	end	
	
	// ready
	always @(*) begin
		axi_aw_ready = state == WR_REQ;
	end
	
	always @(*) begin
		axi_w_ready	 = m_axi_wready;
	end
	
	always @(posedge axi_clk) begin
    if (~a_rst_sync) 
        m_axi_awvalid <= 0;
    else if (m_axi_awvalid && m_axi_awready) 
        m_axi_awvalid <= 0;
    else if (axi_aw_req_en && axi_aw_ready)
        m_axi_awvalid <= 1;
	end

	always @(posedge axi_clk) begin
		if (axi_aw_req_en && axi_aw_ready) begin
			m_axi_awaddr <= axi_aw_addr;
			m_axi_awlen  <= axi_aw_burst_len;
		end
		else begin
			m_axi_awaddr <= m_axi_awaddr;
			m_axi_awlen  <= m_axi_awlen;		
		end
	end
	
	always @(posedge axi_clk) begin
		if (~a_rst_sync) 
			m_axi_wvalid <= 0;
		else if (m_axi_wvalid && m_axi_wready && m_axi_wlast) 
			m_axi_wvalid <= 0;
		else if (axi_w_valid && axi_w_ready)
			m_axi_wvalid <= 1;
		else 
			m_axi_wvalid <= m_axi_wvalid;
	end
	
	always @(posedge axi_clk) begin
		if (~a_rst_sync) 
			m_axi_wlast <= 0;
		else if (m_axi_wvalid && m_axi_wready && m_axi_wlast)
			m_axi_wlast <= 0;        
		else if (axi_w_valid && axi_w_ready && axi_w_last) 
			m_axi_wlast <= 1;
	end
	
	always @(posedge axi_clk) begin
		if (axi_w_valid && axi_w_ready) 
			m_axi_wdata <= axi_w_data;
		else 
			m_axi_wdata <= m_axi_wdata;
	end
	
/********************************************************************\ 
								fsm
\********************************************************************/	
	always @(posedge axi_clk or negedge a_rst_sync) begin 
		if(~a_rst_sync)
			state <= WR_IDLE;
		else
			state <= next_state;
	end
	
	always @(*) begin
		case(state)
			WR_IDLE 	: next_state <= (axi_aw_req_en)? WR_REQ : WR_IDLE;
			WR_REQ		: next_state <= WR_DATA_EN;
			WR_DATA_EN	: next_state <= (m_axi_wvalid && m_axi_wready && m_axi_wlast)? WR_END : WR_DATA_EN;
			WR_END		: next_state <= WR_IDLE;
			default 	: next_state <= state;
		endcase
	end

/********************************************************************\ 
								assign 
\********************************************************************/
always @(posedge axi_clk) begin
    m_axi_awport  <= 0;
	m_axi_awid    <= 0;
	m_axi_awburst <= 2'b01;
	m_axi_awlock  <= 0;
	m_axi_awcache <= 0;
	m_axi_awqos   <= 0;
	m_axi_wstrb   <= {AXI_DATA_WIDTH/8{1'b1}};
	m_axi_awsize  <= AXI_DATA_WIDTH == 512 ? 3'h6 :
					 AXI_DATA_WIDTH == 256 ? 3'h5 :
					 AXI_DATA_WIDTH == 128 ? 3'h4 :
					 AXI_DATA_WIDTH == 64  ? 3'h3 :
					 AXI_DATA_WIDTH == 32  ? 3'h2 : 3'h0;
end
assign m_axi_bready = 1'b1;
endmodule

