//###############################################################################
//# N1 - Formal Testbench - Behavioral Model of the SB_MAC16 DSP Cell           #
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
//#    This is the the formal testbench for the behavioral model of the .       #
//#    SB_MAC16 DSP cell.                                                       #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 12, 2019                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

//DUT configuration
//=================
//Program AGU configuration
//-------------------------
`ifdef CONF_PAGU
`define NEG_TRIGGER                     1'b0                         //Clock edge -> posedge
`define C_REG                           1'b0                         //C0         -> C input unregistered
`define A_REG                           1'b0                         //C1         -> A input unregistered
`define B_REG                           1'b0                         //C2         -> B input unregistered
`define D_REG                           1'b0                         //C3         -> D input unregistered
`define TOP_8x8_MULT_REG                1'b1                         //C4         -> keep unused signals quiet
`define BOT_8x8_MULT_REG                1'b1                         //C5         -> keep unused signals quiet
`define PIPELINE_16x16_MULT_REG1        1'b1                         //C6         -> keep unused signals quiet
`define PIPELINE_16x16_MULT_REG2        1'b1                         //C7         -> keep unused signals quiet
`define TOPOUTPUT_SELECT                2'b00                        //C8,C9      -> unregistered output
`define TOPADDSUB_LOWERINPUT            2'b00                        //C10,C11    -> plain adder
`define TOPADDSUB_UPPERINPUT            1'b1                         //C12        -> connect to op0
`define TOPADDSUB_CARRYSELECT           2'b00                        //C13,C14    -> no carry
`define BOTOUTPUT_SELECT                2'b00                        //C15,C16    -> unregistered output
`define BOTADDSUB_LOWERINPUT            2'b00                        //C17,C18    -> plain adder
`define BOTADDSUB_UPPERINPUT            1'b1                         //C19        -> connect to program counter
`define BOTADDSUB_CARRYSELECT           2'b00                        //C20,C21    -> no carry
`define MODE_8x8                        1'b1                         //C22        -> power safe
`define A_SIGNED                        1'b0                         //C23        -> unsigned
`define B_SIGNED                        1'b0                         //C24        -> unsigned
`endif

//Stack AGU configuration
//-----------------------
`ifdef CONF_SAGU
`define NEG_TRIGGER                     1'b0                         //Clock edge -> posedge
`define C_REG                           1'b0                         //C0         -> C input unregistered
`define A_REG                           1'b0                         //C1         -> A input unregistered
`define B_REG                           1'b0                         //C2         -> B input unregistered
`define D_REG                           1'b0                         //C3         -> D input unregistered
`define TOP_8x8_MULT_REG                1'b1                         //C4         -> keep unused signals quiet
`define BOT_8x8_MULT_REG                1'b1                         //C5         -> keep unused signals quiet
`define PIPELINE_16x16_MULT_REG1        1'b1                         //C6         -> keep unused signals quiet
`define PIPELINE_16x16_MULT_REG2        1'b1                         //C7         -> keep unused signals quiet
`define TOPOUTPUT_SELECT                2'b01                        //C8,C9      -> registered output
`define TOPADDSUB_LOWERINPUT            2'b00                        //C10,C11    -> plain adder
`define TOPADDSUB_UPPERINPUT            1'b0                         //C12        -> connect to stack pointer
`define TOPADDSUB_CARRYSELECT           2'b00                        //C13,C14    -> no carry
`define BOTOUTPUT_SELECT                2'b01                        //C15,C16    -> registered output
`define BOTADDSUB_LOWERINPUT            2'b00                        //C17,C18    -> plain adder
`define BOTADDSUB_UPPERINPUT            1'b1                         //C19        -> connect to stack pointer
`define BOTADDSUB_CARRYSELECT           2'b00                        //C20,C21    -> no carry
`define MODE_8x8                        1'b1                         //C22        -> power safe
`define A_SIGNED                        1'b0                         //C23        -> unsigned
`define B_SIGNED                        1'b0                         //C24        -> unsigned
`endif

