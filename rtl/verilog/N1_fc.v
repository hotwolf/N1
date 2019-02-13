//###############################################################################
//# N1 - Flow control                                                           #
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
    input wire 			     clk_i,                  //module clock
    input wire 			     async_rst_i,            //asynchronous reset
    input wire 			     sync_rst_i,             //synchronous reset
				     
    //Program bus		     	     
    output wire                      pbus_cyc_o,             //bus cycle indicator       +-
    output wire                      pbus_stb_o,             //access request            |
    output wire                      pbus_we_o,              //write enable              |
    output wire                      pbus_tga_rst_o,         //reset                     |
    output wire                      pbus_tga_excpt_o,       //exception                 |
    output wire                      pbus_tga_irq_o,         //interrupt request         | initiator
    output wire                      pbus_tga_jmp_imm_o,     //immediate jump            | to	    
    output wire                      pbus_tga_jmp_ind_o,     //indirect jump             | target   
    output wire                      pbus_tga_cal_imm_o,     //immediate call            |
    output wire                      pbus_tga_cal_ind_o,     //indirect call             |
    output wire                      pbus_tga_bra_imm_o,     //immediate branch          |
    output wire                      pbus_tga_bra_ind_o,     //indirect branch           |
    output wire                      pbus_tga_dat_imm_o,     //immediate data access     |
    output wire                      pbus_tga_dat_ind_o,     //indirect data access      +-
    input  wire                      pbus_ack_i,             //bus cycle                 +-
    input  wire                      pbus_err_i,             //error indicator           | target
    input  wire                      pbus_rty_i,             //retry request             | to initiator
    input  wire                      pbus_stall_i,           //access delay              +-
   
    //Interrupt interface
    output wire                      irq_ack_o,              //interrupt acknowledge
    input  wire [15:0]               irq_req_adr_i,          //requested interrupt vector

    //Exception interface
    output wire                      fc2excpt_buserr;        //bus error 
    input  wire [PC_WIDTH-1:0]       excpt2fc_throw,         //requested interrupt vector
				     
    //IR interface		     
    output  wire                     ir_capture_i,           //capture current IR   
    output  wire                     ir_hoard_i,             //capture hoarded IR
    output  wire                     ir_expend_i,            //hoarded IR -> current IR
  				     
    //Upper stack interface	     
    output  wire                     ust_fetch_o,           //capture current IR
    output  wire                     ust_store_o,           //capture current IR
    output  wire                     ust_fetch_o,           //capture current IR
    output  wire                     ust_fetch_o,           //capture current IR


    input wire [CELL_WIDTH-1:0]      ust_ps0_i,              //top of the parameter stack
    input wire [CELL_WIDTH-1:0]      ust_rs0_i,              //top of the return stack
    
    //Hard IP interface (program counter)
    output wire                      pc_abs_o,               //drive absolute address
    output wire                      pc_update_o,            //update PC
    output wire [PC_WIDTH-1:0]       pc_rel_adr_o,           //relative COF address
    output wire [PC_WIDTH-1:0]       pc_abs_adr_o);          //absolute COF address

   //Internal signals
   //----------------  
   //State variable
   reg [2:0] 			  state_reg;                 //state variable
   reg [2:0] 			  state_next;                //next state
   				
	                       
  




   //Finite state machine
   //--------------------
   localparam STATE_COF0   = 'b00;
   localparam STATE_COF1   = 'b00;
   localparam STATE_EXEC0  = 'b00;
   			   
   always @*		   
     begin		   
        //Default autputs
        pbus_cyc_o	   = 1'b1;                            1'b1;                            //request
        pbus_stb_o	   = 1'b1;                            // bus access
        pbus_we_o	   = 1'b0;                            //read access  
        pbus_sel_o	   = 2'b11;                           //word access  
        pbus_tga_rst_o     = 1'b0;                            //no reset             
        pbus_tga_excpt_o   = 1'b0;                            //no exception         
        pbus_tga_irq_o	   = 1'b0;                            //no interrupt request 
        pbus_tga_jmp_imm_o = 1'b0;                            //no immediate jump         
        pbus_tga_jmp_ind_o = 1'b0;                            //no indirect jump          
        pbus_tga_cal_imm_o = 1'b0;                            //no immediate call         
        pbus_tga_cal_ind_o = 1'b0;                            //no indirect call          
        pbus_tga_bra_imm_o = 1'b0;                            //no immediate branch       
        pbus_tga_bra_ind_o = 1'b0;                            //no indirect branch        
        pbus_tga_dat_imm_o = 1'b0;                            //no immediate data access  
        pbus_tga_dat_ind_o = 1'b0;                            //no indirect data access   
        excpt_ack_o        = 1'b0;                            //exception acknowledge           
        excpt_throw_pbus_o = pbus_err_i;                      //throw pbus error 
        irq_block_o        = 1'b0;                            //don't block interrupts        
        irq_unblock_o      = 1'b0;                            //don't unblock interrupts        
        irq_ack_o	   = 1'b0;                            //no interrupt acknowledge           
        ir_capture_i	   = 1'b0;                            //capture current IR   
        ir_hoard_i	   = 1'b0;                            //capture hoarded IR
        ir_expend_i	   = 1'b0;                            //don't update IR
        pc_abs_o	   = 1'b0;                            //drive absolute address
        pc_update_o	   = ~pbus_stall;                     //update PC
        pc_rel_adr_o	   = 15'h0001;                        //increment
        pc_abs_adr_o	   = RESET_ADR;                       //start of code	
	state_next         = state_reg;                       //remain in current state  

	case (state_reg)
	  STATE_RESET: //(Jump to start of code)
	    begin
               pbus_tga_rst_o     = 1'b1;                     //signal reset             
               excpt_ack_o        = 1'b1;                     //acknowledge any pending exception          
               irq_block_o        = 1'b1;                     //don't block interrupts        
               irq_ack_o          = 1'b0;                     //acknowledge any pending interrupt request           
	       excpt_throw_pbus_o = 1'b0;                     //ignore bus response 
	       pc_abs_o	          = 1'b1;                     //drive reset address
	       state_next         = pbus_stall_i ?            //continue if bus is available
				       state_reg :
                                       STATE_FETCH_1ST;
	    end // case: STATE_RESET

	  STATE_EXCPT: //(Jump to exception vector)
	    begin
               pbus_tga_excpt_o   = 1'b1;                     //signal resetexception             
               excpt_ack_o        = 1'b1;                     //acknowledge any pending exception          
               irq_block_o        = 1'b1;                     //don't block interrupts        
               irq_ack_o          = 1'b0;                     //acknowledge any pending interrupt request           
	       excpt_throw_pbus_o = 1'b0;                     //ignore bus response 
	       pc_abs_o	          = 1'b1;                     //drive reset address
               pc_abs_adr_o	  = excpt_vec_i;              //exception vector	
	       state_next         = pbus_stall_i ?            //continue if bus is available
				       state_reg :
                                       STATE_FETCH_1ST;
	    end // case: STATE_EXEPT
	  
	  STATE_IRQ: //(Jump to interrupt vector)
	    begin
               pbus_tga_irq_o     = 1'b1;                     //signal interrupt request             
               excpt_ack_o        = 1'b1;                     //acknowledge any pending exception          
               irq_block_o        = 1'b1;                     //don't block interrupts        
               irq_ack_o          = 1'b0;                     //acknowledge any pending interrupt request           
	       excpt_throw_pbus_o = 1'b0;                     //ignore bus response 
	       pc_abs_o	          = 1'b1;                     //drive reset address
               pc_abs_adr_o	  = irq_vec_i;                //exception vector	
	       state_next         = pbus_stall_i ?            //continue if bus is available
				       state_reg :
                                       STATE_FETCH_1ST;
	    end // case: STATE_IRQ	  
	  
	  STATE_FETCH_1ST: //(Fetch first opcode)
	    begin
	       if (pbus_ack_i |                               //wait for acknowledge
		   pbus_rty_i |                               //
		   pbus_err_i)                                //
		 begin
		   if (|excpt_vec_i)                          //exception 		     
		     begin
			pbus_stb_o  = 1'b0;                   //pause bus access
                        pc_update_o = 1'b0;                   //don'tupdate PC
			state_next  = STATE_EXCPT;            //handle exception
		     end
		    else if (|irq_vec_i)                      //interrupt request
		     begin
			pbus_stb_o  = 1'b0;                   //pause bus access
                        pc_update_o = 1'b0;                   //don'tupdate PC
                        ust_call_o  = 1'b1;                   //



			  
			state_next  = STATE_IRQ;              //handle exception
		     end















		      



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
		 
