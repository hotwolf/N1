//###############################################################################
//# N1 - DSP Cell Partition for the Lattice iCE40UP5K FPGA                      #
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
//#    This module implements a 16 bit signed multiplier utilizing a DSP cell   #
//#    (SB_MAC16) instance of the Lattice iCE40UP5K FPGA.                       #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 11, 2024                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_alu_smul
   (//Clock and reset
    //input  wire                           clk_i,                        //module clock
    //input  wire                           async_rst_i,                  //asynchronous reset
    //input  wire                           sync_rst_i,                   //synchronous reset

    //ALU interface
    output wire [31:0]                      smul2alu_res_o,               //result
    input  wire [15:0]                      alu2smul_opd0_i,              //first operand
    input  wire [15:0]                      alu2smul_opd1_i);             //second operand


   //SB_MAC32 cell for signed multiplications
   //----------------------------------------
   //Unsigned 16x16 bit multiplication
   //Neither inputs nor outputs are registered
   SB_MAC16
     #(.NEG_TRIGGER              (1'b0),                                  //Clock edge -> posedge
       .C_REG                    (1'b1),                                  //C0         -> keep unused signals quiet
       .A_REG                    (1'b0),                                  //C1         -> A input unregistered
       .B_REG                    (1'b0),                                  //C2         -> B input unregistered
       .D_REG                    (1'b1),                                  //C3         -> keep unused signals quiet
       .TOP_8x8_MULT_REG         (1'b0),                                  //C4         -> pipeline register bypassed
       .BOT_8x8_MULT_REG         (1'b0),                                  //C5         -> pipeline register bypassed
       .PIPELINE_16x16_MULT_REG1 (1'b0),                                  //C6         -> pipeline register bypassed
       .PIPELINE_16x16_MULT_REG2 (1'b0),                                  //C7         -> pipeline register bypassed
       .TOPOUTPUT_SELECT         (2'b11),                                 //C8,C9      -> upper word of product
       .TOPADDSUB_LOWERINPUT     (2'b00),                                 //C10,C11    -> adder not in use (any configuration is fine)
       .TOPADDSUB_UPPERINPUT     (1'b1),                                  //C12        -> connect to constant input
       .TOPADDSUB_CARRYSELECT    (2'b00),                                 //C13,C14    -> no carry
       .BOTOUTPUT_SELECT         (2'b11),                                 //C15,C16    -> lower word of product
       .BOTADDSUB_LOWERINPUT     (2'b00),                                 //C17,C18    -> adder not in use (any configuration is fine)
       .BOTADDSUB_UPPERINPUT     (1'b1),                                  //C19        -> connect to constant input
       .BOTADDSUB_CARRYSELECT    (2'b00),                                 //C20,C21    -> no carry
       .MODE_8x8                 (1'b1),                                  //C22        -> power safe
       .A_SIGNED                 (1'b1),                                  //C23        -> signed
       .B_SIGNED                 (1'b1))                                  //C24        -> signed
   SB_MAC16_smul
     (.CLK                       (1'b0),                                  //no clock
      .CE                        (1'b0),                                  //no clock
      .C                         (16'h0000),                              //not in use
      .A                         (alu2smul_opd0_i),                       //first operand
      .B                         (alu2smul_opd1_i),                       //second operand
      .D                         (16'h0000),                              //not in use
      .AHOLD                     (1'b1),                                  //keep hold register stable
      .BHOLD                     (1'b1),                                  //keep hold register stable
      .CHOLD                     (1'b1),                                  //keep hold register stable
      .DHOLD                     (1'b1),                                  //keep hold register stable
      .IRSTTOP                   (1'b1),                                  //keep hold register in reset
      .IRSTBOT                   (1'b1),                                  //keep hold register in reset
      .ORSTTOP                   (1'b1),                                  //keep hold register in reset
      .ORSTBOT                   (1'b1),                                  //keep hold register in reset
      .OLOADTOP                  (1'b1),                                  //keep unused signals quiet
      .OLOADBOT                  (1'b1),                                  //keep unused signals quiet
      .ADDSUBTOP                 (1'b0),                                  //unused
      .ADDSUBBOT                 (1'b0),                                  //unused
      .OHOLDTOP                  (1'b1),                                  //keep hold register stable
      .OHOLDBOT                  (1'b1),                                  //keep hold register stable
      .CI                        (1'b0),                                  //no carry
      .ACCUMCI                   (1'b0),                                  //no carry
      .SIGNEXTIN                 (1'b0),                                  //no sign extension
      .O                         (smul2alu_res_o),                        //result
      .CO                        (),                                      //ignore carry output
      .ACCUMCO                   (),                                      //ignore carry output
      .SIGNEXTOUT                ());                                     //ignore sign extension output

endmodule // N1_alu_smul
