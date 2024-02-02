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
//#    This module instantiates all levels of the parameter and the return      #
//#    stack.                                                                   #
//#    stack.                                                                   #
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
//#   May 8, 2019                                                               #
//#      - Added RTY_I support to PBUS                                          #
//#   January 24, 2024                                                          #
//#      - New implementation                                                   #
//###############################################################################
`default_nettype none

module N1_prs
  #(parameter   IPS_DEPTH       =       8,                                          //depth of the intermediate parameter stack
    parameter   IRS_DEPTH       =       8)                                          //depth of the intermediate return stack

   (//Clock and reset
    input wire                               clk_i,                                 //module clock
    input wire                               async_rst_i,                           //asynchronous reset
    input wire                               sync_rst_i,                            //synchronous reset

   




    //Program bus (wishbone)
    output wire [15:0]                       pbus_dat_o,                            //write data bus
    input  wire [15:0]                       pbus_dat_i,                            //read data bus

    //Stack bus (wishbone)
    output wire                              sbus_cyc_o,                            //bus cycle indicator       +-
    output reg                               sbus_stb_o,                            //access request            | initiator
    output reg                               sbus_we_o,                             //write enable              | to
    output wire [15:0]                       sbus_dat_o,                            //write data bus            | target
    input  wire                              sbus_ack_i,                            //bus cycle acknowledge     +-
    input  wire                              sbus_stall_i,                          //access delay              | initiator to initiator
    input  wire [15:0]                       sbus_dat_i,                            //read data bus             +-

    //Interrupt interface
    input  wire [15:0]                       irq_req_i,                             //requested interrupt vector

    //Internal signals
    //----------------
    //ALU interface
    output wire [15:0]                       prs2alu_ps0_o,                         //current PS0 (TOS)
    output wire [15:0]                       prs2alu_ps1_o,                         //current PS1 (TOS+1)
    input  wire [15:0]                       alu2prs_ps0_next_i,                    //new PS0 (TOS)
    input  wire [15:0]                       alu2prs_ps1_next_i,                    //new PS1 (TOS+1)

    //DSP interface
    input  wire [SP_WIDTH-1:0]               dsp2prs_psp_i,                         //parameter stack pointer (AGU output)
    input  wire [SP_WIDTH-1:0]               dsp2prs_rsp_i,                         //return stack pointer (AGU output)

    //EXCPT interface
    output reg                               prs2excpt_psuf_o,                      //parameter stack underflow
    output reg                               prs2excpt_rsuf_o,                      //return stack underflow
    input  wire [15:0]                       excpt2prs_tc_i,                        //throw code

    //FC interface
    output reg                               prs2fc_hold_o,                         //stacks not ready
    output wire                              prs2fc_ps0_false_o,                    //PS0 is zero
    input  wire                              fc2prs_hold_i,                         //hold any state transition
    input  wire                              fc2prs_dat2ps0_i,                      //capture read data
    input  wire                              fc2prs_tc2ps0_i,                       //capture throw code
    input  wire                              fc2prs_isr2ps0_i,                      //capture ISR

    //IR interface
    input  wire [15:0]                       ir2prs_lit_val_i,                      //literal value
    input  wire [7:0]                        ir2prs_us_tp_i,                        //upper stack transition pattern
    input  wire [1:0]                        ir2prs_ips_tp_i,                       //10:push, 01:pull
    input  wire [1:0]                        ir2prs_irs_tp_i,                       //10:push, 01:pull
    input  wire                              ir2prs_alu2ps0_i,                      //ALU output  -> PS0
    input  wire                              ir2prs_alu2ps1_i,                      //ALU output  -> PS1
    input  wire                              ir2prs_lit2ps0_i,                      //literal     -> PS0
    input  wire                              ir2prs_pc2rs0_i,                       //PC          -> RS0
    input  wire                              ir2prs_ps_rst_i,                       //reset parameter stack
    input  wire                              ir2prs_rs_rst_i,                       //reset return stack
    input  wire                              ir2prs_psp_get_i,                      //read parameter stack pointer
    input  wire                              ir2prs_psp_set_i,                      //write parameter stack pointer
    input  wire                              ir2prs_rsp_get_i,                      //read return stack pointer
    input  wire                              ir2prs_rsp_set_i,                      //write return stack pointer

    //PAGU interface
    output wire [15:0]                       prs2pagu_ps0_o,                        //PS0
    output wire [15:0]                       prs2pagu_rs0_o,                        //RS0
    input  wire [15:0]                       pagu2prs_prev_adr_i,                   //address register output

    //SAGU interface
    output reg                               prs2sagu_hold_o,                       //maintain stack pointers
    output wire                              prs2sagu_psp_rst_o,                    //reset PSP
    output wire                              prs2sagu_rsp_rst_o,                    //reset RSP
    output reg                               prs2sagu_stack_sel_o,                  //1:RS, 0:PS
    output reg                               prs2sagu_push_o,                       //increment stack pointer
    output reg                               prs2sagu_pull_o,                       //decrement stack pointer
    output reg                               prs2sagu_load_o,                       //load stack pointer
    output wire [SP_WIDTH-1:0]               prs2sagu_psp_load_val_o,               //parameter stack load value
    output wire [SP_WIDTH-1:0]               prs2sagu_rsp_load_val_o,               //return stack load value

    //Probe signals
    output wire [2:0]                        prb_state_task_o,                      //current state
    output wire [1:0]                        prb_state_sbus_o,                      //current state
    output wire [15:0]                       prb_rs0_o,                             //current RS0
    output wire [15:0]                       prb_ps0_o,                             //current PS0
    output wire [15:0]                       prb_ps1_o,                             //current PS1
    output wire [15:0]                       prb_ps2_o,                             //current PS2
    output wire [15:0]                       prb_ps3_o,                             //current PS3
    output wire                              prb_rs0_tag_o,                         //current RS0 tag
    output wire                              prb_ps0_tag_o,                         //current PS0 tag
    output wire                              prb_ps1_tag_o,                         //current PS1 tag
    output wire                              prb_ps2_tag_o,                         //current PS2 tag
    output wire                              prb_ps3_tag_o,                         //current PS3 tag
    output wire [(16*IPS_DEPTH)-1:0]         prb_ips_o,                             //current IPS
    output wire [IPS_DEPTH-1:0]              prb_ips_tags_o,                        //current IPS
    output wire [(16*IRS_DEPTH)-1:0]         prb_irs_o,                             //current IRS
    output wire [IRS_DEPTH-1:0]              prb_irs_tags_o);                       //current IRS

   //Internal signals
   //-----------------
   //FSM
   reg  [2:0]                                state_task_reg;                        //current FSM task
   reg  [2:0]                                state_task_next;                       //next FSM task
   reg  [1:0]                                state_sbus_reg;                        //current stack bus state
   reg  [1:0]                                state_sbus_next;                       //next stack bus state

   reg                                       fsm_idle;                              //FSM is in idle
   reg                                       fsm_ps_shift_up;                       //shift PS upwards   (IPS -> UPS)
   reg                                       fsm_ps_shift_down;                     //shift PS downwards (UPS -> IPS)
   reg                                       fsm_rs_shift_up;                       //shift RS upwards   (IRS -> URS)
   reg                                       fsm_rs_shift_down;                     //shift RS downwards (IRS -> URS)
   reg                                       fsm_psp2ps4;                           //capture PSP
   wire                                      fsm_dat2ps4;                           //capture SBUS read data
   reg                                       fsm_ips_clr_bottom;                    //clear IPS bottom cell
   reg                                       fsm_rsp2rs1;                           //capture RSP
   wire                                      fsm_dat2rs1;                           //capture SBUS read data
   reg                                       fsm_irs_clr_bottom;                    //clear IRS bottom cell
   //Upper stack
   reg  [15:0]                               rs0_reg;                               //current RS0
   reg  [15:0]                               ps0_reg;                               //current PS0
   reg  [15:0]                               ps1_reg;                               //current PS1
   reg  [15:0]                               ps2_reg;                               //current PS2
   reg  [15:0]                               ps3_reg;                               //current PS3
   wire [15:0]                               rs0_next;                              //next RS0
   wire [15:0]                               ps0_next;                              //next PS0
   wire [15:0]                               ps1_next;                              //next PS1
   wire [15:0]                               ps2_next;                              //next PS2
   wire [15:0]                               ps3_next;                              //next PS3
   reg                                       rs0_tag_reg;                           //current RS0 tag
   reg                                       ps0_tag_reg;                           //current PS0 tag
   reg                                       ps1_tag_reg;                           //current PS1 tag
   reg                                       ps2_tag_reg;                           //current PS2 tag
   reg                                       ps3_tag_reg;                           //current PS3 tag
   wire                                      rs0_tag_next;                          //next RS0 tag
   wire                                      ps0_tag_next;                          //next PS0 tag
   wire                                      ps1_tag_next;                          //next PS1 tag
   wire                                      ps2_tag_next;                          //next PS2 tag
   wire                                      ps3_tag_next;                          //next PS3 tag
   wire                                      rs0_we;                                //write enable
   wire                                      ps0_we;                                //write enable
   wire                                      ps1_we;                                //write enable
   wire                                      ps2_we;                                //write enable
   wire                                      ps3_we;                                //write enable
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




   //Intermediate parameter stack to lower stack 
   wire [15:0]                               ips2ls_push_data,                    //push data
   wire                                      ips2ls_push,                         //push request
   wire                                      ips2ls_pull,                         //pull request
   wire [15:0]                               ls2ips_pull_data_del,                //delayed pull data (available one cycle after the pull request)
   wire                                      ls2ips_push_bsy,                     //push busy indicator
   wire                                      ls2ips_pull_bsy,                     //pull busy indicator
   wire                                      ls2ips_empty,                        //empty indicator
   wire                                      ls2ips_full,                         //overflow indicator

   //Intermediate return stack to lower stack 
   wire [15:0]                               irs2ls_push_data,                    //push data
   wire                                      irs2ls_push,                         //push request
   wire                                      irs2ls_pull,                         //pull request
   wire [15:0]                               ls2irs_pull_data_del,                //delayed pull data (available one cycle after the pull request)
   wire                                      ls2irs_push_bsy,                     //push busy indicator
   wire                                      ls2irs_pull_bsy,                     //pull busy indicator
   wire                                      ls2irs_empty,                        //empty indicator
   wire                                      ls2irs_full,                         //overflow indicator

   //Lower stack to DPRAM
   wire [8:0]                                ls2ram_raddr;                          //read address
   wire [8:0]                                ls2ram_waddr;                          //write address
   wire [15:0]                               ls2ram_wdata;                          //write data
   wire                                      ls2ram_re;                             //read enable
   wire                                      ls2ram_we;                             //write enable
   wire [15:0]                               ram2ls_rdata;                          //read data
    

   






   


   //Upper Stack
   //-----------



   




   
   //Intermediate Stack
   //------------------
   //Parameter stack
   N1_is
     #(IS_DEPTH(IRS_DEPTH))                                                                      //depth of the IS (must be >=2)
   irs   
     (//Clock and reset
      .clk_i			(clk_i),                                                //module clock
      .async_rst_i		(async_rst_i),                                          //asynchronous reset
      .sync_rst_i		(sync_rst_i),                                           //synchronous reset
      //Soft reset
      .us2is_rst_i		(),                                         //IS stack reset request
      //Interface to upper stack
      .us2is_push_data_i	(),                                    //US push data
      .us2is_push_i		(),                                         //US push request
      .us2is_pull_i		(),                                         //US pull request
      .is2us_pull_data_o	(),                                    //US pull data
      .is2us_push_bsy_o		(),                                     //US push busy indicator
      .is2us_pull_bsy_o		(),                                     //US pull busy indicator
      .is2us_empty_o		(),                                        //US empty indicator
      .is2us_full_o		(),                                         //US overflow indicator
      //Interface to lower stack
      .ls2is_pull_data_del_i	(ls2ips_pull_data_del),                                //LS delayed pull data (available one cycle after the pull request)
      .ls2is_push_bsy_i		(ls2ips_push_bsy),                                     //LS push busy indicator
      .ls2is_pull_bsy_i		(ls2ips_pull_bsy),                                     //LS pull busy indicator
      .ls2is_empty_i		(ls2ips_empty),                                        //LS empty indicator
      .ls2is_full_i		(ls2ips_full),                                         //LS overflow indicator
      .is2ls_push_data_o	(ips2ls_push_data),                                    //LS push data
      .is2ls_push_o		(ips2ls_push),                                         //LS push request
      .is2ls_pull_o		(ips2ls_pull),                                         //LS pull request
      //Probe signals
      .prb_is_cells_o		(),                                       //current IS cells
      .prb_is_tags_o		(),                                        //current IS tags
      .prb_is_state_o)		();                                      //current state

   //Return stack
   N1_is
     #(IS_DEPTH(IPS_DEPTH))                                                                      //depth of the IS (must be >=2)
   irs   
     (//Clock and reset
      .clk_i			(clk_i),                                                //module clock
      .async_rst_i		(async_rst_i),                                          //asynchronous reset
      .sync_rst_i		(sync_rst_i),                                           //synchronous reset
      //Soft reset
      .us2is_rst_i		(),                                         //IS stack reset request
      //Interface to upper stack
      .us2is_push_data_i	(),                                    //US push data
      .us2is_push_i		(),                                         //US push request
      .us2is_pull_i		(),                                         //US pull request
      .is2us_pull_data_o	(),                                    //US pull data
      .is2us_push_bsy_o		(),                                     //US push busy indicator
      .is2us_pull_bsy_o		(),                                     //US pull busy indicator
      .is2us_empty_o		(),                                        //US empty indicator
      .is2us_full_o		(),                                         //US overflow indicator
      //Interface to lower stack
      .ls2is_pull_data_del_i	(ls2irs_pull_data_del),                                //LS delayed pull data (available one cycle after the pull request)
      .ls2is_push_bsy_i		(ls2irs_push_bsy),                                     //LS push busy indicator
      .ls2is_pull_bsy_i		(ls2irs_pull_bsy),                                     //LS pull busy indicator
      .ls2is_empty_i		(ls2irs_empty),                                        //LS empty indicator
      .ls2is_full_i		(ls2irs_full),                                         //LS overflow indicator
      .is2ls_push_data_o	(irs2ls_push_data),                                    //LS push data
      .is2ls_push_o		(irs2ls_push),                                         //LS push request
      .is2ls_pull_o		(irs2ls_pull),                                         //LS pull request
      //Probe signals
      .prb_is_cells_o		(),                                       //current IS cells
      .prb_is_tags_o		(),                                        //current IS tags
      .prb_is_state_o)		();                                      //current state
   
   //Lower Stack
   //-----------
   //LS controller
   N1_ls_1xdpram
     #(.AWIDTH(8)) //RAM address width
   ls
     (//Clock and reset
      .clk_i			(clk_i),                                                //module clock
      .async_rst_i		(async_rst_i),                                          //asynchronous reset
      .sync_rst_i		(sync_rst_i),                                           //synchronous reset
      //Soft reset
      .us2ls_ps_rst_i		(),                                         //parameter stack reset request
      .us2ls_rs_rst_i		(),                                         //return stack reset request
      //Interface to the immediate stack
      .ips2ls_push_data_i	(ips2ls_push_data),                                   //parameter stack push data
      .irs2ls_push_data_i	(irs2ls_push_data),                                   //return stack push data
      .ips2ls_push_i		(ips2ls_push),                                        //parameter stack push request
      .irs2ls_push_i		(irs2ls_push),                                        //return stack push request
      .ips2ls_pull_i		(ips2ls_pull),                                        //parameter stack pull request
      .irs2ls_pull_i		(irs2ls_pull),                                        //return stack pull request
      .ls2ips_pull_data_del_o	(ls2ips_pull_data_del),                               //parameter stack delayed pull data (available one cycle after the pull request)
      .ls2irs_pull_data_del_o	(ls2irs_pull_data_del),                               //return stack delayed pull data (available one cycle after the pull request)
      .ls2ips_push_bsy_o	(ls2ips_push_bsy),                                    //parameter stack push busy indicator
      .ls2irs_push_bsy_o	(ls2irs_push_bsy),                                    //return stack push busy indicator
      .ls2ips_pull_bsy_o	(ls2ips_pull_bsy),                                    //parameter stack pull busy indicator
      .ls2irs_pull_bsy_o	(ls2irs_pull_bsy),                                    //return stack pull busy indicator
      .ls2ips_empty_o		(ls2ips_empty),                                       //parameter stack empty indicator
      .ls2irs_empty_o		(ls2irs_empty),                                       //return stack empty indicator
      .ls2ips_full_o		(ls2ips_full),                                        //parameter stack full indicator
      .ls2irs_full_o		(ls2irs_full),                                        //return stack full indicator
      //RAM interface
      .ram2ls_rdata_i		(ls2ram_raddr),                                       //read data
      .ls2ram_raddr_o		(ls2ram_raddr),                                       //read address
      .ls2ram_waddr_o		(ls2ram_waddr),                                       //write address
      .ls2ram_wdata_o		(ls2ram_wdata),                                       //write data
      .ls2ram_re_o		(ls2ram_re),                                          //read enable
      .ls2ram_we_o		(ls2ram_we),                                          //write enable
      //Probe signals
      .prb_ps_addr_o		(),                                        //parameter stack address probe
      .prb_rs_addr_o		());                                       //return stack address probe

   //Dual ported RAM
   N1_dpram_256w
   ram
     (//Clock and reset
      .clk_i			(clk_i),                                                //module clock
      //RAM interface		
      ram_raddr_i		(ls2ram_raddr),                                          //read address
      ram_waddr_i		(ls2ram_waddr),                                          //write address
      ram_wdata_i		(ls2ram_wdata),                                          //write data
      ram_re_i			(ls2ram_re),                                             //read enable
      ram_we_i			(ls2ram_we),                                             //write enable
      ram_rdata_o		(ls2ram_raddr));                                         //read data

endmodule // N1_prs
