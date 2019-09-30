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
//#    The inntermediate stack is able to perform four operations:              #
//#                                                                             #
//#    PUSH:                                                                    #
//#     - Shift all IS cells one position towards the bottom                    #
//#     - Store the input of the US onto the top of the IS                      #
//#     - If the bottommost cell of the IS is now occupied, push it's content   #
//#       to the LS and propagate all overflow errors to the US                 #
//#     - Flag the bottommost cell of the IS as empty                           #
//#                                                                             #
//#     PULL:                                                                   #
//#      - If the IS is empty, return a failure, otherwise return the content   #
//#        of the topmost cell.                                                 #
//#      - Shift  all IS cells one position towards the top                     #
//#      - If the IS is now empty, but the LS is not, pull one cell from the LS #
//#        and store it at the top of the IS.                                   #
//#                                                                             #
//#     SET: (write stack pointer)                                              #
//#                                                                             #
//#                                                                             #
//#                                                                             #
//#     SET: (read stack pointer)                                               #
//#                                                                             #
//#                                                                             #
//#                                                                             #
//#                                                                             #
//#                                                                             #
//#                                                                             #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 24, 2019                                                        #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_is
  #(parameter IS_DEPTH = 8)                                                         //depth of the intermediate stack

   (//Clock and reset
    input  wire                              clk_i,                                 //module clock
    input  wire                              async_rst_i,                           //asynchronous reset
    input  wire                              sync_rst_i,                            //synchronous reset

    //Stack bus (wishbone)
    input  wire [15:0]                       sbus_dat_i,                            //read data bus

    //Internal signals
    //----------------
    //DSP interface
    input  wire [SP_WIDTH-1:0]               dsp2is_sp_i,                           //stack pointer (AGU output)

    //LS interface
    //+-----------------------------------------+-------------------------------+-----------------------------+
    //| Requests (mutually exclusive)           | Response on success           | Response on failure         |
    //+--------------------+--------------------+----------------+--------------+----------------+------------+
    //| Type               | Input data         | Signals        | Output data  | Signals        | Cause      |
    //+--------------------+--------------------+----------------+--------------+----------------+------------+
    //| Push to LS         | cell data          | One or more    | none         | One or more    | LS         |
    //| (is2ls_push_req_o) | (is2ls_req_data_o) | cycles after   |              | cycles after   | overflow   |
    //+--------------------+--------------------+ the request:   +--------------+ the request:   +------------+
    //| Pull from LS       | none               |                | cell data    |  ls2is_ack_i & | LS         |
    //| (is2ls_pull_req_o) |                    |  ls2is_ack_i & | (sbus_dat_i) |  ls2is_fail_i  | underflow  |
    //+--------------------+--------------------+ ~ls2is_fail_i  +--------------+----------------+------------+
    //| Overwrite SP       | new SP             |                | none         | Every request is successful |
    //| (is2ls_wrsp_req_o) | (is2ls_req_data_o) |                |              |                             |
    //+--------------------+--------------------+----------------+--------------+-----------------------------+
    output  wire                             is2ls_ls_push_req_o,                   //push request from IS to LS
    output  wire                             is2ls_ls_pull_req_o,                   //pull request from IS to LS
    output  wire                             is2ls_wrsp_req_o,                      //pull request from IS to LS
    output  wire [15:0]                      is2ls_req_data_o,                      //push data or new SP value
    input wire                               ls2is_ack_i,                           //acknowledge of push or pull request
    input wire                               ls2is_fail_i,                          //LS over or underflow
 
    //US interface
    //+-----------------------------------------+-------------------------------------+----------------------------+
    //| Requests (mutually exclusive)           | Response on success                 | Response on failure        |
    //+--------------------+--------------------+----------------+--------------------+----------------+-----------+
    //| Type               | Input data         | Signals        | Output data        | Signals        | Cause     |
    //+--------------------+--------------------+----------------+--------------------+----------------+-----------+
    //| Push to IS         | cell data          | One or more    | none               | One or more    | LS        |
    //| (us2is_push_req_i) | (us2is_req_data_i) |  cycles after  |                    | cycles after   | overflow  |
    //+--------------------+--------------------+   the request: +--------------------+ the request:   +-----------+
    //| Pull from LS       | none               |                | cell data          |                | LS+IS     |
    //| (us2is_pull_req_i) |                    |  is2us_ack_i & | (is2us_ack_data_o) |  is2us_ack_i & | underflow |
    //+--------------------+--------------------+ ~ls2us_fail_i  +--------------------+  is2us_fail_i  +-----------+
    //| Overwrite SP       | new SP             |                | none               |                | LS        |
    //| (us2is_wrsp_req_i) | (us2is_req_data_i) |                |                    |                | overflow  |
    //+--------------------+--------------------+                +--------------------+                +-----------+
    //| Read SP            | none               |                | SP                 |                | LS        |
    //| (us2is_rdsp_req_i) |                    |                | (is2us_ack_data_o) |                | overflow  |
    //+--------------------+--------------------+----------------+--------------------+----------------+-----------+
    output wire                             is2us_ack_o,                            //acknowledge IS request
    output wire                             is2us_fail_o,                           //IS over or underflow
    output wire [15:0]                      is2us_ack_data_o,                       //requested data
    input  wire                             us2is_push_req_i,                       //push request
    input  wire                             us2is_pull_req_i,                       //pull request
    input  wire                             us2is_set_req_i,                        //stack pointer write request
    input  wire                             us2is_get_req_i,                        //stack pointer read request     

    //Probe signals
    output wire                             prb_o);
    
   //Internal signals
   //-----------------
   //Intermediate stack
   reg  [(16*IS_DEPTH)-1:0] 		    is_reg;                                 //current IS
   wire [(16*IS_DEPTH)-1:0] 		    is_next;                                //next IS
   reg  [IS_DEPTH-1:0] 			    is_tags_reg;                            //current IS
   wire [IS_DEPTH-1:0] 		            is_tags_next;                           //next IS





   //Intermediate parameter stack
   //----------------------------
















   //Flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                               //asynchronous reset
       begin
          is_reg      <= {IS_DEPTH{16'h0000}};                                      //cells
          is_tags_reg <= {IS_DEPTH{1'b0}};                                          //tags
       end
     else if (sync_rst_i)                                                           //synchronous reset
       begin
          is_reg      <= {IS_DEPTH{16'h0000}};                                      //cells
          is_tags_reg <= {IS_DEPTH{1'b0}};                                          //tags
       end
     else if (is_we)
       begin
          is_reg      <= is_next;                                                   //cells
          is_tags_reg <= is_tags_next;                                              //tags
      end






   




   //FSM
   reg  [2:0]                                state_task_reg;                        //current FSM task
   reg  [2:0]                                state_task_next;                       //next FSM task
   //Intermediate parameter stack
   reg  [(16*IPS_DEPTH)-1:0]                 ips_reg;                               //current IPS
   wire [(16*IPS_DEPTH)-1:0]                 ips_next;                              //next IPS
   reg  [IPS_DEPTH-1:0]                      ips_tags_reg;                          //current IPS
   wire [IPS_DEPTH-1:0]                      ips_tags_next;                         //next IPS
   wire                                      ips_we;                                //write enable
   wire                                      ips_empty;                             //PS4 contains no data
   wire                                      ips_almost_empty;                      //PS5 contains no data
   wire                                      ips_full;                              //PSn contains data
   wire                                      ips_almost_full;                       //PSn-1 contains data
   //Intermediate return stack
   reg  [(16*IRS_DEPTH)-1:0]                 irs_reg;                               //current IRS
   wire [(16*IRS_DEPTH)-1:0]                 irs_next;                              //next IRS
   reg  [IRS_DEPTH-1:0]                      irs_tags_reg;                          //current IRS
   wire [IRS_DEPTH-1:0]                      irs_tags_next;                         //next IRS
   wire                                      irs_we;                                //write enable
   wire                                      irs_empty;                             //PS1 contains no data
   wire                                      irs_almost_empty;                      //PS2 contains no data
   wire                                      irs_full;                              //PSn contains data
   wire                                      irs_almost_full;                       //PSn-1 contains data
   //Lower parameter stack
   wire                                      lps_empty;                             //PSP is zero
   //Lower return stack
   wire                                      lrs_empty;                             //RSP is zero


    
   //Intermediate parameter stack
   //----------------------------
   assign ips_next      = (fsm_ps_shift_down ?                                      //shift down
                           {ips_reg[(16*IPS_DEPTH)-17:0], 16'h0000}             :   //PSn   -> PSn+1
                           {IPS_DEPTH{16'h0000}})                               |   //
                          (fsm_ps_shift_up ?                                        //shift up
                           {16'h0000, ips_reg[(16*IPS_DEPTH)-1:16]}             :   //PSn+1 -> PSn
                           {IPS_DEPTH{16'h0000}})                               |   //
                          (fsm_dat2ps4 ?                                            //fetch read data
                           {{IPS_DEPTH-1{16'h0000}}, sbus_dat_i}                :   //DAT -> PS4
                           {IPS_DEPTH{16'h0000}})                               |   //
                          (fsm_psp2ps4 ?                                            //fetch PSP
                           {{IPS_DEPTH-1{16'h0000}},                                //DAT -> PS4
                            {16-SP_WIDTH{1'b0}}, dsp2is_psp_i}                 :   //
                           {IPS_DEPTH{16'h0000}})                               |   //
                          (fsm_ips_clr_bottom ?                                     //clear IPS bottom cell
                           ips_reg                                              :   //
                           {IPS_DEPTH{16'h0000}})                               |   //
                          ({16*IPS_DEPTH{fsm_idle}} &                               //
                           (ir2is_ips_tp_i[1] ?                                    //shift down
                            {ips_reg[(16*IPS_DEPTH)-17:0], 16'h0000}            :   //PSn   -> PSn+1
                            {IPS_DEPTH{16'h0000}})                              |   //
                           (ir2is_ips_tp_i[0] ?                                    //shift up
                            {16'h0000, ips_reg[(16*IPS_DEPTH)-1:16]}            :   //PSn+1 -> PSn
                            {IPS_DEPTH{16'h0000}}));                                //
   assign ips_tags_next = (fsm_ps_shift_down ?                                      //shift down
                           {ips_tags_reg[IPS_DEPTH-2:0], 1'b0}                  :   //PSn   -> PSn+1
                           {IPS_DEPTH{1'b0}})                                   |   //
                          (fsm_ps_shift_up  ?                                       //shift up
                           {1'b0, ips_tags_reg[IPS_DEPTH-1:1]}                  :   //PSn+1 -> PSn
                           {IPS_DEPTH{1'b0}})                                   |   //
                          (fsm_dat2ps4 ?                                            //fetch read data
                           {{IPS_DEPTH-1{1'b0}}, 1'b1}                          :   //DAT -> PS4
                           {IPS_DEPTH{1'b0}})                                   |   //
                          (fsm_psp2ps4 ?                                            //get PSP
                           {{IPS_DEPTH-1{1'b0}}, 1'b1}                          :   //DAT -> PS4
                           {IPS_DEPTH{1'b0}})                                   |   //
                          (fsm_ips_clr_bottom ?                                     //clear IPS bottom cell
                           {{1'b0},ips_tags_reg[IPS_DEPTH-2:0]}                 :   //
                           {IPS_DEPTH{1'b0}})                                   |   //
                          ({IPS_DEPTH{fsm_idle}} &                                  //
                           (ir2is_ips_tp_i[1] ?                                    //shift down
                            {ips_tags_reg[IPS_DEPTH-2:0], 1'b0}                 :   //PSn   -> PSn+1
                            {IPS_DEPTH{1'b0}})                                  |   //
                           (ir2is_ips_tp_i[0] ?                                    //shift up
                            {1'b0, ips_tags_reg[IPS_DEPTH-1:1]}                 :   //PSn+1 -> PSn
                            {IPS_DEPTH{1'b0}}));                                    //

   assign ips_we        = fsm_ps_shift_down                                     |   //shift down
                          fsm_ps_shift_up                                       |   //shift up
                          fsm_dat2ps4                                           |   //fetch read data
                          fsm_psp2ps4                                           |   //get PSP
                          fsm_ips_clr_bottom                                    |   //clear IPS bottom cell
                          (fsm_idle &                                               //
                           (ir2is_ps_rst_i                                     |   //reset PS
                            ir2is_ips_tp_i[1]                                  |   //shift down
                            ir2is_ips_tp_i[0]));                                   //shift up

   //Flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                               //asynchronous reset
       begin
          ips_reg      <= {IPS_DEPTH{16'h0000}};                                    //cells
          ips_tags_reg <= {IPS_DEPTH{1'b1}};                                        //tags
       end
     else if (sync_rst_i)                                                           //synchronous reset
       begin
          ips_reg      <= {IPS_DEPTH{16'h0000}};                                    //cells
          ips_tags_reg <= {IPS_DEPTH{1'b1}};                                        //tags
       end
     else if (ips_we)
       begin
          ips_reg      <= ips_next;                                                 //cells
          ips_tags_reg <= ips_tags_next;                                            //tags
      end

   //Shortcuts
   assign ips_empty        = ~ips_tags_reg[0];                                      //PS4 contains no data
   assign ips_almost_empty = ~ips_tags_reg[1];                                      //PS5 contains no data
   assign ips_full         =  ips_tags_reg[IPS_DEPTH-1];                            //PSn contains data
   assign ips_almost_full  =  ips_tags_reg[IPS_DEPTH-2];                            //PSn-1 contains data

   //Intermediate return stack
   //-------------------------
   assign irs_next      = (fsm_rs_shift_down ?                                      //shift down
                           {irs_reg[(16*IRS_DEPTH)-17:0], 16'h0000}             :   //RSn   -> RSn+1
                           {IRS_DEPTH{16'h0000}})                               |   //
                          (fsm_rs_shift_up  ?                                       //shift up
                           {16'h0000, irs_reg[(16*IRS_DEPTH)-1:16]}             :   //RSn+1 -> RSn
                           {IRS_DEPTH{16'h0000}})                               |   //
                          (fsm_dat2rs1 ?                                            //fetch read data
                           {{IRS_DEPTH-1{16'h0000}}, sbus_dat_i}                :   //DAT -> RS4
                           {IRS_DEPTH{16'h0000}})                               |   //
                          (fsm_rsp2rs1 ?                                            //get RSP
                           {{IRS_DEPTH-1{16'h0000}},                                //DAT -> RS4
                            {16-SP_WIDTH{1'b0}}, dsp2is_rsp_i}                 :   //
                           {IRS_DEPTH{16'h0000}})                               |   //
                          (fsm_irs_clr_bottom ?                                     //clear IRS bottom cell
                           ips_reg                                              :   //
                           {IPS_DEPTH{16'h0000}})                               |   //
                          ({16*IRS_DEPTH{fsm_idle}} &                               //
                           (ir2is_irs_tp_i[1] ?                                    //shift down
                            {irs_reg[(16*IRS_DEPTH)-17:0], 16'h0000}            :   //RSn   -> RSn+1
                            {IRS_DEPTH{16'h0000}})                              |   //
                           (ir2is_irs_tp_i[0] ?                                    //shift up
                            {16'h0000, irs_reg[(16*IRS_DEPTH)-1:16]}            :   //RSn+1 -> RSn
                            {IRS_DEPTH{16'h0000}}));                                //
   assign irs_tags_next = (fsm_rs_shift_down ?                                      //shift down
                           {irs_tags_reg[IRS_DEPTH-2:0], 1'b0}                  :   //RSn   -> RSn+1
                           {IRS_DEPTH{1'b0}})                                   |   //
                          (fsm_rs_shift_up  ?                                       //shift up
                           {1'b0, irs_tags_reg[IRS_DEPTH-1:1]}                  :   //RSn+1 -> RSn
                           {IRS_DEPTH{1'b0}})                                   |   //
                          (fsm_dat2rs1 ?                                            //fetch read data
                           {{IRS_DEPTH-1{1'b0}}, 1'b1}                          :   //DAT -> RS4
                           {IRS_DEPTH{1'b0}})                                   |   //
                          (fsm_rsp2rs1 ?                                            //get RSP
                           {{IRS_DEPTH-1{1'b0}}, 1'b1}                          :   //DAT -> RS4
                           {IRS_DEPTH{1'b0}})                                   |   //
                          (fsm_irs_clr_bottom ?                                     //clear IPR bottom cell
                           {{1'b0},irs_tags_reg[IRS_DEPTH-2:0]}                 :   //
                           {IRS_DEPTH{1'b0}})                                   |   //
                          ({IRS_DEPTH{fsm_idle}} &                                  //
                           (ir2is_irs_tp_i[1] ?                                    //shift down
                            {irs_tags_reg[IRS_DEPTH-2:0], 1'b0}                 :   //RSn   -> RSn+1
                            {IRS_DEPTH{1'b0}})                                  |   //
                           (ir2is_irs_tp_i[0] ?                                    //shift up
                            {1'b0, irs_tags_reg[IRS_DEPTH-1:1]}                 :   //RSn+1 -> RSn
                            {IRS_DEPTH{1'b0}}));                                    //
   assign irs_we        = fsm_rs_shift_down                                     |   //shift down
                          fsm_rs_shift_up                                       |   //shift up
                          fsm_dat2rs1                                           |   //fetch read data
                          fsm_rsp2rs1                                           |   //fetch read RSP
                          fsm_irs_clr_bottom                                    |   //clear IRS bottom cell
                          (fsm_idle &                                               //
                           (ir2is_rs_rst_i                                     |   //reset RS
                            ir2is_irs_tp_i[1]                                  |   //shift out
                            ir2is_irs_tp_i[0]));                                   //shift in

   //Flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                               //asynchronous reset
       begin
          irs_reg      <= {IRS_DEPTH{16'h0000}};                                    //cells
          irs_tags_reg <= {IRS_DEPTH{1'b1}};                                        //tags
       end
     else if (sync_rst_i)                                                           //synchronous reset
       begin
          irs_reg      <= {IRS_DEPTH{16'h0000}};                                    //cells
          irs_tags_reg <= {IRS_DEPTH{1'b1}};                                        //tags
       end
     else if (irs_we)
       begin
          irs_reg      <= irs_next;                                                 //cells
          irs_tags_reg <= irs_tags_next;                                            //tags
      end

   //Shortcuts
   assign irs_empty        = ~irs_tags_reg[0];                                      //PS1 contains no data
   assign irs_almost_empty = ~irs_tags_reg[1];                                      //PS2 contains no data
   assign irs_full         =  irs_tags_reg[IRS_DEPTH-1];                            //PSn contains data
   assign irs_almost_full  =  irs_tags_reg[IRS_DEPTH-2];                            //PSn-1 contains data

   //Lower parameter stack
   //---------------------
   assign lps_empty        = ~|dsp2is_psp_i;                                       //PSP is zero

   //Lower return stack
   //------------------
   assign lrs_empty        = ~|dsp2is_rsp_i;                                       //RSP is zero

   //Finite state machine
   //--------------------
   //State encoding (current task)
   localparam STATE_TASK_READY            = 3'b000;                                 //ready fo new task
   localparam STATE_TASK_MANAGE_LS        = 3'b001;                                 //manage lower stack
   localparam STATE_TASK_PS_FILL          = 3'b010;                                 //empty the US and the IS to set a new PS
   localparam STATE_TASK_RS_FILL          = 3'b011;                                 //empty the US and the IS to set a new PS
   localparam STATE_TASK_PS_EMPTY_GET_SP  = 3'b101;                                 //empty the US and the IS to set a new PS
   localparam STATE_TASK_PS_EMPTY_SET_SP  = 3'b100;                                 //empty the US and the IS to set a new PS
   localparam STATE_TASK_RS_EMPTY_GET_SP  = 3'b111;                                 //empty the US and the IS to set a new PS
   localparam STATE_TASK_RS_EMPTY_SET_SP  = 3'b110;                                 //empty the US and the IS to set a new PS
   //State encoding (stack bus)
   localparam STATE_SBUS_IDLE             = 2'b00;                                  //sbus is idle
   localparam STATE_SBUS_WRITE            = 2'b01;                                  //ongoing write access
   localparam STATE_SBUS_READ_PS          = 2'b10;                                  //read data pending for the IPS
   localparam STATE_SBUS_READ_RS          = 2'b11;                                  //read data pending for the IRS

   //Stack bus
   assign sbus_cyc_o         = sbus_stb_o | |(state_sbus_reg ^ STATE_SBUS_IDLE);    //bus cycle indicator
   assign sbus_dat_o            = is2sagu_stack_sel_o ?                            //1:RS, 0:PS
                                  irs_reg[(16*IRS_DEPTH)-1:16*(IRS_DEPTH-1)] :      //unload RS
                                  ips_reg[(16*IPS_DEPTH)-1:16*(IPS_DEPTH-1)];       //unload PS
   assign fsm_dat2ps4        = ~|(state_sbus_reg ^ STATE_SBUS_READ_PS) |            //in STATE_SBUS_READ_PS
                               sbus_ack_i;                                          //bus request acknowledged
   assign fsm_dat2rs1        = ~|(state_sbus_reg ^ STATE_SBUS_READ_RS) |            //in STATE_SBUS_READ_RS
                               sbus_ack_i;                                          //bus request acknowledged

   //SAGU control
   //assign is2sagu_psp_rst_o = fsm_idle & ~fc2is_hold_i & ir2is_ps_rst_i;       //reset PSP
   //assign is2sagu_rsp_rst_o = fsm_idle & ~fc2is_hold_i & ir2is_rs_rst_i;       //reset RSP
   assign is2sagu_psp_rst_o = fsm_idle & ir2is_ps_rst_i;                          //reset PSP
   assign is2sagu_rsp_rst_o = fsm_idle & ir2is_rs_rst_i;                          //reset RSP

   //State transitions
   always @*
     begin
        //Default outputs
        fsm_idle                = 1'b0;                                             //FSM is not idle
        fsm_ps_shift_up         = 1'b0;                                             //shift PS upwards   (IPS -> UPS)
        fsm_ps_shift_down       = 1'b0;                                             //shift PS downwards (UPS -> IPS)
        fsm_rs_shift_up         = 1'b0;                                             //shift RS upwards   (IRS -> URS)
        fsm_rs_shift_down       = 1'b0;                                             //shift RS downwards (IRS -> URS)
        fsm_psp2ps4             = 1'b0;                                             //capture PSP
        fsm_ips_clr_bottom      = 1'b0;                                             //clear IPS bottom cell
        fsm_rsp2rs1             = 1'b0;                                             //capture RSP
        fsm_irs_clr_bottom      = 1'b0;                                             //clear IRS bottom cell
        sbus_stb_o              = 1'b0;                                             //access request
        sbus_we_o               = 1'b0;                                             //write enable
        is2fc_hold_o           = 1'b1;                                             //stacks not ready
        is2sagu_hold_o         = 1'b1;                                             //maintain stack pointers
        is2sagu_stack_sel_o    = 1'b0;                                             //1:RS, 0:PS
        is2sagu_push_o         = 1'b0;                                             //increment stack pointer
        is2sagu_pull_o         = 1'b0;                                             //decrement stack pointer
        is2sagu_load_o         = 1'b0;                                             //load stack pointer
        state_task_next         = state_task_reg;                                   //keep processing current task
        state_sbus_next         = state_sbus_reg;                                   //keep stack bus state

        //Exceptions
        is2excpt_psuf_o = (rs0_tag_reg & ~ps0_tag_reg & &ir2is_us_tp_i[1:0])|     //invalid PS0 <-> RS0 swap
                           (              ~ps0_tag_reg &  ir2is_us_tp_i[2]  )|     //invalid shift to PS0
                           (ps0_tag_reg & ~ps1_tag_reg & &ir2is_us_tp_i[3:2])|     //invalid PS1 <-> PS0 swap
                           (ps1_tag_reg & ~ps2_tag_reg & &ir2is_us_tp_i[5:4])|     //invalid PS2 <-> PS1 swap
                           (ps2_tag_reg & ~ps3_tag_reg & &ir2is_us_tp_i[7:6]);     //invalid PS3 <-> PS2 swap
        is2excpt_rsuf_o = (ps0_tag_reg & ~rs0_tag_reg & &ir2is_us_tp_i[1:0])|     //invalid RS0 <-> PS0 swap;
                           (              ~rs0_tag_reg &  ir2is_irs_tp_i[0]  );    //invalid shift to RS0


        //Wait for ongoing SBUS accesses
        if (~|state_sbus_reg | sbus_ack_i)                                          //bus is idle or current access is ended
          begin
             state_sbus_next = STATE_SBUS_IDLE;                                     //idle by default

             case (state_task_reg)

               //Perform stack operations and initiate early loading and unloading
               STATE_TASK_READY:
                 begin
                    //Idle indicator
                    fsm_idle                  = 1'b1;                               //FSM is idle
                    is2fc_hold_o             = 1'b0;                               //ready to accept new task

                    //Defaults
                    state_task_next           = STATE_TASK_READY;                   //for logic optimization

                    //Detect early load or unload conditions
                    if ((~lrs_empty &
                         irs_almost_empty & ir2is_irs_tp_i[0]) |                   //IRS early load condition
                        (irs_almost_full  & ir2is_irs_tp_i[1]) |                   //IRS early unload condition
                        (~lps_empty &
                         ips_almost_empty & ir2is_ips_tp_i[0]) |                   //IPS early load condition
                        (ips_almost_full  & ir2is_ips_tp_i[1]))                    //IPS early unload condition
                      begin
                         state_task_next = state_task_next |                        //handle lower stack transfers
                                           STATE_TASK_MANAGE_LS;                    //

                         //Initiate early load accesses
                         if ((~lrs_empty &
                              irs_almost_empty & ir2is_irs_tp_i[0]) |              //IRS early load condition
                             (~lps_empty &
                              ips_almost_empty & ir2is_ips_tp_i[0]))               //IPS early load condition
                           begin
                              sbus_stb_o      = 1'b1;                               //request sbus access
                              is2sagu_hold_o =  sbus_stall_i;                      //update stack pointers
                              is2sagu_pull_o = ~sbus_stall_i;                      //decrement stack pointer
                              if (~lrs_empty &
                                  irs_almost_empty & ir2is_irs_tp_i[0])            //IRS early load condition
                                begin
                                   is2sagu_stack_sel_o = 1'b1;                     //select RS immediately
                                   if (~sbus_stall_i)
                                     state_sbus_next    = STATE_SBUS_READ_RS;       //SBUS -> IRS
                                end
                              else
                                begin
                                   if (~sbus_stall_i)
                                     state_sbus_next    = STATE_SBUS_READ_PS;       //SBUS -> IPS
                                end
                           end // if ((irs_almost_empty & ir2is_irs_tp_i[0]) |...\

                      end // if ((irs_almost_empty & ir2is_irs_tp_i[0]) |...

                    //Get PSP
                    if (ir2is_psp_get_i)
                      begin
                         state_task_next = state_task_next |                        //trigger PSP read sequence
                                           STATE_TASK_PS_EMPTY_GET_SP;              //
                      end

                    //Set PSP
                    if (ir2is_psp_set_i)
                      begin
                         state_task_next = state_task_next |                        //trigger PSP write sequence
                                           STATE_TASK_PS_EMPTY_SET_SP;              //
                      end

                    //Get RSP
                    if (ir2is_rsp_get_i)
                      begin
                         state_task_next = state_task_next |                        //trigger PSP read sequence
                                           STATE_TASK_PS_EMPTY_GET_SP;              //
                      end

                    //Set RSP
                    if (ir2is_rsp_set_i)
                      begin
                         state_task_next = state_task_next |                        //trigger PSP write sequence
                                           STATE_TASK_PS_EMPTY_SET_SP;              //
                      end
                 end // case: STATE_TASK_READY

               //Transfer a cell from US to IS
               STATE_TASK_MANAGE_LS:
                 begin

                    //Manage lower return stack
                    if ((~|(state_sbus_reg ^ STATE_SBUS_READ_RS) &                  //IRS load condition
                         ~lrs_empty & irs_empty)                  |                 //
                        irs_full)                                                   //IRS unload condition
                      begin
                         sbus_stb_o                   = 1'b1;                       //request sbus access
                         is2sagu_hold_o              =  sbus_stall_i;              //update stack pointers
                         is2sagu_stack_sel_o         = 1'b1;                       //select RS immediately

                         //Write access
                         if (irs_full)                                              //IRS unload condition
                           begin
                              sbus_we_o               = 1'b1;                       //write enable
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_push_o    = 1'b1;                       //increment stack pointer
                                   fsm_irs_clr_bottom = 1'b1;                       //clear IRS bottom cell
                                   state_sbus_next = STATE_SBUS_WRITE;              //IRS -> SBUS
                                   if ((~|(state_sbus_reg ^ STATE_SBUS_READ_PS) &   //IRS load condition
                                        ~lps_empty & ips_empty)                  |  //
                                       ips_full)                                    //IRS unload condition
                                     state_task_next  = STATE_TASK_MANAGE_LS;       //manage LPS
                                   else
                                     state_task_next  = STATE_TASK_READY;           //ready for next task
                                end // if (~sbus_stall_i)
                           end // if (irs_full)

                         //Read access
                         else
                           begin
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_pull_o    = 1'b1;                       //decrement stack pointer
                                   state_sbus_next    = STATE_SBUS_READ_RS;         //SBUS -> IRS
                                end // else: !if(irs_full)
                           end // else: !if(irs_full)
                      end // if ((~|(state_sbus_reg ^ STATE_SBUS_READ_RS) &...

                    //Manage lower parameter stack
                    else
                    if ((~|(state_sbus_reg ^ STATE_SBUS_READ_PS) &                  //IRS load condition
                         ~lps_empty & ips_empty)                  |                 //
                        ips_full)                                                   //IRS unload condition
                      begin

                         sbus_stb_o                   = 1'b1;                       //request sbus access
                         is2sagu_hold_o              =  sbus_stall_i;              //update stack pointers

                         //Write access
                         if (irs_full)                                              //IRS unload condition
                           begin
                              sbus_we_o               = 1'b1;                       //write enable
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_push_o    = 1'b1;                       //increment stack pointer
                                   fsm_ips_clr_bottom = 1'b1;                       //clear IPS bottom cell
                                   state_sbus_next    = STATE_SBUS_WRITE;           //IRS -> SBUS
                                   state_task_next    = STATE_TASK_READY;           //ready for next task
                                end // if (~sbus_stall_i)
                           end // if (irs_full)

                         //Read access
                         else
                           begin
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_pull_o    = 1'b1;                       //decrement stack pointer
                                   state_sbus_next    = STATE_SBUS_READ_PS;         //SBUS -> IPS
                                end // else: !if(irs_full)
                           end // else: !if(irs_full)
                      end // if ((~|(state_sbus_reg ^ STATE_SBUS_READ_PS) &...

                    //No load or unload required
                    else
                      begin
                         state_task_next              = STATE_TASK_READY;           //ready for the next instruction
                      end
                 end // case: STATE_TASK_MANAGE_LS

               //Empty UPS and IPS to get PSP
               STATE_TASK_PS_EMPTY_GET_SP:
                 begin
                    //Shift content to LPS
                    if (|{ips_tags_reg[IPS_DEPTH-1:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                      begin
                         //Unload IPS
                         if (ips_full)
                           begin
                              sbus_stb_o              = 1'b1;                       //access request
                              sbus_we_o               = 1'b1;                       //write enable
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_hold_o    = 1'b0;                       //update stack pointers
                                   is2sagu_push_o    = 1'b1;                       //increment stack pointer
                                   fsm_ps_shift_down  = 1'b1;                       //shift PS downwards (UPS -> IPS)
                                   state_sbus_next    = STATE_SBUS_WRITE;           //IPS -> SBUS
                                end
                           end
                         //Align IPS
                         else
                           begin
                              fsm_ps_shift_down       = 1'b1;                       //shift PS downwards (UPS -> IPS)
                           end
                      end // if (|{ips_tags_reg[IPS_DEPTH-1:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                    //Copy PSP to PS4
                    else
                      begin
                         fsm_psp2ps4                  = 1'b1;                       //capture PSP
                         state_task_next              = STATE_TASK_PS_FILL;         //refill IPS
                      end // else: !if(|{ips_tags_reg[IPS_DEPTH-1:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                 end // case: STATE_TASK_PS_EMPTY_GET_SP

               //Empty UPS and IPS to set PSP
               STATE_TASK_PS_EMPTY_SET_SP:
                 begin
                    //Shift content to LPS
                    if (|{ips_tags_reg[IPS_DEPTH-2:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                      begin
                         //Unload IPS
                         if (ips_full)
                           begin
                              sbus_stb_o              = 1'b1;                       //access request
                              sbus_we_o               = 1'b1;                       //write enable
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_hold_o    = 1'b0;                       //update stack pointers
                                   is2sagu_push_o    = 1'b1;                       //increment stack pointer
                                   fsm_ps_shift_down  = 1'b1;                       //shift PS downwards (UPS -> IPS)
                                   state_sbus_next    = STATE_SBUS_WRITE;           //IPS -> SBUS
                                end
                           end
                         //Align IPS
                         else
                           begin
                              fsm_ps_shift_down       = 1'b1;                       //shift PS downwards (UPS -> IPS)
                           end
                      end // if (|{ips_tags_reg[IPS_DEPTH-1:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                    //Set PSP
                    else
                      begin
                         if (ips_full)
                           begin
                              fsm_ips_clr_bottom        = 1'b1;                     //clear IPS bottom cell
                              is2sagu_load_o           = 1'b1;                     //load stack pointer
                           end
                         else
                           begin
                              //PS underflow
                              is2excpt_psuf_o = 1'b1;                              //trigger exception
                           end
                         state_task_next               = STATE_TASK_PS_FILL;        //refill IPS
                      end // else: !if(|{ips_tags_reg[IPS_DEPTH-2:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                 end // case: STATE_TASK_PS_EMPTY_SET_SP

               //Empty URS and IRS to get RSP
               STATE_TASK_RS_EMPTY_GET_SP:
                 begin
                    //Shift content to LRS
                    is2sagu_stack_sel_o              = 1'b0;                       //1:RS, 0:PS
                    if (|{irs_tags_reg[IRS_DEPTH-1:0],rs0_reg})
                      begin
                         //Unload IRS
                         if (irs_full)
                           begin
                              sbus_stb_o              = 1'b1;                       //access request
                              sbus_we_o               = 1'b1;                       //write enable
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_hold_o    = 1'b0;                       //update stack pointers
                                   is2sagu_push_o    = 1'b1;                       //increment stack pointer
                                   fsm_rs_shift_down  = 1'b1;                       //shift RS downwards (URS -> IRS)
                                   state_sbus_next    = STATE_SBUS_WRITE;           //IRS -> SBUS
                                end
                           end
                         //Align IRS
                         else
                           begin
                              fsm_rs_shift_down       = 1'b1;                       //shift RS downwards (URS -> IRS)
                           end
                      end // if (|{irs_tags_reg[IRS_DEPTH-1:0],rs0_tag_reg})
                    //Copy RSP to RS4
                    else
                      begin
                         fsm_rsp2rs1                  = 1'b1;                       //capture RSP
                         state_task_next              = STATE_TASK_RS_FILL;         //refill IRS
                      end // else: !if(|{irs_tags_reg[IRS_DEPTH-1:0],rs0_tag_reg})
                 end // case: STATE_TASK_RS_EMPTY_GET_SP

               //Empty URS and IRS to set RSP
               STATE_TASK_RS_EMPTY_SET_SP:
                 begin
                    //Shift content to LRS
                    is2sagu_stack_sel_o              = 1'b0;                        //1:RS, 0:PS
                    if (|{irs_tags_reg[IRS_DEPTH-2:0],rs0_reg})
                      begin
                         //Unload IRS
                         if (irs_full)
                           begin
                              sbus_stb_o              = 1'b1;                       //access request
                              sbus_we_o               = 1'b1;                       //write enable
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_hold_o    = 1'b0;                       //update stack pointers
                                   is2sagu_push_o    = 1'b1;                       //increment stack pointer
                                   fsm_rs_shift_down  = 1'b1;                       //shift RS downwards (URS -> IRS)
                                   state_sbus_next    = STATE_SBUS_WRITE;           //IRS -> SBUS
                                end
                           end
                         //Align IRS
                         else
                           begin
                              fsm_rs_shift_down       = 1'b1;                       //shift RS downwards (URS -> IRS)
                           end
                      end // if (|{irs_tags_reg[IRS_DEPTH-1:0],rs0_tag_reg})
                    //Set RSP
                    else
                      begin
                         if (irs_full)
                           begin
                              fsm_irs_clr_bottom        = 1'b1;                     //clear IRS bottom cell
                              is2sagu_load_o           = 1'b1;                     //load stack pointer
                           end
                         else
                           begin
                              //RS underflow
                              is2excpt_rsuf_o = 1'b1;                              //trigger exception
                           end
                         state_task_next                = STATE_TASK_RS_FILL;       //refill IRS
                      end // else: !if(|{irs_tags_reg[IRS_DEPTH-2:0],rs0_tag_reg})
                 end // case: STATE_TASK_RS_EMPTY_SET_SP

               //Refill PS
               STATE_TASK_PS_FILL:
                 begin
                    //Done
                    if (ps0_tag_reg)
                      begin
                         state_task_next                = STATE_TASK_READY;         //ready for next task
                      end
                    //Shift PS upward
                    else
                      begin
                         //Load IPS
                         if (lps_empty)
                           begin
                              sbus_stb_o                = 1'b1;                     //access request
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_hold_o      = 1'b0;                     //update stack pointers
                                   is2sagu_pull_o      = 1'b1;                     //increment stack pointer
                                   fsm_ps_shift_up      = 1'b1;                     //shift RS downwards (URS -> IRS)
                                   state_sbus_next      = STATE_SBUS_READ_PS;       //SBUS -> IPS
                                end
                           end
                         //Align UPS
                         else
                           begin
                              fsm_ps_shift_up           = 1'b1;                     //shift PS downwards (IPS -> UPS)
                           end // else: !if(lps_empty)
                      end // else: !if(ps0_tag_reg)
                 end // case: STATE_TASK_PS_FILL

               //Refill RS
               STATE_TASK_RS_FILL:
                 begin
                    //Done
                    if (rs0_tag_reg)
                      begin
                         state_task_next                = STATE_TASK_READY;         //ready for next task
                      end
                    //Shift RS upward
                    else
                      begin
                         //Load IRS
                         if (lrs_empty)
                           begin
                              sbus_stb_o                = 1'b1;                     //access request
                              if (~sbus_stall_i)
                                begin
                                   is2sagu_hold_o      = 1'b0;                     //update stack pointers
                                   is2sagu_pull_o      = 1'b1;                     //increment stack pointer
                                   fsm_rs_shift_up      = 1'b1;                     //shift RS downwards (URS -> IRS)
                                   state_sbus_next      = STATE_SBUS_READ_RS;       //SBUS -> IRS
                                end
                           end
                         //Align URS
                         else
                           begin
                              fsm_rs_shift_up           = 1'b1;                     //shift RS downwards (IRS -> URS)
                           end // else: !if(lrs_empty)
                      end // else: !if(rs0_tag_reg)
                 end // case: STATE_TASK_RS_FILL

             endcase // case (state_task_reg)

          end // if (~|state_sbus_reg |sbus_ack_i)
     end // always @ *

   //Flip flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                               //asynchronous reset
       begin
          state_task_reg <= STATE_TASK_READY;                                       //ready fo new task
          state_sbus_reg <= STATE_SBUS_IDLE;                                        //sbus is idle
       end
     else if (sync_rst_i)                                                           //synchronous reset
       begin
          state_task_reg <= STATE_TASK_READY;                                       //ready fo new task
          state_sbus_reg <= STATE_SBUS_IDLE;                                        //sbus is idle
       end
     else                                                                           //state transition
       begin
          state_task_reg <= state_task_next;                                        //state transition
          state_sbus_reg <= state_sbus_next;                                        //state transition
       end


   //Stack data outputs
   //------------------
   assign pbus_dat_o              = ps0_reg;                                        //write data bus
   assign is2alu_ps0_o           = ps0_reg;                                        //current PS0 (TOS)
   assign is2alu_ps1_o           = ps1_reg;                                        //current PS1 (TOS+1)
   assign is2fc_ps0_false_o      = ~|ps0_reg;                                      //PS0 is zero
   assign is2pagu_ps0_o          = ps0_reg;                                        //PS0
   assign is2pagu_rs0_o          = rs0_reg;                                        //RS0
   assign is2sagu_psp_load_val_o =
                           ips_reg[(16*(IPS_DEPTH-1))+SP_WIDTH-1:16*(IPS_DEPTH-1)]; //parameter stack load value
   assign is2sagu_rsp_load_val_o =
                           irs_reg[(16*(IRS_DEPTH-1))+SP_WIDTH-1:16*(IRS_DEPTH-1)]; //return stack load value

   //Probe signals
   //-------------
   assign prb_state_task_o        = state_task_reg;                                 //current FSM task
   assign prb_state_sbus_o        = state_sbus_reg;                                 //current stack bus state
   assign prb_rs0_o               = rs0_reg;                                        //current RS0
   assign prb_ps0_o               = ps0_reg;                                        //current PS0
   assign prb_ps1_o               = ps1_reg;                                        //current PS1
   assign prb_ps2_o               = ps2_reg;                                        //current PS2
   assign prb_ps3_o               = ps3_reg;                                        //current PS3
   assign prb_rs0_tag_o           = rs0_tag_reg;                                    //current RS0 tag
   assign prb_ps0_tag_o           = ps0_tag_reg;                                    //current PS0 tag
   assign prb_ps1_tag_o           = ps1_tag_reg;                                    //current PS1 tag
   assign prb_ps2_tag_o           = ps2_tag_reg;                                    //current PS2 tag
   assign prb_ps3_tag_o           = ps3_tag_reg;                                    //current PS3 tag
   assign prb_ips_o               = ips_reg;                                        //current IPS
   assign prb_ips_tags_o          = ips_tags_reg;                                   //current IPS
   assign prb_irs_o               = irs_reg;                                        //current IRS
   assign prb_irs_tags_o          = irs_tags_reg;                                   //current IRS

endmodule // N1_is
