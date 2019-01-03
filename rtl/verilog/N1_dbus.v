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
  #(parameter   RESET_ADR     = 15'h0000,                    //address of first instruction
    localparam  CELL_WIDTH    = 16,                          //width of a cell
    localparam  PC_WIDTH      = 15)                          //width of the program counter

   (//Clock and reset
    //---------------
    input wire 			  clk_i,                     //module clock
    input wire 			  async_rst_i,               //asynchronous reset
    input wire 			  sync_rst_i,                //synchronous reset

    //Program bus
    //-----------
    output reg  		  pbus_cyc_o,                //bus cycle indicator       +-
    output reg  		  pbus_stb_o,                //access request            | initiator to target
    output wire [PC_WIDTH-1:0] 	  pbus_adr_o,                //address bus               +-
    input wire 			  pbus_ack_i,                //bus cycle acknowledge     +-
    input wire 			  pbus_err_i,                //error indicator           | target
    input wire 			  pbus_rty_i,                //retry request             | to
    input wire 			  pbus_stall_i,              //access delay              | initiator
   
    //Interrupt interface
    //-------------------
    output wire 		  irq_ack_o,                 //interrupt acknowledge           
    input wire [PC_WIDTH-1:0] 	  irq_vec_i,                 //requested interrupt vector 


    //IR interface
    //------------
    output reg 			  fc_fetch_opc_o,           //fetch opcode from Pbus
    input wire [PC_WIDTH-1:0]     ir_rel_adr_i,             //relative address from opcode
    input wire [PC_WIDTH-1:0]     ir_abs_adr_i,             //absolute address from opcode
    input wire 			  ir_jmp_i,                 //jump decoded (absolute)
    input wire 			  ir_bra_i,                 //branch decoded (relative)
    input wire 			  ir_ret_i,                 //returm decoded (absolute)
  
    //Upper stack interface
    //---------------------
    input wire [CELL_WIDTH-1:0]   ust_ps0_i,                //top of the parameter stack
    input wire [CELL_WIDTH-1:0]   ust_rs0_i,                //top of the return stack
    
    
     
    );

   //Internal signals
   //----------------  
   //State variable
   reg [2:0] 			state_reg;                  //state variable
   reg [2:0] 			state_next;                 //next state
   					                       
   //AGU control signals		                       
   wire [PC_WIDTH-1:0]		agu_abs_adr;                //absolute address
   wire	[PC_WIDTH-1:0]		agu_rel_adr;                //lelative address
   reg                          agu_drv_rst;                //drive reset vector
   reg                          agu_drv_irq;                //drive interrupt vector
   reg                          agu_drv_pc;                 //drive current PC
   reg                          agu_drv_ir;                 //drive absolute address from IR
   reg                          agu_drv_ps;                 //drive absolute address from PS
   reg                          agu_drv_rs;                 //drive absolute address from RS
   reg                          agu_drv_rel;                //drive relative address from IR
   reg                          agu_drv_inc;                //drive address increment
   







   //Finite state machine
   //--------------------
   localparam STATE_COF0  = 'b00;
   localparam STATE_COF1  = 'b00;
   localparam STATE_EXEC0 = 'b00;
   
   always @*
     begin
	//Default outputs
	fc_capt_opc_o   = 1'b0;                             //don't update IR
	fc_bus_err_o    = 1'b0;                             //don't flag bus error
	pbus_cyc_o      = 1'b0;                             //don't request a bus access
	pbus_stb_o      = 1'b0;                             //don't request a bus access
        agu_drv_rst     = 1'b0;                             //don't drive reset vector
        agu_drv_irq     = 1'b0;                             //don't drive interrupt vector
        agu_drv_pc      = 1'b0;                             //don't drive current PC
        agu_drv_ir      = 1'b0;                             //don't drive absolute address from IR
        agu_drv_ps      = 1'b0;                             //don't drive absolute address from PS
        agu_drv_rs      = 1'b0;                             //don't drive absolute address from RS
        agu_drv_rel     = 1'b0;                             //don't drive relative address from IR
        agu_drv_inc     = 1'b0;                             //don't drive address increment
	state_next      = state_reg;                        //no state transition
	
	case (state_reg)
	  STATE_RESET0: //(initiate reset vector fetch from PC)
	    begin
	       agu_drv_rst    = 1'b1;                       //drive reset vector
	       if (~pbus_stall_i)                           //proceed, unless the bus is stalled
		 state_next = STATE_COF1;
	    end // case: STATE_RESET0

	  STATE_COF1: //(check bus response)
	    begin
	       if (pbus_ack_i)                              //opcode available on the data bus
		 begin
		    fc_capt_opc_o  = 1'b1;                  //capture opcode in IR
		    agu_drv_inc    = 1'b1;                  //drive address increment
		    if (~pbus_stall_i)                      //proceed, unless the bus is stalled
		      state_next = STATE_EXEC0;
		    else
		      state_next = STATE_COF1_STALL;
		 end
	       if (pbus_rty_i)                              //retry suggested
		 begin
		    agu_drv_pc     = 1'b1;                  //drive current PC
		 end
	       if (pbus_err_i)                              //bus error occured
		 begin
		    fc_bus_err_o   = 1'b1;                  //flag bus error
		    agu_drv_rst    = 1'b1;                  //drive reset vector
	       	    state_next = STATE_COF1_ERR;            //fetch reset cector 
		 end
	       if (~|{pbus_ack_i, pbus_rty_i, pbus_err_i})  //no response
		 begin
		    agu_drv_pc     = 1'b1;                  //drive current PC
		 end
	    end // case: STATE_COF1
	  
	  

	  STATE_EXEC: //(execute instructuion)
	    
	       if (pbus_ack_i)                              //opcode available on the data bus
		 begin
	    	    fc_capt_opc_o  = 1'b1;                  //capture opcode in IR
		    
		    
		    

	  
 
	  
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





   


   

   //AGU
   //---
   assign agu_rel_adr = ({{PC_WIDTH{agu_drv_rel}} & ir_rel_adr_i});
   
   assign agu_abs_adr = ({PC_WIDTH{agu_drv_rst}} & RESET_ADR)                                   |
			({PC_WIDTH{agu_drv_irq}} & irq_vec_i)                                   |
			({PC_WIDTH{agu_drv_ir}}  & ir_abs_adr_i)                                |
			({PC_WIDTH{agu_drv_ps}}  & ust_ps0_i[CELL_WIDTH-1:CELL_WIDTH-PC_WIDTH]) |
			({PC_WIDTH{agu_drv_rs}}  & ust_ps0_i[CELL_WIDTH-1:CELL_WIDTH-PC_WIDTH]);
   
