//###############################################################################
//# N1 - Synthesizable Replacement of the Hard IP Partition                     #
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
//#    This particular implementation is a generic synthesizable implementation #
//#    for targets without arithmetic macro cells.                              #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 10, 2019                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_hm
  #(parameter   SP_WIDTH   =  8,                                  //width of a stack pointer
    localparam  CELL_WIDTH = 16,                                  //width of a cell
    localparam  PC_WIDTH   = 15)                                  //width of the program counter

   (//Clock and reset
    input  wire                             clk_i,                //module clock
    input  wire                             async_rst_i,          //asynchronous reset
    input  wire                             sync_rst_i,           //synchronous reset

    //Flow control interface (program counter)
    input  wire                             fc_hm_abs_rel_b_i,    //1:absolute COF, 0:relative COF
    input  wire                             fc_hm_update_i,       //update PC
    input  wire [PC_WIDTH-1:0]              fc_hm_rel_adr_i,      //relative COF address
    input  wire [PC_WIDTH-1:0]              fc_hm_abs_adr_i,      //absolute COF address
    output wire [PC_WIDTH-1:0]              fc_hm_next_pc_o,      //result

    //ALU interface
    input wire                              alu_hm_sub_add_b_i,   //1:op1 - op0, 0:op1 + op0
    input wire                              alu_hm_smul_umul_b_i, //1:signed, 0:unsigned
    input wire  [CELL_WIDTH-1:0]            alu_hm_add_op0_i,     //first operand for adder/subtractor
    input wire  [CELL_WIDTH-1:0]            alu_hm_add_op1_i,     //second operand for adder/subtractor (zero if no operator selected)
    input wire  [CELL_WIDTH-1:0]            alu_hm_mul_op0_i,     //first operand for multipliers
    input wire  [CELL_WIDTH-1:0]            alu_hm_mul_op1_i,     //second operand dor multipliers (zero if no operator selected)
    output wire [(2*CELL_WIDTH)-1:0]        alu_hm_add_res_o,     //result from adder
    output wire [(2*CELL_WIDTH)-1:0]        alu_hm_mul_res_o,     //result from multiplier

    //Intermediate parameter stack interface (AGU, stack grows towards lower addresses)
    input  wire                             ips_hm_psh_i,         //push (decrement address)
    input  wire                             ips_hm_pul_i,         //pull (increment address)
    input  wire                             ips_hm_rst_i,         //reset AGU
    output wire [SP_WIDTH-1:0]              ips_hm_sp_o,          //stack pointer

    //Intermediate return stack interface (AGU, stack grows tpwardshigher addresses)
    input  wire                             irs_hm_psh_i,         //push (increment address)
    input  wire                             irs_hm_pul_i,         //pull (decrement address)
    input  wire                             irs_hm_rst_i,         //reset AGU
    output wire [SP_WIDTH-1:0]              irs_hm_sp_o);         //stack pointer

   //Internal Signals
   //----------------
   //Program AGU
   reg  [PC_WIDTH-1:0]                      pc_reg;               //program counter
   wire [PC_WIDTH:0]                        pc_agu_sum;           //long AGU result
   //ALU
   wire [CELL_WIDTH:0]                      alu_sum;              //long sum
   wire [(4*CELL_WIDTH)-1:0]                alu_prod;             //long product
   //Lower parameter stack AGU
   reg  [SP_WIDTH-1:0]                      lps_sp_reg;           //stack pointer
   wire [SP_WIDTH:0]                        lps_agu_sum;          //long AGU result
   //Lower return  stack AGU
   reg  [SP_WIDTH-1:0]                      lrs_sp_reg;           //stack pointer
   wire [SP_WIDTH:0]                        lrs_agu_sum;          //long AGU result

   //Program AGU
   //-----------
   //In-/decrementer
   assign pc_agu_sum = fc_hm_rel_adr_i + pc_reg;

   //Stack pointer
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                          //asynchronous reset
          pc_reg <= {PC_WIDTH{1'b0}};                             //start address
        else if (sync_rst_i)                                      //synchronous reset
          pc_reg <= {SP_WIDTH{1'b0}};                             //start address
        else if (fc_hm_update_i)                                  //update PC
           pc_reg <= fc_hm_next_pc_o;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Output
   assign fc_hm_next_pc_o = fc_hm_abs_rel_b_i ? fc_hm_abs_adr_i :
                                                pc_agu_sum[PC_WIDTH-1:0];

   //ALU
   //---
   //Adder
   assign alu_sum  = {CELL_WIDTH+1{alu_hm_sub_add_b_i}} ^
                     (({CELL_WIDTH{alu_hm_sub_add_b_i}} ^ alu_hm_op1_i) + alu_hm_op0_i);

   //Multiplier
   assign alu_prod = {{CELL_WIDTH{alu_smul_umul_b_i & alu_op0_i[CELL_WIDTH-1]}}, alu_op0_i} *
                     {{CELL_WIDTH{alu_smul_umul_b_i & alu_op1_i[CELL_WIDTH-1]}}, alu_op1_i};

   //Output
   assign alu_hm_add_res_o = {{CELL_WIDTH-1{alu_smul_umul_b_i & alu_sum[CELL_WIDTH]}}, alu_sum};
   assign alu_hm_mul_res_o = alu_prod;

   //Lower parameter stack AGU
   //-------------------------
   //In-/decrementer
   assign lps_agu_sum = {{SP_WIDTH-1{lps_agu_psh_i}},1'b1} + lps_sp_reg;

   //Stack pointer
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                          //asynchronous reset
          lps_sp_reg <= {SP_WIDTH{1'b0}};                         //TOS
        else if (sync_rst_i)                                      //synchronous reset
          lps_sp_reg <= {SP_WIDTH{1'b0}};                         //TOS
        else if (ips_hm_psh_i|ips_hm_pul_i|ips_hm_rst_i)          //update SP
          lps_sp_reg <= ips_hm_rst_i ? {SP_WIDTH{1'b0}} :
                                        lps_agu_sum[SP_WIDTH-1:0];
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Output
   assign ips_hm_sp_o = lps_sp_reg;

   //Lower return stack AGU
   //----------------------
   //In-/decrementer
   assign lrs_agu_sum = {{SP_WIDTH-1{irs_hm_psh_i}},1'b1} + lrs_sp_reg;

   //Stack pointer
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                          //asynchronous reset
          lrs_sp_reg <= {SP_WIDTH{1'b0}};                         //TOS
        else if (sync_rst_i)                                      //synchronous reset
          lrs_sp_reg <= {SP_WIDTH{1'b0}};                         //TOS
        else if (irs_hm_psh_i|irs_hm_pul_i|irs_hm_rst_i)          //update SP
          lrs_sp_reg <= irs_hm_rst_i ? {SP_WIDTH{1'b0}} :
                                        lrs_agu_sum[SP_WIDTH-1:0];
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Output
   assign irs_hm_sp_o = lrs_sp_reg;

endmodule // N1_hard
