//###############################################################################
//# N1 - Program Counter (Address Accumulator)                                  #
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
//#    The combinational logic address output (pc_addr_o) is intended to be     #
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
//#   June 2, 2025                                                              #
//#      - Capturing previous PC for interruptable instructions                 #
//###############################################################################
`default_nettype none

module N1_pc
  #(parameter  INT_EXTENSION    = 1)                                      //interrupt extension
   (//Clock and reset
    input  wire                             clk_i,                        //module clock
    input  wire                             async_rst_i,                  //asynchronous reset
    input  wire                             sync_rst_i,                   //synchronous reset


    //Accumulator interface
    input  wire [15:0]                      pc_abs_addr_i,                //absolute address input
    input  wire [15:0]                      pc_rel_addr_i,                //relative address input
    input  wire                             pc_rel_inc_i,                 //increment relative address
    input  wire                             pc_pc_hold_i,                 //maintain PC
    input  wire                             pc_sel_i,                     //1:absolute COF, 0:relative COF
    output wire [15:0]                      pc_next_o,                    //program AGU output
    output wire [15:0]                      pc_prev_o,                    //previous PC

    //Probe signals
    output wire [15:0]                      prb_pc_cur_o,                 //probed current PC
    output wire [15:0]                      prb_pc_prev_o);               //probed previous PC

   //Internal signals
   //----------------
   //Accumulator signals
   reg  [15:0]                              pc_reg;                       //program counter
   reg  [15:0]                              pc_prev_reg;                  //previous program counter
   wire [15:0]                              acc_out;                      //accumulator output

   //AGU accumulator
   //---------------
   //Program counter
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                  //asynchronous reset
          begin
             pc_reg      <= 16'h0000;                                     //start address
             pc_prev_reg <= 16'h0000;                                     //start address
          end
        else if (sync_rst_i)                                              //synchronous reset
          begin
             pc_reg      <= 16'h0000;                                     //start address
             pc_prev_reg <= 16'h0000;                                     //start address
          end
        else if (~pc_pc_hold_i)                                           //update PC
          begin
             pc_reg      <= acc_out;                                      //current PC
             pc_prev_reg <= INT_EXTENSION ? pc_reg : 16'h0000;            //previous PC
          end
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Outputs
   assign acc_out         = pc_sel_i ? pc_abs_addr_i :
                                         pc_reg        +
                                         pc_rel_addr_i +
                                         {15'h0000,pc_rel_inc_i};
   assign pc_next_o     = acc_out;                                        //opcode fetch address
   assign pc_prev_o     = pc_prev_reg;                                    //return address

   //Probe signals
   assign prb_pc_cur_o   = pc_reg;                                         //current PC
   assign prb_pc_prev_o  = pc_prev_reg;                                    //previous PC

endmodule // N1_agu_acc
