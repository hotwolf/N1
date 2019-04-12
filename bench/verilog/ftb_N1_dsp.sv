//###############################################################################
//# N1 - Formal Testbench - DSP Cell Partition                                  #
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
//#    This is the the formal testbench for all implementations of the N1 DSP   #
//#    cell partition.                                                          #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   October 16, 2018                                                          #
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

module ftb_N1_dsp
   (//Clock and reset
    input  wire                             clk_i,                    //module clock
    input  wire                             async_rst_i,              //asynchronous reset
    input  wire                             sync_rst_i,               //synchronous reset

    //Program bus (wishbone)
    output wire [15:0]                      pbus_adr_o,               //address bus

    //Internal interfaces
    //-------------------
    //ALU interface
    output wire [31:0]                      dsp2alu_add_res_o,        //result from adder
    output wire [31:0]                      dsp2alu_mul_res_o,        //result from multiplier
    input  wire                             alu2dsp_add_sel_i,        //1:op1 - op0, 0:op1 + op0
    input  wire                             alu2dsp_mul_sel_i,        //1:signed, 0:unsigned
    input  wire [15:0]                      alu2dsp_add_opd0_i,       //first operand for adder/subtractor
    input  wire [15:0]                      alu2dsp_add_opd1_i,       //second operand for adder/subtractor (zero if no operator selected)
    input  wire [15:0]                      alu2dsp_mul_opd0_i,       //first operand for multipliers
    input  wire [15:0]                      alu2dsp_mul_opd1_i,       //second operand dor multipliers (zero if no operator selected)

    //FC interface
    input  wire                             fc2dsp_pc_hold_i,         //maintain PC

    //PAGU interface
    output wire                             pagu2dsp_adr_sel_i,       //1:absolute COF, 0:relative COF
    output wire [15:0]                      pagu2dsp_aadr_i,          //absolute COF address
    output wire [15:0]                      pagu2dsp_radr_i,          //relative COF address

    //PRS interface
    output wire [15:0]                      dsp2prs_pc_o,             //program counter
    output wire [`SP_WIDTH-1:0]             dsp2prs_psp_o,            //parameter stack pointer (AGU output)
    output wire [`SP_WIDTH-1:0]             dsp2prs_rsp_o,            //return stack pointer (AGU output)

    //SAGU interface
    output wire [`SP_WIDTH-1:0]             dsp2sagu_psp_next_o,      //parameter stack pointer
    output wire [`SP_WIDTH-1:0]             dsp2sagu_rsp_next_o,      //return stack pointer
    input  wire                             sagu2dsp_psp_hold_i,      //maintain PSP
    input  wire                             sagu2dsp_psp_op_sel_i,    //1:set new PSP, 0:add offset to PSP
    input  wire [`SP_WIDTH-1:0]             sagu2dsp_psp_offs_i,      //PSP offset
    input  wire [`SP_WIDTH-1:0]             sagu2dsp_psp_load_val_i,  //new PSP
    input  wire                             sagu2dsp_rsp_hold_i,      //maintain RSP
    input  wire                             sagu2dsp_rsp_op_sel_i,    //1:set new RSP, 0:add offset to RSP
    input  wire [`SP_WIDTH-1:0]             sagu2dsp_rsp_offs_i,      //relative address
    input  wire [`SP_WIDTH-1:0]             sagu2dsp_rsp_load_val_i); //absolute address

   //Instantiation
   //=============
   N1_dsp
     #(.SP_WIDTH (`SP_WIDTH))
   DUT
     (//Clock and reset
      .clk_i                    (clk_i),                              //module clock
      .async_rst_i              (async_rst_i),                        //asynchronous reset
      .sync_rst_i               (sync_rst_i),                         //synchronous reset

      //Program bus (wishbone)
      .pbus_adr_o               (pbus_adr_o),                         //address bus

      //ALU interface
      .dsp2alu_add_res_o        (dsp2alu_add_res_o),                  //result from adder
      .dsp2alu_mul_res_o        (dsp2alu_mul_res_o),                  //result from multiplier
      .alu2dsp_add_sel_i        (alu2dsp_add_sel_i),                  //1:sub, 0:add
      .alu2dsp_mul_sel_i        (alu2dsp_mul_sel_i),                  //1:smul, 0:umul
      .alu2dsp_add_opd0_i       (alu2dsp_add_opd0_i),                 //first operand for adder/subtractor
      .alu2dsp_add_opd1_i       (alu2dsp_add_opd1_i),                 //second operand for adder/subtractor (zero if no operator selected)
      .alu2dsp_mul_opd0_i       (alu2dsp_mul_opd0_i),                 //first operand for multipliers
      .alu2dsp_mul_opd1_i       (alu2dsp_mul_opd1_i),                 //second operand dor multipliers (zero if no operator selected)

      //FC interface
      .fc2dsp_pc_hold_i         (fc2dsp_pc_hold_i),                   //maintain PC

      //PAGU interface
      .pagu2dsp_adr_sel_i       (pagu2dsp_adr_sel_i),                 //1:absolute COF, 0:relative COF
      .pagu2dsp_aadr_i          (pagu2dsp_aadr_i),                    //absolute COF address
      .pagu2dsp_radr_i          (pagu2dsp_radr_i),                    //relative COF address

      //PRS interface
      .dsp2prs_pc_o             (dsp2prs_pc_o),                       //program counter
      .dsp2prs_psp_o            (dsp2prs_psp_o),                      //parameter stack pointer (AGU output)
      .dsp2prs_rsp_o            (dsp2prs_rsp_o),                      //return stack pointer (AGU output)

      //SAGU interface
      .dsp2sagu_psp_next_o      (dsp2sagu_psp_next_o),                //parameter stack pointer
      .dsp2sagu_rsp_next_o      (dsp2sagu_rsp_next_o),                //return stack pointer
      .sagu2dsp_psp_hold_i      (sagu2dsp_psp_hold_i),                //maintain PSP
      .sagu2dsp_psp_op_sel_i    (sagu2dsp_psp_op_sel_i),              //1:set new PSP, 0:add offset to PSP
      .sagu2dsp_psp_offs_i      (sagu2dsp_psp_offs_i),                //PSP offset
      .sagu2dsp_psp_load_val_i  (sagu2dsp_psp_load_val_i),            //new PSP
      .sagu2dsp_rsp_hold_i      (sagu2dsp_rsp_hold_i),                //maintain RSP
      .sagu2dsp_rsp_op_sel_i    (sagu2dsp_rsp_op_sel_i),              //1:set new RSP, 0:add offset to RSP
      .sagu2dsp_rsp_offs_i      (sagu2dsp_rsp_offs_i),                //relative address
      .sagu2dsp_rsp_load_val_i  (sagu2dsp_rsp_load_val_i));           //absolute address

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //==================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                      (clk_i),                         //module clock
      .sync_i                     (1'b1),                          //clock enable
      .async_rst_i                (async_rst_i),                   //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                    //synchronous reset
      .gated_clk_o                ());                             //gated clock

`endif //  `ifdef FORMAL

endmodule // ftb_N1_dsp
