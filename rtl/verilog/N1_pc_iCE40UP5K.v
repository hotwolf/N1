//###############################################################################
//# N1 - Program Counter (Address Accumulator)                                  #
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
//#    This module implements a 16 bit accumulator for address calculationsu    #
//#    utilizing a DSP cell (SB_MAC16) instance of the Lattice iCE40UP5K FPGA.  #
//#                                                                             #
//#    The combinational logic address output (pc_addr_o) is intended to be     #
//#    used as memory address. The (internal) accumulator register can serve as #
//#    program counter.                                                         #
//#                                                                             #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 12, 2024                                                         #
//#      - Initial release                                                      #
//#   May 15, 2025                                                              #
//#      - New naming                                                           #
//#   June 2, 2025                                                              #
//#      - Capturing previous PC for interruptable instructions                 #
//###############################################################################
`default_nettype none

module N1_pc
  #(parameter  INT_EXTENSION    = 1)                                      //interrupt extension
   (//Clock and reset
    input  wire                             clk_i,                        //module clock
    input  wire                             async_rst_i,                  //asynchronous reset
    input  wire                             sync_rst_i,                   //synchronous reset


    //Accumulator interface
    input  wire [15:0]                      pc_abs_addr_i,                //absolute address input
    input  wire [15:0]                      pc_rel_addr_i,                //relative address input
    input  wire                             pc_rel_inc_i,                 //increment relative address
    input  wire                             pc_pc_hold_i,                 //maintain PC
    input  wire                             pc_sel_i,                     //1:absolute COF, 0:relative COF
    output wire [15:0]                      pc_next_o,                    //program AGU output
    output wire [15:0]                      pc_prev_o,                    //previous PC

    //Probe signals
    output wire [15:0]                      prb_pc_cur_o,                 //probed current PC
    output wire [15:0]                      prb_pc_prev_o);               //probed previous PC

   //Internal signals
   //----------------
   //Accumulator signals
   reg  [15:0]                              pc_mirror_reg;                //program counter
   reg  [15:0]                              pc_prev_reg;                  //previous program counter
   wire [31:0]                              acc_out;                      //accumulator output

   //SB_MAC16 cell for the AGU accumulator
   //-------------------------------------
   //The "Hi" part of the SB_MAC32 is unused
   //The "Lo" part of the SB_MAC32 implements accumulator for the AGU
   //The output hold register implement the program counter
   //The AGU output is unregistered (= next address)
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
       .TOPADDSUB_LOWERINPUT     (2'b00),                                 //C10,C11    -> plain adder
       .TOPADDSUB_UPPERINPUT     (1'b1),                                  //C12        -> connect to op0
       .TOPADDSUB_CARRYSELECT    (2'b00),                                 //C13,C14    -> no carry
       .BOTOUTPUT_SELECT         (2'b00),                                 //C15,C16    -> unregistered output
       .BOTADDSUB_LOWERINPUT     (2'b00),                                 //C17,C18    -> plain adder
       .BOTADDSUB_UPPERINPUT     (1'b1),                                  //C19        -> connect to program counter
       .BOTADDSUB_CARRYSELECT    (2'b11),                                 //C20,C21    -> add carry via CI input
       .MODE_8x8                 (1'b1),                                  //C22        -> power safe
       .A_SIGNED                 (1'b0),                                  //C23        -> unsigned
       .B_SIGNED                 (1'b0))                                  //C24        -> unsigned
   SB_MAC16_acc
     (.CLK                       (clk_i),                                 //clock input
      .CE                        (1'b1),                                  //clock enable
      .C                         (16'h0000),                              //unused
      .A                         (16'h0000),                              //unused
      .B                         (pc_rel_addr_i),                         //relative COF address
      .D                         (pc_abs_addr_i),                         //absolute COF address
      .AHOLD                     (1'b1),                                  //keep hold register stable
      .BHOLD                     (1'b1),                                  //keep hold register stable
      .CHOLD                     (1'b1),                                  //keep hold register stable
      .DHOLD                     (1'b1),                                  //keep hold register stable
      .IRSTTOP                   (1'b1),                                  //keep hold register in reset
      .IRSTBOT                   (1'b1),                                  //keep hold register in reset
      .ORSTTOP                   (1'b1),                                  //keep hold register in reset
      .ORSTBOT                   (|{async_rst_i,sync_rst_i}),             //use common reset
      .OLOADTOP                  (1'b0),                                  //no bypass
      .OLOADBOT                  (pc_sel_i),                              //absolute COF
      .ADDSUBTOP                 (1'b0),                                  //subtract
      .ADDSUBBOT                 (1'b0),                                  //always use adder
      .OHOLDTOP                  (1'b1),                                  //keep hold register stable
      .OHOLDBOT                  (pc_pc_hold_i),                          //update PC
      .CI                        (pc_rel_inc_i),                          //address increment
      .ACCUMCI                   (1'b0),                                  //no carry
      .SIGNEXTIN                 (1'b0),                                  //no sign extension
      .O                         (acc_out),                               //result
      .CO                        (),                                      //ignore carry output
      .ACCUMCO                   (),                                      //carry bit determines upper word
      .SIGNEXTOUT                ());                                     //ignore sign extension output

   //Mirrored PC
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                  //asynchronous reset
          begin
             pc_mirror_reg      <= 16'h0000;                              //start address
             pc_prev_reg <= 16'h0000;                                     //start address
          end
        else if (sync_rst_i)                                              //synchronous reset
          begin
             pc_mirror_reg      <= 16'h0000;                              //start address
             pc_prev_reg <= 16'h0000;                                     //start address
          end
        else if (~pc_pc_hold_i)                                           //update PC
          begin
             pc_mirror_reg      <= acc_outt[15:0];                        //current PC
             pc_prev_reg <= INT_EXTENSION ? pc_mirror_reg : 16'h0000;     //previous PC
          end
     end // always @ (posedge async_rst_i or posedge clk_i)

   assign pc_next_o     = acc_out[15:0];                                  //opcode fetch address
   assign pc_prev_o     = pc_prev_reg;                                    //return address

   //Probe signals
   assign prb_pc_cur_o  = pc_mirror_reg;                                  //current PC
   assign prb_pc_prev_o  = pc_prev_reg;                                   //previous PC

endmodule // N1_agu_acc
