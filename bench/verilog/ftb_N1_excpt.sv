//###############################################################################
//# N1 - Formal Testbench - Exception and Interrupt Aggregator                  #
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
//#    This is the the formal testbench for the exception and interrupt         #
//#    aggregator block.                                                        #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   March 4, 2019                                                             #
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

module ftb_N1_excpt
   (//Clock and reset
    input  wire                      clk_i,                  //module clock
    input  wire                      async_rst_i,            //asynchronous reset
    input  wire                      sync_rst_i,             //synchronous reset

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
    input  wire                      sagu2excpt_psof_i,      //PS overflow
    input  wire                      sagu2excpt_rsof_i,      //RS overflow

    //Probe signals
    output wire [2:0]                prb_excpt_o,            //exception tracker
    output wire                      prb_excpt_en_o,         //exception enable
    output wire                      prb_irq_en_o);          //interrupt enable

   //Instantiation
   //=============
   N1_excpt
   DUT
   (//Clock and reset
    .clk_i                           (clk_i),                //module clock
    .async_rst_i                     (async_rst_i),          //asynchronous reset
    .sync_rst_i                      (sync_rst_i),           //synchronous reset

    //Interrupt interface
    .irq_req_i                       (irq_req_i),            //requested ISR

    //FC interface
    .excpt2fc_excpt_o                (excpt2fc_excpt_o),     //exception to be handled
    .excpt2fc_irq_o                  (excpt2fc_irq_o),       //exception to be handled
    .fc2excpt_excpt_clr_i            (fc2excpt_excpt_clr_i), //clear and disable exceptions
    .fc2excpt_irq_dis_i              (fc2excpt_irq_dis_i),   //disable interrupts
    .fc2excpt_buserr_i               (fc2excpt_buserr_i),    //pbus error

    //IR interface
    .ir2excpt_excpt_en_i             (ir2excpt_excpt_en_i),  //enable exceptions
    .ir2excpt_excpt_dis_i            (ir2excpt_excpt_dis_i), //disable exceptions
    .ir2excpt_irq_en_i               (ir2excpt_irq_en_i),    //enable interrupts
    .ir2excpt_irq_dis_i              (ir2excpt_irq_dis_i),   //disable interrupts

    //PRS interface
    .excpt2prs_tc_o                  (excpt2prs_tc_o),       //throw code
    .prs2excpt_psuf_i                (prs2excpt_psuf_i),     //PS underflow
    .prs2excpt_rsuf_i                (prs2excpt_rsuf_i),     //RS underflow

    //SAGU interface
    .sagu2excpt_psof_i               (sagu2excpt_psof_i),    //PS overflow
    .sagu2excpt_rsof_i               (sagu2excpt_rsof_i),    //RS overflow

    //Probe signals
    .prb_excpt_o                     (prb_excpt_o),          //exception tracker
    .prb_excpt_en_o                  (prb_excpt_en_o),       //exception enable
    .prb_irq_en_o                    (prb_irq_en_o));        //interrupt enable

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //==================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                         (clk_i),                //module clock
      .sync_i                        (1'b1),                 //clock enable
      .async_rst_i                   (async_rst_i),          //asynchronous reset
      .sync_rst_i                    (sync_rst_i),           //synchronous reset
      .gated_clk_o                   ());                    //gated clock


`endif //  `ifdef FORMAL

endmodule // ftb_N1_excpt
