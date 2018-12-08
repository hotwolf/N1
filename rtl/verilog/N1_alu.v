//###############################################################################
//# N1 - Arithmetic Logic Unit                                                  #
//###############################################################################
//#    Copyright 2018 Dirk Heisswolf                                            #
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
//#    This module implements the N1's Arithmetic logic unit (ALU). The         #
//#    following operations are supported:                                      #
//#    op1   *    op0                                                           #
//#    op1   +    op0                                                           #
//#    op1   -    op0  or op0    -   imm                                        #
//#    op1  AND   op0                                                           #
//#    op1 LSHIFT op0     op0 LSHIFT imm                                        #
//#                                                                             #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_alu
  #(parameter CELL_WIDTH    = 16,   //cell width
    parameter SBUS_ADR_WDTH = 7)    //Sbus address width
 
   (//Clock and reset
    //---------------
    input wire                             clk_i,            //module clock
    input wire                             async_rst_i,      //asynchronous reset
    input wire                             sync_rst_i,       //synchronous reset

    //IR interface
    //------------
    input wire [3:0]                       ir_op_i           //operator
    input wire [3:0]                       ir_imm_i          //immediate operand
    
    //Interface to the upper stacks
    //-----------------------------
    input  wire [3:0]                      ps_stat_up_i,     //stack status
    input  wire [CELL_WIDTH-1:0]           alu_op0_i,        //1st operand
    input  wire [CELL_WIDTH-1:0]           alu_op1_i,        //2nd operand
    output wire [(2*CELL_WIDTH)-1:0]       alu_res_o,        //result

    //Interface to the intermediate stacks
    //------------------------------------
    input  wire [ISTACK_DEPTH-1:0]         ps_stat__im_i,    //stack status

    //Interface to the lower stacks
    //-----------------------------
    input  wire [SBUS_ADR_WIDTH-1:0]       ps_stat_lo_i,     //stack status

    





    




    

    ); 


endmodule // N1_alu
