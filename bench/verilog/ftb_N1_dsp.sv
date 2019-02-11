//###############################################################################
//# N1 - Formal Testbench - DSP Cell Partition                                  #
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
//#    This is the the formal testbench for all implementations of the N1 DSP   #
//#    cell partition.                                                          #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   October 16, 2018                                                          #
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
`define SP_WIDTH     12
`endif

module ftb_N1_dsp
   (//Clock and reset
    input  wire                             clk_i,                 //module clock
    input  wire                             async_rst_i,           //asynchronous reset
    input  wire                             sync_rst_i,            //synchronous reset

    //ALU interface
    input  wire                             alu2dsp_sub_add_b_i,   //1:op1 - op0, 0:op1 + op0
    input  wire                             alu2dsp_smul_umul_b_i, //1:signed, 0:unsigned
    input  wire [15:0]                      alu2dsp_add_op0_i,     //first operand for adder/subtractor
    input  wire [15:0]                      alu2dsp_add_op1_i,     //second operand for adder/subtractor (zero if no operator selected)
    input  wire [15:0]                      alu2dsp_mul_op0_i,     //first operand for multipliers
    input  wire [15:0]                      alu2dsp_mul_op1_i,     //second operand dor multipliers (zero if no operator selected)
    output wire [31:0]                      dsp2alu_add_res_o,     //result from adder
    output wire [31:0]                      dsp2alu_mul_res_o,     //result from multiplier

    //Flow control interface (program counter)
    input  wire                             fc2dsp_abs_rel_b_i,    //1:absolute COF, 0:relative COF
    input  wire                             fc2dsp_update_i,       //update PC
    input  wire [15:0]                      fc2dsp_rel_adr_i,      //relative COF address
    input  wire [15:0]                      fc2dsp_abs_adr_i,      //absolute COF address
    output wire [15:0]                      dsp2fc_next_pc_o,      //result

    //Intermediate parameter stack interface (AGU, stack grows towards lower addresses)
    input  wire                             ips2dsp_psh_i,         //push (decrement address)
    input  wire                             ips2dsp_pul_i,         //pull (increment address)
    input  wire                             ips2dsp_rst_i,         //reset AGU
    output wire [`SP_WIDTH-1:0]             dsp2ips_lsp_o,         //lower stack pointer

    //Intermediate return stack interface (AGU, stack grows towardshigher addresses)
    input  wire                             irs2dsp_psh_i,         //push (increment address)
    input  wire                             irs2dsp_pul_i,         //pull (decrement address)
    input  wire                             irs2dsp_rst_i,         //reset AGU
    output wire [`SP_WIDTH-1:0]             dsp2irs_lsp_o);        //lower stack pointer

   //Instantiation
   //=============
   N1_dsp
     #(.SP_WIDTH (`SP_WIDTH))
   DUT
     (//Clock and reset
      .clk_i                      (clk_i),                         //module clock
      .async_rst_i                (async_rst_i),                   //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                    //synchronous reset

      //ALU interface
      .alu2dsp_sub_add_b_i        (alu2dsp_sub_add_b_i),           //1:op1 - op0, 0:op1 + op0
      .alu2dsp_smul_umul_b_i      (alu2dsp_smul_umul_b_i),         //1:signed, 0:unsigned
      .alu2dsp_add_op0_i          (alu2dsp_add_op0_i),             //first operand for adder/subtractor
      .alu2dsp_add_op1_i          (alu2dsp_add_op1_i),             //second operand for adder/subtractor (zero if no operator selected)
      .alu2dsp_mul_op0_i          (alu2dsp_mul_op0_i),             //first operand for multipliers
      .alu2dsp_mul_op1_i          (alu2dsp_mul_op1_i),             //second operand dor multipliers (zero if no operator selected)
      .dsp2alu_add_res_o          (dsp2alu_add_res_o),             //result from adder
      .dsp2alu_mul_res_o          (dsp2alu_mul_res_o),             //result from multiplier

      //Flow control interface (program counter)
      .fc2dsp_abs_rel_b_i         (fc2dsp_abs_rel_b_i),            //1:absolute COF, 0:relative COF
      .fc2dsp_update_i            (fc2dsp_update_i),               //update PC
      .fc2dsp_rel_adr_i           (fc2dsp_rel_adr_i),              //relative COF address
      .fc2dsp_abs_adr_i           (fc2dsp_abs_adr_i),              //absolute COF address
      .dsp2fc_next_pc_o           (dsp2fc_next_pc_o),              //result

      //Intermediate parameter stack interface (AGU, stack grows towards lower addresses)
      .ips2dsp_psh_i              (ips2dsp_psh_i),                 //push (decrement address)
      .ips2dsp_pul_i              (ips2dsp_pul_i),                 //pull (increment address)
      .ips2dsp_rst_i              (ips2dsp_rst_i),                 //reset AGU
      .dsp2ips_lsp_o              (dsp2ips_lsp_o),                 //lower stack pointer

      //Intermediate return stack interface (AGU, stack grows towardshigher addresses)
      .irs2dsp_psh_i              (irs2dsp_psh_i),                 //push (increment address)
      .irs2dsp_pul_i              (irs2dsp_pul_i),                 //pull (decrement address)
      .irs2dsp_rst_i              (irs2dsp_rst_i),                 //reset AGU
      .dsp2irs_lsp_o              (dsp2irs_lsp_o));                //lower stack pointer

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //==================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                      (clk_i),                         //module clock
      .sync_i                     (1'b1),                          //clock enable
      .async_rst_i                (async_rst_i),                   //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                    //synchronous reset
      .gated_clk_o                ());                             //gated clock


`endif //  `ifdef FORMAL

endmodule // ftb_N1_dsp
