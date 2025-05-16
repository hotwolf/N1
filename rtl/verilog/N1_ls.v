//###############################################################################
//# N1 - Lower Stack                                                            #
//###############################################################################
//#    Copyright 2018 - 2024 Dirk Heisswolf                                     #
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
//#    This module implements the RAM based lower parameter (LPS) or return     #
//#    stack (LRS).                                                             #
//#                                                                             #
//#    Data path:                                                               #
//#                                    push           pull                      #
//#  Stack interface:                  data           data                      #
//#  (see manual)                       v              ^                        #
//#                                     |              |                        #
//#                                     |           ---+---                     #
//#                                     |          /  Mux  \                    #
//#                                     |         --+-----+--                   #
//#                                     |           |     |                     #
//#                                     |        +--+---+ |                     #
//#                                     |        | TOS  | |                     #
//#                                     |        |Buffer| |                     #
//#                                     |        +--+---+ |                     #
//#                                     |           |     |                     #
//#                                     |        +--+     |                     #
//#                                     |        |        |                     #
//#                                     |     ---+---     |                     #
//#                                     |    /  Mux  \    |                     #
//#                                     |   --+-----+--   |                     #
//#                     +-----+         |     |     |     |                     #
//#                     | AGU |         +-----+     +--+--+                     #
//#                     +--+--+         |              |                        #
//#                        |            |              |                        #
//#                        v            v              ^                        #
//#  Memory interface:   address       write          read                      #
//#  (see manual)                      data           data                      #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 19, 2019                                                        #
//#      - Initial release                                                      #
//#   April 25, 2025                                                            #
//#      - New implementation with a dedicated stack memory                     #
//###############################################################################
`default_nettype none

module N1_ls
  #(parameter ADDR_WIDTH      = 14,                                                 //address width of the memory
    parameter STACK_DIRECTION = 1)                                                  //1:grow stack upward, 0:grow stack downward

   (//Clock and reset
    input  wire                             clk_i,                                  //module clock
    input  wire                             async_rst_i,                            //asynchronous reset
    input  wire                             sync_rst_i,                             //synchronous reset

    //Stack interface
    input  wire                             ls_clear_i,                             //clear request
    input  wire                             ls_push_i,                              //push request
    input  wire                             ls_pull_i,                              //pull request
    input  wire [15:0]                      ls_push_data_i,                         //push request
    output wire                             ls_clear_bsy_o,                         //clear request rejected
    output wire                             ls_push_bsy_o,                          //push request rejected
    output wire                             ls_pull_bsy_o,                          //pull request rejected
    output wire                             ls_empty_o,                             //underflow indicator
    output wire                             ls_full_o,                              //overflow indicator
    output wire [15:0]                      ls_pull_data_o,                         //pull data

    //Memory interface
    input  wire                             mem_access_bsy_i,                       //access request rejected
    input  wire [15:0]                      mem_rdata_i,                            //read data
    input  wire                             mem_rdata_del_i,                        //read data delay
    output wire [ADDR_WIDTH-1:0]            mem_addr_o,                             //address
    output wire                             mem_access_o,                           //access request
    output wire                             mem_rwb_o,                              //data direction
    output wire [15:0]                      mem_wdata_o,                            //write data

    //Dynamic stack ranges
    input  wire [ADDR_WIDTH-1:0]            ls_tos_limit_i,                         //address, which the LS must not reach
    output wire [ADDR_WIDTH-1:0]            ls_tos_o,                               //points to the TOS

    //Probe signals
    output wire                             prb_ls_state_o,                          //probed FSM state
    output wire [15:0]                      prb_ls_tosbuf_o,                         //probed TOS buffer
    output wire [ADDR_WIDTH:0]              prb_ls_agu_o);                           //probed AGU address output

   //Internal registers
   //-----------------
   //FSM
   reg                                      state_reg;                              //current state

   //Local parameters
   //----------------
   localparam START_ADDR = STACK_DIRECTION ? {ADDR_WIDTH{1'b0}} : {1'b1,{ADDR_WIDTH-1{1'b0}}};

   //Internal signals
   //----------------
   //AGU
   wire                                     agu_restart;                            //soft reset
   wire                                     agu_push;                               //advance address
   wire                                     agu_pull;                               //decrement LFSR
   wire                                     agu_addr_sel;                           //address selector (0=agu_push_addr, 1=agu_pull_addr)
   wire [ADDR_WIDTH-1:0]                    agu_push_addr;                          //next free address space
   wire [ADDR_WIDTH-1:0]                    agu_pull_addr;                          //address of 2nd last stack entry
   wire                                     agu_empty;                              //underflow on next pull
   wire                                     agu_full;                               //overflow on next push

   //LFSR
   wire                                     lfsr_restart;                           //soft reset
   wire                                     lfsr_inc;                               //increment LFSR
   wire                                     lfsr_dec;                               //decrement LFSR
   wire [ADDR_WIDTH-1:0]                    lfsr_val;                               //LFSR value
   wire [ADDR_WIDTH-1:0]                    lfsr_inc_val;                           //incremented LFSR value
   wire [ADDR_WIDTH-1:0]                    lfsr_dec_val;                           //decremented LFSR value

   //TOS buffer
   reg                                      tosbuf_bypass;                          //bypass TOS buffer
   reg                                      tosbuf_in_sel;                          //input selector (0=push_data_i, 1=mem_rdata_i)
   reg                                      tosbuf_capture;                         //capture data
   wire [15:0]                              tosbuf_in;                              //TOS buffer input
   reg  [15:0]                              tosbuf_reg;                             //TOS buffer

   //Memory status
   reg                                      mem_bsy;                                //waiting for read data

   //FSM
   reg                                      state_next;                             //next state

   //LFSR AGU
   assign  agu_restart   =  ls_clear_i                           & ~ls_clear_bsy_o; //soft reset
   assign  agu_push      = ~ls_clear_i &  ls_push_i & ~ls_pull_i & ~ls_push_bsy_o;  //advance address
   assign  agu_pull      = ~ls_clear_i & ~ls_push_i &  ls_pull_i & ~ls_pull_bsy_o;  //decrement LFSR
   assign  agu_addr_sel  = agu_pull;                                                //address selector (0=agu_push_addr, 1=agu_pull_addr)

   assign  agu_push_addr = STACK_DIRECTION ? lfsr_inc_val : lfsr_dec_val;
   assign  agu_pull_addr = lfsr_val;

   assign  agu_empty     = ~|(lfsr_val      ^ START_ADDR);
   assign  agu_full      = ~|(agu_push_addr ^ ls_tos_limit_i);

   assign  lfsr_restart  = agu_restart;
   assign  lfsr_inc      = STACK_DIRECTION ? agu_push : agu_pull;
   assign  lfsr_dec      = STACK_DIRECTION ? agu_pull : agu_push;

   assign  ls_tos_o      = lfsr_val;

   N1_lsfr
     #(.WIDTH     (ADDR_WIDTH),                                                   //LFSR width
       .INCLUDE_0 (1),                                                            //cycle through 0
       .START_VAL (START_ADDR))                                                   //start value
   agu
      (//Clock and reset
       .clk_i          (clk_i),                                                   //module clock
       .async_rst_i    (async_rst_i),                                             //asynchronous reset
       .sync_rst_i     (sync_rst_i),                                              //synchronous reset
       //LFSR status
       .lfsr_val_o     (lfsr_val),                                                //LFSR value
       .lfsr_inc_val_o (lfsr_inc_val),                                            //incremented LFSR value
       .lfsr_dec_val_o (lfsr_dec_val),                                            //decremented LFSR value
       //LFSR control
       .lfsr_restart_i (lfsr_restart),                                            //soft reset
       .lfsr_inc_i     (lfsr_inc),                                                //increment LFSR
       .lfsr_dec_i     (lfsr_dec),                                                //decrement LFSR
       //LFSR overrun/underrun indicators
       .lfsr_or_o      (),                                                        //overrun at next INC request
       .lfsr_ur_o      (),                                                        //underrun at next DEC request
       //Probe signals
       .prb_lfsr_o     (prb_ls_agu_o));                                           //LFSR probes

   //TOS buffer
   assign  tosbuf_in     = tosbuf_in_sel ? mem_rdata_i : ls_push_data_i;          //input selector (0=push_data_i, 1=mem_rdata_i)

   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                             //asynchronous reset
       tosbuf_reg <= 16'h0000;                                                    //reset state
     else if (sync_rst_i)                                                         //synchronous reset
       tosbuf_reg <= 16'h0000;                                                    //reset state
     else if (tosbuf_capture)                                                     //capture data
       tosbuf_reg <= tosbuf_in;                                                   //input data

   //Stack interface
   assign  ls_clear_bsy_o = 1'b0;                                                 //clear request rejected
   assign  ls_push_bsy_o  = mem_access_bsy_i | mem_bsy;                           //push request rejected
   assign  ls_pull_bsy_o  = mem_access_bsy_i | mem_bsy;                           //pull request rejected
   assign  ls_full_o      = agu_full;                                             //overflow indicator
   assign  ls_empty_o     = agu_empty;                                            //underflow indicator
   assign  ls_pull_data_o = tosbuf_bypass ? mem_rdata_i : tosbuf_reg;             //pull data

   //Memory interface
   assign  mem_addr_o     = agu_addr_sel ? agu_pull_addr : agu_push_addr;         //address
   assign  mem_access_o   = ls_push_i | ls_pull_i;                                //access request
   assign  mem_rwb_o      = ls_pull_i;                                            //data direction
   assign  mem_wdata_o    = ls_push_data_i;                                       //write data

   //State encoding
   //--------------
   localparam                               STATE_NO_RDATA  = 1'b0;               //no read data to be captured
   localparam                               STATE_RDATA     = 1'b1;               //read data to be captured

   //FSM
   //---
   always @*
     begin
       //Defaults
       tosbuf_bypass   = 1'b0;                                                   //don't bypass TOS buffer
       tosbuf_in_sel   = 1'b0;                                                   //input selector (0=push_data_i, 1=mem_rdata_i)
       tosbuf_capture  = agu_push | agu_pull;                                    //capture data
       mem_bsy         = 1'b0;                                                   //not stalled by read data_del
       state_next      = agu_pull ? STATE_RDATA : STATE_NO_RDATA;                //next state

       //States
       case (state_reg)
         //Reset state
         STATE_NO_RDATA:
           begin
            end

         //Read data available
         STATE_RDATA:
           begin
              tosbuf_bypass   = 1'b1;                                            //bypass TOS buffer
              tosbuf_in_sel   = ~ls_push_i;                                      //input selector (0=push_data_i, 1=mem_rdata_i)

              if (mem_rdata_del_i)
                begin
                   mem_bsy         = 1'b0;                                       //not stalled by read data_del
                   state_next      = STATE_RDATA;                                //next state
                end
              else
                begin
                   tosbuf_capture  = 1'b1;                                       //capture data
                end
           end // case: STATE_RDATA

        endcase // case (lps_state_reg)
     end // always @ *

   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       state_reg <= STATE_NO_RDATA;                                              //reset state
     else if (sync_rst_i)                                                        //synchronous reset
       state_reg <= STATE_NO_RDATA;                                              //reset state
     else                                                                        //state transition
       state_reg <= state_next;                                                  //state transition

   //Probe signals
   //-------------
   assign prb_ls_tosbuf_o = tosbuf_reg;                                          //TOS buffer
   assign prb_ls_state_o  = state_reg;                                           //probed FSM state

endmodule // N1_ls
