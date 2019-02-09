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

//Fall back
//---------

module ftb_N1_ir
   (//Clock and reset
    input  wire                   clk_i,                           //module clock
    input  wire                   async_rst_i,                     //asynchronous reset
    input  wire                   sync_rst_i,                      //synchronous reset

    //Program bus (wishbone)
    input  wire [15:0]            pbus_dat_i,                      //read data bus

    //Instruction decoder output
    output wire                   ir_eow_o,                        //end of word
    output wire                   ir_jmp_o,                        //jump instruction (any)
    output wire                   ir_jmp_ind_o,                    //jump instruction (indirect addressing)
    output wire                   ir_jmp_dir_o,                    //jump instruction (direct addressing)
    output wire                   ir_call_o,                       //call instruction (any)
    output wire                   ir_call_ind_o,                   //call instruction (indirect addressing)
    output wire                   ir_call_dir_o,                   //call instruction (direct addressing)
    output wire                   ir_bra_o,                        //branch instruction (any)
    output wire                   ir_bra_ind_o,                    //branch instruction (indirect addressing)
    output wire                   ir_bra_dir_o,                    //branch instruction (direct addressing)
    output wire                   ir_lit_o,                        //literal instruction
    output wire                   ir_alu_o,                        //ALU instruction (any)
    output wire                   ir_alu_x_x_o,                    //ALU instruction (   x --   x )
    output wire                   ir_alu_xx_x_o,                   //ALU instruction ( x x --   x )
    output wire                   ir_alu_x_xx_o,                   //ALU instruction (   x -- x x )
    output wire                   ir_alu_xx_xx_o,                  //ALU instruction ( x x -- x x )
    output wire                   ir_sop_o,                        //stack operation
    output wire                   ir_fetch_o,                      //memory read (any)
    output wire                   ir_fetch_ind_o,                  //memory read (indirect addressing)
    output wire                   ir_fetch_dir_o,                  //memory read (direct addressing)
    output wire                   ir_store_o,                      //memory write (any)
    output wire                   ir_store_ind_o,                  //memory write (indirect addressing)
    output wire                   ir_store_dir_o,                  //memory write (direct addressing)
    output wire                   ir_ctrl_o,                       //Control instruction (any)
    output wire                   ir_ctrl_ps_rst_o,                //control instruction (reset parameter stack)
    output wire                   ir_ctrl_rs_rst_o,                //control instruction (reset return stack)
    output wire                   ir_ctrl_irqen_we_o,              //control instruction (change interrupt mask)
    output wire                   ir_ctrl_irqen_val_o,             //control instruction (new interrupt mask value)
    output wire [13:0]            ir_dir_abs_adr_o,                //direct absolute COF address
    output wire [12:0]            ir_dir_rel_adr_o,                //direct relative COF address
    output wire [11:0]            ir_lit_val_o,                    //literal value
    output wire [4:0]             ir_opr_o,                        //ALU operator
    output wire [4:0]             ir_imm_op_o,                     //immediate operand
    output wire [9:0]             ir_stp_o,                        //stack transition pattern
    output wire [7:0]             ir_dir_mem_adr_o,                //direct absolute data address
    output wire                   ir_sel_dir_abs_adr_o,            //silect direct absolute address
    output wire                   ir_sel_dir_rel_adr_o,            //select direct relative address
    output wire                   ir_sel_dir_mem_adr_o,            //select direct data address
    output wire                   ir_sel_imm_op_o,                 //select immediate operand

    //Flow control interface
    input  wire                   fc_ir_capture_i,                 //capture current IR
    input  wire                   fc_ir_hoard_i,                   //capture hoarded IR
    input  wire                   fc_ir_expend_i,                  //hoarded IR -> current IR

    //Probe signals
    output wire [15:0]            prb_ir_cur_o,                    //current instruction register
    output wire [15:0]            prb_ir_hoard_o);                 //hoarded instruction register

   //Instantiation
   //=============
   N1_ir
   DUT
     (//Clock and reset
      .clk_i                    (clk_i),                           //module clock
      .async_rst_i              (async_rst_i),                     //asynchronous reset
      .sync_rst_i               (sync_rst_i),                      //synchronous reset

      //Program bus (wishbone)
      .pbus_dat_i               (pbus_dat_i),                      //read data bus

      //Instruction decoder output
      .ir_eow_o                 (ir_eow_o),                        //end of word
      .ir_jmp_o                 (ir_jmp_o),                        //jump instruction (any)
      .ir_jmp_ind_o             (ir_jmp_ind_o),                    //jump instruction (indirect addressing)
      .ir_jmp_dir_o             (ir_jmp_dir_o),                    //jump instruction (direct addressing)
      .ir_call_o                (ir_call_o),                       //call instruction (any)
      .ir_call_ind_o            (ir_call_ind_o),                   //call instruction (indirect addressing)
      .ir_call_dir_o            (ir_call_dir_o),                   //call instruction (direct addressing)
      .ir_bra_o                 (ir_bra_o),                        //branch instruction (any)
      .ir_bra_ind_o             (ir_bra_ind_o),                    //branch instruction (indirect addressing)
      .ir_bra_dir_o             (ir_bra_dir_o),                    //branch instruction (direct addressing)
      .ir_lit_o                 (ir_lit_o),                        //literal instruction
      .ir_alu_o                 (ir_alu_o),                        //ALU instruction (any)
      .ir_alu_x_x_o             (ir_alu_x_x_o),                    //ALU instruction (   x --   x )
      .ir_alu_xx_x_o            (ir_alu_xx_x_o),                   //ALU instruction ( x x --   x )
      .ir_alu_x_xx_o            (ir_alu_x_xx_o),                   //ALU instruction (   x -- x x )
      .ir_alu_xx_xx_o           (ir_alu_xx_xx_o),                  //ALU instruction ( x x -- x x )
      .ir_sop_o                 (ir_sop_o),                        //stack operation
      .ir_fetch_o               (ir_fetch_o),                      //memory read (any)
      .ir_fetch_ind_o           (ir_fetch_ind_o),                  //memory read (indirect addressing)
      .ir_fetch_dir_o           (ir_fetch_dir_o),                  //memory read (direct addressing)
      .ir_store_o               (ir_store_o),                      //memory write (any)
      .ir_store_ind_o           (ir_store_ind_o),                  //memory write (indirect addressing)
      .ir_store_dir_o           (ir_store_dir_o),                  //memory write (direct addressing)
      .ir_ctrl_o                (ir_ctrl_o),                       //Control instruction (any)
      .ir_ctrl_ps_rst_o         (ir_ctrl_ps_rst_o),                //control instruction (reset parameter stack)
      .ir_ctrl_rs_rst_o         (ir_ctrl_rs_rst_o),                //control instruction (reset return stack)
      .ir_ctrl_irqen_we_o       (ir_ctrl_irqen_we_o),              //control instruction (change interrupt mask)
      .ir_ctrl_irqen_val_o      (ir_ctrl_irqen_val_o),             //control instruction (new interrupt mask value)
      .ir_dir_abs_adr_o         (ir_dir_abs_adr_o),                //direct absolute COF address
      .ir_dir_rel_adr_o         (ir_dir_rel_adr_o),                //direct relative COF address
      .ir_lit_val_o             (ir_lit_val_o),                    //literal value
      .ir_opr_o                 (ir_opr_o),                        //ALU operator
      .ir_imm_op_o              (ir_imm_op_o),                     //immediate operand
      .ir_stp_o                 (ir_stp_o),                        //stack transition pattern
      .ir_dir_mem_adr_o         (ir_dir_mem_adr_o),                //direct absolute data address
      .ir_sel_dir_abs_adr_o     (ir_sel_dir_abs_adr_o),            //silect direct absolute address
      .ir_sel_dir_rel_adr_o     (ir_sel_dir_rel_adr_o),            //select direct relative address
      .ir_sel_dir_mem_adr_o     (ir_sel_dir_mem_adr_o),            //select direct data address
      .ir_sel_imm_op_o          (ir_sel_imm_op_o),                 //select immediate operand

      //Flow control interface
      .fc_ir_capture_i          (fc_ir_capture_i),                 //capture current IR
      .fc_ir_hoard_i            (fc_ir_hoard_i),                   //capture hoarded IR
      .fc_ir_expend_i           (fc_ir_expend_i),                  //hoarded IR -> current IR

      //Probe signals
      .prb_ir_cur_o             (prb_ir_cur_o),                    //current instruction register
      .prb_ir_hoard_o           (prb_ir_hoard_o));                 //hoarded instruction register

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
