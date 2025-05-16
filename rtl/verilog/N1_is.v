//###############################################################################
//# N1 - Intermediate Stack                                                     #
//###############################################################################
//#    Copyright 2018 - 2025 Dirk Heisswolf                                     #
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
//#        Upper Stack     top   Intermediate Stack   bottom    Lower Stack     #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+---+    +---+---+---+... #
//#       |   |   |   |<->| 0 | 1 | 2 | 3 | 4 |   |n-1| n |--> |   |   |   |    #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+-+-+    +---+---+---+... #
//#                 ^                                            |              #
//#                 +--------------------------------------------+              #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 24, 2019                                                        #
//#      - Initial release                                                      #
//#   January 15, 2024                                                          #
//#      - New implementation                                                   #
//#   May 2, 2025                                                               #
//#      - New implementation                                                   #
//###############################################################################
`default_nettype none

module N1_is
  #(parameter  DEPTH       = 8,                                                                   //depth of the IS
    localparam STACK_WIDTH = (DEPTH == 0) ? 16 : 16*DEPTH,                                        //for IS bypass
    localparam TAG_WIDTH   = (DEPTH == 0) ?  1 :    DEPTH)                                        //for IS bypass

   (//Clock and reset
    input  wire                             clk_i,                                                //module clock
    input  wire                             async_rst_i,                                          //asynchronous reset
    input  wire                             sync_rst_i,                                           //synchronous reset

    //Interface to upper stack
    input  wire                             is_clear_i,                                           //IS clear request
    input  wire                             is_push_i,                                            //IS push request
    input  wire                             is_pull_i,                                            //IS pull request
    input  wire [15:0]                      is_push_data_i,                                       //IS push data
    output wire                             is_clear_bsy_o,                                       //IS clear busy indicator
    output wire                             is_push_bsy_o,                                        //IS push busy indicator
    output wire                             is_pull_bsy_o,                                        //IS pull busy indicator
    output wire                             is_empty_o,                                           //IS empty indicator
    output wire                             is_full_o,                                            //IS overflow indicator
    output wire [15:0]                      is_pull_data_o,                                       //IS pull data

    //Interface to lower stack
    input  wire                             ls_clear_bsy_i,                                       //LS clear busy indicator
    input  wire                             ls_push_bsy_i,                                        //LS push busy indicator
    input  wire                             ls_pull_bsy_i,                                        //LS pull busy indicator
    input  wire                             ls_empty_i,                                           //LS empty indicator
    input  wire                             ls_full_i,                                            //LS overflow indicator
    input  wire [15:0]                      ls_pull_data_i,                                       //LS pull data
    output wire                             ls_clear_o,                                           //LS clear request
    output wire                             ls_push_o,                                            //LS push request
    output wire                             ls_pull_o,                                            //LS pull request
    output wire [15:0]                      ls_push_data_o,                                       //LS push data

    //Probe signals
    output wire [STACK_WIDTH-1:0]           prb_is_cells_o,                                        //probed cells
    output wire [TAG_WIDTH-1:0]             prb_is_tags_o);                                        //probed tags

   //Registers
   //---------
   //Stack
   reg  [STACK_WIDTH-1:0]                   is_cells_reg;                                         //current IS
   reg  [TAG_WIDTH-1:0]                     is_tags_reg;                                          //current IS

   //Internal signals
   //-----------------
   //Stack
   wire [STACK_WIDTH+15:0]                   is_cells_pushed;                                      //pushed IS
   wire [STACK_WIDTH+15:0]                   is_cells_pulled;                                      //pulled IS
   //Tags
   wire [TAG_WIDTH:0]                        is_tags_pushed;                                       //pushed IS
   wire [TAG_WIDTH:0]                        is_tags_pulled;                                       //pulled IS
   //Probes
   wire [TAG_WIDTH+STACK_WIDTH-1:0]          prb_concat;                                           //concatinated probe signals
   
   //Interface to upper stack
   //------------------------
   assign  is_clear_bsy_o  = ls_clear_bsy_i;                                                             //US clear busy indicator
   assign  is_push_bsy_o   = (DEPTH == 0) ? ls_push_bsy_i  :  is_tags_reg[TAG_WIDTH-1] & ls_push_bsy_i;  //US push busy indicator
   assign  is_pull_bsy_o   = (DEPTH == 0) ? ls_pull_bsy_i  : ~is_tags_reg[0]           & ls_pull_bsy_i;  //US pull busy indicator
   assign  is_empty_o      = (DEPTH == 0) ? ls_empty_i     : ~is_tags_reg[0]           & ls_empty_i;     //US empty indicator
   assign  is_full_o       = (DEPTH == 0) ? ls_full_i      :  is_tags_reg[TAG_WIDTH-1] & ls_full_i;      //US overflow indicator
   assign  is_pull_data_o  = (DEPTH == 0) ? ls_pull_data_i : ~is_tags_reg[0] ? ls_pull_data_i     :      //US pull data
                                                                               is_cells_reg[15:0];

   //Interface to lower stack
   //------------------------
   assign  ls_clear_o      = is_clear_i;                                                                 //LS clear request
   assign  ls_push_o       = (DEPTH == 0) ? is_push_i      :  is_tags_reg[TAG_WIDTH-1] & is_push_i;      //LS push request
   assign  ls_pull_o       = (DEPTH == 0) ? is_pull_i      : ~is_tags_reg[0]           & is_pull_i;      //LS pull request
   assign  ls_push_data_o  = (DEPTH == 0) ? is_push_data_i : is_cells_reg[STACK_WIDTH-1:STACK_WIDTH-16]; //LS push data

   //Stack buffer
   //------------
   assign  is_cells_pushed = (DEPTH == 0) ? {STACK_WIDTH+16{1'b0}} : {is_cells_reg,is_push_data_i};                             //pushed IS
   assign  is_cells_pulled = (DEPTH == 0) ? {STACK_WIDTH+16{1'b0}} : {is_cells_reg[STACK_WIDTH-1:STACK_WIDTH-16],is_cells_reg}; //pulled IS
   assign  is_tags_pushed  = (DEPTH == 0) ? {TAG_WIDTH+1{1'b0}}    : {is_tags_reg,1'b1};                                        //pushed IS
   assign  is_tags_pulled  = (DEPTH == 0) ? {TAG_WIDTH+1{1'b0}}    : {1'b0,is_tags_reg};                                        //pulled IS

   //IS cells
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       is_cells_reg <= {STACK_WIDTH{1'b0}};
     else if (sync_rst_i)                                                                         //synchronous reset
       is_cells_reg <= {STACK_WIDTH{1'b0}};
     else if (~is_clear_i &  is_push_i & ~is_pull_i & ~is_push_bsy_o)                             //push
       is_cells_reg <= is_cells_pushed[STACK_WIDTH-1:0];
     else if (~is_clear_i & ~is_push_i &  is_pull_i & ~is_pull_bsy_o)                             //pull
       is_cells_reg <= is_cells_pulled[STACK_WIDTH+15:16];

   //IS tags
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       is_tags_reg  <= {TAG_WIDTH{1'b0}};
     else if (sync_rst_i)                                                                         //synchronous reset
       is_tags_reg  <= {TAG_WIDTH{1'b0}};
     else if (is_clear_i & ~is_clear_bsy_o)                                                       //soft reset
       is_tags_reg <= {TAG_WIDTH{1'b0}};
     else if ( is_push_i & ~is_pull_i & ~is_push_bsy_o)                                           //push
       is_tags_reg <= is_tags_pushed[TAG_WIDTH-1:0];
     else if (~is_push_i &  is_pull_i & ~is_pull_bsy_o)                                           //pull
       is_tags_reg <= is_tags_pulled[TAG_WIDTH:1];

   //Probe signals
   //-------------
   assign prb_concat = {is_tags_reg,     // 17*DEPTH-1 ... 16*DEPTH                               //concatinated probe signals
                        is_cells_reg};   // 16*DEPTH-1 ... 0
   assign prb_is_o = (DEPTH == 0) ? {PROBE_WIDTH{1'b0}} : prb_concat[PROBE_WIDTH-1:0];            //probe outputs

   // Probe signals
   //---------------------------
   // is_tags_reg[DEPTH-1:0]
   // is_cells_reg[16*DEPTH-1:0]

   //Assertions
   //----------
`ifdef FORMAL
   //Input checks
   //------------
   //Inputs is_rst_i, is_push_i, and is_pull_i must be mutual exclusive
   //N1_is_iasrt1:
   //assert(&{~us2is_push_i, ~us2is_pull_i} |
   //       &{ us2is_push_i, ~us2is_pull_i} |
   //       &{~us2is_push_i,  us2is_pull_i});

   //State consistency checks
   //------------------------
   always @(posedge clk_i) begin
      //No gaps between tags
      for (int i=DEPTH-1; i>=1 ;i=i-1) begin
        N1_is_sasrt1:
        assert(is_tags_reg[i] ? is_tags_reg[i-1] : 1'b1);
      end

      //Upper tags can only be set through a push request
      for (int i=DEPTH-1; i>=2 ;i=i-1) begin
         N1_is_sasrt2:
         assert($rose(is_tags_reg[i]) ? $past(is_push_i & ~is_push_bsy_o) : 1'b1);
      end

      ////Unless a reset occured, tags can only be cleared through a pull request
      //for (int i=DEPTH-1; i>=0 ;i=i-1) begin
      //   N1_is_sasrt3:
      //   assert(      ~async_rst_i   &
      //          $past(~async_rst_i   &
      //                ~us2is_rst_i)  &
      //         $fell(is_tags_reg[i]) ? $past(us2ls_pull_i & ~us2ls_pull_bsy_o) : 1'b1);
      //end

   end // always @ (posedge clk_i)

`endif //  `ifdef FORMAL

endmodule // N1_is
