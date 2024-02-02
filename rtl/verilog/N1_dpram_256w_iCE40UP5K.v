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
//#    This module instantiates one ICE40 sysMEM block (SB_RAM256x16).          #
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
    input  wire [7:0]                       ram_raddr_i,                                          //read address
    input  wire [7:0]                       ram_waddr_i,                                          //write address
    input  wire [15:0]                      ram_wdata_i,                                          //write data
    input  wire                             ram_re_i,                                             //read enable
    input  wire                             ram_we_i,                                             //write enable
    output wire [15:0]                      ram_rdata_o);                                         //read data

   //Memory
   //------
   SB_RAM40_4K
     #(.WRITE_MODE (0),
       .READ_MODE  (0))
   mem
      (.RCLK       (clk_i),
       .WCLK       (clk_i),
       .RADDR      (ram_raddr_i),
       .WADDR      (ram_waddr_i),
       .WDATA      (ram_wdata_i),
       .RCLKE      (ram_re_i),
       .RE         (1'b1),
       .WCLKE      (ram_we_i),
       .WE         (1'b1),
       .MASK       (15'h0000),
       .RDATA      (ram_rdata_o));

endmodule // N1_dpram_256w
