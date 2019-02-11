//###############################################################################
//# N1 - Formal Testbench - Arithmetic Logic Unit                               #
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
//#    This is the the formal testbench for the ALU block.                      #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 11, 2019                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

//DUT configuration
//=================
//Default configuration
//---------------------
`ifdef CONF_DEFAULT
`endif

//Fall back
//---------
`ifndef SP_WIDTH
`define SP_WIDTH       12
`endif
`ifndef IPS_DEPTH
`define IPS_DEPTH       8
`endif
`ifndef IRS_DEPTH
`define IRS_DEPTH       8
`endif

module ftb_N1_alu
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
    input  wire [`IPS_DEPTH-1:0]  ips2alu_tags_i,                    //cell tags
    input  wire [`SP_WIDTH-1:0]   ips2alu_lsp_i,                     //lower stack pointer

    //IR interface
    input  wire [4:0]             ir2alu_opr_i,                      //ALU operator
    input  wire [4:0]             ir2alu_imm_op_i,                   //immediate operand
    input  wire                   ir2alu_sel_imm_op_i,               //select immediate operand

    //Intermediate return stack interface
    input  wire [`IRS_DEPTH-1:0]  irs2alu_tags_i,                    //cell tags
    input  wire [`SP_WIDTH-1:0]   irs2alu_lsp_i,                     //lower stack pointer

    //Upper stack interface
    output wire [15:0]            alu2us_ps0_next_o,                 //new PS0 (TOS)
    output wire [15:0]            alu2us_ps1_next_o,                 //new PS1 (TOS+1)
    input  wire [15:0]            us2alu_ps0_cur_i,                  //current PS0 (TOS)
    input  wire [15:0]            us2alu_ps1_cur_i,                  //current PS1 (TOS+1)
    input  wire [3:0]             us2alu_ptags_i,                    //UPS tags
    input  wire                   us2alu_rtags_i);                   //URS tags

   //Instantiation
   //=============
   N1_alu
     #(.SP_WIDTH  (`SP_WIDTH),                                       //width of the stack pointer
       .IPS_DEPTH (`IPS_DEPTH),                                      //depth of the intermediate parameter stack
       .IRS_DEPTH (`IRS_DEPTH))                                      //depth of the intermediate return stack
   DUT
   (//DSP cell interface
    .alu2dsp_sub_add_b_o        (alu2dsp_sub_add_b_o),               //1:op1 - op0, 0:op1 + op0
    .alu2dsp_smul_umul_b_o      (alu2dsp_smul_umul_b_o),             //1:signed, 0:unsigned
    .alu2dsp_add_op0_o          (alu2dsp_add_op0_o),                 //first operand for adder/subtractor
    .alu2dsp_add_op1_o          (alu2dsp_add_op1_o),                 //second operand for adder/subtractor (zero if no operator selected)
    .alu2dsp_mul_op0_o          (alu2dsp_mul_op0_o),                 //first operand for multipliers
    .alu2dsp_mul_op1_o          (alu2dsp_mul_op1_o),                 //second operand dor multipliers (zero if no operator selected)
    .dsp2alu_add_res_i          (dsp2alu_add_res_i),                 //result from adder
    .dsp2alu_mul_res_i          (dsp2alu_mul_res_i),                 //result from multiplier

    //Exception interface
    .excpt2alu_tc_i             (excpt2alu_tc_i),                    //throw code

    //Intermediate parameter stack interface
    .ips2alu_tags_i             (ips2alu_tags_i),                    //cell tags
    .ips2alu_lsp_i              (ips2alu_lsp_i),                     //lower stack pointer

    //IR interface
    .ir2alu_opr_i               (ir2alu_opr_i),                      //ALU operator
    .ir2alu_imm_op_i            (ir2alu_imm_op_i),                   //immediate operand
    .ir2alu_sel_imm_op_i        (ir2alu_sel_imm_op_i),               //select immediate operand

    //Intermediate return stack interface
    .irs2alu_tags_i             (irs2alu_tags_i),                    //cell tags
    .irs2alu_lsp_i              (irs2alu_lsp_i),                     //lower stack pointer

     //Upper stack interface
    .alu2us_ps0_next_o          (alu2us_ps0_next_o),                 //new PS0 (TOS)
    .alu2us_ps1_next_o          (alu2us_ps1_next_o),                 //new PS1 (TOS+1)
    .us2alu_ps0_cur_i           (us2alu_ps0_cur_i),                  //current PS0 (TOS)
    .us2alu_ps1_cur_i           (us2alu_ps1_cur_i),                  //current PS1 (TOS+1)
    .us2alu_ptags_i             (us2alu_ptags_i),                    //UPS tags
    .us2alu_rtags_i             (us2alu_rtags_i));                   //URS tags

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

`endif //  `ifdef FORMAL

endmodule // ftb_N1_alu
