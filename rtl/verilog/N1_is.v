//###############################################################################
//# N1 - Intermediate Stack                                                     #
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
//#       RESET: Clear the stack                                                #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 24, 2019                                                        #
//#      - Initial release                                                      #
//#   January 15, 2024                                                          #
//#      - New implementation                                                   #
//###############################################################################
`default_nettype none

module N1_is
  #(parameter IS_DEPTH  = 8)                                                                      //depth of the IS (must be >=2)

   (//Clock and reset
    input  wire                             clk_i,                                                //module clock
    input  wire                             async_rst_i,                                          //asynchronous reset
    input  wire                             sync_rst_i,                                           //synchronous reset

    //Soft reset
    input  wire                             us2is_clr_i,                                          //IS stack reset request

    //Interface to upper stack
    input  wire [15:0]                      us2is_push_data_i,                                    //US push data
    input  wire                             us2is_push_i,                                         //US push request
    input  wire                             us2is_pull_i,                                         //US pull request
    output reg  [15:0]                      is2us_pull_data_o,                                    //US pull data
    output reg                              is2us_push_bsy_o,                                     //US push busy indicator
    output reg                              is2us_pull_bsy_o,                                     //US pull busy indicator
    output reg                              is2us_empty_o,                                        //US empty indicator
    output reg                              is2us_full_o,                                         //US overflow indicator

    //Interface to lower stack
    input  wire [15:0]                      ls2is_pull_data_del_i,                                //LS delayed pull data (available one cycle after the pull request)
    input  wire                             ls2is_push_bsy_i,                                     //LS push busy indicator
    input  wire                             ls2is_pull_bsy_i,                                     //LS pull busy indicator
    input  wire                             ls2is_empty_i,                                        //LS empty indicator
    input  wire                             ls2is_full_i,                                         //LS overflow indicator
    output reg  [15:0]                      is2ls_push_data_o,                                    //LS push data
    output reg                              is2ls_push_o,                                         //LS push request
    output reg                              is2ls_pull_o,                                         //LS pull request

    //Probe signals
    output wire [(16*IS_DEPTH)-1:0]         prb_is_cells_o,                                       //current IS cells
    output wire [IS_DEPTH-1:0]              prb_is_tags_o,                                        //current IS tags
    output wire                             prb_is_state_o);                                      //current state

   //Internal signals
   //-----------------
   //Stack
   reg  [(16*IS_DEPTH)-1:0]                 is_cells_reg;                                         //current IS
   reg  [(16*IS_DEPTH)-1:0]                 is_cells_next;                                        //next IS
   reg  [IS_DEPTH-1:0]                      is_tags_reg;                                          //current IS
   reg  [IS_DEPTH-1:0]                      is_tags_next;                                         //next IS
   reg                                      is_we;                                                //IS write enable
   wire                                     is_empty;                                             //IS is empty
   wire                                     is_almost_empty;                                      //IS is almost empty
   wire                                     is_full;                                              //IS is full


   //US
   reg                                      state_reg;                                            //current state
   reg                                      state_next;                                           //next state

   //Stack status
   assign  is_empty         = ~is_tags_reg[0];                                                    //IS is empty if first element is empty
   assign  is_almost_empty  = ~is_tags_reg[1];                                                    //IS is almost empty if second element is empty
   assign  is_full          =  is_tags_reg[IS_DEPTH-1];                                           //IS is full  if last  element is full

   //US
   //---
   localparam STATE_NO_LS_PULL = 1'b0;                                                            //buffered IS operation
   localparam STATE_LS_PULL    = 1'b1;                                                            //pull data from LS is available

   always @*
     begin
        //Defaults
        is2us_pull_data_o  = 16'h0000;                                                            //US pull data
        is2us_push_bsy_o   = 1'b0;                                                                //US push busy indicator
        is2us_pull_bsy_o   = 1'b0;                                                                //US pull busy indicator
        is2us_empty_o      = 1'b0;                                                                //US stack empty indicator
        is2us_full_o       = is_full & ls2is_full_i;                                              //US stack full indicator
        is2ls_push_data_o  = 16'h0000;                                                            //LS push data
        is2ls_push_o       = 1'b0;                                                                //LS push request
        is2ls_pull_o       = 1'b0;                                                                //LS pull request
        is_cells_next      = {IS_DEPTH{16'h0000}};                                                //LS next IS
        is_tags_next       = {IS_DEPTH{1'b0}};                                                    //LS next IS
        is_we              = 1'b0;                                                                //IS write enable
        state_next         = STATE_NO_LS_PULL;                                                    //next state

        case (state_reg)
          STATE_NO_LS_PULL:
            begin
               //State defaults
               is2us_pull_data_o  |= is_cells_reg[15:0];                                          //US pull data
               is2ls_push_data_o  |= is_cells_reg[(16*IS_DEPTH)-1:(16*IS_DEPTH)-16];              //LS push data
               is2us_push_bsy_o   |= is_full & ls2is_push_bsy_i;                                  //push busy indicator
               //is2us_pull_bsy_o |= is_empty;                                                    //US pull busy indicator

               //Push request
               if (us2is_push_i)
                 begin
                    //Prepare shift
                    is_cells_next[(16*IS_DEPTH)-1:0] |= {is_cells_reg[(16*IS_DEPTH)-17:0],us2is_push_data_i}; //next IS
                    is_tags_next[IS_DEPTH-1:0]       |= {is_tags_reg[IS_DEPTH-2:0],1'b1};                     //next IS
                    //Execute push request
                    if (~is_full | ~ls2is_push_bsy_i)
                      begin
                         is_we         |= 1'b1;                                                   //IS write enable
                         is2ls_push_o  |= is_full;                                                //LS push request
                      end
                 end // if (us_push_i)

               //Pull request
               if (us2is_pull_i)
                 begin
                    //Prepare shift
                    is_cells_next[(16*IS_DEPTH)-17:0] |= is_cells_reg[(16*IS_DEPTH)-1:16];        //next IS
                    is_tags_next[IS_DEPTH-1:0]        |= {1'b0,is_tags_reg[IS_DEPTH-2:0]};        //next IS
                    //Execute pull request
                    is_we              |= 1'b1;                                                   //IS write enable
                 end // if (us_pull_i)

               //Request LS pull
               if ( is_empty |
                   (is_almost_empty & us2is_pull_i & ~ls2is_pull_bsy_i))
                 begin
                    is2ls_pull_o  |= 1'b1;                                                        //LS pull request
                    state_next     = ls2is_pull_bsy_i ? STATE_NO_LS_PULL : STATE_LS_PULL;         //next state
                 end

               //Clear request
               if (us2is_clr_i)
                 begin
                    is2ls_push_o       = 1'b0;                                                    //LS push request
                    is2ls_pull_o       = 1'b0;                                                    //LS pull request
                    //is_cells_next    = {IS_DEPTH{16'h0000}};                                    //LS next IS
                    is_tags_next       = {IS_DEPTH{1'b0}};                                        //LS next IS
                    is_we              = 1'b1;                                                    //IS write enable
                    state_next         = STATE_NO_LS_PULL;                                        //next state
                 end

            end // case: STATE_LS_IDLE,...

          STATE_LS_PULL:
            begin
               //State defaults
               is2us_pull_data_o    |= ls2is_pull_data_del_i;                                     //US pull data
               //is2ls_push_data_o  |= 16'hxxxx;                                                  //LS push data
               //is2us_push_bsy_o   |= 1'b0;                                                      //push busy indicator
               //is2us_pull_bsy_o   |= 1'b0;                                                      //US pull busy indicator

               //Push request
               if (us2is_push_i)
                 begin
                    //Prepare shift
                    is_cells_next[31:0] = {ls2is_pull_data_del_i,us2is_push_data_i};              //next IS
                    is_tags_next[1:0]   = 2'b11;                                                  //next IS
                  //if (IS_DEPTH > 2)
                  //  begin
                  //     is_cells_next[(16*IS_DEPTH)-1:32] |= is_cells_reg[(16*IS_DEPTH)-17:16];  //next IS
                  //     is_tags_next[IS_DEPTH-1:2]        |= is_tags_reg[IS_DEPTH-2:1];          //next IS
                  //  end
                    //Execute push request
                    is_we         |= 1'b1;                                                        //IS write enable
                 end // if (us_push_i)

               //Pull request
               if (us2is_pull_i)
                 begin
                    //Request LS pull
                    begin
                       is2ls_pull_o  |= 1'b1;                                                     //LS pull request
                       state_next     = ls2is_pull_bsy_i ? STATE_LS_PULL : STATE_NO_LS_PULL;      //next state
                    end
                 end

               //Capture LS pull data
               if (~us2is_push_i & ~us2is_pull_i)
                 begin

                    //Prepare shift
                    is_cells_next[15:0] = us2is_push_data_i;                                      //next IS
                    is_tags_next[0]     = 1'b1;                                                   //next IS
                  //if (IS_DEPTH > 2)
                  //  begin
                  //     is_cells_next[(16*IS_DEPTH)-1:16] |= is_cells_reg[(16*IS_DEPTH)-17:0];  //next IS
                  //     is_tags_next[IS_DEPTH-1:1]        |= is_tags_reg[IS_DEPTH-2:0];          //next IS
                  //  end
                    //Capture LS data
                    is_we         |= 1'b1;                                                        //IS write enable
                 end // if (~us_push_i & ~us_pull_i & ~is_rst_i)

               //Clear request
               if (us2is_clr_i)
                 begin
                    is2ls_push_o       = 1'b0;                                                    //LS push request
                    is2ls_pull_o       = 1'b0;                                                    //LS pull request
                    //is_cells_next    = {IS_DEPTH{16'h0000}};                                    //LS next IS
                    is_tags_next       = {IS_DEPTH{1'b0}};                                        //LS next IS
                    is_we              = 1'b1;                                                    //IS write enable
                    state_next         = STATE_NO_LS_PULL;                                        //next state
                 end
            end // case: STATE_LS_PULL
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
     else if (is_we)                                                                              //state transition
       is_cells_reg <= is_cells_next;

   //IS tags
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       is_tags_reg  <= {IS_DEPTH{1'b0}};
     else if (sync_rst_i)                                                                         //synchronous reset
       is_tags_reg  <= {IS_DEPTH{1'b0}};
     else if (is_we)                                                                              //state transition
       is_tags_reg  <= is_tags_next;

   //FSM
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       state_reg <= STATE_NO_LS_PULL;
     else if (sync_rst_i)                                                                         //synchronous reset
       state_reg <= STATE_NO_LS_PULL;
     else                                                                                         //state transition
       state_reg <= state_next;

   //Probe signals
   //-------------
   assign prb_is_cells_o     = is_cells_reg;                                                      //current IS cells
   assign prb_is_tags_o      = is_tags_reg;                                                       //current IS tags
   assign prb_is_state_o     = state_reg;                                                         //current state

   //Assertions
   //----------
`ifdef FORMAL
   //Input checks
   //------------
   //Inputs is_rst_i, us_push_i, and us_pull_i must be mutual exclusive
   N1_is_iasrt1:
   assert(&{~us2is_push_i, ~us2is_pull_i} |
          &{ us2is_push_i, ~us2is_pull_i} |
          &{~us2is_push_i,  us2is_pull_i});

   //State consistency checks
   //------------------------
   always @(posedge clk_i) begin
      //No gaps between tags
      for (int i=IS_DEPTH-1; i>=1 ;i=i-1) begin
        N1_is_sasrt1:
        assert(is_tags_reg[i] ? is_tags_reg[i-1] : 1'b1);
      end

      //Upper tags can only be set through a push request
      for (int i=IS_DEPTH-1; i>=2 ;i=i-1) begin
         N1_is_sasrt2:
         assert($rose(is_tags_reg[i]) ? $past(us_push_i & ~us_push_bsy_o) : 1'b1);
      end

      //Unless a reset occured, tags can only be cleared through a pull request
      for (int i=IS_DEPTH-1; i>=0 ;i=i-1) begin
         N1_is_sasrt3:
         assert(      ~async_rst_i   &
                $past(~async_rst_i   &
                      ~us2is_rst_i)  &
               $fell(is_tags_reg[i]) ? $past(us2ls_pull_i & ~us2ls_pull_bsy_o) : 1'b1);
      end

      //LS pull data is pending one cycle after an unstalled LS pull request
      assert((state_reg == STATE_LS_PULL) ? $past(is2ls_pull_o & ~ls2is_pull_bsy_i);

      //Whenever LS pull data is pending, the IS must be empty
      assert((state_reg == STATE_LS_PULL) ? is_empty : 1'b1);

   end // always @ (posedge clk_i)

`endif //  `ifdef FORMAL

endmodule // N1_is
