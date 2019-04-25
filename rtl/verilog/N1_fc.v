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
    input  wire                      ir2fc_eow_i,                                              //end of word (EOW bit set)
    input  wire                      ir2fc_eow_postpone_i,                                     //EOW conflict detected
    input  wire                      ir2fc_jump_or_call_i,                                     //either JUMP or CALL
    input  wire                      ir2fc_bra_i,                                              //conditonal BRANCH instruction
    input  wire                      ir2fc_scyc_i,                                             //linear flow
    input  wire                      ir2fc_mem_i,                                              //memory I/O
    input  wire                      ir2fc_mem_rd_i,                                           //memory read
    input  wire                      ir2fc_madr_sel_i,                                         //direct memory address

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
    output reg                       fc2excpt_buserr_o,                                        //invalid pbus access
    input  wire                      excpt2fc_excpt_i,                                         //exception to be handled
    input  wire                      excpt2fc_irq_i,                                           //exception to be handled

    //Probe signals
    output wire [2:0]                prb_fc_state_o,                                           //state variable
    output wire                      prb_fc_pbus_acc_o);                                       //ongoing bus access

   //Internal signals
   //----------------
   //PBUS monitor
   reg                               pbus_acc_reg;                                             //ongoing bus access
   wire                              pbus_acc_next;                                            //next state of the PBUS monitor
   //State variable
   reg  [2:0]                        state_reg;                                                //state variable
   reg  [2:0]                        state_next;                                               //next state

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
   localparam STATE_EXEC        = 3'b000;                                                      //execute single cycle instruction (next upcode on read data bus)
   localparam STATE_EXEC_STASH  = 3'b001;                                                      //execute single cycle instruction (next opcode stached)
   localparam STATE_EXEC_READ   = 3'b010;                                                      //second cycle of the reaad instruction
   localparam STATE_EXEC_IRQ    = 3'b011;                                                      //Capture ISR and prepare CALL
   localparam STATE_EXEC_EXCPT  = 3'b111;                                                      //Capture ISR and prepare CALL

   always @*
     begin
        //Default outputs
        pbus_stb_o              = 1'b1;                                                        //access request
        irq_ack_o               = 1'b0;                                                        //interrupt acknowledge
        fc2dsp_pc_hold_o        = 1'b0;                                                        //maintain PC
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
        fc2excpt_buserr_o       = 1'b0;                                                        //invalid pbus access
        state_next              = state_reg;                                                   //remain in current state

        //Wait for bus response (stay in sync with memory)
        if (pbus_acc_reg &                                                                     //ongoung bus access
            ~pbus_ack_i  &                                                                     //no bus acknowledge
            ~pbus_err_i)                                                                       //no error indicator
          begin
             state_next       = state_reg;                                                     //remain in current state
             pbus_stb_o       = 1'b0;                                                          //delay next access
             fc2dsp_pc_hold_o = 1'b1;                                                          //don't update PC
             fc2prs_hold_o    = 1'b1;                                                          //don't update stacks
          end
        //Bus response received
        else
          begin
             //Trigger exception
             fc2excpt_buserr_o = pbus_err_i                          &                         //bus error
                                 ~ir2fc_jump_or_call_i               &                         //no JUMP or CALL
                                 ~(ir2fc_bra_i & prs2fc_ps0_false_i) &                         //no BRANCH taken
                                 ~ir2fc_eow_i;                                                 //no EOW
             //Capture read data
             if (~|{state_reg[1:0] ^ STATE_EXEC_READ[1:0]})                                    //STATE_EXEC_READ
               begin
                  fc2prs_dat2ps0_o   = 1'b1;                                                   //read data -> PS0
                  state_next         = STATE_EXEC_STASH;                                       //capture read data only once
               end
             //Wait for stacks
             if (prs2fc_hold_i)                                                                //stacks are busy
               begin
                  if (~|{state_reg[1:0] ^ STATE_EXEC[1:0]})                                    //STATE_EXEC
                    begin
                       fc2ir_stash_o = 1'b1;                                                   //stash next instruction
                       state_next    = STATE_EXEC_STASH;                                       //track stashed opcode
                    end
                  pbus_stb_o       = 1'b0;                                                     //idle pbus
                  fc2dsp_pc_hold_o = 1'b1;                                                     //don't update PC
                  fc2prs_hold_o    = 1'b1;                                                     //don't update stacks
               end // if (prs2fc_hold_i)
             //Initiate next bus access
             else
               begin
                  //Wait while Pbus is stalled
                  if (pbus_stall_i)
                    begin
                       if (~|{state_reg[1:0] ^ STATE_EXEC[1:0]})                               //STATE_EXEC
                         begin
                            fc2ir_stash_o = 1'b1;                                              //stash next instruction
                            state_next    = STATE_EXEC_STASH;                                  //track stashed opcode
                         end
                       fc2dsp_pc_hold_o   = 1'b1;                                              //don't update PC
                       fc2prs_hold_o      = 1'b1;                                              //don't update stacks
                    end
                  //Execute
                  else
                    begin
                       //Multi-cycle instruction
                       if (ir2fc_jump_or_call_i               |                                //call or jump
                           (ir2fc_bra_i & prs2fc_ps0_false_i) |                                //BRANCH taken
                           ir2fc_eow_i                        |                                //EOW
                           ir2fc_mem_i)                                                        //memory I/O
                         begin

                            //Memory I/O
                            if (ir2fc_mem_i)
                              begin
                                 if (~|{state_reg[1:0] ^ STATE_EXEC[1:0]})                     //STATE_EXEC
                                   begin
                                      fc2ir_stash_o      = 1'b1;                               //stash next instruction
                                   end
                                 fc2dsp_pc_hold_o        = 1'b1;                               //don't update PC
                                 fc2ir_force_eow_o       = ir2fc_eow_i;                        //postpone EOW
                                 //Fetch
                                 if (ir2fc_mem_rd_i)
                                   begin
                                      fc2ir_force_nop_o  = 1'b1;                               //overwrite PS0
                                      state_next         = STATE_EXEC_READ;                    //fetch read data
                                   end
                                 //Store
                                 else
                                   begin
                                      fc2ir_force_drop_o =  ir2fc_madr_sel_i;                  //indirect addressing
                                      fc2ir_force_nop_o  = ~ir2fc_madr_sel_i;                  //direct addressing
                                      state_next         = STATE_EXEC_STASH;                   //track stashed opcode
                                   end // else: !if(ir2fc_mem_rd_i)
                              end

                            //Change of flow
                            else if (ir2fc_jump_or_call_i                   |                  //call or jump
                                     (ir2fc_bra_i & prs2fc_ps0_false_i)     |                  //BRANCH taken
                                     (ir2fc_eow_i & ~ir2fc_eow_postpone_i))                    //EOW (not postponed)
                              begin
                                 fc2ir_force_nop_o       = 1'b1;                               //direct addressing
                                 state_next              = STATE_EXEC;                         //execute NOP
                              end

                            //Postponed EOW
                              else
                                begin
                                   fc2ir_force_eow_o       = 1'b1;                             //force EOW bit
                                   fc2ir_force_nop_o       = 1'b1;                             //force NOP instruction
                                   state_next              = STATE_EXEC;                       //execute EOW
                                end

                         end // if (ir2fc_jump_or_call_i              |...

                       //Single-cycle instruction
                       else
                         begin

                            //Prepare exception handler
                            if (~|{state_reg ^ STATE_EXEC_EXCPT})                              //STATE_EXEC_EXCPT
                              begin
                                 fc2dsp_pc_hold_o        = 1'b1;                               //don't update PC
                                 fc2prs_tc2ps0_o         = 1'b1;                               //capture throw code
                                 fc2ir_force_0call_o     = 1'b1;                               //force CALL instruction
                                 fc2excpt_excpt_clr_o    = 1'b1;                               //disable interrupts
                                 state_next              = STATE_EXEC;                         //execute CALL
                              end

                            //Prepare ISR
                            else if (~|{state_reg ^ STATE_EXEC_IRQ})                           //STATE_EXEC_IRQ
                              begin
                                 //IRQ still pending
                                 if (excpt2fc_irq_i)                                           //pending interrupt request
                                   begin
                                      fc2dsp_pc_hold_o   = 1'b1;                               //don't update PC
                                      fc2prs_isr2ps0_o   = 1'b1;                               //capture ISR address
                                      fc2ir_force_call_o = 1'b1;                               //force CALL instruction
                                      fc2excpt_irq_dis_o = 1'b1;                               //disable interrupts
                                      state_next         = STATE_EXEC;                         //execute CALL
                                   end
                                 //IRQ retracted
                                 else
                                   begin
                                      fc2ir_capture_o    = 1'b1;                               //capture IR
                                      state_next         = STATE_EXEC;                         //execute CALL
                                   end // else: !if(excpt2fc_irq_i)
                              end // if (~|{state_reg ^ STATE_EXEC_IRQ})

                            //Exception
                            else if (excpt2fc_excpt_i)                                         //pending exception
                              begin
                                 fc2dsp_pc_hold_o        = 1'b1;                               //don't update PC
                                 fc2ir_force_nop_o       = 1'b1;                               //force jump to addess zero
                                 state_next              = STATE_EXEC_EXCPT;                   //execute jump
                              end

                            //Interrupt request
                            else if (excpt2fc_irq_i)                                           //pending interrupt request
                              begin
                                 fc2dsp_pc_hold_o        = 1'b1;                               //don't update PC
                                 fc2ir_force_nop_o       = 1'b1;                               //capture ISR
                                 state_next              = STATE_EXEC_IRQ;                     //capture ISR
                              end

                            //Continue program flow
                            else
                              begin
                                 fc2ir_expend_o          = ~|{state_reg ^ STATE_EXEC_STASH} |  //use stashed upcode next
                                                           ~|{state_reg ^ STATE_EXEC_READ};    //
                                 fc2ir_capture_o         = ~|{state_reg ^ STATE_EXEC};         //capture opcode
                                 state_next              = STATE_EXEC;                         //execute next opcode
                              end // else: !if(excpt2fc_irq_i)

                         end // else: !if(ir2fc_jump_or_call_i              |...
                    end // else: !if(pbus_stall_i)
               end // else: !if(prs2fc_hold_i)
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
