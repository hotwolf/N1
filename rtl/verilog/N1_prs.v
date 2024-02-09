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
//#   February, 2024                                                            #
//#      - New implementation                                                   #
//###############################################################################
`default_nettype none

module N1_prs
  #(parameter   STACK_DEPTH_WIDTH =       9,                                        //width of stack depth registers
    parameter   IPS_DEPTH         =       4,                                        //depth of the intermediate parameter stack
    parameter   IRS_DEPTH         =       2,                                        //depth of the intermediate return stack
    parameter   LS_AWIDTH         =       8)                                        //lower stack address width
   (//Clock and reset
    input wire                               clk_i,                                 //module clock
    input wire                               async_rst_i,                           //asynchronous reset
    input wire                               sync_rst_i,                            //synchronous reset

    //Stack outputs
    output wire [15:0]                       prs_ps0_o,                             //PS0
    output wire [15:0]                       prs_ps1_o,                             //PS1
    output wire [15:0]                       prs_rs0_o,                             //RS0

    //IR interface
    input  wire [15:0]                       ir2prs_ir_ps0_next_i,                  //IR output (literal value)
    input  wire                              ir2prs_ps0_required_i,                 //at least one cell on the PS required
    input  wire                              ir2prs_ps1_required_i,                 //at least two cells on the PS required
    input  wire                              ir2prs_rs0_required_i,                 //at least one cell on the RS rwquired
    input  wire                              ir2prs_ir_2_ps0_i,                     //IR output     -> PS0
    input  wire                              ir2prs_psd_2_ps0_i,                    //PS depth      -> PS0
    input  wire                              ir2prs_rsd_2_ps0_i,                    //RS depth      -> PS0
    input  wire                              ir2prs_excpt_2_ps0_i,                  //EXCPT output  -> PS0
    input  wire                              ir2prs_biu_2_ps0_i,                    //BI output     -> PS0
    input  wire                              ir2prs_alu_2_ps0_i,                    //ALU output    -> PS0
    input  wire                              ir2prs_alu_2_ps1_i,                    //ALU output    -> PS1
    input  wire                              ir2prs_ps0_2_rsd_i,                    //PS0           -> RS depth (clears RS)
    input  wire                              ir2prs_ps0_2_psd_i,                    //PS0           -> PS depth (clears PS)
    input  wire                              ir2prs_agu_2_rs0_i,                    //AGU output    -> RS0
    input  wire                              ir2prs_ips_2_ps3_i,                    //IPS           -> PS3
    input  wire                              ir2prs_ps3_2_ips_i,                    //PS3           -> IPS
    input  wire                              ir2prs_ps3_2_ps2_i,                    //PS3           -> PS2
    input  wire                              ir2prs_ps2_2_ps3_i,                    //PS2           -> PS3
    input  wire                              ir2prs_ps2_2_ps1_i,                    //PS2           -> PS1
    input  wire                              ir2prs_ps1_2_ps2_i,                    //PS1           -> PS2
    input  wire                              ir2prs_ps1_2_ps0_i,                    //PS1           -> PS0
    input  wire                              ir2prs_ps0_2_ps1_i,                    //PS0           -> PS1
    input  wire                              ir2prs_ps2_2_ps0_i,                    //PS2           -> PS0 (ROT extension)
    input  wire                              ir2prs_ps0_2_ps2_i,                    //PS0           -> PS2 (ROT extension)
    input  wire                              ir2prs_ps0_2_rs0_i,                    //PS0           -> RS0
    input  wire                              ir2prs_rs0_2_ps0_i,                    //RS0           -> PS0
    input  wire                              ir2prs_rs0_2_irs_i,                    //RS0           -> IRS
    input  wire                              ir2prs_irs_2_rs0_i,                    //IRS           -> RS0
    output wire                              prs2ir_bsy_o,                          //PS and RS stalled

    //ALU interface
    input wire [15:0]                        alu2prs_ps0_next_i,                    //ALU result (lower word)
    input wire [15:0]                        alu2prs_ps1_next_i,                    //ALU result (upper word)

    //AGU interface
    input wire [15:0]                        agu2prs_rs0_next_i,                    //PC

    //EXCPT interface
    output wire                              prs2excpt_psof_o,                      //parameter stack overflow
    output wire                              prs2excpt_psuf_o,                      //parameter stack underflow
    output wire                              prs2excpt_rsof_o,                      //return stack overflow
    output wire                              prs2excpt_rsuf_o,                      //return stack underflow
    input  wire [15:0]                       excpt2prs_ps0_next_i,                  //throw code

    //Bus interface
    input  wire [15:0]                       bi2prs_ps0_next_i,                     //read data

    //Probe signals
    output wire [STACK_DEPTH_WIDTH-1:0]      prb_us_rsd_o,                          //RS depth
    output wire [STACK_DEPTH_WIDTH-1:0]      prb_us_psd_o,                          //PS depth
    output wire [15:0]                       prb_us_r0_o,                           //URS R0
    output wire [15:0]                       prb_us_p0_o,                           //UPS P0
    output wire [15:0]                       prb_us_p1_o,                           //UPS P1
    output wire [15:0]                       prb_us_p2_o,                           //UPS P2
    output wire [15:0]                       prb_us_p3_o,                           //URS R0
    output wire [(16*IPS_DEPTH)-1:0]         prb_ips_cells_o,                       //current IS cells
    output wire [IPS_DEPTH-1:0]              prb_ips_tags_o,                        //current IS tags
    output wire                              prb_ips_state_o,                       //current state
    output wire [(16*IRS_DEPTH)-1:0]         prb_irs_cells_o,                       //current IS cells
    output wire [IRS_DEPTH-1:0]              prb_irs_tags_o,                        //current IS tags
    output wire                              prb_irs_state_o,                       //current state
    output wire [LS_AWIDTH-1:0]              prb_lps_addr_o,                        //parameter stack address probe
    output wire [LS_AWIDTH-1:0]              prb_lrs_addr_o);                       //return stack address probe

  //Internal signals
   //-----------------
   //Stack clear requests
   wire                                      us_ps_clr;                             //PS soft reset
   wire                                      us_rs_clr;                             //RS soft reset

   //Upper stack to intermediate parameter stack
   wire [15:0]                               ips2us_pull_data;                      //IPS pull data
   wire                                      ips2us_push_bsy;                       //IPS push busy indicator
   wire                                      ips2us_pull_bsy;                       //IPS pull busy indicator
   wire                                      ips2us_empty;                          //IPS empty indicator
   wire                                      ips2us_full;                           //IPS overflow indicator
   wire [15:0]                               us2ips_push_data;                      //IPS push data
   wire                                      us2ips_push;                           //IPS push request
   wire                                      us2ips_pull;                           //IPS pull request

   //Upper stack to intermediate return stack
   wire [15:0]                               irs2us_pull_data;                      //IRS pull data
   wire                                      irs2us_push_bsy;                       //IRS push busy indicator
   wire                                      irs2us_pull_bsy;                       //IRS pull busy indicator
   wire                                      irs2us_empty;                          //IRS empty indicator
   wire                                      irs2us_full;                           //IRS overflow indicator
   wire [15:0]                               us2irs_push_data;                      //IRS push data
   wire                                      us2irs_push;                           //IRS push request
   wire                                      us2irs_pull;                           //IRS pull request

   //Intermediate parameter stack to lower stack
   wire [15:0]                               ips2ls_push_data;                      //push data
   wire                                      ips2ls_push;                           //push request
   wire                                      ips2ls_pull;                           //pull request
   wire [15:0]                               ls2ips_pull_data_del;                  //delayed pull data (available one cycle after the pull request)
   wire                                      ls2ips_push_bsy;                       //push busy indicator
   wire                                      ls2ips_pull_bsy;                       //pull busy indicator
   wire                                      ls2ips_empty;                          //empty indicator
   wire                                      ls2ips_full;                           //overflow indicator

   //Intermediate return stack to lower stack
   wire [15:0]                               irs2ls_push_data;                      //push data
   wire                                      irs2ls_push;                           //push request
   wire                                      irs2ls_pull;                           //pull request
   wire [15:0]                               ls2irs_pull_data_del;                  //delayed pull data (available one cycle after the pull request)
   wire                                      ls2irs_push_bsy;                       //push busy indicator
   wire                                      ls2irs_pull_bsy;                       //pull busy indicator
   wire                                      ls2irs_empty;                          //empty indicator
   wire                                      ls2irs_full;                           //overflow indicator

   //Lower stack to DPRAM
   wire [LS_AWIDTH-1:0]                      ls2ram_raddr;                          //read address
   wire [LS_AWIDTH-1:0]                      ls2ram_waddr;                          //write address
   wire [15:0]                               ls2ram_wdata;                          //write data
   wire                                      ls2ram_re;                             //read enable
   wire                                      ls2ram_we;                             //write enable
   wire [15:0]                               ram2ls_rdata;                          //read data

   //Upper Stack
   //-----------
   N1_us
     #(.STACK_DEPTH_WIDTH(STACK_DEPTH_WIDTH))                                       //width of stack depth registers
   us
   (//Clock and reset
    .clk_i                      (clk_i),                                            //module clock
    .async_rst_i                (async_rst_i),                                      //asynchronous reset
    .sync_rst_i                 (sync_rst_i),                                       //synchronous reset

    //Stack outputs
    .us_ps0_o                   (prs_ps0_o),                                        ///PS0
    .us_ps1_o                   (prs_ps1_o),                                        ///PS1
    .us_rs0_o                   (prs_rs0_o),                                        ///RS0

    //Stack clear requests
    .us_ps_clr_o                (us_ps_clr),                                        //PS soft reset
    .us_rs_clr_o                (us_rs_clr),                                        //PS soft reset

    //IR interface
    .ir2us_ir_ps0_next_i        (ir2prs_ir_ps0_next_i),                             //IR output (literal value)
    .ir2us_ps0_required_i       (ir2prs_ps0_required_i),                            //at least one cell on the PS required
    .ir2us_ps1_required_i       (ir2prs_ps1_required_i),                            //at least two cells on the PS required
    .ir2us_rs0_required_i       (ir2prs_rs0_required_i),                            //at least one cell on the RS rwquired
    .ir2us_ir_2_ps0_i           (ir2prs_ir_2_ps0_i),                                //IR output     -> PS0
    .ir2us_psd_2_ps0_i          (ir2prs_psd_2_ps0_i),                               //PS depth      -> PS0
    .ir2us_rsd_2_ps0_i          (ir2prs_rsd_2_ps0_i),                               //RS depth      -> PS0
    .ir2us_excpt_2_ps0_i        (ir2prs_excpt_2_ps0_i),                             //EXCPT output  -> PS0
    .ir2us_biu_2_ps0_i          (ir2prs_biu_2_ps0_i),                               //BI output     -> PS0
    .ir2us_alu_2_ps0_i          (ir2prs_alu_2_ps0_i),                               //ALU output    -> PS0
    .ir2us_alu_2_ps1_i          (ir2prs_alu_2_ps1_i),                               //ALU output    -> PS1
    .ir2us_ps0_2_rsd_i          (ir2prs_ps0_2_rsd_i),                               //PS0           -> RS depth (clears RS)
    .ir2us_ps0_2_psd_i          (ir2prs_ps0_2_psd_i),                               //PS0           -> PS depth (clears PS)
    .ir2us_agu_2_rs0_i          (ir2prs_agu_2_rs0_i),                               //AGU output    -> RS0
    .ir2us_ips_2_ps3_i          (ir2prs_ips_2_ps3_i),                               //IPS           -> PS3
    .ir2us_ps3_2_ips_i          (ir2prs_ps3_2_ips_i),                               //PS3           -> IPS
    .ir2us_ps3_2_ps2_i          (ir2prs_ps3_2_ps2_i),                               //PS3           -> PS2
    .ir2us_ps2_2_ps3_i          (ir2prs_ps2_2_ps3_i),                               //PS2           -> PS3
    .ir2us_ps2_2_ps1_i          (ir2prs_ps2_2_ps1_i),                               //PS2           -> PS1
    .ir2us_ps1_2_ps2_i          (ir2prs_ps1_2_ps2_i),                               //PS1           -> PS2
    .ir2us_ps1_2_ps0_i          (ir2prs_ps1_2_ps0_i),                               //PS1           -> PS0
    .ir2us_ps0_2_ps1_i          (ir2prs_ps0_2_ps1_i),                               //PS0           -> PS1
    .ir2us_ps2_2_ps0_i          (ir2prs_ps2_2_ps0_i),                               //PS2           -> PS0 (ROT extension)
    .ir2us_ps0_2_ps2_i          (ir2prs_ps0_2_ps2_i),                               //PS0           -> PS2 (ROT extension)
    .ir2us_ps0_2_rs0_i          (ir2prs_ps0_2_rs0_i),                               //PS0           -> RS0
    .ir2us_rs0_2_ps0_i          (ir2prs_rs0_2_ps0_i),                               //RS0           -> PS0
    .ir2us_rs0_2_irs_i          (ir2prs_rs0_2_irs_i),                               //RS0           -> IRS
    .ir2us_irs_2_rs0_i          (ir2prs_irs_2_rs0_i),                               //IRS           -> RS0
    .us2ir_bsy_o                (prs2ir_bsy_o),                                     //PS and RS stalled

    //ALU interface
    .alu2us_ps0_next_i          (alu2prs_ps0_next_i),                               //ALU result (lower word)
    .alu2us_ps1_next_i          (alu2prs_ps1_next_i),                               //ALU result (upper word)

    //AGU interface
    .agu2us_rs0_next_i          (agu2prs_rs0_next_i),                               //PC

    //EXCPT interface
    .us2excpt_psof_o            (prs2excpt_psof_o),                                 //parameter stack overflow
    .us2excpt_psuf_o            (prs2excpt_psuf_o),                                 //parameter stack underflow
    .us2excpt_rsof_o            (prs2excpt_rsof_o),                                 //return stack overflow
    .us2excpt_rsuf_o            (prs2excpt_rsuf_o),                                 //return stack underflow
    .excpt2us_ps0_next_i        (excpt2prs_ps0_next_i),                             //throw code

    //Bus interface
    .bi2us_ps0_next_i           (bi2prs_ps0_next_i),                                //read data

    //IPS interface
    .ips2us_pull_data_i         (ips2us_pull_data),                                 //IPS pull data
    .ips2us_push_bsy_i          (ips2us_push_bsy),                                  //IPS push busy indicator
    .ips2us_pull_bsy_i          (ips2us_pull_bsy),                                  //IPS pull busy indicator
    .ips2us_empty_i             (ips2us_empty),                                     //IPS empty indicator
    .ips2us_full_i              (ips2us_full),                                      //IPS overflow indicator
    .us2ips_push_data_o         (us2ips_push_data),                                 //IPS push data
    .us2ips_push_o              (us2ips_push),                                      //IPS push request
    .us2ips_pull_o              (us2ips_pull),                                      //IPS pull request

    //IRS interface
    .irs2us_pull_data_i         (irs2us_pull_data),                                 //IRS pull data
    .irs2us_push_bsy_i          (irs2us_push_bsy),                                  //IRS push busy indicator
    .irs2us_pull_bsy_i          (irs2us_pull_bsy),                                  //IRS pull busy indicator
    .irs2us_empty_i             (irs2us_empty),                                     //IRS empty indicator
    .irs2us_full_i              (irs2us_full),                                      //IRS overflow indicator
    .us2irs_push_data_o         (us2irs_push_data),                                 //IRS push data
    .us2irs_push_o              (us2irs_push),                                      //IRS push request
    .us2irs_pull_o              (us2irs_pull),                                      //IRS pull request

    //Probe signals
    .prb_us_rsd_o               (prb_us_rsd_o),                                     //RS depth
    .prb_us_psd_o               (prb_us_psd_o),                                     //PS depth
    .prb_us_r0_o                (prb_us_r0_o),                                      //URS R0
    .prb_us_p0_o                (prb_us_p0_o),                                      //UPS P0
    .prb_us_p1_o                (prb_us_p1_o),                                      //UPS P1
    .prb_us_p2_o                (prb_us_p2_o),                                      //UPS P2
    .prb_us_p3_o                (prb_us_p3_o));                                     //URS R0

   //Intermediate Stack
   //------------------
   //Parameter stack
   N1_is
     #(.IS_DEPTH(IPS_DEPTH))                                                        //depth of the IS (must be >=2)
   ips
     (//Clock and reset
      .clk_i                    (clk_i),                                            //module clock
      .async_rst_i              (async_rst_i),                                      //asynchronous reset
      .sync_rst_i               (sync_rst_i),                                       //synchronous reset
      //Soft reset
      .us2is_clr_i              (us_ps_clr),                                        //IS stack reset request
      //Interface to upper stack
      .us2is_push_data_i        (us2ips_push_data),                                 //US push data
      .us2is_push_i             (us2ips_push),                                      //US push request
      .us2is_pull_i             (us2ips_pull),                                      //US pull request
      .is2us_pull_data_o        (ips2us_pull_data),                                 //US pull data
      .is2us_push_bsy_o         (ips2us_push_bsy),                                  //US push busy indicator
      .is2us_pull_bsy_o         (ips2us_pull_bsy),                                  //US pull busy indicator
      .is2us_empty_o            (ips2us_empty),                                     //US empty indicator
      .is2us_full_o             (ips2us_full),                                      //US overflow indicator
      //Interface to lower stack
      .ls2is_pull_data_del_i    (ls2ips_pull_data_del),                             //LS delayed pull data (available one cycle after the pull request)
      .ls2is_push_bsy_i         (ls2ips_push_bsy),                                  //LS push busy indicator
      .ls2is_pull_bsy_i         (ls2ips_pull_bsy),                                  //LS pull busy indicator
      .ls2is_empty_i            (ls2ips_empty),                                     //LS empty indicator
      .ls2is_full_i             (ls2ips_full),                                      //LS overflow indicator
      .is2ls_push_data_o        (ips2ls_push_data),                                 //LS push data
      .is2ls_push_o             (ips2ls_push),                                      //LS push request
      .is2ls_pull_o             (ips2ls_pull),                                      //LS pull request
      //Probe signals
      .prb_is_cells_o           (prb_ips_cells_o),                                  //current IS cells
      .prb_is_tags_o            (prb_ips_tags_o),                                   //current IS tags
      .prb_is_state_o           (prb_ips_state_o));                                 //current state

   //Return stack
   N1_is
     #(.IS_DEPTH(IRS_DEPTH))                                                        //depth of the IS (must be >=2)
   irs
     (//Clock and reset
      .clk_i                    (clk_i),                                            //module clock
      .async_rst_i              (async_rst_i),                                      //asynchronous reset
      .sync_rst_i               (sync_rst_i),                                       //synchronous reset
      //Soft reset
      .us2is_clr_i              (us_rs_clr),                                        //IS stack reset request
      //Interface to upper stack
      .us2is_push_data_i        (us2irs_push_data),                                 //US push data
      .us2is_push_i             (us2irs_push),                                      //US push request
      .us2is_pull_i             (us2irs_pull),                                      //US pull request
      .is2us_pull_data_o        (irs2us_pull_data),                                 //US pull data
      .is2us_push_bsy_o         (irs2us_push_bsy),                                  //US push busy indicator
      .is2us_pull_bsy_o         (irs2us_pull_bsy),                                  //US pull busy indicator
      .is2us_empty_o            (irs2us_empty),                                     //US empty indicator
      .is2us_full_o             (irs2us_full),                                      //US overflow indicator
      //Interface to lower stack
      .ls2is_pull_data_del_i    (ls2irs_pull_data_del),                             //LS delayed pull data (available one cycle after the pull request)
      .ls2is_push_bsy_i         (ls2irs_push_bsy),                                  //LS push busy indicator
      .ls2is_pull_bsy_i         (ls2irs_pull_bsy),                                  //LS pull busy indicator
      .ls2is_empty_i            (ls2irs_empty),                                     //LS empty indicator
      .ls2is_full_i             (ls2irs_full),                                      //LS overflow indicator
      .is2ls_push_data_o        (irs2ls_push_data),                                 //LS push data
      .is2ls_push_o             (irs2ls_push),                                      //LS push request
      .is2ls_pull_o             (irs2ls_pull),                                      //LS pull request
      //Probe signals
      .prb_is_cells_o           (prb_irs_cells_o),                                  //current IS cells
      .prb_is_tags_o            (prb_irs_tags_o),                                   //current IS tags
      .prb_is_state_o           (prb_irs_state_o));                                 //current state

   //Lower Stack
   //-----------
   //LS controller
   N1_ls_1xdpram
     #(.LS_AWIDTH(8)) //RAM address width
   ls
     (//Clock and reset
      .clk_i                    (clk_i),                                            //module clock
      .async_rst_i              (async_rst_i),                                      //asynchronous reset
      .sync_rst_i               (sync_rst_i),                                       //synchronous reset
      //Soft reset
      .us2ls_ps_clr_i           (us_ps_clr),                                        //parameter stack reset request
      .us2ls_rs_clr_i           (us_rs_clr),                                        //return stack reset request
      //Interface to the immediate stack
      .ips2ls_push_data_i       (ips2ls_push_data),                                 //parameter stack push data
      .irs2ls_push_data_i       (irs2ls_push_data),                                 //return stack push data
      .ips2ls_push_i            (ips2ls_push),                                      //parameter stack push request
      .irs2ls_push_i            (irs2ls_push),                                      //return stack push request
      .ips2ls_pull_i            (ips2ls_pull),                                      //parameter stack pull request
      .irs2ls_pull_i            (irs2ls_pull),                                      //return stack pull request
      .ls2ips_pull_data_del_o   (ls2ips_pull_data_del),                             //parameter stack delayed pull data (available one cycle after the pull request)
      .ls2irs_pull_data_del_o   (ls2irs_pull_data_del),                             //return stack delayed pull data (available one cycle after the pull request)
      .ls2ips_push_bsy_o        (ls2ips_push_bsy),                                  //parameter stack push busy indicator
      .ls2irs_push_bsy_o        (ls2irs_push_bsy),                                  //return stack push busy indicator
      .ls2ips_pull_bsy_o        (ls2ips_pull_bsy),                                  //parameter stack pull busy indicator
      .ls2irs_pull_bsy_o        (ls2irs_pull_bsy),                                  //return stack pull busy indicator
      .ls2ips_empty_o           (ls2ips_empty),                                     //parameter stack empty indicator
      .ls2irs_empty_o           (ls2irs_empty),                                     //return stack empty indicator
      .ls2ips_full_o            (ls2ips_full),                                      //parameter stack full indicator
      .ls2irs_full_o            (ls2irs_full),                                      //return stack full indicator
      //RAM interface
      .ram2ls_rdata_i           (ram2ls_rdata),                                     //read data
      .ls2ram_raddr_o           (ls2ram_raddr),                                     //read address
      .ls2ram_waddr_o           (ls2ram_waddr),                                     //write address
      .ls2ram_wdata_o           (ls2ram_wdata),                                     //write data
      .ls2ram_re_o              (ls2ram_re),                                        //read enable
      .ls2ram_we_o              (ls2ram_we),                                        //write enable
      //Probe signals
      .prb_lps_addr_o           (prb_lps_addr_o),                                   //parameter stack address probe
      .prb_lrs_addr_o           (prb_lrs_addr_o));                                  //return stack address probe

   //Dual ported RAM
   N1_dpram_256w
   ram
     (//Clock and reset
      .clk_i                    (clk_i),                                            //module clock
      //RAM interface
      .ram_raddr_i              (ls2ram_raddr),                                     //read address
      .ram_waddr_i              (ls2ram_waddr),                                     //write address
      .ram_wdata_i              (ls2ram_wdata),                                     //write data
      .ram_re_i                 (ls2ram_re),                                        //read enable
      .ram_we_i                 (ls2ram_we),                                        //write enable
      .ram_rdata_o              (ram2ls_rdata));                                    //read data

   //Assertions
   //----------
`ifdef FORMAL

`endif //  `ifdef FORMAL
  
endmodule // N1_prs
