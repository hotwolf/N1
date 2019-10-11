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
//#    |             0 |               |<- Bottom of                             #
//#    |               |               |   the PS                                #
//#    |               |      PS       |                                         #
//#    |               |               |   Top of                                #
//#    |               |               |<- the PS                                #
//#    +               +---------------+                                         #
//#    |               |               |<- PSP                                   #
//#    |               |               |                                         #
//#    |               |     free      |                                         #
//#    |               |               |                                         #
//#    |               |               |<- ~RSP                                  #
//#    +               +---------------+                                         #
//#    |               |               |<- Top of                                #
//#    |               |               |   the RS                                #
//#    |               |      RS       |                                         #
//#    |               |               |   Bottom of                             #
//#    |(2^SP_WIDTH)-1 |               |<- the RS                                #
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
    output wire                             sbus_cyc_o,                           //bus cycle indicator       +-
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
    //+------------------+----------------------------------------+
    //| ls2dsp_psp_opr_o | Action                                 |
    //+------------------+----------------------------------------+
    //|      0   0       | add ls2dsp_psp_add_opd_o to PSP        |
    //+------------------+----------------------------------------+
    //|      0   1       | subtract ls2dsp_psp_add_opd_o from PSP |
    //+------------------+----------------------------------------+
    //|      1   x       | set PSP to ls2dsp_psp_set_opd_o        |
    //+------------------+----------------------------------------+
    output reg                              ls2dsp_psp_hold_o,                  //don't update PSP
    output reg  [1:0]                       ls2dsp_psp_opr_o,                   //PSP operator
    output wire [SP_WIDTH-1:0]              ls2dsp_psp_set_opd_o,               //PSP SET value
    output wire [SP_WIDTH-1:0]              ls2dsp_psp_add_opd_o,               //PSP CMP value
    //+------------------+----------------------------------------+
    //| ls2dsp_rsp_opr_o | Action                                 |
    //+------------------+----------------------------------------+
    //|      0   0       | add ls2dsp_rsp_add_opd_o to RSP        |
    //+------------------+----------------------------------------+
    //|      0   1       | subtract ls2dsp_rsp_add_opd_o from RSP |
    //+------------------+----------------------------------------+
    //|      1   x       | set RSP to ls2dsp_rsp_set_opd_o        |
    //+------------------+----------------------------------------+
    output reg                              ls2dsp_rsp_hold_o,                    //don't update RSP
    output reg  [1:0]                       ls2dsp_rsp_opr_o,                     //RSP operator
    output wire [SP_WIDTH-1:0]              ls2dsp_psp_set_opd_o,                 //PSP SET value
    output wire [SP_WIDTH-1:0]              ls2dsp_psp_add_opd_o,                 //PSP CMP value
    input  wire [SP_WIDTH-1:0]              dsp2ls_psp_i,                         //current PSP
    input  wire [SP_WIDTH-1:0]              dsp2ls_rsp_i,                         //current RSP
    input  wire [SP_WIDTH-1:0]              dsp2ls_psp_next_i,                    //next PSP
    input  wire [SP_WIDTH-1:0]              dsp2ls_rsp_next_i,                    //next RSP
    input  wire                             dsp2ls_psp_sign_i,                    //carry bit
    input  wire                             dsp2ls_rsp_sign_i,                    //carry bit

    //IPS interface
    output wire                             ls2ips_ready_o,                       //LPS is ready for the next command
    output wire                             ls2ips_overflow_o,                    //LPS overflow
    output wire                             ls2ips_empty_o,                       //LPS is empty
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
    output wire                             ls2irs_empty_o,                       //LRS is empty
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
   reg 					    lps_sbus_cyc;                           //bus cycle indicator from LPS
   reg 					    lps_sbus_stb;                           //bus request from LPS
   reg 					    lps_sbus_we;                            //write enable from LPS
   reg 					    lps_psp2sbus;                           //drive address from current PSP
   reg 					    lps_agu2sbus;                           //drive address from decremented PSP
   reg 					    lps_ips2sbus;                           //drive write data from IPS
   reg 					    lps_tos2sbus;                           //drive write data from buffered TOS
   reg 					    lrs_sbus_cyc;                           //bus cycle indicator from LRS
   reg 					    lrs_sbus_stb;                           //bus request from LRS
   reg 					    lrs_sbus_we;                            //write enable from LRS
   reg 					    lrs_rsp2sbus;                           //drive address from current RSP
   reg 					    lrs_agu2sbus;                           //drive address from decremented RSP
   reg 					    lrs_ips2sbus;                           //drive write data from IPS
   reg 					    lrs_tos2sbus;                           //drive write data from buffered TOS

   
  
   


   //Stack boundaries
   wire                                     lps_empty;                            //LPS is empty
   wire                                     lrs_empty;                            //LRS is empty
   wire                                     ls_overflow;                          //stack overflow

   //TOS buffers
   reg  [15:0]                              lps_tos_reg;                          //duplicate of the TOS in RAM
   reg  [15:0]                              lps_tos_next;                         //new TOS buffer value
   reg                                      lps_tos_we;                           //update TOS buffer
   reg  [15:0]                              lrs_tos_reg;                          //duplicate of the TOS in RAM
   reg  [15:0]                              lrs_tos_next;                         //new TOS buffer value
   reg                                      lrs_tos_we;                           //update TOS buffer

   //TOS buffer input selects
   reg                                      lps_ips2tos;                          //load TOS buffer from IS
   reg                                      lps_sbus2tos;                         //load TOS buffer from SBUS
   reg                                      lrs_irs2tos;                          //load TOS buffer from IS
   reg                                      lrs_sbus2tos;                         //load TOS buffer from SBUS  

   //Data output selects
   reg                                      lps_tos2ips;                          //return buffered TOS
   reg                                      lps_psp2ips;                          //return current PSP
   reg                                      lps_sbus2ips;                         //return SBUS read data
   reg                                      lrs_tos2irs;                          //return buffered TOS
   reg                                      lrs_rsp2irs;                          //return current PSP
   reg                                      lrs_sbus2irs;                         //return SBUS read data

   //Validateded requests
   wire                                     lps_pull_val;                         //validated LPS pull request
   wire                                     lps_push_val;                         //validated LPS push request
   wire                                     lrs_push_val;                         //validated LRS push request
   wire                                     lrs_pull_val;                         //validated LRS pull request

   //Arbitrated requests
   //wire                                     lps_pull_arb;                         //arbitrateded LPS pull request
   //wire                                     lps_push_arb;                         //arbitrateded LPS push request
   //wire                                     lrs_push_arb;                         //arbitrateded LRS push request
   //wire                                     lrs_pull_arb;                         //arbitrateded LRS pull request

   //SBUS requests
   wire                                     lps_sbus_stb;                         //SBUS request from LPS
   wire                                     lps_sbus_we;                          //SBUS write request from LPS
   wire                                     lrs_sbus_stb;                         //SBUS request from LRS
   wire                                     lrs_sbus_we;                          //SBUS write request from LRS
   


   
   //FSM state variables
   reg [2:0]                                lps_state_reg;                        //LPS state
   reg [2:0]                                lps_state_next;                       //next LPS state
   reg [2:0]                                lrs_state_reg;                        //LPS state
   reg [2:0]                                lrs_state_next;                       //next LPS state

   //FSM state shortcuts
   wire                                     lps_state_ack;                        //LPS in STATE_ACK
   wire                                     lps_state_ack_fail;                   //LPS in STATE_ACK_FAIL
   wire                                     lps_state_sbus;                       //LPS in STATE_SBUS
   wire                                     lps_state_sbus_fail;                  //LPS in STATE_SBUS_FAIL
   wire                                     lrs_state_ack;                        //LRS in STATE_ACK
   wire                                     lrs_state_ack_fail;                   //LRS in STATE_ACK_FAIL
   wire                                     lrs_state_sbus;                       //LRS in STATE_SBUS
   wire                                     lrs_state_sbus_fail;                  //LRS in STATE_SBUS_FAIL

   //Stack bus
   //---------
   assign sbus_cyc_o            = lps_sbus_cyc | lrs_sbus_cyc;                    //SBUS cycle from either stack
   assign sbus_stb_o            = lps_sbus_stb | lrs_sbus_stb;                    //SBUS request from either stack
   assign sbus_we_o             = lps_sbus_we  | lrs_sbus_we;                     //write access from either stack
   assign sbus_adr_o            = ({SP_WIDTH{lps_psp2sbus}} & dsp2ls_psp_i) |     //drive address bus from PSP
			          ({SP_WIDTH{lps_agu2sbus}} &                     //drive address from AGU
			                   dsp2ls_psp_next_i[SP_WIDTH-1:0]) |     //
                                  ({SP_WIDTH{lrs_rsp2sbus}} & dsp2ls_rsp_i) |     //drive address bus from RSP
			          ({SP_WIDTH{lrs_agu2sbus}} &                     //drive address from AGU
			        	   dsp2ls_rsp_next_i[SP_WIDTH-1:0]);      //
   assign sbus_tga_ps_o         =  lps_sbus_cyc                                   //parameter stack access
   assign sbus_tga_rs_o         = ~lps_sbus_cyc                                   //return stack access
   assign sbus_dat_o            = ({16{lps_ips2sbus}} & ips2ls_data_i) |          //drive write data from IPS
			          ({16{lps_tos2sbus}} & lps_tos_reg)   |          //drive write data from TOS
                                  ({16{lrs_irs2sbus}} & irs2ls_data_i) |          //drive write data from IRS
			          ({16{lrs_tos2sbus}} & lrs_tos_reg);             //drive write data from TOS
                                
   //DSP interface
   //-------------
   assign ls2dsp_psp_set_data_o = ips2ls_data_i;                //PSP SET value
   assign ls2dsp_psp_cmp_data_o = ;                //PSP CMP value
   assign ls2dsp_rsp_set_data_o = irs2ls_data_i;                //RSP SET value
   assign ls2dsp_rsp_cmp_data_o = ;                //RSP CMP value
 



   

   
   //Internal status signals
   //-----------------------
   //Stack boundaries
   assign ls_full             = &(dsp2ls_psp_i^dsp2ls_rsp_i);                     //stack pointer collision
   assign lps_empty           = ~|dsp2ls_psp_i;                                   //PSP is zero
   assign lrs_empty           = ~|dsp2ls_rsp_i;                                   //RSP is zero

   //Validated requests
   assign lps_pull_val        = ips2ls_pull_i & ~lps_empty;                       //validated LPS pull request (1st prio) 
   assign lrs_pull_val        = irs2ls_pull_i & ~lrs_empty;                       //validated LRS pull request (2nd prio)
   assign lps_push_val        = ips2ls_push_i & ~ls_overflow;                     //validated LPS push request (3rd prio)
   assign lrs_push_val        = irs2ls_push_i & ~ls_overflow;                     //validated LRS push request (4th prio)
   
   //Arbitrated requests
   assign lps_pull_arb        = lps_pull_val;                                     //arbitrateded LPS pull request (1st prio) 
   assign lrs_pull_arb        = lrs_pull_val & ~lps_pull_val;                     //arbitrateded LRS pull request (2nd prio)
   assign lps_push_arb        = lps_push_val & ~lrs_pull_val;                     //arbitrateded LPS push request (3rd prio)
   assign lrs_push_arb        = lrs_push_val & ~lps_pull_val &                    //arbitrateded LRS push request (4th prio)
                                               ~lps_push_val;

   //TOS buffers
   assign lps_tos_next        = ({16{lps_ips2tos}}  & ips2ls_data_i) |            //load TOS buffer from IS
				({16{lps_sbus2tos}} & sbus_dat_i);                //load TOS buffer from SBUS
   assign lrs_tos_next        = ({16{lrs_irs2tos}}  & irs2ls_data_i) |            //load TOS buffer from IS
				({16{lrs_sbus2tos}} & sbus_dat_i);                //load TOS buffer from SBUS







   reg                                      lps_ips2tos;                          //load TOS buffer from IS
   reg                                      lps_sbus2tos;                         //load TOS buffer from SBUS
   reg                                      lrs_irs2tos;                          //load TOS buffer from IS
   reg                                      lrs_sbus2tos;                         //load TOS buffer from SBUS  




   





   //State shortcuts
   assign lps_state_ack       = ~|(lps_state_reg ^ STATE_ACK);                    //LPS in STATE_ACK
   assign lps_state_ack_fail  = ~|(lps_state_reg ^ STATE_ACK_FAIL);               //LPS in STATE_ACK_FAIL
   assign lps_state_sbus      = ~|(lps_state_reg ^ STATE_SBUS);                   //LPS in STATE_SBUS
   assign lps_state_sbus_fail = ~|(lps_state_reg ^ STATE_SBUS_FAIL);              //LPS in STATE_SBUS_FAIL

   assign lrs_state_ack       = ~|(lrs_state_reg ^ STATE_ACK);                    //LRS in STATE_ACK
   assign lrs_state_ack_fail  = ~|(lrs_state_reg ^ STATE_ACK_FAIL);               //LRS in STATE_ACK_FAIL
   assign lrs_state_sbus      = ~|(lrs_state_reg ^ STATE_SBUS);                   //LRS in STATE_SBUS
   assign lrs_state_sbus_fail = ~|(lrs_state_reg ^ STATE_SBUS_FAIL);              //LRS in STATE_SBUS_FAIL


   //IPS interface
   //-------------
   assign ls2ips_full_o       = ls_full;                                          //LPS is full
   assign ls2ips_empty_o      = lps_empty;                                        //LPS is empty
   assign ls2ips_data_o       = ({16{lps_tos2ips}}  & lps_tos_reg)  |             //return buffered TOS
                                ({16{lps_psp2ips}}  & dsp2ls_psp_i) |             //return current PSP
                                ({16{lps_sbus2ips}} & sbus_dat_i );               //return SBUS read data
   

   //IRS interface
   //-------------
   assign ls2irs_full_o       = ls_full;                                          //LRS is full
   assign ls2irs_empty_o      = lrs_empty;                                        //LRS is empty
   assign ls2irs_data_o       = ({16{lrs_tos2irs}}  & lrs_tos_reg)  |             //return buffered TOS
                                ({16{lrs_rsp2irs}}  & dsp2ls_rsp_i) |             //return current RSP
                                ({16{lrs_sbus2irs}} & sbus_dat_i );               //return SBUS read data
   



   
   //DSP interface
   //-------------
   assign ls2dsp_psp_inc_o    =  lps_push_arb;                                    //increment PSP
   assign ls2dsp_psp_dec_o    =  ips2ls_pull_req_i;                               //decrement PSP
   assign ls2dsp_psp_set_o    =  ips2ls_set_req_i;                                //load new PSP
   assign ls2dsp_rsp_inc_o    =  lrs_push_arb;                                    //increment RSP
   assign ls2dsp_rsp_dec_o    =  irs2ls_pull_req_i;                               //decrement RSP
   assign ls2dsp_rsp_set_o    =  irs2ls_set_req_i;                                //load new RSP

   //Stack bus
   //---------
   assign sbus_stb_o          = ips2ls_push_req_i |                               //push request from IPS to LS
                                ips2ls_pull_req_i |                               //pull request from IPS to LS
                                irs2ls_push_req_i |                               //push request from IRS to LS
                                irs2ls_pull_req_i;                                //pull request from IRS to LS
   assign sbus_cyc_o          = sbus_stb_o          |                             //new push or pull request
                                lps_state_sbus      |                                 //ongoing LPS push or pull request
                                lps_state_sbus_fail |                             //ongoing LPS push or pull request
                                lrs_state_sbus      |                             //ongoing LPS push or pull request
                                lrs_state_sbus_fail;                                  //ongoing LRS push or pull request
   assign sbus_we_o           = lps_push_arb | lrs_push_arb ;                     //push request
   assign sbus_adr_o          = ({SP_WIDTH{lps_pull_arb}} &                       //decremented PSP
				               dsp2ls_psp_next_i[SP_WIDTH-1:0]) | //
                                ({SP_WIDTH{lrs_pull_arb}} &                       //decremented RSP
				               dsp2ls_rsp_next_i[SP_WIDTH-1:0]) | //
				({SP_WIDTH{lps_push_arb}} & dsp2ls_psp_i)       | //current PSP
                                ({SP_WIDTH{lrs_push_arb}} & dsp2ls_rsp_i);        //current RSP
   assign sbus_tga_ps_o       = lps_pull_arb | lps_push_arb;                      //parameter stack access
   assign sbus_tga_rs_o       = ~sbus_tga_ps_o;                                   //return stack access
   assign sbus_dat_o          = ({16{lps_push_arb}} & ips2ls_req_data_i) |        //push data from IPS
                                ({16{lrs_push_arb}} & irs2ls_req_data_i);         //push data from IRS

   //IPS interface
   //-------------
   assign ls2ips_ack_o        =  lps_state_ack                     |              //LPS in STATE_ACK
                                 lps_state_ack_fail                |              //LPS in STATE_ACK_FAIL
                                (lps_state_sbus      & sbus_ack_i) |              //LPS in STATE_SBUS
                                (lps_state_sbus_fail & sbus_ack_i);               //LPS in STATE_SBUS_FAIL
   assign ls2ips_fail_o       =  lps_state_ack_fail                |              //LPS in STATE_ACK_FAIL
                                (lps_state_sbus_fail & sbus_ack_i);               //LPS in STATE_SBUS_FAIL

   //IRS interface
   //-------------
   assign ls2irs_ack_o        =  lrs_state_ack                     |              //LRS in STATE_ACK
                                 lrs_state_ack_fail                |              //LRS in STATE_ACK_FAIL
                                (lrs_state_sbus      & sbus_ack_i) |              //LRS in STATE_SBUS
                                (lrs_state_sbus_fail & sbus_ack_i);               //LRS in STATE_SBUS_FAIL
   assign ls2irs_fail_o       =  lrs_state_ack_fail                |              //LRS in STATE_ACK_FAIL
                                (lrs_state_sbus_fail & sbus_ack_i);               //LRS in STATE_SBUS_FAIL

   //FSMs
   //----
   //LPS state transitions
   always @*
     begin
        //Defaults
	
	



        ls2dsp_psp_hold_o    = 1'b1;                                             //don't update PSP
        lps_state_next       = 0;                                    //stay in current state

        //Handle incoming requests
	if (lps_pull_val)
	  //Valid pull request
	  begin
	     lps_tos2ips = 1'b1;
	    



	     




	  end

	if (lps_push_val)
	  //Valid push request
	  begin
	     lps_ips2tos = 1'b1;
	     lps_tos_we  = 1'b1;
	     

	     




	  end
	
	if (ips2ls_set_i)
	  //Set request
	  begin
	     ls2dsp_rsp_opr_o = DSP_CMP_PSP;
	     




	  end

	if (ips2ls_get_i)
	  //Get request
	  begin
	     lps_psp2ips = 1'b1;




	  end

	if (~lps_pull_val &
	    ~lps_push_val &
	    ~ips2ls_set_i &
	    ~ips2ls_get_i)
	  //No request
	  begin



	     lps_state_next = lps_state_next | STATE_IDLE;
	  end

	

	





       if (~lps_state_sbus | sbus_ack_i)
          begin

             //Simplify logic, because of one-hot encoding
             lps_state_next = 3'b000;                                            //clear bits

             //IPS pull request
             if (lps_pull_arb)
               begin
                  //IPS pull request on empty stack
                  if (lps_pull_fail_cond)
                    begin
                       lps_state_next |= STATE_ACK_FAIL;                         //flag failure in next cycle
                    end
                  //IPS pull request on non-empty stack
                  else
                    begin
                       //SBUS is ready
                       if (~sbus_stall_i)
                         begin
                            ls2dsp_psp_hold_o  = 1'b1;                           //update PSP
                            lps_state_next    |= STATE_SBUS;                     //track SBUS access
                         end
                    end
               end // if (lps_pull_arb)

             //IPS push request
             if (lps_push_arb)
               begin
                  //SBUS is ready
                  if (~sbus_stall_i)
                    begin
                       ls2dsp_psp_hold_o = 1'b1;                                 //update PSP
                       //IPS push request with overflow condition
                       if (lps_pull_fail_cond)
                         begin
                            lps_state_next |= STATE_SBUS_FAIL;                   //track SBUS access and signal failure
                         end
                       //IPS push request without overflow condition
                       else
                         begin
                            lps_state_next |= STATE_SBUS;                        //track SBUS access and signal failure
                         end
                    end // if (~sbus_stall_i)
                  //SBUS is not ready
                  else
                    begin
                       lps_state_next |= STATE_IDLE0;                            //move back to idle state
                    end
               end // if (lps_push_arb)

             //IPS set request
             if (ips2ls_set_req_i)
               begin
                  lps_state_next |= STATE_ACK;                                   //flag success in next cycle
               end

             //No request
             if (~lps_pull_arb &
                 ~lps_push_arb &
                 ~lps_push_arb)
               begin
                  lps_state_next |= STATE_IDLE0;                                 //clear bits
               end

          end // if (~lps_state_sbus | sbus_ack_i)
     end // always @ *
   
   //LPS state variables
   always @(posedge async_rst_i or posedge clk_i)
     begin  
        if (async_rst_i)                                                         //asynchronous reset
          begin
             lps_state_reg <= STATE_IDLE0;                                       //reset state
          end
        else if (sync_rst_i)                                                     //synchronous reset
          begin
             lps_state_reg <= STATE_IDLE0;                                       //reset state
          end
        else                                                                     //state transition
          begin
             lps_state_reg <= lps_state_next;                                    //next state
          end
     end

   //LRS state transitions
   always @*
     begin
        //Defaults
        ls2dsp_rsp_hold_o    = 1'b1;                                             //don't update RSP
        lrs_state_next       = lrs_state_reg;                                    //stay in current state

        //Handle incomming requests
        if (~lrs_state_sbus | sbus_ack_i)
          begin

             //Simplify logic, because of one-hot encoding
             lrs_state_next = 3'b000;                                            //clear bits

             //IRS pull request
             if (lrs_pull_arb)
               begin
                  //IRS pull request on empty stack
                  if (lrs_pull_fail_cond)
                    begin
                       lrs_state_next |= STATE_ACK_FAIL;                         //flag failure in next cycle
                    end
                  //IRS pull request on non-empty stack
                  else
                    begin
                       //SBUS is ready
                       if (~sbus_stall_i)
                         begin
                            ls2dsp_rsp_hold_o  = 1'b1;                           //update RSP
                            lrs_state_next    |= STATE_SBUS;                     //track SBUS access
                         end
                    end
               end // if (lrs_pull_arb)

             //IRS push request
             if (lrs_push_arb)
               begin
                  //SBUS is ready
                  if (~sbus_stall_i)
                    begin
                       ls2dsp_rsp_hold_o = 1'b1;                                 //update RSP
                       //IRS push request with overflow condition
                       if (lrs_pull_fail_cond)
                         begin
                            lrs_state_next |= STATE_SBUS_FAIL;                   //track SBUS access and signal failure
                         end
                       //IRS push request without overflow condition
                       else
                         begin
                            lrs_state_next |= STATE_SBUS;                        //track SBUS access and signal failure
                         end
                    end // if (~sbus_stall_i)
                  //SBUS is not ready
                  else
                    begin
                       lrs_state_next |= STATE_IDLE0;                            //move back to idle state
                    end
               end // if (lrs_push_arb)

             //IRS set request
             if (irs2ls_set_req_i)
               begin
                  lrs_state_next |= STATE_ACK;                                   //flag success in next cycle
               end

             //No request
             if (~lrs_pull_arb &
                 ~lrs_push_arb &
                 ~lrs_push_arb)
               begin
                  lrs_state_next |= STATE_IDLE0;                                 //clear bits
               end

          end // if (~lrs_state_sbus | sbus_ack_i)
     end // always @ *

   //LRS state variables
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                         //asynchronous reset
          begin
             lrs_state_reg <= STATE_IDLE0;                                       //reset state
          end
        else if (sync_rst_i)                                                     //synchronous reset
          begin
             lrs_state_reg <= STATE_IDLE0;                                       //reset state
          end
        else                                                                     //state transition
          begin
             lrs_state_reg <= lrs_state_next;                                    //next state
          end
     end

   //Probe signals
   //-------------
   assign prb_lps_state_o     = lps_state_reg;                                  //LPS state
   assign prb_lrs_state_o     = lrs_state_reg;                                  //LRS state 
 
endmodule // N1_ls
