//###############################################################################
//# N1 - Parameter and Return Stack                                             #
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
//#    This module implements all levels of the parameter and the return stack. #
//#    These levels are:                                                        #
//#    - The upper stack, which provides direct access to the most cells and    #
//#      which is capable of performing stack operations.                       #
//#                                                                             #
//#  Imm.  |                  Upper Stack                   |    Upper   | Imm. #
//#  Stack |                                                |    Stack   | St.  #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#      |<->|  PS3  |<=>|  PS2  |<=>|  PS1  |<=>|  PS0  |<===>|  RS0  |<->|    #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#                                                 TOS     |     TOS           #
//#                          Parameter Stack                | Return Stack      #
//#                                                                             #
//#    - The intermediate stack serves as a buffer between the upper and the    #
//#      lower stack. It is designed to handle smaller fluctuations in stack    #
//#      content, minimizing accesses to the lower stack.                       #
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
//#    - The lower stack resides in RAM to to implement a deep stack.           #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 13, 2018                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_prs
  #(parameter   SP_WIDTH        =      12,                                         //width of the stack pointer
    parameter   IPS_DEPTH       =       8,                                         //depth of the intermediate parameter stack
    parameter   IRS_DEPTH       =       8)                                         //depth of the intermediate return stack

   (//Clock and reset
    input wire                               clk_i,                                //module clock
    input wire                               async_rst_i,                          //asynchronous reset
    input wire                               sync_rst_i,                           //synchronous reset

    //Program bus (wishbone)
    output  wire [15:0]                      pbus_dat_o,                           //write data bus
    input  wire [15:0]                       pbus_dat_i,                           //read data bus

    //Stack bus (wishbone)
    output wire                              sbus_cyc_o,                           //bus cycle indicator       +-
    output reg                               sbus_stb_o,                           //access request            | initiator
    output reg                               sbus_we_o,                            //write enable              | to
    output wire [15:0]                       sbus_dat_o,                           //write data bus            | target
    input  wire                              sbus_ack_i,                           //bus cycle acknowledge     +-
    input  wire                              sbus_stall_i,                         //access delay              | initiator to initiator
    input  wire [15:0]                       sbus_dat_i,                           //read data bus             +-

    //Interrupt interface
    input  wire [15:0]                       irq_req_i,                            //requested interrupt vector

    //Internal signals
    //----------------
    //ALU interface
    output wire [15:0]                       prs2alu_ps0_o,                        //current PS0 (TOS)
    output wire [15:0]                       prs2alu_ps1_o,                        //current PS1 (TOS+1)
    input  wire [15:0]                       alu2prs_ps0_next_i,                   //new PS0 (TOS)
    input  wire [15:0]                       alu2prs_ps1_next_i,                   //new PS1 (TOS+1)

     //DSP interface
    input  wire [15:0]                       dsp2prs_pc_i,                         //program counter
    input  wire [SP_WIDTH-1:0]               dsp2prs_psp_i,                        //parameter stack pointer (AGU output)
    input  wire [SP_WIDTH-1:0]               dsp2prs_rsp_i,                        //return stack pointer (AGU output)

    //EXCPT interface
    output reg                               prs2excpt_psuf_o,                     //parameter stack underflow
    output reg                               prs2excpt_rsuf_o,                     //return stack underflow
    input  wire [15:0]                       excpt2prs_tc_i,                       //throw code

    //FC interface
    output reg                               prs2fc_hold_o,                        //stacks not ready
    output wire                              prs2fc_ps0_false_o,                   //PS0 is zero
    input  wire                              fc2prs_hold_i,                        //hold any state tran
    input  wire                              fc2prs_dat2ps0_i,                     //capture read data
    input  wire                              fc2prs_tc2ps0_i,                      //capture throw code
    input  wire                              fc2prs_isr2ps0_i,                     //capture ISR

    //IR interface
    input  wire [15:0]                       ir2prs_lit_val_i,                     //literal value
    input  wire [7:0]                        ir2prs_us_tp_i,                       //upper stack transition pattern
    input  wire [1:0]                        ir2prs_ips_tp_i,                      //10:push, 01:pull
    input  wire [1:0]                        ir2prs_irs_tp_i,                      //10:push, 01:pull
    input  wire                              ir2prs_alu2ps0_i,                     //ALU output  -> PS0
    input  wire                              ir2prs_alu2ps1_i,                     //ALU output  -> PS1
    input  wire                              ir2prs_lit2ps0_i,                     //literal     -> PS0
    input  wire                              ir2prs_pc2rs0_i,                      //PC          -> RS0
    input  wire                              ir2prs_ps_rst_i,                      //reset parameter stack
    input  wire                              ir2prs_rs_rst_i,                      //reset return stack
    input  wire                              ir2prs_psp_get_i,                     //read parameter stack pointer
    input  wire                              ir2prs_psp_set_i,                     //write parameter stack pointer
    input  wire                              ir2prs_rsp_get_i,                     //read return stack pointer
    input  wire                              ir2prs_rsp_set_i,                     //write return stack pointer

    //PAGU interface
    output wire [15:0]                       prs2pagu_ps0_o,                       //PS0
    output wire [15:0]                       prs2pagu_rs0_o,                       //RS0

    //SAGU interface
    output reg                               prs2sagu_hold_o,                      //maintain stack pointers
    output wire                              prs2sagu_psp_rst_o,                   //reset PSP
    output wire                              prs2sagu_rsp_rst_o,                   //reset RSP
    output reg                               prs2sagu_stack_sel_o,                 //1:RS, 0:PS
    output reg                               prs2sagu_push_o,                      //increment stack pointer
    output reg                               prs2sagu_pull_o,                      //decrement stack pointer
    output reg                               prs2sagu_load_o,                      //load stack pointer
    output wire [SP_WIDTH-1:0]               prs2sagu_psp_load_val_o,              //parameter stack load value
    output wire [SP_WIDTH-1:0]               prs2sagu_rsp_load_val_o,              //return stack load value

    //Probe signals
    output wire [2:0]                        prb_state_task_o,                     //current state
    output wire [1:0]                        prb_state_sbus_o,                     //current state
    output wire [15:0]                       prb_rs0_o,                            //current RS0
    output wire [15:0]                       prb_ps0_o,                            //current PS0
    output wire [15:0]                       prb_ps1_o,                            //current PS1
    output wire [15:0]                       prb_ps2_o,                            //current PS2
    output wire [15:0]                       prb_ps3_o,                            //current PS3
    output wire                              prb_rs0_tag_o,                        //current RS0 tag
    output wire                              prb_ps0_tag_o,                        //current PS0 tag
    output wire                              prb_ps1_tag_o,                        //current PS1 tag
    output wire                              prb_ps2_tag_o,                        //current PS2 tag
    output wire                              prb_ps3_tag_o,                        //current PS3 tag
    output wire [(16*IPS_DEPTH)-1:0]         prb_ips_o,                            //current IPS
    output wire [IPS_DEPTH-1:0]              prb_ips_tags_o,                       //current IPS
    output wire [(16*IRS_DEPTH)-1:0]         prb_irs_o,                            //current IRS
    output wire [IRS_DEPTH-1:0]              prb_irs_tags_o);                      //current IRS

   //Internal signals
   //-----------------
   //FSM
   reg  [2:0]                                state_task_reg;                       //current FSM task
   reg  [2:0]                                state_task_next;                      //next FSM task
   reg  [1:0]                                state_sbus_reg;                       //current stack bus state
   reg  [1:0]                                state_sbus_next;                      //next stack bus state

   reg                                       fsm_idle;                             //FSM is in idle
   reg                                       fsm_ps_shift_up;                      //shift PS upwards   (IPS -> UPS)
   reg                                       fsm_ps_shift_down;                    //shift PS downwards (UPS -> IPS)
   reg                                       fsm_rs_shift_up;                      //shift RS upwards   (IRS -> URS)
   reg                                       fsm_rs_shift_down;                    //shift RS downwards (IRS -> URS)
   reg                                       fsm_psp2ps4;                          //capture PSP
   wire                                      fsm_dat2ps4;                          //capture SBUS read data
   reg                                       fsm_ips_clr_bottom;                   //clear IPS bottom cell
   reg                                       fsm_rsp2rs1;                          //capture RSP
   wire                                      fsm_dat2rs1;                          //capture SBUS read data
   reg                                       fsm_irs_clr_bottom;                   //clear IRS bottom cell
   //Upper stack
   reg  [15:0]                               rs0_reg;                              //current RS0
   reg  [15:0]                               ps0_reg;                              //current PS0
   reg  [15:0]                               ps1_reg;                              //current PS1
   reg  [15:0]                               ps2_reg;                              //current PS2
   reg  [15:0]                               ps3_reg;                              //current PS3
   wire [15:0]                               rs0_next;                             //next RS0
   wire [15:0]                               ps0_next;                             //next PS0
   wire [15:0]                               ps1_next;                             //next PS1
   wire [15:0]                               ps2_next;                             //next PS2
   wire [15:0]                               ps3_next;                             //next PS3
   reg                                       rs0_tag_reg;                          //current RS0 tag
   reg                                       ps0_tag_reg;                          //current PS0 tag
   reg                                       ps1_tag_reg;                          //current PS1 tag
   reg                                       ps2_tag_reg;                          //current PS2 tag
   reg                                       ps3_tag_reg;                          //current PS3 tag
   wire                                      rs0_tag_next;                         //next RS0 tag
   wire                                      ps0_tag_next;                         //next PS0 tag
   wire                                      ps1_tag_next;                         //next PS1 tag
   wire                                      ps2_tag_next;                         //next PS2 tag
   wire                                      ps3_tag_next;                         //next PS3 tag
   wire                                      rs0_we;                               //write enable
   wire                                      ps0_we;                               //write enable
   wire                                      ps1_we;                               //write enable
   wire                                      ps2_we;                               //write enable
   wire                                      ps3_we;                               //write enable
   //Intermediate parameter stack
   reg  [(16*IPS_DEPTH)-1:0]                 ips_reg;                              //current IPS
   wire [(16*IPS_DEPTH)-1:0]                 ips_next;                             //next IPS
   reg  [IPS_DEPTH-1:0]                      ips_tags_reg;                         //current IPS
   wire [IPS_DEPTH-1:0]                      ips_tags_next;                        //next IPS
   wire                                      ips_we;                               //write enable
   wire                                      ips_empty;                            //PS4 contains no data
   wire                                      ips_almost_empty;                     //PS5 contains no data
   wire                                      ips_full;                             //PSn contains data
   wire                                      ips_almost_full;                      //PSn-1 contains data
   //Intermediate return stack
   reg  [(16*IRS_DEPTH)-1:0]                 irs_reg;                              //current IRS
   wire [(16*IRS_DEPTH)-1:0]                 irs_next;                             //next IRS
   reg  [IRS_DEPTH-1:0]                      irs_tags_reg;                         //current IRS
   wire [IRS_DEPTH-1:0]                      irs_tags_next;                        //next IRS
   wire                                      irs_we;                               //write enable
   wire                                      irs_empty;                            //PS1 contains no data
   wire                                      irs_almost_empty;                     //PS2 contains no data
   wire                                      irs_full;                             //PSn contains data
   wire                                      irs_almost_full;                      //PSn-1 contains data
   //Lower parameter stack
   wire                                      lps_empty;                            //PSP is zero
   //Lower return stack
   wire                                      lrs_empty;                            //RSP is zero

   //Upper stack
   //-----------
   //RS0
   assign rs0_next     = (fsm_rs_shift_up      ? irs_reg[15:0]      : 16'h0000) |  //RS1 -> RS0
                         ({16{fsm_idle}} &
                          ((ir2prs_us_tp_i[0]  ? ps0_reg            : 16'h0000) |  //PS0 -> RS0
                           (ir2prs_irs_tp_i[0] ? irs_reg[15:0]      : 16'h0000) |  //RS1 -> RS0
                           (ir2prs_pc2rs0_i    ? dsp2prs_pc_i       : 16'h0000))); //PC  -> RS0
   assign rs0_tag_next = (fsm_rs_shift_up      & irs_tags_reg[0])               |  //RS1 -> RS0
                         (fsm_idle             &
                          ((ir2prs_us_tp_i[0]  & ps0_tag_reg)                   |  //PS0 -> RS0
                           (ir2prs_irs_tp_i[0] & irs_tags_reg[0])               |  //RS1 -> RS0
                            ir2prs_pc2rs0_i));                                     //PC  -> RS0
   assign rs0_we       = fsm_rs_shift_down                                      |  //0   -> RS0
                         fsm_rs_shift_up                                        |  //RS1 -> RS0
                         (fsm_idle & ~fc2prs_hold_i &
                          (ir2prs_rs_rst_i                                      |  //reset RS
                           ir2prs_us_tp_i[0]                                    |  //PS0 -> RS0
                           ir2prs_irs_tp_i[0]                                   |  //RS1 -> RS0
                           ir2prs_pc2rs0_i));                                      //PC  -> RS0

   //PS0
   assign ps0_next     = (fsm_ps_shift_up      ? ps1_reg            : 16'h0000) |  //PS1 -> PS0
                         ({16{fsm_idle}} &
                          ((ir2prs_us_tp_i[1]  ? rs0_reg            : 16'h0000) |  //RS0 -> PS0
                           (ir2prs_us_tp_i[2]  ? ps1_reg            : 16'h0000) |  //PS1 -> PS0
                           (ir2prs_alu2ps0_i   ? alu2prs_ps0_next_i : 16'h0000) |  //ALU -> PS0
                           (ir2prs_lit2ps0_i   ? ir2prs_lit_val_i   : 16'h0000) |  //LIT -> PS0
                           (fc2prs_dat2ps0_i   ? pbus_dat_i         : 16'h0000) |  //DAT -> PS0
                           (fc2prs_tc2ps0_i    ? excpt2prs_tc_i     : 16'h0000) |  //TC  -> PS0
                           (fc2prs_isr2ps0_i   ? irq_req_i          : 16'h0000))); //ISR -> PS0
   assign ps0_tag_next = (fsm_ps_shift_up      & ps1_tag_reg)                   |  //PS1 -> PS0
                         (fsm_idle             &
                          ((ir2prs_us_tp_i[1]  & rs0_tag_reg)                   |  //RS0 -> PS0
                           (ir2prs_us_tp_i[2]  & ps1_tag_reg)                   |  //PS1 -> PS0
                            ir2prs_alu2ps0_i                                    |  //ALU -> PS0
                            fc2prs_dat2ps0_i                                    |  //DAT -> PS0
                            ir2prs_lit2ps0_i                                    |  //LIT -> PS0
                            fc2prs_isr2ps0_i));                                    //ISR -> PS0
   assign ps0_we       = fsm_ps_shift_down                                      |  //0   -> PS0
                         fsm_ps_shift_up                                        |  //PS1 -> PS0
                         (fsm_idle & ~fc2prs_hold_i &
                          (ir2prs_ps_rst_i                                      |  //reset PS
                           ir2prs_us_tp_i[1]                                    |  //RS0 -> PS0
                           ir2prs_us_tp_i[2]                                    |  //PS1 -> PS0
                           ir2prs_alu2ps0_i                                     |  //ALU -> PS0
                           fc2prs_dat2ps0_i                                     |  //DAT -> PS0
                           ir2prs_lit2ps0_i                                     |  //LIT -> PS0
                           fc2prs_isr2ps0_i));                                     //ISR -> PS0

   //PS1
   assign ps1_next     = (fsm_ps_shift_down    ? ps0_reg            : 16'h0000) |  //PS0 -> PS1
                         (fsm_ps_shift_up      ? ps2_reg            : 16'h0000) |  //PS2 -> PS1
                         ({16{fsm_idle}} &
                          ((ir2prs_us_tp_i[3]  ? ps0_reg            : 16'h0000) |  //PS0 -> PS1
                           (ir2prs_us_tp_i[4]  ? ps2_reg            : 16'h0000) |  //PS2 -> PS1
                           (ir2prs_alu2ps1_i   ? alu2prs_ps1_next_i : 16'h0000))); //ALU -> PS1
   assign ps1_tag_next = (fsm_ps_shift_down    & ps0_tag_reg)                   |  //PS0 -> PS1
                         (fsm_ps_shift_up      & ps2_tag_reg)                   |  //PS2 -> PS1
                         (fsm_idle             &
                          ((ir2prs_us_tp_i[3]  & ps0_tag_reg)                   |  //PS0 -> PS1
                           (ir2prs_us_tp_i[4]  & ps2_tag_reg)                   |  //PS2 -> PS1
                            ir2prs_alu2ps1_i));                                    //ALU -> PS1
   assign ps1_we       = fsm_ps_shift_down                                      |  //PS0 -> PS1
                         fsm_ps_shift_up                                        |  //PS2 -> PS1
                         (fsm_idle & ~fc2prs_hold_i &
                          (ir2prs_ps_rst_i                                      |  //reset PS
                           ir2prs_us_tp_i[3]                                    |  //PS0 -> PS1
                           ir2prs_us_tp_i[4]                                    |  //PS2 -> PS1
                           ir2prs_alu2ps1_i));                                     //ALU -> PS1

   //PS2
   assign ps2_next     = (fsm_ps_shift_down    ? ps1_reg            : 16'h0000) |  //PS1 -> PS2
                         (fsm_ps_shift_up      ? ps3_reg            : 16'h0000) |  //PS3 -> PS2
                         ({16{fsm_idle}} &
                          ((ir2prs_us_tp_i[5]  ? ps1_reg            : 16'h0000) |  //PS1 -> PS2
                           (ir2prs_us_tp_i[6]  ? ps3_reg            : 16'h0000))); //PS3 -> PS2
   assign ps2_tag_next = (fsm_ps_shift_down    & ps1_tag_reg)                   |  //PS1 -> PS2
                         (fsm_ps_shift_up      & ps3_tag_reg)                   |  //PS3 -> PS2
                         (fsm_idle             &
                          ((ir2prs_us_tp_i[5]  & ps1_tag_reg)                   |  //PS1 -> PS2
                           (ir2prs_us_tp_i[6]  & ps3_tag_reg)));                   //PS3 -> PS2
   assign ps2_we       = fsm_ps_shift_down                                      |  //PS1 -> PS2
                         fsm_ps_shift_up                                        |  //PS3 -> PS2
                         (fsm_idle & ~fc2prs_hold_i &
                          (ir2prs_ps_rst_i                                      |  //reset PS
                           ir2prs_us_tp_i[5]                                    |  //PS1 -> PS2
                           ir2prs_us_tp_i[6]));                                    //PS3 -> PS2

   //PS3
   assign ps3_next     = (fsm_ps_shift_down    ? ps2_reg            : 16'h0000) |  //PS2 -> PS3
                         (fsm_ps_shift_up      ? ips_reg[15:0]      : 16'h0000) |  //PS4 -> PS3
                         ({16{fsm_idle}}       &
                          ((ir2prs_us_tp_i[7]  ? ps2_reg            : 16'h0000) |  //PS2 -> PS3
                           (ir2prs_ips_tp_i[0] ? ips_reg[15:0]      : 16'h0000))); //PS4 -> PS3
   assign ps3_tag_next = (fsm_ps_shift_down    & ps2_tag_reg)                   |  //PS2 -> PS3
                         (fsm_ps_shift_up      & ips_tags_reg[0])               |  //PS4 -> PS3
                         (fsm_idle             &
                          ((ir2prs_us_tp_i[7]  & ps2_tag_reg)                   |  //PS2 -> PS3
                           (ir2prs_ips_tp_i[0] & ips_tags_reg[0])));               //PS4 -> PS3
   assign ps3_we       = fsm_ps_shift_down                                      |  //PS2 -> PS3
                         fsm_ps_shift_up                                        |  //PS4 -> PS3
                         (fsm_idle & ~fc2prs_hold_i &
                          (ir2prs_ps_rst_i                                      |  //reset PS
                           ir2prs_us_tp_i[7]                                    |  //PS2 -> PS3
                           ir2prs_ips_tp_i[0]));                                   //PS4 -> PS3

   //Flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                              //asynchronous reset
       begin
          rs0_reg     <= 16'h0000;                                                 //RS0 (TOS)
          ps0_reg     <= 16'h0000;                                                 //PS0 (TOS)
          ps1_reg     <= 16'h0000;                                                 //PS1 (TOS+1)
          ps2_reg     <= 16'h0000;                                                 //PS2 (TOS+2)
          ps3_reg     <= 16'h0000;                                                 //PS3 (TOS+3)
          rs0_tag_reg <= 1'b0;                                                     //RS0 tag
          ps0_tag_reg <= 1'b1;                                                     //PS0 tag
          ps1_tag_reg <= 1'b0;                                                     //PS1 tag
          ps2_tag_reg <= 1'b0;                                                     //PS2 tag
          ps3_tag_reg <= 1'b0;                                                     //PS3 tag
       end
     else if (sync_rst_i)                                                          //synchronous reset
       begin
          rs0_reg     <= 16'h0000;                                                 //RS0 (TOS)
          ps0_reg     <= 16'h0000;                                                 //PS0 (TOS)
          ps1_reg     <= 16'h0000;                                                 //PS1 (TOS+1)
          ps2_reg     <= 16'h0000;                                                 //PS2 (TOS+2)
          ps3_reg     <= 16'h0000;                                                 //PS3 (TOS+3)
          rs0_tag_reg <= 1'b0;                                                     //RS0 tag
          ps0_tag_reg <= 1'b1;                                                     //PS0 tag
          ps1_tag_reg <= 1'b0;                                                     //PS1 tag
          ps2_tag_reg <= 1'b0;                                                     //PS2 tag
          ps3_tag_reg <= 1'b0;                                                     //PS3 tag
       end
     else
       begin
          if (rs0_we) rs0_reg     <= rs0_next;                                     //RS0 (TOS)
          if (ps0_we) ps0_reg     <= ps0_next;                                     //PS0 (TOS)
          if (ps1_we) ps1_reg     <= ps1_next;                                     //PS1 (TOS+1)
          if (ps2_we) ps2_reg     <= ps2_next;                                     //PS2 (TOS+2)
          if (ps3_we) ps3_reg     <= ps3_next;                                     //PS3 (TOS+3)
          if (rs0_we) rs0_tag_reg <= rs0_tag_next;                                 //RS0 tag
          if (ps0_we) ps0_tag_reg <= ps0_tag_next;                                 //PS0 tag
          if (ps1_we) ps1_tag_reg <= ps1_tag_next;                                 //PS1 tag
          if (ps2_we) ps2_tag_reg <= ps2_tag_next;                                 //PS2 tag
          if (ps3_we) ps3_tag_reg <= ps3_tag_next;                                 //PS3 tag
       end

   //Intermediate parameter stack
   //----------------------------
   assign ips_next      = (fsm_ps_shift_down ?                                     //shift down
                           {ips_reg[(16*IPS_DEPTH)-17:0], 16'h0000}             :  //PSn   -> PSn+1
                           {IPS_DEPTH{16'h0000}})                               |  //
                          (fsm_ps_shift_up ?                                       //shift up
                           {16'h0000, ips_reg[(16*IPS_DEPTH)-1:16]}             :  //PSn+1 -> PSn
                           {IPS_DEPTH{16'h0000}})                               |  //
                          (fsm_dat2ps4 ?                                           //fetch read data
                           {{IPS_DEPTH-1{16'h0000}}, sbus_dat_i}                :  //DAT -> PS4
                           {IPS_DEPTH{16'h0000}})                               |  //
                          (fsm_psp2ps4 ?                                           //fetch PSP
                           {{IPS_DEPTH-1{16'h0000}},                               //DAT -> PS4
                            {16-SP_WIDTH{1'b0}}, dsp2prs_psp_i}                 :  //
                           {IPS_DEPTH{16'h0000}})                               |  //
                          (fsm_ips_clr_bottom ?                                    //clear IPS bottom cell
                           ips_reg                                              :  //
                           {IPS_DEPTH{16'h0000}})                               |  //
                          ({16*IPS_DEPTH{fsm_idle}} &                              //
                           (ir2prs_ips_tp_i[1] ?                                   //shift down
                            {ips_reg[(16*IPS_DEPTH)-17:0], 16'h0000}            :  //PSn   -> PSn+1
                            {IPS_DEPTH{16'h0000}})                              |  //
                           (ir2prs_ips_tp_i[0] ?                                   //shift up
                            {16'h0000, ips_reg[(16*IPS_DEPTH)-1:16]}            :  //PSn+1 -> PSn
                            {IPS_DEPTH{16'h0000}}));                               //
   assign ips_tags_next = (fsm_ps_shift_down ?                                     //shift down
                           {ips_tags_reg[IPS_DEPTH-2:0], 1'b0}                  :  //PSn   -> PSn+1
                           {IPS_DEPTH{1'b0}})                                   |  //
                          (fsm_ps_shift_up  ?                                      //shift up
                           {1'b0, ips_tags_reg[IPS_DEPTH-1:1]}                  :  //PSn+1 -> PSn
                           {IPS_DEPTH{1'b0}})                                   |  //
                          (fsm_dat2ps4 ?                                           //fetch read data
                           {{IPS_DEPTH-1{1'b0}}, 1'b1}                          :  //DAT -> PS4
                           {IPS_DEPTH{1'b0}})                                   |  //
                          (fsm_psp2ps4 ?                                           //get PSP
                           {{IPS_DEPTH-1{1'b0}}, 1'b1}                          :  //DAT -> PS4
                           {IPS_DEPTH{1'b0}})                                   |  //
                          (fsm_ips_clr_bottom ?                                    //clear IPS bottom cell
                           {{1'b0},ips_tags_reg[IPS_DEPTH-2:0]}                 :  //
                           {IPS_DEPTH{1'b0}})                                   |  //
                          ({IPS_DEPTH{fsm_idle}} &                                 //
                           (ir2prs_ips_tp_i[1] ?                                   //shift down
                            {ips_tags_reg[IPS_DEPTH-2:0], 1'b0}                 :  //PSn   -> PSn+1
                            {IPS_DEPTH{1'b0}})                                  |  //
                           (ir2prs_ips_tp_i[0] ?                                   //shift up
                            {1'b0, ips_tags_reg[IPS_DEPTH-1:1]}                 :  //PSn+1 -> PSn
                            {IPS_DEPTH{1'b0}}));                                   //

   assign ips_we        = fsm_ps_shift_down                                     |  //shift down
                          fsm_ps_shift_up                                       |  //shift up
                          fsm_dat2ps4                                           |  //fetch read data
                          fsm_psp2ps4                                           |  //get PSP
                          fsm_ips_clr_bottom                                    |  //clear IPS bottom cell
                          (fsm_idle &                                              //
                           (ir2prs_ps_rst_i                                     |  //reset PS
                            ir2prs_ips_tp_i[1]                                  |  //shift down
                            ir2prs_ips_tp_i[0]));                                  //shift up

   //Flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                              //asynchronous reset
       begin
          ips_reg      <= {IPS_DEPTH{16'h0000}};                                   //cells
          ips_tags_reg <= {IPS_DEPTH{1'b1}};                                       //tags
       end
     else if (sync_rst_i)                                                          //synchronous reset
       begin
          ips_reg      <= {IPS_DEPTH{16'h0000}};                                   //cells
          ips_tags_reg <= {IPS_DEPTH{1'b1}};                                       //tags
       end
     else if (ips_we)
       begin
          ips_reg      <= ips_next;                                                //cells
          ips_tags_reg <= ips_tags_next;                                           //tags
      end

   //Shortcuts
   assign ips_empty        = ~ips_tags_reg[0];                                     //PS4 contains no data
   assign ips_almost_empty = ~ips_tags_reg[1];                                     //PS5 contains no data
   assign ips_full         =  ips_tags_reg[IPS_DEPTH-1];                           //PSn contains data
   assign ips_almost_full  =  ips_tags_reg[IPS_DEPTH-2];                           //PSn-1 contains data

   //Intermediate return stack
   //-------------------------
   assign irs_next      = (fsm_rs_shift_down ?                                     //shift down
                           {irs_reg[(16*IRS_DEPTH)-17:0], 16'h0000}             :  //RSn   -> RSn+1
                           {IRS_DEPTH{16'h0000}})                               |  //
                          (fsm_rs_shift_up  ?                                      //shift up
                           {16'h0000, irs_reg[(16*IRS_DEPTH)-1:16]}             :  //RSn+1 -> RSn
                           {IRS_DEPTH{16'h0000}})                               |  //
                          (fsm_dat2rs1 ?                                           //fetch read data
                           {{IRS_DEPTH-1{16'h0000}}, sbus_dat_i}                :  //DAT -> RS4
                           {IRS_DEPTH{16'h0000}})                               |  //
                          (fsm_rsp2rs1 ?                                           //get RSP
                           {{IRS_DEPTH-1{16'h0000}},                               //DAT -> RS4
                            {16-SP_WIDTH{1'b0}}, dsp2prs_rsp_i}                 :  //
                           {IRS_DEPTH{16'h0000}})                               |  //
                          (fsm_irs_clr_bottom ?                                    //clear IRS bottom cell
                           ips_reg                                              :  //
                           {IPS_DEPTH{16'h0000}})                               |  //
                          ({16*IRS_DEPTH{fsm_idle}} &                              //
                           (ir2prs_irs_tp_i[1] ?                                   //shift down
                            {irs_reg[(16*IRS_DEPTH)-17:0], 16'h0000}            :  //RSn   -> RSn+1
                            {IRS_DEPTH{16'h0000}})                              |  //
                           (ir2prs_irs_tp_i[0] ?                                   //shift up
                            {16'h0000, irs_reg[(16*IRS_DEPTH)-1:16]}            :  //RSn+1 -> RSn
                            {IRS_DEPTH{16'h0000}}));                               //
   assign irs_tags_next = (fsm_rs_shift_down ?                                     //shift down
                           {irs_tags_reg[IRS_DEPTH-2:0], 1'b0}                  :  //RSn   -> RSn+1
                           {IRS_DEPTH{1'b0}})                                   |  //
                          (fsm_rs_shift_up  ?                                      //shift up
                           {1'b0, irs_tags_reg[IRS_DEPTH-1:1]}                  :  //RSn+1 -> RSn
                           {IRS_DEPTH{1'b0}})                                   |  //
                          (fsm_dat2rs1 ?                                           //fetch read data
                           {{IRS_DEPTH-1{1'b0}}, 1'b1}                          :  //DAT -> RS4
                           {IRS_DEPTH{1'b0}})                                   |  //
                          (fsm_rsp2rs1 ?                                           //get RSP
                           {{IRS_DEPTH-1{1'b0}}, 1'b1}                          :  //DAT -> RS4
                           {IRS_DEPTH{1'b0}})                                   |  //
                          (fsm_irs_clr_bottom ?                                    //clear IPR bottom cell
                           {{1'b0},irs_tags_reg[IRS_DEPTH-2:0]}                 :  //
                           {IRS_DEPTH{1'b0}})                                   |  //
                          ({IRS_DEPTH{fsm_idle}} &                                 //
                           (ir2prs_irs_tp_i[1] ?                                   //shift down
                            {irs_tags_reg[IRS_DEPTH-2:0], 1'b0}                 :  //RSn   -> RSn+1
                            {IRS_DEPTH{1'b0}})                                  |  //
                           (ir2prs_irs_tp_i[0] ?                                   //shift up
                            {1'b0, irs_tags_reg[IRS_DEPTH-1:1]}                 :  //RSn+1 -> RSn
                            {IRS_DEPTH{1'b0}}));                                   //
   assign irs_we        = fsm_rs_shift_down                                     |  //shift down
                          fsm_rs_shift_up                                       |  //shift up
                          fsm_dat2rs1                                           |  //fetch read data
                          fsm_rsp2rs1                                           |  //fetch read RSP
                          fsm_irs_clr_bottom                                    |  //clear IRS bottom cell
                          (fsm_idle &                                              //
                           (ir2prs_rs_rst_i                                     |  //reset RS
                            ir2prs_irs_tp_i[1]                                  |  //shift out
                            ir2prs_irs_tp_i[0]));                                  //shift in

   //Flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                              //asynchronous reset
       begin
          irs_reg      <= {IRS_DEPTH{16'h0000}};                                   //cells
          irs_tags_reg <= {IRS_DEPTH{1'b1}};                                       //tags
       end
     else if (sync_rst_i)                                                          //synchronous reset
       begin
          irs_reg      <= {IRS_DEPTH{16'h0000}};                                   //cells
          irs_tags_reg <= {IRS_DEPTH{1'b1}};                                       //tags
       end
     else if (irs_we)
       begin
          irs_reg      <= irs_next;                                                //cells
          irs_tags_reg <= irs_tags_next;                                           //tags
      end

   //Shortcuts
   assign irs_empty        = ~irs_tags_reg[0];                                     //PS1 contains no data
   assign irs_almost_empty = ~irs_tags_reg[1];                                     //PS2 contains no data
   assign irs_full         =  irs_tags_reg[IRS_DEPTH-1];                           //PSn contains data
   assign irs_almost_full  =  irs_tags_reg[IRS_DEPTH-2];                           //PSn-1 contains data

   //Lower parameter stack
   //---------------------
   assign lps_empty        = ~|dsp2prs_psp_i;                                      //PSP is zero

   //Lower return stack
   //------------------
   assign lrs_empty        = ~|dsp2prs_rsp_i;                                      //RSP is zero

   //Finite state machine
   //--------------------
   //State encoding (current task)
   localparam STATE_TASK_READY            = 3'b000;                                //ready fo new task
   localparam STATE_TASK_MANAGE_LS        = 3'b001;                                //manage lower stack
   localparam STATE_TASK_PS_FILL          = 3'b010;                                //empty the US and the IS to set a new PS
   localparam STATE_TASK_RS_FILL          = 3'b011;                                //empty the US and the IS to set a new PS
   localparam STATE_TASK_PS_EMPTY_GET_SP  = 3'b101;                                //empty the US and the IS to set a new PS
   localparam STATE_TASK_PS_EMPTY_SET_SP  = 3'b100;                                //empty the US and the IS to set a new PS
   localparam STATE_TASK_RS_EMPTY_GET_SP  = 3'b111;                                //empty the US and the IS to set a new PS
   localparam STATE_TASK_RS_EMPTY_SET_SP  = 3'b110;                                //empty the US and the IS to set a new PS
   //State encoding (stack bus)
   localparam STATE_SBUS_IDLE             = 2'b00;                                 //sbus is idle
   localparam STATE_SBUS_WRITE            = 2'b01;                                 //ongoing write access
   localparam STATE_SBUS_READ_PS          = 2'b10;                                 //read data pending for the IPS
   localparam STATE_SBUS_READ_RS          = 2'b11;                                 //read data pending for the IRS

   //Stack bus
   assign sbus_cyc_o         = sbus_stb_o | |(state_sbus_reg ^ STATE_SBUS_IDLE);   //bus cycle indicator
   assign sbus_dat_o            = prs2sagu_stack_sel_o ?                           //1:RS, 0:PS
                                  irs_reg[(16*IRS_DEPTH)-1:16*(IRS_DEPTH-1)] :     //unload RS
                                  ips_reg[(16*IPS_DEPTH)-1:16*(IPS_DEPTH-1)];      //unload PS
   assign fsm_dat2ps4        = ~|(state_sbus_reg ^ STATE_SBUS_READ_PS) |           //in STATE_SBUS_READ_PS
                               sbus_ack_i;                                         //bus request acknowledged
   assign fsm_dat2rs1        = ~|(state_sbus_reg ^ STATE_SBUS_READ_RS) |           //in STATE_SBUS_READ_RS
                               sbus_ack_i;                                         //bus request acknowledged

   //SAGU control
   //assign prs2sagu_psp_rst_o = fsm_idle & ~fc2prs_hold_i & ir2prs_ps_rst_i;      //reset PSP
   //assign prs2sagu_rsp_rst_o = fsm_idle & ~fc2prs_hold_i & ir2prs_rs_rst_i;      //reset RSP
   assign prs2sagu_psp_rst_o = fsm_idle & ir2prs_ps_rst_i;                         //reset PSP
   assign prs2sagu_rsp_rst_o = fsm_idle & ir2prs_rs_rst_i;                         //reset RSP

   //State transitions
   always @*
     begin
        //Default outputs
        fsm_idle                = 1'b0;                                            //FSM is not idle
        fsm_ps_shift_up         = 1'b0;                                            //shift PS upwards   (IPS -> UPS)
        fsm_ps_shift_down       = 1'b0;                                            //shift PS downwards (UPS -> IPS)
        fsm_rs_shift_up         = 1'b0;                                            //shift RS upwards   (IRS -> URS)
        fsm_rs_shift_down       = 1'b0;                                            //shift RS downwards (IRS -> URS)
        fsm_psp2ps4             = 1'b0;                                            //capture PSP
        fsm_ips_clr_bottom      = 1'b0;                                            //clear IPS bottom cell
        fsm_rsp2rs1             = 1'b0;                                            //capture RSP
        fsm_irs_clr_bottom      = 1'b0;                                            //clear IRS bottom cell
        sbus_stb_o              = 1'b0;                                            //access request
        sbus_we_o               = 1'b0;                                            //write enable
        prs2fc_hold_o           = 1'b1;                                            //stacks not ready
        prs2sagu_hold_o         = 1'b1;                                            //maintain stack pointers
        prs2sagu_stack_sel_o    = 1'b0;                                            //1:RS, 0:PS
        prs2sagu_push_o         = 1'b0;                                            //increment stack pointer
        prs2sagu_pull_o         = 1'b0;                                            //decrement stack pointer
        prs2sagu_load_o         = 1'b0;                                            //load stack pointer
        state_task_next         = state_task_reg;                                  //keep processing current task
        state_sbus_next         = state_sbus_reg;                                  //keep stack bus state

        //Exceptions
        prs2excpt_psuf_o = (rs0_tag_reg & ~ps0_tag_reg & &ir2prs_us_tp_i[1:0])|    //invalid PS0 <-> RS0 swap
                           (              ~ps0_tag_reg &  ir2prs_us_tp_i[2]  )|    //invalid shift to PS0
                           (ps0_tag_reg & ~ps1_tag_reg & &ir2prs_us_tp_i[3:2])|    //invalid PS1 <-> PS0 swap
                           (ps1_tag_reg & ~ps2_tag_reg & &ir2prs_us_tp_i[5:4])|    //invalid PS2 <-> PS1 swap
                           (ps2_tag_reg & ~ps3_tag_reg & &ir2prs_us_tp_i[7:6]);    //invalid PS3 <-> PS2 swap
        prs2excpt_rsuf_o = (ps0_tag_reg & ~rs0_tag_reg & &ir2prs_us_tp_i[1:0])|    //invalid RS0 <-> PS0 swap;
                           (              ~rs0_tag_reg &  ir2prs_irs_tp_i[0]  );   //invalid shift to RS0


        //Wait for ongoing SBUS accesses
        if (~|state_sbus_reg | sbus_ack_i)                                         //bus is idle or current access is ended
          begin
             state_sbus_next = STATE_SBUS_IDLE;                                    //idle by default

             case (state_task_reg)

               //Perform stack operations and initiate early loading and unloading
               STATE_TASK_READY:
                 begin
                    //Idle indicator
                    fsm_idle                  = 1'b1;                              //FSM is idle
                    prs2fc_hold_o             = 1'b0;                              //ready to accept new task

                    //Defaults
                    state_task_next           = STATE_TASK_READY;                  //for logic optimization

                    //Detect early load or unload conditions
                    if ((~lrs_empty &
                         irs_almost_empty & ir2prs_irs_tp_i[0]) |                  //IRS early load condition
                        (irs_almost_full  & ir2prs_irs_tp_i[1]) |                  //IRS early unload condition
                        (~lps_empty &
                         ips_almost_empty & ir2prs_ips_tp_i[0]) |                  //IPS early load condition
                        (ips_almost_full  & ir2prs_ips_tp_i[1]))                   //IPS early unload condition
                      begin
                         state_task_next = state_task_next |                       //handle lower stack transfers
                                           STATE_TASK_MANAGE_LS;                   //

                         //Initiate early load accesses
                         if ((~lrs_empty &
                              irs_almost_empty & ir2prs_irs_tp_i[0]) |             //IRS early load condition
                             (~lps_empty &
                              ips_almost_empty & ir2prs_ips_tp_i[0]))              //IPS early load condition
                           begin
                              sbus_stb_o      = 1'b1;                              //request sbus access
                              prs2sagu_hold_o =  sbus_stall_i;                     //update stack pointers
                              prs2sagu_pull_o = ~sbus_stall_i;                     //decrement stack pointer
                              if (~lrs_empty &
                                  irs_almost_empty & ir2prs_irs_tp_i[0])           //IRS early load condition
                                begin
                                   prs2sagu_stack_sel_o = 1'b1;                    //select RS immediately
                                   if (~sbus_stall_i)
                                     state_sbus_next    = STATE_SBUS_READ_RS;      //SBUS -> IRS
                                end
                              else
                                begin
                                   if (~sbus_stall_i)
                                     state_sbus_next    = STATE_SBUS_READ_PS;      //SBUS -> IPS
                                end
                           end // if ((irs_almost_empty & ir2prs_irs_tp_i[0]) |...\

                      end // if ((irs_almost_empty & ir2prs_irs_tp_i[0]) |...

                    //Get PSP
                    if (ir2prs_psp_get_i)
                      begin
                         state_task_next = state_task_next |                       //trigger PSP read sequence
                                           STATE_TASK_PS_EMPTY_GET_SP;             //
                      end

                    //Set PSP
                    if (ir2prs_psp_set_i)
                      begin
                         state_task_next = state_task_next |                       //trigger PSP write sequence
                                           STATE_TASK_PS_EMPTY_SET_SP;             //
                      end

                    //Get RSP
                    if (ir2prs_rsp_get_i)
                      begin
                         state_task_next = state_task_next |                       //trigger PSP read sequence
                                           STATE_TASK_PS_EMPTY_GET_SP;             //
                      end

                    //Set RSP
                    if (ir2prs_rsp_set_i)
                      begin
                         state_task_next = state_task_next |                       //trigger PSP write sequence
                                           STATE_TASK_PS_EMPTY_SET_SP;             //
                      end
                 end // case: STATE_TASK_READY

               //Transfer a cell from US to IS
               STATE_TASK_MANAGE_LS:
                 begin

                    //Manage lower return stack
                    if ((~|(state_sbus_reg ^ STATE_SBUS_READ_RS) &                 //IRS load condition
                         ~lrs_empty & irs_empty)                  |                //
                        irs_full)                                                  //IRS unload condition
                      begin
                         sbus_stb_o                   = 1'b1;                      //request sbus access
                         prs2sagu_hold_o              =  sbus_stall_i;             //update stack pointers
                         prs2sagu_stack_sel_o         = 1'b1;                      //select RS immediately

                         //Write access
                         if (irs_full)                                             //IRS unload condition
                           begin
                              sbus_we_o               = 1'b1;                      //write enable
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_push_o    = 1'b1;                      //increment stack pointer
                                   fsm_irs_clr_bottom = 1'b1;                      //clear IRS bottom cell
                                   state_sbus_next = STATE_SBUS_WRITE;             //IRS -> SBUS
                                   if ((~|(state_sbus_reg ^ STATE_SBUS_READ_PS) &  //IRS load condition
                                        ~lps_empty & ips_empty)                  | //
                                       ips_full)                                   //IRS unload condition
                                     state_task_next  = STATE_TASK_MANAGE_LS;      //manage LPS
                                   else
                                     state_task_next  = STATE_TASK_READY;          //ready for next task
                                end // if (~sbus_stall_i)
                           end // if (irs_full)

                         //Read access
                         else
                           begin
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_pull_o    = 1'b1;                      //decrement stack pointer
                                   state_sbus_next    = STATE_SBUS_READ_RS;        //SBUS -> IRS
                                end // else: !if(irs_full)
                           end // else: !if(irs_full)
                      end // if ((~|(state_sbus_reg ^ STATE_SBUS_READ_RS) &...

                    //Manage lower parameter stack
                    else
                    if ((~|(state_sbus_reg ^ STATE_SBUS_READ_PS) &                 //IRS load condition
                         ~lps_empty & ips_empty)                  |                //
                        ips_full)                                                  //IRS unload condition
                      begin

                         sbus_stb_o                   = 1'b1;                      //request sbus access
                         prs2sagu_hold_o              =  sbus_stall_i;             //update stack pointers

                         //Write access
                         if (irs_full)                                             //IRS unload condition
                           begin
                              sbus_we_o               = 1'b1;                      //write enable
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_push_o    = 1'b1;                      //increment stack pointer
                                   fsm_ips_clr_bottom = 1'b1;                      //clear IPS bottom cell
                                   state_sbus_next    = STATE_SBUS_WRITE;          //IRS -> SBUS
                                   state_task_next    = STATE_TASK_READY;          //ready for next task
                                end // if (~sbus_stall_i)
                           end // if (irs_full)

                         //Read access
                         else
                           begin
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_pull_o    = 1'b1;                      //decrement stack pointer
                                   state_sbus_next    = STATE_SBUS_READ_PS;        //SBUS -> IPS
                                end // else: !if(irs_full)
                           end // else: !if(irs_full)
                      end // if ((~|(state_sbus_reg ^ STATE_SBUS_READ_PS) &...

                    //No load or unload required
                    else
                      begin
                         state_task_next              = STATE_TASK_READY;          //ready for the next instruction
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
                              sbus_stb_o              = 1'b1;                      //access request
                              sbus_we_o               = 1'b1;                      //write enable
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_hold_o    = 1'b0;                      //update stack pointers
                                   prs2sagu_push_o    = 1'b1;                      //increment stack pointer
                                   fsm_ps_shift_down  = 1'b1;                      //shift PS downwards (UPS -> IPS)
                                   state_sbus_next    = STATE_SBUS_WRITE;          //IPS -> SBUS
                                end
                           end
                         //Align IPS
                         else
                           begin
                              fsm_ps_shift_down       = 1'b1;                      //shift PS downwards (UPS -> IPS)
                           end
                      end // if (|{ips_tags_reg[IPS_DEPTH-1:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                    //Copy PSP to PS4
                    else
                      begin
                         fsm_psp2ps4                  = 1'b1;                      //capture PSP
                         state_task_next              = STATE_TASK_PS_FILL;        //refill IPS
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
                              sbus_stb_o              = 1'b1;                      //access request
                              sbus_we_o               = 1'b1;                      //write enable
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_hold_o    = 1'b0;                      //update stack pointers
                                   prs2sagu_push_o    = 1'b1;                      //increment stack pointer
                                   fsm_ps_shift_down  = 1'b1;                      //shift PS downwards (UPS -> IPS)
                                   state_sbus_next    = STATE_SBUS_WRITE;          //IPS -> SBUS
                                end
                           end
                         //Align IPS
                         else
                           begin
                              fsm_ps_shift_down       = 1'b1;                      //shift PS downwards (UPS -> IPS)
                           end
                      end // if (|{ips_tags_reg[IPS_DEPTH-1:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                    //Set PSP
                    else
                      begin
                         if (ips_full)
                           begin
                              fsm_ips_clr_bottom        = 1'b1;                    //clear IPS bottom cell
                              prs2sagu_load_o           = 1'b1;                    //load stack pointer
                           end
                         else
                           begin
                              //PS underflow
                              prs2excpt_psuf_o = 1'b1;                             //trigger exception
                           end
                         state_task_next               = STATE_TASK_PS_FILL;       //refill IPS
                      end // else: !if(|{ips_tags_reg[IPS_DEPTH-2:0],ps3_tag_reg,ps2_tag_reg,ps1_tag_reg,ps0_tag_reg})
                 end // case: STATE_TASK_PS_EMPTY_SET_SP

               //Empty URS and IRS to get RSP
               STATE_TASK_RS_EMPTY_GET_SP:
                 begin
                    //Shift content to LRS
                    prs2sagu_stack_sel_o              = 1'b0;                      //1:RS, 0:PS
                    if (|{irs_tags_reg[IRS_DEPTH-1:0],rs0_reg})
                      begin
                         //Unload IRS
                         if (irs_full)
                           begin
                              sbus_stb_o              = 1'b1;                      //access request
                              sbus_we_o               = 1'b1;                      //write enable
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_hold_o    = 1'b0;                      //update stack pointers
                                   prs2sagu_push_o    = 1'b1;                      //increment stack pointer
                                   fsm_rs_shift_down  = 1'b1;                      //shift RS downwards (URS -> IRS)
                                   state_sbus_next    = STATE_SBUS_WRITE;          //IRS -> SBUS
                                end
                           end
                         //Align IRS
                         else
                           begin
                              fsm_rs_shift_down       = 1'b1;                      //shift RS downwards (URS -> IRS)
                           end
                      end // if (|{irs_tags_reg[IRS_DEPTH-1:0],rs0_tag_reg})
                    //Copy RSP to RS4
                    else
                      begin
                         fsm_rsp2rs1                  = 1'b1;                      //capture RSP
                         state_task_next              = STATE_TASK_RS_FILL;        //refill IRS
                      end // else: !if(|{irs_tags_reg[IRS_DEPTH-1:0],rs0_tag_reg})
                 end // case: STATE_TASK_RS_EMPTY_GET_SP

               //Empty URS and IRS to set RSP
               STATE_TASK_RS_EMPTY_SET_SP:
                 begin
                    //Shift content to LRS
                    prs2sagu_stack_sel_o              = 1'b0;                       //1:RS, 0:PS
                    if (|{irs_tags_reg[IRS_DEPTH-2:0],rs0_reg})
                      begin
                         //Unload IRS
                         if (irs_full)
                           begin
                              sbus_stb_o              = 1'b1;                      //access request
                              sbus_we_o               = 1'b1;                      //write enable
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_hold_o    = 1'b0;                      //update stack pointers
                                   prs2sagu_push_o    = 1'b1;                      //increment stack pointer
                                   fsm_rs_shift_down  = 1'b1;                      //shift RS downwards (URS -> IRS)
                                   state_sbus_next    = STATE_SBUS_WRITE;          //IRS -> SBUS
                                end
                           end
                         //Align IRS
                         else
                           begin
                              fsm_rs_shift_down       = 1'b1;                      //shift RS downwards (URS -> IRS)
                           end
                      end // if (|{irs_tags_reg[IRS_DEPTH-1:0],rs0_tag_reg})
                    //Set RSP
                    else
                      begin
                         if (irs_full)
                           begin
                              fsm_irs_clr_bottom        = 1'b1;                    //clear IRS bottom cell
                              prs2sagu_load_o           = 1'b1;                    //load stack pointer
                           end
                         else
                           begin
                              //RS underflow
                              prs2excpt_rsuf_o = 1'b1;                             //trigger exception
                           end
                         state_task_next                = STATE_TASK_RS_FILL;      //refill IRS
                      end // else: !if(|{irs_tags_reg[IRS_DEPTH-2:0],rs0_tag_reg})
                 end // case: STATE_TASK_RS_EMPTY_SET_SP

               //Refill PS
               STATE_TASK_PS_FILL:
                 begin
                    //Done
                    if (ps0_tag_reg)
                      begin
                         state_task_next                = STATE_TASK_READY;        //ready for next task
                      end
                    //Shift PS upward
                    else
                      begin
                         //Load IPS
                         if (lps_empty)
                           begin
                              sbus_stb_o                = 1'b1;                    //access request
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_hold_o      = 1'b0;                    //update stack pointers
                                   prs2sagu_pull_o      = 1'b1;                    //increment stack pointer
                                   fsm_ps_shift_up      = 1'b1;                    //shift RS downwards (URS -> IRS)
                                   state_sbus_next      = STATE_SBUS_READ_PS;      //SBUS -> IPS
                                end
                           end
                         //Align UPS
                         else
                           begin
                              fsm_ps_shift_up           = 1'b1;                    //shift PS downwards (IPS -> UPS)
                           end // else: !if(lps_empty)
                      end // else: !if(ps0_tag_reg)
                 end // case: STATE_TASK_PS_FILL

               //Refill RS
               STATE_TASK_RS_FILL:
                 begin
                    //Done
                    if (rs0_tag_reg)
                      begin
                         state_task_next                = STATE_TASK_READY;        //ready for next task
                      end
                    //Shift RS upward
                    else
                      begin
                         //Load IRS
                         if (lrs_empty)
                           begin
                              sbus_stb_o                = 1'b1;                    //access request
                              if (~sbus_stall_i)
                                begin
                                   prs2sagu_hold_o      = 1'b0;                    //update stack pointers
                                   prs2sagu_pull_o      = 1'b1;                    //increment stack pointer
                                   fsm_rs_shift_up      = 1'b1;                    //shift RS downwards (URS -> IRS)
                                   state_sbus_next      = STATE_SBUS_READ_RS;      //SBUS -> IRS
                                end
                           end
                         //Align URS
                         else
                           begin
                              fsm_rs_shift_up           = 1'b1;                    //shift RS downwards (IRS -> URS)
                           end // else: !if(lrs_empty)
                      end // else: !if(rs0_tag_reg)
                 end // case: STATE_TASK_RS_FILL

             endcase // case (state_task_reg)

          end // if (~|state_sbus_reg |sbus_ack_i)
     end // always @ *

   //Flip flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                              //asynchronous reset
       begin
          state_task_reg <= STATE_TASK_READY;                                       //ready fo new task
          state_sbus_reg <= STATE_SBUS_IDLE;                                       //sbus is idle
       end
     else if (sync_rst_i)                                                          //synchronous reset
       begin
          state_task_reg <= STATE_TASK_READY;                                      //ready fo new task
          state_sbus_reg <= STATE_SBUS_IDLE;                                       //sbus is idle
       end
     else                                                                          //state transition
       begin
          state_task_reg <= state_task_next;                                       //state transition
          state_sbus_reg <= state_sbus_next;                                       //state transition
       end


   //Stack data outputs
   //------------------
   assign pbus_dat_o              = ps0_reg;                                       //write data bus
   assign prs2alu_ps0_o           = ps0_reg;                                       //current PS0 (TOS)
   assign prs2alu_ps1_o           = ps1_reg;                                       //current PS1 (TOS+1)
   assign prs2fc_ps0_false_o      = ~|ps0_reg;                                     //PS0 is zero
   assign prs2pagu_ps0_o          = ps0_reg;                                       //PS0
   assign prs2pagu_rs0_o          = rs0_reg;                                       //RS0
   assign prs2sagu_psp_load_val_o =
                           ips_reg[(16*(IPS_DEPTH-1))+SP_WIDTH-1:16*(IPS_DEPTH-1)];//parameter stack load value
   assign prs2sagu_rsp_load_val_o =
                           irs_reg[(16*(IRS_DEPTH-1))+SP_WIDTH-1:16*(IRS_DEPTH-1)];//return stack load value

   //Probe signals
   //-------------
   assign prb_state_task_o        = state_task_reg;                                //current FSM task
   assign prb_state_sbus_o        = state_sbus_reg;                                //current stack bus state
   assign prb_rs0_o               = rs0_reg;                                       //current RS0
   assign prb_ps0_o               = ps0_reg;                                       //current PS0
   assign prb_ps1_o               = ps1_reg;                                       //current PS1
   assign prb_ps2_o               = ps2_reg;                                       //current PS2
   assign prb_ps3_o               = ps3_reg;                                       //current PS3
   assign prb_rs0_tag_o           = rs0_tag_reg;                                   //current RS0 tag
   assign prb_ps0_tag_o           = ps0_tag_reg;                                   //current PS0 tag
   assign prb_ps1_tag_o           = ps1_tag_reg;                                   //current PS1 tag
   assign prb_ps2_tag_o           = ps2_tag_reg;                                   //current PS2 tag
   assign prb_ps3_tag_o           = ps3_tag_reg;                                   //current PS3 tag
   assign prb_ips_o               = ips_reg;                                       //current IPS
   assign prb_ips_tags_o          = ips_tags_reg;                                  //current IPS
   assign prb_irs_o               = irs_reg;                                       //current IRS
   assign prb_irs_tags_o          = irs_tags_reg;                                  //current IRS

endmodule // N1_prs
