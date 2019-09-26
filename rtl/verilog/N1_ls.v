//###############################################################################
//# N1 - Lower Stack                                                            #
//###############################################################################
//#    Copyright 2018 - 2019 Dirk Heisswolf                                     #
//#    This file is part of the N1 project.                                     #
//#                                                                             #
//#    N1 is free software: you can redistribute it and/or modify               #
//#    it under the terms of the GNU General Public License as published by     #
//#    the Free Software Foundation, either version 3 of the License, or        #
//#    (at your option) any later version.                                      #
//#                                                                             #
//#    N1 is distributed in the hope that it will be useful,                    #
//#    but WITHOUT ANY WARRANTY; without even the implied warranty of           #
//#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
//#    GNU General Public License for more details.                             #
//#                                                                             #
//#    You should have received a copy of the GNU General Public License        #
//#    along with N1.  If not, see <http://www.gnu.org/licenses/>.              #
//###############################################################################
//# Description:                                                                #
//#    This module manages the RAM based lower parameter and return stacks.     #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 19, 2019                                                        #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_ls
  #(parameter   SP_WIDTH        =      12)                              //width of either stack pointer

   (//Clock and reset
    input  wire                             clk_i,                      //module clock
    input  wire                             async_rst_i,                //asynchronous reset
    input  wire                             sync_rst_i,                 //synchronous reset

    //Stack bus (wishbone)
    output wire                             sbus_cyc_o,                 //bus cycle indicator       +-
    output reg                              sbus_stb_o,                 //access request            |
    output reg                              sbus_we_o,                  //write enable              | initiator
    output wire [SP_WIDTH-1:0]              sbus_adr_o,                 //address bus               | to       
    output wire                             sbus_tga_ps_o,              //parameter stack access    | target	       
    output wire                             sbus_tga_rs_o,              //return stack access       |
    output wire [15:0]                      sbus_dat_o,                 //write data bus            |
    input  wire                             sbus_ack_i,                 //bus cycle acknowledge     +-
    input  wire                             sbus_err_i,                 //bus error response        | target to
    input  wire                             sbus_stall_i,               //access delay              | initiator
    input  wire [15:0]                      sbus_dat_i,                 //read data bus             +-

    //Internal signals
    //----------------
    //DSP interface
    output wire                             ls2dsp_psp_inc_o,           //increment PSP
    output wire                             ls2dsp_psp_dec_o,           //decrement PSP
    output wire                             ls2dsp_psp_load_o,          //load new PSP
    output wire [SP_WIDTH-1:0]              ls2dsp_psp_next_o,          //new PSP (load value)
    output wire                             ls2dsp_rsp_inc_o,           //increment RSP
    output wire                             ls2dsp_rsp_dec_o,           //decrement RSP
    output wire                             ls2dsp_rsp_load_o,          //load new RSP
    output wire [SP_WIDTH-1:0]              ls2dsp_rsp_next_o,          //new RSP (load value)
    input  wire [SP_WIDTH-1:0]              dsp2ls_psp_i,               //current PSP
    input  wire [SP_WIDTH-1:0]              dsp2ls_rsp_i,               //current RSP
								        
    //IPS interface
    //+-------------------------------------------+-----------------------------------+----------------------------------+
    //| Requests (mutually exclusive)             | Response on success               | Response on failure              |
    //+---------------------+---------------------+--------------------+--------------+--------------------+-------------+
    //| Type                | Input data          | Signals            | Output data  | Signals            | Cause       |
    //+---------------------+---------------------+--------------------+--------------+--------------------+-------------+
    //| Push to LPS         | cell data           | One or more cycles | none         | One or more cycles | LPS         |
    //| (ips2ls_push_req_i) | (ips2ls_req_data_i) | after the request: |              | after the request: | overflow    |
    //+---------------------+---------------------+                    +--------------+                    +-------------+
    //| Pull from LPS       | none                |  ls2ips_ack_o &    | cell data    |  ls2ips_ack_o &    | LPS         |
    //| (ips2ls_pull_req_i) |                     | ~ls2ips_fail_o     | (sbus_dat_i) |  ls2ips_fail_o     | underflow   |
    //+---------------------+---------------------+                    +--------------+--------------------+-------------+
    //| Overwrite PSP       | new PSP             |                    | none         | Every request is successful      |
    //| (ips2ls_wrsp_req_i) | (ips2ls_req_data_i) |                    |              |                                  |
    //+---------------------+---------------------+--------------------+--------------+----------------------------------+
    output wire                             ls2ips_ack_o,               //acknowledge push or pull request
    output wire                             ls2ips_fail_o,              //LPS over or underflow
    input  wire                             ips2ls_push_req_i,          //push request from IPS to LS
    input  wire                             ips2ls_pull_req_i,          //pull request from IPS to LS
    input  wire                             ips2ls_wrsp_req_i,          //request to set PSP
    input  wire [15:0]                      ips2ls_req_data_i,          //push data or new PSP value

    //IRS interface
    //+-------------------------------------------+-----------------------------------+----------------------------------+
    //| Requests (mutually exclusive)             | Response on success               | Response on failure              |
    //+---------------------+---------------------+--------------------+--------------+--------------------+-------------+
    //| Type                | Input data          | Signals            | Output data  | Signals            | Cause       |
    //+---------------------+---------------------+--------------------+--------------+--------------------+-------------+
    //| Push to LRS         | cell data           | One or more cycles | none         | One or more cycles | LRS         |
    //| (irs2ls_push_req_i) | (irs2ls_req_data_i) | after the request: |              | after the request: | overflow    |
    //+---------------------+---------------------+                    +--------------+                    +-------------+
    //| Pull from LRS       | none                |  ls2irs_ack_o &    | cell data    |  ls2irs_ack_o &    | LRS         |
    //| (irs2ls_pull_req_i) |                     | ~ls2irs_fail_o     | (sbus_dat_i) |  ls2irs_fail_o     | underflow   |
    //+---------------------+---------------------+                    +--------------+--------------------+-------------+
    //| Overwrite RSP       | new RSP             |                    | none         | Every request is successful      |
    //| (irs2ls_wrsp_req_i) | (irs2ls_req_data_i) |                    |              |                                  |
    //+---------------------+---------------------+--------------------+--------------+----------------------------------+
    output wire                             ls2irs_ack_o,               //acknowledge push or pull request
    output wire                             ls2irs_fail_o,              //LRS over or underflow
    input  wire                             irs2ls_push_req_i,          //push request from IRS to LS
    input  wire                             irs2ls_pull_req_i,          //pull request from IRS to LS
    input  wire                             irs2ls_wrsp_req_i,          //request to set RSP
    input  wire [15:0]                      irs2ls_req_data_i,          //push data or new RSP value

    //Probe signals
    output wire                             prb_ls_of_o,                //overflow condition
    output wire                             prb_ls_ps_o,                //PS operation
    output wire                             prb_ls_rs_o);               //RS operation

   //Internal signals
   //----------------
   //Status signals
   wire                                     lps_empty;                  //LPS is empty
   wire                                     lrs_empty;                  //LRS is empty
   wire                                     ls_overflow;                //stack overflow   
   reg                                      lrs_lps_b;                  //0:LPS, 1:LRS

   //LPS FSM
   reg [1:0] 				    state_lps_reg;              //LPS state
   reg [1:0] 				    state_lps_next;             //next LPS state
   
   //LRS FSM
   reg [1:0] 				    state_lps_reg;              //LPS state
   reg [1:0] 				    state_lps_next;             //next LPS state
   


   reg  				    state_sbus_reg;             //SBus state
   reg [1:0] 				    state_lps_reg;              //LPS state
   reg [1:0] 				    state_lrs_reg;              //LRS state
   reg  				    state_sbus_next;            //next SBus state
   reg [1:0] 				    state_lps_next;             //next LPS state
   reg [1:0] 				    state_lrs_next;             //next LRS state

   //Internal status signals
   //-----------------------
   assign lps_empty   = ~|dsp2ls_psp_i;                                 //PSP is zero
   assign lrs_empty   = ~|dsp2ls_rsp_i;                                 //RSP is zero
   assign ls_overflow = &(dsp2ls_psp_i^dsp2ls_rsp_i);                   //PSP == ~RSP 


   //Stack bus
   //---------
   assign sbus_cyc_o = sbus_stb_o;
   assign sbus_stb_o,                 //access request            | initiator
   assign sbus_we_o,                  //write enable              | to
   assign sbus_adr_o,                 //address bus
   assign sbus_tga_ps_o,              //parameter stack access
   assign sbus_tga_rs_o,              //return stack access
   assign sbus_dat_o,                 //write data bus            | target







   
   //FSMs
   //----
   //SBus
   localparam STATE_SBUS_IDLE         = 1'b0;
   localparam STATE_SBUS_ACK_PENDING  = 1'b1;		  


   //LPS
   localparam STATE_LPS_IDLE          = 2'b00;
   localparam STATE_LPS_SBUS          = 2'b01;
   localparam STATE_LPS_ERROR         = 2'b10;
   localparam STATE_LPS_ACK           = 2'b11;
   	
   always @*
     begin
	//Defaults
	ls2ips_ack_o   = 1'b0;    //no acknowledge
    output wire                             ls2excpt_psof_o,            //PS overflow
    output wire                             ls2excpt_rsof_o,            //RS overflow
	
	state_lps_next = state_lps_reg;

	
	case (state_lps_reg)
	  //LPS is idle
	  STATE_LPS_IDLE:
	    begin
	       //Push request
	       if (ips2ls_push_req_i)
		 begin
		    //Overflow
		    if (ls_overflow)
		      begin
			 ls2excpt_psof_o = 1'b1;
			 state_lps_next  = STATE_LPS_ERROR;
		      end
		    else
		    //SBus is rea  
		    if (&(state_lps_reg^STATE_LPS_SBUS) | sbus_ack_i
			



	    end
	  
	
	   




			       
   
   //LRS
   localparam STATE_LPRS_IDLE          = 2'b00;
   localparam STATE_LPRS_SBUS          = 2'b01;
   localparam STATE_LPRS_ERROR         = 2'b10;
   localparam STATE_LPRS_ACK           = 2'b11;





endmodule // N1_ls
