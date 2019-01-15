//###############################################################################
//# N1 - Instruction Register                                                   #
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
//#    This module implements the N1's instruction register(IR) and the related #
//#    logic.                                                                   #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_ir
  #(localparam CELL_WIDTH  = 16,   //cell width
    localparam PC_WIDTH    = 15)   //width of the program counter
    localparam STP_WIDTH   = 10)   //width of the stack transition pattern

   (//Clock and reset
    input wire                    clk_i,                    //module clock
    input wire                    async_rst_i,              //asynchronous reset
    input wire                    sync_rst_i,               //synchronous reset

    //Parameter stack interface				            
    input  wire [CELL_WIDTH-1:0]  ps1_i,                    //TOS+1
    input  wire [CELL_WIDTH-1:0]  ps0_i,                    //TOS
						            
    //IR interface				            
    input  wire [CELL_WIDTH-1:0]  ir_dat_i,                 //read data input
    input  wire                   ir_capture_i,             //capture current IR   
    input  wire                   ir_hoard_i,               //capture hoarded IR
    input  wire                   ir_expend_i,              //hoarded IR -> current IR

    //Program Counter
    output wire                   pc_rel_o,                 //add address offset
    output wire                   pc_abs_o,                 //drive absolute address
    output wire [PC_WIDTH-1:0]    pc_rel_adr_o,             //relative COF address
    output wire [PC_WIDTH-1:0]    pc_abs_adr_o,             //absolute COF address
 
    //ALU
    output wire                   alu_add_o,                //op1 + op0
    output wire                   alu_sub_o,                //op1 - op0
    output wire                   alu_umul_o,               //op1 * op0 (unsigned)
    output wire                   alu_smul_o,               //op1 * op0 (signed)
    output wire  [CELL_WIDTH-1:0] alu_op0_o,                //first operand
    output wire  [CELL_WIDTH-1:0] alu_op1_o,                //second operand
   
    //Literal
    output wire  [CELL_WIDTH-1:0] ir_lit_o,                 //literal value

    //Upper stacks
    output wire  [STP_WIDTH-1:0]  us_stp_o,                 //stack transition pattern





    output wire [CELL_WIDTH-1:0]  ir_lit_o,                 //literal value


    output wire [CELL_WIDTH-1:0]  ir_io_adr_o,              //immediate I/O address
    output wire [STP_WIDTH-1:0]   ir_stp_o,                 //stack transition pattern 
    output wire [STP_WIDTH-1:0]   ir_alu_opr_o,             //ALU operator 
    output wire [STP_WIDTH-1:0]   ir_alu_opd_o,


             //ALU operand 
    

    
    //Upper stack interface
    //---------------------





    
    );





   
   
   //Internal signals
   //----------------  
   //Instruction registers
   reg  [CELL_WIDTH-1:0] 	ir_cur_reg;                  //current instruction register
   reg  [CELL_WIDTH-1:0] 	ir_hoard_reg;                //hoarded instruction register

   //Flip flops
   //----------
   //Current instruction register
   always @(posedge async_rst_i or posedge clk_i)
     begin
	if (async_rst_i)                                    //asynchronous reset
	  ir_cur_reg  <= {CELL_WIDTH{1'b0}};
	else if (sync_rst_i)                                //synchronous reset
	  ir_cur_reg  <= {CELL_WIDTH{1'b0}};
	else if (ir_capture_i | ir_expend_i)                //update IR
	  ir_cur_reg  <= (({CELL_WIDTH{ir_capture_i}} &  ir_dat_i) |
	                  ({CELL_WIDTH{ir_expend_i}}  &  ir_hoard_reg));
      end // always @ (posedge async_rst_i or posedge clk_i)
   
   //Hoarded instruction register
   always @(posedge async_rst_i or posedge clk_i)
     begin
	if (async_rst_i)                                    //asynchronous reset
	  ir_hoard_reg  <= {CELL_WIDTH{1'b0}};
	else if (sync_rst_i)                                //synchronous reset
	  ir_hoard_reg  <= {CELL_WIDTH{1'b0}};
	else if (ir_hoard_i)                                //capture opcode
	  ir_hoard_reg  <= ir_dat_i;
      end // always @ (posedge async_rst_i or posedge clk_i)
  
   //Instruction decoding
   //--------------------  
   assign ir_abs_adr_o = {{CELL_WIDTH-14{1'b0},            ir_cur_reg[13:0]};
   assign ir_rel_adr_o = {{CELL_WIDTH-13{ir_cur_reg[12]}}, ir_cur_reg[12:0]};
   assign ir_lit_o     = {{CELL_WIDTH-12{ir_cur_reg[11]}}, ir_cur_reg[11:0]};
   assign ir_io_adr_o  = {{CELL_WIDTH-11{1'b0},            ir_cur_reg[9:0], 1'b0};
   assign ir_stp_o     = ir_cur_reg[STP_WIDTH-1:0];
   assign ir_alu_opt_o = ir_cur_reg[7:4];
   assign ir_alu_opd_o = ir_cur_reg[3:0];
   










endmodule // N1_ir
