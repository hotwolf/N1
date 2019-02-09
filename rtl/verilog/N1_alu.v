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
//#    This module implements the N1's Arithmetic logic unit (ALU). The         #
//#    following operations are supported:                                      #
//#    op1   *    op0                                                           #
//#    op1   +    op0                                                           #
//#    op1   -    op0  or op0    -   imm                                        #
//#    op1  AND   op0                                                           #
//#    op1 LSHIFT op0     op0 LSHIFT imm                                        #
//#                                                                             #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_alu
  #(parameter   SP_WIDTH        =      12,                           //width of the stack pointer
    parameter   IPS_WIDTH       =       8,                           //depth of the intermediate parameter stack
    parameter   IRS_WIDTH       =       8)                           //depth of the intermediate return stack



   
    localparam 16    = 16,                           //cell width
    localparam OPR_WIDTH     =  5,                           //width of the operator field
    localparam IMM_WIDTH     =  5,                           //width of immediate values
    localparam US_STAT_WIDTH =  8,                           //width of the operator field
    localparam IS_STAT_WIDTH =  8,                           //width of the operator field
    localparam LS_SP_WIDTH   = 16,                           //width of the operator field

   (




    //IR interface
    input  wire [OPR_WIDTH-1:0]      ir_alu_opr_i,           //ALU operator
    input  wire [IMM_WIDTH-1:0]      ir_alu_immop_i,         //immediade operand

    //Upper stack interface
    input  wire [16:0]       us_ps0_i,               //PS0 (TOS)
    input  wire [16:0]       us_ps1_i,               //PS1 (TOS+1)
    input  wire [US_STAT_WIDTH-1:0]  us_pstat_i,             //UPS status
    input  wire [US_STAT_WIDTH-1:0]  us_rstat_i,             //URS status

    //Intermediate stack interface
    input  wire [IS_STAT_WIDTH-1:0]  ips_stat_i,             //IPS status
    input  wire [IS_STAT_WIDTH-1:0]  ips_stat_i,             //IRS status

    //Lower stack interface
    input  wire [LS_SP_WIDTH-1:0]    lps_sp_i,               //LPS stack pointer
    input  wire [LS_SP_WIDTH-1:0]    lps_sp_i,               //LRS stack pointer

    //Hard IP interface
    output wire                      alu_hm_sub_add_b_o,     //0:op1 + op0, 1:op1 + op0
    output wire                      alu_hm_smul_umul_b_o,   //0:unsigned, 1:signed
    output wire [16-1:0]     alu_hm_add_op0_o,       //first operand for adder
    output wire [16-1:0]     alu_hm_add_op1_o,       //second operand for adder
    output wire [16-1:0]     alu_hm_mul_op0_o,       //first operand for multiplier
    output wire [16-1:0]     alu_hm_mul_op1_o,       //second operand for multiplier
    input  wire [(2*16)-1:0] alu_hm_add_i,           //result from adder
    input  wire [(2*16)-1:0] alu_hm_mul_i);          //result from multiplier

   //Internal signals
   //----------------
   //Intermediate operands
   wire                      imm_is_zero;                    //immediate operand is zero
   wire [16-1:0]     uimm;                           //unsigned immediate operand   (1..31)
   wire [16-1:0]     simm;                           //signed immediate operand   (-16..-1,1..15)
   wire [16-1:0]     oimm;                           //shifted immediate oprtand  (-15..15)
   //Adder
   wire [(2*16)-1:0] add_out;                        //adder output
   //Comparator
   wire                      cmp_eq;                         //equals comparator output
   wire                      cmp_neq;                        //not-equals comparator output
   wire                      cmp_lt_unsig;                   //unsigned lower_than comparator output
   wire                      cmp_gt_sig                      //signed greater-than comparator output
   wire                      cmp_gt_unsig;                   //unsigned greater_than comparator output
   wire                      cmp_lt_sig;                     //signed lower-than comparator output
   wire                      cmp_eq;                         //equals comparator output
   wire                      cmp_neq;                        //not-equals comparator output
   wire                      cmp_mexed;                      //multiplexed comparator outputs
   wire [(2*16)-1:0] cmp_out;                        //comparator output
   //Multiplier
   wire [(2*16)-1:0] mul_out;                        //multiplier output
   //Bitwise logic
   wire [16-1:0]     bl_op0;                         //first operand
   wire [16-1:0]     bl_and;                         //result of AND operation
   wire [16-1:0]     bl_xor;                         //result of XOR operation
   wire [16-1:0]     bl_or;                          //result of OR operation
   wire [(2*16)-1:0] bl_out;                         //bit logic output
   //Barrel shifter
   wire [16-1:0]     lsr_op0;                        //first operand
   wire [16-1:0]     lsr_op1;                        //second operand
   wire                      lsr_msb;                        //MSB of first operand
   wire [16-1:0]     lsr_sh0;                        //shift 1 bit
   wire [16-1:0]     lsr_sh1;                        //shift 2 bits
   wire [16-1:0]     lsr_sh2;                        //shift 4 bits
   wire [16-1:0]     lsr_sh3;                        //shift 8 bits
   wire [16-1:0]     lsr_sh4;                        //shift 16 bits
   wire [(2*16)-1:0] lsr_res;                        //result
   wire [16-1:0]     lsl_op0;                        //first operand
   wire [16-1:0]     lsl_op1;                        //second operand
   wire [(2*16)-1:0] lsl_sh0;                        //shift 1 bit
   wire [(2*16)-1:0] lsl_sh1;                        //shift 2 bits
   wire [(2*16)-1:0] lsl_sh2;                        //shift 4 bits
   wire [(2*16)-1:0] lsl_sh3;                        //shift 8 bits
   wire [(2*16)-1:0] lsl_sh3;                        //shift 16 bits
   wire [(2*16)-1:0] lsl_sh4;                        //shift 32 bits
   wire [(2*16)-1:0] lsl_res;                        //result
   wire [(2*16)-1:0] ls_out;                         //shifter output
   //Literal value
   wire [(2*16)-1:0] lit_out;                         //literal value output
   //Processor status
   wire [(2*16)-1:0] stat_out;                        //processor status output

   //Immediate operands
   //------------------
   assign uimm        = {{  16-IMMOP_WIDTH{1'b0}},                         ir_alu_immop};                  //unsigned immediate operand   (1..31)
   assign simm        = {{1+16-IMMOP_WIDTH{ ir_alu_immop[IMMOP_WIDTH-1]}}, ir_alu_immop[IMMOP_WIDTH-2:0]}; //signed immediate operand   (-16..-1,1..15)
   assign oimm        = {{1+16-IMMOP_WIDTH{~ir_alu_immop[IMMOP_WIDTH-1}}}, ir_alu_immop[IMMOP_WIDTH-2:0]}; //shifted immediate oprtand  (-15..15)

   //Hard IP adder
   //-------------
   //Inputs
   assign alu_hw_sub_add_b_o = |ir_alu_opr_i[3:1];           //0:op1 + op0, 1:op1 + op0
   assign alu_hw_add_op0_o   = ir_alu_opr_i[0] ? (imm_is_zero ? us_ps0_i : oimm) :
                                                 (imm_is_zero ? us_ps1_i : us_ps0_i);
   assign alu_hw_add_op1_o   = ir_alu_opr_i[0] ? (imm_is_zero ? us_ps1_i : us_ps0_i) :
                                                 (imm_is_zero ? us_ps0_i : uimm);
   //Result
   assign add_out            = ~|ir_alu_opr_i[4:2] ? {{16{alu_hw_add_i[16]}}, alu_hw_add_i[16-1:0]} :
                                                     {2*16{1'b0}};

   //Comparator
   //----------
   assign cmp_eq          = ~|alu_hw_add_i[16-1:0];  //equals comparator output
   assign cmp_neq         = ~cmp_eq;                         //not-equals comparator output
   assign cmp_lt_unsig    =   alu_hw_add_i[16];      //unsigned lower_than comparator output
   assign cmp_gt_sig      =   alu_hw_add_i[16-1];    //signed greater-than comparator output
   assign cmp_gt_unsig    =   ~|{lt_unsig, cmp_eq};          //unsigned greater_than comparator output
   assign cmp_lt_sig      =   ~|{gt_sig,   cmp_eq};          //signed lower-than comparator output
   assign cmp_muxed       = (~|{ir_alu_opr_i^5'b00100}                &  cmp_lt_unsig) |
                            (~|{ir_alu_opr_i^5'b00101}                &  cmp_gt_sig)   |
                            (~|{ir_alu_opr_i^5'b00110}                &  cmp_gt_unsig) |
                            (~|{ir_alu_opr_i^5'b00111}                &  cmp_lt_sig)   |
                            (~|{ir_alu_opr_i[16-1:1]^4'b1011} &  cmp_eq)       |
                            (~|{ir_alu_opr_i[16-1:1]^4'b1010} &  cmp_neq);
   //Result
   assign cmp_out         = {2*16{cmp_muxed}};

   //Hard IP multiplier
   //------------------
   //Inputs
   assign alu_smul_umul_b_0 = ir_alu_opr_i[1];               //0:unsigned, 1:signed
   assign alu_add_op0_o     = &{ir_alu_opr_i[4:2]^3'b100) ? us_ps0_i : {16{1'b0}};
   assign alu_add_op1_o     = imm_is_zero ? us_ps1_i :
                              (ir_alu_opr_i[0] ?  simm : uimm);
   //Result
   assign mul_out           = alu_hw_mul_i;

   //Bitwise logic
   //------------------
   //AND
   assign bl_and           = ~|{ir_alu_opr_i[1:0]^2'b00} ?
                             (imm_is_zero ? (us_ps0_i & us_ps1_i) : (us_ps0_i & simm)) : {16{1'b0}};
   //XOR
   assign bl_xor            = ~(ir_alu_opr_i[0]^1'b0) ?
                             (imm_is_zero ? (us_ps0_i ^ us_ps1_i) : (us_ps0_i ^ simm)) : {16{1'b0}};
   //AND
   assign bl_or            = ~|{ir_alu_opr_i[1:0]^2'b10} ?
                             (imm_is_zero ? (us_ps0_i | us_ps1_i) : (us_ps0_i | uimm)) : {16{1'b0}};
   //Result
   assign bl_out           = ~|{ir_alu_opr_i[4:2]^3'b100} ?
                              {{16{1'b0}}, bl_and | bl_xor | bl_or} : {2*16{1'b0}};

   //Barrel shifter
   //--------------
   //Right shift
   assign lsr_op0 = us_ps0_i;                                //first operand
   assign lsr_op1 = imm_is_zero ? us_ps1_i : uimm;           //second operand
   assign lsr_msb = opr_asr ? lsr_op0[16] : 1'b0;    //MSB of first operand
   assign lsr_sh0 = lsr_op1[0] ?                             //shift 1 bit
                    {lsr_msb, lsr_op0[16-1:1]} :     //
                    lsr_op0;                                 //
   assign lsr_sh1 = lsr_op1[1] ?                             //shift 2 bits
                    {{2{lsr_msb}}, lsr_sh0[16-1:2]} ://
                    lsr_sh0;                                 //
   assign lsr_sh2 = lsr_op1[2] ?                             //shift 4 bits
                    {{4{lsr_msb}}, lsr_sh1[16-1:4]} ://
                    lsr_sh1;                                 //
   assign lsr_sh3 = lsr_op1[3] ?                             //shift 8 bits
                    {{8{lsr_msb}}, lsr_sh2[16-1:8]} ://
                    lsr_sh2;                                 //
   assign lsr_sh4 = |lsr_op1[16-1:4] ?               //shift 16 bits
                    {16{lsr_msb}} :                          //
                    lsr_sh3;                                 //
   assign lsr_res = ~ir_alu_opr_i[0] ?                       //result
                    {{16{lsr_msb}},clsr_sh4} :       //
                    {2*16{1'b0}};                    //
   //Left shift
   assign lsl_op0 = us_ps0_i;                                //first operand
   assign lsl_op1 = imm_is_zero ? us_ps1_i : uimm;           //second operand
   assign lsl_sh0 = lsl_op1[0] ?                             //shift 1 bit
                    {{16-1{1'b0}}, lsl_op0, 1'b0} :  //
                    {{16{1'b0}}, lsl_op0};           //
   assign lsl_sh1 = lsl_op1[1] ?                             //shift 2 bits
                    {lsl_sh0[(2*16)-3:0], 2'b0} :    //
                    lsl_sh0;                                 //
   assign lsl_sh2 = lsl_op1[2] ?                             //shift 4 bits
                    {lsl_sh0[(2*16)-5:0], 4'h0} :    //
                    lsl_sh1;                                 //
   assign lsl_sh3 = lsl_op1[3] ?                             //shift 8 bits
                    {lsl_sh0[(2*16)-9:0], 8'h00} :   //
                    lsl_sh2;                                 //
   assign lsl_sh3 = lsl_op1[4] ?                             //shift 16 bits
                    {lsl_sh0[(2*16)-16:0], 16'h0000}://
                    lsl_sh3;                                 //
   assign lsl_sh4 = |lsl_op1[16-1:5] ?               //shift 32 bits
                    {2*16{1'b0}}:                    //
                    lsl_sh3;                                 //
   assign lsl_res = ir_alu_opr_i[0] ?                        //shift 32 bits
                    lsl_sh4 : {2*16{1'b0}};          //
   //Result
   assign ls_out  = ~|{ir_alu_opr_i[4:2]^3'b101} ?
                    (lsr_res | lsl_res) : {2*16{1'b0}};

   //Literal value
   //-------------
   assign lit_out = ~|{ir_alu_opr_i[4:2]^3'b110} ?
                    {{16-1{simm[5]}}, simm, us_ps0_i[11:0} :
                    {2*16{1'b0}};

   //Processor status
   //----------------
   assign stat_out = ~|{ir_alu_opr_i[4:2]^3'b111} ?
                     (({2*16{~|{ir_alu_opr_i[1:2]^2'b00}}} & cpu_stat_i)                         |
                      ({2*16{~|{ir_alu_opr_i[1:2]^2'b01}}} & excpt_throw_code_i)                 |
                      ({2*16{~|{ir_alu_opr_i[1:2]^2'b10}}} & {lps_sp_i, ips_stat_i, us_pstat_i}) |
                      ({2*16{~|{ir_alu_opr_i[1:2]^2'b11}}} & {lrs_sp_i, irs_stat_i, us_rstat_i})) :
                     {2*16{1'b0}};

   //ALU output
   //----------
    assign alu_o   = add_out  |
                     cmp_out  |
                     mul_out  |
                     bl_out   |
                     ls_out   |
                     lit_out  |
                     stat_out;

endmodule // N1_alu
