//###############################################################################
//# N1 - Dual Ported RAM (256 words)                                            #
//###############################################################################
//#    Copyright 2018 - 2023 Dirk Heisswolf                                     #
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
//#    This is the behavioral model of a 256 word dual module, which is         #
//#    compatible to an ICE40 sysMEM block (SB_RAM256x16).                      #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 14, 2024                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_dpram_256w
   (//Clock and reset
    input  wire                             clk_i,                                                //module clock

    //RAM interface
    input  wire [7:0]                       raddr_i,                                              //read address
    input  wire [7:0]                       waddr_i,                                              //write address
    input  wire [15:0]                      wdata_i,                                              //write data
    input  wire                             re_i,                                                 //read enable
    input  wire                             we_i,                                                 //write enable
    output reg  [15:0]                      rdata_o);                                             //read data

   //Memory
   //------
   reg [15:0] mem [0:255];
   always @(posedge clk_i) begin
      if (we_i) mem[waddr_i] <= wdata_i;
      if (re_i)      rdata_o <= mem[raddr_i];
   end

endmodule // N1_dpram_256w
