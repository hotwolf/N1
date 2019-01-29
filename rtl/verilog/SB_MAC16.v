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
  #(parameter   NEG_TRIGGER              = 1'b0,              //Clock edge -> active clock edge (0:posedge, 1:negedge)
    parameter   C_REG                    = 1'b0,              //C0         -> hold register C (0:bypass, 1:use)
    parameter   A_REG                    = 1'b0,              //C1         -> hold register A (0:bypass, 1:use)
    parameter   B_REG                    = 1'b0,              //C2         -> hold register B (0:bypass, 1:use)
    parameter   D_REG                    = 1'b0,              //C3         -> hold register D (0:bypass, 1:use)
    parameter   TOP_8x8_MULT_REG         = 1'b0,              //C4         -> pipeline register F (0:bypass, 1:use)
    parameter   BOT_8x8_MULT_REG         = 1'b0,              //C5         -> pipeline register G (0:bypass, 1:use)
    parameter   PIPELINE_16x16_MULT_REG1 = 1'b0,              //C6         -> pipeline registers J and K (0:bypass, 1:use)
    parameter   PIPELINE_16x16_MULT_REG2 = 1'b0,              //C7         -> pipeline register  H (0:bypass, 1:use)
    parameter   TOPOUTPUT_SELECT         = 2'b00,             //C8,C9      -> upper output O select
    parameter   TOPADDSUB_LOWERINPUT     = 2'b00,             //C10,C11    -> upper adder input select
    parameter   TOPADDSUB_UPPERINPUT     = 1'b1,              //C12        -> input W (0:accu Q, 1:input C)
    parameter   TOPADDSUB_CARRYSELECT    = 2'b00,             //C13,C14    -> upper adder carry select
    parameter   BOTOUTPUT_SELECT         = 2'b00,             //C15,C16    -> lower output O select
    parameter   BOTADDSUB_LOWERINPUT     = 2'b00,             //C17,C18    -> input Z select
    parameter   BOTADDSUB_UPPERINPUT     = 1'b1,              //C19        -> input Y select
    parameter   BOTADDSUB_CARRYSELECT    = 2'b00,             //C20,C21    -> lower adder carry select
    parameter   MODE_8x8                 = 1'b1,              //C22        -> power safe
    parameter   A_SIGNED                 = 1'b0,              //C23        -> input A (0:unsigned, 1:signed)
    parameter   B_SIGNED                 = 1'b0)              //C24        -> input B (0:unsigned, 1:signed)
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
    output wire [31:0]         O,                             //result
    output wire                CO,                            //carry output
    output wire                ACCUMCO,                       //carry output
    output wire                SIGNEXTOUT);                   //sign extension output

   //Clock
   reg                         CLK_gated;                     //gated internal clock

   //Hold and pipeline registers
   reg  [15:0]                 A_reg;
   reg  [15:0]                 B_reg;
   reg  [15:0]                 C_reg;
   reg  [15:0]                 D_reg;
   reg  [15:0]                 F_reg;
   reg  [15:0]                 G_reg;
   reg  [31:0]                 H_reg;
   reg  [15:0]                 J_reg;
   reg  [15:0]                 K_reg;
   reg  [15:0]                 Q_reg;
   reg  [15:0]                 S_reg;

   //Multiplexer outputs
   wire [15:0]                A_mux;
   wire [15:0]                B_mux;
   wire [15:0]                C_mux;
   wire [15:0]                D_mux;
   wire [15:0]                F_mux;
   wire [15:0]                G_mux;
   wire [31:0]                H_mux;
   wire [15:0]                J_mux;
   wire [15:0]                K_mux;
   wire [15:0]                P_mux;
   wire [15:0]                Q_mux;
   wire [15:0]                R_mux;
   wire [15:0]                S_mux;
   wire [15:0]                W_mux;
   wire [15:0]                X_mux;
   wire [15:0]                Y_mux;
   wire [15:0]                Z_mux;
   wire                     HCI_mux;
   wire                     LCI_mux;

   //Multiplier outputs
   wire [31:0]                F_mul;
   wire [23:0]                J_mul;
   wire [23:0]                K_mul;
   wire [15:0]                G_mul;

    //Adder outputs
   wire [31:0]                L_add;
   wire [16:0]                P_add;
   wire [16:0]                R_add;

   //Clock
   //------
   always @(CLK)
     CLK_gated = (CLK ^ NEG_TRIGGER) & CE;

   //Hold and pipeline registers
   //---------------------------
   //A
   always @(posedge CLK_gated or posedge IRSTTOP)
     if (IRSTTOP)
       A_reg <= 16'h0000;
     else if (~AHOLD)
       A_reg <= A;

   //B
   always @(posedge CLK_gated or posedge IRSTBOT)
     if (IRSTBOT)
       B_reg <= 16'h0000;
     else if (~BHOLD)
       B_reg <= B;

   //C
   always @(posedge CLK_gated or posedge IRSTTOP)
     if (IRSTTOP)
       C_reg <= 16'h0000;
     else if (~CHOLD)
       C_reg <= C;

   //D
   always @(posedge CLK_gated or posedge IRSTBOT)
     if (IRSTBOT)
       D_reg <= 16'h0000;
     else if (~DHOLD)
       D_reg <= D;

   //F
   always @(posedge CLK_gated or posedge IRSTTOP)
     if (IRSTTOP)
       F_reg <= 16'h0000;
     else if (~|MODE_8x8)
       F_reg <= F_mul[15:0];

   //G
   always @(posedge CLK_gated or posedge IRSTBOT)
     if (IRSTBOT)
       G_reg <= 16'h0000;
     else if (~|MODE_8x8)
       G_reg <= G_mul[15:0];

   //H
   always @(posedge CLK_gated or posedge IRSTBOT)
     if (IRSTBOT)
       H_reg <= 32'h00000000;
     else if (~|MODE_8x8)
       H_reg <= L_add[31:0];

   //J
   always @(posedge CLK_gated or posedge IRSTTOP)
     if (IRSTTOP)
       J_reg <= 16'h0000;
     else if (~|MODE_8x8)
       J_reg <= J_mul[15:0];

   //K
   always @(posedge CLK_gated or posedge IRSTBOT)
     if (IRSTBOT)
       K_reg <= 16'h0000;
     else if (~|MODE_8x8)
       K_reg <= K_mul[15:0];

   //Q
   always @(posedge CLK_gated or posedge ORSTTOP)
     if (ORSTTOP)
       Q_reg <= 16'h0000;
     else if (~OHOLDTOP)
       Q_reg <= P_mux;

   //S
   always @(posedge CLK_gated or posedge ORSTBOT)
     if (ORSTBOT)
       S_reg <= 16'h0000;
     else if (~OHOLDBOT)
       S_reg <= R_mux;

   //Multiplexers
   //------------
   //A
   assign A_mux = |A_REG ? A_reg : A;

   //B
   assign B_mux = |B_REG ? B_reg : B;

   //C
   assign C_mux = |C_REG ? C_reg : C;

   //D
   assign D_mux = |D_REG ? D_reg : D;

   //F
   assign F_mux = |TOP_8x8_MULT_REG ? F_reg : F_mul[15:0];

   //G
   assign G_mux = |BOT_8x8_MULT_REG ? G_reg : G_mul[15:0];

   //H
   assign H_mux = |PIPELINE_16x16_MULT_REG2 ? H_reg : L_add[31:0];

   //J
   assign J_mux = |PIPELINE_16x16_MULT_REG1 ? J_reg : J_mul[15:0];

   //K
   assign K_mux = |PIPELINE_16x16_MULT_REG1 ? K_reg : K_mul[15:0];

   //P
   assign P_mux = OLOADTOP ? C_mux : {16{ADDSUBTOP}} ^ P_add[15:0];

   //Q
   assign Q_mux = TOPOUTPUT_SELECT[1] ? (TOPOUTPUT_SELECT[0] ? H_mux[31:16] :
                                                               F_mux)       :
                                        (TOPOUTPUT_SELECT[0] ? Q_reg        :
                                                               P_mux);

   //R
   assign R_mux = OLOADBOT ? D_mux : {16{ADDSUBBOT}} ^ R_add[15:0];

   //S
   assign S_mux = BOTOUTPUT_SELECT[1] ? (BOTOUTPUT_SELECT[0] ? H_mux[15:0] :
                                                               G_mux)      :
                                        (BOTOUTPUT_SELECT[0] ? S_reg       :
                                                               R_mux);

   //W
   assign W_mux = |TOPADDSUB_UPPERINPUT ? C_mux : Q_reg;

   //X
   assign X_mux = TOPADDSUB_LOWERINPUT[1] ? (TOPADDSUB_LOWERINPUT[0] ? {16{Z_mux[15]}} :
                                                                       H_mux[31:16])   :
                                            (TOPADDSUB_LOWERINPUT[0] ? F_mux           :
                                                                       A_mux);

   //Y
   assign Y_mux = |BOTADDSUB_UPPERINPUT ? D_mux : S_reg;

   //Z
   assign Z_mux = BOTADDSUB_LOWERINPUT[1] ? (BOTADDSUB_LOWERINPUT[0] ? {16{SIGNEXTIN}} :
                                                                       H_mux[15:0])    :
                                            (BOTADDSUB_LOWERINPUT[0] ? G_mux           :
                                                                       B_mux);

   //HCI
   assign HCI_mux = TOPADDSUB_CARRYSELECT[1] ? (TOPADDSUB_CARRYSELECT[0] ? ADDSUBBOT ^ R_add[16] :
                                                                           R_add[16])            :
                                                TOPADDSUB_CARRYSELECT[0];

   //LCI
   assign LCI_mux = BOTADDSUB_CARRYSELECT[1] ? (BOTADDSUB_CARRYSELECT[0] ? CI       :
                                                                           ACCUMCI) :
                                                BOTADDSUB_CARRYSELECT[0];

   //Multipliers
   //-----------
   //F
   assign F_mul = {{8{|A_SIGNED & A_mux[15]}}, A_mux[15:8]} *
                  {{8{|B_SIGNED & B_mux[15]}}, B_mux[15:8]};

   //G
   assign G_mul = A_mux[7:0] * B_mux[7:0];

   //J
   assign J_mul = A_mux[7:0] *
                  {{8{|B_SIGNED & B_mux[15]}}, B_mux[15:8]};

   //K
   assign K_mul = {{8{|A_SIGNED & A_mux[15]}}, A_mux[15:8]} *
                  B_mux[7:0];

   //Adders
   //------
   assign L_add = {F_mux, 16'h0000}                          +
                  {16'h0000, G_mux}                          +
                  {{8{|B_SIGNED & J_mux[15]}}, J_mux, 8'h00} +
                  {{8{|MODE_8x8 & K_mux[15]}}, K_mux, 8'h00};

   assign P_add = {16'h0000, HCI_mux}             +
                  {1'b0, {16{ADDSUBTOP}} ^ W_mux} +
                  {1'b0, X_mux};

   assign R_add = {16'h0000, LCI_mux}       +
                  {1'b0, {16{ADDSUBBOT}} ^ Y_mux} +
                  {1'b0, Z_mux};

   //Outputs
   //-------
   assign SIGNEXTOUT = X_mux[15];
   assign CO         = P_add[16] ^ ADDSUBTOP;
   assign ACCUMCO    = P_add[16];
   assign O          = {Q_mux, S_mux};

endmodule // SB_MAC16
