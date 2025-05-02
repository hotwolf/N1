//###############################################################################
//# N1 - Single Ported RAM                                                      #
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
//#    This is the behavioral model of a single ported RAM.                     #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   April 25, 2025                                                            #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_spram
  #(parameter ADDR_WIDTH = 14)
   (//Clock and reset
    input  wire                             clk_i,                                                //module clock

    //RAM interface
    input  wire [ADDR_WIDTH-1:0]            spram_addr_i,                                         //address
    input  wire                             spram_write_i,                                        //write request
    input  wire                             spram_read_i,                                         //read request
    input  wire [15:0]                      spram_wdata_i,                                        //write data
    output reg  [15:0]                      spram_rdata_o);                                       //read data

   //Memory
   //------
   reg [15:0] mem [0:(2**ADDR_WIDTH)-1];
   always @(posedge clk_i) begin
      if (  spram_write_i & ~spram_read_i)  mem[spram_addr_i] <= spram_wdata_i;                   //write access
      if ( ~spram_write_i &  spram_read_i)  spram_rdata_o <= mem[spram_addr_i];                   //read access
      if (~(spram_write_i ^  spram_read_i)) spram_rdata_o <= 16'hcafe;                            //undefined read data
   end
          
endmodule // N1_spram
