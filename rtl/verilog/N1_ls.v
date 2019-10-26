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
    output wire                             sbus_cyc_o,                           //bus cycle indicator       +-
    output wire                             sbus_stb_o,                           //access request            |
    output wire                             sbus_we_o,                            //write enable              | initiator
    output wire [SP_WIDTH-1:0]              sbus_adr_o,                           //address bus               | to
    output wire                             sbus_tga_ps_o,                        //parameter stack access    | target
    output wire                             sbus_tga_rs_o,                        //return stack access       |
    output wire  [15:0]                     sbus_dat_o,                           //write data bus            |
    input  wire                             sbus_ack_i,                           //bus cycle acknowledge     +-
    input  wire                             sbus_stall_i,                         //access delay              | initiator
    input  wire [15:0]                      sbus_dat_i,                           //read data bus             +-

    //Internal interfaces
    //-------------------
    //DSP interface
    output wire                             ls2dsp_sp_opr_o,                      //0:inc, 1:dec
    output wire                             ls2dsp_sp_sel_o,                      //0:PSP, 1:RSP
    output wire [SP_WIDTH-1:0]              ls2dsp_psp_o,                         //PSP
    output wire [SP_WIDTH-1:0]              ls2dsp_rsp_o,                         //RSP
    input  wire                             dsp2ls_overflow_i,                    //stacks overlap
    input  wire                             dsp2ls_sp_carry_i,                    //carry of inc/dec operation
    input  wire [SP_WIDTH-1:0]              dsp2ls_sp_next_i,                     //next PSP or RSP

    //IPS interface
    output reg                              ls2ips_ready_o,                       //LPS is ready for the next command
    output wire                             ls2ips_overflow_o,                    //LPS overflow
    output wire                             ls2ips_underflow_o,                   //LPS underflow
    output reg  [15:0]                      ls2ips_pull_data_o,                   //LPS pull data
    input  wire                             ips2ls_push_i,                        //push cell from IPS to LS
    input  wire                             ips2ls_pull_i,                        //pull cell from IPS to LS
    input  wire                             ips2ls_set_i,                         //set PSP
    input  wire                             ips2ls_get_i,                         //get PSP
    input  wire                             ips2ls_reset_i,                       //reset PSP
    input  wire [15:0]                      ips2ls_push_data_i,                   //LPS push data

    //IRS interface
    output reg                              ls2irs_ready_o,                       //LRS is ready for the next command
    output wire                             ls2irs_overflow_o,                    //LRS overflow
    output wire                             ls2irs_underflow_o,                   //LRS underflow
    output reg  [15:0]                      ls2irs_pull_data_o,                   //LRS pull data
    input  wire                             irs2ls_push_i,                        //push cell from IRS to LS
    input  wire                             irs2ls_pull_i,                        //pull cell from IRS to LS
    input  wire                             irs2ls_set_i,                         //set RSP
    input  wire                             irs2ls_get_i,                         //get RSP
    input  wire                             irs2ls_reset_i,                       //reset RSP
    input  wire [15:0]                      irs2ls_push_data_i,                   //LRS push data

    //Probe signals
    output wire [2:0]                       prb_lps_state_o,                      //LPS state
    output wire [2:0]                       prb_lrs_state_o,                      //LRS state
    output wire [15:0]                      prb_lps_tos_o,                        //LPS TOS
    output wire [15:0]                      prb_lrs_tos_o);                       //LRS TOS

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
   reg  [15:0]                              lps_sbus_dat;                         //write data
   reg                                      lps_sbus_busy;                        //SBUS in use

   //LRS SBUS signals
   reg                                      lrs_sbus_cyc;                         //bus cycle indicator
   reg                                      lrs_sbus_stb;                         //access request
   reg                                      lrs_sbus_we;                          //write enable
   reg  [SP_WIDTH-1:0]                      lrs_sbus_adr;                         //address bus
   reg  [15:0]                              lrs_sbus_dat;                         //write data
   reg                                      lrs_sbus_busy;                        //SBUS in use

   //LPS SAGU signals
   reg                                      lps_sp_sel;                            //select PSP as SAGU input
   reg                                      lps_sp_opr;                            //0:inc, 1:dec

   //LRS SAGU signals
   reg                                      lrs_sp_sel;                            //select RSP as SAGU input
   reg                                      lrs_sp_opr;                            //0:inc, 1:dec

   //IS signals
   reg                                      lps_pull_data_sel;                    //0:TOS, 1:SBUS
   reg                                      lrs_pull_data_sel;                    //0:TOS, 1:SBUS

   //FSM
   reg  [2:0]                               lps_state_reg;                        //current LPS state
   reg  [2:0]                               lps_state_next;                       //next LPS state
   reg  [2:0]                               lrs_state_reg;                        //current LRS state
   reg  [2:0]                               lrs_state_next;                       //next LRS state

   //SBUS (wishbone)
   //---------------
   assign sbus_cyc_o          =  lps_sbus_cyc | lrs_sbus_cyc;                     //bus cycle indicator
   assign sbus_stb_o          =  lps_sbus_stb | lrs_sbus_stb;                     //access request
   assign sbus_we_o           =  lps_sbus_we  | lrs_sbus_stb;                     //write enable
   assign sbus_adr_o          =  lps_sbus_adr | lrs_sbus_adr;                     //address bus
   assign sbus_tga_ps_o       =  lps_sbus_stb;                                    //parameter stack access
   assign sbus_tga_rs_o       =  lrs_sbus_stb;                                    //return stack access
   assign sbus_dat_o          =  lps_sbus_dat | lrs_sbus_dat;                     //write data bus

   //DSP interface
   //-------------
   assign ls2dsp_sp_opr_o     = ~lps_sp_sel ? lrs_sp_opr : lps_sp_opr;            //0:inc, 1:dec
   assign ls2dsp_sp_sel_o     = ~lps_sp_sel;                                      //0:PSP, 1:RSP
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

   //LPS TOS register
   //----------------
   //IS cells
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                             //asynchronous reset
       lps_tos_reg <= 16'h0000;
     else if (sync_rst_i)                                                         //synchronous reset
       lps_tos_reg <= 16'h0000;
     else if (lps_tos_we)                                                         //state transition
       lps_tos_reg <= lps_tos_next;

   //LRS TOS register
   //----------------
   //IS cells
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                             //asynchronous reset
       lrs_tos_reg <= 16'h0000;
     else if (sync_rst_i)                                                         //synchronous reset
       lrs_tos_reg <= 16'h0000;
     else if (lrs_tos_we)                                                         //state transition
       lrs_tos_reg <= lrs_tos_next;

   //State encoding
   //--------------
   localparam                               STATE_IDLE        = 3'b000;           //idle state
   localparam                               STATE_IDLE_DUMMY1 = 3'b001;           //idle state
   localparam                               STATE_IDLE_DUMMY2 = 3'b010;           //idle state
   localparam                               STATE_IDLE_DUMMY3 = 3'b011;           //idle state
   localparam                               STATE_PUSH_STALL  = 3'b100;           //wait until STALL is released
   localparam                               STATE_PUSH_ACK    = 3'b101;           //wait until ACK has been received
   localparam                               STATE_PULL_STALL  = 3'b110;           //wait until STALL is released
   localparam                               STATE_PULL_ACK    = 3'b111;           //wait until ACK has been received

   //LPS FSM
   //-------
    always @*
     begin
        //Defaults
        ls2ips_ready_o           = 1'b1;                                          //LPS is ready for the next command
        ls2ips_pull_data_o       = 16'h0000;                                      //LPS pull data
        psp_next                 = {SP_WIDTH{1'b0}};                              //next PSP
        psp_we                   = 1'b0;                                          //write enable
        lps_tos_next             = 16'h0000;                                      //new TOS buffer value
        lps_tos_we               = 1'b0;                                          //update TOS buffer
        lps_sbus_cyc             = 1'b0;                                          //bus cycle indicator
        lps_sbus_stb             = 1'b0;                                          //access request
        lps_sbus_we              = 1'b0;                                          //write enable
        lps_sbus_adr             = {SP_WIDTH{1'b0}};                              //address bus
        lps_sbus_dat             = 16'h0000;                                      //write data
        lps_sbus_busy            = 1'b0;                                          //SBUS in use
        lps_sp_sel               = 1'b0;                                          //select PSP as SAGU input
        lps_sp_opr               = 1'b0;                                          //0:inc, 1:dec
        lps_state_next           = 3'b000;                                        //next LPS state

        //Handle requests
        if (ips2ls_push_i)
          //Push to LPS
          begin
             psp_next            = psp_next | dsp2ls_sp_next_i;                   //next PSP
             lps_tos_next        = lps_tos_next | ips2ls_push_data_i;             //new TOS buffer value
             lps_tos_we          = 1'b1;                                          //update TOS buffer
             lps_sbus_cyc        = 1'b1;                                          //bus cycle indicator
             lps_sbus_stb        = 1'b1;                                          //access request
             lps_sbus_we         = lps_sbus_we | ~dsp2ls_overflow_i;              //write enable
             lps_sbus_adr        = lps_sbus_adr | psp_reg;                        //address bus
             lps_sbus_dat        = lps_sbus_dat | ips2ls_push_data_i;             //write data
             lps_sp_sel          = 1'b1;                                          //select PSP as SAGU input

             if (sbus_stall_i | lrs_sbus_busy)
               //SBUS is stalled
               begin
                  lps_state_next = lps_state_next | STATE_PUSH_STALL;             //next LPS state
               end
             else
               //SBUS is available
               begin
                  psp_we         = 1'b0;                                          //write enable
                  lps_state_next = lps_state_next | STATE_PUSH_ACK;               //next LPS state
               end // else: !if(sbus_stall_i | lrs_sbus_busy)
          end // if (ips2ls_push_i)

        if (ips2ls_pull_i)
          //Pull from LPS
          begin
             ls2ips_pull_data_o  = ls2ips_pull_data_o | lps_tos_reg;              //LPS pull data
             psp_next            = psp_next | dsp2ls_sp_next_i;                   //next PSP
             lps_sbus_cyc        = 1'b1;                                          //bus cycle indicator
             lps_sbus_stb        = 1'b1;                                          //access request
             lps_sbus_adr        = lps_sbus_adr | dsp2ls_sp_next_i;               //address bus
             lps_sp_sel          = 1'b1;                                          //select PSP as SAGU input
             lps_sp_opr          = 1'b1;                                          //0:inc, 1:dec

             if (sbus_stall_i | lrs_sbus_busy)
               //SBUS is stalled
               begin
                  lps_state_next = lps_state_next | STATE_PULL_STALL;             //next LPS state
               end
             else
               //SBUS is available
               begin
                  psp_we         = 1'b1;                                          //write enable
                  lps_state_next = lps_state_next | STATE_PULL_ACK;               //next LPS state
               end // else: !if(sbus_stall_i | lrs_sbus_busy)
          end // if (ips2ls_pull_i)

        if (ips2ls_set_i)
          //Set PSP
          begin
             psp_next            = psp_next | ips2ls_push_data_i[SP_WIDTH-1:0];   //next PSP
             psp_we              = 1'b1;                                          //write enable
             lps_state_next      = lps_state_next | STATE_PULL_STALL;             //next LPS state
          end

        if (ips2ls_get_i)
          //Get PSP
          begin
             lps_tos_next        = lps_tos_next |                                 //new TOS buffer value
                                   {{16-SP_WIDTH{1'b0}}, psp_reg};                //
             lps_tos_we          = 1'b1;                                          //update TOS buffer
             lps_state_next      = lps_state_next | STATE_PUSH_STALL;             //next LPS state
          end

        if (ips2ls_reset_i)
          //Reset PSP
          begin
             psp_we              = 1'b1;                                          //write enable
           //lps_state_next      = lps_state_next | STATE_IDLE;                   //next LPS state
             lps_state_next[2]   = lps_state_next[2] | STATE_IDLE[2];             //next LPS state
          end

        if (~ips2ls_push_i &
            ~ips2ls_pull_i &
            ~ips2ls_set_i  &
            ~ips2ls_get_i  &
            ~ips2ls_reset_i)
          //No request
          begin
           //lps_state_next      = lps_state_next | STATE_IDLE;                   //next LPS state
             lps_state_next[2]   = lps_state_next[2] | STATE_IDLE[2];             //next LPS state
          end

        //States
        case (lps_state_reg)
          //Idle state
          STATE_IDLE,
          STATE_IDLE_DUMMY1,
          STATE_IDLE_DUMMY2,
          STATE_IDLE_DUMMY3:
            begin
               //Only handle requests
            end

          //Stalled push access
          STATE_PUSH_STALL:
            begin
               //Defaults
               ls2ips_ready_o      = 1'b0;                                        //LPS is ready for the next command
               psp_next            = dsp2ls_sp_next_i;                            //next PSP
               lps_tos_we          = 1'b0;                                        //update TOS buffer
               lps_sbus_cyc        = 1'b1;                                        //bus cycle indicator
               lps_sbus_stb        = 1'b1;                                        //access request
               lps_sbus_we         = ~dsp2ls_overflow_i;                          //write enable
               lps_sbus_adr        = psp_reg;                                     //address bus
               lps_sbus_dat        = lps_tos_reg;                                 //write data
               lps_sp_sel          = 1'b1;                                        //select PSP as SAGU input

               if (sbus_stall_i | lrs_sbus_busy)
                 //SBUS is stalled
                 begin
                    lps_state_next = STATE_PUSH_STALL;                            //next LPS state
                 end
               else
                 //SBUS is available
                 begin
                    psp_we         = 1'b1;                                        //write enable
                    lps_state_next = STATE_PUSH_ACK;                              //next LPS state
                 end // else: !if(sbus_stall_i | lrs_sbus_busy)
            end // case: STATE_PUSH_STALL

          //Unacknowledged push access
          STATE_PUSH_ACK:
            begin
               if (~sbus_ack_i)
                 //No ACK
                 begin
                    ls2ips_ready_o = 1'b0;                                        //LPS is ready for the next command
                    psp_we         = 1'b0;                                        //write enable
                    lps_tos_we     = 1'b1;                                        //update TOS buffer
                    lps_sbus_busy  = 1'b1;                                        //SBUS in use
                    lps_state_next = STATE_PUSH_ACK;                              //next LPS state
                 end
            end // case: STATE_PUSH_ACK

          //Stalled pull access
          STATE_PULL_STALL:
            begin
               //Defaults
               ls2ips_ready_o      = 1'b0;                                        //LPS is ready for the next command
               psp_next            = dsp2ls_sp_next_i;                            //next PSP
               lps_tos_we          = 1'b0;                                        //update TOS buffer
               lps_sbus_cyc        = 1'b1;                                        //bus cycle indicator
               lps_sbus_stb        = 1'b1;                                        //access request
               lps_sbus_we         = 1'b0;                                        //write enable
               lps_sbus_adr        = dsp2ls_sp_next_i;                                     //address bus
               lps_sp_sel          = 1'b1;                                        //select PSP as SAGU input

               if (sbus_stall_i | lrs_sbus_busy)
                 //SBUS is stalled
                 begin
                    lps_state_next = STATE_PULL_STALL;                            //next LPS state
                 end
               else
                 //SBUS is available
                 begin
                    psp_we         = 1'b1;                                        //write enable
                    lps_state_next = STATE_PULL_ACK;                              //next LPS state
                 end // else: !if(sbus_stall_i | lrs_sbus_busy)
            end // case: STATE_PULL_STALL

          //Unacknowledged push access
          STATE_PULL_ACK:
            begin
               //Receive read data from SBUS
               lps_tos_next        = ips2ls_push_i ?                              //bypass TOS register
                                        {{16-SP_WIDTH{1'b0}}, dsp2ls_sp_next_i} : //push after pull
                                        sbus_dat_i;                               //plain pull
               ls2ips_pull_data_o  = sbus_dat_i;                                  //pull after pull

               if (~sbus_ack_i)
                 //No ACK
                 begin
                    ls2ips_ready_o = 1'b0;                                        //LPS is ready for the next command
                    psp_we         = 1'b0;                                        //write enable
                    lps_tos_we     = 1'b1;                                        //update TOS buffer
                    lps_sbus_busy  = 1'b1;                                        //SBUS in use
                    lps_state_next = STATE_PUSH_ACK;                              //next LPS state
                 end
               else
                 //ACK
                 begin
                    //Update TOS
                    lps_tos_we = 1'b1;                                            //update TOS buffer
                 end // else: !if(~sbus_ack_i)
            end // case: STATE_PULL_ACK

        endcase // case (lps_state_reg)
     end // always @ *

   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                             //asynchronous reset
       lps_state_reg <= STATE_IDLE;                                               //reset state
     else if (sync_rst_i)                                                         //synchronous reset
       lps_state_reg <= STATE_IDLE;                                               //reset state
     else                                                                         //state transition
       lps_state_reg <= lps_state_next;                                           //state transition

   //LRS FSM
   //-------
    always @*
     begin
        //Defaults
        ls2irs_ready_o                = 1'b1;                                     //LRS is ready for the next command
        ls2irs_pull_data_o            = 16'h0000;                                 //LRS pull data
        rsp_next                      = {SP_WIDTH{1'b0}};                         //next RSP
        rsp_we                        = 1'b0;                                     //write enable
        lrs_tos_next                  = 16'h0000;                                 //new TOS buffer value
        lrs_tos_we                    = 1'b0;                                     //update TOS buffer
        lrs_sbus_cyc                  = 1'b0;                                     //bus cycle indicator
        lrs_sbus_stb                  = 1'b0;                                     //access request
        lrs_sbus_we                   = 1'b0;                                     //write enable
        lrs_sbus_adr                  = {SP_WIDTH{1'b0}};                         //address bus
        lrs_sbus_dat                  = 16'h0000;                                 //write data
        lrs_sbus_busy                 = 1'b0;                                     //SBUS in use
        lrs_sp_sel                    = 1'b0;                                     //select RSP as SAGU input
        lrs_sp_opr                    = 1'b0;                                     //0:inc, 1:dec
        lrs_state_next                = 3'b000;                                   //next LRS state

        //Handle requests
        if (irs2ls_push_i)
          //Push to LRS
          begin
             rsp_next                 = rsp_next | dsp2ls_sp_next_i;              //next RSP
             lrs_tos_next             = lrs_tos_next | irs2ls_push_data_i;        //new TOS buffer value
             lrs_tos_we               = 1'b1;                                     //update TOS buffer
             lrs_sbus_cyc             = 1'b1;                                     //bus cycle indicator
             lrs_sbus_stb             = 1'b1;                                     //access request

             if (ips2ls_push_i | ips2ls_pull_i)
               //High priority request for LRS
               begin
                  lrs_state_next = STATE_PUSH_STALL;                              //next LRS state
               end
             else
               //No igh priority request for LRS
               begin
                  lrs_sbus_we         = lrs_sbus_we | ~dsp2ls_overflow_i;         //write enable
                  lrs_sbus_adr        = lrs_sbus_adr | rsp_reg;                   //address bus
                  lrs_sbus_dat        = lrs_sbus_dat | irs2ls_push_data_i;        //write data
                  lrs_sp_sel          = 1'b1;                                     //select RSP as SAGU input

                  if (sbus_stall_i | lps_sbus_busy)
                    //SBUS is stalled
                    begin
                       lrs_state_next = lrs_state_next | STATE_PUSH_STALL;        //next LRS state
                    end
                  else
                    //SBUS is available
                    begin
                       rsp_we         = 1'b0;                                     //write enable
                       lrs_state_next = lrs_state_next | STATE_PUSH_ACK;          //next LRS state
                    end // else: !if(sbus_stall_i | lps_sbus_busy)
               end // else: !if(ips2ls_push_i | ips2ls_pull_i)
          end // if (irs2ls_push_i)


        if (irs2ls_pull_i)
          //Pull from LRS
          begin
             ls2irs_pull_data_o       = ls2irs_pull_data_o  | lrs_tos_reg  ;      //LRS pull data
             rsp_next                 = rsp_next | dsp2ls_sp_next_i;              //next RSP
             lrs_tos_next             = lrs_tos_next | irs2ls_push_data_i;        //new TOS buffer value
             lrs_tos_we               = 1'b1;                                     //update TOS buffer
             lrs_sbus_cyc             = 1'b1;                                     //bus cycle indicator
             lrs_sbus_stb             = 1'b1;                                     //access request

             if (ips2ls_push_i | ips2ls_pull_i)
               //High priority request for LPS
               begin
                  lrs_state_next      = lrs_state_next | STATE_PULL_STALL;        //next LRS state
               end
             else
               //No high priority request for LPS
               begin
                  lrs_sbus_adr        = lrs_sbus_adr | rsp_reg;                   //address bus
                  lrs_sp_sel          = 1'b1;                                     //select RSP as SAGU input
                  lrs_sp_opr          = 1'b1;                                     //0:inc, 1:dec

                  if (sbus_stall_i | lps_sbus_busy)
                    //SBUS is stalled
                    begin
                       lrs_state_next = lrs_state_next | STATE_PULL_STALL;        //next LPS state
                    end
                  else
                    //SBUS is available
                    begin
                       rsp_we         = 1'b0;                                     //write enable
                       lrs_state_next = lrs_state_next | STATE_PULL_ACK;          //next LRS state
                    end // else: !if(sbus_stall_i | lps_sbus_busy)
               end // else: !if(ips2ls_push_i | ips2ls_pull_i)
          end // if (irs2ls_pull_i)

        if (irs2ls_set_i)
          //Set RSP
          begin
             rsp_next            = rsp_next | irs2ls_push_data_i[SP_WIDTH-1:0];   //next RSP
             rsp_we              = 1'b1;                                          //write enable
             lrs_state_next      = lrs_state_next | STATE_PULL_STALL;             //next LRS state
          end

        if (irs2ls_get_i)
          //Get RSP
          begin
             lrs_tos_next        = lrs_tos_next |                                 //new TOS buffer value
                                   {{16-SP_WIDTH{1'b0}}, rsp_reg};                //
             lrs_tos_we          = 1'b1;                                          //update TOS buffer
             lrs_state_next      = lrs_state_next | STATE_PUSH_STALL;             //next LRS state
          end

        if (irs2ls_reset_i)
          //Reset RSP
          begin
             rsp_we              = 1'b1;                                          //write enable
           //lrs_state_next      = lrs_state_next | STATE_IDLE;                   //next LRS state
             lrs_state_next[2]   = lrs_state_next[2] | STATE_IDLE[2];             //next LRS state
          end

        if (~irs2ls_push_i &
            ~irs2ls_pull_i &
            ~irs2ls_set_i  &
            ~irs2ls_get_i  &
            ~irs2ls_reset_i)
          //No request
          begin
             lrs_state_next      = lrs_state_next | STATE_IDLE;                   //next LRS state
          end

        //States
        case (lrs_state_reg)
          //Idle state
          STATE_IDLE,
          STATE_IDLE_DUMMY1,
          STATE_IDLE_DUMMY2,
          STATE_IDLE_DUMMY3:
            begin
               //Only handle requests
            end

          //Stalled push access
          STATE_PUSH_STALL:
            begin
               ls2ips_ready_o         = 1'b0;                                     //LPS is ready for the next command
               rsp_next               = dsp2ls_sp_next_i;                         //next RSP
               lrs_tos_we             = 1'b0;                                     //update TOS buffer
               lrs_sbus_cyc           = 1'b1;                                     //bus cycle indicator
               lrs_sbus_stb           = 1'b1;                                     //access request

             if (ips2ls_push_i | ips2ls_pull_i)
               //High priority request for LPS
               begin
                  lrs_state_next = STATE_PUSH_STALL;                              //next LRS state
               end
             else
               //No igh priority request for LPS
               begin
                  lrs_sbus_we         = ~dsp2ls_overflow_i;                       //write enable
                  lrs_sbus_adr        = rsp_reg;                                  //address bus
                  lrs_sbus_dat        = lrs_tos_reg;                              //write data
                  lrs_sp_sel          = 1'b1;                                     //select RSP as SAGU input

                  if (sbus_stall_i | lps_sbus_busy)
                    //SBUS is stalled
                    begin
                       lrs_state_next = lrs_state_next | STATE_PUSH_STALL;        //next LRS state
                    end
                  else
                    //SBUS is available
                    begin
                       rsp_we         = 1'b0;                                     //write enable
                       lrs_state_next = lrs_state_next | STATE_PUSH_ACK;          //next LRS state
                    end // else: !if(sbus_stall_i | lps_sbus_busy)
               end // else: !if(ips2ls_push_i | ips2ls_pull_i)
            end // case: STATE_PUSH_STALL

          //Unacknowledged push access
          STATE_PUSH_ACK:
            begin
               if (~sbus_ack_i)
                 //No ACK
                 begin
                    ls2irs_ready_o = 1'b0;                                        //LRS is ready for the next command
                    rsp_we         = 1'b0;                                        //write enable
                    lrs_tos_we     = 1'b1;                                        //update TOS buffer
                    lrs_sbus_busy  = 1'b1;                                        //SBUS in use
                    lrs_state_next = STATE_PUSH_ACK;                              //next LRS state
                 end
            end // case: STATE_PUSH_ACK

          //Stalled pull access
          STATE_PULL_STALL:
            begin
               //Defaults
               ls2irs_ready_o      = 1'b0;                                        //LRS is ready for the next command
               rsp_next            = dsp2ls_sp_next_i;                            //next RSP
               lrs_tos_we          = 1'b0;                                        //update TOS buffer
               lrs_sbus_cyc        = 1'b1;                                        //bus cycle indicator
               lrs_sbus_stb        = 1'b1;                                        //access request
               lrs_sbus_we         = 1'b0;                                        //write enable
               lrs_sbus_adr        = dsp2ls_sp_next_i;                            //address bus
               lrs_sp_sel          = 1'b1;                                        //select RSP as SAGU input

               if (sbus_stall_i | lrs_sbus_busy)
                 //SBUS is stalled
                 begin
                    lrs_state_next = STATE_PULL_STALL;                            //next LRS state
                 end
               else
                 //SBUS is available
                 begin
                    rsp_we         = 1'b1;                                        //write enable
                    lrs_state_next = STATE_PULL_ACK;                              //next LRS state
                 end // else: !if(sbus_stall_i | lrs_sbus_busy)
            end // case: STATE_PULL_STALL

          //Unacknowledged push access
          STATE_PULL_ACK:
            begin
               //Receive read data from SBUS
               lrs_tos_next        = irs2ls_push_i ?                              //bypass TOS register
                                        {{16-SP_WIDTH{1'b0}}, dsp2ls_sp_next_i} : //push after pull
                                        sbus_dat_i;                               //plain pull
               ls2irs_pull_data_o  = sbus_dat_i;                                  //pull after pull

               if (~sbus_ack_i)
                 //No ACK
                 begin
                    ls2irs_ready_o = 1'b0;                                        //LRS is ready for the next command
                    rsp_we         = 1'b0;                                        //write enable
                    lrs_tos_we     = 1'b1;                                        //update TOS buffer
                    lrs_sbus_busy  = 1'b1;                                        //SBUS in use
                    lrs_state_next = STATE_PUSH_ACK;                              //next LRS state
                 end
               else
                 //ACK
                 begin
                    //Update TOS
                    lrs_tos_we = 1'b1;                                            //update TOS buffer
                 end // else: !if(~sbus_ack_i)
            end // case: STATE_PULL_ACK

        endcase // case (lrs_state_reg)
     end // always @ *

   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                             //asynchronous reset
       lrs_state_reg <= STATE_IDLE;                                               //reset state
     else if (sync_rst_i)                                                         //synchronous reset
       lrs_state_reg <= STATE_IDLE;                                               //reset state
     else                                                                         //state transition
       lrs_state_reg <= lrs_state_next;                                           //state transition

   //Probe signals
   //-------------
   assign prb_lps_state_o     = lps_state_reg;                                    //LPS state
   assign prb_lrs_state_o     = lrs_state_reg;                                    //LRS state
   assign prb_lps_tos_o       = lps_tos_reg;                                      //LPS TOS
   assign prb_lrs_tos_o       = lrs_tos_reg;                                      //LRS TOS

endmodule // N1_ls
