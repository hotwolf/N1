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
//#    This module implements the RAM based lower parameter (LPS) and return    #
//#    stack (LRS).                                                             #
//#    Both stacks are allocated to trhe same address space, growing towards    #
//#    each other. The stack pointers PSP and RSP show the number of cells on   #
//#    each stack. Therefore PSP and ~RSP (bitwise inverted RSP) point to the   #
//#    next free location of the corresponding stack.                           #
//#    Overflows are only detected when both stacks overlap                     #
//#    Underflows are only detected when a pull operation is attempted on an    #
//#    empty stack.                                                             #
//#                                                                             #
//#                       Stack RAM                                             #
//#                   +---------------+                                         #
//#                 0 |               |<- Bottom of                             #
//#                   |               |   the PS                                #
//#                   |      PS       |                                         #
//#                   |               |   Top of                                #
//#                   |               |<- the PS                                #
//#                   +---------------+                                         #
//#                   |               |<- PSP                                   #
//#                   |               |                                         #
//#                   |     free      |                                         #
//#                   |               |                                         #
//#                   |               |<- ~RSP                                  #
//#                   +---------------+                                         #
//#                   |               |<- Top of                                #
//#                   |               |   the RS                                #
//#                   |      RS       |                                         #
//#                   |               |   Bottom of                             #
//#    (2^SP_WIDTH)-1 |               |<- the RS                                #
//#                   +---------------+                                         #
//#                                                                             #
//#    Both stacks support the following operations:                            #
//#       PUSH: Push one cell to the TOS                                        #
//#       PULL:  Pull one cell from the TOS                                     #
//#       PUSH:  Push one cell to the TOS                                       #
//#       SET:   Set the PS to the value found at the TOS                       #
//#       GET:   Push the PS to the TOS                                         #
//#       RESET: Clear the stack                                                #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 19, 2019                                                        #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_ls
  #(parameter SP_WIDTH = 12)                                                      //width of either stack pointer

   (//Clock and reset
    input  wire                             clk_i,                                //module clock
    input  wire                             async_rst_i,                          //asynchronous reset
    input  wire                             sync_rst_i,                           //synchronous reset

    //Stack bus (wishbone)
    output reg                              sbus_cyc_o,                           //bus cycle indicator       +-
    output wire                             sbus_stb_o,                           //access request            |
    output wire                             sbus_we_o,                            //write enable              | initiator
    output wire [SP_WIDTH-1:0]              sbus_adr_o,                           //address bus               | to
    output wire                             sbus_tga_ps_o,                        //parameter stack access    | target
    output wire                             sbus_tga_rs_o,                        //return stack access       |
    output wire [15:0]                      sbus_dat_o,                           //write data bus            |
    input  wire                             sbus_ack_i,                           //bus cycle acknowledge     +-
    input  wire                             sbus_stall_i,                         //access delay              | initiator
    input  wire [15:0]                      sbus_dat_i,                           //read data bus             +-

    //Internal interfaces
    //-------------------
    //DSP interface
    output wire                             ls2dsp_sp_opr_o,                      //0:inc, 1:dec
    output wire [SP_WIDTH-1:0]              ls2dsp_sp_sel_o,                      //0:PSP, 1:RSP
    output wire [SP_WIDTH-1:0]              ls2dsp_psp_o,                         //PSP
    output wire [SP_WIDTH-1:0]              ls2dsp_rsp_o,                         //RSP
    input  wire                             dsp2ls_overflow_i,                    //stacks overlap
    input  wire                             dsp2ls_sp_carry_i,                    //carry of inc/dec operation
    input  wire [SP_WIDTH-1:0]              dsp2ls_sp_next_i,                     //next PSP or RSP

    //IPS interface
    output wire                             ls2ips_ready_o,                       //LPS is ready for the next command
    output wire                             ls2ips_overflow_o,                    //LPS overflow
    output wire                             ls2ips_underflow_o,                   //LPS underflow
    output wire [15:0]                      ls2ips_pull_data_o,                   //LPS pull data
    input  wire                             ips2ls_push_i,                        //push cell from IPS to LS
    input  wire                             ips2ls_pull_i,                        //pull cell from IPS to LS
    input  wire                             ips2ls_set_i,                         //set PSP
    input  wire                             ips2ls_get_i,                         //get PSP
    input  wire                             ips2ls_reset_i,                       //reset PSP
    input  wire [15:0]                      ips2ls_push_data_i,                   //LPS push data

    //IRS interface
    output wire                             ls2irs_ready_o,                       //LRS is ready for the next command
    output wire                             ls2irs_overflow_o,                    //LRS overflow
    output wire                             ls2irs_underflow_o,                   //LRS underflow
    output wire [15:0]                      ls2irs_pull_data_o,                   //LRS pull data
    input  wire                             irs2ls_push_i,                        //push cell from IRS to LS
    input  wire                             irs2ls_pull_i,                        //pull cell from IRS to LS
    input  wire                             irs2ls_set_i,                         //set RSP
    input  wire                             irs2ls_get_i,                         //get RSP
    input  wire                             irs2ls_reset_i,                       //reset RSP
    input  wire [15:0]                      irs2ls_push_data_i,                   //LRS push data

   //Probe signals
    output wire [2:0]                       prb_lps_state_o,                      //LPS state
    output wire [2:0]                       prb_lrs_state_o);                     //LRS state 
    output wire [15:0]                      prb_lps_tos_o,                        //LPS TOS
    output wire [15:0]                      prb_lrs_tos_o,                        //LRS TOS 
    output wire                             prb_ls_overflow_o);                   //LS overflow

   //Internal signals
   //----------------
   //PSP
   reg  [SP_WIDTH-1:0]                      psp_reg;                              //current PSP
   reg  [SP_WIDTH-1:0]                      psp_next;                             //next PSP
   reg                                      psp_we;                               //write enable

   //RSP
   reg  [SP_WIDTH-1:0]                      rsp_reg;                              //current RSP
   reg  [SP_WIDTH-1:0]                      rsp_next;                             //next RSP
   reg                                      rsp_we;                               //write enable
   wire [SP_WIDTH-1:0]                      rsp_b;                                //inverted RSP (cell count)

   //LPS TOS buffer
   reg  [15:0]                              lps_tos_reg;                          //duplicate of the TOS in RAM
   reg  [15:0]                              lps_tos_next;                         //new TOS buffer value
   reg                                      lps_tos_we;                           //update TOS buffer

   //LRS TOS buffer
   reg  [15:0]                              lrs_tos_reg;                          //duplicate of the TOS in RAM
   reg  [15:0]                              lrs_tos_next;                         //new TOS buffer value
   reg                                      lrs_tos_we;                           //update TOS buffer

   //LPS SBUS signals 
   reg                                      lps_sbus_cyc;                         //bus cycle indicator 
   reg                                      lps_sbus_stb;                         //access request      
   reg                                      lps_sbus_we;                          //write enable        
   reg  [SP_WIDTH-1:0]                      lps_sbus_adr;                         //address bus         					    
   wire                                     lps_sbus_ack;                         //bus cycle acknowledge
   wire                                     lps_sbus_stall;                       //access delay         
   wire [15:0]                              lps_sbus_dat;                         //read data bus        

   //LRS SBUS signals 
   reg                                      lrs_sbus_cyc;                         //bus cycle indicator 
   reg                                      lrs_sbus_stb;                         //access request      
   reg                                      lrs_sbus_we;                          //write enable        
   reg  [SP_WIDTH-1:0]                      lrs_sbus_adr;                         //address bus         					    
   wire                                     lrs_sbus_ack;                         //bus cycle acknowledge
   wire                                     lrs_sbus_stall;                       //access delay         
   wire [15:0]                              lrs_sbus_dat;                         //read data bus        

   //SAGU signals
   reg                                      sp_sel;				   //0:PSP, 1:RSP  
   reg                                      lps_sp_opr;                            //0:inc, 1:dec
   reg                                      lrs_sp_opr;                            //0:inc, 1:dec

   //IS signals
   reg                                      lps_pull_data_sel;                    //0:TOS, 1:SBUS
   reg                                      lrs_pull_data_sel;                    //0:TOS, 1:SBUS
   					    
   //FSM
   reg  [2:0] 				    state_lps_reg;			  //current LPS state
   reg  [2:0] 				    state_lps_next;                       //next LPS state
   reg  [2:0] 				    state_lrs_reg;			  //current LRS state
   reg  [2:0] 				    state_lrs_next;			  //next LRS state
   
   //SBUS (wishbone)
   //---------------
   assign sbus_cyc_o          =  lps_sbus_cyc | lrs_sbus_cyc;                     //bus cycle indicator     
   assign sbus_stb_o          =  lps_sbus_stb | lrs_sbus_stb;                     //access request          
   assign sbus_we_o           =  lps_sbus_stb ? lps_sbus_we  : lrs_sbus_stb;      //write enable            
   assign sbus_adr_o          =  lps_sbus_stb ? lps_sbus_adr : lrs_sbus_adr;      //address bus             
   assign sbus_tga_ps_o       =  lps_sbus_stb;                                    //parameter stack access  
   assign sbus_tga_rs_o       = ~lps_sbus_stb;                                    //return stack access     
   assign sbus_dat_o          =  lps_sbus_stb ? lps_sbus_dat : lrs_sbus_dat;      //write data bus          
				 
   //DSP interface
   //-------------
   assign ls2dsp_sp_opr_o     = sp_sel ? lrs_SP_opr : lps_sp_opr;                 //0:inc, 1:dec
   assign ls2dsp_sp_sel_o     = sp_sel;                                           //0:PSP, 1:RSP
   assign ls2dsp_psp_o        = psp_reg;                                          //PSP
   assign ls2dsp_rsp_o        = rsp_reg;                                          //RSP

    //IPS interface
    //--------------------
    assign ls2ips_overflow_o  = dsp2ls_overflow_i;                                //LPS overflow
    assign ls2ips_underflow_o = ~|psp_reg;                                        //LPS underflow
    assign ls2ips_pull_data_o = lps_pull_data_sel ? sbus_dat_i : lps_tos_reg;     //LPS pull data

    //IRS interface
    //--------------------
    assign ls2irs_overflow_o  = dsp2ls_overflow_i;                                //LRS overflow
    assign ls2irs_underflow_o = &rsp_reg;                                         //LRS underflow
    assign ls2irs_pull_data_o = lrs_pull_data_sel ? sbus_dat_i : lrs_tos_reg;     //LRS pull data

    












   
   //SBUS FSM
   //--------
   localparam                               STATE_SBUS_IDLE     = 2'b00;          //SBUS is idle
   localparam                               STATE_SBUS_LPS      = 2'b01;          //LPS access ongoing
   localparam                               STATE_SBUS_LRS      = 2'b10;          //LRS access ongoing
   localparam                               STATE_SBUS_DUMMY    = 2'b11;          //unreachable
  
   //LPS FSM
   //-------
   localparam                               STATE_LPS_IDLE      = 2'b00;          //LPS is idle
   localparam                               STATE_LPS_PUSH      = 2'b01;          //LPS push operation ongoing
   localparam                               STATE_LPS_PULL      = 2'b10;          //LRS pull operation ongoing
   localparam                               STATE_LPS_DUMMY     = 2'b11;          //unreachable

    always @*
     begin
        //Defaults
	psp_next            = {SP_WIDTH{1'b0}};                                   //next PSP
	psp_we              = 1'b0;                                               //update PSP
        lps_tos_next        = 16'h0000;                                           //new TOS buffer value
        lps_tos_we          = 1'b0;                                               //update TOS buffer
	lrs_sbus_stb        = 1'b0;                                               //bus request
        lrs_sbus_we         = 1'b0;                                               //write enable
        lps_sbus_adr        = {SP_WIDTH{1,b1}};                                   //address bus
        lps_agu_opr         = 1'b01;                                              //0:inc, 1:dec
        lps_sbus_dat        = 16'h0000;                                           //write data bus
							  
							  

	
	state_lps_next      = 2'b00;                                              //next LPS state
	
	//Handle requests
	if (ips2ls_push_i)
	  //Push to LPS
	  begin
	     psp_next       = psp_next | dsp2ls_sp_next_i;                       //next PSP
 	     lps_tos_next   = lps_tos_next | ips2ls_push_data_i;                 //new TOS buffer value
	     lps_tos_we     = 1'b1;                                              //update TOS buffer
	     lps_sbus_stb   = 1'b1;                                              //bus request
             lps_sbus_we    = 1'b1;                                              //write enable
	     lps_sbus_adr   = lps_sbus_adr | psp_reg;                            //address bus
             lps_sbus_dat   = ips2ls_push_data_i;                                //write data bus
             lps_agu_opr    = 1'b1;                                              //0:inc, 1:dec
	     if (lps_sbus_stall)                                                 //bus is busy  
	       //SBUS busy
	       begin
		  state_lps_next = state_lps_next | STATE_LPS_PUSH_STALL;        //wait while stall
	       end
	     else
	       //SBUS free
	       begin     
		  psp_we         = 1'b1;                                          //update PSP
		  state_lps_next = state_lps_next | STATE_LPS_PUSH_ACK;          //wait for ack
	       end		   
	  end // if (ips2ls_push_i)

	if (ips2ls_pull_i)
	  //Pull from LPS
	  begin
	     lps_sbus_stb   = 1'b1;                                              //bus request
	     lps_sbus_adr   = lps_sbus_adr | dsp2ls_sp_next_i;                   //address bus
	     if (lps_sbus_stall)                                                 //bus is busy  
	       //SBUS busy
	       begin
		  state_lps_next = state_lps_next | STATE_LPS_PULL_STALL;        //wait while stall
	       end
	     else
	       //SBUS free
	       begin     
		  state_lps_next = state_lps_next | STATE_LPS_PULL_ACK;          //wait for ack
	       end		   
	  end // if (ips2ls_pull_i)
	
	if (ips2ls_set_i)
	  //Set PSP
	  begin
	     psp_next       = psp_next | ips2ls_push_data_i[SP_WIDTH-1:0];        //next PSP
	     psp_we         = 1'b1;                                               //update PSP
	     state_lps_next = state_lps_next | STATE_LPS_IDLE;                    //next LPS state
          end

	if (ips2ls_get_i)
	  //Get PSP
	  begin
	     lps_tos_next   = lps_tos_next | psp_reg;                            //new TOS buffer value
	     lps_tos_we     = 1'b1;                                              //update TOS buffer
	     state_lps_next = state_lps_next | STATE_LPS_IDLE;                   //next LPS state
          end

	if (ips2ls_reset_i)
	  //Reset LPS
	  begin
	     psp_we         = 1'b1;                                               //update PSP
	     state_lps_next = state_lps_next | STATE_LPS_IDLE;                    //next LPS state
          end
	
	//Manage states
	case (state_lps_reg)
	  STATE_IDLE,
	  STATE_IDLE_DUMMY0,
	  STATE_IDLE_DUMMY1,
	  STATE_IDLE_DUMMY2:
	    begin
	    end

	  STATE_LPS_PUSH_STALL:
	    begin
	       psp_next     = psp_next | dsp2ls_sp_next_i;                       //next PSP
 	       lps_tos_next = lps_tos_next | ips2ls_push_data_i;                  //new TOS buffer value
	       lps_tos_we   = 1'b1;                                               //update TOS buffer
	       lps_sbus_stb = 1'b1;                                               //bus request
               lps_sbus_we  = 1'b1;                                               //write enable
	       lps_sbus_adr = lps_sbus_adr | psp_reg;                             //address bus
               lps_sbus_dat = ips2ls_push_data_i;                                 //write data bus
               lps_agu_opr  = 1'b1;                                               //0:inc, 1:dec
	       if (lps_sbus_stall)                                                //bus is busy  
		 //SBUS busy
		 begin
		    state_lps_next = state_lps_next | STATE_LPS_PUSH_STALL;       //wait while stall
		 end
	       else
		 //SBUS free
		 begin     
		    psp_we         = 1'b1;                                          //update PSP
		    state_lps_next = state_lps_next | STATE_LPS_PUSH_ACK;         //wait for ack
		 end		   
	    end // case: STATE_LPS_PUSH_STALL
	  

	  STATE_LPS_PUSH_ACK:
	    begin
	       if (~lps_sbus_ack)
		 //No ACK received
		 begin





		 end
	    end // case: STATE_LPS_PUSH_ACK
	  



     end // always @ *
   

   
   //LRS FSM
   //-------
   localparam                               STATE_LRS_IDLE      = 2'b00;          //LPS is idle
   localparam                               STATE_LRS_PUSH      = 2'b01;          //LPS push operation ongoing
   localparam                               STATE_LRS_PULL      = 2'b10;          //LRS pull operation ongoing
   localparam                               STATE_LRS_DUMMY     = 2'b11;          //unreachable
  








   
  always @*
     begin
        //Defaults
        sbus_cyc_o    = lps_sbus_stb | lrs_sbus_stb;                              //bus cycle indicator
        sbus_stb_o    = lps_sbus_stb | lrs_sbus_stb;                              //access request 
        sbus_we_o     = lps_sbus_stb ? lps_sbus_we                           //write enable              | initiator
        sbus_adr_o    =                           //address bus               | to
        sbus_tga_ps_o =                         //parameter stack access    | target
        sbus_tga_rs_o =                         //return stack access       |
        sbus_dat_o    =                           //write data bus            |
	
	

	//Handle requests
	if (ips2ls_push_i)
	  //Push request
	  begin
	     


	      
	  end
	


   
   
   //FSM state encoding
   //------------------
   //localparam                               STATE_IDLE0     = 3'b000;             //idle, no response pending
   //localparam                               STATE_IDLE1     = 3'b100;             //idle, no response pending
   //localparam                               STATE_IDLE2     = 3'b010;             //idle, no response pending
   //localparam                               STATE_IDLE3     = 3'b110;             //idle, no response pending
   //localparam                               STATE_ACK       = 3'b010;             //signal success
   //localparam                               STATE_ACK_FAIL  = 3'b110;             //signal failure
   //localparam                               STATE_SBUS      = 3'b011;             //wait for SBUS and signal success
   //localparam                               STATE_SBUS_FAIL = 3'b111;             //wait for SBUS and signal failure

   //Internal signals
   //----------------
   //SBUS control signals
   //reg 					    lps_sbus_cyc;                           //bus cycle indicator from LPS
   //reg 					    lps_sbus_stb;                           //bus request from LPS
   //reg 					    lps_sbus_we;                            //write enable from LPS
   //reg 					    lps_psp2sbus;                           //drive address from current PSP
   //reg 					    lps_agu2sbus;                           //drive address from decremented PSP
   //reg 					    lps_ips2sbus;                           //drive write data from IPS
   //reg 					    lps_tos2sbus;                           //drive write data from buffered TOS
   //reg 					    lrs_sbus_cyc;                           //bus cycle indicator from LRS
   //reg 					    lrs_sbus_stb;                           //bus request from LRS
   //reg 					    lrs_sbus_we;                            //write enable from LRS
   //reg 					    lrs_rsp2sbus;                           //drive address from current RSP
   //reg 					    lrs_agu2sbus;                           //drive address from decremented RSP
   //reg 					    lrs_ips2sbus;                           //drive write data from IPS
   //reg 					    lrs_tos2sbus;                           //drive write data from buffered TOS

   



   //LPS TOS buffer
   reg  [15:0]                              lps_tos_reg;                          //duplicate of the TOS in RAM
   reg  [15:0]                              lps_tos_next;                         //new TOS buffer value
   reg                                      lps_tos_we;                           //update TOS buffer

   //LRS TOS buffer
   reg  [15:0]                              lrs_tos_reg;                          //duplicate of the TOS in RAM
   reg  [15:0]                              lrs_tos_next;                         //new TOS buffer value
   reg                                      lrs_tos_we;                           //update TOS buffer

   //Stack boundaries
   wire                                     lps_empty;                            //LPS is empty
   wire                                     lrs_empty;                            //LRS is empty
   wire                                     ls_overflow;                          //stack overflow



   //Stack bus (wishbone)



   assign sbus_adr_o     = ls_adr_sel ?                                           //address bus
			   (lps_adr_inc ? dsp2ls_psp_i : dsp2ls_psp_next_i) :
			   (lrs_adr_inc ? dsp2ls_rsp_i : dsp2ls_rsp_next_i)



   assign sbus_tga_ps_o  = ~ls_adr_sel;                                           //parameter stack access
   assign sbus_tga_rs_o  =  ls_adr_sel;                                           //return stack access
   assign sbus_dat_o     = ;                                                      //write data bus
  



   //IPS interface
   //assign ls2ips_overflow_o  = ls_overflow;                                       //LPS is full or overflowing
   //assign ls2ips_underflow_o     = lps_empty;                                         //LPS is empty
   //assign ls2ips_pull_data_o = lps_pull_data_sel ?  lps_tos_reg : sbus_dat_i;     //LPS pull data
			     
   //IRS interface
   assign ls2irs_overflow_o  = ls_overflow;                                      //LRS is full or overflowing
   assign ls2irs_underflow_o     = lrs_empty;                                        //LRS is empty
   assign ls2irs_pull_data_o = lrs_pull_data_sel ?  lrs_tos_reg : sbus_dat_i;    //LRS pull data

   //Stack boundaries
   assign lps_empty          = ~|dsp2ls_psp_i;                                   //LPS is empty
   assign lrs_empty          = ~|dsp2ls_rsp_i;                                   //LRS is empty
   assign ls_overflow        = dsp2ls_psp_carry_i | dsp2ls_rsp_carry_i;    //stack overflow






   //FSMs
   //----
   //LPS state transitions
   always @*
     begin
        //Defaults
	
	

	//Handle requests
	if (ips2ls_push_i)
	  //Push request
	  begin
	     


	      
	  end
	
	

   
   

   //Probe signals
   //-------------
   assign prb_lps_state_o     = lps_state_reg;                                    //LPS state
   assign prb_lrs_state_o     = lrs_state_reg;                                    //LRS state 
   assign prb_lps_tos_o       = lps_tos_reg;                                      //LPS TOS
   assign prb_lrs_tos_o       = lrs_tos_reg;                                      //LRS TOS 
 
endmodule // N1_ls
