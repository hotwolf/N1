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
//#    This module implements a 32 bit adder/subtractor utilizing a DSP cell    #
//#    (SB_MAC16) instance of the Lattice iCE40UP5K FPGA.                       #
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
    input  wire                             alu2add_pm_i,                 //operator: 1:op1 - op0, 0:op1 + op0
    input  wire [15:0]                      alu2add_op0_i,                //first operand
    input  wire [15:0]                      alu2add_op1_i);               //second operand (zero if no operator selected)

   //SB_MAC16 cell configured as 32 bit Adder/Subtractor
   //---------------------------------------------------
   SB_MAC16
     #(.NEG_TRIGGER              (1'b0),                                  //Clock edge -> posedge
       .C_REG                    (1'b0),                                  //C0         -> C input unregistered
       .A_REG                    (1'b0),                                  //C1         -> A input unregistered
       .B_REG                    (1'b0),                                  //C2         -> B input unregistered
       .D_REG                    (1'b0),                                  //C3         -> D input unregistered
       .TOP_8x8_MULT_REG         (1'b1),                                  //C4         -> keep unused signals quiet
       .BOT_8x8_MULT_REG         (1'b1),                                  //C5         -> keep unused signals quiet
       .PIPELINE_16x16_MULT_REG1 (1'b1),                                  //C6         -> keep unused signals quiet
       .PIPELINE_16x16_MULT_REG2 (1'b1),                                  //C7         -> keep unused signals quiet
       .TOPOUTPUT_SELECT         (2'b00),                                 //C8,C9      -> unregistered output
       .TOPADDSUB_LOWERINPUT     (2'b00),                                 //C10,C11    -> connect to op0
       .TOPADDSUB_UPPERINPUT     (1'b1),                                  //C12        -> connect to op1
       .TOPADDSUB_CARRYSELECT    (2'b11),                                 //C13,C14    -> Cascade CO from lower Adder/Subtractor
       .BOTOUTPUT_SELECT         (2'b00),                                 //C15,C16    -> unregistered output
       .BOTADDSUB_LOWERINPUT     (2'b00),                                 //C17,C18    -> plain adder
       .BOTADDSUB_UPPERINPUT     (1'b1),                                  //C19        -> connect to op0
       .BOTADDSUB_CARRYSELECT    (2'b00),                                 //C20,C21    -> no carry
       .MODE_8x8                 (1'b1),                                  //C22        -> power safe
       .A_SIGNED                 (1'b0),                                  //C23        -> unsigned
       .B_SIGNED                 (1'b0))                                  //C24        -> unsigned
   SB_MAC16_add
     (.CLK                       (clk_i),                                 //clock input
      .CE                        (1'b1),                                  //clock enable
      .C                         (16'h0000),                              //first operand (upper word)
      .A                         (16'h0000),                              //second operand (upper word)
      .B                         (alu2add_op1_i),                         //second operand
      .D                         (alu2add_op0_i),                         //first operand
      .AHOLD                     (1'b1),                                  //keep hold register stable
      .BHOLD                     (1'b1),                                  //keep hold register stable
      .CHOLD                     (1'b1),                                  //keep hold register stable
      .DHOLD                     (1'b1),                                  //keep hold register stable
      .IRSTTOP                   (1'b1),                                  //keep hold register in reset
      .IRSTBOT                   (1'b1),                                  //keep hold register in reset
      .ORSTTOP                   (1'b1),                                  //keep hold register in reset
      .ORSTBOT                   (1'b1),                                  //use common reset
      .OLOADTOP                  (1'b0),                                  //no bypass
      .OLOADBOT                  (1'b0),                                  //no bypass
      .ADDSUBTOP                 (alu2add_pm_i),                          //operator: 1:op1 - op0, 0:op1 + op0
      .ADDSUBBOT                 (alu2add_pm_i),                          //operator: 1:op1 - op0, 0:op1 + op0
      .OHOLDTOP                  (1'b1),                                  //keep hold register stable
      .OHOLDBOT                  (1'b1),                                  //keep hold register stable
      .CI                        (1'b0),                                  //no carry
      .ACCUMCI                   (1'b0),                                  //no carry
      .SIGNEXTIN                 (1'b0),                                  //no sign extension
      .O                         (add2alu_res_o),                         //result
      .CO                        (),                                      //ignore carry output
      .ACCUMCO                   (),                                      //carry bit determines upper word
      .SIGNEXTOUT                ());                                     //ignore sign extension output

endmodule // N1_alu_add
