//###############################################################################
//# N1 - Hard IP Partition for the Lattice iCE40UP5K FPGA                       #
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
//#    This is the top level of the partition, containing hard all IP for the   #
//#    N1 processor. There are multiple implementations of this block, each     #
//#    specific to one of the supported target FPGAs. The target-specific       #
//#    implementation is chosen at the file collection for synthesis or         #
//#    simulation.                                                              #
//#    This particular implementation is customized for the Lattice iCE40UP5K   #
//#    FPGA.                                                                    #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 10, 2019                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_hard
  #(parameter   SP_WIDTH   =  8,                               //width of a stack pointer
    localparam  CELL_WIDTH = 16,                               //width of a cell
    localparam  PC_WIDTH   = 15)                               //width of the program counter

   (//Clock and reset
    input  wire                             clk_i,             //module clock
    input  wire                             async_rst_i,       //asynchronous reset
    input  wire                             sync_rst_i,        //synchronous reset

    //Lower parameter stack AGU (stack grows lower addresses)
    input  wire                             lps_agu_psh_i,     //push (decrement address)
    input  wire                             lps_agu_pul_i,     //pull (increment address)
    input  wire                             lps_agu_rst_i,     //reset AGU
    output wire [SP_WIDTH-1:0]              lps_agu_o,         //result

    //Lower return stack AGU (stack grows higher addresses)
    input  wire                             lrs_agu_psh_i,     //push (increment address)
    input  wire                             lrs_agu_pul_i,     //pull (decrement address)
    input  wire                             lrs_agu_rst_i,     //reset AGU
    output wire [SP_WIDTH-1:0]              lrs_agu_o,         //result

    //Program Counter
    input  wire                             pc_abs_i,          //drive absolute address (relative otherwise)
    input  wire                             pc_update_i,       //update PC
    input  wire [PC_WIDTH-1:0]              pc_rel_adr_i,      //relative COF address
    input  wire [PC_WIDTH-1:0]              pc_abs_adr_i,      //absolute COF address
    output wire [PC_WIDTH-1:0]              pc_next_o,         //result

    //ALU
    input wire                              alu_hm_sub_add_b_i,   //0:op1 + op0, 1:op1 + op0
    input wire                              alu_hm_smul_umul_b_i, //0:signed, 1:unsigned
    input wire  [CELL_WIDTH-1:0]            alu_hm_add_op0_i,     //first operand for adder/subtractor
    input wire  [CELL_WIDTH-1:0]            alu_hm_add_op1_i,     //second operand for adder/subtractor (zero if no operator selected)
    input wire  [CELL_WIDTH-1:0]            alu_hm_mul_op0_i,     //first operand for multipliers
    input wire  [CELL_WIDTH-1:0]            alu_hm_mul_op1_i,     //second operand dor multipliers (zero if no operator selected)
    output wire [(2*CELL_WIDTH)-1:0]        alu_hm_add_o,        //result from adder
    output wire [(2*CELL_WIDTH)-1:0]        alu_hm_mul_o);        //result from multiplier

   //Internal Signals
   //----------------
   //Stack AGUs
   wire [31:0]                              sagu_out;          //Stack AGU output
   //Program AGU
   wire [31:0]                              pagu_out;          //Program AGU output
   //ALU
   wire [31:0]                              alu_add_c;         //ALU adder carry bit
   wire [31:0]                              alu_add_out;       //ALU adder output
   wire [31:0]                              alu_umul_out;      //ALU unsigned multiplier output
   wire [31:0]                              alu_smul_out;      //ALU signed multiplier output

   //Shared SB_MAC32 cell for both stack AGUs
   //----------------------------------------
   //The "Hi" part of the SB_MAC32 implements the parameter stack AGU.
   //The "Lo" part of the SB_MAC32 implements the return stack AGU.
   //The output hold register implement the stack pointers.
   //The AGU outputs are registered (= stack pointers)
   SB_MAC16
     #(.NEG_TRIGGER              (1'b0),                       //Clock edge -> posedge
       .C_REG                    (1'b0),                       //C0         -> C input unregistered
       .A_REG                    (1'b0),                       //C1         -> A input unregistered
       .B_REG                    (1'b0),                       //C2         -> B input unregistered
       .D_REG                    (1'b0),                       //C3         -> D input unregistered
       .TOP_8x8_MULT_REG         (1'b1),                       //C4         -> keep unused signals quiet
       .BOT_8x8_MULT_REG         (1'b1),                       //C5         -> keep unused signals quiet
       .PIPELINE_16x16_MULT_REG1 (1'b1),                       //C6         -> keep unused signals quiet
       .PIPELINE_16x16_MULT_REG2 (1'b1),                       //C7         -> keep unused signals quiet
       .TOPOUTPUT_SELECT         (2'b01),                      //C8,C9      -> registered output
       .TOPADDSUB_LOWERINPUT     (2'b00),                      //C10,C11    -> plain adder
       .TOPADDSUB_UPPERINPUT     (1'b0),                       //C12        -> connect to stack pointer
       .TOPADDSUB_CARRYSELECT    (2'b00),                      //C13,C14    -> no carry
       .BOTOUTPUT_SELECT         (2'b01),                      //C15,C16    -> registered output
       .BOTADDSUB_LOWERINPUT     (2'b00),                      //C17,C18    -> plain adder
       .BOTADDSUB_UPPERINPUT     (1'b1),                       //C19        -> connect to stack pointer
       .BOTADDSUB_CARRYSELECT    (2'b00),                      //C20,C21    -> no carry
       .MODE_8x8                 (1'b1),                       //C22        -> power safe
       .A_SIGNED                 (1'b0),                       //C23        -> unsigned
       .B_SIGNED                 (1'b0))                       //C24        -> unsigned
   SB_MAC16_sagu
     (.CLK                       (clk_i),                      //clock input
      .CE                        (1'b1),                       //clock enable
      .C                         (16'h0000),                   //PSP reset value
      .A                         (16'h0001),                   //parameter stack increment/decrement
      .B                         (16'h0001),                   //return stack increment/decrement
      .D                         (16'hFFFF),                   //RSP reset value
      .AHOLD                     (1'b1),                       //keep hold register stable
      .BHOLD                     (1'b1),                       //keep hold register stable
      .CHOLD                     (1'b1),                       //keep hold register stable
      .DHOLD                     (1'b1),                       //keep hold register stable
      .IRSTTOP                   (1'b1),                       //keep hold register in reset
      .IRSTBOT                   (1'b1),                       //keep hold register in reset
      .ORSTTOP                   (|{async_rst_i,sync_rst_i}),  //use common reset
      .ORSTBOT                   (|{async_rst_i,sync_rst_i}),  //use common reset
      .OLOADTOP                  (lps_agu_rst_i),              //soft reset
      .OLOADBOT                  (lrs_agu_rst_i),              //soft reset
      .ADDSUBTOP                 (lps_agu_psh_i),              //push (decrement address)
      .ADDSUBBOT                 (lrs_agu_pul_i),              //pull (decrement address)
      .OHOLDTOP                  (~|{lps_agu_psh_i,            //update PSP
                                     lps_agu_pul_i,            //
                                     lps_agu_rst_i}),          //
      .OHOLDBOT                  (~|{lrs_agu_psh_i,            //update RSP
                                     lps_agu_pul_i,            //
                                     lps_agu_rst_i}),          //
      .CI                        (1'b0),                       //no carry
      .ACCUMCI                   (1'b0),                       //no carry
      .SIGNEXTIN                 (1'b0),                       //no sign extension
      .O                         (sagu_out),                   //result
      .CO                        (),                           //ignore carry output
      .ACCUMCO                   (),                           //ignore carry output
      .SIGNEXTOUT                ());                          //ignore sign extension output

   assign lps_agu_o = sagu_out[SP_WIDTH+15:16];
   assign lrs_agu_o = sagu_out[SP_WIDTH-1:0];

   //Shared SB_MAC32 cell for the program AGU and the ALU adder
   //----------------------------------------------------------
   //The "Hi" part of the SB_MAC32 implements the ALU adder
   //Inputs and outputs of the ALU adder are unregistered
   //The "Lo" part of the SB_MAC32 implements the program AGU
   //The output hold register implement the program counter
   //The AGU output is unregistered (= next address)
   SB_MAC16
     #(.NEG_TRIGGER              (1'b0),                       //Clock edge -> posedge
       .C_REG                    (1'b0),                       //C0         -> C input unregistered
       .A_REG                    (1'b0),                       //C1         -> A input unregistered
       .B_REG                    (1'b0),                       //C2         -> B input unregistered
       .D_REG                    (1'b0),                       //C3         -> D input unregistered
       .TOP_8x8_MULT_REG         (1'b1),                       //C4         -> keep unused signals quiet
       .BOT_8x8_MULT_REG         (1'b1),                       //C5         -> keep unused signals quiet
       .PIPELINE_16x16_MULT_REG1 (1'b1),                       //C6         -> keep unused signals quiet
       .PIPELINE_16x16_MULT_REG2 (1'b1),                       //C7         -> keep unused signals quiet
       .TOPOUTPUT_SELECT         (2'b00),                      //C8,C9      -> unregistered output
       .TOPADDSUB_LOWERINPUT     (2'b00),                      //C10,C11    -> plain adder
       .TOPADDSUB_UPPERINPUT     (1'b1),                       //C12        -> connect to op0
       .TOPADDSUB_CARRYSELECT    (2'b00),                      //C13,C14    -> no carry
       .BOTOUTPUT_SELECT         (2'b00),                      //C15,C16    -> unregistered output
       .BOTADDSUB_LOWERINPUT     (2'b00),                      //C17,C18    -> plain adder
       .BOTADDSUB_UPPERINPUT     (1'b1),                       //C19        -> connect to program counter
       .BOTADDSUB_CARRYSELECT    (2'b00),                      //C20,C21    -> no carry
       .MODE_8x8                 (1'b1),                       //C22        -> power safe
       .A_SIGNED                 (1'b0),                       //C23        -> unsigned
       .B_SIGNED                 (1'b0))                       //C24        -> unsigned
   SB_MAC16_pagu
     (.CLK                       (clk_i),                      //clock input
      .CE                        (1'b1),                       //clock enable
      .C                         (alu_hm_op1_i),               //op1
      .A                         (alu_hm_op0_i),               //op0
      .B                         (pc_rel_adr_i),               //relative COF address
      .D                         (pc_abs_adr_i),               //absolute COF address
      .AHOLD                     (1'b1),                       //keep hold register stable
      .BHOLD                     (1'b1),                       //keep hold register stable
      .CHOLD                     (1'b1),                       //keep hold register stable
      .DHOLD                     (1'b1),                       //keep hold register stable
      .IRSTTOP                   (1'b1),                       //keep hold register in reset
      .IRSTBOT                   (1'b1),                       //keep hold register in reset
      .ORSTTOP                   (1'b1),                       //keep hold register in reset
      .ORSTBOT                   (|{async_rst_i,sync_rst_i}),  //use common reset
      .OLOADTOP                  (1'b0),                       //no bypass
      .OLOADBOT                  (pc_abs_i),                   //absolute COF
      .ADDSUBTOP                 (alu_hm_sub_add_bi),          //subtract
      .ADDSUBBOT                 (1'b0),                       //always use adder
      .OHOLDTOP                  (1'b1),                       //keep hold register stable
      .OHOLDBOT                  (~pc_update_i),               //update PC
      .CI                        (1'b0),                       //no carry
      .ACCUMCI                   (1'b0),                       //no carry
      .SIGNEXTIN                 (1'b0),                       //no sign extension
      .O                         (pagu_out),                   //result
      .CO                        (),                           //ignore carry output
      .ACCUMCO                   (alu_add_c),                  //carry bit determines upper word
      .SIGNEXTOUT                ());                          //ignore sign extension output

   //Outputs
   assign alu_hm_add_o = {{CELL_WIDTH{alu_add_c}}, pagu_out[(2*CELL_WIDTH)-1:CELL_WIDTH]};
   assign pc_next_o    = pagu_out[PC_WIDTH:0];

   //SB_MAC32 cell for unsigned multiplications
   //-------------------------------------------
   //Unsigned 16x16 bit multiplication
   //Neither inputs nor outputs are registered
   SB_MAC16
     #(.NEG_TRIGGER              (1'b0),                       //Clock edge -> posedge
       .C_REG                    (1'b1),                       //C0         -> keep unused signals quiet
       .A_REG                    (1'b0),                       //C1         -> A input unregistered
       .B_REG                    (1'b0),                       //C2         -> B input unregistered
       .D_REG                    (1'b1),                       //C3         -> keep unused signals quiet
       .TOP_8x8_MULT_REG         (1'b0),                       //C4         -> pipeline register bypassed
       .BOT_8x8_MULT_REG         (1'b0),                       //C5         -> pipeline register bypassed
       .PIPELINE_16x16_MULT_REG1 (1'b0),                       //C6         -> pipeline register bypassed
       .PIPELINE_16x16_MULT_REG2 (1'b0),                       //C7         -> pipeline register bypassed
       .TOPOUTPUT_SELECT         (2'b11),                      //C8,C9      -> upper word of product
       .TOPADDSUB_LOWERINPUT     (2'b00),                      //C10,C11    -> adder not in use (any configuration is fine)
       .TOPADDSUB_UPPERINPUT     (1'b1),                       //C12        -> connect to constant input
       .TOPADDSUB_CARRYSELECT    (2'b00),                      //C13,C14    -> no carry
       .BOTOUTPUT_SELECT         (2'b11),                      //C15,C16    -> lower word of product
       .BOTADDSUB_LOWERINPUT     (2'b00),                      //C17,C18    -> adder not in use (any configuration is fine)
       .BOTADDSUB_UPPERINPUT     (1'b1),                       //C19        -> connect to constant input
       .BOTADDSUB_CARRYSELECT    (2'b00),                      //C20,C21    -> no carry
       .MODE_8x8                 (1'b1),                       //C22        -> power safe
       .A_SIGNED                 (1'b0),                       //C23        -> unsigned
       .B_SIGNED                 (1'b0))                       //C24        -> unsigned
   SB_MAC16_pagu
     (.CLK                       (1'b0),                       //no clock
      .CE                        (1'b0),                       //no clock
      .C                         (16'h0000),                   //not in use
      .A                         (alu_hm_op0_i),               //op0
      .B                         (alu_hm_op1_i),               //op1
      .D                         (16'h0000),                   //not in use
      .AHOLD                     (1'b1),                       //keep hold register stable
      .BHOLD                     (1'b1),                       //keep hold register stable
      .CHOLD                     (1'b1),                       //keep hold register stable
      .DHOLD                     (1'b1),                       //keep hold register stable
      .IRSTTOP                   (1'b1),                       //keep hold register in reset
      .IRSTBOT                   (1'b1),                       //keep hold register in reset
      .ORSTTOP                   (1'b1),                       //keep hold register in reset
      .ORSTBOT                   (1'b1),                       //keep hold register in reset
      .OLOADTOP                  (1'b1),                       //keep unused signals quiet
      .OLOADBOT                  (1'b1),                       //keep unused signals quiet
      .ADDSUBTOP                 (1'b0),                       //unused
      .ADDSUBBOT                 (1'b0),                       //unused
      .OHOLDTOP                  (1'b1),                       //keep hold register stable
      .OHOLDBOT                  (1'b1),                       //keep hold register stable
      .CI                        (1'b0),                       //no carry
      .ACCUMCI                   (1'b0),                       //no carry
      .SIGNEXTIN                 (1'b0),                       //no sign extension
      .O                         (alu_umul_out),               //result
      .CO                        (),                           //ignore carry output
      .ACCUMCO                   (),                           //ignore carry output
      .SIGNEXTOUT                ());                          //ignore sign extension output

   //SB_MAC32 cell for signed multiplications
   //----------------------------------------
   //Unsigned 16x16 bit multiplication
   //Neither inputs nor outputs are registered
   SB_MAC16
     #(.NEG_TRIGGER              (1'b0),                       //Clock edge -> posedge
       .C_REG                    (1'b1),                       //C0         -> keep unused signals quiet
       .A_REG                    (1'b0),                       //C1         -> A input unregistered
       .B_REG                    (1'b0),                       //C2         -> B input unregistered
       .D_REG                    (1'b1),                       //C3         -> keep unused signals quiet
       .TOP_8x8_MULT_REG         (1'b0),                       //C4         -> pipeline register bypassed
       .BOT_8x8_MULT_REG         (1'b0),                       //C5         -> pipeline register bypassed
       .PIPELINE_16x16_MULT_REG1 (1'b0),                       //C6         -> pipeline register bypassed
       .PIPELINE_16x16_MULT_REG2 (1'b0),                       //C7         -> pipeline register bypassed
       .TOPOUTPUT_SELECT         (2'b11),                      //C8,C9      -> upper word of product
       .TOPADDSUB_LOWERINPUT     (2'b00),                      //C10,C11    -> adder not in use (any configuration is fine)
       .TOPADDSUB_UPPERINPUT     (1'b1),                       //C12        -> connect to constant input
       .TOPADDSUB_CARRYSELECT    (2'b00),                      //C13,C14    -> no carry
       .BOTOUTPUT_SELECT         (2'b11),                      //C15,C16    -> lower word of product
       .BOTADDSUB_LOWERINPUT     (2'b00),                      //C17,C18    -> adder not in use (any configuration is fine)
       .BOTADDSUB_UPPERINPUT     (1'b1),                       //C19        -> connect to constant input
       .BOTADDSUB_CARRYSELECT    (2'b00),                      //C20,C21    -> no carry
       .MODE_8x8                 (1'b1),                       //C22        -> power safe
       .A_SIGNED                 (1'b1),                       //C23        -> signed
       .B_SIGNED                 (1'b1))                       //C24        -> signed
   SB_MAC16_pagu
     (.CLK                       (1'b0),                       //no clock
      .CE                        (1'b0),                       //no clock
      .C                         (16'h0000),                   //not in use
      .A                         (alu_hm_op0_i),               //op0
      .B                         (alu_hm_op1_i),               //op1
      .D                         (16'h0000),                   //not in use
      .AHOLD                     (1'b1),                       //keep hold register stable
      .BHOLD                     (1'b1),                       //keep hold register stable
      .CHOLD                     (1'b1),                       //keep hold register stable
      .DHOLD                     (1'b1),                       //keep hold register stable
      .IRSTTOP                   (1'b1),                       //keep hold register in reset
      .IRSTBOT                   (1'b1),                       //keep hold register in reset
      .ORSTTOP                   (1'b1),                       //keep hold register in reset
      .ORSTBOT                   (1'b1),                       //keep hold register in reset
      .OLOADTOP                  (1'b1),                       //keep unused signals quiet
      .OLOADBOT                  (1'b1),                       //keep unused signals quiet
      .ADDSUBTOP                 (1'b0),                       //unused
      .ADDSUBBOT                 (1'b0),                       //unused
      .OHOLDTOP                  (1'b1),                       //keep hold register stable
      .OHOLDBOT                  (1'b1),                       //keep hold register stable
      .CI                        (1'b0),                       //no carry
      .ACCUMCI                   (1'b0),                       //no carry
      .SIGNEXTIN                 (1'b0),                       //no sign extension
      .O                         (alu_smul_out),               //result
      .CO                        (),                           //ignore carry output
      .ACCUMCO                   (),                           //ignore carry output
      .SIGNEXTOUT                ());                          //ignore sign extension output

   //Output
   assign alu_hm_mul_o = {(alu_hm_smul_umul_b_i ? alu_smul_out[31:16] : alu_umul_out[31:16]),
                                                                        alu_umul_out[15:0]};

endmodule // N1_hard
