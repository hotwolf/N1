//###############################################################################
//# N1 - Synthesizable Replacement of the DSP Cell Partition                    #
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
//#    This is a synthesizable replacement for the DSP cell partition. It can   #
//#    used for verification and automatic DSP cell allocation.                 #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 10, 2019                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_dsp
  #(//Integration parameters
    parameter   SP_WIDTH   =  12)                                  //width of a stack pointer

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
    output wire [SP_WIDTH-1:0]              ips_dsp_sp_o,          //stack pointer

    //Intermediate return stack interface (AGU, stack grows tpwardshigher addresses)
    input  wire                             irs_dsp_psh_i,         //push (increment address)
    input  wire                             irs_dsp_pul_i,         //pull (decrement address)
    input  wire                             irs_dsp_rst_i,         //reset AGU
    output wire [SP_WIDTH-1:0]              irs_dsp_sp_o);         //stack pointer

   //Internal Signals
   //----------------
   //Program AGU
   reg  [15:0]                              pc_reg;                //program counter
   wire [16:0]                              pc_agu_out;            //long AGU result
   //ALU
   wire [16:0]                              alu_add_out;           //long sum
   wire [31:0]                              alu_mul_out;           //long product
   //Lower parameter stack AGU
   reg  [SP_WIDTH-1:0]                      lps_sp_reg;            //stack pointer
   wire [SP_WIDTH:0]                        lps_agu_out;           //long AGU result
   //Lower return  stack AGU
   reg  [SP_WIDTH-1:0]                      lrs_sp_reg;            //stack pointer
   wire [SP_WIDTH:0]                        lrs_agu_out;           //long AGU result

   //Program AGU
   //-----------
   //In-/decrementer
   assign pc_agu_out = fc_dsp_rel_adr_i + pc_reg;

   //Stack pointer
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                          //asynchronous reset
          pc_reg <= {16{1'b0}};                                   //start address
        else if (sync_rst_i)                                      //synchronous reset
          pc_reg <= {16{1'b0}};                                   //start address
        else if (fc_dsp_update_i)                                 //update PC
          pc_reg <= fc_dsp_next_pc_o;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Output
   assign fc_dsp_next_pc_o = fc_dsp_abs_rel_b_i ? fc_dsp_abs_adr_i :
                                                  pc_agu_out[15:0];

   //ALU
   //---
   //Adder
   assign alu_add_out  = {16+1{alu_dsp_sub_add_b_i}} ^
                     ({1'b0, {16{alu_dsp_sub_add_b_i}} ^ alu_dsp_add_op1_i} +
                      {1'b0, alu_dsp_add_op0_i});

   //Multiplier
   assign alu_mul_out = {{16{alu_dsp_smul_umul_b_i & alu_dsp_mul_op0_i[15]}}, alu_dsp_mul_op0_i} *
                     {{16{alu_dsp_smul_umul_b_i & alu_dsp_mul_op1_i[15]}}, alu_dsp_mul_op1_i};

   //Output
   assign alu_dsp_add_res_o[31:16] = alu_dsp_smul_umul_b_i ? {16{alu_add_out[16]}} :
                                                             {{15{1'b0}}, alu_add_out[16]};
   assign alu_dsp_add_res_o[15:0]  = alu_add_out[15:0];
   assign alu_dsp_mul_res_o        = alu_mul_out;

   //Lower parameter stack AGU
   //-------------------------
   //In-/decrementer
   assign lps_agu_out = {{SP_WIDTH-1{ips_dsp_psh_i}},1'b1} + lps_sp_reg;

   //Stack pointer
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                          //asynchronous reset
          lps_sp_reg <= {SP_WIDTH{1'b0}};                         //TOS
        else if (sync_rst_i)                                      //synchronous reset
          lps_sp_reg <= {SP_WIDTH{1'b0}};                         //TOS
        else if (ips_dsp_psh_i|ips_dsp_pul_i|ips_dsp_rst_i)       //update SP
          lps_sp_reg <= ips_dsp_rst_i ? {SP_WIDTH{1'b0}} :
                                        lps_agu_out[SP_WIDTH-1:0];
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Output
   assign ips_dsp_sp_o = lps_sp_reg;

   //Lower return stack AGU
   //----------------------
   //In-/decrementer
   assign lrs_agu_out = {{SP_WIDTH-1{irs_dsp_psh_i}},1'b1} + lrs_sp_reg;

   //Stack pointer
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                          //asynchronous reset
          lrs_sp_reg <= {SP_WIDTH{1'b0}};                         //TOS
        else if (sync_rst_i)                                      //synchronous reset
          lrs_sp_reg <= {SP_WIDTH{1'b0}};                         //TOS
        else if (irs_dsp_psh_i|irs_dsp_pul_i|irs_dsp_rst_i)       //update SP
          lrs_sp_reg <= irs_dsp_rst_i ? {SP_WIDTH{1'b0}} :
                                        lrs_agu_out[SP_WIDTH-1:0];
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Output
   assign irs_dsp_sp_o = lrs_sp_reg;

endmodule // N1_dsp
