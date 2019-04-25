//###############################################################################
//# N1 - Formal Testbench - Parameter and Return Stack                          #
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
//#    This is the the formal testbench for parameter and return stack.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   March 25, 2019                                                            #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

//DUT configuration
//=================
//Default configuration
//---------------------
`ifdef CONF_DEFAULT
`endif

//Fall back
//---------
`ifndef SP_WIDTH
`define SP_WIDTH  12
`endif
`ifndef IPS_DEPTH
`define IPS_DEPTH  8
`endif
`ifndef IRS_DEPTH
`define IRS_DEPTH  8
`endif

module ftb_N1_prs

   (//Clock and reset
    input wire                               clk_i,                                //module clock
    input wire                               async_rst_i,                          //asynchronous reset
    input wire                               sync_rst_i,                           //synchronous reset

    //Program bus (wishbone)
    output wire [15:0]                       pbus_dat_o,                           //write data bus
    input  wire [15:0]                       pbus_dat_i,                           //read data bus

    //Stack bus (wishbone)
    output wire                              sbus_cyc_o,                           //bus cycle indicator       +-
    output wire                              sbus_stb_o,                           //access request            | initiator
    output wire                              sbus_we_o,                            //write enable              | to
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
    input  wire [`SP_WIDTH-1:0]              dsp2prs_psp_i,                        //parameter stack pointer (AGU output)
    input  wire [`SP_WIDTH-1:0]              dsp2prs_rsp_i,                        //return stack pointer (AGU output)

    //EXCPT interface
    output wire                              prs2excpt_psuf_o,                     //parameter stack underflow
    output wire                              prs2excpt_rsuf_o,                     //return stack underflow
    input  wire [15:0]                       excpt2prs_tc_i,                       //throw code

    //FC interface
    output wire                              prs2fc_hold_o,                        //stacks not ready
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
    input  wire                              ir2prs_dat2ps0_i,                     //read data   -> PS0
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
    output wire                              prs2sagu_hold_o,                      //maintain stack pointers
    output wire                              prs2sagu_psp_rst_o,                   //reset PSP
    output wire                              prs2sagu_rsp_rst_o,                   //reset RSP
    output wire                              prs2sagu_stack_sel_o,                 //1:RS, 0:PS
    output wire                              prs2sagu_push_o,                      //increment stack pointer
    output wire                              prs2sagu_pull_o,                      //decrement stack pointer
    output wire                              prs2sagu_load_o,                      //load stack pointer
    output wire [`SP_WIDTH-1:0]              prs2sagu_psp_load_val_o,              //parameter stack load value
    output wire [`SP_WIDTH-1:0]              prs2sagu_rsp_load_val_o,              //return stack load value

    //Probe signals
    output wire [2:0]                        prb_state_task_o,                     //current FSM task
    output wire [1:0]                        prb_state_sbus_o,                     //current stack bus state
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
    output wire [(16*`IPS_DEPTH)-1:0]        prb_ips_o,                            //current IPS
    output wire [`IPS_DEPTH-1:0]             prb_ips_tags_o,                       //current IPS
    output wire [(16*`IRS_DEPTH)-1:0]        prb_irs_o,                            //current IRS
    output wire [`IRS_DEPTH-1:0]             prb_irs_tags_o);                      //current IRS

   //Instantiation
   //=============
   N1_prs
     #(.SP_WIDTH  (`SP_WIDTH),                                                      //width of the stack pointer
       .IPS_DEPTH (`IPS_DEPTH),                                                     //depth of the intermediate parameter stack
       .IRS_DEPTH (`IRS_DEPTH))                                                    //depth of the intermediate return stack
   DUT
   (//Clock and reset
    .clk_i                      (clk_i),                                           //module clock
    .async_rst_i                (async_rst_i),                                     //asynchronous reset
    .sync_rst_i                 (sync_rst_i),                                      //synchronous reset

    //Program bus (wishbone)
    .pbus_dat_o                 (pbus_dat_o),                                      //write data bus
    .pbus_dat_i                 (pbus_dat_i),                                      //read data bus

    //Stack bus (wishbone)
    .sbus_cyc_o                 (sbus_cyc_o),                                      //bus cycle indicator       +-
    .sbus_stb_o                 (sbus_stb_o),                                      //access request            | initiator
    .sbus_we_o                  (sbus_we_o),                                       //write enable              | to
    .sbus_dat_o                 (sbus_dat_o),                                      //write data bus            | target
    .sbus_ack_i                 (sbus_ack_i),                                      //bus cycle acknowledge     +-
    .sbus_stall_i               (sbus_stall_i),                                    //access delay              | initiator to initiator
    .sbus_dat_i                 (sbus_dat_i),                                      //read data bus             +-

    //Interrupt interface
    .irq_req_i                  (irq_req_i),                                       //requested interrupt vector

    //Internal signals
    //----------------
    //ALU interface
    .prs2alu_ps0_o              (prs2alu_ps0_o),                                   //current PS0 (TOS)
    .prs2alu_ps1_o              (prs2alu_ps1_o),                                   //current PS1 (TOS+1)
    .alu2prs_ps0_next_i         (alu2prs_ps0_next_i),                              //new PS0 (TOS)
    .alu2prs_ps1_next_i         (alu2prs_ps1_next_i),                              //new PS1 (TOS+1)

     //DSP interface
    .dsp2prs_pc_i               (dsp2prs_pc_i),                                    //program counter
    .dsp2prs_psp_i              (dsp2prs_psp_i),                                   //parameter stack pointer
    .dsp2prs_rsp_i              (dsp2prs_rsp_i),                                   //return stack pointer

    //EXCPT interface
    .prs2excpt_psuf_o           (prs2excpt_psuf_o),                                //parameter stack underflow
    .prs2excpt_rsuf_o           (prs2excpt_rsuf_o),                                //return stack underflow
    .excpt2prs_tc_i             (excpt2prs_tc_i),                                  //throw code

    //FC interface
    .prs2fc_hold_o              (prs2fc_hold_o),                                   //stacks not ready
    .prs2fc_ps0_false_o         (prs2fc_ps0_false_o),                              //PS0 is zero
    .fc2prs_hold_i              (fc2prs_hold_i),                                   //hold any state tran
    .fc2prs_dat2ps0_i           (fc2prs_dat2ps0_i),                                //capture read data
    .fc2prs_tc2ps0_i            (fc2prs_tc2ps0_i),                                 //capture throw code
    .fc2prs_isr2ps0_i           (fc2prs_isr2ps0_i),                                //capture ISR

    //IR interface
    .ir2prs_lit_val_i           (ir2prs_lit_val_i),                                //literal value
    .ir2prs_us_tp_i             (ir2prs_us_tp_i),                                  //upper stack transition pattern
    .ir2prs_ips_tp_i            (ir2prs_ips_tp_i),                                 //10:push, 01:pull
    .ir2prs_irs_tp_i            (ir2prs_irs_tp_i),                                 //10:push, 01:pull
    .ir2prs_alu2ps0_i           (ir2prs_alu2ps0_i),                                //ALU output  -> PS0
    .ir2prs_alu2ps1_i           (ir2prs_alu2ps1_i),                                //ALU output  -> PS1
    .ir2prs_lit2ps0_i           (ir2prs_lit2ps0_i),                                //literal     -> PS0
    .ir2prs_pc2rs0_i            (ir2prs_pc2rs0_i),                                 //PC          -> RS0
    .ir2prs_ps_rst_i            (ir2prs_ps_rst_i),                                 //reset parameter stack
    .ir2prs_rs_rst_i            (ir2prs_rs_rst_i),                                 //reset return stack
    .ir2prs_psp_get_i           (ir2prs_psp_get_i),                                //read parameter stack pointer
    .ir2prs_psp_set_i           (ir2prs_psp_set_i),                                //write parameter stack pointer
    .ir2prs_rsp_get_i           (ir2prs_rsp_get_i),                                //read return stack pointer
    .ir2prs_rsp_set_i           (ir2prs_rsp_set_i),                                //write return stack pointer

    //PRS interface
    .prs2pagu_ps0_o             (prs2pagu_ps0_o),                                  //PS0
    .prs2pagu_rs0_o             (prs2pagu_rs0_o),                                  //RS0

    //SAGU interface
    .prs2sagu_hold_o            (prs2sagu_hold_o),                                 //maintain stack pointers
    .prs2sagu_psp_rst_o         (prs2sagu_psp_rst_o),                              //reset PSP
    .prs2sagu_rsp_rst_o         (prs2sagu_rsp_rst_o),                              //reset RSP
    .prs2sagu_stack_sel_o       (prs2sagu_stack_sel_o),                            //1:RS               (), 0:PS
    .prs2sagu_push_o            (prs2sagu_push_o),                                 //increment stack pointer
    .prs2sagu_pull_o            (prs2sagu_pull_o),                                 //decrement stack pointer
    .prs2sagu_load_o            (prs2sagu_load_o),                                 //load stack pointer
    .prs2sagu_psp_load_val_o    (prs2sagu_psp_load_val_o),                         //parameter stack load value
    .prs2sagu_rsp_load_val_o    (prs2sagu_rsp_load_val_o),                         //return stack load value

    //Probe signals
    .prb_state_task_o           (prb_state_task_o),                                //current state
    .prb_state_sbus_o           (prb_state_sbus_o),                                //current state
    .prb_rs0_o                  (prb_rs0_o),                                       //current RS0
    .prb_ps0_o                  (prb_ps0_o),                                       //current PS0
    .prb_ps1_o                  (prb_ps1_o),                                       //current PS1
    .prb_ps2_o                  (prb_ps2_o),                                       //current PS2
    .prb_ps3_o                  (prb_ps3_o),                                       //current PS3
    .prb_rs0_tag_o              (prb_rs0_tag_o),                                   //current RS0 tag
    .prb_ps0_tag_o              (prb_ps0_tag_o),                                   //current PS0 tag
    .prb_ps1_tag_o              (prb_ps1_tag_o),                                   //current PS1 tag
    .prb_ps2_tag_o              (prb_ps2_tag_o),                                   //current PS2 tag
    .prb_ps3_tag_o              (prb_ps3_tag_o),                                   //current PS3 tag
    .prb_ips_o                  (prb_ips_o),                                       //current IPS
    .prb_ips_tags_o             (prb_ips_tags_o),                                  //current IPS
    .prb_irs_o                  (prb_irs_o),                                       //current IRS
    .prb_irs_tags_o             (prb_irs_tags_o));                                 //current IRS

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

`endif //  `ifdef FORMAL

endmodule // ftb_N1_prs
