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
    input  wire                              clk_i,              //module clock
    input  wire                              async_rst_i,        //asynchronous reset
    input  wire                              sync_rst_i,         //synchronous reset

    //Program bus (wishbone)
    output wire                              pbus_cyc_o,         //bus cycle indicator       +-
    output wire                              pbus_stb_o,         //access request            |
    output wire                              pbus_we_o,          //write enable              |
    output wire [15:0]                       pbus_adr_o,         //address bus               |
    output wire [15:0]                       pbus_dat_o,         //write data bus            |
    output wire                              pbus_tga_jmp_dir_o, //direct jump               | initiator
    output wire                              pbus_tga_jmp_ind_o, //indirect jump             | to
    output wire                              pbus_tga_cal_dir_o, //direct call               | target
    output wire                              pbus_tga_cal_ind_o, //indirect call             |
    output wire                              pbus_tga_bra_dir_o, //direct branch             |
    output wire                              pbus_tga_bra_ind_o, //indirect branch           |
    output wire                              pbus_tga_dat_dir_o, //direct data access        |
    output wire                              pbus_tga_dat_ind_o, //indirect data access      +-
    input  wire                              pbus_ack_i,         //bus cycle                 +-
    input  wire                              pbus_err_i,         //error indicator           | target
    input  wire                              pbus_rty_i,         //retry request             | to
    input  wire                              pbus_stall_i,       //access delay              | initiator
    input  wire [15:0]                       pbus_dat_i,         //read data bus             +-

    //Stack bus (wishbone)
    output wire                              sbus_cyc_o,         //bus cycle indicator       +-
    output wire                              sbus_stb_o,         //access request            |
    output wire                              sbus_we_o,          //write enable              | initiator
    output wire [`SP_WIDTH-1:0]              sbus_adr_o,         //address bus               | to
    output wire [15:0]                       sbus_dat_o,         //write data bus            | target
    output wire                              sbus_tga_ps_o,      //parameter stack access    |
    output wire                              sbus_tga_rs_o,      //return stack access       +-
    input  wire                              sbus_ack_i,         //bus cycle acknowledge     +-
    input  wire                              sbus_err_i,         //error indicator           | target
    input  wire                              sbus_rty_i,         //retry request             | to
    input  wire                              sbus_stall_i,       //access delay              | initiator
    input  wire [15:0]                       sbus_dat_i,         //read data bus             +-

    //Interrupt interface
    output wire                              irq_ack_o,          //interrupt acknowledge
    input wire [15:0]                        irq_req_adr_i,      //requested interrupt vector

    //Probe signals
    //Exception aggregator
    //Flow Controller
    output wire [3:0]                        prb_fc_state_o,     //FSM state
    //Intermediate parameter stack
    output wire [`IPS_DEPTH-1:0]             prb_ips_tags_o,     //intermediate stack cell tags
    output wire [(`IPS_DEPTH*16)-1:0]        prb_ips_cells_o,    //intermediate stack cells
    output wire [`SP_WIDTH-1:0]              prb_ips_lsp_o,      //lower stack pointer
    output wire [1:0]                        prb_ips_state_o,    //FSM state
    //Intermediate return stack
    output wire [`IRS_DEPTH-1:0]             prb_irs_tags_o,     //intermediate stack cell tags
    output wire [(`IRS_DEPTH*16)-1:0]        prb_irs_cells_o,    //intermediate stack cells
    output wire [`SP_WIDTH-1:0]              prb_irs_lsp_o,      //lower stack pointer
    output wire [1:0]                        prb_irs_state_o,    //FSM state
    //Stack bus arbiter
    output wire [1:0]                        prb_sarb_state_o,   //FSM state
    //Upper stacks
    output wire [3:0]                        prb_us_ps_tags_o,   //intermediate stack cell tags
    output wire [(4*16)-1:0]                 prb_us_ps_cells_o,  //intermediate stack cells
    output wire                              prb_us_rs_tags_o,   //intermediate stack cell tags
    output wire [15:0]                       prb_us_rs_cells_o,  //intermediate stack cells
    output wire [1:0]                        prb_us_state_o);    //FSM state

   //Instantiation
   //=============
   N1
     #(.SP_WIDTH  (`SP_WIDTH),                                   //width of a stack pointer
       .IPS_DEPTH (`IPS_DEPTH),                                  //depth of the intermediate parameter stack
       .IRS_DEPTH (`IRS_DEPTH))                                  //depth of the intermediate return stack
   DUT
     (//Clock and reset
      .clk_i                    (clk_i),                         //module clock
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset

      //Program bus (wishbone)
      .pbus_cyc_o               (pbus_cyc_o),                    //bus cycle indicator       +-
      .pbus_stb_o               (pbus_stb_o),                    //access request            |
      .pbus_we_o                (pbus_we_o),                     //write enable              |
      .pbus_adr_o               (pbus_adr_o),                    //address bus               |
      .pbus_dat_o               (pbus_dat_o),                    //write data bus            |
      .pbus_tga_jmp_dir_o       (pbus_tga_jmp_dir_o),            //direct jump               | initiator
      .pbus_tga_jmp_ind_o       (pbus_tga_jmp_ind_o),            //indirect jump             | to
      .pbus_tga_cal_dir_o       (pbus_tga_cal_dir_o),            //direct call               | target
      .pbus_tga_cal_ind_o       (pbus_tga_cal_ind_o),            //indirect call             |
      .pbus_tga_bra_dir_o       (pbus_tga_bra_dir_o),            //direct branch             |
      .pbus_tga_bra_ind_o       (pbus_tga_bra_ind_o),            //indirect branch           |
      .pbus_tga_dat_dir_o       (pbus_tga_dat_dir_o),            //direct data access        |
      .pbus_tga_dat_ind_o       (pbus_tga_dat_ind_o),            //indirect data access      +-
      .pbus_ack_i               (pbus_ack_i),                    //bus cycle                 +-
      .pbus_err_i               (pbus_err_i),                    //error indicator           | target
      .pbus_rty_i               (pbus_rty_i),                    //retry request             | to
      .pbus_stall_i             (pbus_stall_i),                  //access delay              | initiator
      .pbus_dat_i               (pbus_dat_i),                    //read data bus             +-

      //Stack bus (wishbone)
      .sbus_cyc_o               (sbus_cyc_o),                    //bus cycle indicator       +-
      .sbus_stb_o               (sbus_stb_o),                    //access request            |
      .sbus_we_o                (sbus_we_o),                     //write enable              | initiator
      .sbus_adr_o               (sbus_adr_o),                    //address bus               | to
      .sbus_dat_o               (sbus_dat_o),                    //write data bus            | target
      .sbus_tga_ps_o            (sbus_tga_ps_o),                 //parameter stack access    |
      .sbus_tga_rs_o            (sbus_tga_rs_o),                 //return stack access       +-
      .sbus_ack_i               (sbus_ack_i),                    //bus cycle acknowledge     +-
      .sbus_err_i               (sbus_err_i),                    //error indicator           | target
      .sbus_rty_i               (sbus_rty_i),                    //retry request             | to
      .sbus_stall_i             (sbus_stall_i),                  //access delay              | initiator
      .sbus_dat_i               (sbus_dat_i),                    //read data bus             +-

      //Interrupt interface
      .irq_ack_o                (irq_ack_o),                     //interrupt acknowledge
      .irq_req_adr_i            (irq_req_adr_i),                 //requested interrupt vector

      //Probe signals
      //Exception aggregator
      //Flow Controller
      .prb_fc_state_o           (prb_fc_state_o),                //FSM state
      //Intermediate parameter stack
      .prb_ips_tags_o           (prb_ips_tags_o),                //intermediate stack cell tags
      .prb_ips_cells_o          (prb_ips_cells_o),               //intermediate stack cells
      .prb_ips_lsp_o            (prb_ips_lsp_o),                 //lower stack pointer
      .prb_ips_state_o          (prb_ips_state_o),               //FSM state
      //Intermediate return stack
      .prb_irs_tags_o           (prb_irs_tags_o),                //intermediate stack cell tags
      .prb_irs_cells_o          (prb_irs_cells_o),               //intermediate stack cells
      .prb_irs_lsp_o            (prb_irs_lsp_o),                 //lower stack pointer
      .prb_irs_state_o          (prb_irs_state_o),               //FSM state
      //Stack bus arbiter
      .prb_sarb_state_o         (prb_sarb_state_o),              //FSM state
      //Upper stacks
      .prb_us_ps_tags_o         (prb_us_ps_tags_o),              //intermediate stack cell tags
      .prb_us_ps_cells_o        (prb_us_ps_cells_o),             //intermediate stack cells
      .prb_us_rs_tags_o         (prb_us_rs_tags_o),              //intermediate stack cell tags
      .prb_us_rs_cells_o        (prb_us_rs_cells_o),             //intermediate stack cells
      .prb_us_state_o           (prb_us_state_o));               //FSM state

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
