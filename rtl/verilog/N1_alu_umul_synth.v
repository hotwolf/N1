//###############################################################################
//# N1 - Unsigned Multiplier for ALU Operations                                 #
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
//#    This module implements a 16 bit unsigned multiplier utilizing a DSP cell #
//#    (SB_MAC16) instance of the Lattice iCE40UP5K FPGA.                       #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 11, 2024                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_alu_umul
   (//Clock and reset
    //input  wire                           clk_i,                        //module clock
    //input  wire                           async_rst_i,                  //asynchronous reset
    //input  wire                           sync_rst_i,                   //synchronous reset

    //ALU interface
    output wire [31:0]                      umul2alu_res_o,               //result
    input  wire [15:0]                      alu2umul_opd0_i,              //first operand
    input  wire [15:0]                      alu2umul_opd1_i);             //second operand

   //Unsigned multiplier
   //-------------------
   assign umul2alu_res_o = alu2umul_opd0_i * alu2umul_opd1_i;

endmodule // N1_alu_umul