//Unsigned multiplier configuration
//---------------------------------
`ifdef CONF_UMUL
`define NEG_TRIGGER                     1'b0                         //Clock edge -> posedge
`define C_REG                           1'b1                         //C0         -> keep unused signals quiet
`define A_REG                           1'b0                         //C1         -> A input unregistered
`define B_REG                           1'b0                         //C2         -> B input unregistered
`define D_REG                           1'b1                         //C3         -> keep unused signals quiet
`define TOP_8x8_MULT_REG                1'b0                         //C4         -> pipeline register bypassed
`define BOT_8x8_MULT_REG                1'b0                         //C5         -> pipeline register bypassed
`define PIPELINE_16x16_MULT_REG1        1'b0                         //C6         -> pipeline register bypassed
`define PIPELINE_16x16_MULT_REG2        1'b0                         //C7         -> pipeline register bypassed
`define TOPOUTPUT_SELECT                2'b11                        //C8,C9      -> upper word of product
`define TOPADDSUB_LOWERINPUT            2'b00                        //C10,C11    -> adder not in use (any configuration is fine)
`define TOPADDSUB_UPPERINPUT            1'b1                         //C12        -> connect to constant input
`define TOPADDSUB_CARRYSELECT           2'b00                        //C13,C14    -> no carry
`define BOTOUTPUT_SELECT                2'b11                        //C15,C16    -> lower word of product
`define BOTADDSUB_LOWERINPUT            2'b00                        //C17,C18    -> adder not in use (any configuration is fine)
`define BOTADDSUB_UPPERINPUT            1'b1                         //C19        -> connect to constant input
`define BOTADDSUB_CARRYSELECT           2'b00                        //C20,C21    -> no carry
`define MODE_8x8                        1'b1                         //C22        -> power safe
`define A_SIGNED                        1'b0                         //C23        -> unsigned
`define B_SIGNED                        1'b0                         //C24        -> unsigned
`endif

//Signed multiplier configuration
//-------------------------------
`ifdef CONF_SMUL
`define NEG_TRIGGER                     1'b0                         //Clock edge -> posedge
`define C_REG                           1'b1                         //C0         -> keep unused signals quiet
`define A_REG                           1'b0                         //C1         -> A input unregistered
`define B_REG                           1'b0                         //C2         -> B input unregistered
`define D_REG                           1'b1                         //C3         -> keep unused signals quiet
`define TOP_8x8_MULT_REG                1'b0                         //C4         -> pipeline register bypassed
`define BOT_8x8_MULT_REG                1'b0                         //C5         -> pipeline register bypassed
`define PIPELINE_16x16_MULT_REG1        1'b0                         //C6         -> pipeline register bypassed
`define PIPELINE_16x16_MULT_REG2        1'b0                         //C7         -> pipeline register bypassed
`define TOPOUTPUT_SELECT                2'b11                        //C8,C9      -> upper word of product
`define TOPADDSUB_LOWERINPUT            2'b00                        //C10,C11    -> adder not in use (any configuration is fine)
`define TOPADDSUB_UPPERINPUT            1'b1                         //C12        -> connect to constant input
`define TOPADDSUB_CARRYSELECT           2'b00                        //C13,C14    -> no carry
`define BOTOUTPUT_SELECT                2'b11                        //C15,C16    -> lower word of product
`define BOTADDSUB_LOWERINPUT            2'b00                        //C17,C18    -> adder not in use (any configuration is fine)
`define BOTADDSUB_UPPERINPUT            1'b1                         //C19        -> connect to constant input
`define BOTADDSUB_CARRYSELECT           2'b00                        //C20,C21    -> no carry
`define MODE_8x8                        1'b1                         //C22        -> power safe
`define A_SIGNED                        1'b1                         //C23        -> signed
`define B_SIGNED                        1'b1                         //C24        -> signed
`endif

