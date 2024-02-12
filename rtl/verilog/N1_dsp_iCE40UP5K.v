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
//#    This module is a container for DSP cell (SB_MAC16) instances of the      #
//#    Lattice iCE40UP5K FPGA. The DSP cells are hard instantiated as some of   #
//#    them are shared by different parts of the N1 design.                     #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 10, 2019                                                          #
//#      - Initial release                                                      #
//#   May 8, 2019                                                               #
//#      - Added RTY_I support to PBUS                                          #
//#   October 17, 2019                                                          #
//#      - New stack AGU interface                                              #
//###############################################################################
`default_nettype none

module N1_dsp
  #(//Integration parameters
    parameter   SP_WIDTH   =  12)                                         //width of a stack pointer

   (//Clock and reset
    input  wire                             clk_i,                        //module clock
    input  wire                             async_rst_i,                  //asynchronous reset
    input  wire                             sync_rst_i,                   //synchronous reset

    //Internal interfaces
    //-------------------
    //ALU interface
    output wire [31:0]                      dsp2alu_add_res_o,            //result from adder
    output wire [31:0]                      dsp2alu_mul_res_o,            //result from multiplier
    input  wire                             alu2dsp_add_sel_i,            //1:op1 - op0, 0:op1 + op0
    input  wire                             alu2dsp_mul_sel_i,            //1:signed, 0:unsigned
    input  wire [15:0]                      alu2dsp_add_opd0_i,           //first operand for adder/subtractor
    input  wire [15:0]                      alu2dsp_add_opd1_i,           //second operand for adder/subtractor (zero if no operator selected)
    input  wire [15:0]                      alu2dsp_mul_opd0_i,           //first operand for multipliers
    input  wire [15:0]                      alu2dsp_mul_opd1_i,           //second operand dor multipliers (zero if no operator selected)

    //FC interface
    input  wire                             fc2dsp_pc_hold_i,             //maintain PC
    input  wire                             fc2dsp_radr_inc_i,            //increment relative address

    //LS interface
    output wire                             dsp2ls_overflow_o,            //stacks overlap
    output wire                             dsp2ls_sp_carry_o,            //carry of inc/dec operation
    output wire [SP_WIDTH-1:0]              dsp2ls_sp_next_o,             //next PSP or RSP
    input  wire                             ls2dsp_sp_opr_i,              //0:inc, 1:dec
    input  wire                             ls2dsp_sp_sel_i,              //0:PSP, 1:RSP
    input  wire [SP_WIDTH-1:0]              ls2dsp_psp_i,                 //PSP
    input  wire [SP_WIDTH-1:0]              ls2dsp_rsp_i,                 //RSP

    //PAGU interface
    output wire [15:0]                      dsp2pagu_adr_o,               //program AGU output
    input  wire                             pagu2dsp_adr_sel_i,           //1:absolute COF, 0:relative COF
    input  wire [15:0]                      pagu2dsp_aadr_i,              //absolute COF address
    input  wire [15:0]                      pagu2dsp_radr_i,              //relative COF address

    //Probe signals
    output wire [15:0]                      prb_dsp_pc_o,                 //PC
    output wire [SP_WIDTH-1:0]              prb_dsp_psp_o,                //PSP
    output wire [SP_WIDTH-1:0]              prb_dsp_rsp_o);               //RSP

   //Internal signals
   //----------------
   //ALU
   wire                                     alu_add_c;                    //ALU adder carry bit
   wire [31:0]                              alu_add_out;                  //ALU adder output
   wire [31:0]                              alu_umul_out;                 //ALU unsigned multiplier output
   wire [31:0]                              alu_smul_out;                 //ALU signed multiplier output
   //Program AGU
   reg  [15:0]                              pc_mirror_reg;                //program counter
   wire [31:0]                              pagu_out;                     //program AGU output
   //Stack AGUs
   wire [15:0]                              sagu_in;                      //Stack AGU input
   wire [31:0]                              sagu_out;                     //Stack AGU output

   //Shared SB_MAC16 cell for the program AGU and the ALU adder
   //----------------------------------------------------------
   //The "Hi" SB_MAC16part of the SB_MAC32 implements the ALU adder
   //Inputs and outputs of the ALU adder are unregistered
   //The "Lo" part of the SB_MAC32 implements the program AGU
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
   SB_MAC16_pagu
     (.CLK                       (clk_i),                                 //clock input
      .CE                        (1'b1),                                  //clock enable
      .C                         (alu2dsp_add_opd1_i),                    //op1
      .A                         (alu2dsp_add_opd0_i),                    //op0
      .B                         (pagu2dsp_radr_i),                       //relative COF address
      .D                         (pagu2dsp_aadr_i),                       //absolute COF address
      .AHOLD                     (1'b1),                                  //keep hold register stable
      .BHOLD                     (1'b1),                                  //keep hold register stable
      .CHOLD                     (1'b1),                                  //keep hold register stable
      .DHOLD                     (1'b1),                                  //keep hold register stable
      .IRSTTOP                   (1'b1),                                  //keep hold register in reset
      .IRSTBOT                   (1'b1),                                  //keep hold register in reset
      .ORSTTOP                   (1'b1),                                  //keep hold register in reset
      .ORSTBOT                   (|{async_rst_i,sync_rst_i}),             //use common reset
      .OLOADTOP                  (1'b0),                                  //no bypass
      .OLOADBOT                  (pagu2dsp_adr_sel_i),                    //absolute COF
      .ADDSUBTOP                 (alu2dsp_add_sel_i),                     //subtract
      .ADDSUBBOT                 (1'b0),                                  //always use adder
      .OHOLDTOP                  (1'b1),                                  //keep hold register stable
      .OHOLDBOT                  (fc2dsp_pc_hold_i),                      //update PC
      .CI                        (fc2dsp_radr_inc_i),                     //address increment
      .ACCUMCI                   (1'b0),                                  //no carry
      .SIGNEXTIN                 (1'b0),                                  //no sign extension
      .O                         (pagu_out),                              //result
      .CO                        (),                                      //ignore carry output
      .ACCUMCO                   (alu_add_c),                             //carry bit determines upper word
      .SIGNEXTOUT                ());                                     //ignore sign extension output

   //Mirrored PC
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                  //asynchronous reset
          pc_mirror_reg <= 16'h0000;                                      //reset PC
        else if (sync_rst_i)                                              //synchronous reset
          pc_mirror_reg <= 16'h0000;                                      //reset PC
        else if (~fc2dsp_pc_hold_i)                                       //update PC
          pc_mirror_reg <= pagu_out[15:0];                                //
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Outputs
   assign dsp2alu_add_res_o = {{16{alu_add_c}}, pagu_out[31:16]};         //adder output
   assign dsp2pagu_adr_o    = pagu_out[15:0];                             //AGU autput

   //Probe signals
   assign prb_dsp_pc_o      = pc_mirror_reg;                              //PC

   //Shared SB_MAC32 cell for both stack AGUs
   //----------------------------------------
   //The "Hi" part of the SB_MAC32 monitors stack overflows
   //The "Lo" part of the SB_MAC32 increments or decrements either stack pointer
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
       .TOPADDSUB_UPPERINPUT     (1'b1),                                  //C12        -> connect PSP (C)
       .TOPADDSUB_CARRYSELECT    (2'b00),                                 //C13,C14    -> no carry
       .BOTOUTPUT_SELECT         (2'b00),                                 //C15,C16    -> unregistered output
       .BOTADDSUB_LOWERINPUT     (2'b00),                                 //C17,C18    -> plain adder
       .BOTADDSUB_UPPERINPUT     (1'b1),                                  //C19        -> connect to muxed SP (D)
       .BOTADDSUB_CARRYSELECT    (2'b01),                                 //C20,C21    -> increment
       .MODE_8x8                 (1'b1),                                  //C22        -> power safe
       .A_SIGNED                 (1'b0),                                  //C23        -> unsigned
       .B_SIGNED                 (1'b0))                                  //C24        -> unsigned
   SB_MAC16_sagu
     (.CLK                       (clk_i),                                 //clock input
      .CE                        (1'b1),                                  //clock enable
      .C                         ({{16-SP_WIDTH{1'b0}},ls2dsp_psp_i}),    //PSP
      .A                         ({{16-SP_WIDTH{1'b0}},ls2dsp_rsp_i}),    //RSP
      .B                         (16'h0000),                              //zero
      .D                         (sagu_in),                               //muxed SP
      .AHOLD                     (1'b1),                                  //keep hold register stable
      .BHOLD                     (1'b1),                                  //keep hold register stable
      .CHOLD                     (1'b1),                                  //keep hold register stable
      .DHOLD                     (1'b1),                                  //keep hold register stable
      .IRSTTOP                   (1'b1),                                  //keep hold register in reset
      .IRSTBOT                   (1'b1),                                  //keep hold register in reset
      .ORSTTOP                   (1'b1),                                  //keep in reset
      .ORSTBOT                   (1'b1),                                  //keep in reset
      .OLOADTOP                  (1'b0),                                  //no load
      .OLOADBOT                  (1'b0),                                  //no load
      .ADDSUBTOP                 (1'b0),                                  //always use adder
      .ADDSUBBOT                 (ls2dsp_sp_opr_i),                       //0:inc, 1:dec
      .OHOLDTOP                  (1'b1),                                  //keep hold register stable
      .OHOLDBOT                  (1'b1),                                  //keep hold register stable
      .CI                        (1'b0),                                  //no carry
      .ACCUMCI                   (1'b0),                                  //no carry
      .SIGNEXTIN                 (1'b0),                                  //no sign extension
      .O                         (sagu_out),                              //result
      .CO                        (),                                      //ignore carry output
      .ACCUMCO                   (),                                      //ignore carry output
      .SIGNEXTOUT                ());                                     //ignore sign extension output

   //Inputs
   assign sagu_in           = {{16-SP_WIDTH{1'b0}},                       //stack AGU input
                               (ls2dsp_sp_sel_i ? ls2dsp_rsp_i :          // 1:RSP
                                                  ls2dsp_psp_i)};         // 0:PSP
   //Outputs
   assign dsp2ls_overflow_o = sagu_out[SP_WIDTH+16];                      //stacks overlap
   assign dsp2ls_sp_carry_o = sagu_out[SP_WIDTH];                         //carry of inc/dec operation
   assign dsp2ls_sp_next_o  = sagu_out[SP_WIDTH-1:0];                     //next PSP or RSP

   //SB_MAC32 cell for unsigned multiplications
   //-------------------------------------------
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
       .A_SIGNED                 (1'b0),                                  //C23        -> unsigned
       .B_SIGNED                 (1'b0))                                  //C24        -> unsigned
   SB_MAC16_umul
     (.CLK                       (1'b0),                                  //no clock
      .CE                        (1'b0),                                  //no clock
      .C                         (16'h0000),                              //not in use
      .A                         (alu2dsp_mul_opd0_i),                    //op0
      .B                         (alu2dsp_mul_opd1_i),                    //op1
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
      .O                         (alu_umul_out),                          //result
      .CO                        (),                                      //ignore carry output
      .ACCUMCO                   (),                                      //ignore carry output
      .SIGNEXTOUT                ());                                     //ignore sign extension output

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
      .A                         (alu2dsp_mul_opd0_i),                    //op0
      .B                         (alu2dsp_mul_opd1_i),                    //op1
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
      .O                         (alu_smul_out),                          //result
      .CO                        (),                                      //ignore carry output
      .ACCUMCO                   (),                                      //ignore carry output
      .SIGNEXTOUT                ());                                     //ignore sign extension output

   //Output
   assign dsp2alu_mul_res_o = {(alu2dsp_mul_sel_i ? alu_smul_out[31:16] : alu_umul_out[31:16]),
                                                                          alu_umul_out[15:0]};

endmodule // N1_dsp
