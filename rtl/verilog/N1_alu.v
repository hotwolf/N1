//###############################################################################
//# N1 - Arithmetic Logic Unit                                                  #
//###############################################################################
//#    Copyright 2018 Dirk Heisswolf                                            #
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
//#    This module implements the N1's Arithmetic logic unit (ALU).             #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_alu
   (//DSP interface
    output wire                   alu2dsp_add_sel_o,                   //1:sub, 0:add
    output wire                   alu2dsp_mul_sel_o,                   //1:smul, 0:umul
    output wire [15:0]            alu2dsp_add_opd0_o,                  //first operand for adder/subtractor
    output wire [15:0]            alu2dsp_add_opd1_o,                  //second operand for adder/subtractor (zero if no operator selected)
    output wire [15:0]            alu2dsp_mul_opd0_o,                  //first operand for multipliers
    output wire [15:0]            alu2dsp_mul_opd1_o,                  //second operand dor multipliers (zero if no operator selected)
    input  wire [31:0]            dsp2alu_add_res_i,                   //result from adder
    input  wire [31:0]            dsp2alu_mul_res_i,                   //result from multiplier

    //IR interface
    input  wire [4:0]             ir2alu_opr_i,                        //ALU operator
    input  wire [4:0]             ir2alu_opd_i,                        //immediate operand
    input  wire                   ir2alu_opd_sel_i,                    //0: PS1, 1: immediate

    //PRS interface
    output wire [15:0]            alu2prs_ps0_next_o,                  //new PS0 (TOS)
    output wire [15:0]            alu2prs_ps1_next_o,                  //new PS1 (TOS+1)
    input  wire [15:0]            prs2alu_ps0_i,                       //current PS0 (TOS)
    input  wire [15:0]            prs2alu_ps1_i);                      //current PS1 (TOS+1)

   //Internal signals
   //----------------
   //Intermediate operands
   wire [15:0]                    uimm;                                //unsigned immediate operand   (1..31)
   wire [15:0]                    simm;                                //signed immediate operand   (-16..-1,1..15)
   wire [15:0]                    oimm;                                //shifted immediate oprtand  (-15..15)
   //Adder
   wire [31:0]                    add_out;                             //adder output
   //Comparator
   wire                           cmp_eq;                              //equals comparator output
   wire                           cmp_neq;                             //not-equals comparator output
   wire                           cmp_ult;                             //unsigned lower_than comparator output
   wire                           cmp_sgt;                             //signed greater-than comparator output
   wire                           cmp_ugt;                             //unsigned greater_than comparator output
   wire                           cmp_slt;                             //signed lower-than comparator output
   wire                           cmp_res;                             //multiplexed comparator outputs
   wire [31:0]                    cmp_out;                             //comparator output
   //MAX/MIN value
   wire                           max_sel;                             //0: PS1, 1:PS0
   wire [15:0]                    max_res;                             //MAX/MIN value
   wire [31:0]                    max_out;                             //MAX/MIN ALU output
   //Multiplier
   wire [31:0]                    mul_out;                             //multiplier output
   //Bitwise logic
   wire [15:0]                    bl_op0;                              //first operand
   wire [15:0]                    bl_and;                              //result of AND operation
   wire [15:0]                    bl_xor;                              //result of XOR operation
   wire [15:0]                    bl_or;                               //result of OR operation
   wire [31:0]                    bl_out;                              //bit logic output
   //Barrel shifter
   wire [15:0]                    lsr_op0;                             //first operand
   wire [15:0]                    lsr_op1;                             //second operand
   wire                           lsr_msb;                             //MSB of first operand
   wire [15:0]                    lsr_sh0;                             //shift 1 bit
   wire [15:0]                    lsr_sh1;                             //shift 2 bits
   wire [15:0]                    lsr_sh2;                             //shift 4 bits
   wire [15:0]                    lsr_sh3;                             //shift 8 bits
   wire [15:0]                    lsr_sh4;                             //shift 16 bits
   wire [31:0]                    lsr_res;                             //result
   wire [15:0]                    lsl_op0;                             //first operand
   wire [15:0]                    lsl_op1;                             //second operand
   wire [31:0]                    lsl_sh0;                             //shift 1 bit
   wire [31:0]                    lsl_sh1;                             //shift 2 bits
   wire [31:0]                    lsl_sh2;                             //shift 4 bits
   wire [31:0]                    lsl_sh3;                             //shift 8 bits
   wire [31:0]                    lsl_sh4;                             //shift 16 bits
   wire [31:0]                    lsl_sh5;                             //shift 32 bits
   wire [31:0]                    lsl_res;                             //result
   wire [31:0]                    ls_out;                              //shifter output
   //Literal value
   wire [31:0]                    lit_out;                             //literal value output
   //Processor status
   wire [31:0]                    stat_out;                            //processor status output
   //ALU output
   wire [31:0]                    alu_out;                             //ALU output

   //Immediate operands
   //------------------
   assign uimm        = { 11'h000,               ir2alu_opd_i};        //unsigned immediate operand (1..31)
   assign simm        = {{12{ ir2alu_opd_i[4]}}, ir2alu_opd_i[3:0]};   //signed immediate operand   (-16..-1,1..15)
   assign oimm        = {{12{~ir2alu_opd_i[4]}}, ir2alu_opd_i[3:0]};   //shifted immediate oprtand  (-15..15)

   //Hard IP adder
   //-------------
   //Inputs
   assign alu2dsp_add_sel_o  = |ir2alu_opr_i[3:1] |                    //0:op1 + op0, 1:op1 - op0
                               (ir2alu_opr_i[0] & prs2alu_ps0_i[15]);  //absolute value

   assign alu2dsp_add_opd0_o =  ir2alu_opr_i[0] ? prs2alu_ps0_i :
                                                  (ir2alu_opd_sel_i ? uimm : prs2alu_ps1_i);

   assign alu2dsp_add_opd1_o =  ir2alu_opr_i[0] ? (ir2alu_opd_sel_i ? oimm : prs2alu_ps1_i) :
                                                  prs2alu_ps0_i;

   //Sum, difference, absolute value
   //-------------------------------
   assign add_out         = ~|(ir2alu_opr_i[4:2] ^ 3'b000) ?
                            dsp2alu_add_res_i : 32'h00000000;

   //MAX and MIN values
   //------------------
   assign max_sel         = ir2alu_opr_i[1] ^
                            (ir2alu_opr_i[1] ? cmp_slt : cmp_ult);
   assign max_res         = max_sel ? prs2alu_ps0_i : prs2alu_ps1_i;
   assign max_out         = {16'h0000,
                             (~|(ir2alu_opr_i[4:2] ^ 3'b001) ? max_res : 16'h0000)};

   //Comparator
   //----------
   assign cmp_eq          = ~|dsp2alu_add_res_i[15:0];                 //TRUE if op1 == op2
   assign cmp_neq         = ~cmp_eq;                                   //TRUE if op1 <> op2
   assign cmp_ult         = dsp2alu_add_res_i[16];                     //TRUE if op1 <  op2
   assign cmp_slt         = dsp2alu_add_res_i[15];                     //TRUE if op1 <  op2
   assign cmp_ugt         = ~|{cmp_ult, cmp_eq};                       //TRUE if op1 >  op2
   assign cmp_sgt         = ~|{cmp_slt, cmp_eq};                       //TRUE if op1 >  op2


   assign cmp_res         = (~|{ir2alu_opr_i[2:1]^2'b00}  &  cmp_eq)  |
                            (~|{ir2alu_opr_i[2:1]^2'b01}  &  cmp_neq) |
                            (~|{ir2alu_opr_i[2:0]^3'b100} &  cmp_ult) |
                            (~|{ir2alu_opr_i[2:0]^3'b101} &  cmp_slt) |
                            (~|{ir2alu_opr_i[2:0]^3'b110} &  cmp_ugt) |
                            (~|{ir2alu_opr_i[2:0]^3'b011} &  cmp_sgt);
   //Result
   assign cmp_out         = {32{~|(ir2alu_opr_i[4:3]^2'b01) & cmp_res}};

   //Hard IP multiplier
   //------------------
   //Inputs
   assign alu2dsp_mul_sel_o  = ir2alu_opr_i[1];                   //0:unsigned, 1:signed
   assign alu2dsp_mul_opd0_o = &(ir2alu_opr_i[4:2]^3'b100) ? prs2alu_ps0_i : 16'h0000;
   assign alu2dsp_mul_opd1_o = ir2alu_opd_sel_i ? (ir2alu_opr_i[0] ?  simm : uimm) : prs2alu_ps1_i;
   //Result
   assign mul_out            = dsp2alu_mul_res_i;

   //Bitwise logic
   //------------------
   //AND
   assign bl_and           = ~|{ir2alu_opr_i[1:0]^2'b00} ?
                             (ir2alu_opd_sel_i ? (prs2alu_ps0_i & simm) : (prs2alu_ps0_i & prs2alu_ps1_i)) : 16'h0000;
   //XOR
   assign bl_xor            = ~(ir2alu_opr_i[0]^1'b0) ?
                             (ir2alu_opd_sel_i ? (prs2alu_ps0_i ^ simm) : (prs2alu_ps0_i ^ prs2alu_ps1_i)) : 16'h0000;
   //AND
   assign bl_or            = ~|{ir2alu_opr_i[1:0]^2'b10} ?
                             (ir2alu_opd_sel_i ? (prs2alu_ps0_i | uimm) : (prs2alu_ps0_i | prs2alu_ps1_i)) : 16'h0000;
   //Result
   assign bl_out           = ~|{ir2alu_opr_i[4:2]^3'b101} ?
                              {16'h0000, bl_and | bl_xor | bl_or} : 32'h00000000;

   //Barrel shifter
   //--------------
   //Right shift
   assign lsr_op0 = prs2alu_ps0_i;                                   //first operand
   assign lsr_op1 = ir2alu_opd_sel_i ? uimm : prs2alu_ps1_i;         //second operand
   assign lsr_msb = ir2alu_opr_i[1] ? lsr_op0[15] : 1'b0;            //MSB of first operand
   assign lsr_sh0 = lsr_op1[0] ?                                     //shift 1 bit
                    {lsr_msb, lsr_op0[15:1]} :                       //
                    lsr_op0;                                         //
   assign lsr_sh1 = lsr_op1[1] ?                                     //shift 2 bits
                    {{2{lsr_msb}}, lsr_sh0[15:2]} :                  //
                    lsr_sh0;                                         //
   assign lsr_sh2 = lsr_op1[2] ?                                     //shift 4 bits
                    {{4{lsr_msb}}, lsr_sh1[15:4]} :                  //
                    lsr_sh1;                                         //
   assign lsr_sh3 = lsr_op1[3] ?                                     //shift 8 bits
                    {{8{lsr_msb}}, lsr_sh2[15:8]} :                  //
                    lsr_sh2;                                         //
   assign lsr_sh4 = |lsr_op1[15:4] ?                                 //shift 16 bits
                    {16{lsr_msb}} :                                  //
                    lsr_sh3;                                         //
   assign lsr_res = ~ir2alu_opr_i[0] ?                               //result
                    {{16{lsr_msb}}, lsr_sh4} :                       //
                    32'h00000000;                                    //
   //Left shift
   assign lsl_op0 = prs2alu_ps0_i;                                   //first operand
   assign lsl_op1 = ir2alu_opd_sel_i ? uimm : prs2alu_ps1_i;         //second operand
   assign lsl_sh0 = lsl_op1[0] ?                                     //shift 1 bit
                    {15'h0000, lsl_op0, 1'b0} :                      //
                    {16'h0000, lsl_op0};                             //
   assign lsl_sh1 = lsl_op1[1] ?                                     //shift 2 bits
                    {lsl_sh0[29:0], 2'b0} :                          //
                    lsl_sh0;                                         //
   assign lsl_sh2 = lsl_op1[2] ?                                     //shift 4 bits
                    {lsl_sh0[27:0], 4'h0} :                          //
                    lsl_sh1;                                         //
   assign lsl_sh3 = lsl_op1[3] ?                                     //shift 8 bits
                    {lsl_sh0[23:0], 8'h00} :                         //
                    lsl_sh2;                                         //
   assign lsl_sh4 = lsl_op1[4] ?                                     //shift 16 bits
                    {lsl_sh0[15:0], 16'h0000}:                       //
                    lsl_sh3;                                         //
   assign lsl_sh5 = |lsl_op1[15:5] ?                                 //shift 32 bits
                    32'h00000000:                                    //
                    lsl_sh3;                                         //
   assign lsl_res = ir2alu_opr_i[0] ?                                //shift 32 bits
                    lsl_sh4 : 32'h00000000;                          //
   //Result
   assign ls_out  = ~|{ir2alu_opr_i[4:2]^3'b110} ?
                    (lsr_res | lsl_res) : 32'h00000000;

   //Literal value
   //-------------
   assign lit_out = ~|{ir2alu_opr_i[4:2]^3'b110} ?
                    {{15{simm[5]}}, simm[4:0], prs2alu_ps0_i[11:0]} :
                    32'h00000000;

   //ALU output
   //----------
    assign alu_out = add_out  |
                     max_out  |
                     cmp_out  |
                     mul_out  |
                     bl_out   |
                     ls_out   |
                     lit_out;
    assign alu2prs_ps1_next_o = alu_out[31:16];                      //new PS1 (TOS+1)
    assign alu2prs_ps0_next_o = alu_out[15:0];                       //new PS0 (TOS)

endmodule // N1_alu