//Fall back
//---------
`ifndef NEG_TRIGGER
`define NEG_TRIGGER                     1'b0                         //Clock edge
`endif
`ifndef C_REG
`define C_REG                           1'b0                         //C0
`endif
`ifndef A_REG
`define A_REG                           1'b0                         //C1
`endif
`ifndef B_REG
`define B_REG                           1'b0                         //C2
`endif
`ifndef D_REG
`define D_REG                           1'b0                         //C3
`endif
`ifndef TOP_8x8_MULT_REG
`define TOP_8x8_MULT_REG                1'b0                         //C4
`endif
`ifndef BOT_8x8_MULT_REG
`define BOT_8x8_MULT_REG                1'b0                         //C5
`endif
`ifndef PIPELINE_16x16_MULT_REG1
`define PIPELINE_16x16_MULT_REG1        1'b0                         //C6
`endif
`ifndef PIPELINE_16x16_MULT_REG2
`define PIPELINE_16x16_MULT_REG2        1'b0                         //C7
`endif
`ifndef TOPOUTPUT_SELECT
`define TOPOUTPUT_SELECT                2'b00                        //C8,C9
`endif
`ifndef TOPADDSUB_LOWERINPUT
`define TOPADDSUB_LOWERINPUT            2'b00                        //C10,C11
`endif
`ifndef TOPADDSUB_UPPERINPUT
`define TOPADDSUB_UPPERINPUT            1'b1                         //C12
`endif
`ifndef TOPADDSUB_CARRYSELECT
`define TOPADDSUB_CARRYSELECT           2'b00                        //C13,C14
`endif
`ifndef BOTOUTPUT_SELECT
`define BOTOUTPUT_SELECT                2'b00                        //C15,C16
`endif
`ifndef BOTADDSUB_LOWERINPUT
`define BOTADDSUB_LOWERINPUT            2'b00                        //C17,C18
`endif
`ifndef BOTADDSUB_UPPERINPUT
`define BOTADDSUB_UPPERINPUT            1'b0                         //C19
`endif
`ifndef BOTADDSUB_CARRYSELECT
`define BOTADDSUB_CARRYSELECT           2'b00                        //C20,C21
`endif
`ifndef MODE_8x8
`define MODE_8x8                        1'b0                         //C22
`endif
`ifndef A_SIGNED
`define A_SIGNED                        1'b0                         //C23
`endif
`ifndef B_SIGNED
`define B_SIGNED                        1'b0                         //C24
`endif

