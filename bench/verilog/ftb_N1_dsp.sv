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

    //Flow control interface (program counter)
    input  wire                             fc_dsp_abs_rel_b_i,    //1:absolute COF, 0:relative COF
    input  wire                             fc_dsp_update_i,       //update PC
    input  wire [15:0]                      fc_dsp_rel_adr_i,      //relative COF address
    input  wire [15:0]                      fc_dsp_abs_adr_i,      //absolute COF address
    output wire [15:0]                      fc_dsp_next_pc_o,      //result

    //ALU interface
    input  wire                             alu_dsp_sub_add_b_i,   //1:op1 - op0, 0:op1 + op0
    input  wire                             alu_dsp_smul_umul_b_i, //1:signed, 0:unsigned
    input  wire [15:0]                      alu_dsp_add_op0_i,     //first operand for adder/subtractor
    input  wire [15:0]                      alu_dsp_add_op1_i,     //second operand for adder/subtractor (zero if no operator selected)
    input  wire [15:0]                      alu_dsp_mul_op0_i,     //first operand for multipliers
    input  wire [15:0]                      alu_dsp_mul_op1_i,     //second operand dor multipliers (zero if no operator selected)
    output wire [31:0]                      alu_dsp_add_res_o,     //result from adder
    output wire [31:0]                      alu_dsp_mul_res_o,     //result from multiplier

    //Intermediate parameter stack interface (AGU, stack grows towards lower addresses)
    input  wire                             ips_dsp_psh_i,         //push (decrement address)
    input  wire                             ips_dsp_pul_i,         //pull (increment address)
    input  wire                             ips_dsp_rst_i,         //reset AGU
    output wire [`SP_WIDTH-1:0]             ips_dsp_sp_o,          //stack pointer

    //Intermediate return stack interface (AGU, stack grows towardshigher addresses)
    input  wire                             irs_dsp_psh_i,         //push (increment address)
    input  wire                             irs_dsp_pul_i,         //pull (decrement address)
    input  wire                             irs_dsp_rst_i,         //reset AGU
    output wire [`SP_WIDTH-1:0]             irs_dsp_sp_o);         //stack pointer

   //Instantiation
   //=============
   N1_dsp
     #(.SP_WIDTH (`SP_WIDTH))
   DUT
     (//Clock and reset
      .clk_i                      (clk_i),                         //module clock
      .async_rst_i                (async_rst_i),                   //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                    //synchronous reset

      //Flow control interface (program counter)
      .fc_dsp_abs_rel_b_i         (fc_dsp_abs_rel_b_i),            //1:absolute COF, 0:relative COF
      .fc_dsp_update_i            (fc_dsp_update_i),               //update PC
      .fc_dsp_rel_adr_i           (fc_dsp_rel_adr_i),              //relative COF address
      .fc_dsp_abs_adr_i           (fc_dsp_abs_adr_i),              //absolute COF address
      .fc_dsp_next_pc_o           (fc_dsp_next_pc_o),              //result

      //ALU interface
      .alu_dsp_sub_add_b_i        (alu_dsp_sub_add_b_i),           //1:op1 - op0, 0:op1 + op0
      .alu_dsp_smul_umul_b_i      (alu_dsp_smul_umul_b_i),         //1:signed, 0:unsigned
      .alu_dsp_add_op0_i          (alu_dsp_add_op0_i),             //first operand for adder/subtractor
      .alu_dsp_add_op1_i          (alu_dsp_add_op1_i),             //second operand for adder/subtractor (zero if no operator selected)
      .alu_dsp_mul_op0_i          (alu_dsp_mul_op0_i),             //first operand for multipliers
      .alu_dsp_mul_op1_i          (alu_dsp_mul_op1_i),             //second operand dor multipliers (zero if no operator selected)
      .alu_dsp_add_res_o          (alu_dsp_add_res_o),             //result from adder
      .alu_dsp_mul_res_o          (alu_dsp_mul_res_o),             //result from multiplier

      //Intermediate parameter stack interface (AGU, stack grows towards lower addresses)
      .ips_dsp_psh_i              (ips_dsp_psh_i),                 //push (decrement address)
      .ips_dsp_pul_i              (ips_dsp_pul_i),                 //pull (increment address)
      .ips_dsp_rst_i              (ips_dsp_rst_i),                 //reset AGU
      .ips_dsp_sp_o               (ips_dsp_sp_o),                  //stack pointer

      //Intermediate return stack interface (AGU, stack grows towardshigher addresses)
      .irs_dsp_psh_i              (irs_dsp_psh_i),                 //push (increment address)
      .irs_dsp_pul_i              (irs_dsp_pul_i),                 //pull (decrement address)
      .irs_dsp_rst_i              (irs_dsp_rst_i),                 //reset AGU
      .irs_dsp_sp_o               (irs_dsp_sp_o));                 //stack pointer

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
