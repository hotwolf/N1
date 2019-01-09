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
  #(parameter   SP_WIDTH        =  8,                          //width of a stack pointer
    parameter   CELL_WIDTH      = 16,                          //cell width
    parameter   IS_DEPTH        =  8,                          //depth of the intermediate stack
    parameter   LS_GROW_UPWARDS =  0)                          //0=lower stack grows towards lower addresses
                                                               //1=lower stack grows towards higher addresses
   (//Clock and reset
    input  wire                              clk_i,            //module clock
    input  wire                              async_rst_i,      //asynchronous reset
    input  wire                              sync_rst_i,       //synchronous reset

    //Upper stack interface
    input  wire  [CELL_WIDTH-1:0]            us_bos_i,         //data input: US->IS

    //Intermediate stack interface
    output wire [CELL_WIDTH-1:0]            is_tos_o,          //data output: IS->US
    output wire                             is_filled_o,       //immediate stack holds data
    output reg                              is_busy_o,         //RAM controller is busy
    input  wire                             is_push_i,         //push data to TOS
    input  wire                             is_pull_i,         //pull data from TOS
    input  wire                             is_reset_i,        //pull data from TOS

    //Lower stack bus
    output reg                              lsbus_cyc_o,       //bus cycle indicator       +-
    output reg                              lsbus_stb_o,       //access request            | initiator
    output reg                              lsbus_we_o,        //write enable              | to
    output wire [SP_WIDTH-1:0]              lsbus_adr_o,       //address bus               | target
    output wire [CELL_WIDTH-1:0]            lsbus_dat_o,       //write data bus            +-
    input  wire                             lsbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                             lsbus_err_i,       //error indicator           | target
    input  wire                             lsbus_rty_i,       //retry request             | to
    input  wire                             lsbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]            lsbus_dat_i);      //read data bus             +-

    //Exceptions
    output reg                              excpt_lsbus_o,     //bus error
    output reg                              excpt_is_uf_o,     //underflow

    //External address in-/decrementer
    output wire [SP_WIDTH:0]                sagu_sp_o,          //current address
    output wire                             sagu_inc_o,         //increment address
    output wire                             sagu_dec_o,         //decrement address
    input  wire [SP_WIDTH:0]                sagu_res_i,         //result

    //Probe signals
    output wire [(IS_DEPTH*CELL_WIDTH)-1:0] prb_is_o,          //intermediate stack content
    output wire [IS_DEPTH-1:0]              prb_is_stat_o,     //intermediate stack status
    output wire [SP_WIDTH-1:0]              prb_ls_sp_o);      //lower stack pointer

   //Internal Signals
   //----------------
   //Internal regiters
   reg  [(IS_DEPTH*CELL_WIDTH)-1:0]        is_reg;             //intermediate stack content
   reg  [IS_DEPTH-1:0]                     is_stat_reg;        //intermediate stack status
   reg  [(IS_DEPTH*CELL_WIDTH)-1:0]        is_next;            //next intermediate stack content
   reg  [IS_DEPTH-1:0]                     is_stat_next;       //intermediate stack status
   reg                                     is_push;            //push operation
   reg                                     is_pull;            //pull operation
   reg                                     is_load;            //load operation
   reg                                     is_unload;          //unload operation
   reg                                     is_reset;           //reset operation
   reg  [SP_WIDTH-1:0]                     ls_sp_reg;          //lower stack pointer
   wire [SP_WIDTH-1:0]                     ls_sp_next;         //next lower stack pointer
   reg                                     ls_sp_push;         //update SP in push direction
   reg                                     ls_sp_pull;         //update SP in pull direction
   reg                                     ls_sp_reset;        //reset SP
   //FSM
   reg  [1:0]  state_reg;                                      //state variable
   reg  [1:0]  state_next;                                     //next state
   //Shortcuts
   wire        ls_bos          = {SP_WIDTH{~|LS_GROW_UPWARDS}};//bottom of the lower stack
   wire        ls_filled       = |(ls_sp_reg ^ ls_bos);        //LS content indicator
   wire        is_empty        = ~is_stat_reg[0];              //IS content indicator
   wire        is_almost_empty = ~is_stat_reg[1];              //IS content indicator
   wire        is_full         =  is_stat_reg[IS_DEPTH-1];     //IS content indicator
   wire        is_almost_full  =  is_stat_reg[IS_DEPTH-2];     //IS content indicator

   //Counters
   //--------
   integer b, c;                                               //bit position, cell position

   //Probes
   //------
   assign prb_is_o      = is_reg;                              //intermediate stack content
   assign prb_is_stat_o = is_stat_reg;                         //intermediate stack status
   assign prb_ls_sp_o   = ls_sp_reg;                           //lower stack pointer

   //Intermediate stack
   //------------------
   always @*
     for (c=0; c<IS_DEPTH;   c=c+1)
     for (b=0; b<CELL_WIDTH; b=b+1)
       begin
          //Top of the stack
          if (c == 0)
            begin
               is_stat_next[c]              =  is_push                                   |
                                              (is_pull   & is_stat_reg[c+1])             |
                                               is_load
                                               is_unload);
               is_in_next[b+(c*CELL_WIDTH)] = (is_push   & us_bos_i[b])                  |
                                              (is_pull   & is_reg[b+((c+1)*CELL_WIDTH)]) |
                                              (is_load   & lsbus_dat_i[b])               |
            end                               (is_unload & is_reg[b+(c*CELL_WIDTH)]);

          //Bottom of the stack
          else if (c == (IS_DEPTH-1))
            begin
               is_stat_next[c]              =  is_push & is_stat_reg[c-1];
               is_in_next[b+(c*CELL_WIDTH)] =  is_reg[b+((c-1)*CELL_WIDTH)];
            end
          //Middle of the stack
          else
            begin
               is_stat_next[c]              = (is_push   & is_stat_reg[c-1])             |
                                              (is_pull   & is_stat_reg[c+1]))            |
                                              (is_unload & is_stat_reg[c]);
               is_in_next[b+(c*CELL_WIDTH)] = (is_push   & is_reg[b+((c-1)*CELL_WIDTH)]) |
                                              (is_pull   & is_reg[b+((c+1)*CELL_WIDTH)]) |
                                              (is_unload & is_reg[b+(c*CELL_WIDTH)]);
            end
       end // for (b=0; b<CELL_WIDTH; b=b+1)

   //TOS outputs
   assign is_tos_o    = is_reg[CELL_WIDTH-1:0];
   assign is_filled_o = is_stat_reg[0];

   //Registers
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                            //asynchronous reset
       begin
          is_stat_reg <= {IS_DEPTH{1'b0}};
          is_reg      <= {IS_DEPTH*CELL_WIDTH{1'b0}};
       end
     else if (sync_rst_i)                                        //synchronous reset
       begin
          is_stat_reg <= {IS_DEPTH{1'b0}};
          is_reg      <= {IS_DEPTH*CELL_WIDTH{1'b0}};
       end
     else if (is_push | is_pull | is_load | is_unload | is_reset)//stack operation
       begin
          is_stat_reg <= is_stat_next;
          is_reg      <= is_next;
       end

   //Lower stack
   //-----------
   //Lower stack bus
   assign lsbus_adr_o = ls_sp_reg;
   assign lsbus_dat_o = is_reg[(IS_DEPTH-1)*CELL_WIDTH:(IS_DEPTH*CELL_WIDTH)-1];

   //Stack AGU
   assign sagu_sp_o    = ls_sp_reg;                                //current address
   assign sagu_inc_o   = LS_GROW_UPWARDS ? ls_sp_push : ls_sp_pull;//increment address
   assign sagu_dec_o   = LS_GROW_UPWARDS ? ls_sp_pull : ls_sp_push;//decrement address

   //Stack pointer
   assign ls_sp_next  = ({SP_WIDTH{ls_sp_push | ls_sp_pull}} & sagu_res_i) |
                        ({SP_WIDTH{ls_sp_reset}}             & ls_bos);

   //Registers
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                            //asynchronous reset
       ls_sp_reg <= ls_bos;
     else if (sync_rst_i)                                        //synchronous reset
       ls_sp_reg <= ls_bos;
     else if (ls_sp_push | ls_sp_pull | ls_sp_reset)             //stack operation
       ls_sp_reg <= ls_sp_next;

   //Finite state machine
   //--------------------
   localparam STATE_READY      = 2'b00;                          //awaiting bus request (reset state)
   localparam STATE_LOAD       = 2'b01;                          //awaiting bus acknowledge
   localparam STATE_UNLOAD     = 2'b10;                          //awaiting bus acknowledge
   localparam STATE_INVALID    = 2'b11;                          //unreachable state
   always @*
     begin
        //Default outputs
        state_next    = state_reg;                               //remain in current state
        is_busy_o     = 1'b0;                                    //ready
        lsbus_cyc_o   = 1'b0;                                    //bus cycle indicator
        lsbus_stb_o   = 1'b0;                                    //access request
        lsbus_we_o    = 1'b0;                                    //write enable
        is_push       = is_push_i;                               //push operation
        is_pull       = is_pull_i;                               //pull operation
        is_load       = 1'b0;                                    //load operation
        is_unload     = 1'b0;                                    //unload operation
        is_reset      = is_reset_i;                              //reset operation
        ls_sp_push    = 1'b0;                                    //update SP in push direction
        ls_sp_pull    = 1'b0;                                    //update SP in pull direction
        ls_sp_reset   = is_reset_i;                              //reset SP
        excpt_lsbus_o = 1'b0;                                    //bus error
        excpt_is_uf_o = 1'b0;                                    //underflow

        case (state_reg)
          STATE_READY:                                           //no ongoing bus cycle
            begin
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

endmodule // N1_is
