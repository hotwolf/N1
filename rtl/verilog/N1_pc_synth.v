//###############################################################################
//# N1 - Program Counter (Address Accumulator)                                  #
//###############################################################################
//#    Copyright 2018 - 2025 Dirk Heisswolf                                     #
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
//#    This module implements a 16 bit accumulator for address calculations.    #
//#                                                                             #
//#    The combinational logic address output (pc_addr_o) is intended to be     #
//#    used as memory address. The (internal) accumulator register can serve as #
//#    program counter.                                                         #
//#                                                                             #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 12, 2024                                                         #
//#      - Initial release                                                      #
//#   May 15, 2025                                                              #
//#      - New naming                                                           #
//#   June 2, 2025                                                              #
//#      - Capturing previous PC for interruptable instructions                 #
//###############################################################################
`default_nettype none

module N1_pc
  #(parameter  PC_EXTENSION     =        1,                               //program counter extension
    parameter  INT_EXTENSION    =        1,                               //interrupt extension
    parameter  IMM_PADDR_OFFS   = 16'h0000)                               //offset for immediate program address
   (//Clock and reset
    input  wire                             clk_i,                        //module clock
    input  wire                             async_rst_i,                  //asynchronous reset
    input  wire                             sync_rst_i,                   //synchronous reset

    //FE interface
    input  wire                             fe2pc_update_i,               //switch to next address

    //IR interface
    input  wire [13:0]                      ir2pc_abs_addr_i,             //absolute address
    input  wire [12:0]                      ir2pc_rel_addr_i,             //absolute address
    input  wire                             ir2pc_call_or_jump_i,         //call or jump instruction
    input  wire                             ir2pc_branch_i,               //branch instruction
    input  wire                             ir2pc_return_i,               //return

    //UPRS interface
    input  wire [15:0]                      uprs_ps0_pull_data_i,         //PS0 pull data
    input  wire [15:0]                      uprs_rs0_pull_data_i,                    //RS0 pull data

    //PC outputs
    output wire [15:0]                      pc_next_o,                    //program AGU output
    output wire [15:0]                      pc_prev_o,                    //previous PC

    //Probe signals
    output wire [15:0]                      prb_pc_cur_o,                 //probed current PC
    output wire [15:0]                      prb_pc_prev_o);               //probed previous PC

   //Internal signals
   //----------------
   //Address selection
   wire [15:0]                              abs_addr;                     //absolute address
   wire [16:0]                              rel_addr;                     //relative address
   wire [16:0]                              inc_addr;                     //address increment
   wire [15:0]                              ret_addr;                     //return address
   wire [15:0]                              next_addr;                    //next address

   //Program counter
   reg  [15:0]                              pc_reg;                       //program counter
   reg  [15:0]                              pc_prev_reg;                  //previous program counter
   
   //Address selection
   assign abs_addr     = &ir2pc_abs_addr_i ?                                       //absolute address
			    uprs_ps0_pull_data_i :                                 //PS0
                            {IMM_PADDR_OFFS[15:14],ir2pc_abs_addr_i};              //immediate address   
   assign rel_addr     = {{3{ir2pc_rel_addr_i[12]}},ir2pc_rel_addr_i} + pc_reg;    //relative address
   assign inc_addr     =                                     16'h0001 + pc_reg;    //address increment
   assign ret_addr     = uprs_rs0_pull_data_i;                                     //return address

   assign next_addr    = ir2pc_call_or_jump_i                   ? abs_addr       : //absolute address
			 ir2pc_branch_i & |uprs_ps0_pull_data_i ? rel_addr[15:0] : //relative address
			 ir2pc_return_i                         ? ret_addr[15:0] : //return address
                                                                  inc_addr;        //address increment

   //AGU accumulator
   //---------------
   //Program counter
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                  //asynchronous reset
          begin
             pc_reg      <= 16'h0000;                                     //start address
             pc_prev_reg <= 16'h0000;                                     //start address
          end
        else if (sync_rst_i)                                              //synchronous reset
          begin
             pc_reg      <= 16'h0000;                                     //start address
             pc_prev_reg <= 16'h0000;                                     //start address
          end
        else if (fe2pc_update_i)                                          //update PC
          begin
             pc_reg      <= next_addr;                                    //current PC
             pc_prev_reg <= PC_EXTENSION|INT_EXTENSION ? pc_reg :         //previous PC
                                                         16'h0000;
          end
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Outputs
   assign pc_next_o     = acc_out;                                        //opcode fetch address
   assign pc_prev_o     = pc_prev_reg;                                    //return address

   //Probe signals
   assign prb_pc_cur_o   = pc_reg;                                        //current PC
   assign prb_pc_prev_o  = pc_prev_reg;                                   //previous PC

endmodule // N1_pc
