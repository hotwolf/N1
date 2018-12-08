//###############################################################################
//# N1 - Flow control                                                           #
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
//#    This module implements the N1's program counter (PC) and the program bus #
//#    (Pbus).                                                                  #
//#                                                                             #
//#    Linear program flow:                                                     #
//#                                                                             #
//#                     +----+----+----+----+----+----+                         #
//#    Program Counter  |PC0 |PC1 |PC2 |PC3 |PC4 |PC5 |                         #
//#                +----+----+----+----+----+----+----+                         #
//#    Address bus | A0 | A1 | A2 | A3 | A4 | A5 |                              #
//#                +----+----+----+----+----+----+----+                         #
//#    Data bus         | D0 | D1 | D2 | D3 | D4 | D5 |                         #
//#                     +----+----+----+----+----+----+----+                    #
//#    Instruction decoding  | I0 | I1 | I2 | I3 | I4 | I5 |                    #
//#                          +----+----+----+----+----+----+                    #
//#                                                                             #
//#                                                                             #
//#    Change of flow:                                                          #
//#                                                                             #
//#                     +----+----+----+----+----+----+                         #
//#    Program Counter  |PC0 |PC1 |PC2 |PC3 |PC4 |PC5 |                         #
//#                +----+----+----+----+----+----+----+                         #
//#    Address bus | A0 | A1 |*A2 | A3 | A4 | A5 |                              #
//#                +----+----+----+----+----+----+----+                         #
//#    Data bus         | D0 | D1 | D2 | D3 | D4 | D5 |                         #
//#                     +----+----+----+----+----+----+----+                    #
//#    Instruction decoding  |COF |    | D2 | I3 | I4 | I5 |                    #
//#                          +----+    +----+----+----+----+                    #
//#                                                                             #
//#                                                                             #
//#    Refetch opcode:                                                          #
//#                                                                             #
//#                     +----+----+----+----+----+----+                         #
//#    Program Counter  |PC0 |PC1 |PC1 |PC1 |PC2 |PC3 |                         #
//#                +----+----+----+----+----+----+----+                         #
//#    Address bus | A0 | A1 | A2 | A1 | A2 | A3 |                              #
//#                +----+----+----+----+----+----+----+                         #
//#    Data bus         | D0 |RTY | D1 | D1 | D2 | D3 |                         #
//#                     +----+----+----+----+----+----+----+                    #
//#    Instruction decoding  | I0 |         | I1 | I2 | I3 |                    #
//#                          +----+         +----+----+----+                    #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_flowctrl
  #(parameter  RST_ADR        = 14'h0000,  //reset entry point
    parameter  EXCPT_ADR      = 14'h0001,  //exception entry point
    parameter  IRQ_ADR        = 14'h0002,  //interrupt entry point
    localparam PC_WIDTH       = 14,        //width of the program counter
    localparam REL_ADR_WIDTH  = 13)        //branch address width

   (//Clock and reset
    //---------------
    input wire                             clk_i,            //module clock
    input wire                             async_rst_i,      //asynchronous reset
    input wire                             sync_rst_i,       //synchronous reset

    //Program bus
    //-----------
    output wire                            pbus_cyc_o,       //bus cycle indicator       +-
    output wire                            pbus_stb_o,       //access request            | initiator to target
    output wire [PC_WIDTH-1:0]             pbus_adr_o,       //address bus               +-
    input  wire                            pbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                            pbus_err_i,       //error indicator           | target
    input  wire                            pbus_rty_i,       //retry request             | to
    input  wire                            pbus_stall_i,     //access delay              | initiator

    



    
    
    //FSM interface
    //-------------

    //IR interface
    //------------
    output reg                             fc_fetch_opc_o,   //fetch opcode from Pbus
    input  wire [REL_ADR_WIDTH-1:0]        ir_rel_adr_i,     //relative address from opcode
    input  wire [PC_WIDTH-1:0]             ir_abs_adr_i,     //absolute address from opcode
    input  wire                            ir_jmp_i,         //jump decoded (absolute)
    input  wire                            ir_bra_i,         //branch decoded (relative)
    input  wire                            ir_ret_i,         //returm decoded (absolute)
  
    //Upper stack interface
    //---------------------

    
    
     
    );

   //Internal signals
   //----------------  
   //State variable
   reg [2:0] 				   state_reg;        //state variable
   reg [2:0] 				   state_next;       //next state
   						             
   //Program counter				             
   reg [PC_WIDTH-1:0] 			   pc_reg;           //program counter
   reg [PC_WIDTH-1:0] 			   pc_next;          //next program counter
   reg 					   pc_we;            //write enable
						             
   //AGU control signals			             
   reg 					   agu_inc;          //increment program counter
   reg 					   agu_dec;          //decrement program counter
   reg 					   agu_rel;          //resolve relative address
   reg 					   agu_abs;          //set absolute address
   reg 					   agu_ret;          //set return address
   wire [REL_ADR_WIDTH-1:0]		   agu_opr;          //operand for AGU adder
   wire	[PC_WIDTH-1:0]		           agu_res;          //result of AGU adder

       
   //State transitions
   //-----------------
   localparam STATE_COF0  = 'b00;
   localparam STATE_COF1  = 'b00;
   localparam STATE_EXEC0 = 'b00;
   
   always @*
     begin
	//Default outputs
	fc_fetch_opc_o = 1'b0;                               //fetch opcode from Pbus
     	agu_inc        = 1'b0;                               //increment program counter
	agu_dec        = 1'b0;                               //decrement program counter
	agu_rel        = 1'b0;                               //resolve relative address
	agu_abs        = 1'b0;                               //set absolute address
	agu_ret        = 1'b0;                               //set return address
	pc_we          = 1'b0;                               //update program counter
	state_next     = state_reg;                          //state transition
	
	case (state_reg)
	  STATE_COF0: //(initiate opcode fetch from PC)
	    begin
	       fc_fetch_opc_o = 1'b0;                        //fetch opcode from Pbus
     	       agu_inc        = 1'b0;                        //increment program counter
	       agu_dec        = 1'b0;                        //decrement program counter
	       agu_rel        = 1'b0;                        //resolve relative address
	       agu_abs        = 1'b0;                        //set absolute address
	       agu_ret        = 1'b0;                        //set return address
	       pc_we          = 1,b0;                        //update program counter
	       if (~pbus_stall_i)                            //state transition
		 state_next = STATE_CF1;
	    end // case: STATE_COF0
	  
	  STATE_COF1: //(initiate opcode fetch from PC+1)
	    begin
	       fc_fetch_opc_o = pbus_ack_i;                  //fetch opcode from Pbus
     	       agu_inc        = 1'b1;                        //increment program counter
	       agu_dec        = 1'b0;                        //decrement program counter
	       agu_rel        = 1'b0;                        //resolve relative address
	       agu_abs        = 1'b0;                        //set absolute address
	       agu_ret        = 1'b0;                        //set return address
	       pc_we          = pbus_ack_i;                  //update program counter
	       if (~pbus_stall_i & pbus_ack_i)               //state transition
		 state_next = STATE_CF1;
	    end // case: STATE_COF1
	  
 

   //Address generation unit (AGU)
   //-----------------------------
   assign agu_opr = ({REL_ADR_WIDTH{agu_inc}} & {{REL_ADR_WIDTH-1{1'b0}},1'b1}) |
		    ({REL_ADR_WIDTH{agu_dec}} &  {REL_ADR_WIDTH-1{1'b1}})       |
		    ({REL_ADR_WIDTH{agu_rel}} &  ir_rel_adr_i);

   N1_adder
     #(.OPR0_WIDTH(PC_WIDTH),
       .OPR1_WIDTH(REL_ADR_WIDTH),
       .RES_WIDTH(PC_WIDTH)) agu 
       (.opr0 (pc_reg),
	.opr1 (agu_opr),
	.res  (agu_res));
   
   assign pc_next = pbus_adr_o

   //Program bus outputs
   //-------------------
   assign pbus_cyc_o      = 1'b1;                            //bus cycle indicator 
   assign pbus_stb_o      = 1'b1;                            //access request
   assign pbus_adr_o      = ({PC_WIDTH{agu_abs}} & ir_abs_adr_i)  |                               //address bus
			    ({PC_WIDTH{agu_ret}} & ust_ret_adr_i) |  
			    ({PC_WIDTH{~agu_abs & ~agu_ret}} & agu_res) |  
			    


	  
   //Flip flops
   //----------
   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     begin
	if (async_rst_i)
	  state_reg <= STATE_RESET;
	else if (sync_rst_i)
	  state_reg <= STATE_RESET;
	else
	  state_reg <= state_next;
     end // always @ (posedge async_rst_i or posedge clk_i)
   
   //Program counter
   always @(posedge async_rst_i or posedge clk_i)
     begin
	if (async_rst_i)
	  pc_req <= rst_adr;
	else if (sync_rst_i)
	  pc_req <= rst_adr;
        else if (pc_we)
	  pc_reg <= pc_next;
     end // always @ (posedge async_rst_i or posedge clk_i)
   
endmodule // N1_flowctrl
		 
