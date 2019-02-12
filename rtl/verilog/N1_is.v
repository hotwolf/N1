//###############################################################################
//# N1 - Intermediate and Lower Stack                                           #
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
//#    This module implements the intermediate stack of the N1 processor. The   #
//#    intermediate stack receives push or pull requests from the upper stack.  #
//#    If possible these requests are executed on internal storage. In case of  #
//#    over or underflows, the requests are executed on the lower stack, which  #
//#    resides in RAM                                   .                       #
//#                                                                             #
//#        Upper Stack           Intermediate Stack                             #
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
//###############################################################################
//# Version History:                                                            #
//#   December 3, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_is
  #(parameter   SP_WIDTH        =      12,                           //width of the stack pointer
    parameter   IS_DEPTH        =       8,                           //depth of the intermediate stack
    parameter   LS_START        = 12'hfff)                           //stack pointer value of the empty lower stack

   (//Clock and reset
    input  wire                             clk_i,                   //module clock
    input  wire                             async_rst_i,             //asynchronous reset
    input  wire                             sync_rst_i,              //synchronous reset

    //ALU interface
    output wire [IS_DEPTH-1:0]              is2alu_tags_o,          //cell tags
    output wire [SP_WIDTH-1:0]              is2alu_lsp_o,            //lower stack pointer

    //DSP partition interface
    input  wire [SP_WIDTH-1:0]              dsp2is_lsp_i,             //lower stack pointer
    output reg                              is2dsp_psh_o,            //push (decrement address)
    output reg                              is2dsp_pul_o,            //pull (increment address)
    output reg                              is2dsp_rst_o,            //reset AGU

    //Exception aggregator interface
    output reg                              is2excpt_buserr_o,       //bus error

    //Stack bus arbiter interface
    output reg                              is2sarb_cyc_o,           //bus cycle indicator       +-
    output reg                              is2sarb_stb_o,           //access request            | initiator
    output reg                              is2sarb_we_o,            //write enable              | to
    output wire [SP_WIDTH-1:0]              is2sarb_adr_o,           //address bus               | target
    output wire [15:0]                      is2sarb_dat_o,           //write data bus            +-
    input  wire                             sarb2is_ack_i,           //bus cycle acknowledge     +-
    input  wire                             sarb2is_err_i,           //error indicator           | target
    input  wire                             sarb2is_rty_i,           //retry request             | to
    input  wire                             sarb2is_stall_i,         //access delay              | initiator
    input  wire [15:0]                      sarb2is_dat_i,           //read data bus             +-

    //Upper stack interface
    input  wire                             us2is_rst_i,             //reset stack
    input  wire                             us2is_psh_i,             //US  -> IRS
    input  wire                             us2is_pul_i,             //IRS -> US
    input  wire                             us2is_psh_ctag_i,        //upper stack cell tag
    input  wire [15:0]                      us2is_psh_cell_i,        //upper stack cell
    output reg                              is2us_busy_o,            //intermediate stack is busy
    output wire                             is2us_pul_ctag_o,        //intermediate stack cell tag
    output wire [15:0]                      is2us_pul_cell_o,        //intermediate stack cell

    //Probe signals
    output wire [IS_DEPTH-1:0]              prb_is_tags_o,           //intermediate stack cell tags
    output wire [(IS_DEPTH*16)-1:0]         prb_is_cells_o,          //intermediate stack cells
    output wire [SP_WIDTH-1:0]              prb_is_lsp_o,            //lower stack pointer
    output wire [1:0]                       prb_is_state_o);         //FSM state

   //Internal Signals
   //----------------
   //Intermediate stack registers
   reg  [IS_DEPTH-1:0]                      is_tags_reg;            //intermediate stack cell tags
   reg  [(IS_DEPTH*16)-1:0]                 is_cells_reg;            //intermediate stack cells
   wire [IS_DEPTH-1:0]                      is_tags_next;           //intermediate stack cell tags
   wire [(IS_DEPTH*16)-1:0]                 is_cells_next;           //intermediate stack cells
   //Intermediate stack indicators
   wire                                     is_empty;                //intermediate stack is empty
   wire                                     is_almost_empty;         //only one cell left
   wire                                     is_full;                 //intermediate stack is full
   wire                                     is_almost_full;          //only room for one more cell
   wire                                     is_needs_load;           //transfer from lower stack required
   wire                                     is_needs_unload;         //transfer to lower stack required
   //Intermediate stack actions
   reg                                      is_push;                 //push to upper stack
   reg                                      is_pull;                 //pull from upper stack
   reg                                      is_load;                 //load from lower stack
   reg                                      is_unload;               //unload to lower stack
   reg                                      is_reset;                //reset intermediate stack

   //Lower stack
   wire                                     ls_empty;                //lower stack is empty

   //FSM
   reg  [1:0]                               state_reg;               //FSM state variable
   reg  [1:0]                               state_next;              //FSM next state

   //Lower stack
   //-----------
   //Indicators
   assign ls_empty      = ~|(dsp2is_lsp_i ^ LS_START);
   //Stack bus arbiter interface
   assign is2sarb_adr_o = dsp2is_lsp_i;                              //address bus
   assign is2sarb_dat_o = is_cells_reg[(16*IS_DEPTH)-1:16*(IS_DEPTH-1)];//write data bus

   //Intermediate stack
   //------------------
   //Indicators
   assign is_empty         = ~is_tags_reg[0];                        //IS is empty
   assign is_almost_empty  = ~is_tags_reg[1];                        //IS is almost empty or empty
   assign is_full          =  is_tags_reg[IS_DEPTH-1];               //IM is full
   assign is_almost_full   =  is_tags_reg[IS_DEPTH-2];               //IM is almost full or full
   assign is_needs_load    =  ~ls_empty &                            //LS not empty and
                              (is_empty |                            // IS empty or
                               (is_almost_empty & us2is_pul_i));     // pull from almost empty IS
   assign is_needs_unload  = is_full |                               // IS full or
                             (is_almost_full & us2is_psh_i);         // push to almost full IS
   //Cell tag transitions
   assign is_tags_next = (is_push   ? {{is_tags_reg[IS_DEPTH-2:0]}, us2is_psh_ctag_i} : {IS_DEPTH{1'b0}}) |
                          (is_pull   ? {2'b00, is_tags_reg[IS_DEPTH-2:1]}              : {IS_DEPTH{1'b0}}) |
                          (is_load   ? {{IS_DEPTH-1{1'b0}}, 1'b1}                       : {IS_DEPTH{1'b0}}) |
                          (is_unload ? {1'b0, {IS_DEPTH-1{1'b1}}}                       : {IS_DEPTH{1'b0}});

   //Cell transitions
   assign is_cells_next = (is_push   ?
                             {is_cells_reg[(16*(IS_DEPTH-1))-1:0], us2is_psh_cell_i} :
                             {16*IS_DEPTH{1'b0}})                                     |
                          (is_pull   ?
                            {{2*16{1'b0}}, is_cells_reg[(16*(IS_DEPTH-1))-1:16]}     :
                            {16*IS_DEPTH{1'b0}})                                      |
                          (is_load   ?
                             {{16*(IS_DEPTH-1){1'b0}}, sarb2is_dat_i}                :
                             {16*IS_DEPTH{1'b0}})                                     |
                          (is_unload ?
                             {{16{1'b0}}, is_cells_reg[(16*(IS_DEPTH-1))-1:0]}       :
                          {16*IS_DEPTH{1'b0}});
   //Flip-flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                //asynchronous reset
       begin
          is_tags_reg <= {IS_DEPTH{1'b0}};
          is_cells_reg <= {16*IS_DEPTH{1'b0}};
     end
     else if (sync_rst_i)                                            //synchronous reset
       begin
          is_tags_reg <= {IS_DEPTH{1'b0}};
          is_cells_reg <= {16*IS_DEPTH{1'b0}};
       end
     else if (is_push | is_pull | is_load | is_unload | is_reset)    //stack operation
       begin
          is_tags_reg <= is_tags_next;
          is_cells_reg <= is_cells_next;
       end

   //Upper stack
   //-----------
   assign is2us_pul_ctag_o = is_tags_reg[0];                         //intermediate stack cell tag
   assign is2us_pul_cell_o = is_cells_reg[15:0];                     //intermediate stack cell

   //Finite state machine
   //--------------------
   localparam STATE_RESET   = 2'b00;                                 //awaiting bus request (reset state)
   localparam STATE_READY   = 2'b01;                                 //awaiting bus acknowledge
   localparam STATE_LOAD    = 2'b10;                                 //awaiting bus acknowledge
   localparam STATE_UNLOAD  = 2'b11;                                 //unreachable state
   always @*
     begin
        //Default outputs
        state_next          = state_reg;                             //remain in current state
        is_push             = 1'b0;                                  //don't push to upper stack
        is_pull             = 1'b0;                                  //don't pull from upper stack
        is_load             = 1'b0;                                  //don't load from lower stack
        is_unload           = 1'b0;                                  //don't unload to lower stack
        is_reset            = 1'b0;                                  //don't reset intermediate stack
        is2us_busy_o        = (~ls_empty & is_empty) | is_full;      //busy if imediate stack need action
        is2excpt_buserr_o   = 1'b0;                                  //no exceptionbus error
        is2sarb_cyc_o       = 1'b0;                                  //no bus request
        is2sarb_stb_o       = 1'b0;                                  //no bus request
        is2sarb_we_o        = is_needs_unload;                       //write on unload
        is2dsp_psh_o        = 1'b0;                                  //don't push to lower stack
        is2dsp_pul_o        = 1'b0;                                  //don't pull from lower stack
        is2dsp_rst_o        = us2is_rst_i;                           //reset lower stack on request

        case (state_reg)
          STATE_RESET:
            begin
               state_next   = STATE_READY;                           //stack ready
               is2dsp_rst_o = 1'b1;                                  //reset lower stack
               is_reset     = 1'b1;                                  //reset intermediate stack
               is2us_busy_o = 1'b1;                                  //busy signal
            end // case: STATE_RESET

          STATE_READY:                                               //no ongoing bus cycle
            begin
               //Load/unload
               if (is_needs_load | is_needs_unload)
                 begin
                    is2sarb_cyc_o = 1'b1;                            //no bus request
                    is2sarb_stb_o = 1'b1;                            //no bus request
                    if (~sarb2is_stall_i)                            //stack bus is busy
                      state_next = (is_needs_load ?                  //either load
                                     STATE_LOAD : 2'b00) |           //
                                   (is_needs_unload ?                //or unload
                                     STATE_UNLOAD : 2'b00);          //
                 end
            end // case: STATE_READY

          STATE_LOAD:                                                //load cycle ongoing
            begin
               is_load           = sarb2is_ack_i;                    //load from lower stack
               is2dsp_pul_o      = sarb2is_ack_i;                    //adjust stack pointer
               is2excpt_buserr_o = sarb2is_err_i;                    //bus error
               if (sarb2is_ack_i |
                   sarb2is_rty_i |
                   sarb2is_err_i)
                 state_next    = STATE_READY;                        //remain in current state
            end // case: STATE_LOAD

          STATE_UNLOAD:                                              //unload cycle ongoing
            begin
               is_unload         = sarb2is_ack_i;                    //unload to lower stack
               is2dsp_psh_o      = sarb2is_ack_i;                    //adjust stack pointer
               is2excpt_buserr_o = sarb2is_err_i;                    //bus error
               if (sarb2is_ack_i |
                   sarb2is_rty_i |
                   sarb2is_err_i)
                 state_next    = STATE_READY;                        //remain in current state
            end // case: STATE_UNLOAD

        endcase // case (state_reg)
     end // always @ *

   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                //asynchronous reset
       state_reg <= STATE_RESET;
     else if (sync_rst_i)                                            //synchronous reset
       state_reg <= STATE_RESET;
     else
       state_reg <= state_next;                                      //state transition

   //ALU interface
   //-------------
   assign is2alu_tags_o  = is_tags_reg;                              //intermediate stack cell tags
   assign is2alu_lsp_o   = dsp2is_lsp_i;                             //stack pointer

   //Probe signals
   //-------------
   assign prb_is_tags_o  = is_tags_reg;                              //intermediate stack cell tags
   assign prb_is_cells_o = is_cells_reg;                             //intermediate stack cells
   assign prb_is_lsp_o   = dsp2is_lsp_i;                             //stack pointer
   assign prb_is_state_o = state_reg;                                //FSM state

endmodule // N1_is
