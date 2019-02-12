//###############################################################################
//# N1 - Formal Testbench - Stack Bus Arbiter                                   #
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
//#    This is the the formal testbench for stack bus arbiter.                  #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 5, 2019                                                           #
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
`define SP_WIDTH     12
`endif

module ftb_N1_sarb
   (//Clock and reset
    input  wire                             clk_i,                 //module clock
    input  wire                             async_rst_i,           //asynchronous reset
    input  wire                             sync_rst_i,            //synchronous reset

    //Merged stack bus (wishbone)
    output wire                             sbus_cyc_o,                //bus cycle indicator       +-
    output wire                             sbus_stb_o,                //access request            |
    output wire                             sbus_we_o,                 //write enable              | initiator
    output wire [`SP_WIDTH-1:0]             sbus_adr_o,                //address bus               | to
    output wire [15:0]                      sbus_dat_o,                //write data bus            | target
    output wire                             sbus_tga_ps_o,             //parameter stack access    |
    output wire                             sbus_tga_rs_o,             //return stack access       +-
    input  wire                             sbus_ack_i,                //bus cycle acknowledge     +-
    input  wire                             sbus_err_i,                //error indicator           | target
    input  wire                             sbus_rty_i,                //retry request             | to
    input  wire                             sbus_stall_i,              //access delay              | initiator
    input  wire [15:0]                      sbus_dat_i,                //read data bus             +-

    //Parameter stack bus (wishbone)
    input  wire                             ips2sarb_cyc_i,            //bus cycle indicator       +-
    input  wire                             ips2sarb_stb_i,            //access request            | initiator
    input  wire                             ips2sarb_we_i,             //write enable              | to
    input  wire [`SP_WIDTH-1:0]             ips2sarb_adr_i,            //address bus               | target
    input  wire [15:0]                      ips2sarb_dat_i,            //write data bus            +-
    output wire                             sarb2ips_ack_o,            //bus cycle acknowledge     +-
    output wire                             sarb2ips_err_o,            //error indicator           | target
    output wire                             sarb2ips_rty_o,            //retry request             | to
    output wire                             sarb2ips_stall_o,          //access delay              | initiator
    output wire [15:0]                      sarb2ips_dat_o,            //read data bus             +-

    //Return stack bus (wishbone)
    input  wire                             irs2sarb_cyc_i,            //bus cycle indicator       +-
    input  wire                             irs2sarb_stb_i,            //access request            | initiator
    input  wire                             irs2sarb_we_i,             //write enable              | to
    input  wire [`SP_WIDTH-1:0]             irs2sarb_adr_i,            //address bus               | target
    input  wire [15:0]                      irs2sarb_dat_i,            //write data bus            +-
    output wire                             sarb2irs_ack_o,            //bus cycle acknowledge     +-
    output wire                             sarb2irs_err_o,            //error indicator           | target
    output wire                             sarb2irs_rty_o,            //retry request             | to
    output wire                             sarb2irs_stall_o,          //access delay              | initiator
    output wire [15:0]                      sarb2irs_dat_o,            //read data bus             +-

    //Probe signals
    output wire [1:0]                       prb_sarb_state_o);         //FSM state

   //Instantiation
   //=============
   N1_sarb
     #(.SP_WIDTH (`SP_WIDTH))
   DUT
     (//Clock and reset
      .clk_i                    (clk_i),                               //module clock
      .async_rst_i              (async_rst_i),                         //asynchronous reset
      .sync_rst_i               (sync_rst_i),                          //synchronous reset

      //Merged stack bus (wishbone)
      .sbus_cyc_o               (sbus_cyc_o),                          //bus cycle indicator       +-
      .sbus_stb_o               (sbus_stb_o),                          //access request            |
      .sbus_we_o                (sbus_we_o),                           //write enable              | initiator
      .sbus_adr_o               (sbus_adr_o),                          //address bus               | to
      .sbus_dat_o               (sbus_dat_o),                          //write data bus            | target
      .sbus_tga_ps_o            (sbus_tga_ps_o),                       //parameter stack access    |
      .sbus_tga_rs_o            (sbus_tga_rs_o),                       //return stack access       +-
      .sbus_ack_i               (sbus_ack_i),                          //bus cycle acknowledge     +-
      .sbus_err_i               (sbus_err_i),                          //error indicator           | target
      .sbus_rty_i               (sbus_rty_i),                          //retry request             | to
      .sbus_stall_i             (sbus_stall_i),                        //access delay              | initiator
      .sbus_dat_i               (sbus_dat_i),                          //read data bus             +-

      //Parameter stack bus (wishbone)
      .ips2sarb_cyc_i           (ips2sarb_cyc_i),                      //bus cycle indicator       +-
      .ips2sarb_stb_i           (ips2sarb_stb_i),                      //access request            | initiator
      .ips2sarb_we_i            (ips2sarb_we_i),                       //write enable              | to
      .ips2sarb_adr_i           (ips2sarb_adr_i),                      //address bus               | target
      .ips2sarb_dat_i           (ips2sarb_dat_i),                      //write data bus            +-
      .sarb2ips_ack_o           (sarb2ips_ack_o),                      //bus cycle acknowledge     +-
      .sarb2ips_err_o           (sarb2ips_err_o),                      //error indicator           | target
      .sarb2ips_rty_o           (sarb2ips_rty_o),                      //retry request             | to
      .sarb2ips_stall_o         (sarb2ips_stall_o),                    //access delay              | initiator
      .sarb2ips_dat_o           (sarb2ips_dat_o),                      //read data bus             +-

      //Return stack bus (wishbone)
      .irs2sarb_cyc_i           (irs2sarb_cyc_i),                      //bus cycle indicator       +-
      .irs2sarb_stb_i           (irs2sarb_stb_i),                      //access request            | initiator
      .irs2sarb_we_i            (irs2sarb_we_i),                       //write enable              | to
      .irs2sarb_adr_i           (irs2sarb_adr_i),                      //address bus               | target
      .irs2sarb_dat_i           (irs2sarb_dat_i),                      //write data bus            +-
      .sarb2irs_ack_o           (sarb2irs_ack_o),                      //bus cycle acknowledge     +-
      .sarb2irs_err_o           (sarb2irs_err_o),                      //error indicator           | target
      .sarb2irs_rty_o           (sarb2irs_rty_o),                      //retry request             | to
      .sarb2irs_stall_o         (sarb2irs_stall_o),                    //access delay              | initiator
      .sarb2irs_dat_o           (sarb2irs_dat_o),                      //read data bus             +-

      //Probe signals
      .prb_sarb_state_o         (prb_sarb_state_o));                   //FSM state

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //===================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                    (clk_i),                               //module clock
      .sync_i                   (1'b1),                                //clock enable
      .async_rst_i              (async_rst_i),                         //asynchronous reset
      .sync_rst_i               (sync_rst_i),                          //synchronous reset
      .gated_clk_o              ());                                   //gated clock


`endif //  `ifdef FORMAL

endmodule // ftb_N1_sarb
