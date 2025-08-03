/**************************************************************************\ 
module name : ADMA : rd_master
author		: Yuzhe Li

DATE		: 11,2024

modify		:
\*************************************************************************/
`timescale 1ns/1ns

module rd_master#(
	parameter AXI_DATA_WIDTH = 128,
	parameter AXI_ADDR_WIDTH = 32
)(
	// clk && rst
	input								aclk				,
	input								reset_n				,
	// from rd_buffer
	input		[AXI_ADDR_WIDTH -1:0]	axi_ar_addr			,
	input								axi_ar_req_en		,
	input		[7:0]					axi_ar_burst_len	,
	output								axi_ar_ready		,

	output	reg	[AXI_DATA_WIDTH -1:0]	axi_r_data			,
	output 	reg 						axi_r_valid			,
	output  reg							axi_r_last			,
	// output axi bus
	output	reg							m_axi_arvalid		,
	output	reg	[AXI_ADDR_WIDTH -1:0]	m_axi_araddr		,
	input								m_axi_arready		,
	output  reg [7:0]					m_axi_arlen			,

	output  reg	[3:0]					m_axi_arid 			,
	output  reg [1:0]					m_axi_arburst		,
	output	reg [2:0]					m_axi_arsize		,
	output 	reg [2:0]					m_axi_arport		,
	output	reg	[3:0]					m_axi_arqos			,
	output	reg							m_axi_arlock		,
	output	reg [3:0]					m_axi_arcache		,

	input		[3:0]					m_axi_rid 			,
	input								m_axi_rvalid 		,
	output								m_axi_rready 		,
	input		[AXI_DATA_WIDTH -1:0]	m_axi_rdata			,
	input       						m_axi_rlast			,
	input								m_axi_rresp
);

//============================ parameter ===============================//
// fsm
localparam AXI_RD_IDLE = 4'b0001;
localparam AXI_RD_CMD  = 4'b0001;
localparam AXI_RD_DATA = 4'b0001;
localparam AXI_RD_END  = 4'b0001;

//=========================== reg && wire ==============================//
// aysnc
(* dont_touch ="true" *)reg aresetn_d0;
(* dont_touch ="true" *)reg aresetn_d1;
(* dont_touch ="true" *)reg aresetn;
// fsm
reg [3:0] state;
reg [3:0] next_state;
//============================ time sequ ===============================//
// aysnc
always@(posedge aclk or negedge reset_n) begin
	if(~reset_n) begin
		aresetn_d0 <= 1'b0;
		aresetn_d1 <= 1'b0;
		aresetn    <= 1'b0;
	end
	else begin
		aresetn_d0 <= reset_n	;
		aresetn_d1 <= aresetn_d0;
		aresetn    <= aresetn_d1;
	end
end


//=============================== fsm ==================================//
// 状态机备用便于后续优化
always@(posedge aclk or negedge aresetn) begin
	if(~aresetn)
		state <= AXI_RD_IDLE;
	else
		state <= next_state;
end

always@(*) begin
	if(~aresetn)
		next_state <= AXI_RD_IDLE;
	else begin
		case (state)
			AXI_RD_IDLE : next_state <= (axi_ar_req_en)? AXI_RD_CMD : AXI_RD_IDLE;
			AXI_RD_CMD	: next_state <= AXI_RD_DATA;
			AXI_RD_DATA : next_state <= (m_axi_rvalid && m_axi_rready && m_axi_rlast)? AXI_RD_END : AXI_RD_DATA;
			AXI_RD_END  : next_state <= AXI_RD_IDLE;
			default : next_state = state;
		endcase

	end

end
//============================== output ================================//
assign axi_ar_ready = state == AXI_RD_CMD;
always@(posedge aclk) begin
	m_axi_arport 	<= 0;
	m_axi_arid  	<= 0;
	m_axi_arburst 	<= 2'b01; // 连续突发
	m_axi_arcache	<= 0;
	m_axi_arqos		<= 0;
	m_axi_arlock	<= 0;
	m_axi_arsize	<= AXI_DATA_WIDTH == 512 ? 3'h6 :
					   AXI_DATA_WIDTH == 256 ? 3'h5 :
					   AXI_DATA_WIDTH == 128 ? 3'h4 :
					   AXI_DATA_WIDTH == 64  ? 3'h3 :
					   AXI_DATA_WIDTH == 32  ? 3'h2 : 3'h0;
end
// m_axi_arvalid
always@(posedge aclk or negedge aresetn) begin
	if(~aresetn)
		m_axi_arvalid <= 1'b0;
	else if(m_axi_arvalid && m_axi_arready)
		m_axi_arvalid <= 1'b0;
	else if(axi_ar_req_en && axi_ar_ready)
		m_axi_arvalid <=1'b1;
	else
		m_axi_arvalid <= m_axi_arvalid;
end
// addr && len(包长)
always@(posedge aclk or negedge aresetn) begin
	if(~aresetn) begin
		m_axi_araddr  <= 'd0 ;
		m_axi_arlen   <= 'd0 ;
	end
	else if(axi_ar_req_en && axi_ar_ready) begin
		m_axi_araddr  <= axi_ar_addr;
		m_axi_arlen	  <= axi_ar_burst_len;
	end

end
// to buffer
always@(posedge aclk) begin
	axi_r_data  <= m_axi_rdata	;
	axi_r_valid <= m_axi_rvalid ;
	axi_r_last	<= m_axi_rlast	;
end

assign m_axi_rready = 1'b1 ;

endmodule
