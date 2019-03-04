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
//#    Program Counter  |PC0 |PC1 |PC2 |PC3 |PC4 |PC5 |                         #
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
    input  wire                      pbus_err_i,                                               //error indicator           | target to initiator
    input  wire                      pbus_stall_i,                                             //access delay              +-

    //Interrupt interface
    output reg                       irq_ack_o,                                                //interrupt acknowledge

    //Internal interfaces
    //-------------------
    //DSP interface
    output reg                       fc2dsp_pc_hold_o,                                         //maintain PC

    //IR interface
    output reg                       fc2ir_capture_o,                                          //capture current IR
    output reg                       fc2ir_stash_o,                                            //capture stashed IR
    output reg                       fc2ir_expend_o,                                           //stashed IR -> current IR
    output reg                       fc2ir_force_eow_o,                                        //load EOW bit
    output reg                       fc2ir_force_0call_o,                                      //load 0 CALL instruction
    output reg                       fc2ir_force_call_o,                                       //load CALL instruction
    output reg                       fc2ir_force_drop_o,                                       //load DROP instruction
    output reg                       fc2ir_force_nop_o,                                        //load NOP instruction
    output reg                       fc2ir_force_isr_o,                                        //load ISR instruction
    input  wire                      ir2fc_eow_i,                                              //end of word (EOW bit set)
    input  wire                      ir2fc_eow_postpone_i,                                     //EOW conflict detected
    input  wire                      ir2fc_jump_or_call_i,                                     //either JUMP or CALL
    input  wire                      ir2fc_bra_i,                                              //conditonal BRANCG instruction
    input  wire                      ir2fc_isr_i,                                              //ISR launcher
    input  wire                      ir2fc_scyc_i,                                             //linear flow
    input  wire                      ir2fc_mem_i,                                              //memory I/O
    input  wire                      ir2fc_mem_rd_i,                                           //memory read
    input  wire                      ir2fc_madr_sel_i,                                         //direct memory address

    //PRS interface
    output reg                       fc2prs_hold_o,                                            //hold any state tran
    output reg                       fc2prs_dat2ps0_o,                                         //capture read data
    input  wire                      prs2fc_hold_i,                                            //stacks not ready
    input  wire                      prs2fc_ps0_true_i,                                        //PS0 in non-zero

    //EXCPT interface
    output wire                      fc2excpt_excpt_dis_o,                                     //disable exceptions
    output wire                      fc2excpt_irq_dis_o,                                       //disable interrupts
    output wire                      fc2excpt_buserr_o,                                        //invalid pbus access
    input  wire                      excpt2fc_excpt_i,                                         //exception to be handled
    input  wire                      excpt2fc_irq_i,                                           //exception to be handled

    //Probe signals
    output wire [1:0]                prb_fc_state_o,                                           //state variable
    output wire                      prb_fc_pbus_acc_o);                                       //ongoing bus access

   //Internal signals
   //----------------
   //PBUS monitor
   reg                               pbus_acc_reg;                                             //ongoing bus access
   wire                              pbus_acc_next;                                            //next state of the PBUS monitor
   //State variable
   reg  [1:0]                        state_reg;                                                //state variable
   reg  [1:0]                        state_next;                                               //next state
   
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

   assign pbus_cyc_o = pbus_stb_o | pbus_acc_reg;                                              //bus cycle indicator

   //Finite state machine
   //--------------------
   localparam STATE_EXEC           = 2'00;
   localparam STATE_EXEC_STASH     = 2'01;
   localparam STATE_UNREACH        = 2'10;
   localparam STATE_EXEC_READ      = 2'11;

   always @*
     begin
        //Default outputs
        pbus_stb_o              = 1'b0;                                                        //access request

        irq_ack_o               = 1'b0;                                                        //interrupt acknowledge

        fc2dsp_pc_hold_o        = 1'b0;                                                        //maintain PC

        fc2ir_capture_o         = 1'b0;                                                        //capture current IR
        fc2ir_stash_o           = 1'b0;                                                        //capture stashed IR
        fc2ir_expend_o          = 1'b0;                                                        //stashed IR -> current IR
        fc2ir_force_eow_o       = 1'b0;                                                        //load EOW bit
        fc2ir_force_0call_o     = 1'b0;                                                        //load 0 CALL instruction
        fc2ir_force_call_o      = 1'b0;                                                        //load CALL instruction
        fc2ir_force_fetch_o     = 1'b0;                                                        //load FETCH instruction
        fc2ir_force_drop_o      = 1'b0;                                                        //load DROP instruction
        fc2ir_force_nop_o       = 1'b0;                                                        //load NOP instruction
        fc2ir_force_rdpsh_o     = 1'b0;                                                        //load FETCH instruction (push to TOS)
        fc2ir_force_rdrpl_o     = 1'b0;                                                        //load FETCH instruction (replace TOS)
        fc2ir_force_isr_o       = 1'b0;                                                         //load ISR instruction

        fc2prs_dat2ps0_o        = 1'b0;                                                        //capture read data
        fc2prs_hold_o           = 1'b0;                                                        //hold any state tran

        fc2excpt_excpt_dis_o    = 1'b0;                                                        //disable exceptions
        fc2excpt_irq_dis_o      = 1'b0;                                                        //disable interrupts
        fc2excpt_buserr_o       = 1'b0;                                                        //invalid pbus access

        state_next              = 0;                                                           //remain in current state

        //Wait for bus response (stay in sync with memory)
        if (pbus_acc_reg &                                                                     //ongoung bus access
            ~pbus_ack_i  &                                                                     //no bus acknowledge
            ~pbus_err_i)                                                                       //no error indicator
          begin
             pbus_stb_o       = 1'b0;                                                          //delay next access
             fc2dsp_pc_hold_o = 1'b1;                                                          //don't update PC
             fc2prs_hold_o    = 1'b1;                                                          //don't update stacks
             state_next       = state_reg;                                                     //remain in current state
          end
        //Bus response received
        else
          begin
             //Trigger exception
             fc2excpt_buserr_o = pbus_err_i & ~ir2fc_cof_i;                                    //bus error and no COF
             //Capture read data
             fc2prs_dat2ps0_o  = ~|{state_reg ^ STATE_EXEC_READ} |                             //memory read
                                 ~|{state_reg ^ STATE_UNREACH};                                //unreachable
             //Wait for stacks
             if ((~|{state_reg ^ STATE_EXEC} |                                                 //EXEC without stashed instruction
                  ~|{state_reg ^ STATE_EXEC_STASH}) &                                          //EXEC with stashed instruction
                 prs2fc_hold_i)                                                                //stacks are busy
               begin
                  fc2ir_stash_o    = ~|{state_reg ^ STATE_EXEC};                               //stash next instruction
                  pbus_cyc_o       = ~|{state_reg ^ STATE_EXEC};                               //delay next access
                  pbus_stb_o       = 1'b0;                                                     //
                  fc2dsp_pc_hold_o = 1'b1;                                                     //don't update PC
                  fc2prs_hold_o    = 1'b1;                                                     //don't update stacks
                  state_next       = STATE_EXEC_STASH;                                         //track stashed opcode
               end
             //Initiate next bus access
             else
               begin
                  pbus_stb_o    = 1'b1;                                                        //bus access
                  //Wait while Pbus is stalled
                  if (pbus_stall_i)
                    begin
                       fc2ir_stash_o    = ~|{state_reg ^ STATE_EXEC};                          //stash next instruction
                       fc2dsp_pc_hold_o = 1'b1;                                                //don't update PC
                       fc2prs_hold_o    = 1'b1;                                                //don't update stacks
                       state_next       = STATE_EXEC_STASH;                                    //track stashed opcode
                    end
                  //Execute
                  else
                    begin
                       //Memory I/O
                       if (ir2fc_mem_i)
                         begin
                            fc2dsp_pc_hold_o        = 1'b1;                                    //don't update PC
                            fc2ir_stash_o           = ~|{state_reg ^ STATE_EXEC);              //stash next instruction
                            fc2ir_force_eow_o       = ir2fc_eow_i;                             //postpone EOW
                            //Fetch
                            if (ir2fc_mem_rd_i)
                              begin
                                 fc2ir_force_nop_o  = 1'b1;                                    //
                                 state_next         = STATE_EXEC_READ;                         //fetch read data
                              end
                            //Store
                            else
                              begin
                                 fc2ir_force_drop_o =  ir2fc_sel_madr_i;                       //indirect addressing
                                 fc2ir_force_nop_o  = ~ir2fc_sel_madr_i;                       //direct addressing
                                 state_next         = STATE_EXEC_STASH;                        //track stashed opcode
                              end // else: !if(ir2fc_mem_rd_i)
                         end
                       //Change of flow
                       if ( ir2fc_jump_or_call_i |                                             //call or jump
			   (ir2fc_bra_i & prs2fc_ps0_true_i) |                                 //taken branch
			   (ir2fc_scyc & ir2fc_eow_o & ~ir2fc_eow_postpone_o))                 //EOW
                         begin
                            //Exception
                            if (excpt2fc_excpt_i)                                              //pending exception
                              begin
                                 fc2ir_force_0call_o  = 1'b1;                                  //force jump to addess zero
                                 fc2ir_force_eow_o    = 1'b1;                                  //(call + EOW)
                                 fc2excpt_excpt_dis_i = 1'b1;                                  //inhibit further exceptions
                              end
                            //Interrupt
                            else if (excpt2fc_irq_i)                                           //pending interrupt
                              begin
                                 fc2ir_force_isr_o   = 1'b1;                                   //force ISR instruction
                              end
                            //Resume program flow
                            else
                              begin
                                 fc2ir_force_nop_o   = 1'b1;                                   //force NOP opcode
                              end
                            state_next               = state_next |                            //make use of onehot encoding
                                                       STATE_EXEC;                             //execute NOP
                         end // if (ir2fc_cof_i)
                       //ISR launcher
                       if (ir2fc_isr_i)                                                        //ISR launcher
                         begin
                            //Exception
                            if (excpt2fc_excpt_i)                                              //pending exception
                              begin
                                 fc2ir_force_0call_o  = 1'b1;                                  //force jump to addess zero
                                 fc2ir_force_eow_o    = 1'b1;                                  //(call + EOW)
                                 fc2excpt_excpt_dis_i = 1'b1;                                  //inhibit further exceptions
                              end
                            //Launch ISR
                            else
                              begin
                                 fc2dsp_pc_hold_o     = 1'b1;                                  //don't update PC
                                 fc2excpt_irq_dis_o   =  excpt2fc_irq_i;                       //disable interrupts
                                 fc2ir_force_call_o   =  excpt2fc_irq_i;                       //execute CALL if interrupts are pending
                                 fc2ir_force_drop_o   = ~excpt2fc_irq_i;                       //execute DROP if no interrupts are pendingt
                                 fc2ir_force_eow_o    = fc2ir_force_eow_o |                    //make use of onehot encoding
                                                        ir2fc_eow_i;                           //postpone EOW
                              end // else: !if(excpt2fc_excpt_i)
                            state_next                = state_next |                           //make use of onehot encoding
                                                        STATE_EXEC;                            //execute NOP
                         end // if (ir2fc_isr_i)
                       //Linear execution
                       if ((~ir2fc_eow_o | ir2fc_eow_postpone_o) &                             //no EOW
			   ((ir2fc_bra_i & ~prs2fc_ps0_true_i) |                               //branch not taken
			    ir2fc_scyc))                                                       //single cycle instruction
                         begin
                            //Exception
                            if (excpt2fc_excpt_i) //pending exception
                              begin
                                 fc2ir_force_0call_o  = 1'b1;                                  //force jump to addess zero
                                 fc2ir_force_eow_o    = 1'b1;                                  //(call + EOW)
                                 fc2excpt_excpt_dis_i = 1'b1;                                  //inhibit further exceptions
                              end
                            //Interrupt
                            else if (excpt2fc_irq_i)                                           //pending interrupt
                              begin
                                 fc2dsp_pc_hold_o     = 1'b1;                                  //don't update PC
                                 fc2ir_force_isr_o    = 1'b1;                                  //force ISR instruction
                              end
                            //Postpone EOW
                            else if (ir2fc_eow_postpone_i)                                     //postpone EOW
                              begin
                                 fc2dsp_pc_hold_o     = 1'b1;                                  //don't update PC
                                 fc2ir_force_nop_o    = 1'b1;                                  //force NOP execution
                                 fc2ir_force_eow_o    = 1'b1;                                  //force EOW bit
                              end
                            //Continue program flow
                            else
                              begin
                                 fc2ir_expend_o       = ~|{state_reg ^ STATE_EXEC_STASH) |     //use stashed upcode next
                                                        ~|{state_reg ^ STATE_EXEC_READ);       //
                                 fc2ir_capture_o      = ~|{state_reg ^ STATE_EXEC);            //capture opcode
                              end // else: !if(ir2fc_eow_postpone_i)
                            state_next                = state_next |                           //make use of onehot encoding
                                                        STATE_EXEC;                            //execute next opcode
                         end // if (ir2fc_lin_i)
                    end // else: !if(pbus_stall_i)
               end // else: !if((~|{state_reg ^ STATE_EXEC} |...
          end // else: !if(pbus_acc_reg &...
     end // always @ *

   //Flip flops
   //----------
   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                                       //asynchronous reset
          state_reg <= STATE_EXEC;
        else if (sync_rst_i)                                                                   //synchronous reset
          state_reg <= STATE_EXEC;
        else                                                                                   //state transition
          state_reg <= state_next;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Probe signals
   //-------------
   assign  prb_fc_state_o    = state_reg;                                                     //state variable
   assign  prb_fc_pbus_acc_o = pbus_acc_reg;                                                  //ongoing bus access

endmodule // N1_fc
