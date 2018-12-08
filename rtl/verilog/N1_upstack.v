//###############################################################################
//# N1 - Upper Stacks                                                           #
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
//#    This module implements the upper stacks of the N1 processor. The upper   #
//#    stacks contain the top most cells of the partameter and the return       #
//#    stack. They provide direct access to their cells and are capable of      #
//#    performing stack operations.                                             #
//#                                                                             #
//#  Imm.  |                  Upper Stack                   |    Upper   | Imm. #
//#  Stack |                                                |    Stack   | St.  #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#      |<->|  PS3  |<=>|  PS2  |<=>|  PS1  |<=>|  PS0  |<===>|  RS0  |<->|    #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#                                                 TOS     |     TOS           #
//#                          Parameter Stack                | Return Stack      #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_upstack
  #(parameter CELL_WIDTH  = 16)   //cell width
   
   (//Clock and reset
    //---------------
    input wire                             clk_i,            //module clock
    input wire                             async_rst_i,      //asynchronous reset
    input wire                             sync_rst_i,       //synchronous reset

    //IR interface
    //------------
   
    
   
    
   
    
   
    
   
    
    //ALU interface
    //------------- 
    output wire [CELL_WIDTH-1:0]           alu_psinfo_up_o,  //stack status 
    output wire [CELL_WIDTH-1:0]           alu_op0_o,        //1st operand
    output wire [CELL_WIDTH-1:0]           alu_op1_o,        //2nd operand
    input  wire [(2*CELL_WIDTH)-1:0]       alu_res_i,        //result

    //Dbus interface
    //--------------
    output wire [CELL_WIDTH-1:0]           dbus_adr_o,       //address
    output wire [CELL_WIDTH-1:0]           dbus_dat_o,       //write data
    input  wire [CELL_WIDTH-1:0]           dbus_dat_i,       //read data
    
    //Interface io lower return stack
    //-------------------------------
    output wire [CELL_WIDTH:0]             rs0_o,            //RS0 (TOS)
    input  wire [CELL_WIDTH:0]             rs1_i,            //RS1 (TOS+1)
   
    //Interface io lower parameter stack
    //----------------------------------
    output wire [CELL_WIDTH:0]             ps3_o,            //PS3 (TOS+3)
    input  wire [CELL_WIDTH:0]             ps4_i,            //PS4 (TOS+4)
    
    );
   
   //Stack cells
   reg  [CELL_WIDTH:0] 			   rs0_reg;          //RS0 (TOS)
   reg  [CELL_WIDTH:0] 			   ps0_reg;          //PS0 (TOS)
   reg  [CELL_WIDTH:0] 			   ps1_reg;          //PS1 (TOS+1)
   reg  [CELL_WIDTH:0] 			   ps2_reg;          //PS2 (TOS+2)
   reg  [CELL_WIDTH:0] 			   ps3_reg;          //PS3 (TOS+3)
   
   //Stack transition controls 
   reg                                     ps0_to_rs0;       //PS0  -> RS0
   reg                                     rs1_to_rs0;       //RS1  -> RS0
   reg                                     alu_to_ps0;       //ALU  -> PS0
   reg                                     dbus_to_ps0;      //DBUS -> PS0
   reg                                     rs0_to_ps0;       //RS0  -> PS0
   reg                                     ps1_t0_ps0;       //PS1  -> PS0
   reg                                     alu_to_ps1;       //ALU  -> PS1
   reg                                     ps0_to_ps1;       //PS0  -> PS1
   reg                                     ps2_t0_ps1;       //PS2  -> PS1
   reg                                     ps1_to_ps2;       //PS1  -> PS2
   reg                                     ps3_t0_ps2;       //PS3  -> PS2
   reg                                     ps2_to_ps3;       //PS2  -> PS3
   reg                                     ps4_to_ps3;       //PS4  -> PS3

   





   



   
   //Flip flops
   always @(posedge async_rst_i or posedge clk_i)
     begin
	if (async_rst_i)
	  begin                                              //asynchronous reset
	     rs0_reg <= {CELL_WIDTH+1{1'b0}};                //return stack:    TOS
             ps0_reg <= {CELL_WIDTH+1{1'b0}};                //parameter stack: TOS
             ps1_reg <= {CELL_WIDTH+1{1'b0}};                //parameter stack: TOS+1
             ps2_reg <= {CELL_WIDTH+1{1'b0}};                //parameter stack: TOS+2
             ps3_reg <= {CELL_WIDTH+1{1'b0}};                //parameter stack: TOS+3
          end
        else if (sync_rst_i)
          begin                                              //asynchronous reset
   	     rs0_reg <= {CELL_WIDTH+1{1'b0}};                //return stack:    TOS
             ps0_reg <= {CELL_WIDTH+1{1'b0}};                //parameter stack: TOS
             ps1_reg <= {CELL_WIDTH+1{1'b0}};                //parameter stack: TOS+1
             ps2_reg <= {CELL_WIDTH+1{1'b0}};                //parameter stack: TOS+2
             ps3_reg <= {CELL_WIDTH+1{1'b0}};                //parameter stack: TOS+3
          end
        else
          begin                                              //asynchronous reset
	     //RS0 (TOS)
	     if (ps0_to_rs0 |
                 rs1_to_rs0)
	       rs0_reg <= ({CELL_WIDTH+1{ps0_to_rs0}} & ps0_reg) |
	     	          ({CELL_WIDTH+1{rs1_to_rs0}} & rs1_i);
	     //PS0 (TOS)
	     if (alu_to_ps0  |
		 dbus_to_ps0 |
		 rs0_to_ps0  |
		 ps1_t0_ps0)
	       ps0_reg <= ({CELL_WIDTH+1{alu_to_ps0}} & {1'b1, alu_res_i[CELL_WIDTH-1:0]})  |
		          ({CELL_WIDTH+1{alu_to_ps0}} & {1'b1, dbus_dat_i[CELL_WIDTH-1:0]}) |
		          ({CELL_WIDTH+1{rs0_to_ps0}} & rs0)                                |
		          ({CELL_WIDTH+1{ps1_to_ps0}} & ps1);
	     //PS1 (TOS+1)
	     if (alu_to_ps1 |
		 ps0_to_ps1 |
		 ps2_t0_ps1)
	       ps1_reg <= ({CELL_WIDTH+1{alu_to_ps1}} & {1'b1, alu_in[(2*CELL_WIDTH)-1:CELL_WIDTH]}) |
		          ({CELL_WIDTH+1{ps0_to_ps1}} & rs0)                                         |
		          ({CELL_WIDTH+1{ps2_to_ps1}} & ps2);
	     //PS2 (TOS+2)
	     if (ps1_to_ps2 |
		 ps3_t0_ps2)
	       ps2_reg <= ({CELL_WIDTH+1{ps1_to_ps12} & ps1) |
		          ({CELL_WIDTH+1{ps3_to_ps12} & ps3);	
	     //PS3 (TOS+3)
	     if (ps2_to_ps3 |
                 ps4_to_ps3)
	       rs3_reg <= ({CELL_WIDTH+1{ps2_to_ps3}} & ps0_reg) |
	     	          ({CELL_WIDTH+1{ps4_to_ps3}} & ps4_i);
          end // else: !if(sync_rst_i)
     end // always @ (posedge async_rst_i or posedge clk_i)

endmodule // N1_upstack
