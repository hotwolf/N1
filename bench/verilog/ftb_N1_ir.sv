//###############################################################################
//# N1 - Formal Testbench - Instruction Register                                #
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
//#    This is the the formal testbench for the instruction register block.     #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 8, 2019                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

//DUT configuration
//=================
//Default configuration
//---------------------
`ifdef CONF_DEFAULT
`endif

//iCE40UP5K configuration
//-----------------------
`ifdef CONF_ICE40UP5K
`endif

//Fall back
//---------

module ftb_N1_ir
   (//Clock and reset
    input wire                    clk_i,                           //module clock
    input wire                    async_rst_i,                     //asynchronous reset
    input wire                    sync_rst_i,                      //synchronous reset

    //Program bus (wishbone)
    output wire                   pbus_tga_cof_jmp_o,              //COF jump
    output wire                   pbus_tga_cof_cal_o,              //COF call
    output wire                   pbus_tga_cof_bra_o,              //COF conditional branch
    output wire                   pbus_tga_cof_eow_o,              //COF return from call
    output wire                   pbus_tga_dat_o,                  //data access
    output wire                   pbus_we_o,                       //write enable
    input  wire [15:0]            pbus_dat_i,                      //read data bus

    //Internal interfaces
    //-------------------
    //ALU interface
    output wire [4:0]             ir2alu_opr_o,                    //ALU operator
    output wire [4:0]             ir2alu_opd_o,                    //immediate operand
    output wire                   ir2alu_opd_sel_o,                //select immediate operand

    //EXCPT interface
    output wire                   ir2excpt_excpt_en_o,             //enable exceptions
    output wire                   ir2excpt_excpt_dis_o,            //disable exceptions
    output wire                   ir2excpt_irq_en_o,               //enable interrupts
    output wire                   ir2excpt_irq_dis_o,              //disable interrupts

    //FC interface
    output wire                   ir2fc_eow_o,                     //end of word (EOW bit set)
    output wire                   ir2fc_eow_postpone_o,            //EOW conflict detected
    output wire                   ir2fc_jump_or_call_o,            //either JUMP or CALL
    output wire                   ir2fc_bra_o,                     //conditonal BRANCG instruction
    output wire                   ir2fc_scyc_o,                    //linear flow
    output wire                   ir2fc_mem_o,                     //memory I/O
    output wire                   ir2fc_mem_rd_o,                  //memory read
    output wire                   ir2fc_madr_sel_o,                //select (indirect) data address
    input  wire                   fc2ir_capture_i,                 //capture current IR
    input  wire                   fc2ir_stash_i,                   //capture stashed IR
    input  wire                   fc2ir_expend_i,                  //stashed IR -> current IR
    input  wire                   fc2ir_force_eow_i,               //load EOW bit
    input  wire                   fc2ir_force_0call_i,             //load 0 CALL instruction
    input  wire                   fc2ir_force_call_i,              //load CALL instruction
    input  wire                   fc2ir_force_drop_i,              //load DROP instruction
    input  wire                   fc2ir_force_nop_i,               //load NOP instruction

    //PAGU interface
    output wire                   ir2pagu_eow_o,                   //end of word (EOW bit)
    output wire                   ir2pagu_eow_postpone_o,          //postpone EOW
    output wire                   ir2pagu_jmp_or_cal_o,            //jump or call instruction
    output wire                   ir2pagu_bra_o,                   //conditional branch
    output wire                   ir2pagu_scyc_o,                  //single cycle instruction
    output wire                   ir2pagu_mem_o,                   //memory I/O
    output wire                   ir2pagu_aadr_sel_o,              //select (indirect) absolute address
    output wire                   ir2pagu_madr_sel_o,              //select (indirect) memory address
    output wire [13:0]            ir2pagu_aadr_o,                  //direct absolute address
    output wire [12:0]            ir2pagu_radr_o,                  //direct relative address
    output wire [7:0]             ir2pagu_madr_o,                  //direct memory address

    //PRS interface
    output wire                   ir2prs_alu2ps0_o,                //ALU output  -> PS0
    output wire                   ir2prs_alu2ps1_o,                //ALU output  -> PS1
    output wire                   ir2prs_lit2ps0_o,                //literal     -> PS0
    output wire                   ir2prs_pc2rs0_o,                 //PC          -> RS0
    output wire                   ir2prs_ps_rst_o,                 //reset parameter stack
    output wire                   ir2prs_rs_rst_o,                 //reset return stack
    output wire                   ir2prs_psp_get_o,                //read parameter stack pointer
    output wire                   ir2prs_psp_set_o,                //write parameter stack pointer
    output wire                   ir2prs_rsp_get_o,                //read return stack pointer
    output wire                   ir2prs_rsp_set_o,                //write return stack pointer
    output wire [15:0]            ir2prs_lit_val_o,                //literal value
    output wire [7:0]             ir2prs_us_tp_o,                  //upper stack transition pattern
    output wire [1:0]             ir2prs_ips_tp_o,                 //10:push, 01:pull
    output wire [1:0]             ir2prs_irs_tp_o,                 //10:push, 01:pull

    //Probe signals
    output wire [15:0]            prb_ir_o,                        //current instruction register
    output wire [15:0]            prb_ir_stash_o);                 //stashed instruction register

   //Instantiation
   //=============
   N1_ir
   DUT
     (//Clock and reset
      .clk_i                      (clk_i),                         //module clock
      .async_rst_i                (async_rst_i),                   //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                    //synchronous reset

      //Program bus (wishbone)
      .pbus_tga_cof_jmp_o         (pbus_tga_cof_jmp_o),            //COF jump
      .pbus_tga_cof_cal_o         (pbus_tga_cof_cal_o),            //COF call
      .pbus_tga_cof_bra_o         (pbus_tga_cof_bra_o),            //COF conditional branch
      .pbus_tga_cof_eow_o         (pbus_tga_cof_eow_o),            //COF return from call
      .pbus_tga_dat_o             (pbus_tga_dat_o),                //data access
      .pbus_we_o                  (pbus_we_o),                     //write enable
      .pbus_dat_i                 (pbus_dat_i),                    //read data bus

      //ALU interface
      .ir2alu_opr_o               (ir2alu_opr_o),                  //ALU operator
      .ir2alu_opd_o               (ir2alu_opd_o),                  //immediate operand
      .ir2alu_opd_sel_o           (ir2alu_opd_sel_o),              //select immediate operand

      //EXCPT interface
      .ir2excpt_excpt_en_o        (ir2excpt_excpt_en_o),           //enable exceptions
      .ir2excpt_excpt_dis_o       (ir2excpt_excpt_dis_o),          //disable exceptions
      .ir2excpt_irq_en_o          (ir2excpt_irq_en_o),             //enable interrupts
      .ir2excpt_irq_dis_o         (ir2excpt_irq_dis_o),            //disable interrupts

      //FC interface
      .ir2fc_eow_o                (ir2fc_eow_o),                   //end of word (EOW bit set)
      .ir2fc_eow_postpone_o       (ir2fc_eow_postpone_o),          //EOW conflict detected
      .ir2fc_jump_or_call_o       (ir2fc_jump_or_call_o),          //either JUMP or CALL
      .ir2fc_bra_o                (ir2fc_bra_o),                   //conditonal BRANCG instruction
      .ir2fc_scyc_o               (ir2fc_scyc_o),                  //linear flow
      .ir2fc_mem_o                (ir2fc_mem_o),                   //memory I/O
      .ir2fc_mem_rd_o             (ir2fc_mem_rd_o),                //memory read
      .ir2fc_madr_sel_o           (ir2fc_madr_sel_o),              //select (indirect) data address
      .fc2ir_capture_i            (fc2ir_capture_i),               //capture current IR
      .fc2ir_stash_i              (fc2ir_stash_i),                 //capture stashed IR
      .fc2ir_expend_i             (fc2ir_expend_i),                //stashed IR -> current IR
      .fc2ir_force_eow_i          (fc2ir_force_eow_i),             //load EOW bit
      .fc2ir_force_0call_i        (fc2ir_force_0call_i),           //load 0 CALL instruction
      .fc2ir_force_call_i         (fc2ir_force_call_i),            //load CALL instruction
      .fc2ir_force_drop_i         (fc2ir_force_drop_i),            //load DROP instruction
      .fc2ir_force_nop_i          (fc2ir_force_nop_i),             //load NOP instruction

      //PAGU interface
      .ir2pagu_eow_o              (ir2pagu_eow_o),                 //end of word (EOW bit)
      .ir2pagu_eow_postpone_o     (ir2pagu_eow_postpone_o),        //postpone EOW
      .ir2pagu_jmp_or_cal_o       (ir2pagu_jmp_or_cal_o),          //jump or call instruction
      .ir2pagu_bra_o              (ir2pagu_bra_o),                 //conditional branch
      .ir2pagu_scyc_o             (ir2pagu_scyc_o),                //single cycle instruction
      .ir2pagu_mem_o              (ir2pagu_mem_o),                 //memory I/O
      .ir2pagu_aadr_sel_o         (ir2pagu_aadr_sel_o),            //select (indirect) absolute address
      .ir2pagu_madr_sel_o         (ir2pagu_madr_sel_o),            //select (indirect) memory address
      .ir2pagu_aadr_o             (ir2pagu_aadr_o),                //direct absolute address
      .ir2pagu_radr_o             (ir2pagu_radr_o),                //direct relative address
      .ir2pagu_madr_o             (ir2pagu_madr_o),                //direct memory address

      //PRS interface
      .ir2prs_alu2ps0_o           (ir2prs_alu2ps0_o),              //ALU output  -> PS0
      .ir2prs_alu2ps1_o           (ir2prs_alu2ps1_o),              //ALU output  -> PS1
      .ir2prs_lit2ps0_o           (ir2prs_lit2ps0_o),              //literal     -> PS0
      .ir2prs_pc2rs0_o            (ir2prs_pc2rs0_o),               //PC          -> RS0
      .ir2prs_ps_rst_o            (ir2prs_ps_rst_o),               //reset parameter stack
      .ir2prs_rs_rst_o            (ir2prs_rs_rst_o),               //reset return stack
      .ir2prs_psp_get_o           (ir2prs_psp_get_o),              //read parameter stack pointer
      .ir2prs_psp_set_o           (ir2prs_psp_set_o),              //write parameter stack pointer
      .ir2prs_rsp_get_o           (ir2prs_rsp_get_o),              //read return stack pointer
      .ir2prs_rsp_set_o           (ir2prs_rsp_set_o),              //write return stack pointer
      .ir2prs_lit_val_o           (ir2prs_lit_val_o),              //literal value
      .ir2prs_us_tp_o             (ir2prs_us_tp_o),                //upper stack transition pattern
      .ir2prs_ips_tp_o            (ir2prs_ips_tp_o),               //10:push, 01:pull
      .ir2prs_irs_tp_o            (ir2prs_irs_tp_o),               //10:push, 01:pull

      //Probe signals
      .prb_ir_o                   (prb_ir_o),                      //current instruction register
      .prb_ir_stash_o             (prb_ir_stash_o));               //stashed instruction register

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //===================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                    (clk_i),                           //module clock
      .sync_i                   (1'b1),                            //clock enable
      .async_rst_i              (async_rst_i),                     //asynchronous reset
      .sync_rst_i               (sync_rst_i),                      //synchronous reset
      .gated_clk_o              ());                               //gated clock

`endif //  `ifdef FORMAL

endmodule // ftb_N1_ir
