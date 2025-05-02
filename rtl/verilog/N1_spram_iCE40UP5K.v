//###############################################################################
//# N1 - Single Ported RAM for iCE40UP5K targets                                #
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
//#    This module inplements a single ported RAM by instantiating              #
//#    SB_SPRAM256KA primitives of the iCE40 family.                            #
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
    input  wire                             clk_i,                                                   //module clock

    //RAM interface
    input  wire [ADDR_WIDTH-1:0]            spram_addr_i,                                            //address
    input  wire                             spram_access_i,                                          //access request
    input  wire                             spram_rwb_i,                                             //data direction
    input  wire [15:0]                      spram_wdata_i,                                           //write data
    output wire  [15:0]                     spram_rdata_o);                                          //read data

   //Determine the required number if SB_SPRAM256KA instances
   localparam MEM_CNT   = (ADDR_WIDTH > 14) ? 2**(ADDR_WIDTH-14) : 1;                                 //number of instantiated memory blocks


   //Memory block selection
   wire [13:0]                              addr;                                                    //memory address
   wire [MEM_CNT-1:0]                       cs;                                                      //chip selects
   wire [(16*MEM_CNT)-1:0]                  rdata;                                                   //concatinated read data
   wire [(16*MEM_CNT)-1:0]                  rdata_shifted;                                           //LSB alligned read data

   //Format memory address
   localparam ADDR_WIDTH_MAX14 = (ADDR_WIDTH > 14) ? 14 : ADDR_WIDTH;                                //addres width, saturated at 14
   localparam ADDR_PAD  = 14 - ADDR_WIDTH_MAX14;                                                     //number of padding pits
   assign addr = {{ADDR_PAD{1'b0}},spram_addr_i[ADDR_WIDTH_MAX14-1:0]};                              //generate 14 bit address

   //Select addressed memory
   localparam ADDR_SELHI = (ADDR_WIDTH > 14) ? ADDR_WIDTH-1 : 0;                                     //memory select index in address
   localparam ADDR_SELLO = (ADDR_WIDTH > 14) ? 14           : 0;                                     //memory select index in address
   assign cs = (ADDR_WIDTH > 14) ? {{MEM_CNT-1{1'b0}},spram_access_i} << spram_addr_i[ADDR_SELHI:ADDR_SELLO] :
                                    {MEM_CNT{spram_access_i}};

   //Multiplex read data
   assign rdata_shifted = (ADDR_WIDTH > 14) ? rdata >>  16 * spram_addr_i[ADDR_SELHI:ADDR_SELLO] :
                          rdata;
   assign spram_rdata_o = rdata_shifted[15:0];

   //Memory instances
   SB_SPRAM256KA mem[MEM_CNT-1:0]
     (.ADDRESS           (addr),                           //address
      .DATAIN            (spram_wdata_i),                  //write data
      .MASKWREN          (4'hf),                           //nibble write mask
      .WREN              (spram_access_i & ~spram_rwb_i),  //write enable
      .CHIPSELECT        (cs),                             //memory select
      .CLOCK             (clk_i),                          //clock
      .STANDBY           (1'b0),                           //standby mode
      .SLEEP             (1'b0),                           //sleep mode
      .POWEROFF          (1'b1),                           //power off
      .DATAOUT           (rdata));                         //read data

endmodule // N1_spram


//SB_SPRAM256K stub for linting
//module SB_SPRAM256KA
//  (input  wire [13:0] ADDRESS,             //address
//   input  wire [15:0] DATAIN,              //write data
//   input  wire [ 3:0] MASKWREN,            //nibble write mask
//   input  wire        WREN,                //write enable
//   input  wire        CHIPSELECT,          //memory select
//   input  wire        CLOCK,               //clock
//   input  wire        STANDBY,             //standby mode
//   input  wire        SLEEP,               //sleep mode
//   input  wire        POWEROFF,            //power off
//   output wire [15:0] DATAOUT);            //read data
//
//   assign DATAOUT = 16'hffff;
//
//endmodule // SB_SPRAM256KA
