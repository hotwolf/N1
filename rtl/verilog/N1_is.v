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
  #(parameter   SP_WIDTH        =     8,                       //width of the stack pointer
    parameter   IS_DEPTH        =     8,                       //depth of the intermediate stack
    parameter   LS_EMPTY        = 8'h00,                       //stack pointer value of the empty lower stack 
    localparam  CELL_WIDTH      =    16)                       //cell width
                                                               //1=lower stack grows towards higher addresses
   (//Clock and reset
    input  wire                             clk_i,             //module clock
    input  wire                             async_rst_i,       //asynchronous reset
    input  wire                             sync_rst_i,        //synchronous reset

    //Upper stack - intermediate stack interface
    input  wire                             us_is_rst_i,       //reset stack
    input  wire                             us_is_psh_i,       //US  -> IRS
    input  wire                             us_is_pul_i,       //IRS -> US
    input  wire                             us_is_psh_ctag_i,  //upper stack cell tag
    input  wire [CELL_WIDTH-1:0]            us_is_psh_cell_i,  //upper stack cell
    output reg                              us_is_busy_o,      //intermediate stack is busy
    output wire                             us_is_pul_ctag_o,  //intermediate stack cell tag
    output wire [CELL_WIDTH-1:0]            us_is_pul_cell_o,  //intermediate stack cell
 
    //Intermediate stack - exception interface
    output wire                             is_excpt_buserr_o, //bus error

    //Intermediate stack - stack bus arbiter interface (wishbone)
    output reg                              is_sarb_cyc_o,     //bus cycle indicator       +-
    output reg                              is_sarb_stb_o,     //access request            | initiator
    output reg                              is_sarb_we_o,      //write enable              | to
    output wire [SP_WIDTH-1:0]              is_sarb_adr_o,     //address bus               | target
    output wire [CELL_WIDTH-1:0]            is_sarb_dat_o,     //write data bus            +-
    input  wire                             is_sarb_ack_i,     //bus cycle acknowledge     +-
    input  wire                             is_sarb_err_i,     //error indicator           | target
    input  wire                             is_sarb_rty_i,     //retry request             | to
    input  wire                             is_sarb_stall_i,   //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]            is_sarb_dat_i,     //read data bus             +-

    //Intermediate return stack - ALU interface
    output wire [IS_DEPTH-1:0]              is_alu_ctags_o,    //cell tags

    //Intermediate stack - hard macro interface
    output reg                              is_hm_psh_o,       //push (decrement address)
    output reg                              is_hm_pul_o,       //pull (increment address)
    output reg                              is_hm_rst_o,       //reset AGU
    input  wire [SP_WIDTH-1:0]              is_hm_sp_i,        //stack pointer

    //Probe signals
    output wire [IS_DEPTH-1:0]              prb_is_ctags_o,    //intermediate stack cell tags
    output wire [(IS_DEPTH*CELL_WIDTH)-1:0] prb_is_cells_o;    //intermediate stack cells
    output wire [SP_WIDTH-1:0]              prb_is_sp_o,       //stack pointer
    output wire [1:0]                       prb_is_state_o);   //FSM state

   //Internal Signals
   //----------------
   //Intermediate stack
   reg  [IS_DEPTH-1:0]                      is_ctags_reg;      //intermediate stack cell tags
   reg  [(IS_DEPTH*CELL_WIDTH)-1:0]         is_cells_reg;      //intermediate stack cells
   wire [IS_DEPTH-1:0]                      is_ctags_next;     //intermediate stack cell tags
   wire [(IS_DEPTH*CELL_WIDTH)-1:0]         is_cells_next;     //intermediate stack cells
 
   wire                                     is_empty;          //intermediate stack is empty
   wire                                     is_almost_empty;   //only one cell left
   wire                                     is_full;           //intermediate stack is full
   wire                                     is_almost_full;    //only room for one more cell
   wire                                     is_needs_load;     //transfer from lower stack required
   wire                                     is_needs_unload;   //transfer to lower stack required 

   wire                                     is_push;           //push to upper stack 
   wire                                     is_pull;           //pull from upper stack 
   reg                                      is_load;           //load from lower stack
   reg                                      is_unload;         //unload to lower stack 
   reg                                      is_reset;          //reset intermediate stack 

   //Lower stack
   wire                                     ls_empty;          //lower stack is empty
      
   //FSM
   reg  [1:0]                               state_reg;         //FSM state variable
   reg  [1:0]                               state_next;        //FSM next state
 
   //Upper stack
   //-----------
   assign us_is_pul_ctag_o = is_ctags[0];                      //intermediate stack cell tag
   assign us_is_pul_cell_o = is_cells[CELL_WIDTH-1:0];         //intermediate stack cell
   
   //Intermediate stack
   //------------------
   assign is_empty         = ~is_ctags_reg[0];                 //intermediate stack is empty
   assign is_almost_empty  = ~is_ctags_reg[1];                 //only one cell left
   assign is_full;         =  is_ctags_reg[IS_DEPTH-1];        //intermediate stack is full
   assign is_almost_full;  =  is_ctags_reg[IS_DEPTH-2];        //only room for one more cell
   assign is_needs_load;   = ~ls_empty & is_empty;             //transfer from lower stack required
   assign is_needs_unload  =  is_full;                         //transfer to lower stack required 
   assign is_push          =  us_is_psh_i;                     //push request
   assign is_pull          =  us_is_pul_i;                     //pull request 

   //Cell tag transitions
   assign is_ctags_next = (is_push   ? {is_ctags_reg[IS_DEPTH-2:0]}, us_is_psh_ctag_i} : {IS_DEPTH{1'b0}}}) |
			  (is_pull   ? {2'b00, is_ctags_reg[IS_DEPTH-2:1]}             : {IS_DEPTH{1'b0}}}) |
                          (is_load   ? {{IS_DEPTH-1{1'b0}}, 1'b1}                      : {IS_DEPTH{1'b0}}}) |
                          (is_unload ? {1'b0, {IS_DEPTH-1{1'b1}}}                      : {IS_DEPTH{1'b0}}});
   
   //Cell transitions
   assign is_cells_next = (is_push   ? 
			     {is_cells_reg[(CELL_WIDTH*(IS_DEPTHTH-1))-1:0], us_is_psh_cell_i} : 
			     {CELL_WIDTH*IS_DEPTH{1'b0}})                                                  |
			  (is_pull   ? 
			    {{2*CELL_WIDTH{1'b0}}, is_cells_reg[(CELL_WIDTH*(IS_DEPTH-1))-1:CELL_WIDTH]} : 
			    {CELL_WIDTH*IS_DEPTH{1'b0}})                                                   |
                          (is_load   ? 
			     {{CELL_WTDTH*(IS_DEPTH-1){1'b0}}, is_sarb_dat_i} : 
			     {CELL_WIDTH*IS_DEPTH{1'b0}})                                                  |
                          (is_unload ? 
			     {{CELL_WIDTH{1'b0}}, is_cells_reg[(CELL_WIDTH*(IS_DEPTH-1))-1:0]} : 
			  {CELL_WIDTH*IS_DEPTH{1'b0}});
   
   //Flip-flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                            //asynchronous reset
       begin
          is_ctags_reg <= {IS_DEPTH{1'b0}};
          is_cells_reg <= {CELL_WIDTH*IS_DEPTH{1'b0}};
     end  
     else if (sync_rst_i)                                        //synchronous reset
       begin
          is_ctags_reg <= {IS_DEPTH{1'b0}};
          is_sells_reg <= {CELL_WIDTH*IS_DEPTH{1'b0}};
       end
     else if (is_push | is_pull | is_load | is_unload | is_reset)//stack operation
       begin
          is_ctags_reg <= is_ctags_next;
          is_cellsreg  <= is_cells_next;
       end
  
   //Lower stack
   //-----------
   assign is_sarb_adr_o = is_hm_sp_i;                                                 //address bus
   assign is_sarb_dat_o = is_cells[(CELL_WIDTH*IS_DEPTH)-1:CELL_WIDTH*(IS_DEPTH-1)]; //write data bus
     
   //Finite state machine
   //--------------------
   localparam STATE_READY      = 2'b00;                        //awaiting bus request (reset state)
   localparam STATE_LOAD       = 2'b01;                        //awaiting bus acknowledge
   localparam STATE_UNLOAD     = 2'b10;                        //awaiting bus acknowledge
   localparam STATE_INVALID    = 2'b11;                        //unreachable state
   always @*
     begin
        //Default outputs
        state_next    = state_reg;                             //remain in current state 
        is_sarb_cyc_o = 1'b0;                                  //no bus request
        is_sarb_stb_o = 1'b0;                                  //no bus request     
        is_sarb_we_o  = 1'b0;                                  //read       
        is_hm_psh_o   = 1'b0;                                  //don't push to lower stack
        is_hm_pul_o   = 1'b0;                                  //don't pull from lower stack
        is_hm_rst_o   = 1'b0;                                  //don't reset lower stack
        is_load       = 1'b0;                                  //don't load from lower stack
        is_unload     = 1'b0;                                  //don't unload to lower stack 
        is_reset      = 1'b0;                                  //don't reset intermediate stack 
        us_is_busy_o  = is_needs_load | is_needs_unload;       //busy if imediate stack need action

        case (state_reg)
	  STATE_RESET:
	    begin
               state_next    = STATE_READY;                    //remain in current state 
               is_hm_rst_o   = 1'b1;                           //reset lower stack
               is_reset      = 1'b1;                           //reset intermediate stack 
               us_is_busy_o  = 1'b1;                           //busy signal
	    end // case: STATE_RESET
	  
          STATE_READY:                                           //no ongoing bus cycle
            begin
	       TBD











               //Check if IS loading is required
               if ((is_empty & ls_filled) &                      //loading required immediately
                   (is_almost_empty & is_pull_i & ls_filled))    //loading required after pull
                 begin
                    state_next  = lsbus_stall_i ? state_reg :    //stall
                                                  STATE_LOAD;    //load operation
                    lsbus_cyc_o = 1'b1;                          //request bus cycle
                    lsbus_stb_o = 1'b1;                          //
                    if (is_empty)                                //IS is empty
                      begin
                         is_busy     = 1'b1;                     //set busy flag
                         is_push     = 1'b0;                     //disable push operation
                         is_pull     = 1'b0;                     //disable pull operation
                         is_reset    = 1'b0;                     //disable reset operation
                         ls_sp_reset = 1'b0;                     //disable SP reset
                      end
                 end // if ((is_empty & ls_filled) &...

               //Check if IS unloading is required
               if ( is_full &                                    //unloading required immediately
                   (is_almost_full & is_push_i))                 //unloading required after pull
                 begin
                    state_next  = lsbus_stall_i ? state_reg :    //stall
                                                  STATE_UNLOAD;  //load operation
                    lsbus_cyc_o = 1'b1;                          //request bus cycle
                    lsbus_stb_o = 1'b1;                          //
                    lsbus_we_o = 1'b1;                           //write access
                    if (is_full)                                 //IS is full
                      begin
                         is_busy     = 1'b1;                     //set busy flag
                         is_push     = 1'b0;                     //disable push operation
                         is_pull     = 1'b0;                     //disable pull operation
                         is_reset    = 1'b0;                     //disable reset operation
                         ls_sp_reset = 1'b0;                     //disable SP reset
                      end
                 end // if ( is_full &...

               //Check for underflow
               if (is_empty & is_pull_i& ~ls_filled )            //pull from empty stack
                 begin
                    excpt_is_uf_o    = 1'b0;                     //underflow exception
                 end
            end // case: STATE_READY

          STATE_LOAD:
            begin
               is_busy     = 1'b1;                               //set busy signal
               is_push     = 1'b0;                               //disable push operation
               is_pull     = 1'b0;                               //disable pull operation
               is_reset    = 1'b0;                               //disable reset operation
               ls_sp_reset = 1'b0;                               //disable SP reset
               if (lsbus_rty_i)                                  //retry request
                 begin
                    state_next    = STATE_READY;                 //retry bus access
                 end
               if (lsbus_err_i)                                  //bus error
                 begin
                    excpt_lsbus_o = 1'b1;                        //trigger exception
                    state_next    = STATE_READY;                 //retry bus access
                 end
               if (lsbus_ack_i)                                  //bus acknowledge
                 begin
                    is_load       = 1'b1;                        //load IS
                    ls_sp_pull    = 1'b1;                        //update PS
                    state_next    = STATE_READY;                 //ready for next operation
                 end
            end // case: STATE_LOAD

          STATE_UNLOAD:
            begin
               is_busy     = 1'b1;                               //set busy signal
               is_push     = 1'b0;                               //disable push operation
               is_pull     = 1'b0;                               //disable pull operation
               is_reset    = 1'b0;                               //disable reset operation
               ls_sp_reset = 1'b0;                               //disable SP reset
               if (lsbus_rty_i)                                  //retry request
                 begin
                    state_next    = STATE_READY;                 //retry bus access
                 end
               if (lsbus_err_i)                                  //bus error
                 begin
                    excpt_lsbus_o = 1'b1;                        //trigger exception
                    state_next    = STATE_READY;                 //retry bus access
                 end
               if (lsbus_ack_i)                                  //bus acknowledge
                 begin
                    is_unload     = 1'b1;                        //load IS
                    ls_sp_push    = 1'b1;                        //update PS
                    state_next     = STATE_READY;                //ready for next operation
                 end
            end // case: STATE_LOAD

          STATE_INVALID:  //unreachable
            begin
               state_next    = STATE_READY;                      //retry bus access
            end

        endcase // case (state_reg)
     end // always @ *

   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                            //asynchronous reset
       state_reg <= STATE_IDLE;
     else if (sync_rst_i)                                        //synchronous reset
       state_reg <= STATE_IDLE;
     else
       state_reg <= state_next;                                  //state transition

   //Probe signals
   assign prb_is_ctags_o = ctags_reg;                            //intermediate stack cell tags
   assign prb_is_cells_o = cells_reg;                            //intermediate stack cells
   assign prb_is_sp_o    = is_hm_sp_i;                           //stack pointer
   assign prb_is_state_o = state_reg;                            //FSM state

endmodule // N1_is
