//###############################################################################
//# N1 - Exception and Interrupt Aggregator                                     #
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
//#    This module captures and masks exceptions and interrupts.                #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 20, 2019                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_excpt
   (//Clock and reset
    input wire                       clk_i,                  //module clock
    input wire                       async_rst_i,            //asynchronous reset
    input wire                       sync_rst_i,             //synchronous reset

    //Interrupt interface
    input  wire [15:0]               irq_req_i,              //requested ISR

    //Internal interfaces
    //-------------------
    //FC interface
    output wire                      excpt2fc_excpt_o,       //exception to be handled
    output wire                      excpt2fc_irq_o,         //exception to be handled
    input  wire                      fc2excpt_excpt_clr_i,   //clear and disable exceptions
    input  wire                      fc2excpt_irq_dis_i,     //disable interrupts
    input  wire                      fc2excpt_buserr_i,      //pbus error

    //IR interface
    input  wire                      ir2excpt_excpt_en_i,    //enable exceptions
    input  wire                      ir2excpt_excpt_dis_i,   //disable exceptions
    input  wire                      ir2excpt_irq_en_i,      //enable interrupts
    input  wire                      ir2excpt_irq_dis_i,     //disable interrupts

    //PRS interface
    output wire [15:0]               excpt2prs_tc_o,         //throw code
    input  wire                      prs2excpt_psuf_i,       //PS underflow
    input  wire                      prs2excpt_rsuf_i,       //RS underflow

    //SAGU interface
    input  wire                      sagu2excpt_psof_i,       //PS overflow
    input  wire                      sagu2excpt_rsof_i,       //RS overflow

    //Probe signals
    output wire [2:0]                prb_excpt_o,            //exception tracker
    output wire                      prb_excpt_en_o,         //exception enable
    output wire                      prb_irq_en_o);          //interrupt enable

   //ANS Forth throw codes:
   //----------------------
   //Parameter stack overflow:  -3
   localparam TC_PSOF = 16'hFFFD;
   //Parameter stack underflow: -4
   localparam TC_PSUF = 16'hFFFC;
   //Return stack overflow:     -5
   localparam TC_RSOF = 16'hFFFB;
   //Return stack underflow:    -6
   localparam TC_RSUF = 16'hFFFA;
   //Invalid memory address:    -9
   localparam TC_IMEM = 16'hFFF7;

   //Internal signals
   //----------------
   //Exception tracker
   reg [2:0]                         excpt_reg;              //current exception
   //Interrupt/exception enable
   reg                               excpt_en_reg;           //exception enable
   reg                               irq_en_reg;             //interrupt enable

   //Exception tracker
   //-----------------
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                     //asynchronous reset
          excpt_reg <= 3'b000;
        else if (sync_rst_i)                                 //synchronous reset
          excpt_reg <= 3'b000;
        else if (fc2excpt_excpt_clr_i |                      //clear from FC
                 ~|{excpt_reg, ~excpt_en_reg})               //capture new exception
          excpt_reg <= fc2excpt_excpt_clr_i ? 3'b000       : //clear old exceptions
                       sagu2excpt_psof_i    ? TC_PSOF[2:0] : //PS overflow
                       prs2excpt_psuf_i     ? TC_PSUF[2:0] : //PS underflow
                       sagu2excpt_rsof_i    ? TC_RSOF[2:0] : //RS overflow
                       prs2excpt_rsuf_i     ? TC_RSUF[2:0] : //RS underflow
                       fc2excpt_buserr_i    ? TC_IMEM[2:0] : //pbus error
                                              3'b000;        //no exception
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Exception enable
   //----------------
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                     //asynchronous reset
          excpt_en_reg <= 1'b0;
        else if (sync_rst_i)                                 //synchronous reset
          excpt_en_reg <= 1'b0;
        else if (ir2excpt_excpt_en_i  |                      //enable fron IR
                 ir2excpt_excpt_dis_i |                      //disable fron IR
                 fc2excpt_excpt_clr_i)                       //disable from FC
          excpt_en_reg <= ir2excpt_excpt_en_i;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Interrupt enable
   //----------------
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                     //asynchronous reset
          irq_en_reg <= 1'b0;
        else if (sync_rst_i)                                 //synchronous reset
          irq_en_reg <= 1'b0;
        else if (ir2excpt_irq_en_i | ir2excpt_irq_dis_i)     //write condition
          irq_en_reg <= ir2excpt_irq_en_i;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Outputs
   //-------
   assign excpt2fc_excpt_o = |excpt_reg & excpt_en_reg;      //exception indicator
   assign excpt2fc_irq_o   = |irq_req_i & irq_en_reg;        //interrupt indicator
   assign excpt2prs_tc_o   = {{12{|excpt_reg}},              //throw code
                              ^excpt_reg[2:1],
                               excpt_reg};

   //Probe signals
   //-------------
   //Exception tracker
   assign prb_excpt_o    = excpt_reg;                        //current exception
   //Interrupt/exception enable
   assign prb_excpt_en_o = excpt_en_reg;                     //exception enable
   assign prb_irq_en_o   = irq_en_reg;                       //interrupt enable

endmodule // N1_excpt
