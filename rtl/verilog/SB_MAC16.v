//###############################################################################
//# N1 - Behavioral Model of the SB_MAC16 DSP Cell                              #
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
//#    This is a behavioral model of the SB_MAC16 DSP cell, which ia available  #
//#    on several Lattice iCE40 FPGA devices. This model has been written based #
//#    on the public documentation from Lattice.                                #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 25, 2019                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module SB_MAC16
  #(NEG_TRIGGER              = 1'b0,                          //Clock edge -> posedge
    C_REG                    = 1'b0,                          //C0         -> C input register
    A_REG                    = 1'b0,                          //C1         -> A input register
    B_REG                    = 1'b0,                          //C2         -> B input register
    D_REG                    = 1'b0,                          //C3         -> D input register
    TOP_8x8_MULT_REG         = 1'b0,                          //C4         -> F pipeline register
    BOT_8x8_MULT_REG         = 1'b0,                          //C5         -> G pipeline register
    PIPELINE_16x16_MULT_REG1 = 1'b0,                          //C6         -> J and K pipeline registers
    PIPELINE_16x16_MULT_REG2 = 1'b0,                          //C7         -> H pipeline register
    TOPOUTPUT_SELECT         = 2'b00,                         //C8,C9      -> O upper output
    TOPADDSUB_LOWERINPUT     = 2'b00,                         //C10,C11    -> upper adder input
    TOPADDSUB_UPPERINPUT     = 1'b1,                          //C12        -> W input
    TOPADDSUB_CARRYSELECT    = 2'b00,                         //C13,C14    -> carry to upper adder
    BOTOUTPUT_SELECT         = 2'b00,                         //C15,C16    -> O lower output
    BOTADDSUB_LOWERINPUT     = 2'b00,                         //C17,C18    -> Z input
    BOTADDSUB_UPPERINPUT     = 1'b1,                          //C19        -> Y input
    BOTADDSUB_CARRYSELECT    = 2'b00,                         //C20,C21    -> carry to lower adder
    MODE_8x8                 = 1'b1,                          //C22        -> power safe
    A_SIGNED                 = 1'b0,                          //C23        -> A input signed
    B_SIGNED                 = 1'b0)                          //C24        -> B input signed
   (input  wire                CLK,                           //clock input
    input  wire                CE,                            //clock enable
    input  wire [15:0]         C,                             //adder input
    input  wire [15:0]         A,                             //multiplier input
    input  wire [15:0]         B,                             //multiplier input
    input  wire [15:0]         D,                             //adder input
    input  wire                AHOLD,                         //pipeline register control
    input  wire                BHOLD,                         //pipeline register control
    input  wire                CHOLD,                         //pipeline register control
    input  wire                DHOLD,                         //pipeline register control
    input  wire                IRSTTOP,                       //pipeline register reset
    input  wire                IRSTBOT,                       //pipeline register reset
    input  wire                ORSTTOP,                       //pipeline register reset
    input  wire                ORSTBOT,                       //pipeline register  reset
    input  wire                OLOADTOP,                      //bypass
    input  wire                OLOADBOT,                      //bypass
    input  wire                ADDSUBTOP,                     //add/subtract
    input  wire                ADDSUBBOT,                     //add/subtract
    input  wire                OHOLDTOP,                      //pipeline register control
    input  wire                OHOLDBOT,                      //pipeline register control
    input  wire                CI,                            //carry input
    input  wire                ACCUMCI,                       //carry input
    input  wire                SIGNEXTIN,                     //sign extension
    input  wire [31:0]         O,                             //result
    input  wire                CO,                            //carry output
    input  wire                ACCUMCO,                       //carry output
    input  wire                SIGNEXTOUT);                   //sign extension output

   //Clock
   reg                         CLK_gated;                     //gated internal clock
                         
   //Hold and pipeline registers
   reg  [15:0]                 A_reg;
   reg  [15:0]                 B_reg;
   reg  [15:0]                 C_reg;
   reg  [15:0]                 D_reg;
   reg                         _reg;
   reg                         _reg;
   reg                         _reg;
   reg                         _reg;
   reg                         _reg;
   reg                         _reg;
   reg                         _reg;
   reg                         _reg;
   reg                         _reg;
   reg                         _reg;
   
   //Multiplexer outputs
   wire [15:0]                A_mux;
   wire [15:0]                B_mux;
   wire [15:0]                C_mux;
   wire [15:0]                D_mux;
   wire                        _mux;
   wire                        _mux;
   wire                        _mux;
   wire                        _mux;
   wire                        _mux;
   wire                        _mux;
   wire                        _mux;
   wire                        _mux;
   wire                        _mux;
   wire                        _mux;

   //Multiplier outputs
   
   

   
   //Clock
   //------
   always @(CLK)
     CLK_gated = (CLK ^ NEG_TRIGER) & CE;
   
   //Hold and pipeline registers
   //---------------------------  
   //A		      
   always @(posedge CLK_gated or IRSTTOP)
     if (IRSTTOP)
       A_reg <= 1'b0;
     else if (AHOLD)
       A_reg = A;
   
   //B		      
   always @(posedge CLK_gated or IRSTBOT)
     if (IRSTBOT)
       B_reg <= 1'b0;
     else if (BHOLD)
       B_reg = B;
   
   //C		      
   always @(posedge CLK_gated or IRSTTOP)
     if (IRSTTOP)
       C_reg <= 1'b0;
     else if (CHOLD)
       C_reg = C;
   
   //D		      
   always @(posedge CLK_gated or IRSTBOT)
     if (IRSTBOT)
       D_reg <= 1'b0;
     else if (DHOLD)
       D_reg = D;
   
   //Multiplexers
   //------------  
   //A		      
   assign A_mux = |C1 ? A_reg : A;

   //B		      
   assign B_mux = |C2 ? B_reg : B;

   //C		      
   assign C_mux = |C0 ? C_reg : C;

   //D		      
   assign D_mux = |C3 ? D_reg : D;

   
   
   
endmodule // SB_MAC16
