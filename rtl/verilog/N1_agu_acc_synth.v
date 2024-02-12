//###############################################################################
//# N1 - Accumulator for AGU Operations                                         #
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
//#    This module implements a 16 bit accumulator.                             #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 12, 2024                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_agu_acc
  #(//Integration parameters
    parameter   SP_WIDTH   =  12)                                         //width of a stack pointer

   (//Clock and reset
    input  wire                             clk_i,                        //module clock
    input  wire                             async_rst_i,                  //asynchronous reset
    input  wire                             sync_rst_i,                   //synchronous reset


    //AGU interface
    output wire [15:0]                      acc2agu_adr_o,                //program AGU output
    input  wire [15:0]                      agu2acc_aadr_i,               //absolute COF address
    input  wire [15:0]                      agu2acc_radr_i,               //relative COF address
    input  wire                             agu2acc_adr_sel_i,           //1:absolute COF, 0:relative COF
    input  wire                             agu2acc_pc_hold_i,            //maintain PC
    input  wire                             agu2acc_radr_inc_i,           //increment relative address

    //Probe signals
    output wire [15:0]                      prb_dsp_pc_o);                //PC

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
        if (async_rst_i)                                                //asynchronous reset
          pc_reg <= 16'h0000;                                           //start address
        else if (sync_rst_i)                                            //synchronous reset
          pc_reg <= 16'h0000;                                           //start address
        else if (~agu2acc_pc_hold_i)                                    //update PC
          pc_reg <= acc_out;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Outputs
   assign acc_out           = agu2acc_adr_sel_i ? agu2acc_aadr_i :
                                                  pc_reg          +
                                                  agu2acc_radr_i +
                                                  {15'h0000,agu2acc_radr_inc_i};
   assign acc2agu_adr_o     = acc_out;                                  //program AGU output

   //Probe signals
   assign prb_dsp_pc_o      = pc_reg;                                   //PC

endmodule // N1_agu_acc
