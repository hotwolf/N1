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
//#    Both stacks are allocated to trhe same address space, growong towards    #
//#    each other. The stack pointers PSP and RSP show the number of cells on   #
//#    each stack. Therefore PSP and ~RSP (bitwise inverted RSP) point to the   #
//#    next free location of the corresponding stack.                           #
//#    Overflows are only detected when PSP and ~RSP reach a given safety       #
//#    distance during a push operation. In this case, the overflow condition   #
//#    is flagged to the IS while the push operation is performed.              #
//#    Underflows are only detected when a pull operation is attempted on an    #
//#    empty stack. In this case, the underflow condition is flagged to the IS  #
//#    and the push operation is inhibited.                                     #
//#                                                                             #
//#                       Stack RAM                                             #
//#                   +---------------+                                         #
//#    |             0 |               |<- Bottom of                             #
//#    |               |               |   the PS                                #
//#    |               |      PS       |                                         #
//#    |               |               |   Top of                                #
//#    |               |               |<- the PS                                #
//#    +               +---------------+                                         #
//#    |               | ^ Safety      |<- PSP                                   #
//#    |               | | disdtance   |                                         #
//#    |               | v to ~RSP     |                                         #
//#    |               |...............|                                         #
//#    |               |               |                                         #
//#    |               |               |                                         #
//#    |               |               |                                         #
//#    |               |...............|                                         #
//#    |               | ^ Safety      |                                         #
//#    |               | | disdtance   |                                         #
//#    |               | v to PSP      |<- ~RSP                                  #
//#    +               +---------------+                                         #
//#    |               |               |<- Top of                                #
//#    |               |               |   the RS                                #
//#    |               |      RS       |                                         #
//#    |               |               |   Bottom of                             #
//#    |(2^SP_WIDTH)-1 |               |<- the RS                                #
//#                   +---------------+                                         #
//#                                                                             #
//#    SBus access priority:                                                    #
//#    Concurrent push or pull requests for the two stacks will be executed in  #
//#    the following order:                                                     #
//#                         1. Pull request to LPS                              #
//#                         2. Pull request to LRS                              #
//#                         3. Push request to LPS                              #
//#                         4. Push request to LRS                              #
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
    output reg                              sbus_stb_o,                           //access request            |
    output reg                              sbus_we_o,                            //write enable              | initiator
    output wire [SP_WIDTH-1:0]              sbus_adr_o,                           //address bus               | to
    output wire                             sbus_tga_ps_o,                        //parameter stack access    | target
    output wire                             sbus_tga_rs_o,                        //return stack access       |
    output wire [15:0]                      sbus_dat_o,                           //write data bus            |
    input  wire                             sbus_ack_i,                           //bus cycle acknowledge     +-
    input  wire                             sbus_stall_i,                         //access delay              | initiator
    input  wire [15:0]                      sbus_dat_i,                           //read data bus             +-

    //Internal signals
    //----------------
    //DSP interface
    //+------------------+------------------+-----------------------+  +------------------+------------------+-----------------------+
    //| ls2dsp_psp_inc_o | ls2dsp_psp_dec_o | dsp2ls_psp_next_i     |  | ls2dsp_rsp_inc_o | ls2dsp_rsp_dec_o | dsp2ls_rsp_next_i     |
    //+------------------+------------------+-----------------------+  +------------------+------------------+-----------------------+
    //|        0         |        0         | PSP + safety distance |  |        0         |        0         | PSP + safety distance |
    //+------------------+------------------+-----------------------+  +------------------+------------------+-----------------------+
    //|        0         |        1         | PSP - 1               |  |        0         |        1         | PSP - 1               |
    //+------------------+------------------+-----------------------+  +------------------+------------------+-----------------------+
    //|        1         |        0         | PSP + 1               |  |        1         |        0         | PSP + 1               |
    //+------------------+------------------+-----------------------+  +------------------+------------------+-----------------------+
    //|        1         |        1         | !!! FORBIDDEN !!!     |  |        1         |        1         | !!! FORBIDDEN !!!     |
    //+------------------+------------------+-----------------------+  +------------------+------------------+-----------------------+
    output reg                              ls2dsp_psp_hold_o,                    //don't update PSP
    output wire                             ls2dsp_psp_inc_o,                     //increment PSP
    output wire                             ls2dsp_psp_dec_o,                     //decrement PSP
    output wire                             ls2dsp_psp_set_o,                     //load new PSP
    output reg                              ls2dsp_rsp_hold_o,                    //don't update RSP
    output wire                             ls2dsp_rsp_inc_o,                     //increment RSP
    output wire                             ls2dsp_rsp_dec_o,                     //decrement RSP
    output wire                             ls2dsp_rsp_set_o,                     //load new RSP
    input  wire [SP_WIDTH-1:0]              dsp2ls_psp_i,                         //current PSP
    input  wire [SP_WIDTH-1:0]              dsp2ls_rsp_i,                         //current RSP
    input  wire [SP_WIDTH-1:0]              dsp2ls_psp_next_i,                    //next PSP
    input  wire [SP_WIDTH-1:0]              dsp2ls_rsp_next_i,                    //next RSP

    //IPS interface
    //+-------------------------------------------+--------------------------------+-----------------------------+
    //| Requests (mutually exclusive)             | Response on success            | Response on failure         |
    //+---------------------+---------------------+-----------------+--------------+-----------------+-----------+
    //| Type                | Input data          | Signals         | Output data  | Signals         | Cause     |
    //+---------------------+---------------------+-----------------+--------------+-----------------+-----------+
    //| Push to LPS         | cell data           | One or more     | none         | One or more     | LPS       |
    //| (ips2ls_push_req_i) | (ips2ls_req_data_i) | cycles after    |              | cycles after    | overflow  |
    //+---------------------+---------------------+ the request:    +--------------+ the request:    +-----------+
    //| Pull from LPS       | none                |                 | cell data    |  ls2ips_ack_o & | LPS       |
    //| (ips2ls_pull_req_i) |                     |  ls2ips_ack_o & | (sbus_dat_i) |  ls2ips_fail_o  | underflow |
    //+---------------------+---------------------+ ~ls2ips_fail_o  +--------------+-----------------+-----------+
    //| Overwrite PSP       | new PSP             |                 | none         | Every request is successful |
    //| (ips2ls_wrsp_req_i) | (ips2ls_req_data_i) |                 |              |                             |
    //+---------------------+---------------------+-----------------+--------------+-----------------------------+
    output wire                             ls2ips_ack_o,                         //acknowledge push or pull request
    output wire                             ls2ips_fail_o,                        //LPS over or underflow
    input  wire                             ips2ls_push_req_i,                    //push request from IPS to LS
    input  wire                             ips2ls_pull_req_i,                    //pull request from IPS to LS
    input  wire                             ips2ls_set_req_i,                     //request to set PSP
    input  wire [15:0]                      ips2ls_req_data_i,                    //push data or new PSP value

    //IRS interface
    //+-------------------------------------------+--------------------------------+-----------------------------+
    //| Requests (mutually exclusive)             | Response on success            | Response on failure         |
    //+---------------------+---------------------+-----------------+--------------+-----------------+-----------+
    //| Type                | Input data          | Signals         | Output data  | Signals         | Cause     |
    //+---------------------+---------------------+-----------------+--------------+-----------------+-----------+
    //| Push to LRS         | cell data           | One or more     | none         | One or more     | LRS       |
    //| (irs2ls_push_req_i) | (irs2ls_req_data_i) | cycles after    |              | cycles after    | overflow  |
    //+---------------------+---------------------+ the request:    +--------------+ the request:    +-----------+
    //| Pull from LRS       | none                |                 | cell data    |  ls2irs_ack_o & | LRS       |
    //| (irs2ls_pull_req_i) |                     |  ls2irs_ack_o & | (sbus_dat_i) |  ls2irs_fail_o  | underflow |
    //+---------------------+---------------------+ ~ls2irs_fail_o  +--------------+-----------------+-----------+
    //| Overwrite RSP       | new RSP             |                 | none         | Every request is successful |
    //| (irs2ls_wrsp_req_i) | (irs2ls_req_data_i) |                 |              |                             |
    //+---------------------+---------------------+-----------------+--------------+-----------------------------+
    output wire                             ls2irs_ack_o,                         //acknowledge push or pull request
    output wire                             ls2irs_fail_o,                        //LRS over or underflow
    input  wire                             irs2ls_push_req_i,                    //push request from IRS to LS
    input  wire                             irs2ls_pull_req_i,                    //pull request from IRS to LS
    input  wire                             irs2ls_set_req_i,                     //request to set RSP
    input  wire [15:0]                      irs2ls_req_data_i,                    //push data or new RSP value

    //Probe signals
    output wire [2:0]                       prb_lps_state_o,                      //LPS state
    output wire [2:0]                       prb_lrs_state_o);                     //LRS state 

   //FSM state encoding
   //------------------
   localparam                               STATE_IDLE0     = 3'b000;             //idle, no response pending
   localparam                               STATE_IDLE1     = 3'b100;             //idle, no response pending
   localparam                               STATE_IDLE2     = 3'b010;             //idle, no response pending
   localparam                               STATE_IDLE3     = 3'b110;             //idle, no response pending
   localparam                               STATE_ACK       = 3'b010;             //signal success
   localparam                               STATE_ACK_FAIL  = 3'b110;             //signal failure
   localparam                               STATE_SBUS      = 3'b011;             //wait for SBUS and signal success
   localparam                               STATE_SBUS_FAIL = 3'b111;             //wait for SBUS and signal failure

   //Internal signals
   //----------------
   //Stack boundaries
   wire                                     lps_empty;                            //LPS is empty
   wire                                     lrs_empty;                            //LRS is empty
   wire                                     ls_overflow;                          //stack overflow

   //Arbitrated requests
   wire                                     lps_pull_arb;                         //arbitrateded LPS pull request
   wire                                     lps_push_arb;                         //arbitrateded LPS push request
   wire                                     lrs_push_arb;                         //arbitrateded LRS push request
   wire                                     lrs_pull_arb;                         //arbitrateded LRS pull request

   //Fail conditions
   wire                                     lps_pull_fail_cond;                   //fail condition for LPS pull request
   wire                                     lps_push_fail_cond;                   //fail condition for LRS pull request
   wire                                     lrs_pull_fail_cond;                   //fail condition for LPS push request
   wire                                     lrs_push_fail_cond;                   //fail condition for LRS push request

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

   //Internal status signals
   //-----------------------
   //Stack boundaries
   assign lps_empty           = ~|dsp2ls_psp_i;                                   //PSP is zero
   assign lrs_empty           = ~|dsp2ls_rsp_i;                                   //RSP is zero
   assign ls_overflow         = &(dsp2ls_psp_next_i^dsp2ls_rsp_next_i);           //stack pointer collision

   //Arbitrated requests
   assign lps_pull_arb        = ips2ls_pull_req_i;                                //arbitrateded LPS pull request (1st prio) 
   assign lrs_pull_arb        = irs2ls_pull_req_i & ~ips2ls_pull_req_i;           //arbitrateded LRS pull request (2nd prio)
   assign lps_push_arb        = ips2ls_push_req_i & ~irs2ls_pull_req_i;           //arbitrateded LPS push request (3rd prio)
   assign lrs_push_arb        = irs2ls_push_req_i & ~ips2ls_pull_req_i &          //arbitrateded LRS push request (4th prio)
                                                    ~ips2ls_push_req_i;

   //Fail conditions
   assign lps_pull_fail_cond  = lps_empty;                                        //fail condition for LPS pull request
   assign lps_push_fail_cond  = ls_overflow;                                      //fail condition for LRS pull request
   assign lps_pull_fail_cond  = lrs_empty;                                        //fail condition for LPS push request
   assign lps_push_fail_cond  = ls_overflow;                                      //fail condition for LRS push request

   //State shortcuts
   assign lps_state_ack       = ~|(lps_state_reg ^ STATE_ACK);                    //LPS in STATE_ACK
   assign lps_state_ack_fail  = ~|(lps_state_reg ^ STATE_ACK_FAIL);               //LPS in STATE_ACK_FAIL
   assign lps_state_sbus      = ~|(lps_state_reg ^ STATE_SBUS);                   //LPS in STATE_SBUS
   assign lps_state_sbus_fail = ~|(lps_state_reg ^ STATE_SBUS_FAIL);              //LPS in STATE_SBUS_FAIL

   assign lrs_state_ack       = ~|(lrs_state_reg ^ STATE_ACK);                    //LRS in STATE_ACK
   assign lrs_state_ack_fail  = ~|(lrs_state_reg ^ STATE_ACK_FAIL);               //LRS in STATE_ACK_FAIL
   assign lrs_state_sbus      = ~|(lrs_state_reg ^ STATE_SBUS);                   //LRS in STATE_SBUS
   assign lrs_state_sbus_fail = ~|(lrs_state_reg ^ STATE_SBUS_FAIL);              //LRS in STATE_SBUS_FAIL

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
   assign sbus_adr_o          = ({SP_WIDTH{lps_pull_arb}} & dsp2ls_psp_next_i) |  //decremented PSP
                                ({SP_WIDTH{lrs_pull_arb}} & dsp2ls_rsp_next_i) |  //decremented RSP
                                ({SP_WIDTH{lps_push_arb}} & dsp2ls_psp_i)      |  //current PSP
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
        lps_state_next       = lps_state_reg;                                    //stay in current state

        //Handle incomming requests
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
