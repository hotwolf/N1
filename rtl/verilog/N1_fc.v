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

module N1_fc
  #(parameter   TC_PSUF   = 12,                                                              //width of a stack pointer
    parameter   TC_PSOF  =  8,                                                               //depth of the intermediate parameter stack
    parameter   TC_RSUF  =  8)                                                               //depth of the intermediate return stack


   (//Clock and reset
    input wire                       clk_i,                                                  //module clock
    input wire                       async_rst_i,                                            //asynchronous reset
    input wire                       sync_rst_i,                                             //synchronous reset

    //Program bus
    output reg                       pbus_cyc_o,                                             //bus cycle indicator       +-
    output reg                       pbus_stb_o,                                             //access request            | initiator to target
    input  wire                      pbus_ack_i,                                             //bus acknowledge           +-
    input  wire                      pbus_err_i,                                             //error indicator           | target to initiator
    input  wire                      pbus_stall_i,                                           //access delay              +-

    //Interrupt interface
    output reg                       irq_ack_o,                                              //interrupt acknowledge

    //Internal interfaces
    //-------------------
    //DSP interface
    output reg                       fc2dsp_hold_o,                                          //maintain PC

    //IR interface
    output reg                       fc2ir_capture_o,                                        //capture current IR
    output reg                       fc2ir_stash_o,                                          //capture stashed IR
    output reg                       fc2ir_expend_o,                                         //stashed IR -> current IR
    output reg                       fc2ir_force_eow_o,                                      //load EOW bit
    output reg                       fc2ir_force_0call_o,                                    //load 0 CALL instruction
    output reg                       fc2ir_force_call_o,                                     //load CALL instruction
    output reg                       fc2ir_force_fetch_o,                                    //load FETCH instruction
    output reg                       fc2ir_force_drop_o,                                     //load DROP instruction
    output reg                       fc2ir_force_nop_o,                                      //load NOP instruction
    input  wire                      ir2fc_eow_i,                                            //end of word (EOW bit set)
    input  wire                      ir2fc_eow_postpone_i,                                   //EOW conflict detected
    input  wire                      ir2fc_bra_i,                                            //conditional branch
    input  wire                      ir2fc_jmp_or_call_i,                                    //jump or call instruction
    input  wire                      ir2fc_mem_i,                                            //memory I/O
    input  wire                      ir2fc_memrd_i,                                          //mreory read
    input  wire                      ir2fc_scyc_i,                                           //single cycle instruction

    //PRS interface
    output reg                       fc2prs_hold_o,                                          //hold any state tran
    input  wire                      prs2fc_hold_i,                                          //stacks not ready
    input  wire                      prs2fc_ps0_true_i,                                      //PS0 in non-zero

    //EXCPT interface
    output wire                      fc2excpt_excpt_dis_o,                                   //disable exceptions
    output wire                      fc2excpt_irq_dis_o,                                     //disable interrupts
    output wire                      fc2excpt_buserr_o,                                      //invalid pbus access
    input  wire                      excpt2fc_excpt_i,                                       //exception to be handled
    input  wire                      excpt2fc_irq_i,                                         //exception to be handled

     //Probe signals
    output wire [2:0]                prb_fc_state_o);                                        //state variable

   //Internal signals
   //----------------
   //State variable
   reg  [2:0]                        state_reg;                                              //state variable
   reg  [2:0]                        state_next;                                             //next state

   //Finite state machine <-TBD (remove INIT0)
   //--------------------
   localparam STATE_INIT_0         = 3'b000;
   localparam STATE_INIT_1         = 3'b001;
   localparam STATE_EXEC           = 3'b010;
   localparam STATE_EXEC_STASH     = 3'b011;
   localparam STATE_EXEC_MEM       = 3'b100;
   localparam STATE_EXEC_MEM_CAPT  = 3'b101;
   localparam STATE_EXEC_ISR       = 3'b110;
   localparam STATE_UNREACH        = 3'b111;

   always @*
     begin
        //Default outputs
        pbus_cyc_o              = 1'b0;                                                      //bus cycle indicator
        pbus_stb_o              = 1'b0;                                                      //access request

        irq_ack_o               = 1'b0;                                                      //interrupt acknowledge

        fc2dsp_hold_o           = 1'b0;                                                      //maintain PC

        fc2ir_capture_o         = 1'b0;                                                      //capture current IR
        fc2ir_stash_o           = 1'b0;                                                      //capture stashed IR
        fc2ir_expend_o          = 1'b0;                                                      //stashed IR -> current IR
        fc2ir_force_eow_o       = 1'b0;                                                      //load EOW bit
        fc2ir_force_0call_o     = 1'b0;                                                      //load 0 CALL instruction
        fc2ir_force_call_o      = 1'b0;                                                      //load CALL instruction
        fc2ir_force_fetch_o     = 1'b0;                                                      //load FETCH instruction
        fc2ir_force_drop_o      = 1'b0;                                                      //load DROP instruction
        fc2ir_force_nop_o       = 1'b0;                                                      //load NOP instruction

        fc2prs_hold_o           = 1'b0;                                                      //hold any state tran

        fc2excpt_excpt_dis_o    = 1'b0;                                                      //disable exceptions
        fc2excpt_irq_dis_o      = 1'b0;                                                      //disable interrupts
        fc2excpt_buserr_o       = 1'b0;                                                      //invalid pbus access

        state_next              = 0;                                                         //remain in current state

        case (state_reg)
          //Initiate jump to address zero
          STATE_INIT_0:
            begin
               pbus_cyc_o          = 1'bo;                                                   //Keep bus idle
               pbus_stb_o          = 1'b0;                                                   //
               fc2ir_force_0call_o = 1'b1;                                                   //force jump to addess zero
               fc2ir_force_eow_o   = 1'b1;                                                   //(call + EOW)
               state_next          = STATE_INIT1;                                            //execute jump
            end

          //Jump to address zero
          STATE_INIT_1:
            begin
               pbus_cyc_o          = 1'b1;                                                   //first bus request
               pbus_stb_o          = 1'b1;                                                   //
               fc2ir_force_nop_o   = 1'b1;                                                   //force wait cycle
               state_next          = pbus_stall_i ? state_reg :                              //handle stall
                                                    STATE_EXEC;                              //execute first opcode
            end

          //Execute first cycle of the current instruction
          STATE_EXEC,
          STATE_EXEC_STASH:
            begin
               //Wait for bus response (stay in sync with memory)
               if (~|{state_reg ^ STATE_EXEC} &                                              //only valid for STATE_EXEC
                   ~pbus_ack_i &                                                             //no bus acknowledge
                   ~pbus_err_i)                                                              //no error indicator
                 begin
                    pbus_cyc_o     = 1'b1;                                                   //delay next access
                    pbus_stb_o     = 1'b0;                                                   //
                    fc2dsp_hold_o  = 1'b1;                                                   //don't update PC
                    fc2prs_hold_o  = 1'b1;                                                   //don't update stacks
                    state_next     = state_reg;                                              //remain in current state
                 end
               //Bus response received
               else
                 begin
                    //Trigger exception
                    fc2excpt_buserr_o = ~|{ir2fc_jmp_or_call_i,                              //no jump or call
                                           (ir2fc_bra_i &                                    //no conditional branch
                                            |prs2fc_ps0_i),                                  //
                                           ir2fc_eow_i,                                      //no EOW
                                           ~pbus_err_i};                                     //bus error
                    //Wait for stacks
                    if (prs2fc_hold_i)                                                       //stacks are busy
                      begin
                         fc2ir_stash_o = ~|{state_reg ^ STATE_EXEC};                         //stash next instruction
                         pbus_cyc_o    = ~|{state_reg ^ STATE_EXEC};                         //delay next access
                         pbus_stb_o    = 1'b0;                                               //
                         fc2dsp_hold_o = 1'b1;                                               //don't update PC
                         fc2prs_hold_o = 1'b1;                                               //don't update stacks
                         state_next    = STATE_EXEC_STASH;                                   //track stashed opcode
                      end
                    //Initiate next bus access
                    else
                      begin
                         pbus_cyc_o    = 1'b1;                                               //bus access
                         pbus_stb_o    = 1'b1;                                               //
                         //Wait while Pbus is stalled
                         if (pbus_stall_i)
                           begin
                              fc2ir_stash_o = ~|{state_reg ^ STATE_EXEC};                    //stash next instruction
                              fc2dsp_hold_o = 1'b1;                                          //don't update PC
                              fc2prs_hold_o = 1'b1;                                          //don't update stacks
                              state_next    = STATE_EXEC_STASH;                              //track stashed opcode
                           end
                         //Execute
                         else
                           begin
                              //Memory I/O
                              if (ir2fc_mem_i)
                                begin
                                   fc2dsp_hold_o       = 1'b1;                               //don't update PC
                                   fc2ir_stash_o       = fc2ir_stash_o  |                    //make use of onehot encoding
                                                         ~|{state_reg ^ STATE_EXEC);         //stash next instruction
                                   fc2ir_force_drop_o  = fc2ir_force_drop_o |                //make use of onehot encoding
                                                         ~ir2fc_memrd_i;                     //force DROP opcode
                                   fc2ir_force_fetch_o = fc2ir_force_fetch_o                 //make use of onehot encoding
                                                         ir2fc_memrd_i;                      //force FETCH opcode
                                   fc2ir_force_eow_o   = fc2ir_force_eow_o |                 //make use of onehot encoding
                                                         ir2fc_eow_i;                        //postpone EOW
                                   state_next          = state_next |                        //make use of onehot encoding
                                                         STATE_EXEC_MEM;                     //handle 2nd memory I/O cycle
                                end

                              //Change of flow
                              if (ir2fc_jmp_or_call_i                                    |   //jump or call
                                  (ir2fc_bra_i & prs2fc_ps0_true_i)                      |   //conditional branch
                                  (ir2fc_bra_i & ir2fc_eow_i)                            |   //conditional branch with EOW
                                  (ir2fc_scyc_i & ir2fc_eow_i & ~ir2pagu_eow_postpone_i))    //end of word
                                begin
                                   //Exception
                                   if (excpt2fc_excpt_i)                                     //pending exception
                                     begin
                                        fc2ir_force_0call_o  = 1'b1;                         //force jump to addess zero
                                        fc2ir_force_eow_o    = 1'b1;                         //(call + EOW)
                                        fc2excpt_excpt_dis_i = 1'b1;                         //inhibit further exceptions
                                        state_next           = state_next |                  //make use of onehot encoding
                                                               STATE_EXEC;                   //execute jump
                                     end
                                   //Interrupt
                                   else if (excpt2fc_irq_i)                                   //pending interrupt
                                     begin
                                        fc2ir_force_ivec_o = 1'b1;                            //force IVEC instruction
                                        state_next         = state_next |                     //make use of onehot encoding
                                                             STATE_ISR;                       //service interrupt
                                     end
                                   //Resume program flow
                                   else
                                     begin
                                        fc2ir_force_nop_o   = 1'b1;                          //force NOP opcode
                                        state_next          = state_next |                   //make use of onehot encoding
                                                              STATE_EXEC;                    //execute NOP
                                     end
                                end // if (ir2fc_jmp_or_call_i |...

                              //Linear execution
                              if ((ir2fc_scyc_i & (~ir2fc_eow_i | ir2pagu_eow_postpone_i)) | //single cycle instruction
                                  (ir2fc_bra_i  & ~ir2fc_eow_i & ~prs2fc_ps0_true_i))        //conditional branch
                                begin
                                   //Exception
                                   if (excpt2fc_excpt_i) //pending exception
                                     begin
                                        fc2ir_force_0call_o  = 1'b1;                         //force jump to addess zero
                                        fc2ir_force_eow_o    = 1'b1;                         //(call + EOW)
                                        fc2excpt_excpt_dis_i = 1'b1;                         //inhibit further exceptions
                                        state_next           = state_next |                  //make use of onehot encoding
                                                               STATE_EXEC;                   //execute jump
                                     end
                                   //Interrupt
                                   else if (excpt2fc_irq_i)                                  //pending interrupt
                                     begin
                                        fc2dsp_hold_o        = 1'b1;                         //don't update PC
                                        fc2ir_force_ivec_o   = 1'b1;                         //force IVEC instruction
                                        state_next           = state_next |                  //make use of onehot encoding
                                                               STATE_ISR;                    //service interrupt
                                     end
                                   //Postpone EOW
                                   else if (ir2fc_scyc_i & ir2fc_eow_i &                     //single cycle instruction with EOW bit set
                                            ir2pagu_eow_postpone_i)                          //postpone EOW
                                     begin
                                        fc2dsp_hold_o        = 1'b1;                         //don't update PC
                                        fc2ir_force_nop_o    = 1'b1;                         //force NOP execution
                                        fc2ir_force_eow_o    = 1'b1;                         //force EOW bit
                                        state_next           = state_next |                  //make use of onehot encoding
                                                               STATE_EXEC;                   //execute NOP

                                     end
                                   //Continue program flow
                                   else
                                     begin
                                        fc2ir_expend_o  = fc2ir_expend_o |                   //make use of onehot encoding
                                                          ~|{state_reg ^ STATE_EXEC_STASH);  //use stashed upcode next
                                        fc2ir_capture_o = fc2ir_capture_o |                  //make use of onehot encoding
                                                          ~|{state_reg ^ STATE_EXEC);        //capture opcode
                                        state_next      = state_next |                       //make use of onehot encoding
                                                          STATE_EXEC;                        //execute next opcode
                                     end // else: !if(ir2fc_scyc_i & (~ir2fc_eow_i | ir2pagu_eow_postpone_i))
                                end // if ((ir2fc_scyc_i & (~ir2fc_eow_i | ir2pagu_eow_postpone_i)) |...
                           end // else: !if(pbus_stall_i)
                      end // else: !if(prs2fc_hold_i)
                 end // else: !if(~|{state_reg ^ STATE_EXEC)
            end // case: STATE_EXEC,...

          //Execute the second cycle of a memory I/O instruction
          STATE_EXEC_MEM,
          STATE_EXEC_MEM_CAPT:
            begin
               //Wait for bus response (stay in sync with memory)
               if (~pbus_ack_i &                                                             //no bus acknowledge
                   ~pbus_err_i)                                                              //no error indicator
                 begin
                    pbus_cyc_o    = 1'b1;                                                    //delay next access
                    pbus_stb_o    = 1'b0;                                                    //
                    fc2dsp_hold_o = 1'b1;                                                    //don't update PC
                    fc2prs_hold_o = 1'b1;                                                    //don't update stacks
                    state_next    = state_reg;                                               //remain in current state
                 end
               //Bus response received
               else
                 begin
                    //Fetch read data
                    fc2prs_hold_o = ~|{state_reg ^ STATE_MEM_CAPT};                          //don't update stacks
                    //Trigger exception
                    fc2excpt_buserr_o = pbus_err_i;                                          //bus error
                    //Initiate next bus access
                    pbus_cyc_o    = 1'b1;                                                    //bus access
                    pbus_stb_o    = 1'b1;                                                    //
                    //Wait while Pbus is stalled
                    if (pbus_stall_i)
                      begin
                         fc2dsp_hold_o = 1'b1;                                               //don't update PC
                         state_next    = STATE_MEM_CAPT;                                     //remember captured data
                      end
                    //Exception
                    else if (excpt2fc_excpt_i)                                               //pending exception
                      begin
                         fc2ir_force_0call_o  = 1'b1;                                        //force jump to addess zero
                         fc2ir_force_eow_o    = 1'b1;                                        //(call + EOW)
                         fc2excpt_excpt_dis_i = 1'b1;                                        //inhibit further exceptions
                         state_next           = STATE_EXEC;                                  //execute jump
                      end
                    //Interrupt
                    else if (excpt2fc_irq_i)                                                 //pending interrupt
                      begin
                         fc2ir_force_ivec_o = 1'b1;                                          //force IVEC instruction
                         state_next         = STATE_ISR;                                     //service interrupt
                      end
                    //Execute EOW
                    else if (ir2fc_eow_i)                                                    //EOW captured
                      begin
                         fc2ir_force_nop_o    = 1'b1;                                        //force NOP execution
                         state_next           = STATE_EXEC;                                  //execute NOP
                      end
                    //Expend stashed instruction
                    else
                      begin
                         fc2ir_expend_o = 1'b1                                               //stashed IR -> current IR
                         state_next     = STATE_EXEC;                                        //execute stashed i
                      end // else: !if(ir2fc_eow_i)
                 end // else: !if(~pbus_ack_i &...
            end // case: STATE_EXEC_MEM,...

          //ISR launcher
          STATE_ISR,
          STATE_UNREACH:
            begin
               fc2dsp_hold_o = 1'b1;                                                         //don't update PC
               fc2ir_force_call_o   = 1'b1;                                                  //force CALL execution
               state_next           = STATE_EXEC;                                            //execute CALL
            end

        endcase // case (state_reg)
     end // always @ *

   //Flip flops
   //----------
   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                                     //asynchronous reset
          state_reg <= STATE_INIT1;
        else if (sync_rst_i)                                                                 //synchronous reset
          state_reg <= STATE_INIT1;
        else                                                                                 //state transition
          state_reg <= state_next;
     end // always @ (posedge async_rst_i or posedge clk_i)

   //Probe signals
   //-------------
   assign  prb_fc_state_o = state_reg;   //state variable

endmodule // N1_fc
