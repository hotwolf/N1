//###############################################################################
//# N1 - Exception and Interrupt Aggregator                                     #
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
//#    This module captures and masks exceptions and interrupts.                #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 20, 2019                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_excpt
   (//Clock and reset
    input wire 			     clk_i,                  //module clock
    input wire 			     async_rst_i,            //asynchronous reset
    input wire 			     sync_rst_i,             //synchronous reset
				     
    //Interrupt interface
    output wire                      irq_ack_o,              //interrupt acknowledge
    input  wire [15:0]               irq_req_adr_i,          //requested interrupt vector

    //Internal interfaces
    //-------------------
    //FC interface
    output wire                      excpt2fc_excpt_o,       //exception to be handled
    output wire                      excpt2fc_irq_o,         //exception to be handled
    input  wire                      excpt2fc_excpt_dis_i,   //disable exceptions
    input  wire                      excpt2fc_buserr_i,      //pbus error

    //IR interface
    input  wire                      ir2excpt_except_en_i,   //enable exceptions
    input  wire                      ir2excpt_irq_en_i,      //enable interrupts
    input  wire                      ir2excpt_irq_dis_i,     //disable interrupts

    //PRS interface
    output wire [15:0]               excpt2prs_tc_o,         //throw code
    input  wire                      prs2excpt_psof_i,       //PS overflow    
    input  wire                      prs2excpt_psuf_i,       //PS underflow   
    input  wire                      prs2excpt_rsof_i,       //RS overflow    
    input  wire                      prs2excpt_rsuf_i,       //RS underflow   



    

);



   //Internal signals
   //----------------  
   
   //Interrupts
   reg 				     irq_en_req;             //current interrupt enable
   reg 				     irq_en_next;            //next interrupt enable
 				     
   //Exceptions
   reg 				     excpt_en_req;           //current exception enable
   reg 				     excpt_en_next;          //next exception enable
   reg [4:0] 			     excpt_reg;              //current exceptions
   reg [4:0]			     excpt_next;             //next exceptions
   
   //State variable
   reg  [2:0] 			     state_reg;              //state variable
   reg  [2:0] 			     state_next;             //next state
   				
	                       
  










   



   //Finite state machine
   //--------------------
   localparam STATE_COF0   = 'b00;
   localparam STATE_COF1   = 'b00;
   localparam STATE_EXEC0  = 'b00;
   			   
   always @*		   
     begin		   
        //Default outputs
        pbus_cyc_o		= 1'b1;                      //bus cycle indicator    
        pbus_stb_o		= 1'b1;                      //access request         
        pbus_we_o		= 1'b0;                      //write enable           
        pbus_adr_o		= 16'h0000;                  //address bus            
        pbus_tga_cof_jmp_o	= 1'b0;                      //COF jump               
        pbus_tga_cof_cal_o	= 1'b0;                      //COF call               
        pbus_tga_cof_bra_o	= 1'b0;                      //COF conditional branch  
        pbus_tga_cof_ret_o	= 1'b0;                      //COF return from call    	
        pbus_tga_dat_o	        = 1'b0;                      //data access         
        pbus_tga_dir_adr_o	= 1'b0;                      //direct addressing   
        pbus_tga_imm_adr_o	= 1'b0;                      //immediate addressing
        
        
        fc2dsp_abs_rel_b_o	= 1'b0;                      //relative address
        fc2dsp_hold_o	        = 1'b0;                      //maintain PC 
        fc2dsp_rel_adr_o	= 16'h0000;                  //relative COF address
        fc2dsp_abs_adr_o	= 16'h0000;                  //absolute COF address
        
        fc2ir_capture_o	        = 1'b0;                      //capture current IR
        fc2ir_stash_o	        = 1'b0;                      //capture stashed IR
        fc2ir_expend_o	        = 1'b0;                      //stashed IR -> current IR
        fc2ir_clr_o	        = 1'b0;                      //clear IR

	fc2prs_stp_o            = 12'h000;                   //stack transition pattern
	fc2prs_rs0_next_o       = 16'h0000;                  //RS0 output
	
	state_next              = 0;                         //remain in current state  
	irq_en_next             = irq_en_req;                //interrupt enable
	excpt_en_next           = excpt_en_req;              //exception enable
	excpt_next              = excpt_req;                 //exceptions
	
	//Capture exceptions
	if (~|excpt_tc_reg)
	  begin
	     excpt_tc_next = {prs2fc_psof_i,                 //PS overflow    
			      prs2fc_psuf_i,                 //PS underflow   
			      prs2fc_rsof_i,                 //RS overflow    
			      prs2fc_rsuf_i,                 //RS underflow   
			      prs2fc_buserr_i};              //stack bus error
	  end

	//Default AGU configuration
	//Jump or Call
	if (ir2fc_jmp_i | 
	    ir2fc_cal_i)			           
	  begin				           
	     fc2dsp_abs_rel_b_o = 1'b1;                      //drive absolute address  
	     fc2dsp_abs_adr_o   = fc2dsp_abs_adr_o    |      //         
				  (ir2fc_sel_absdir_i ?      //direct or indirect addressing
				   ir2fc_absdir_i     :      //direct address
				   prs2fc_ps0_i);            //indirect address
	  end
	//Conditional branch
	if (ir2fc_bra_i)
	  begin
	     fc2dsp_rel_adr_o   = fc2dsp_rel_adr_o    |      //
				  (ir2fc_sel_reldir_i ?      //direct or indirect addressing
				   (|prs2fc_ps0_i    ?       //flag in PS0
				    ir2fc_reldir_i   :       //direct address
				    16'h0001)         :      //increment
				   (|prs2fc_ps1_i    ?       //flag in PS1
				    prs2fc_ps0_i     :       //indirect address
				    16'h0000));              //increment
	  end
	//Memory IO	
	if (ir2fc_mem_i)			           
	  begin				           
	     fc2dsp_abs_rel_b_o = 1'b1;                      //drive absolute address  
	     fc2dsp_abs_adr_o   = fc2dsp_abs_adr_o  |        //         
				  (ir2fc_sel_imm_i  ?        //immediate or indirect addressing
				   ir2fc_imm_i     :         //immediate address
				   prs2fc_ps0_i);            //indirect address
	  end
	//Single cycle instruction
	if (ir2fc_lit_i | 
	    ir2fc_alu_i | 
	    ir2fc_stk_i | 
	    ir2fc_ctrl_i)
	  begin
	     fc2dsp_abs_adr_o   = fc2dsp_abs_adr_o  |        //
				  16'h0001);                 //increment
	  end
		  			   
	case (state_reg)

	  



		    
		    
	  STATE_EXEC:
	    begin
	       //Wait for bus response (stay in sync with memory)
	       if (~pbus_ack_i &                                   //no bus acknowledge    
		   ~pbus_err_i &                                   //no error indicator
	           ~pbus_rty_i)                                    //no retry request
		 begin					           
                    pbus_cyc_o    = 1'b0;                          //delay next access		    
		    fc2dsp_hold_o = 1'b1;                          //don't update PC
		    fc2prs_hold_o = 1'b1;                          //don't update stacks 		    
		    state_next    = state_reg;                     //remain in current state
		 end					           
	       //Wait for stacks		           
	       else if (prs2fc_hold_i)                             //stacks are busy
		 begin
		    fc2ir_stash_o   = 1'b1;                        //stash next instruction
		    if (pbus_ack_i)                                   //acknowledge received
		      begin					   
			 state_next = state_next |                 //remember ACK
				      STATE_EXEC_ACK;		   
		      end	    	    			   
		    if (pbus_err_i)                                //acknowledge received
		      begin					   
			 state_next = state_next |                 //remember ERR
				      STATE_EXEC_ERR;		   
		      end					   
		    if (pbus_rty_i)                                //acknowledge received
		      begin					   
			 state_next = state_next |                 //remember RTY
				       STATE_EXEC_RTY;
		      end
		 end
	       //Execute instruction
	       if (ir2fc_mem_i)
		//Memory I/O
		 begin
		    fc2dsp_hold_o = 1'b1;                          //don't update PC
		    


		 end
	       else
		 //Single cycle instruction
		 begin
		    //Enforce NOP after COF
		    if (ir2fc_jmp_or_cal_i | (ir2fc_bra_i & prs2fc_ps0_i)) //COF
		      begin
			      fc2ir_load_nop_o = 1'b1;             //NOP -> IR
		      end
		    //Enforce separated EOW
		    if (ir2fc_eow_conflict_i)
		      begin
			      fc2ir_load_eow_o = 1'b1;             //EOW -> IR
		      end
	 	    //determine next state
		    





		    state_next    = state_reg;                     //remain in current state
	       	 end // else: !if(ir2fc_mem_i)
	    end // case: STATE_EXEC
	  


	endcase // case (state_reg)
	


	  
	  
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
   assign agu_rel_adr = ({{16{agu_drv_rel}} & ir_rel_adr_i});
   
   assign agu_abs_adr = ({16{agu_drv_rst}} & RESET_ADR)                                   |
			({16{agu_drv_irq}} & irq_vec_i)                                   |
			({16{agu_drv_ir}}  & ir_abs_adr_i)                                |
			({16{agu_drv_ps}}  & ust_ps0_i[CELL_WIDTH-1:CELL_WIDTH-16]) |
			({16{agu_drv_rs}}  & ust_ps0_i[CELL_WIDTH-1:CELL_WIDTH-16]);
   
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
   //reg [15:0] 			   pc_reg;           //program counter
   //reg [15:0] 			   pc_next;          //next program counter
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
   assign agu_abs_adr = {16{ir_cof_abs}} & ir_abs_adr;

   assign agu_rel_adr = ({16{ir_abs_bra}} &  {{PCWIDTH-1{1'b0}}, 1,b0})) | //increment address



                        {16{ir_abs_bra}} & 
			(|ust_ps_top ? {{16-BRANCH_WIDTH{ir_rel_adr[BRANCH_WIDTH-1]}}, ir_rel_adr} :
			               {{PCWIDTH-1{1'b0}}, 1,b0});
   
   



   assign agu_opr = ({REL_ADR_WIDTH{agu_inc}} & {{REL_ADR_WIDTH-1{1'b0}},1'b1}) |
		    ({REL_ADR_WIDTH{agu_dec}} &  {REL_ADR_WIDTH-1{1'b1}})       |
		    ({REL_ADR_WIDTH{agu_rel}} &  ir_rel_adr_i);



   assign pbus_adr_o = agu_abs_adr | (pc_reg + agu_rel_adr);
   






   
   //Program bus outputs
   //-------------------
   assign pbus_cyc_o      = 1'b1;                            //bus cycle indicator 
   assign pbus_stb_o      = 1'b1;                            //access request
   assign pbus_adr_o      = ({16{agu_abs}} & ir_abs_adr_i)  |                               //address bus
			    ({16{agu_ret}} & ust_ret_adr_i) |  
			    ({16{~agu_abs & ~agu_ret}} & agu_res) |  
			    






   
   
   
endmodule // N1_flowctrl
		 
