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
    localparam IMOP_WIDTH  =  5)   //width of immediate operands

   (//Clock and reset
    input wire                    clk_i,                    //module clock
    input wire                    async_rst_i,              //asynchronous reset
    input wire                    sync_rst_i,               //synchronous reset

    //Flow control interface				            
    input  wire                   ir_capture_i,             //capture current IR   
    input  wire                   ir_hoard_i,               //capture hoarded IR
    input  wire                   ir_expend_i,              //hoarded IR -> current IR

    //Program bus interface				            
    input  wire [CELL_WIDTH-1:0]  pbus_dat_i,                 //read data input

    //IR ALU interface				            
    output wire                   ir_add_o,                //op1 +  op0
    output wire                   ir_sub_o,                //op1 -  op0
    output wire                   ir_umul_o,               //op1 *  op0 (unsigned)
    output wire                   ir_smul_o,               //op1 *  op0 (signed)
    output wire                   ir_and_o,                //op1 &  op0
    output wire                   ir_or_o,                 //op1 |  op0
    output wire                   ir_xor_o,                //op1 ^  op0
    output wire                   ir_neg_o,                //      -op0
    output wire                   ir_lt_o,                 //      -op0
    output wire                   ir_eq_o,                 //      -op0





    output wire                   alu_lsh_o,                //op1 << op0
    output wire                   alu_rsh_o,                //op1 >> op0


    output wire [IMOP_WIDTH-1:0]  ir_imop_i,                //immediate ALU operand 

    output wire [CELL_WIDTH-1:0]  ir_ps0_i,                 //literal value 
    output wire [CELL_WIDTH-1:0]  ir_rs0_i,                 //COF address 

    output wire                   ir_ps_reset_i,            //reset stack
    output wire                   ir_rs_reset_i,            //reset stack

    output wire                   ir_pagu_to_rs0_i          //pbus_dat_i -> RS0
    output wire                   ir_ir_to_rs0_i            //opcode     -> RS0
    output wire                   ir_ps0_to_rs0_i           //PS0        -> RS0  
    output wire                   ir_rs1_to_rs0_i           //RS1        -> RS0  
    output wire                   ir_rs0_to_rs1_i           //RS0        -> RS1  
    output wire                   ir_pbus_to_ps0_i          //pbus_dat_i -> PS0
    output wire                   ir_ir_to_ps0_i            //opcode     -> RS0
    output wire                   ir_alu_to_ps0_i           //ALU        -> PS0
    output wire                   ir_rs0_to_ps0_i           //RS0        -> PS0
    output wire                   ir_ps1_to_ps0_i           //PS1        -> PS0
    output wire                   ir_alu_to_ps1_i           //ALU        -> RS1
    output wire                   ir_ps0_to_ps1_i           //PS0        -> PS1
    output wire                   ir_ps2_to_ps1_i           //PS2        -> PS1
    output wire                   ir_ps1_to_ps2_i           //PS1        -> PS2
    output wire                   ir_ps3_to_ps2_i           //PS3        -> PS2
    output wire                   ir_ps2_to_ps3_i           //PS2        -> PS3
    output wire                   ir_ps4_to_ps3_i           //PS4        -> PS3
    output wire                   ir_ps3_to_ps4_i           //PS3        -> PS4

  


    //Parameter stack interface				            
    input  wire [CELL_WIDTH-1:0]  ps1_i,                    //TOS+1
    input  wire [CELL_WIDTH-1:0]  ps0_i,                    //TOS
						            


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
