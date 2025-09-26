//-------------------------------------------------------------------//
//
//	Copyright(c) 2020 BeeBeans Technologies. All rights reserved.
//
//	System      : System using LAN8810
//
//	Module      : LAN8810_INIT
//
//	Description : Initialze for LAN8810
//
//	file	: LAN8810_INIT.v
//
//	Note	:
//
//	history	:
//		1.0		20201224	---------		Created by M.Ishiwata
//		1.1		20250801	---------		Changed the state number definition to ensure the second reset time is at least 50ms.
//		1.2		20250904	---------		Reset Mask
//
//-------------------------------------------------------------------//
`timescale 1ps / 1ps
`default_nettype none


module	LAN8810_INIT
	#(
		parameter	[7:0]	freqency	= 200		// Frequency of CLOCK_IN (MHz)
	)(
		input	wire			I_nRESET,			// in :reset in
		input	wire			CLOCK,				// in :SiTCP Clock
		input	wire	[ 4:0]	PHY_ADDR,			// in :PHY Address[4:0]
		input	wire			SiTCP_PHY_nRST,		// in :PHY Reset from SiTCP
		input	wire			SiTCP_MDC,			// in :MDC form SiTCP
		input	wire			SiTCP_MDIO_OUT,		// in :MDIO_OUT from SiTCP
		input	wire			SiTCP_MDIO_OE,		// in :MDIO_OE from SiTCP
		output	wire			MDC,				// out:MDC to LAN8810
		output	wire			O_MDIO,				// out:To the I port of the MDIO driver
		output	wire			T_MDIO,				// out:To the T port of the MDIO driver
		output	reg				PHY_nRESET,			// out:Reset for LAN8810
		output	reg				O_RESET				// out:reset out
	);
	localparam	[7:0]	load_1us = freqency - 2;

	reg		[ 8:0]	CNT_1us;
	reg		[ 7:0]	CNT_100us;
	reg		[ 7:0]	CNT_10ms;
	reg				STATE_RUN;
	reg		[ 3:0]	INIT_STATE;
	reg				INIT_MDC;
	reg				INIT_MDT;
	reg				INIT_MDO;
	reg		[ 6:0]	INC_LOD;
	reg		[ 7:0]	CNT_INC;
	reg		[ 6:0]	CNT_MDIO;
	reg				STATE_INC;
	reg				ENB_MDIO;
	reg		[31:0]	SFT_MDIO;
	wire			STATE_MDIO;

	assign	MDC		= O_RESET?	INIT_MDC:	SiTCP_MDC;
	assign	O_MDIO	= O_RESET?	INIT_MDO:	SiTCP_MDIO_OUT;
	assign	T_MDIO	= O_RESET?	INIT_MDT:	(~SiTCP_MDIO_OE);

	initial	CNT_1us[8:0]	= {1'b0,load_1us[7:0]};
	initial	CNT_100us[7:0]	= {1'b0,7'd99};
	initial	CNT_10ms[7:0]	= {1'b0,7'd99};
	always @( posedge CLOCK) begin
		CNT_1us[8:0]	<= CNT_1us[8]?		{1'b0,load_1us[7:0]}:	(CNT_1us[8:0] - 9'd1);
		CNT_100us[7:0]	<= CNT_100us[7]?	{1'b0,7'd99}:			(CNT_100us[7:0] - {7'd0,CNT_1us[8]});
		CNT_10ms[7:0]	<= CNT_10ms[7]?		{1'b0,7'd99}:			(CNT_10ms[7:0] - {7'd0,CNT_100us[7]});
	end
//
//	INIT_STATE
//		0000		PHY_nRESET = H	100us
//		0001		PHY_nRESET = L				  30ms
//		0010		PHY_nRESET = L	100us(It's not a waiting time)
//		0011		PHY_nRESET = H				 250ms
//		0100		PHY_nRESET = H	MDIO(0) <= 0x4040
//		0101		PHY_nRESET = H				1000ms
//		0110		PHY_nRESET = L	100us(It's not a waiting time)
//		0111		PHY_nRESET = L				  50ms
//		1000		PHY_nRESET = H	100us(It's not a waiting time)
//		1001		PHY_nRESET = H				1000ms
//		1010		PHY_nRESET = H	MDIO(0) <= 0x1340
//		1011		PHY_nRESET = H				1000ms
//		1100		PHY_nRESET = H	MDIO(0) <= 0x1340
//		1101		PHY_nRESET = H				1000ms
//		1110		PHY_nRESET = H	MDIO(0) <= 0x1340
//		1111		PHY_nRESET = H

	assign	STATE_MDIO	= (
		(INIT_STATE[3:0] == 4'b0100)|
		(INIT_STATE[3:0] == 4'b1010)|
		(INIT_STATE[3:0] == 4'b1100)|
		(INIT_STATE[3:0] == 4'b1110)
	);
	always @( posedge CLOCK or negedge I_nRESET) begin
		if (~I_nRESET) begin
			STATE_RUN		<= 1'b0;
			INIT_STATE[3:0]	<= 4'b0000;
			PHY_nRESET		<= 1'b1;
			O_RESET			<= 1'b1;
			INIT_MDC		<= 1'b1;
			INIT_MDT		<= 1'b1;
			INIT_MDO		<= 1'b1;
		end else begin
			STATE_RUN		<= STATE_RUN | CNT_100us[7];
			INIT_STATE[3:0]	<= STATE_INC?		(INIT_STATE[3:0] + 4'd1):	INIT_STATE[3:0];
			PHY_nRESET		<= ~(
				( INIT_STATE[3:0] == 4'b0001)|
				( INIT_STATE[3:0] == 4'b0010)|
				( INIT_STATE[3:0] == 4'b0110)|
				( INIT_STATE[3:0] == 4'b0111)
			);
			O_RESET			<= O_RESET & ~(INIT_STATE[3:0] == 4'b1111);
			INIT_MDC		<= STATE_MDIO?		(INIT_MDC ^ (CNT_1us[8] & ~(INIT_MDC & CNT_MDIO[6]))):	INIT_MDC;
			INIT_MDT		<= ENB_MDIO?	~CNT_MDIO[5]:	INIT_MDT;
			if (ENB_MDIO) begin
				INIT_MDO		<= CNT_MDIO[5]?		SFT_MDIO[31]:	1'b1;
			end
		end
	end
	always @( posedge CLOCK) begin
		INC_LOD[6:0]	<= (
			((INIT_STATE[3:1] == 3'b000)?	7'd2:		7'd0)|
			((INIT_STATE[3:1] == 3'b001)?	7'd24:		7'd0)|
			((INIT_STATE[3:1] == 3'b010)?	7'd99:		7'd0)|
			((INIT_STATE[3:1] == 3'b011)?	7'd4:		7'd0)|
			((INIT_STATE[3:1] == 3'b100)?	7'd99:		7'd0)|
			((INIT_STATE[3:1] == 3'b101)?	7'd99:		7'd0)|
			((INIT_STATE[3:1] == 3'b110)?	7'd99:		7'd0)|
			((INIT_STATE[3:1] == 3'b111)?	7'd0:		7'd0)
		);
		CNT_INC[7:0]	<= INIT_STATE[0]?	(CNT_INC[7:0] - {7'd0,CNT_10ms[7]}):	{1'b0,INC_LOD[6:0]};
		CNT_MDIO[6:0]	<= STATE_MDIO?			(CNT_MDIO[6:0] + {6'd0,ENB_MDIO}):		7'd0;
		STATE_INC	<= STATE_RUN & (
			((INIT_STATE[3:0] == 4'b0000) & CNT_100us[7])|
			((INIT_STATE[3:0] == 4'b0001) & CNT_INC[7] & CNT_10ms[7])|
			((INIT_STATE[3:0] == 4'b0010) & CNT_100us[7])|
			((INIT_STATE[3:0] == 4'b0011) & CNT_INC[7] & CNT_10ms[7])|
			((INIT_STATE[3:0] == 4'b0100) & CNT_MDIO[6]  & ENB_MDIO)|
			((INIT_STATE[3:0] == 4'b0101) & CNT_INC[7] & CNT_10ms[7])|
			((INIT_STATE[3:0] == 4'b0110) & CNT_100us[7])|
			((INIT_STATE[3:0] == 4'b0111) & CNT_INC[7] & CNT_10ms[7])|
			((INIT_STATE[3:0] == 4'b1000) & CNT_100us[7])|
			((INIT_STATE[3:0] == 4'b1001) & CNT_INC[7] & CNT_10ms[7])|
			((INIT_STATE[3:0] == 4'b1010) & CNT_MDIO[6]  & ENB_MDIO)|
			((INIT_STATE[3:0] == 4'b1011) & CNT_INC[7] & CNT_10ms[7])|
			((INIT_STATE[3:0] == 4'b1100) & CNT_MDIO[6]  & ENB_MDIO)|
			((INIT_STATE[3:0] == 4'b1101) & CNT_INC[7] & CNT_10ms[7])|
			((INIT_STATE[3:0] == 4'b1110) & CNT_MDIO[6]  & ENB_MDIO)
		);
		ENB_MDIO	<= STATE_MDIO & INIT_MDC & CNT_1us[8];
		if (ENB_MDIO) begin
			SFT_MDIO[31:0]	<= CNT_MDIO[5]?		{SFT_MDIO[30:0],1'b1}:		{2'b01,2'b01,PHY_ADDR[4:0],5'b0_0000,2'b11,(INIT_STATE[3]?	16'h1340:	16'h4040)};
		end
	end

endmodule
`default_nettype wire
