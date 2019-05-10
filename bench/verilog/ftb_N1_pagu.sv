//###############################################################################
//# N1 - Formal Testbench - Program Bus Address Generation Unit                 #
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
//#    This is the the formal testbench for the program bus AGU.                #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   March 5, 2019                                                             #
//#      - Initial release                                                      #
//#   May 8, 2019                                                               #
//#      - Added RTY_I support to PBUS                                          #
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
`ifndef PBUS_AADR_OFFSET
`define PBUS_AADR_OFFSET  16'h0000
`endif
`ifndef PBUS_MADR_OFFSET
`define PBUS_MADR_OFFSET  16'h0000
`endif

module ftb_N1_pagu
   (//Clock and reset
    input  wire                      clk_i,                     //module clock
    input  wire                      async_rst_i,               //asynchronous reset
    input  wire                      sync_rst_i,                //synchronous reset

    //Program bus (wishbone)
    output wire [15:0]               pbus_adr_o,                //address bus

    //Internal interfaces
    //-------------------
    //DSP interface
    output wire                      pagu2dsp_adr_sel_o,        //1:absolute COF, 0:relative COF
    output wire [15:0]               pagu2dsp_radr_o,           //relative COF address
    output wire [15:0]               pagu2dsp_aadr_o,           //absolute COF address
    input  wire [15:0]               dsp2pagu_adr_i,            //AGU output

    //FC interface
    input  wire                      fc2pagu_prev_adr_hold_i,   //maintain stored address
    input  wire                      fc2pagu_prev_adr_sel_i,    //0:AGU output, 1:previous address

    //IR interface
    input  wire                      ir2pagu_eow_i,             //end of word (EOW bit)
    input  wire                      ir2pagu_eow_postpone_i,    //postpone EOW
    input  wire                      ir2pagu_jmp_or_cal_i,      //jump or call instruction
    input  wire                      ir2pagu_bra_i,             //conditional branch
    input  wire                      ir2pagu_scyc_i,            //single cycle instruction
    input  wire                      ir2pagu_mem_i,             //memory I/O
    input  wire                      ir2pagu_aadr_sel_i,        //select (indirect) absolute address
    input  wire                      ir2pagu_madr_sel_i,        //select (indirect) data address
    input  wire [13:0]               ir2pagu_aadr_i,            //direct absolute address
    input  wire [12:0]               ir2pagu_radr_i,            //direct relative address
    input  wire [7:0]                ir2pagu_madr_i,            //direct memory address

    //PAGU interface
    input  wire [15:0]               dsp2pagu_adr,              //AGU output

   //PRS interface
    output wire [15:0]               pagu2prs_prev_adr_o,       //address register output
    input  wire [15:0]               prs2pagu_ps0_i,            //PS0
    input  wire [15:0]               prs2pagu_rs0_i,            //RS0

    //Probe signals
    output wire [15:0]               prb_pagu_prev_adr_o);      //address register

   //Instantiation
   //=============
   N1_pagu
     #(.PBUS_AADR_OFFSET (`PBUS_AADR_OFFSET),                   //offset for direct program address
       .PBUS_MADR_OFFSET (`PBUS_MADR_OFFSET))                   //offset for direct data
   DUT
     (//Clock and reset
      .clk_i                         (clk_i),                   //module clock
      .async_rst_i                   (async_rst_i),             //asynchronous reset
      .sync_rst_i                    (sync_rst_i),              //synchronous reset

      //Program bus (wishbone)
      .pbus_adr_o                    (pbus_adr_o),              //address bus

      //DSP interface
      .pagu2dsp_adr_sel_o            (pagu2dsp_adr_sel_o),      //1:absolute COF, 0:relative COF
      .pagu2dsp_radr_o               (pagu2dsp_radr_o),         //relative COF address
      .pagu2dsp_aadr_o               (pagu2dsp_aadr_o),         //absolute COF address
      .dsp2pagu_adr_i                (dsp2pagu_adr_i),          //AGU output

      //FC interface
      .fc2pagu_prev_adr_hold_i       (fc2pagu_prev_adr_hold_i), //maintain stored address
      .fc2pagu_prev_adr_sel_i        (fc2pagu_prev_adr_sel_i),  //0:AGU output, 1:previous address

      //IR interface
      .ir2pagu_eow_i                 (ir2pagu_eow_i),           //end of word (EOW bit)
      .ir2pagu_eow_postpone_i        (ir2pagu_eow_postpone_i),  //postpone EOW
      .ir2pagu_jmp_or_cal_i          (ir2pagu_jmp_or_cal_i),    //jump or call instruction
      .ir2pagu_bra_i                 (ir2pagu_bra_i),           //conditional branch
      .ir2pagu_scyc_i                (ir2pagu_scyc_i),          //single cycle instruction
      .ir2pagu_mem_i                 (ir2pagu_mem_i),           //memory I/O
      .ir2pagu_aadr_sel_i            (ir2pagu_aadr_sel_i),      //select (indirect) absolute address
      .ir2pagu_madr_sel_i            (ir2pagu_madr_sel_i),      //select (indirect) data address
      .ir2pagu_aadr_i                (ir2pagu_aadr_i),          //direct absolute address
      .ir2pagu_radr_i                (ir2pagu_radr_i),          //direct relative address
      .ir2pagu_madr_i                (ir2pagu_madr_i),          //direct memory address

      //PRS interface
      .pagu2prs_prev_adr_o           (pagu2prs_prev_adr_o),     //address register output
      .prs2pagu_ps0_i                (prs2pagu_ps0_i),          //PS0
      .prs2pagu_rs0_i                (prs2pagu_rs0_i),          //RS0

      //Probe signals
      .prb_pagu_prev_adr_o           (prb_pagu_prev_adr_o));    //address register

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //===================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                        (clk_i),                    //module clock
      .sync_i                       (1'b1),                     //clock enable
      .async_rst_i                  (async_rst_i),              //asynchronous reset
      .sync_rst_i                   (sync_rst_i),               //synchronous reset
      .gated_clk_o                  ());                        //gated clock

`endif //  `ifdef FORMAL

endmodule // ftb_N1_pagu
