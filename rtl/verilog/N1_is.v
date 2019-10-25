//###############################################################################
//# N1 - Intermediate Stack                                                     #
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
//#    This module implements one instance of an intermediate stack (IS). The   #
//#    intermediate stack serves as a buffer between the upper and the lower    #
//#    stack (LS). It is designed to handle smaller fluctuations in stack       #
//#    content, minimizing accesses to the lower stack.                         #
//#                                                                             #
//#        Upper Stack     top   Intermediate Stack   bottom                    #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+---+                     #
//#       |   |   |   |<=>| 0 | 1 | 2 | 3 | 4 |   |n-1| n |                     #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+-+-+                     #
//#                         ^                           |                       #
//#                         |                           v     +----------+      #
//#                       +-+-----------------------------+   |   RAM    |      #
//#                       |        RAM Controller         |<=>| (Lower   |      #
//#                       +-------------------------------+   |   Stack) |      #
//#                                                           +----------+      #
//#                                                                             #
//#    The IS in conjunction with the LS supports the following operations:     #
//#       PUSH:  Push one cell to the TOS                                       #
//#       PULL:  Pull one cell from the TOS                                     #
//#       SET:   Write push data to the SP                                      #
//#       GET:   Pull data from the PS to the TOS                               #
//#       RESET: Clear the stack                                                #
//#                                                                             #
//#    The IS signals its readiness to execute a new stack operation via the    #
//#    is2us_ready_o signal. Operation which execute for more than one clock    #
//#    cycle delay the execution flow by asserting the is2us_ready_o signal in  #
//#    the cycles following the request.                                        #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 24, 2019                                                        #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_is
  #(parameter IS_DEPTH  = 8,                                                                      //depth of the IS (must be >=2)
    parameter IS_BYPASS = 0)                                                                      //conncet the LS directly to the US

   (//Clock and reset
    input  wire                             clk_i,                                                //module clock
    input  wire                             async_rst_i,                                          //asynchronous reset
    input  wire                             sync_rst_i,                                           //synchronous reset

    //Internal signals
    //----------------
    //LS interface
    //!!! ls2is_overflow_i is only valid when the RSP is incremented (combinational feedback)
    //!!! ls2is_underflow_i is only valid when the RSP is decremented (combinational feedback)
    output wire                             is2ls_push_o,                                         //push cell from IS to LS
    output wire                             is2ls_pull_o,                                         //pull cell from IS to LS
    output wire                             is2ls_set_o,                                          //set SP
    output wire                             is2ls_get_o,                                          //get SP
    output wire                             is2ls_reset_o,                                        //reset SP
    output wire [15:0]                      is2ls_push_data_o,                                    //LS push data
    input  wire                             ls2is_ready_i,                                        //LS is ready for the next command
    input  wire                             ls2is_overflow_i,                                     //LS is full or overflowing
    input  wire                             ls2is_underflow_i,                                    //LS empty
    input  wire [15:0]                      ls2is_pull_data_i,                                    //LS pull data

    //US interface
    //!!! is2us_overflow_o is only valid when the RSP is incremented (combinational feedback)
    //!!! is2us_underflow_o is only valid when the RSP is decremented (combinational feedback)
    output wire                             is2us_ready_o,                                        //IS is ready for the next command
    output wire                             is2us_overflow_o,                                     //LS+IS are full or overflowing
    output wire                             is2us_underflow_o,                                    //LS+IS are empty
    output wire [15:0]                      is2us_pull_data_o,                                    //IS pull data
    input  wire                             us2is_push_i,                                         //push cell from US to IS
    input  wire                             us2is_pull_i,                                         //pull cell from US to IS
    input  wire                             us2is_set_i,                                          //set SP
    input  wire                             us2is_get_i,                                          //get SP
    input  wire                             us2is_reset_i,                                        //reset SP
    input  wire [15:0]                      us2is_push_data_i,                                    //IS push data

    //Probe signals
    output wire [(16*IS_DEPTH)-1:0]         prb_is_cells_o,                                       //current IS cells
    output wire [IS_DEPTH-1:0]              prb_is_tags_o,                                        //current IS tags
    output wire [1:0]                       prb_is_state_o);                                      //current state

   //Internal signals
   //-----------------
   //Internal status signals
   wire                                     is_tos_tag;                                           //TOS holds data
   wire                                     is_bos_tag;                                           //BOS holds data
   wire                                     is_abos_tag;                                          //cell above BOS holds data
   wire [15:0]                              is_tos_cell;                                          //TOS data
   wire [15:0]                              is_bos_cell;                                          //BOS data
   reg                                      is_ready;                                             //LS+IS are ready
   reg                                      is_overflow;                                              //LS+IS overflow
   reg                                      is_underflow;                                         //LS+IS underflow

   //Internal control signals
   reg                                      is_push;                                              //push IS
   reg                                      is_pull;                                              //pull IS
   reg                                      is_flush;                                             //flush IS
   reg                                      is_reset;                                             //reset IS
   reg                                      ls_push;                                              //push to LS
   reg                                      ls_pull;                                              //pull from LS
   reg                                      ls_set;                                               //set LSP
   reg                                      ls_get;                                               //get LSP
   reg                                      ls_reset;                                             //reset LS

   //IS registers
   reg  [(16*IS_DEPTH)-1:0]                 is_cells_reg;                                         //current IS
   wire [(16*IS_DEPTH)-1:0]                 is_cells_next;                                        //next IS
   reg                                      is_cells_we;                                          //write enable
   reg  [IS_DEPTH-1:0]                      is_tags_reg;                                          //current IS
   wire [IS_DEPTH-1:0]                      is_tags_next;                                         //next IS
   reg                                      is_tags_we;                                           //write enable

   //FSM
   reg  [1:0]                               state_reg;                                            //current state
   reg  [1:0]                               state_next;                                           //next state

   //LS interface
   //------------
   assign is2ls_push_o       = |IS_BYPASS ? us2is_push_i      : ls_push;                          //push cell from IS to LS
   assign is2ls_pull_o       = |IS_BYPASS ? us2is_pull_i      : ls_pull;                          //pull cell from IS to LS
   assign is2ls_set_o        = |IS_BYPASS ? us2is_set_i       : ls_set;                           //set SP
   assign is2ls_get_o        = |IS_BYPASS ? us2is_get_i       : ls_get;                           //get SP
   assign is2ls_reset_o      = |IS_BYPASS ? us2is_reset_i     : ls_reset;                         //reset SP
   assign is2ls_push_data_o  = |IS_BYPASS ? us2is_push_data_i : (is_bos_tag ?                     //IS pull data
                                                                     is_bos_cell :                //push data from IS
                                                                     us2is_push_data_i);          //push data ftom US


   //US interface
   //------------
   assign is2us_ready_o      = |IS_BYPASS ? ls2is_ready_i     : is_ready;                         //IS is ready for the next command
   assign is2us_overflow_o   = |IS_BYPASS ? ls2is_overflow_i  : is_overflow;                      //LS+IS overflow
   assign is2us_underflow_o  = |IS_BYPASS ? ls2is_underflow_i : is_underflow;                     //LS+IS underflow
   assign is2us_pull_data_o  = |IS_BYPASS ? ls2is_pull_data_i : (is_tos_tag ?                     //IS pull data
                                                                     is_tos_cell :                //pull data from IS
                                                                     ls2is_pull_data_i);          //pull data from LS

   //Internal status signals
   //-----------------------
   assign is_tos_tag         =  is_tags_reg[0];                                                   //TOS holds data
   assign is_bos_tag         =  is_tags_reg[IS_DEPTH-1];                                          //BOS holds data
   assign is_abos_tag        =  is_tags_reg[IS_DEPTH-2];                                          //cell above BOS holds data
   assign is_tos_cell        =  is_cells_reg[15:0];                                               //TOS data
   assign is_bos_cell        =  is_cells_reg[(16*IS_DEPTH)-1:(16*IS_DEPTH)-16];                   //BOS data
   assign is_overflow        =  ls2is_overflow_i  & is_bos_tag;                                   //LS+IS overflow
   assign is_underflow       =  ls2is_underflow_i & ~is_tos_tag;                                  //LS+IS underflow

   //Internal control signals
   //------------------------

   //IS registers
   //------------
   assign is_cells_next      =
          ({16*IS_DEPTH{is_push}}      & {is_cells_reg[(16*IS_DEPTH)-17:0], us2is_push_data_i}) | //push cell from US
          ({16*IS_DEPTH{is_pull}}      & {16'h0000, is_cells_reg[(16*IS_DEPTH)-1:16]})          | //pull cell to US
          ({16*IS_DEPTH{is_flush}}     & {is_cells_reg[(16*IS_DEPTH)-17:0], 16'h0000})          | //flush cell on IS
        //({16*IS_DEPTH{is_reset}}     & {16*IS_DEPTH{1'b0}})                                   | //reset IS
           {16*IS_DEPTH{1'b0}};

   assign is_tags_next       =
          ({IS_DEPTH{is_push}}         & {is_tags_reg[IS_DEPTH-2:0], 1'b1})                     | //push cell from US
          ({IS_DEPTH{is_pull}}         & {1'b0, is_tags_reg[IS_DEPTH-1:1]})                     | //pull cell to US
          ({IS_DEPTH{is_flush}}        & {is_tags_reg[IS_DEPTH-2:0], 1'b0})                     | //flush cell on IS
          ({IS_DEPTH{is_reset}}        & {IS_DEPTH{1'b0}})                                      | //reset IS
           {IS_DEPTH{1'b0}};

   //FSM
   //---
   localparam STATE_IDLE  = 2'b00;                                                                //idle state
   localparam STATE_SET   = 2'b01;                                                                //idle state
   localparam STATE_GET   = 2'b10;                                                                //idle state
   localparam STATE_RESET = 2'b11;                                                                //idle state

   always @*
     begin

        case (state_reg)
          STATE_IDLE:
            begin
               //Defaults
               is_ready         = (~is_tos_tag | is_bos_tag) ? & ls2is_ready_i : 1'b1;            //propagate ready indicator
               is_push          = 1'b0;                                                           //don't push IS
               is_pull          = 1'b0;                                                           //don't pull IS
               is_flush         = 1'b0;                                                           //don't flush IS
               is_reset         = 1'b0;                                                           //don't reset IS
               ls_push          = 1'b0;                                                           //don't push to LS
               ls_pull          = 1'b0;                                                           //don't pull from LS
               ls_set           = 1'b0;                                                           //don't set LSP
               ls_get           = 1'b0;                                                           //don't get LSP
               ls_reset         = 1'b0;                                                           //don't reset LS
               state_next       = 2'b00;                                                          //next state

               //Handle requests
               if (us2is_push_i)
                 //Push request
                 begin
                    is_push    = is_push    | (~is_bos_tag | ls2is_ready_i);                      //push IS
                    ls_push    = ls_push    |  is_bos_tag;                                        //push LS
                    state_next = state_next |  STATE_IDLE;                                        //done or try again
                 end

               if (us2is_pull_i)
                 //Pull request
                 begin
                    is_pull    = is_pull    | (is_tos_tag | ls2is_ready_i);                       //pull IS
                    ls_pull    = ls_pull    |  ~is_tos_tag;                                       //pull from LS
                    state_next = state_next |  STATE_IDLE;                                        //done or try again
                 end

               if (us2is_set_i)
                 //Set request
                 begin
                    if (~is_tos_tag)
                      //IS is empty
                      begin
                         ls_set     = 1'b1;                                                       //push SP directly to the LS
                         state_next = state_next | STATE_IDLE;                                    //done or try again
                      end
                    else
                      //IS is not empty
                      begin
                         is_push    = is_push    |  (~is_bos_tag | ls2is_ready_i);                //push SP to IS
                         ls_push    = ls_push    |    is_bos_tag;                                 //push LS
                         state_next = state_next | ((~is_bos_tag | ls2is_ready_i) ? STATE_SET :   //flush IS
                                                                                    STATE_IDLE);  //retry initial push
                      end // else: !if(~is_tos_tag)
                 end // if (us2is_set_i)

               if (us2is_get_i)
                 //Get request
                 begin
                    if (~is_tos_tag)
                      //IS is empty
                      begin
                         ls_get     = 1'b0;                                                       //push LSP to TOS
                         state_next = state_next | STATE_IDLE;                                    //done or try again
                      end
                    else
                      //IS is not empty
                      begin
                         is_flush   = is_flush   | (~is_bos_tag | ls2is_ready_i);                 //flush IS
                         ls_push    = ls_push    |  is_bos_tag;                                   //push LS
                         state_next = state_next | STATE_GET;                                     //flush IS
                      end // else: !if(~is_tos_tag)
                 end // if (us2is_get_i)

               if (us2is_reset_i)
                 //Reset request
                 begin
                    is_reset   = is_reset  | ls2is_ready_i;                                       //don't reset IS
                    ls_reset   = 1'b1;                                                            //don't reset LS
                    state_next = state_next | (ls2is_ready_i ? STATE_IDLE : STATE_RESET);         //done or try again
                 end
            end // case: STATE_IDLE

          STATE_SET:
            begin
               //Defaults
               is_ready         = 1'b0;                                                           //deassert ready indicator
               is_push          = 1'b0;                                                           //don't push IS
               is_pull          = 1'b0;                                                           //don't pull IS
             //is_flush         = 1'b0;                                                           //don't flush IS
               is_reset         = 1'b0;                                                           //don't reset IS
             //ls_push          = 1'b0;                                                           //don't push to LS
               ls_pull          = 1'b0;                                                           //don't pull from LS
               ls_set           = 1'b0;                                                           //don't set LSP
               ls_get           = 1'b0;                                                           //don't get LSP
               ls_reset         = 1'b1;                                                           //don't reset LS

               if (is_bos_tag & ~is_abos_tag)
                 //Everythig is flushed except for SP value
                 begin
                    is_flush   = ls2is_ready_i;                                                   //flush IS
                    ls_set     = 1'b1;                                                            //push SP to the LS
                    state_next = ls2is_ready_i ? STATE_IDLE : STATE_SET;                          //done or try again
                 end
               else
                 //Keep flushing
                 begin
                    is_flush   = ~is_bos_tag | ls2is_ready_i;                                     //flush  IS
                    ls_push    = is_bos_tag;                                                      //push LS
                    state_next = STATE_SET;                                                       //flush IS
                 end // else: !if(is_bos_tag & ~is_abos_tag)
            end // case: STATE_SET

          STATE_GET:
            begin
               //Defaults
               is_ready         = 1'b0;                                                           //deassert ready indicator
               is_push          = 1'b0;                                                           //don't push IS
               is_pull          = 1'b0;                                                           //don't pull IS
             //is_flush         = 1'b0;                                                           //don't flush IS
               is_reset         = 1'b0;                                                           //don't reset IS
             //ls_push          = 1'b0;                                                           //don't push to LS
               ls_pull          = 1'b0;                                                           //don't pull from LS
               ls_set           = 1'b0;                                                           //don't set LSP
               ls_get           = 1'b0;                                                           //don't get LSP
               ls_reset         = 1'b1;                                                           //don't reset LS

               if (is_bos_tag & ~is_abos_tag)
                 //Everythig is flushed except for one cell
                 begin
                    is_flush   = ls2is_ready_i;                                                   //flush IS
                    ls_get     = 1'b1;                                                            //pull SP to the TOS of rhe LS
                    state_next = ls2is_ready_i ? STATE_IDLE : STATE_SET;                          //done or try again
                 end
               else
                 //Keep flushing
                 begin
                    is_flush   = ~is_bos_tag | ls2is_ready_i;                                     //flush  IS
                    ls_push    = is_bos_tag;                                                      //push LS
                    state_next = STATE_GET;                                                       //flush IS
                 end // else: !if(is_bos_tag & ~is_abos_tag)
            end // case: STATE_GET

          STATE_RESET:
            begin
               //Defaults
               is_ready         = 1'b0;                                                           //deassert ready indicator
               is_push          = 1'b0;                                                           //don't push IS
               is_pull          = 1'b0;                                                           //don't pull IS
               is_flush         = 1'b0;                                                           //don't flush IS
               is_reset         = 1'b0;                                                           //don't reset IS
               ls_push          = 1'b0;                                                           //don't push to LS
               ls_pull          = 1'b0;                                                           //don't pull from LS
               ls_set           = 1'b0;                                                           //don't set LSP
               ls_get           = 1'b0;                                                           //don't get LSP
               ls_reset         = 1'b1;                                                           //don't reset LS
               state_next       = ls2is_ready_i ? STATE_IDLE : STATE_RESET;                       //next state
            end // case: STATE_RESET
        endcase // case (state_reg)

     end // always @ *

   //Flip flops
   //----------
   //IS cells
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       is_cells_reg <= {IS_DEPTH{16'h0000}};
     else if (sync_rst_i)                                                                         //synchronous reset
       is_cells_reg <= {IS_DEPTH{16'h0000}};
     else if (~|IS_BYPASS & is_cells_we)                                                          //state transition
       is_cells_reg <= is_cells_next;

   //IS tags
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       is_tags_reg  <= {IS_DEPTH{1'b0}};
     else if (sync_rst_i)                                                                         //synchronous reset
       is_tags_reg  <= {IS_DEPTH{1'b0}};
     else if (~|IS_BYPASS & is_tags_we)                                                           //state transition
       is_tags_reg  <= is_tags_next;

   //FSM
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       state_reg <= STATE_IDLE;                                                                   //reset state
     else if (sync_rst_i)                                                                         //synchronous reset
       state_reg <= STATE_IDLE;                                                                   //reset state
     else if (~|IS_BYPASS)                                                                        //state transition
       state_reg <= state_next;                                                                   //state transition

   //Probe signals
   //-------------
   assign prb_is_cells_o     = is_cells_reg;                                                      //current IS cells
   assign prb_is_tags_o      = is_tags_reg;                                                       //current IS tags
   assign prb_is_state_o     = state_reg;                                                         //current state

endmodule // N1_is
