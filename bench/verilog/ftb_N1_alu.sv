//###############################################################################
//# N1 - Formal Testbench - Arithmetic Logic Unit                               #
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
//#    This is the the formal testbench for the ALU block.                      #
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

module ftb_N1_alu
   (//DSP cell interface
    output wire                   alu2dsp_add_sel_o,                 //1:sub, 0:add
    output wire                   alu2dsp_mul_sel_o,                 //1:smul, 0:umul
    output wire [15:0]            alu2dsp_add_opd0_o,                //first operand for adder/subtractor
    output wire [15:0]            alu2dsp_add_opd1_o,                //second operand for adder/subtractor (zero if no operator selected)
    output wire [15:0]            alu2dsp_mul_opd0_o,                //first operand for multipliers
    output wire [15:0]            alu2dsp_mul_opd1_o,                //second operand dor multipliers (zero if no operator selected)
    input  wire [31:0]            dsp2alu_add_res_i,                 //result from adder
    input  wire [31:0]            dsp2alu_mul_res_i,                 //result from multiplier

    //IR interface
    input  wire [4:0]             ir2alu_opr_i,                      //ALU operator
    input  wire [4:0]             ir2alu_opd_i,                      //immediate operand
    input  wire                   ir2alu_opd_sel_i,                  //select (stacked)  operand

    //PRS interface
    output wire [15:0]            alu2prs_ps0_next_o,                //new PS0 (TOS)
    output wire [15:0]            alu2prs_ps1_next_o,                //new PS1 (TOS+1)
    input  wire [15:0]            prs2alu_ps0_i,                     //current PS0 (TOS)
    input  wire [15:0]            prs2alu_ps1_i);                    //current PS1 (TOS+1)

   //Instantiation
   //=============
   N1_alu
   DUT
   (//DSP cell interface
    .alu2dsp_add_sel_o          (alu2dsp_add_sel_o),                 //1:sub, 0:add
    .alu2dsp_mul_sel_o          (alu2dsp_mul_sel_o),                 //1:smul, 0:umul
    .alu2dsp_add_opd0_o         (alu2dsp_add_opd0_o),                //first operand for adder/subtractor
    .alu2dsp_add_opd1_o         (alu2dsp_add_opd1_o),                //second operand for adder/subtractor (zero if no operator selected)
    .alu2dsp_mul_opd0_o         (alu2dsp_mul_opd0_o),                //first operand for multipliers
    .alu2dsp_mul_opd1_o         (alu2dsp_mul_opd1_o),                //second operand dor multipliers (zero if no operator selected)
    .dsp2alu_add_res_i          (dsp2alu_add_res_i),                 //result from adder
    .dsp2alu_mul_res_i          (dsp2alu_mul_res_i),                 //result from multiplier

    //IR interface
    .ir2alu_opr_i               (ir2alu_opr_i),                      //ALU operator
    .ir2alu_opd_i               (ir2alu_opd_i),                      //immediate operand
    .ir2alu_opd_sel_i           (ir2alu_opd_sel_i),                  //select (stacked) operand

     //PRS interface
    .alu2prs_ps0_next_o         (alu2prs_ps0_next_o),                //new PS0 (TOS)
    .alu2prs_ps1_next_o         (alu2prs_ps1_next_o),                //new PS1 (TOS+1)
    .prs2alu_ps0_i              (prs2alu_ps0_i),                     //current PS0 (TOS)
    .prs2alu_ps1_i              (prs2alu_ps1_i));                    //current PS1 (TOS+1)

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

`endif //  `ifdef FORMAL

endmodule // ftb_N1_alu
