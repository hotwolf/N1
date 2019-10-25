//###############################################################################
//# N1 - Synthesizable Replacement of the DSP Cell Partition                    #
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
//#    This is a synthesizable replacement for the DSP cell partition. It can   #
//#    used for verification and automatic DSP cell allocation.                 #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 10, 2019                                                          #
//#      - Initial release                                                      #
//#   May 7, 2019                                                               #
//#      - added input "fc2dsp_radr_inc_i"                                      #
//#   May 8, 2019                                                               #
//#      - Moved PBUS address generation to PAGU                                #
//#   October 17, 2019                                                          #
//#      - New stack AGU interface                                              #
//###############################################################################
`default_nettype none

module N1_dsp
  #(//Integration parameters
    parameter   SP_WIDTH   =  12)                                       //width of a stack pointer

   (//Clock and reset
    input  wire                             clk_i,                      //module clock
    input  wire                             async_rst_i,                //asynchronous reset
    input  wire                             sync_rst_i,                 //synchronous reset

    //Internal interfaces
    //-------------------
    //ALU interface
    output wire [31:0]                      dsp2alu_add_res_o,          //result from adder
    output wire [31:0]                      dsp2alu_mul_res_o,          //result from multiplier
    input  wire                             alu2dsp_add_sel_i,          //1:op1 - op0, 0:op1 + op0
    input  wire                             alu2dsp_mul_sel_i,          //1:signed, 0:unsigned
    input  wire [15:0]                      alu2dsp_add_opd0_i,         //first operand for adder/subtractor
    input  wire [15:0]                      alu2dsp_add_opd1_i,         //second operand for adder/subtractor (zero if no operator selected)
    input  wire [15:0]                      alu2dsp_mul_opd0_i,         //first operand for multipliers
    input  wire [15:0]                      alu2dsp_mul_opd1_i,         //second operand dor multipliers (zero if no operator selected)

    //FC interface
    input  wire                             fc2dsp_pc_hold_i,           //maintain PC
    input  wire                             fc2dsp_radr_inc_i,          //increment relative address

    //LS interface
    output wire                             dsp2ls_overflow_o,            //stacks overlap
    output wire                             dsp2ls_sp_carry_o,            //carry of inc/dec operation
    output wire [SP_WIDTH-1:0]              dsp2ls_sp_next_o,             //next PSP or RSP
    input  wire                             ls2dsp_sp_opr_i,              //0:inc, 1:dec
    input  wire                             ls2dsp_sp_sel_i,              //0:PSP, 1:RSP
    input  wire [SP_WIDTH-1:0]              ls2dsp_psp_i,                 //PSP
    input  wire [SP_WIDTH-1:0]              ls2dsp_rsp_i,                 //RSP
    input  wire [SP_WIDTH-1:0]              ls2dsp_rsp_b_i,           //~RSP

    //PAGU interface
    output wire [15:0]                      dsp2pagu_adr_o,             //program AGU output
    input  wire                             pagu2dsp_adr_sel_i,         //1:absolute COF, 0:relative COF
    input  wire [15:0]                      pagu2dsp_aadr_i,            //absolute COF address
    input  wire [15:0]                      pagu2dsp_radr_i,            //relative COF address

    //Probe signals
    output wire [15:0]                      prb_dsp_pc_o);              //PC

   //Internal Signals
   //----------------
   //Program AGU
   reg  [15:0]                              pc_reg;                     //current PC
   wire [15:0]                              pc_next;                    //next PC
   //Lower stack AGU
   wire [SP_WIDTH:0]                        ls_cell_count;              //number of cells in combined stacks
   wire [SP_WIDTH-1:0]                      ls_sp;                      //PSP or RSP
   wire [SP_WIDTH:0]                        ls_sp_next;                 //incremented/decremented SP

   //ALU
   //---
   //Adder
   assign dsp2alu_add_res_o = { 15'h0000, {17{alu2dsp_add_sel_i}}} ^
                              ({16'h0000, {16{alu2dsp_add_sel_i}}  ^ alu2dsp_add_opd1_i} +
                               {16'h0000, alu2dsp_add_opd0_i});

   //Multiplier
   assign dsp2alu_mul_res_o = {{16{alu2dsp_mul_sel_i & alu2dsp_mul_opd0_i[15]}}, alu2dsp_mul_opd0_i} *
                              {{16{alu2dsp_mul_sel_i & alu2dsp_mul_opd1_i[15]}}, alu2dsp_mul_opd1_i};

   //Lower stack AGU
   //---------------
   assign ls_cell_count     = {1'b0, ls2dsp_psp_i} +                    //cells on LSP
                              {1'b0, ls2dsp_rsp_i};                     //cells on RSP
   assign dsp2ls_overflow_o = ls_cell_count[SP_WIDTH];                  //carry
   assign ls_sp             = ls2dsp_sp_sel_i ? ls2dsp_rsp_i :          //1:RSP
                                                ls2dsp_psp_i;           //0:PSP
   assign ls_sp_next        = {1'b0, ls_sp} +                           //PSP or RSP
                              {{SP_WIDTH{ls2dsp_sp_opr_i}}, 1'b1};      //+1 or -1
   assign dsp2ls_sp_carry_o = ls_sp_next[SP_WIDTH];                     //carry
   assign dsp2ls_sp_next_o  = ls_sp_next[SP_WIDTH-1:0];                 //incremented/decremented SP

   //Program AGU
   //-----------
   //Program counter
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                //asynchronous reset
          pc_reg <= 16'h0000;                                           //start address
        else if (sync_rst_i)                                            //synchronous reset
          pc_reg <= 16'h0000;                                           //start address
        else if (~fc2dsp_pc_hold_i)                                     //update PC
          pc_reg <= pc_next;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Outputs
   assign pc_next           = pagu2dsp_adr_sel_i ? pagu2dsp_aadr_i :
                                                   pc_reg          +
                                                   pagu2dsp_radr_i +
                                                   {15'h0000,fc2dsp_radr_inc_i};
   assign dsp2pagu_adr_o    = pc_next;                                  //program AGU output

   //Probe signals
   assign prb_dsp_pc_o      = pc_reg;                                   //PC

endmodule // N1_dsp
