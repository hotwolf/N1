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
//#    This module implements the finite state machine of the N1 CPU, which     #
//#    contols the execution flow.                                              #
//#                                                                             #
//#    Linear program flow:                                                     #
//#                                                                             #
//#                     +----+----+----+----+----+----+                         #
//#    Program counter  |PC0 |PC1 |PC2 |PC3 |PC4 |PC5 |                         #
//#                +----+----+----+----+----+----+----+                         #
//#    Address bus | A0 | A1 | A2 | A3 | A4 | A5 |                              #
//#                +----+----+----+----+----+----+----+                         #
//#    Data bus         | D0 | D1 | D2 | D3 | D4 | D5 |                         #
//#                     +----+----+----+----+----+----+----+                    #
//#    Instruction register  | I0 | I1 | I2 | I3 | I4 | I5 |                    #
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
//#    Instruction register  |COF |    | I2 | I3 | I4 | I5 |                    #
//#                          +----+    +----+----+----+----+                    #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//#   May 8, 2019                                                               #
//#      - Added RTY_I support to PBUS                                          #
//###############################################################################
`default_nettype none

module N1_fc
   (//Clock and reset
    input wire                       clk_i,                                                    //module clock
    input wire                       async_rst_i,                                              //asynchronous reset
    input wire                       sync_rst_i,                                               //synchronous reset

    //Program bus
    output wire                      pbus_cyc_o,                                               //bus cycle indicator       +-
    output reg                       pbus_stb_o,                                               //access request            | initiator to target
    input  wire                      pbus_ack_i,                                               //bus acknowledge           +-
    input  wire                      pbus_err_i,                                               //error indicator           | target to
    input  wire                      pbus_rty_i,                                               //retry request             | initiator
    input  wire                      pbus_stall_i,                                             //access delay              +-

    //Interrupt interface
    output reg                       irq_ack_o,                                                //interrupt acknowledge

    //Internal interfaces
    //-------------------
    //DSP interface
    output reg                       fc2dsp_pc_hold_o,                                         //maintain PC
    output reg                       fc2dsp_radr_inc_o,                                        //increment relative address

    //IR interface
    output reg                       fc2ir_capture_o,                                          //capture current IR
    output reg                       fc2ir_stash_o,                                            //capture stashed IR
    output reg                       fc2ir_expend_o,                                           //stashed IR -> current IR
    output reg                       fc2ir_force_eow_o,                                        //load EOW bit
    output reg                       fc2ir_force_0call_o,                                      //load 0 CALL instruction
    output reg                       fc2ir_force_call_o,                                       //load CALL instruction
    output reg                       fc2ir_force_drop_o,                                       //load DROP instruction
    output reg                       fc2ir_force_nop_o,                                        //load NOP instruction
    input  wire                      ir2fc_eow_i,                                              //end of word (EOW bit set)
    input  wire                      ir2fc_eow_postpone_i,                                     //EOW conflict detected
    input  wire                      ir2fc_jump_or_call_i,                                     //either JUMP or CALL
    input  wire                      ir2fc_bra_i,                                              //conditonal BRANCH instruction
    input  wire                      ir2fc_scyc_i,                                             //linear flow
    input  wire                      ir2fc_mem_i,                                              //memory I/O
    input  wire                      ir2fc_mem_rd_i,                                           //memory read
    input  wire                      ir2fc_madr_sel_i,                                         //direct memory address

    //PAGU interface
    output wire                      fc2pagu_prev_adr_hold_o,           //do not use                       //maintain stored address
    output wire                      fc2pagu_prev_adr_sel_o,            //do not use                       //0:AGU output, 1:previous address

    //PRS interface
    output reg                       fc2prs_hold_o,                                            //hold any state tran
    output reg                       fc2prs_dat2ps0_o,                                         //capture read data
    output reg                       fc2prs_tc2ps0_o,                                          //capture throw code
    output reg                       fc2prs_isr2ps0_o,                                         //capture ISR
    input  wire                      prs2fc_hold_i,                                            //stacks not ready
    input  wire                      prs2fc_ps0_false_i,                                       //PS0 is zero

    //EXCPT interface
    output reg                       fc2excpt_excpt_clr_o,                                     //clear and disable exceptions
    output reg                       fc2excpt_irq_dis_o,                                       //disable interrupts
    output wire                      fc2excpt_buserr_o,                                        //invalid pbus access
    input  wire                      excpt2fc_excpt_i,                                         //exception to be handled
    input  wire                      excpt2fc_irq_i,                                           //exception to be handled

    //Probe signals
    output wire [2:0]                prb_fc_state_o,                                           //state variable
    output wire                      prb_fc_pbus_acc_o);                                       //ongoing bus access

   //Internal signals
   //----------------
   //FSM interfaces
   reg                               fsm_exec_ir_hold;                                         //keep IR content
   reg                               fsm_pbus_hold;                                            //bus delay

   //State variables
   reg                               fsm_pbus_state_reg;                                       //current PBUS state
   reg                               fsm_pbus_state_next;                                      //next PBUS state
   reg                               fsm_ir_state_reg;                                         //current IR state
   reg                               fsm_ir_state_next;                                        //next IR state

   //PBUS monitor
   //------------
   assign pbus_acc_next =  (pbus_stb_o & ~pbus_stall_i) |                                      //bus cycle initiation
                          ~(pbus_acc_reg & (pbus_ack_i | pbus_err_i));                         //bus cycle termination

   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                                       //asynchronous reset
          pbus_acc_reg <= 1'b0;
        else if (sync_rst_i)                                                                   //synchronous reset
          pbus_acc_reg <= 1'b0;
        else                                                                                   //state transition
          pbus_acc_reg <= pbus_acc_next;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Handle CYC_O output
   assign pbus_cyc_o = pbus_stb_o | pbus_acc_reg;                                              //bus cycle indicator

   //Trigger exception
   assign fc2excpt_buserr_o = pbus_acc_reg &                                                   //ongoing bus access
                              pbus_err_i  &                                                    //bus error
                              ~ir2fc_jump_or_call_i               &                            //no JUMP or CALL
                              ~(ir2fc_bra_i & prs2fc_ps0_false_i) &                            //no BRANCH taken
                              ~ir2fc_eow_i;                                                    //no EOW

   //Finite state machines
   //---------------------



//   //Execution state machine
//   //-----------------------
//   
//   always @*
//     begin
//        //Default outputs	
//        fsm_exec_pc_hold             = 1'b0;                                         //update PC
//        fsm_exec_pbus_hold             = 1'b0;                                         //continous bus requests
//
//	fsm_exec_state_next = STATE_EXEC_OPC;
//	
//	
//
//	case (fsm_exec_state_reg)
//	  //Execute opcode
//	  STATE_EXEC_OPC:
//	    begin
//	       //Wait until 
//	       if (~fsm_pbus_hold &
//		   ~fsm_ir_hold)
//		 begin
//
//		    
//
//		    
//		    if (fsm_exec__hold
//
//
//
//
//
//		    
//		    //Memory I/O		    
//		    if (ir2fc_mem_i)
//		      begin
//			 //Maintain PC
//			 fsm_exec_pc_hold             = 1'b1;                                         //hold PC
//			 fsm_exec_pbus_hold            = prs2fc_hold_i;                               //stacks not ready
//			 
//			 
//
//			 
//	    
//		    //Change of flow 
//		    if (ir2fc_jump_or_call_i               |                                           //JUMP or CALL
//			(ir2fc_bra_i & prs2fc_ps0_false_i) |                                           //BRANCH taken
//			(ir2fc_eow_i & ~ir2fc_mem_i)       |                                           //EOW
//			excpt2fc_irq_i                     |                                           //pending interrupt request
//			excpt2fc_excpt_i)                                                              //pending exception
//		      begin
//			 
//
//
//
//
//	     
//		 end
//
//
//
//	       
//	       if (fsm_pbus_rty_opc)
//		 begin
//		    
//		    
//		    
//
//
//		 end
//
//	       if (fsm_pbus_rty_dat)
//		 begin
//		    
//		    
//		    
//
//
//		 end
//
//	       if (fsm_pbus_rty_err)
//		 begin
//		    
//		    
//		    
//
//
//		 end
//
//	       if (~fsm_pbus_hold &
//		   ~fsm_ir_hold)
//		 begin
//		    
//
//
//
//
//	     
//		 end
//	       
//
//
//
//
   //PBUS state machine
   //------------------
   //The PBUS state machine handles the wishbone protocol ob the PBUS and all 
   //delays that come along with it.

   //PBUS state
   localparam STATE_PBUS_RESET           = 2'b00;                                              //inhibit bus requests
   localparam STATE_PBUS_IDLE            = 2'b01;                                              //bus is idle
   localparam STATE_PBUS_OPCODE          = 2'b10;                                              //ongoing opcode fetch
   localparam STATE_PBUS_DATA            = 2'b11;                                              //ongoing read access
  				         
   //State transitions and outputs       
   always @*			         
     begin			         
        //Default outputs	         
	pbus_cyc_o                       = 1'b1;                                               //bus is busy
        pbus_stb_o                       = 1'b1;                                               //new bus request
	fsm_pbus_capture_opc             = 1'b0;                                               //don't capture opcode
	fsm_pbus_halt                    = 1'b1;                                               //bus not ready
	fsm_pbus_state_next              = fsm_pbus_state_reg;                                 //idle state
				         
	case (state_pbus_reg)	         
	  STATE_PBUS_RESET:	         
	    begin		         
	       pbus_cyc_o                = 1'b0;                                               //bus is idle
               pbus_stb_o                = 1'b0;                                               //no bus request
	       fsm_pbus_state_next       = STATE_PBUS_IDLE;                                    //idle state
	    end // case: STATE_PBUS_RESET
	  			         
	  STATE_PBUS_IDLE:	         
	    begin		         
	       if (~pbus_stall_i)                                                              //bus is not stalled
		 begin		         
		    state_pbus_next      = ir2fc_mem_i ? STATE_PBUS_DATA : STATE_PBUS_OPCODE;  //opcode fetch od data access
		 end		         
	    end // case: STATE_PBUS_IDLE
				         
	  STATE_PBUS_OPCODE:	         
	    begin		         
	       fsm_pbus_capture_opccode  =  pbus_ack_i;                                        //capture opcode when available
	       fsm_pbus_halt             =  pbus_stall_i |                                     //access delay
					    ~(pbus_ack_i | pbus_err_i | pbus_rty_i);           //    
	       fsm_pbus_error            =  pbus_err_i;                                        //access error
	       fsm_pbus_refetch_opcode   =  pbus_rty_i;                                        //retry request
	       pbus_stb_o                = ~(pbus_err_i | pbus_rty_i);                         //block bus request for one cycle
	    end // case: STATE_PBUS_OPCODE
	  	  
	  STATE_PBUS_DATA:	         
	    begin		         
	       fsm_pbus_halt             =  pbus_stall_i |                                     //access delay
					    ~(pbus_ack_i | pbus_err_i | pbus_rty_i);           //    
	       fsm_pbus_error            =  pbus_err_i;                                        //access error
	       fsm_pbus_refetch_data     =  pbus_rty_i;                                        //retry request
	       pbus_stb_o                = ~(pbus_err_i | pbus_rty_i);                         //block bus request for one cycle
	    end // case: STATE_PBUS_DATA	  
	endcase // case (state_pbus_reg)
     end // always @ *

   //IR state machine
   //----------------
   //The IR state machine monitors and controls the instruction register.
   
   //IR state
   localparam STATE_IR_NOT_STASHED = 1'b0;                                                     //no stashed opcode
   localparam STATE_IR_STASHED     = 1'b1;                                                     //stashed opcode
		   
   //State transitions and outputs
   always @*
     begin
        //Default outputs
	fc2ir_capture_o = 1'b0;                                                                //don't capture current IR
	fc2ir_stash_o   = 1'b0;                                                                //don't capture stashed IR
	fc2ir_expend_o  = 1'b0;                                                                //don't expend stashed IR
	fsm_ir_state_next = fsm_ir_state_reg;                                                  //stay in current state
	
	case (fsm_ir_state_reg)
	  STATE_IR_NOT_STASHED:
	    begin
	       if (fsm_pbus_capture_opcode)
		 begin
		    if (fsm_exec_ir_hold |                                                     //multy cycle instruction
			fsm_pbus_hold)                                                         //bus stalled
		      begin
			 fc2ir_stash_o = 1'b1;                                                 //capture stashed IR
			 fsm_ir_state_next = STATE_IR_STASHED;                                 //stash opcode
		      end
		    else
		      begin
			 fc2ir_capture_o = 1'b1;                                               //capture current IR
		      end
		 end // if (fsm_pbus_capture_opcode)
	    end // case: STATE_IR_NOT_STASHED
	  
	  STATE_IR_STASHED:
	    begin
	       if (~fsm_exec_ir_hold)                                                          //IR may be updated
		 begin
		    fc2ir_expend_o = 1'b1;                                                     //stashed IR -> current IR
		    fsm_ir_state_next = STATE_IR_NOT_STASHED;                                  //discard stashed opcode
		 end // if (~fsm_exec_ir_hold)	       
	    end // case: STATE_IR_STASHE
	  
	endcase // case (fsm_ir_state_reg)
     end // always @ *
   
   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                                       //asynchronous reset
          fsm_ir_state_reg <= STATE_IR_NOT_STASHED;
        else if (sync_rst_i)                                                                   //synchronous reset
          fsm_ir_state_reg <= STATE_IR_NOT_STASHED;
        else                                                                                   //state transition
          fsm_ir_state_reg <= fsm_ir_state_next;
     end // always @ (posedge async_rst_i or posedge clk_i)
















   

  

   localparam STATE_RESET       = 3'b000;                                                      //reset state -> delay first bus access
   localparam STATE_EXEC        = 3'b001;                                                      //execute single cycle instruction (next upcode on read data bus)
   localparam STATE_EXEC_STASH  = 3'b010;                                                      //execute single cycle instruction (next opcode stached)
   localparam STATE_EXEC_READ   = 3'b011;                                                      //second cycle of the reaad instruction
   localparam STATE_EXEC_IRQ    = 3'b100;                                                      //Capture ISR and prepare CALL
   localparam STATE_EXEC_EXCPT  = 3'b111;                                                      //Capture ISR and prepare CALL

   always @*
     begin
        //Default outputs
        pbus_stb_o              = 1'b1;                                                        //access request
        irq_ack_o               = 1'b0;                                                        //interrupt acknowledge
        fc2dsp_pc_hold_o        = 1'b0;                                                        //update PC
        fc2dsp_radr_inc_o       = 1'b1;                                                        //increment relative address
        fc2ir_capture_o         = 1'b0;                                                        //capture current IR
        fc2ir_stash_o           = 1'b0;                                                        //capture stashed IR
        fc2ir_expend_o          = 1'b0;                                                        //stashed IR -> current IR
        fc2ir_force_eow_o       = 1'b0;                                                        //load EOW bit
        fc2ir_force_0call_o     = 1'b0;                                                        //load 0 CALL instruction
        fc2ir_force_call_o      = 1'b0;                                                        //load CALL instruction
        fc2ir_force_drop_o      = 1'b0;                                                        //load DROP instruction
        fc2ir_force_nop_o       = 1'b0;                                                        //load NOP instruction
        fc2prs_hold_o           = 1'b0;                                                        //hold any state tran
        fc2prs_dat2ps0_o        = 1'b0;                                                        //capture read data
        fc2prs_tc2ps0_o         = 1'b0;                                                        //capture throw code
        fc2prs_isr2ps0_o        = 1'b0;                                                        //capture ISR
        fc2excpt_excpt_clr_o    = 1'b0;                                                        //disable exceptions
        fc2excpt_irq_dis_o      = 1'b0;                                                        //disable interrupts
        state_next              = state_reg;                                                   //remain in current state

//      //Keep PBUS idle during reset
//      if (~|{state_reg ^ STATE_RESET})
//          begin
//             state_next       = STATE_EXEC;                                                    //fetch opcode
//             pbus_stb_o       = 1'b0;                                                          //delay next access
//             fc2dsp_pc_hold_o = 1'b1;                                                          //don't update PC
//             fc2prs_hold_o    = 1'b1;                                                          //don't update stacks
//          end
//      else
//        //Wait for bus response (stay in sync with memory)
//        if (pbus_acc_reg &                                                                     //ongoing bus access
//            ~pbus_ack_i  &                                                                     //no bus acknowledge
//            ~pbus_err_i  &                                                                     //no error indicator
//            ~pbus_rty_i)                                                                       //no retry request
//          begin
//             //state_next     = state_reg;                                                     //remain in current state
//             pbus_stb_o       = 1'b0;                                                          //delay next access
//             fc2dsp_pc_hold_o = 1'b1;                                                          //don't update PC
//             fc2prs_hold_o    = 1'b1;                                                          //don't update stacks
//          end
//      else
//      //Handle first execution cycle
//      if ((~|{state_reg ^ STATE_EXEC}) |
//          (~|{state_reg ^ STATE_EXEC_RTY}))
//        begin
//           //Common logic
//           fc2dsp_radr_inc_o                 = ~|{state_reg ^ STATE_EXEC};                   //increment relative address
//
//           //Memory I/O
//           if (ir2fc_mem_i)
//             begin
//                //Maintain PC
//                fc2dsp_pc_hold_o             = 1'b1;                                         //update PC
//
//                //Incoming opcode
//                if (pbus_acc_reg &                                                           //ongoing bus access
//                    pbus_ack_i)                                                              //bus acknowledge
//                  begin
//                     fc2ir_stash_o           = 1'b1;                                         //stash opcode
//                  end
//
//                //Delays
//                  if ((prs2fc_hold_i) |                                                        //stacks not ready
//                    (pbus_stall_i))                                                          //PBUS is busy
//                  begin
//                     pbus_stb_o              = pbus_stall_i;                                 //access request
//                     fc2prs_hold_o           = pbus_stall_i;                                 //don't update stacks
//                     //Retry request
//                     if (pbus_acc_reg &                                                      //ongoing bus access
//                         pbus_rty_i)                                                         //retry request
//                       begin
//                          state_next = STATE_EXEC_RTY;                                       //remember retry request
//                       end
//                  end
//                //No delay
//                else
//                  begin
//
//
//
//                  end
//             end
//
//           //Change of flow
//           if (ir2fc_jump_or_call_i               |                                           //JUMP or CALL
//                 (ir2fc_bra_i & prs2fc_ps0_false_i) |                                           //BRANCH taken
//                 (ir2fc_eow_i & ~ir2fc_mem_i)       |                                           //EOW
//               excpt2fc_irq_i                     |                                           //pending interrupt request
//               excpt2fc_excpt_i)                                                              //pending exception
//             begin
//
//
//
//             end
//
//           //Single cycle
//           if ((ir2fc_scyc_i                        |                                         //single cycle instruction
//                 (ir2fc_bra_i & ~prs2fc_ps0_false_i)) &                                         //BRANCH not taken
//               (~ir2fc_eow_i                        |                                         //not end of word (EOW bit cleared)
//                ir2fc_eow_postpone_i))                                                        //EOW conflict detected
//             begin
//
//
//
//
//
//             end
//
//
//                //Delay bus request
//                if (prs2fc_hold_i |                                                          //stacks are busy
//                    (pbus_acc_reg &                                                          //ongoing bus access
//                     pbus_rty_i))                                                            //retry request
//                  begin
//                     pbus_stb_o              = 1'b0;                                         //no access request
//                  end
//
//                //Freeze PC
//                if (prs2fc_hold_i |                                                          //stacks are busy
//                    pbus_stall_i  |                                                          //PBUS is busy
//                    (pbus_acc_reg &                                                          //ongoing bus access
//                     pbus_rty_i))                                                            //retry request
//                  begin
//                     fc2dsp_pc_hold_o        = 1'b1;                                         //keep PC
//                  end
//
//                //Capture opcode
//                if (~prs2fc_hold_i                                                           //stacks are busy
//                    ~pbus_stall_i  |                                                          //PBUS is busy
//                    (pbus_acc_reg &                                                          //ongoing bus access
//                     pbus_rty_i))                                                            //retry request
//
//
//
//
//
//
//        fc2ir_capture_o         = 1'b0;                                                        //capture current IR
//        fc2ir_stash_o           = 1'b0;                                                        //capture stashed IR
//        fc2ir_expend_o          = 1'b0;                                                        //stashed IR -> current IR
//        fc2ir_force_eow_o       = 1'b0;                                                        //load EOW bit
//        fc2ir_force_0call_o     = 1'b0;                                                        //load 0 CALL instruction
//        fc2ir_force_call_o      = 1'b0;                                                        //load CALL instruction
//        fc2ir_force_drop_o      = 1'b0;                                                        //load DROP instruction
//        fc2ir_force_nop_o       = 1'b0;                                                        //load NOP instruction
//        fc2prs_hold_o           = 1'b0;                                                        //hold any state tran
//        fc2prs_dat2ps0_o        = 1'b0;                                                        //capture read data
//        fc2prs_tc2ps0_o         = 1'b0;                                                        //capture throw code
//        fc2prs_isr2ps0_o        = 1'b0;                                                        //capture ISR
//        fc2excpt_excpt_clr_o    = 1'b0;                                                        //disable exceptions
//        fc2excpt_irq_dis_o      = 1'b0;                                                        //disable interrupts
//        state_next              = state_reg;                                                   //remain in current state
//
//
//
//
//
//
//
//
//
//                //Single cycle execution
//                if (pbus_acc_reg   &                                                         //ongoing bus access
//                    pbus_ack_i     &                                                         //bus acknowledge
//                    ~prs2fc_hold_i &                                                         //stacks are ready
//                    ~pbus_stall_i  &                                                         //PBUS is idle
//                    ~ir2fc_mem_i)                                                            //no memory I/O
//                  begin
//                     fc2ir_capture_o  = 1'b1;                                                //capture opcode
//                  end
//
//                //Incoming opcode, bus stalled, no mem I/O
//                if (pbus_acc_reg &                                                           //ongoing bus access
//                    pbus_ack_i   &                                                           //bus acknowledge
//                    pbus_stall_i &                                                           //PBUS is busy
//                  ~ir2fc_mem_i)                                                              //no mem I/O
//                  begin
//                     fc2ir_stash_o    = 1'b1;                                                //stash opcode
//                     fc2dsp_pc_hold_o = 1'b1;                                                //don't update PC
//                     fc2prs_hold_o    = 1'b1;                                                //don't update stacks
//                  end
//
//                //Incoming opcode, stacks busy, no mem I/O
//                if (pbus_acc_reg  &                                                          //ongoing bus access
//                    pbus_ack_i    &                                                          //bus acknowledge
//                    prs2fc_hold_i &                                                          //stacks are busy
//                  ~ir2fc_mem_i)                                                              //no mem I/O
//                  begin
//                     pbus_stb_o       = 1'b0;                                                //delay access request
//                     fc2ir_stash_o    = 1'b1;                                                //stash opcode
//                     fc2dsp_pc_hold_o = 1'b1;                                                //don't update PC
//                     fc2prs_hold_o    = 1'b1;                                                //don't update stacks
//                  end
//
//
//
//
//                //Retry request, bus stalled, no mem I/O
//                if (pbus_acc_reg &                                                           //ongoing bus access
//                    pbus_ack_i   &                                                           //bus acknowledge
//                    pbus_stall_i &                                                           //PBUS is busy
//                  ~ir2fc_mem_i)                                                              //no mem I/O
//                  begin
//                     fc2ir_stash_o    = 1'b1;                                                //stash opcode
//                     fc2dsp_pc_hold_o = 1'b1;                                                //don't update PC
//                     fc2prs_hold_o    = 1'b1;                                                //don't update stacks
//                  end
//
//                //Retry request, stacks busy, no mem I/O
//                if (pbus_acc_reg  &                                                          //ongoing bus access
//                    pbus_ack_i    &                                                          //bus acknowledge
//                    prs2fc_hold_i &                                                          //stacks are busy
//                  ~ir2fc_mem_i)                                                              //no mem I/O
//                  begin
//                     pbus_stb_o       = 1'b0;                                                //delay access request
//                     fc2ir_stash_o    = 1'b1;                                                //stash opcode
//                     fc2dsp_pc_hold_o = 1'b1;                                                //don't update PC
//                     fc2prs_hold_o    = 1'b1;                                                //don't update stacks
//                  end
//
//
//
//
//
//                //Handle incoming opcodes
//                if (pbus_acc_reg &                                                           //ongoing bus access
//                    pbus_ack_i)                                                              //bus acknowledge
//                  begin
//                     if (prs2fc_hold_i |                                                     //stacks are busy
//                         pbus_stall_i)                                                       //PBUS is busy
//                       begin
//                          pbus_stb_o       = pbus_stall_i;                                   //delay access request
//                          fc2ir_stash_o    = 1'b1;                                           //stash opcode
//                          fc2dsp_pc_hold_o = 1'b1;                                           //don't update PC
//                          fc2prs_hold_o    = 1'b1;                                           //don't update stacks
//                       end
//                     else                                                                    //ready to execute instruction cycle
//                       begin
//                          fc2ir_capture_o  = ~ir2fc_mem_i;                                   //capture opcide
//                       end
//                  end
//
//                //Handle retry requests
//                if ((pbus_acc_reg &                                                           //ongoing bus access
//                     pbus_ack_i)  |                                                           //retry request
//                    (~|{state_reg ^ STATE_EXEC_RTY}))
//                  begin
//                     fc2dsp_radr_inc_o     = 1'b0;                                            //PC is address output
//                  end
//
//                //Memory I/O
//                  if (ir2fc_mem_i)
//                  begin
//                     if (pbus_acc_reg &                                                           //ongoing bus access
//                         pbus_ack_i)                                                              //bus acknowledge
//                       begin
//                             fc2ir_stash_o      = 1'b1;
//
//
//
//
//
//
//          //Handle RTY_I
//          if (pbus_acc_reg                        &                                          //ongoing bus access
//              pbus_rty_i                          &                                          //retry request
//                ~ir2fc_jump_or_call_i               &                                          //no JUMP or CALL
//                ~(ir2fc_bra_i & prs2fc_ps0_false_i) &                                          //no BRANCH taken
//                ~ir2fc_eow_i;                                                                  //no EOW
//            begin
//              fc2dsp_pc_hold_o  = 1'b0;                                                      //maintain PC
//              fc2dsp_radr_inc_o = 1'b1;                                                      //relative address
//
//
//
//
//
//
//
//
//
//
//
//
//        end
//      else
//      //Handle second execution cycle if fetch instruction
//      if (~|{state_reg ^ STATE_READ})
//        begin
//
//
//
//
//
//        end
//      else
//      //Execute ISR
//      if (~|{state_reg ^ STATE_IRQ})
//        begin
//
//
//
//
//
//        end
//      else
//      //Handle exception
//      if (~|{state_reg ^ STATE_EXCPT})
//        begin
//
//
//
//
//
//        end
//     end // always @ *
//
//
//
//
//
//
//        begin
//           //Capture read data
//             if (~|{state_reg[1:0] ^ STATE_EXEC_READ[1:0]})                                    //STATE_EXEC_READ
//
//
//
//               begin
//                  fc2prs_dat2ps0_o   = 1'b1;                                                   //read data -> PS0
//                  state_next         = STATE_EXEC_STASH;                                       //capture read data only once
//               end
//             //Wait for stacks
//             if (prs2fc_hold_i)                                                                //stacks are busy
//               begin
//                  if (~|{state_reg[1:0] ^ STATE_EXEC[1:0]})                                    //STATE_EXEC
//                    begin
//                       fc2ir_stash_o = 1'b1;                                                   //stash next instruction
//                       state_next    = STATE_EXEC_STASH;                                       //track stashed opcode
//                    end
//                  pbus_stb_o       = 1'b0;                                                     //idle pbus
//                  fc2dsp_pc_hold_o = 1'b1;                                                     //don't update PC
//                  fc2prs_hold_o    = 1'b1;                                                     //don't update stacks
//               end // if (prs2fc_hold_i)
//
//
//
//
//
//
//
//
//
//
//             //Initiate next bus access
//             else
//               begin
//                  //Wait while Pbus is stalled
//                  if (pbus_stall_i)
//                    begin
//                       if (~|{state_reg[1:0] ^ STATE_EXEC[1:0]})                               //STATE_EXEC
//                         begin
//                            fc2ir_stash_o = 1'b1;                                              //stash next instruction
//                            state_next    = STATE_EXEC_STASH;                                  //track stashed opcode
//                         end
//                       fc2dsp_pc_hold_o   = 1'b1;                                              //don't update PC
//                       fc2prs_hold_o      = 1'b1;                                              //don't update stacks
//                    end
//                  //Execute
//                  else
//                    begin
//                       //Multi-cycle instruction
//                       if (ir2fc_jump_or_call_i               |                                //call or jump
//                           (ir2fc_bra_i & prs2fc_ps0_false_i) |                                //BRANCH taken
//                           ir2fc_eow_i                        |                                //EOW
//                           ir2fc_mem_i)                                                        //memory I/O
//                         begin
//
//                            //Memory I/O
//                            if (ir2fc_mem_i)
//                              begin
//                                 if (~|{state_reg[1:0] ^ STATE_EXEC[1:0]})                     //STATE_EXEC
//                                   begin
//                                      fc2ir_stash_o      = 1'b1;                               //stash next instruction
//                                   end
//                                 fc2dsp_pc_hold_o        = 1'b1;                               //don't update PC
//                                 fc2ir_force_eow_o       = ir2fc_eow_i;                        //postpone EOW
//                                 //Fetch
//                                 if (ir2fc_mem_rd_i)
//                                   begin
//                                      fc2ir_force_nop_o  = 1'b1;                               //overwrite PS0
//                                      state_next         = STATE_EXEC_READ;                    //fetch read data
//                                   end
//                                 //Store
//                                 else
//                                   begin
//                                      fc2ir_force_drop_o =  ir2fc_madr_sel_i;                  //indirect addressing
//                                      fc2ir_force_nop_o  = ~ir2fc_madr_sel_i;                  //direct addressing
//                                      state_next         = STATE_EXEC_STASH;                   //track stashed opcode
//                                   end // else: !if(ir2fc_mem_rd_i)
//                              end
//
//                            //Change of flow
//                            else if (ir2fc_jump_or_call_i                   |                  //call or jump
//                                     (ir2fc_bra_i & prs2fc_ps0_false_i)     |                  //BRANCH taken
//                                     (ir2fc_eow_i & ~ir2fc_eow_postpone_i))                    //EOW (not postponed)
//                              begin
//                                 fc2ir_force_nop_o       = 1'b1;                               //direct addressing
//                                 state_next              = STATE_EXEC;                         //execute NOP
//                              end
//
//                            //Postponed EOW
//                              else
//                                begin
//                                   fc2ir_force_eow_o       = 1'b1;                             //force EOW bit
//                                   fc2ir_force_nop_o       = 1'b1;                             //force NOP instruction
//                                   state_next              = STATE_EXEC;                       //execute EOW
//                                end
//
//                         end // if (ir2fc_jump_or_call_i              |...
//
//                       //Single-cycle instruction
//                       else
//                         begin
//
//                            //Prepare exception handler
//                            if (~|{state_reg ^ STATE_EXEC_EXCPT})                              //STATE_EXEC_EXCPT
//                              begin
//                                 fc2dsp_pc_hold_o        = 1'b1;                               //don't update PC
//                                 fc2prs_tc2ps0_o         = 1'b1;                               //capture throw code
//                                 fc2ir_force_0call_o     = 1'b1;                               //force CALL instruction
//                                 fc2excpt_excpt_clr_o    = 1'b1;                               //disable interrupts
//                                 state_next              = STATE_EXEC;                         //execute CALL
//                              end
//
//                            //Prepare ISR
//                            else if (~|{state_reg ^ STATE_EXEC_IRQ})                           //STATE_EXEC_IRQ
//                              begin
//                                 //IRQ still pending
//                                 if (excpt2fc_irq_i)                                           //pending interrupt request
//                                   begin
//                                      fc2dsp_pc_hold_o   = 1'b1;                               //don't update PC
//                                      fc2prs_isr2ps0_o   = 1'b1;                               //capture ISR address
//                                      fc2ir_force_call_o = 1'b1;                               //force CALL instruction
//                                      fc2excpt_irq_dis_o = 1'b1;                               //disable interrupts
//                                      state_next         = STATE_EXEC;                         //execute CALL
//                                   end
//                                 //IRQ retracted
//                                 else
//                                   begin
//                                      fc2ir_capture_o    = 1'b1;                               //capture IR
//                                      state_next         = STATE_EXEC;                         //execute CALL
//                                   end // else: !if(excpt2fc_irq_i)
//                              end // if (~|{state_reg ^ STATE_EXEC_IRQ})
//
//                            //Exception
//                            else if (excpt2fc_excpt_i)                                         //pending exception
//                              begin
//                                 fc2dsp_pc_hold_o        = 1'b1;                               //don't update PC
//                                 fc2ir_force_nop_o       = 1'b1;                               //force jump to addess zero
//                                 state_next              = STATE_EXEC_EXCPT;                   //execute jump
//                              end
//
//                            //Interrupt request
//                            else if (excpt2fc_irq_i)                                           //pending interrupt request
//                              begin
//                                 fc2dsp_pc_hold_o        = 1'b1;                               //don't update PC
//                                 fc2ir_force_nop_o       = 1'b1;                               //capture ISR
//                                 state_next              = STATE_EXEC_IRQ;                     //capture ISR
//                              end
//
//                            //Continue program flow
//                            else
//                              begin
//                                 fc2ir_expend_o          = ~|{state_reg ^ STATE_EXEC_STASH} |  //use stashed upcode next
//                                                           ~|{state_reg ^ STATE_EXEC_READ};    //
//                                 fc2ir_capture_o         = ~|{state_reg ^ STATE_EXEC};         //capture opcode
//                                 state_next              = STATE_EXEC;                         //execute next opcode
//                              end // else: !if(excpt2fc_irq_i)
//
//                         end // else: !if(ir2fc_jump_or_call_i              |...
//                    end // else: !if(pbus_stall_i)
//               end // else: !if(prs2fc_hold_i)
//          end // else: !if(pbus_acc_reg &...
//
//
//
//
//
//
//        //Wait for bus response (stay in sync with memory)
//        if (pbus_acc_reg &                                                                     //ongoung bus access
//            ~pbus_ack_i  &                                                                     //no bus acknowledge
//            ~pbus_err_i)                                                                       //no error indicator
//          begin
//             state_next       = state_reg;                                                     //remain in current state
//             pbus_stb_o       = 1'b0;                                                          //delay next access
//             fc2dsp_pc_hold_o = 1'b1;                                                          //don't update PC
//             fc2prs_hold_o    = 1'b1;                                                          //don't update stacks
//          end
//
//      //Keep bus idle in STATE_RESET
//      if (~|state_reg ^ STATE_RESET)
//        begin
//             state_next       = STATE_EXEC;                                                    //fetch first opcode
//             pbus_stb_o       = 1'b0;                                                          //delay next access
//             fc2dsp_pc_hold_o = 1'b1;                                                          //don't update PC
//             fc2prs_hold_o    = 1'b1;                                                          //don't update stacks
//        end
//
     end // always @ *

   //Flip flops
   //----------
   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                                       //asynchronous reset
          state_reg <= STATE_RESET;
        else if (sync_rst_i)                                                                   //synchronous reset
          state_reg <= STATE_RESET;
        else                                                                                   //state transition
          state_reg <= state_next;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Probe signals
   //-------------
   assign  prb_fc_state_o    = state_reg;                                                     //state variable
   assign  prb_fc_pbus_acc_o = pbus_acc_reg;                                                  //ongoing bus access

endmodule // N1_fc
