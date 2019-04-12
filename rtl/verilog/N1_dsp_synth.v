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
    parameter   SP_WIDTH   =  12)                                     //width of a stack pointer

   (//Clock and reset
    input  wire                             clk_i,                    //module clock
    input  wire                             async_rst_i,              //asynchronous reset
    input  wire                             sync_rst_i,               //synchronous reset

    //Program bus (wishbone)
    output wire [15:0]                      pbus_adr_o,               //address bus

    //Internal interfaces
    //-------------------
    //ALU interface
    output wire [31:0]                      dsp2alu_add_res_o,        //result from adder
    output wire [31:0]                      dsp2alu_mul_res_o,        //result from multiplier
    input  wire                             alu2dsp_add_sel_i,        //1:op1 - op0, 0:op1 + op0
    input  wire                             alu2dsp_mul_sel_i,        //1:signed, 0:unsigned
    input  wire [15:0]                      alu2dsp_add_opd0_i,       //first operand for adder/subtractor
    input  wire [15:0]                      alu2dsp_add_opd1_i,       //second operand for adder/subtractor (zero if no operator selected)
    input  wire [15:0]                      alu2dsp_mul_opd0_i,       //first operand for multipliers
    input  wire [15:0]                      alu2dsp_mul_opd1_i,       //second operand dor multipliers (zero if no operator selected)

    //FC interface
    input  wire                             fc2dsp_pc_hold_i,         //maintain PC

    //PAGU interface
    output wire                             pagu2dsp_adr_sel_i,       //1:absolute COF, 0:relative COF
    output wire [15:0]                      pagu2dsp_aadr_i,          //absolute COF address
    output wire [15:0]                      pagu2dsp_radr_i,          //relative COF address

    //PRS interface
    output wire [15:0]                      dsp2prs_pc_o,             //program counter
    output wire [SP_WIDTH-1:0]              dsp2prs_psp_o,            //parameter stack pointer
    output wire [SP_WIDTH-1:0]              dsp2prs_rsp_o,            //return stack pointer

    //SAGU interface
    output wire [SP_WIDTH-1:0]              dsp2sagu_psp_next_o,      //parameter stack pointer
    output wire [SP_WIDTH-1:0]              dsp2sagu_rsp_next_o,      //return stack pointer
    input  wire                             sagu2dsp_psp_hold_i,      //maintain PSP
    input  wire                             sagu2dsp_psp_op_sel_i,    //1:set new PSP, 0:add offset to PSP
    input  wire [SP_WIDTH-1:0]              sagu2dsp_psp_offs_i,      //PSP offset
    input  wire [SP_WIDTH-1:0]              sagu2dsp_psp_load_val_i,  //new PSP
    input  wire                             sagu2dsp_rsp_hold_i,      //maintain RSP
    input  wire                             sagu2dsp_rsp_op_sel_i,    //1:set new RSP, 0:add offset to RSP
    input  wire [SP_WIDTH-1:0]              sagu2dsp_rsp_offs_i,      //relative address
    input  wire [SP_WIDTH-1:0]              sagu2dsp_rsp_load_val_i); //absolute address

   //Internal Signals
   //----------------
   //Program AGU
   reg  [15:0]                              pc_reg;                   //program counter
   //Lower parameter stack AGU
   reg  [SP_WIDTH-1:0]                      psp_reg;                  //parameter stack pointer
   //Lower return  stack AGU
   reg  [SP_WIDTH-1:0]                      rsp_reg;                  //return stack pointer

   //ALU
   //---
   //Adder
   assign dsp2alu_add_res_o = { 15'h0000, {17{alu2dsp_add_sel_i}}} ^
                              ({16'h0000, {16{alu2dsp_add_sel_i}}  ^ alu2dsp_add_opd1_i} +
                               {16'h0000, alu2dsp_add_opd0_i});

   //Multiplier
   assign dsp2alu_mul_res_o = {{16{alu2dsp_mul_sel_i & alu2dsp_mul_opd0_i[15]}}, alu2dsp_mul_opd0_i} *
                              {{16{alu2dsp_mul_sel_i & alu2dsp_mul_opd1_i[15]}}, alu2dsp_mul_opd1_i};

   //Program AGU
   //-----------
   //Program counter
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                              //asynchronous reset
          pc_reg <= 16'h0000;                                         //start address
        else if (sync_rst_i)                                          //synchronous reset
          pc_reg <= 16'h0000;                                         //start address
        else if (~fc2dsp_pc_hold_i)                                   //update PC
          pc_reg <= pbus_adr_o;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Outputs
   assign pbus_adr_o   = pagu2dsp_adr_sel_i ? pagu2dsp_aadr_i :
                                              pagu2dsp_radr_i + pc_reg;
   assign dsp2prs_pc_o = pc_reg;

   //Parameter stack AGU
   //-------------------
   //Stack pointer
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                              //asynchronous reset
          psp_reg <= {SP_WIDTH{1'b0}};                                //TOS
        else if (sync_rst_i)                                          //synchronous reset
          psp_reg <= {SP_WIDTH{1'b0}};                                //TOS
        else if (~sagu2dsp_psp_hold_i)                                //update PSP
          psp_reg <= dsp2sagu_psp_next_o;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Output
   assign dsp2sagu_psp_next_o = sagu2dsp_psp_op_sel_i ? sagu2dsp_psp_load_val_i :
                                                        sagu2dsp_psp_offs_i + psp_reg;
   assign dsp2prs_psp_o       =  psp_reg;

   //Return stack AGU
   //----------------
   //Stack pointer
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                              //asynchronous reset
          rsp_reg <= {SP_WIDTH{1'b0}};                                //TOS
        else if (sync_rst_i)                                          //synchronous reset
          rsp_reg <= {SP_WIDTH{1'b0}};                                //TOS
        else if (~sagu2dsp_rsp_hold_i)                                //update RSP
          rsp_reg <= dsp2sagu_rsp_next_o;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Output
   assign dsp2sagu_rsp_next_o = sagu2dsp_rsp_op_sel_i ? sagu2dsp_rsp_load_val_i :
                                                        sagu2dsp_rsp_offs_i + rsp_reg;
   assign dsp2prs_rsp_o       = rsp_reg;

endmodule // N1_dsp
