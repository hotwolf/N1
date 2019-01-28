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
  #(NEG_TRIGGER              = 1'b0,                          //Clock edge -> active clock edge (0:posedge, 1:negedge)
    C_REG                    = 1'b0,                          //C0         -> hold register C (0:bypass, 1:use)
    A_REG                    = 1'b0,                          //C1         -> hold register A (0:bypass, 1:use)
    B_REG                    = 1'b0,                          //C2         -> hold register B (0:bypass, 1:use)
    D_REG                    = 1'b0,                          //C3         -> hold register D (0:bypass, 1:use)
    TOP_8x8_MULT_REG         = 1'b0,                          //C4         -> pipeline register F (0:bypass, 1:use)
    BOT_8x8_MULT_REG         = 1'b0,                          //C5         -> pipeline register G (0:bypass, 1:use)
    PIPELINE_16x16_MULT_REG1 = 1'b0,                          //C6         -> pipeline registers J and K (0:bypass, 1:use)
    PIPELINE_16x16_MULT_REG2 = 1'b0,                          //C7         -> pipeline register  H (0:bypass, 1:use)
    TOPOUTPUT_SELECT         = 2'b00,                         //C8,C9      -> upper output O select
    TOPADDSUB_LOWERINPUT     = 2'b00,                         //C10,C11    -> upper adder input select
    TOPADDSUB_UPPERINPUT     = 1'b1,                          //C12        -> input W (0:accu Q, 1:input C)
    TOPADDSUB_CARRYSELECT    = 2'b00,                         //C13,C14    -> upper adder carry select
    BOTOUTPUT_SELECT         = 2'b00,                         //C15,C16    -> lower output O select
    BOTADDSUB_LOWERINPUT     = 2'b00,                         //C17,C18    -> input Z select
    BOTADDSUB_UPPERINPUT     = 1'b1,                          //C19        -> input Y select
    BOTADDSUB_CARRYSELECT    = 2'b00,                         //C20,C21    -> lower adder carry select
    MODE_8x8                 = 1'b1,                          //C22        -> power safe
    A_SIGNED                 = 1'b0,                          //C23        -> input A (0:unsigned, 1:signed)
    B_SIGNED                 = 1'b0)                          //C24        -> input B (0:unsigned, 1:signed)
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
   wire 		    HCI_mux;
   wire 		    LCI_mux;
   
   //Multiplier outputs
   wire [31:0]                F_mul;
   wire [23:0]                J_mul;
   wire [23:0]                K_mul;
   wire [15:0]                G_mul;
   
    //Adder outputs
   wire [19:0]                L_add;
   wire [17:0]                P_add;
   wire [17:0]                R_add;
     
   //Clock
   //------
   always @(CLK)
     CLK_gated = (CLK ^ NEG_TRIGER) & CE;
   
   //Hold and pipeline registers
   //---------------------------  
   //A		      
   always @(posedge CLK_gated or IRSTTOP)
     if (IRSTTOP)
       A_reg <= 16'h0000;
     else if (~AHOLD)
       A_reg <= A;
   
   //B		      
   always @(posedge CLK_gated or IRSTBOT)
     if (IRSTBOT)
       B_reg <= 16'h0000;
     else if (~BHOLD)
       B_reg <= B;
   
   //C		      
   always @(posedge CLK_gated or IRSTTOP)
     if (IRSTTOP)
       C_reg <= 16'h0000;
     else if (~CHOLD)
       C_reg <= C;
   
   //D		      
   always @(posedge CLK_gated or IRSTBOT)
     if (IRSTBOT)
       D_reg <= 16'h0000;
     else if (~DHOLD)
       D_reg <= D;

   //F		      
   always @(posedge CLK_gated or IRSTTOP)
     if (IRSTTOP)
       F_reg <= 16'h0000;
     else if (~|C22)
       F_reg <= F_mul[15:0];
   
   //G		      
   always @(posedge CLK_gated or IRSTBOT)
     if (IRSTBOT)
       G_reg <= 16'h0000;
     else if (~|C22)
       G_reg <= G_mul[15:0];

   //H		      
   always @(posedge CLK_gated or IRSTBOT)
     if (IRSTBOT)
       H_reg <= 32'h00000000;
     else if (~|C22)
       H_reg <= L_add[31:0];

   //J		      
   always @(posedge CLK_gated or IRSTTOP)
     if (IRSTTOP)
       J_reg <= 16'h0000;
     else if (~|C22)
       J_reg <= J_mul[15:0];
   
   //K		      
   always @(posedge CLK_gated or IRSTBOT)
     if (IRSTBOT)
       K_reg <= 16'h0000;
     else if (~|C22)
       K_reg <= K_mul[15:0];

   //Q		      
   always @(posedge CLK_gated or ORSTTOP)
     if (ORSTTOP)
       Q_reg <= 16'h0000;
     else if (~OHOLDTOP)
       Q_reg <= P_mux;

   //S		      
   always @(posedge CLK_gated or ORSTBOT)
     if (ORSTBOT)
       S_reg <= 16'h0000;
     else if (~OHOLDBOT)
       S_reg <= R_mux;

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

   //F		      
   assign F_mux = |C4 ? F_reg : F_mul[15:0];

   //G		      
   assign G_mux = |C5 ? G_reg : G_mul[15:0];

   //H		      
   assign H_mux = |C7 ? H_reg : L_add[31:0];
   
   //J		      
   assign J_mux = |C6 ? J_reg : J_mul[15:0];

   //K		      
   assign K_mux = |C6 ? K_reg : K_mul[15:0];

   //P		      
   assign P_mux = OLOADTOP ? C_mux : {16{ADDSUBTOP}} ^ P_add[15:0];

   //Q		      
   assign Q_mux = |C9 ? (|C8 ? H_mux[31:16] :
                               F_mux)       :
                        (|C8 ? Q_reg        :
                               P_mux);
  
   //R		      
   assign R_mux = OLOADBOT ? D_mux : {16{ADDSUBBOT}} ^ R_add[15:0];

   //S		      
   assign S_mux = |C16 ? (|C15 ? H_mux[15:0] :
                                 G_mux)      :
                         (|C15 ? S_reg       :
                                 R_mux);

   //W		      
   assign W_mux = |C12 ? C_mux : Q_reg;

   //X		      
   assign X_mux = |C11 ? (|C10 ? {16{Z_mux[15]}} :
			         H_mux[31:16])   :
		         (|C10 ? F_mux           :
 			         A_mux);

   //Y		      
   assign Y_mux = |C19 ? D_mux : S_reg;

   //Z		      
   assign Z_mux = |C18 ? (|C17 ? {16{SIGNEXTIN}} :
			         H_mux[15:0])    :
		         (|C17 ? G_mux           :
 			         B_mux);

   //HCI		      
   assign HCI_mux = |C14 ? (|C13 ? ADDSUBBOT ^ R_add[16] :
			           R_add[16])            :
 		            |C13;
     
   //LCI		      
   assign LCI_mux = |C21 ? (|C20 ? CI       :
			           ACCUMCI) :
 		            |C13;
   
   //Multipliers
   //-----------  
   //F		      
   assign F_mul = {{8{|C23 & A_mux[15]}}, A_mux[15:8]} *
		  {{8{|C24 & B_mux[15]}}, B_mux[15:8]};

   //G
   assign G_mul = A_mux[7:0] * B_mux[7:0];

   //J
   assign J_mul = A_mux[7:0] *
		  {{8{|C24 & B_mux[15]}}, B_mux[15:8]};

   //K
   assign K_mul = {{8{|C23 & A_mux[15]}}, A_mux[15:8]} *
		  B_mux[7:0];

   //Adders
   //------  
   assign L_add = {F_mux, 16'h0000}              +
                  {16'h0000, G_mux}              +
                  {{8{|C24 & J_mux[15]}}, 8'h00} + 
                  {{8{|C22 & K_mux[15]}}, 8'h00};
   
   assign P_add = {15'h0000, HCI__mux}           +
                  ({16{ADDSUBTOP}} ^ W_mux)      + 
                  X_mux;
   
   assign R_add = {15'h0000, LCI__mux}           +
                  ({16{ADDSUBBOT}} ^ Y_mux)      + 
                  Z_mux;

   //Outputs
   //-------  
   assign SIGNEXTOUT = X_mux[15];
   assign CO         = P_add[16] ^ ADDSUBTOP;
   assign ACCUMCO    = P_add[16];
   assign O          = {Q_mux, S_mux};

endmodule // SB_MAC16