module ftb_SB_MAC16
   (input  wire                         CLK,                         //clock input
    input  wire                         CE,                          //clock enable
    input  wire [15:0]                  C,                           //adder input
    input  wire [15:0]                  A,                           //multiplier input
    input  wire [15:0]                  B,                           //multiplier input
    input  wire [15:0]                  D,                           //adder input
    input  wire                         AHOLD,                       //pipeline register control
    input  wire                         BHOLD,                       //pipeline register control
    input  wire                         CHOLD,                       //pipeline register control
    input  wire                         DHOLD,                       //pipeline register control
    input  wire                         IRSTTOP,                     //pipeline register reset
    input  wire                         IRSTBOT,                     //pipeline register reset
    input  wire                         ORSTTOP,                     //pipeline register reset
    input  wire                         ORSTBOT,                     //pipeline register  reset
    input  wire                         OLOADTOP,                    //bypass
    input  wire                         OLOADBOT,                    //bypass
    input  wire                         ADDSUBTOP,                   //add/subtract
    input  wire                         ADDSUBBOT,                   //add/subtract
    input  wire                         OHOLDTOP,                    //pipeline register control
    input  wire                         OHOLDBOT,                    //pipeline register control
    input  wire                         CI,                          //carry input
    input  wire                         ACCUMCI,                     //carry input
    input  wire                         SIGNEXTIN,                   //sign extension
    output wire [31:0]                  O,                           //result
    output wire                         CO,                          //carry output
    output wire                         ACCUMCO,                     //carry output
    output wire                         SIGNEXTOUT);                 //sign extension output

   //Instantiation
   //=============
   SB_MAC16
     #(.NEG_TRIGGER                     (`NEG_TRIGGER),              //Clock edge
       .C_REG                           (`C_REG),                    //C0
       .A_REG                           (`A_REG),                    //C1
       .B_REG                           (`B_REG),                    //C2
       .D_REG                           (`D_REG),                    //C3
       .TOP_8x8_MULT_REG                (`TOP_8x8_MULT_REG),         //C4
       .BOT_8x8_MULT_REG                (`BOT_8x8_MULT_REG),         //C5
       .PIPELINE_16x16_MULT_REG1        (`PIPELINE_16x16_MULT_REG1), //C6
       .PIPELINE_16x16_MULT_REG2        (`PIPELINE_16x16_MULT_REG2), //C7
       .TOPOUTPUT_SELECT                (`TOPOUTPUT_SELECT),         //C8,C9
       .TOPADDSUB_LOWERINPUT            (`TOPADDSUB_LOWERINPUT),     //C10,C11
       .TOPADDSUB_UPPERINPUT            (`TOPADDSUB_UPPERINPUT),     //C12
       .TOPADDSUB_CARRYSELECT           (`TOPADDSUB_CARRYSELECT),    //C13,C14
       .BOTOUTPUT_SELECT                (`BOTOUTPUT_SELECT),         //C15,C16
       .BOTADDSUB_LOWERINPUT            (`BOTADDSUB_LOWERINPUT),     //C17,C18
       .BOTADDSUB_UPPERINPUT            (`BOTADDSUB_UPPERINPUT),     //C19
       .BOTADDSUB_CARRYSELECT           (`BOTADDSUB_CARRYSELECT),    //C20,C21
       .MODE_8x8                        (`MODE_8x8),                 //C22
       .A_SIGNED                        (`A_SIGNED),                 //C23
       .B_SIGNED                        (`B_SIGNED))                 //C24
   DUT
     (.CLK                              (CLK),                       //clock input
      .CE                               (CE),                        //clock enable
      .C                                (C),                         //adder input
      .A                                (A),                         //multiplier input
      .B                                (B),                         //multiplier input
      .D                                (D),                         //adder input
      .AHOLD                            (AHOLD),                     //pipeline register control
      .BHOLD                            (BHOLD),                     //pipeline register control
      .CHOLD                            (CHOLD),                     //pipeline register control
      .DHOLD                            (DHOLD),                     //pipeline register control
      .IRSTTOP                          (IRSTTOP),                   //pipeline register reset
      .IRSTBOT                          (IRSTBOT),                   //pipeline register reset
      .ORSTTOP                          (ORSTTOP),                   //pipeline register reset
      .ORSTBOT                          (ORSTBOT),                   //pipeline register  reset
      .OLOADTOP                         (OLOADTOP),                  //bypass
      .OLOADBOT                         (OLOADBOT),                  //bypass
      .ADDSUBTOP                        (ADDSUBTOP),                 //add/subtract
      .ADDSUBBOT                        (ADDSUBBOT),                 //add/subtract
      .OHOLDTOP                         (OHOLDTOP),                  //pipeline register control
      .OHOLDBOT                         (OHOLDBOT),                  //pipeline register control
      .CI                               (CI),                        //carry input
      .ACCUMCI                          (ACCUMCI),                   //carry input
      .SIGNEXTIN                        (SIGNEXTIN),                 //sign extension
      .O                                (O),                         //result
      .CO                               (CO),                        //carry output
      .ACCUMCO                          (ACCUMCO),                   //carry output
      .SIGNEXTOUT                       (SIGNEXTOUT));               //sign extension output

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

`endif //  `ifdef FORMAL

endmodule // ftb_SB_MAC16
