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
    //---------------
    input wire                    clk_i,                    //module clock
    input wire                    async_rst_i,              //asynchronous reset
    input wire                    sync_rst_i,               //synchronous reset
						            
    //Program bus				            
    //-----------				            
    input  wire [CELL_WIDTH-1:0]  pbus_dat_i,               //read data
						            
    //IR interface				            
    //------------				            
    input  wire                   ir_capt_cur_i,            //capture current IR   
    input  wire                   ir_capt_next_i,           //capture next IR
    input  wire                   ir_next_2_cur_i,          //next IR -> current IR
    
    output wire [PC_WIDTH-1:0]    ir_abs_adr_o,             //absolute address from opcode
    output wire [PC_WIDTH-1:0]    ir_rel_adr_o,             //relative address from opcode
    output wire [CELL_WIDTH-1:0]  ir_lit_o,                 //literal value
    output wire [CELL_WIDTH-1:0]  ir_io_adr_o,              //immediate I/O address
    output wire [STP_WIDTH-1:0]   ir_stp_o,                 //stack transition pattern 
    output wire [STP_WIDTH-1:0]   ir_alu_opr_o,             //ALU operator 
    output wire [STP_WIDTH-1:0]   ir_alu_opd_o,             //ALU operand 
    


    
    //Upper stack interface
    //---------------------



    
    );





   
   
   //Internal signals
   //----------------  
   //instruction registers
   reg  [CELL_WIDTH-1:0] 	ir_cur_reg;                 //current instruction
   reg  [CELL_WIDTH-1:0] 	ir_next_reg;                //next instruction


   //Instruction decoding
   //--------------------  
   assign ir_abs_adr_o = {{CELL_WIDTH-14{1'b0},            ir_cur_reg[13:0]};
   assign ir_rel_adr_o = {{CELL_WIDTH-13{ir_cur_reg[12]}}, ir_cur_reg[12:0]};
   assign ir_lit_o     = {{CELL_WIDTH-12{ir_cur_reg[11]}}, ir_cur_reg[11:0]};
   assign ir_io_adr_o  = {{CELL_WIDTH-11{1'b0},            ir_cur_reg[9:0], 1'b0};
   assign ir_stp_o     = ir_cur_reg[STP_WIDTH-1:0];
   assign ir_alu_opt_o = ir_cur_reg[7:4];
   assign ir_alu_opd_o = ir_cur_reg[3:0];
   
   //Flip flops
   //----------
   //Instruction registers
   always @(posedge async_rst_i or posedge clk_i)
     begin
	if (async_rst_i)
	  begin
	     ir_cur_reg  <= {CELL_WIDTH:1'b0}};
	     ir_next_reg <= {CELL_WIDTH:1'b0}}; 
	  end
	else if (sync_rst_i)
	  begin
	     ir_cur_reg  <= {CELL_WIDTH:1'b0}};
	     ir_next_reg <= {CELL_WIDTH:1'b0}}; 
	  end
	else
	  begin
	     if (|{ir_capt_cur_i, ir_next_2_cur_i})
	       ir_cur_reg   <= (({CELL_WIDTH{ir_capt_cur_i}}   & pbus_dat_i) |
	                        ({CELL_WIDTH{ir_next_2_cur_i}} & ir_next_reg));	     
	     if (ir_capt_next_i, ir_next_2_cur_i}
	       ir_next_reg  <= pbus_dat_i;
	  end // else: !if(sync_rst_i)
     end // always @ (posedge async_rst_i or posedge clk_i)

endmodule // N1_ir
