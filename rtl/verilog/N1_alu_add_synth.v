//###############################################################################
//# N1 - DSP Cell Partition for the Lattice iCE40UP5K FPGA                      #
//###############################################################################
//#    Copyright 2018 - 2024 Dirk Heisswolf                                     #
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
//#    This module implements a 32 bit adder/subtractor.                        #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 10, 2024                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_alu_add
   (//Clock and reset
    //input  wire                           clk_i,                        //module clock
    //input  wire                           async_rst_i,                  //asynchronous reset
    //input  wire                           sync_rst_i,                   //synchronous reset

    //ALU interface
    output wire [31:0]                      add2alu_res_o,                //result
    input  wire                             alu2add_opr_i,                //operator: 1:op1 - op0, 0:op1 + op0
    input  wire [15:0]                      alu2add_opd0_i,               //first operand
    input  wire [15:0]                      alu2add_opd1_i);              //second operand (zero if no operator selected)

    //Adder/Subtractor
    //----------------
    assign add2alu_res_o = alu2add_opr_i ? {15'h0000,alu2add_opd0_i} - {15'h0000,alu2add_opd1_i} :
                                           {15'h0000,alu2add_opd0_i} + {15'h0000,alu2add_opd1_i};

endmodule // N1_alu_add
