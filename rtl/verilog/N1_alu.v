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
  #(parameter   SP_WIDTH  = 12,                                      //width of the stack pointer
    parameter   IPS_DEPTH =  8,                                      //depth of the intermediate parameter stack
    parameter   IRS_DEPTH =  8)                                      //depth of the intermediate return stack
   (//DSP cell interface
    output wire                   alu2dsp_sub_add_b_o,               //1:op1 - op0, 0:op1 + op0
    output wire                   alu2dsp_smul_umul_b_o,             //1:signed, 0:unsigned
    output wire [15:0]            alu2dsp_add_op0_o,                 //first operand for adder/subtractor
    output wire [15:0]            alu2dsp_add_op1_o,                 //second operand for adder/subtractor (zero if no operator selected)
    output wire [15:0]            alu2dsp_mul_op0_o,                 //first operand for multipliers
    output wire [15:0]            alu2dsp_mul_op1_o,                 //second operand dor multipliers (zero if no operator selected)
    input  wire [31:0]            dsp2alu_add_res_i,                 //result from adder
    input  wire [31:0]            dsp2alu_mul_res_i,                 //result from multiplier

    //Exception interface
    input  wire [15:0]            excpt2alu_tc_i,                    //throw code

    //Intermediate parameter stack interface
    input  wire [IPS_DEPTH-1:0]   ips2alu_tags_i,                    //cell tags
    input  wire [SP_WIDTH-1:0]    ips2alu_lsp_i,                     //lower stack pointer

    //IR interface
    input  wire [4:0]             ir2alu_opr_i,                      //ALU operator
    input  wire [4:0]             ir2alu_imm_op_i,                   //immediate operand
    input  wire                   ir2alu_sel_imm_op_i,               //select immediate operand

   //Intermediate return stack interface
    input  wire [IRS_DEPTH-1:0]   irs2alu_tags_i,                    //cell tags
    input  wire [SP_WIDTH-1:0]    irs2alu_lsp_i,                     //lower stack pointer

    //Upper stack interface
    output wire [15:0]            alu2us_ps0_next_o,                 //new PS0 (TOS)
    output wire [15:0]            alu2us_ps1_next_o,                 //new PS1 (TOS+1)
    input  wire [15:0]            us2alu_ps0_cur_i,                  //current PS0 (TOS)
    input  wire [15:0]            us2alu_ps1_cur_i,                  //current PS1 (TOS+1)
    input  wire [3:0]             us2alu_ptags_i,                    //UPS tags
    input  wire                   us2alu_rtags_i);                   //URS tags

   //Internal signals
   //----------------
   //Intermediate operands
   wire [15:0]                    uimm;                              //unsigned immediate operand   (1..31)
   wire [15:0]                    simm;                              //signed immediate operand   (-16..-1,1..15)
   wire [15:0]                    oimm;                              //shifted immediate oprtand  (-15..15)
   //Adder
   wire [31:0]                    add_out;                           //adder output
   //Comparator
   wire                           cmp_eq;                            //equals comparator output
   wire                           cmp_neq;                           //not-equals comparator output
   wire                           cmp_lt_unsig;                      //unsigned lower_than comparator output
   wire                           cmp_gt_sig;                        //signed greater-than comparator output
   wire                           cmp_gt_unsig;                      //unsigned greater_than comparator output
   wire                           cmp_lt_sig;                        //signed lower-than comparator output
   wire                           cmp_muxed;                         //multiplexed comparator outputs
   wire [31:0]                    cmp_out;                           //comparator output
   //Multiplier
   wire [31:0]                    mul_out;                           //multiplier output
   //Bitwise logic
   wire [15:0]                    bl_op0;                            //first operand
   wire [15:0]                    bl_and;                            //result of AND operation
   wire [15:0]                    bl_xor;                            //result of XOR operation
   wire [15:0]                    bl_or;                             //result of OR operation
   wire [31:0]                    bl_out;                            //bit logic output
   //Barrel shifter
   wire [15:0]                    lsr_op0;                           //first operand
   wire [15:0]                    lsr_op1;                           //second operand
   wire                           lsr_msb;                           //MSB of first operand
   wire [15:0]                    lsr_sh0;                           //shift 1 bit
   wire [15:0]                    lsr_sh1;                           //shift 2 bits
   wire [15:0]                    lsr_sh2;                           //shift 4 bits
   wire [15:0]                    lsr_sh3;                           //shift 8 bits
   wire [15:0]                    lsr_sh4;                           //shift 16 bits
   wire [31:0]                    lsr_res;                           //result
   wire [15:0]                    lsl_op0;                           //first operand
   wire [15:0]                    lsl_op1;                           //second operand
   wire [31:0]                    lsl_sh0;                           //shift 1 bit
   wire [31:0]                    lsl_sh1;                           //shift 2 bits
   wire [31:0]                    lsl_sh2;                           //shift 4 bits
   wire [31:0]                    lsl_sh3;                           //shift 8 bits
   wire [31:0]                    lsl_sh4;                           //shift 16 bits
   wire [31:0]                    lsl_sh5;                           //shift 32 bits
   wire [31:0]                    lsl_res;                           //result
   wire [31:0]                    ls_out;                            //shifter output
   //Literal value
   wire [31:0]                    lit_out;                           //literal value output
   //Processor status
   wire [31:0]                    stat_out;                          //processor status output
   //ALU output
   wire [31:0]                    alu_out;                           //ALU output

   //Immediate operands
   //------------------
   assign uimm        = { 11'h000,                  ir2alu_imm_op_i};      //unsigned immediate operand (1..31)
   assign simm        = {{12{ ir2alu_imm_op_i[4]}}, ir2alu_imm_op_i[3:0]}; //signed immediate operand   (-16..-1,1..15)
   assign oimm        = {{12{~ir2alu_imm_op_i[4]}}, ir2alu_imm_op_i[3:0]}; //shifted immediate oprtand  (-15..15)

   //Hard IP adder
   //-------------
   //Inputs
   assign alu2dsp_sub_add_b_o = |ir2alu_opr_i[3:1];                  //0:op1 + op0, 1:op1 + op0
   assign alu2dsp_add_op0_o   = ir2alu_opr_i[0] ? (ir2alu_sel_imm_op_i ? oimm             : us2alu_ps0_cur_i) :
                                                  (ir2alu_sel_imm_op_i ? us2alu_ps0_cur_i : us2alu_ps1_cur_i);
   assign alu2dsp_add_op1_o   = ir2alu_opr_i[0] ? (ir2alu_sel_imm_op_i ? us2alu_ps0_cur_i : us2alu_ps1_cur_i) :
                                                  (ir2alu_sel_imm_op_i ? uimm             : us2alu_ps0_cur_i);
   //Result
   assign add_out             = ~|ir2alu_opr_i[4:2] ? dsp2alu_add_res_i : 32'h00000000;

   //Comparator
   //----------
   assign cmp_eq          = ~|dsp2alu_add_res_i[15:0];               //equals comparator output
   assign cmp_neq         = ~cmp_eq;                                 //not-equals comparator output
   assign cmp_lt_unsig    =   dsp2alu_add_res_i[16];                 //unsigned lower_than comparator output
   assign cmp_gt_sig      =   dsp2alu_add_res_i[15];                 //signed greater-than comparator output
   assign cmp_gt_unsig    =   ~|{cmp_lt_unsig, cmp_eq};              //unsigned greater_than comparator output
   assign cmp_lt_sig      =   ~|{cmp_gt_sig,   cmp_eq};              //signed lower-than comparator output
   assign cmp_muxed       = (~|{ir2alu_opr_i^5'b00100}     &  cmp_lt_unsig) |
                            (~|{ir2alu_opr_i^5'b00101}     &  cmp_gt_sig)   |
                            (~|{ir2alu_opr_i^5'b00110}     &  cmp_gt_unsig) |
                            (~|{ir2alu_opr_i^5'b00111}     &  cmp_lt_sig)   |
                            (~|{ir2alu_opr_i[4:1]^4'b0100} &  cmp_eq)       |
                            (~|{ir2alu_opr_i[4:1]^4'b0101} &  cmp_neq);
   //Result
   assign cmp_out         = {2*16{cmp_muxed}};

   //Hard IP multiplier
   //------------------
   //Inputs
   assign alu2dsp_smul_umul_b_o = ir2alu_opr_i[1];                       //0:unsigned, 1:signed
   assign alu2dsp_mul_op0_o     = &(ir2alu_opr_i[4:2]^3'b100) ? us2alu_ps0_cur_i : 16'h0000;
   assign alu2dsp_mul_op1_o     = ir2alu_sel_imm_op_i ? (ir2alu_opr_i[0] ?  simm : uimm) : us2alu_ps1_cur_i;
   //Result
   assign mul_out               = dsp2alu_mul_res_i;

   //Bitwise logic
   //------------------
   //AND
   assign bl_and           = ~|{ir2alu_opr_i[1:0]^2'b00} ?
                             (ir2alu_sel_imm_op_i ? (us2alu_ps0_cur_i & simm) : (us2alu_ps0_cur_i & us2alu_ps1_cur_i)) : 16'h0000;
   //XOR
   assign bl_xor            = ~(ir2alu_opr_i[0]^1'b0) ?
                             (ir2alu_sel_imm_op_i ? (us2alu_ps0_cur_i ^ simm) : (us2alu_ps0_cur_i ^ us2alu_ps1_cur_i)) : 16'h0000;
   //AND
   assign bl_or            = ~|{ir2alu_opr_i[1:0]^2'b10} ?
                             (ir2alu_sel_imm_op_i ? (us2alu_ps0_cur_i | uimm) : (us2alu_ps0_cur_i | us2alu_ps1_cur_i)) : 16'h0000;
   //Result
   assign bl_out           = ~|{ir2alu_opr_i[4:2]^3'b100} ?
                              {16'h0000, bl_and | bl_xor | bl_or} : 32'h00000000;

   //Barrel shifter
   //--------------
   //Right shift
   assign lsr_op0 = us2alu_ps0_cur_i;                                //first operand
   assign lsr_op1 = ir2alu_sel_imm_op_i ? uimm : us2alu_ps1_cur_i;   //second operand
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
   assign lsl_op0 = us2alu_ps0_cur_i;                                //first operand
   assign lsl_op1 = ir2alu_sel_imm_op_i ? uimm : us2alu_ps1_cur_i;   //second operand
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
   assign ls_out  = ~|{ir2alu_opr_i[4:2]^3'b101} ?
                    (lsr_res | lsl_res) : 32'h00000000;

   //Literal value
   //-------------
   assign lit_out = ~|{ir2alu_opr_i[4:2]^3'b110} ?
                    {{15{simm[5]}}, simm[4:0], us2alu_ps0_cur_i[11:0]} :
                    32'h00000000;

   //Processor status
   //----------------
   assign stat_out = ~|{ir2alu_opr_i[4:2]^3'b111} ?
                      ({32{~|(ir2alu_opr_i[2:1]^2'b01)}} & {{16{excpt2alu_tc_i[15]}}, excpt2alu_tc_i})  |
                      ({32{~|(ir2alu_opr_i[2:1]^2'b10)}} & {{16-SP_WIDTH{1'b0}}, ips2alu_lsp_i, 4'h0,
                                                            ips2alu_tags_i, us2alu_ptags_i})            |
                      ({32{~|(ir2alu_opr_i[2:1]^2'b11)}} & {{16-SP_WIDTH{1'b0}}, irs2alu_lsp_i,
                                                            7'h00, irs2alu_tags_i, us2alu_rtags_i})  :
                     32'h00000000;

   //ALU output
   //----------
    assign alu_out = add_out  |
                     cmp_out  |
                     mul_out  |
                     bl_out   |
                     ls_out   |
                     lit_out  |
                     stat_out;
    assign alu2us_ps1_next_o = alu_out[31:16];                       //new PS1 (TOS+1)
    assign alu2us_ps0_next_o = alu_out[15:0];                        //new PS0 (TOS)

endmodule // N1_alu
