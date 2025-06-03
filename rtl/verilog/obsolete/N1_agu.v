//###############################################################################
//# N1 - Program Bus Address Generation Unit                                    #
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
//#    This module provides addresses for the program bus (Pbus).               #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 20, 2019                                                         #
//#      - Initial release                                                      #
//#   May 8, 2019                                                               #
//#      - Added RTY_I support to PBUS                                          #
//###############################################################################
`default_nettype none

module N1_agu
  #(parameter PBUS_AADR_OFFSET = 16'h0000,                       //offset for direct program address
    parameter PBUS_MADR_OFFSET = 16'h0000)                       //offset for direct data

   (//Clock and reset
    input  wire                      clk_i,                      //module clock
    input  wire                      async_rst_i,                //asynchronous reset
    input  wire                      sync_rst_i,                 //synchronous reset

    //Program bus (wishbone)
    output wire [15:0]               pbus_adr_o,                 //address bus

    //DSP interface
    output reg                       agu2dsp_adr_sel_o,          //1:absolute COF, 0:relative COF
    output reg  [15:0]               agu2dsp_radr_o,             //relative COF address
    output reg  [15:0]               agu2dsp_aadr_o,             //absolute COF address
    input  wire [15:0]               dsp2agu_adr_i,              //AGU output
								 
    //FC interface						 
    input  wire                      fc2agu_prev_adr_hold_i,     //maintain stored address
    input  wire                      fc2agu_prev_adr_sel_i,      //0:AGU output, 1:previous address

    //IR interface
    input  wire                      ir2agu_eow_i,               //end of word (EOW bit)
    input  wire                      ir2agu_eow_postpone_i,      //postpone EOW
    input  wire                      ir2agu_jmp_or_cal_i,        //jump or call instruction
    input  wire                      ir2agu_bra_i,               //conditional branch
    input  wire                      ir2agu_scyc_i,              //single cycle instruction
    input  wire                      ir2agu_mem_i,               //memory I/O
    input  wire                      ir2agu_aadr_sel_i,          //select (indirect) absolute address
    input  wire                      ir2agu_madr_sel_i,          //select (indirect) data address
    input  wire [13:0]               ir2agu_aadr_i,              //direct absolute address
    input  wire [12:0]               ir2agu_radr_i,              //direct relative address
    input  wire [7:0]                ir2agu_madr_i,              //direct memory address
								 
    //PRS interface						 
    output wire [15:0]               agu2prs_prev_adr_o,         //address register output
    input  wire [15:0]               prs2agu_ps0_i,              //PS0
    input  wire [15:0]               prs2agu_rs0_i,              //RS0

    //Probe signals
    output wire [15:0]               prb_agu_prev_adr_o);        //address register

   //Internal parameters
   //-------------------
   localparam RST_ADR = 16'h0000;                                //reset address

   //Internal signalss
   //-------------------
   //Direct addresses
   wire [15:0]                       full_aadr = {PBUS_AADR_OFFSET[15:14], ir2agu_aadr_i};
   wire [15:0]                       full_radr = {{3{ir2agu_radr_i[12]}}, ir2agu_radr_i};
   wire [15:0]                       full_madr = {PBUS_MADR_OFFSET[15:8],  ir2agu_madr_i};
   //Address register
   reg  [15:0]                       prev_adr_reg;               //address register

   //DSP control
   //-----------
   always @*
     begin
        //default
        agu2dsp_adr_sel_o    =  1'b0;                            //1:absolute COF, 0:relative COF
        agu2dsp_radr_o       = 16'h0000;                         //relative COF address
        agu2dsp_aadr_o       = 16'h0000;                         //absolute COF address

        //Jump or Call
        if (ir2agu_jmp_or_cal_i)
          begin
             agu2dsp_adr_sel_o = 1'b1;                           //drive absolute address
             agu2dsp_aadr_o    = agu2dsp_aadr_o     |            //make use of onehot encoding
                                  (ir2agu_aadr_sel_i ?           //direct or indirect addressing
                                   prs2agu_ps0_i     :           //indirect address
                                   full_aadr);                   //direct address
          end // if (ir2agu_jmp_or_cal_i)

        //Conditional branch
        if (ir2agu_bra_i)
          begin
             agu2dsp_adr_sel_o = ir2agu_eow_i &                  //EOW bit set
                                  ~|prs2agu_ps0_i;               //branch not taken
             agu2dsp_aadr_o    = agu2dsp_aadr_o     |            //make use of onehot encoding
                                  prs2agu_rs0_i;                 //return address
             agu2dsp_radr_o    = agu2dsp_aadr_o     |            //make use of onehot encoding
                                  (|prs2agu_ps0_i    ?           //branch or not
                                   full_radr          :          //branch address
                                   16'h0000);                    //linear flow
          end // if (ir2agu_bra_i)

        //Single cycle instruction
        if (ir2agu_scyc_i)
          begin
            //Increment PC
             begin
                agu2dsp_adr_sel_o = ir2agu_eow_i &               //EOW bit set
                                     ~ir2agu_eow_postpone_i;     //don't postpone EOW
                agu2dsp_aadr_o    = agu2dsp_aadr_o  |            //make use of onehot encoding
                                     prs2agu_rs0_i;              //return address
                agu2dsp_radr_o    = agu2dsp_aadr_o  |            //make use of onehot encoding
                                     16'h0000;                   //linear flow
             end
          end // if (ir2agu_scyc_i)

        //Memory IO
        if (ir2agu_mem_i)
          begin
             agu2dsp_adr_sel_o = 1'b1;                           //drive absolute address
             agu2dsp_aadr_o    = agu2dsp_aadr_o     |            //make use of onehot encoding
                                  (ir2agu_madr_sel_i ?           //immediate or indirect addressing
                                  prs2agu_ps0_i      :           //indirect address
                                  full_madr);                    //direct address
          end // if (ir2fc_mem_i)
     end // always @ *

   //Address register (for RTY_I handling)
   //-------------------------------------
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                         //asynchronous reset
          prev_adr_reg <= 16'h0000;                              //reset value
        else if (sync_rst_i)                                     //synchronous reset
          prev_adr_reg <= 16'h0000;                              //reset value
        else if (~fc2agu_prev_adr_hold_i)                        //update address register
          prev_adr_reg <= dsp2agu_adr_i;                         //AGU output
     end // always @ (posedge async_rst_i or posedge clk_i)

   //PBUS address
   assign pbus_adr_o = fc2agu_prev_adr_sel_i ? dsp2agu_adr_i :  //AGU output
                                                prev_adr_reg;    //address register

   //Stack input
   assign agu2prs_prev_adr_o = prev_adr_reg;                    //address register

   //Probe signal
   assign prb_agu_prev_adr_o = prev_adr_reg;                    //address register

endmodule // N1_agu
