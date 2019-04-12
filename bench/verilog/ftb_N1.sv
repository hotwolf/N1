//###############################################################################
//# N1 - Formal Testbench - Top Level                                           #
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
//#    This is the the formal testbench for the top level block of the N1       #
//#    processor.                                                               #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 11, 2019                                                         #
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
`define SP_WIDTH       12
`endif
`ifndef IPS_DEPTH
`define IPS_DEPTH       8
`endif
`ifndef IRS_DEPTH
`define IRS_DEPTH       8
`endif

module ftb_N1
   (//Clock and reset
    input  wire                              clk_i,                 //module clock
    input  wire                              async_rst_i,           //asynchronous reset
    input  wire                              sync_rst_i,            //synchronous reset

    //Program bus (wishbone)
    output wire                              pbus_cyc_o,            //bus cycle indicator       +-
    output wire                              pbus_stb_o,            //access request            |
    output wire                              pbus_we_o,             //write enable              |
    output wire [15:0]                       pbus_adr_o,            //address bus               |
    output wire [15:0]                       pbus_dat_o,            //write data bus            | initiator
    output wire                              pbus_tga_cof_jmp_o,    //COF jump                  | to
    output wire                              pbus_tga_cof_cal_o,    //COF call                  | target
    output wire                              pbus_tga_cof_bra_o,    //COF conditional branch    |
    output wire                              pbus_tga_cof_eow_o,    //COF return from call      |
    output wire                              pbus_tga_dat_o,        //data access               |
    input  wire                              pbus_ack_i,            //bus cycle                 +-
    input  wire                              pbus_err_i,            //error indicator           | target to
    input  wire                              pbus_stall_i,          //access delay              | initiator
    input  wire [15:0]                       pbus_dat_i,            //read data bus             +-

    //Stack bus (wishbone)
    output wire                              sbus_cyc_o,            //bus cycle indicator       +-
    output wire                              sbus_stb_o,            //access request            |
    output wire                              sbus_we_o,             //write enable              | initiator
    output wire [`SP_WIDTH-1:0]              sbus_adr_o,            //address bus               | to
    output wire [15:0]                       sbus_dat_o,            //write data bus            | target
    output wire                              sbus_tga_ps_o,         //parameter stack access    |
    output wire                              sbus_tga_rs_o,         //return stack access       +-
    input  wire                              sbus_ack_i,            //bus cycle acknowledge     +-
    input  wire                              sbus_err_i,            //error indicator           | target
    input  wire                              sbus_rty_i,            //retry request             | to
    input  wire                              sbus_stall_i,          //access delay              | initiator
    input  wire [15:0]                       sbus_dat_i,            //read data bus             +-

    //Interrupt interface
    output wire                              irq_ack_o,             //interrupt acknowledge
    input  wire [15:0]                       irq_req_i,             //requested interrupt vector

    //Probe signals
    //EXCPT - Exception aggregator
    output wire [2:0]                        prb_excpt_o,           //exception tracker
    output wire                              prb_excpt_en_o,        //exception enable
    output wire                              prb_irq_en_o,          //interrupt enable
    //FC - Flow control
    output wire [2:0]                        prb_fc_state_o,        //state variable
    output wire                              prb_fc_pbus_acc_o,     //ongoing bus access
    //IR - Instruction register
    output wire [15:0]                       prb_ir_o,              //current instruction register
    output wire [15:0]                       prb_ir_stash_o,        //stashed instruction register
    //Probe signals
    output wire [2:0]                        prb_state_task_o,      //current state
    output wire [1:0]                        prb_state_sbus_o,      //current state
    output wire [15:0]                       prb_rs0_o,             //current RS0
    output wire [15:0]                       prb_ps0_o,             //current PS0
    output wire [15:0]                       prb_ps1_o,             //current PS1
    output wire [15:0]                       prb_ps2_o,             //current PS2
    output wire [15:0]                       prb_ps3_o,             //current PS3
    output wire                              prb_rs0_tag_o,         //current RS0 tag
    output wire                              prb_ps0_tag_o,         //current PS0 tag
    output wire                              prb_ps1_tag_o,         //current PS1 tag
    output wire                              prb_ps2_tag_o,         //current PS2 tag
    output wire                              prb_ps3_tag_o,         //current PS3 tag
    output wire [(16*`IPS_DEPTH)-1:0]        prb_ips_o,             //current IPS
    output wire [`IPS_DEPTH-1:0]             prb_ips_tags_o,        //current IPS
    output wire [(16*`IRS_DEPTH)-1:0]        prb_irs_o,             //current IRS
    output wire [`IRS_DEPTH-1:0]             prb_irs_tags_o);       //current IRS

   //Instantiation
   //=============
   N1
     #(.SP_WIDTH  (`SP_WIDTH),                                      //width of a stack pointer
       .IPS_DEPTH (`IPS_DEPTH),                                     //depth of the intermediate parameter stack
       .IRS_DEPTH (`IRS_DEPTH))                                     //depth of the intermediate return stack
   DUT
     (//Clock and reset
      .clk_i                    (clk_i),                            //module clock
      .async_rst_i              (async_rst_i),                      //asynchronous reset
      .sync_rst_i               (sync_rst_i),                       //synchronous reset

      //Program bus (wishbone)
      .pbus_cyc_o               (pbus_cyc_o),                       //bus cycle indicator       +-
      .pbus_stb_o               (pbus_stb_o),                       //access request            |
      .pbus_we_o                (pbus_we_o),                        //write enable              |
      .pbus_adr_o               (pbus_adr_o),                       //address bus               |
      .pbus_dat_o               (pbus_dat_o),                       //write data bus            | initiator
      .pbus_tga_cof_jmp_o       (pbus_tga_cof_jmp_o),               //COF jump                  | to
      .pbus_tga_cof_cal_o       (pbus_tga_cof_cal_o),               //COF call                  | target
      .pbus_tga_cof_bra_o       (pbus_tga_cof_bra_o),               //COF conditional branch    |
      .pbus_tga_cof_eow_o       (pbus_tga_cof_eow_o),               //COF return from call      |
      .pbus_tga_dat_o           (pbus_tga_dat_o),                   //data access               |
      .pbus_ack_i               (pbus_ack_i),                       //bus cycle                 +-
      .pbus_err_i               (pbus_err_i),                       //error indicator           | target to
      .pbus_stall_i             (pbus_stall_i),                     //access delay              | initiator
      .pbus_dat_i               (pbus_dat_i),                       //read data bus             +-

      //Stack bus (wishbone)
      .sbus_cyc_o               (sbus_cyc_o),                       //bus cycle indicator       +-
      .sbus_stb_o               (sbus_stb_o),                       //access request            |
      .sbus_we_o                (sbus_we_o),                        //write enable              | initiator
      .sbus_adr_o               (sbus_adr_o),                       //address bus               | to
      .sbus_dat_o               (sbus_dat_o),                       //write data bus            | target
      .sbus_tga_ps_o            (sbus_tga_ps_o),                    //parameter stack access    |
      .sbus_tga_rs_o            (sbus_tga_rs_o),                    //return stack access       +-
      .sbus_ack_i               (sbus_ack_i),                       //bus cycle acknowledge     +-
      .sbus_stall_i             (sbus_stall_i),                     //access delay              | target to initiator
      .sbus_dat_i               (sbus_dat_i),                       //read data bus             +-

      //Interrupt interface
      .irq_ack_o                (irq_ack_o),                        //interrupt acknowledge
      .irq_req_i                (irq_req_i),                        //requested interrupt vector

      //Probe signals
      //EXCPT - Exception aggregator
      .prb_excpt_o              (prb_excpt_o),                      //exception tracker
      .prb_excpt_en_o           (prb_excpt_en_o),                   //exception enable
      .prb_irq_en_o             (prb_irq_en_o),                     //interrupt enable
      //FC - Flow control
      .prb_fc_state_o           (prb_fc_state_o),                   //state variable
      .prb_fc_pbus_acc_o        (prb_fc_pbus_acc_o),                //ongoing bus access
      //IR - Instruction register
      .prb_ir_o                 (prb_ir_o),                         //current instruction register
      .prb_ir_stash_o           (prb_ir_stash_o),                   //stashed instruction register
      //Probe signals
      .prb_state_task_o         (prb_state_task_o),                 //current state
      .prb_state_sbus_o         (prb_state_sbus_o),                 //current state
      .prb_rs0_o                (prb_rs0_o),                        //current RS0
      .prb_ps0_o                (prb_ps0_o),                        //current PS0
      .prb_ps1_o                (prb_ps1_o),                        //current PS1
      .prb_ps2_o                (prb_ps2_o),                        //current PS2
      .prb_ps3_o                (prb_ps3_o),                        //current PS3
      .prb_rs0_tag_o            (prb_rs0_tag_o),                    //current RS0 tag
      .prb_ps0_tag_o            (prb_ps0_tag_o),                    //current PS0 tag
      .prb_ps1_tag_o            (prb_ps1_tag_o),                    //current PS1 tag
      .prb_ps2_tag_o            (prb_ps2_tag_o),                    //current PS2 tag
      .prb_ps3_tag_o            (prb_ps3_tag_o),                    //current PS3 tag
      .prb_ips_o                (prb_ips_o),                        //current IPS
      .prb_ips_tags_o           (prb_ips_tags_o),                   //current IPS
      .prb_irs_o                (prb_irs_o),                        //current IRS
      .prb_irs_tags_o           (prb_irs_tags_o));                  //current IRS

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //===================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                    (clk_i),                         //module clock
      .sync_i                   (1'b1),                          //clock enable
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset
      .gated_clk_o              ());                             //gated clock

`endif //  `ifdef FORMAL

endmodule // ftb_N1
