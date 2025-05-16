//###############################################################################
//# N1 - Address Accumulator                                                    #
//###############################################################################
//#    Copyright 2018 - 2025 Dirk Heisswolf                                     #
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
//#    This module implements a 16 bit accumulator for address calculations.    #
//#                                                                             #
//#    The combinational logicaddress output (aacc_addr_o) is intended to be    #
//#    used as memory address. The (internal) accumulator register can serve as #
//#    program counter.                                                         #
//#                                                                             #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 12, 2024                                                         #
//#      - Initial release                                                      #
//#   May 15, 2025                                                              #
//#      - New naming                                                           #
//###############################################################################
`default_nettype none

module N1_aacc
   (//Clock and reset
    input  wire                             clk_i,                        //module clock
    input  wire                             async_rst_i,                  //asynchronous reset
    input  wire                             sync_rst_i,                   //synchronous reset


    //Accumulator interface
    input  wire [15:0]                      aacc_abs_addr_i,              //absolute address input
    input  wire [15:0]                      aacc_rel_addr_i,              //relative address input
    input  wire                             aacc_rel_inc_i,               //increment relative address
    input  wire                             aacc_pc_hold_i,               //maintain PC
    input  wire                             aacc_sel_i,                   //1:absolute COF, 0:relative COF
    output wire [15:0]                      aacc_addr_o,                  //program AGU output

    //Probe signals
    output wire [15:0]                      prb_aacc_pc_o);                //probed PC

   //Internal signals
   //----------------
   //Accumulator signals
   reg  [15:0]                              pc_reg;                       //program counter
   wire [15:0]                              acc_out;                      //accumulator output

   //AGU accumulator
   //---------------
   //Program counter
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                  //asynchronous reset
          pc_reg <= 16'h0000;                                             //start address
        else if (sync_rst_i)                                              //synchronous reset
          pc_reg <= 16'h0000;                                             //start address
        else if (~aacc_pc_hold_i)                                         //update PC
          pc_reg <= acc_out;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Outputs
   assign acc_out         = aacc_sel_i ? aacc_abs_addr_i :
                                         pc_reg          +
                                         aacc_rel_addr_i +
                                         {15'h0000,aacc_rel_inc_i};
   assign aacc_addr_o     = acc_out;                                      //address output

   //Probe signals
   assign prb_aacc_pc_o   = pc_reg;                                       //PC

endmodule // N1_agu_acc