`ifdef SB_MAC16
   //Use Lattice DSP hard macco if available
   SB_MAC16
     #(.B_SIGNED                 (1'b0 ), //C24        -> unused multiplier
       .A_SIGNED                 (1`b0 ), //C23	       -> unused multiplier
       .MODE_8x8                 (1'b1 ), //C22	       -> unused multiplier
       .BOTADDSUB_CARRYSELECT    (2'b11), //C21,C20    -> incrementer
       .BOTADDSUB_UPPERINPUT     (1'b0 ), //C19	       -> PC
       .BOTADDSUB_LOWERINPUT     (2'b00), //C18,C17    -> relative address
       .BOTOUTPUT_SELECT         (2'b00), //C16,C15    -> output from adder
       .TOPADDSUB_CARRYSELECT    (2'b00), //C14,C13    -> unused adder
       .TOPADDSUB_UPPERINPUT     (1'b1 ), //C12	       -> unused adder
       .TOPADDSUB_LOWERINPUT     (2'b00), //C11,C10    -> unused adder
       .TOPOUTPUT_SELECT         (2'b01), //C9,C8      -> unused output
       .PIPELINE_16x16_MULT_REG2 (1'b1 ), //C7	       -> no pipeline FFs
       .PIPELINE_16x16_MULT_REG1 (1'b1 ), //C6	       -> no pipeline FFs
       .BOT_8x8_MULT_REG         (1'b1 ), //C5	       -> no pipeline FFs 
       .TOP_8x8_MULT_REGv        (1'b1 ), //C4	       -> no pipeline FFs
       .D_REG                    (1'b0 ), //C3	       -> unregistered input
       .B_REG                    (1'b0 ), //C2	       -> unregistered input
       .A_REG                    (1'b1 ), //C1	       -> unused input
       .C_REG                    (1'b1 ), //C0	       -> unused input 
       .NEG_TRIGGER              (1'b0 )) //clock edge -> posedge
   agu
     (
      .A          (16'h0000),             //unused input
      .B          (agu_rel_adr),          //relative address
      .C          (16'h0000),             //unused input
      .D          (agu_abs_adr),          //absolute address
      .O          (agu_out),              //address output
      .CLK        (clk_i),                //clock input
      .CE         (1'b1),                 //always clocked
      .IRSTTOP    (1'b1),                 //keep unused FFs in reset state
      .IRSTBOT    (1'b1),                 //keep unused FFs in reset state
      .ORSTTOP    (1'b1),                 //keep unused FFs in reset state
      .ORSTBOT    (async_rst_i),          //asynchronous reset
      .AHOLD      (1'b1),                 //unused FF
      .BHOLD      (1'b0),                 //unused FF
      .CHOLD      (1'b1),                 //unused FF
      .DHOLD      (1'b0),                 //unused FF
      .OHOLDTOP   (1'b1),                 //unused FF
      .OHOLDBOT   (1'b0),                 //always update PC
      .OLOADTOP   (1'b0),                 //unused FF
      .OLOADBOT   (|{agu_drv_rst,         //load absolute address
		     agu_drv_irq,
		     agu_drv_ir,
		     agu_drv_ps,
		     agu_drv_rs}),        
      .ADDSUBTOP  (1'b0),                 //unused adder
      .ADDSUBBOT  (1'b0),                 //use adder
      .CO         (),                     //unused carry output
      .CI         (agu_drv_inc),          //increment PC
      .ACCUMCI    (1'b0),                 //unused carry input
      .ACCUMCO    (),                     //unused carry output
      .SIGNEXTIN  (1'b0),                 //unused sign extension input
      .SIGNEXTOUT ());                    //unused sign extension output







`else
			 //Program counter				             
   //reg [PC_WIDTH-1:0] 			   pc_reg;           //program counter
   //reg [PC_WIDTH-1:0] 			   pc_next;          //next program counter
   //reg 					   pc_we;            //write enable
						             

   




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

`endif   

  //Address generation unit (AGU)
  //-----------------------------
   assign agu_abs_adr = {PC_WIDTH{ir_cof_abs}} & ir_abs_adr;

   assign agu_rel_adr = ({PC_WIDTH{ir_abs_bra}} &  {{PCWIDTH-1{1'b0}}, 1,b0})) | //increment address



                        {PC_WIDTH{ir_abs_bra}} & 
			(|ust_ps_top ? {{PC_WIDTH-BRANCH_WIDTH{ir_rel_adr[BRANCH_WIDTH-1]}}, ir_rel_adr} :
			               {{PCWIDTH-1{1'b0}}, 1,b0});
   
   



   assign agu_opr = ({REL_ADR_WIDTH{agu_inc}} & {{REL_ADR_WIDTH-1{1'b0}},1'b1}) |
		    ({REL_ADR_WIDTH{agu_dec}} &  {REL_ADR_WIDTH-1{1'b1}})       |
		    ({REL_ADR_WIDTH{agu_rel}} &  ir_rel_adr_i);



   assign pbus_adr_o = agu_abs_adr | (pc_reg + agu_rel_adr);
   






   
   //Program bus outputs
   //-------------------
   assign pbus_cyc_o      = 1'b1;                            //bus cycle indicator 
   assign pbus_stb_o      = 1'b1;                            //access request
   assign pbus_adr_o      = ({PC_WIDTH{agu_abs}} & ir_abs_adr_i)  |                               //address bus
			    ({PC_WIDTH{agu_ret}} & ust_ret_adr_i) |  
			    ({PC_WIDTH{~agu_abs & ~agu_ret}} & agu_res) |  
			    






   
   
   
endmodule // N1_flowctrl
		 
