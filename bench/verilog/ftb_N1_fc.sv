//###############################################################################
//# N1 - Formal Testbench - Flow Control                                        #
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
//#    This is the the formal testbench for the flow control FSM.               #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   March 4, 2019                                                             #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

//DUT configuration
//=================
//Default configuration
//---------------------
`ifdef CONF_DEFAULT
`endif

//Fall back
//---------

module ftb_N1_fc
   (//Clock and reset
    input wire                       clk_i,                        //module clock
    input wire                       async_rst_i,                  //asynchronous reset
    input wire                       sync_rst_i,                   //synchronous reset

    //Program bus
    output wire                      pbus_cyc_o,                   //bus cycle indicator       +-
    output wire                      pbus_stb_o,                   //access request            | initiator to target
    input  wire                      pbus_ack_i,                   //bus acknowledge           +-
    input  wire                      pbus_err_i,                   //error indicator           | target to initiator
    input  wire                      pbus_stall_i,                 //access delay              +-

    //Interrupt interface
    output wire                      irq_ack_o,                    //interrupt acknowledge

    //Internal interfaces
    //-------------------
    //DSP interface
    output wire                      fc2dsp_pc_hold_o,             //maintain PC

    //IR interface
    output wire                      fc2ir_capture_o,              //capture current IR
    output wire                      fc2ir_stash_o,                //capture stashed IR
    output wire                      fc2ir_expend_o,               //stashed IR -> current IR
    output wire                      fc2ir_force_eow_o,            //load EOW bit
    output wire                      fc2ir_force_0call_o,          //load 0 CALL instruction
    output wire                      fc2ir_force_call_o,           //load CALL instruction
    output wire                      fc2ir_force_drop_o,           //load DROP instruction
    output wire                      fc2ir_force_nop_o,            //load NOP instruction
    input  wire                      ir2fc_eow_i,                  //end of word (EOW bit set)
    input  wire                      ir2fc_eow_postpone_i,         //EOW conflict detected
    input  wire                      ir2fc_jump_or_call_i,         //either JUMP or CALL
    input  wire                      ir2fc_bra_i,                  //conditonal BRANCH instruction
    input  wire                      ir2fc_scyc_i,                 //linear flow
    input  wire                      ir2fc_mem_i,                  //memory I/O
    input  wire                      ir2fc_mem_rd_i,               //memory read
    input  wire                      ir2fc_madr_sel_i,             //direct memory address

    //PRS interface
    output wire                      fc2prs_hold_o,                //hold any state tran
    output wire                      fc2prs_dat2ps0_o,             //capture read data
    output wire                      fc2prs_tc2ps0_o,              //capture throw code
    output wire                      fc2prs_isr2ps0_o,             //capture ISR
    input  wire                      prs2fc_hold_i,                //stacks not ready
    input  wire                      prs2fc_ps0_false_i,           //PS0 is zero

    //EXCPT interface
    output wire                      fc2excpt_excpt_clr_o,         //disable exceptions
    output wire                      fc2excpt_irq_dis_o,           //disable interrupts
    output wire                      fc2excpt_buserr_o,            //invalid pbus access
    input  wire                      excpt2fc_excpt_i,             //exception to be handled
    input  wire                      excpt2fc_irq_i,               //exception to be handled

    //Probe signals
    output wire [2:0]                prb_fc_state_o,               //state variable
    output wire                      prb_fc_pbus_acc_o);           //ongoing bus access

   //Instantiation
   //=============
   N1_fc
   DUT
     (//Clock and reset
      .clk_i                      (clk_i),                         //module clock
      .async_rst_i                (async_rst_i),                   //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                    //synchronous reset

      //Program bus
      .pbus_cyc_o                 (pbus_cyc_o),                    //bus cycle indicator       +-
      .pbus_stb_o                 (pbus_stb_o),                    //access request            | initiator to target
      .pbus_ack_i                 (pbus_ack_i),                    //bus acknowledge           +-
      .pbus_err_i                 (pbus_err_i),                    //error indicator           | target to initiator
      .pbus_stall_i               (pbus_stall_i),                  //access delay              +-

      //Interrupt interface
      .irq_ack_o                  (irq_ack_o),                     //interrupt acknowledge

      //DSP interface
      .fc2dsp_pc_hold_o           (fc2dsp_pc_hold_o),              //maintain PC

      //IR interface
      .fc2ir_capture_o            (fc2ir_capture_o),               //capture current IR
      .fc2ir_stash_o              (fc2ir_stash_o),                 //capture stashed IR
      .fc2ir_expend_o             (fc2ir_expend_o),                //stashed IR -> current IR
      .fc2ir_force_eow_o          (fc2ir_force_eow_o),             //load EOW bit
      .fc2ir_force_0call_o        (fc2ir_force_0call_o),           //load 0 CALL instruction
      .fc2ir_force_call_o         (fc2ir_force_call_o),            //load CALL instruction
      .fc2ir_force_drop_o         (fc2ir_force_drop_o),            //load DROP instruction
      .fc2ir_force_nop_o          (fc2ir_force_nop_o),             //load NOP instruction
      .ir2fc_eow_i                (ir2fc_eow_i),                   //end of word (EOW bit set)
      .ir2fc_eow_postpone_i       (ir2fc_eow_postpone_i),          //EOW conflict detected
      .ir2fc_jump_or_call_i       (ir2fc_jump_or_call_i),          //either JUMP or CALL
      .ir2fc_bra_i                (ir2fc_bra_i),                   //conditonal BRANCG instruction
      .ir2fc_scyc_i               (ir2fc_scyc_i),                  //linear flow
      .ir2fc_mem_i                (ir2fc_mem_i),                   //memory I/O
      .ir2fc_mem_rd_i             (ir2fc_mem_rd_i),                //memory read
      .ir2fc_madr_sel_i           (ir2fc_madr_sel_i),              //direct memory address

      //PRS interface
      .fc2prs_hold_o              (fc2prs_hold_o),                 //hold any state tran
      .fc2prs_dat2ps0_o           (fc2prs_dat2ps0_o),              //capture read data
      .fc2prs_tc2ps0_o            (fc2prs_tc2ps0_o),               //capture throw code
      .fc2prs_isr2ps0_o           (fc2prs_isr2ps0_o),              //capture ISR
      .prs2fc_hold_i              (prs2fc_hold_i),                 //stacks not ready
      .prs2fc_ps0_false_i         (prs2fc_ps0_false_i),            //PS0 is zero

      //EXCPT interface
      .fc2excpt_excpt_clr_o       (fc2excpt_excpt_clr_o),          //disable exceptions
      .fc2excpt_irq_dis_o         (fc2excpt_irq_dis_o),            //disable interrupts
      .fc2excpt_buserr_o          (fc2excpt_buserr_o),             //invalid pbus access
      .excpt2fc_excpt_i           (excpt2fc_excpt_i),              //exception to be handled
      .excpt2fc_irq_i             (excpt2fc_irq_i),                //exception to be handled

      //Probe signals
      .prb_fc_state_o             (prb_fc_state_o),                //state variable
      .prb_fc_pbus_acc_o          (prb_fc_pbus_acc_o));            //ongoing bus access

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //===================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                      (clk_i),                         //module clock
      .sync_i                     (1'b1),                          //clock enable
      .async_rst_i                (async_rst_i),                   //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                    //synchronous reset
      .gated_clk_o                ());                             //gated clock

`endif // `ifdef FORMAL

endmodule // ftb_N1_fc
