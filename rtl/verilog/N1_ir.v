//###############################################################################
//# N1 - Instruction Register                                                   #
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
//#    This module implements the N1's instruction register(IR) and the decoder #
//#    logic.                                                                   #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_ir
   (//Clock and reset
    input wire                    clk_i,                                          //module clock
    input wire                    async_rst_i,                                    //asynchronous reset
    input wire                    sync_rst_i,                                     //synchronous reset

    //Program bus (wishbone)
    input  wire [15:0]            pbus_dat_i,                                     //read data bus

    //Instruction decoder output
    output wire                   ir_eow_o,                                       //end of word
    output wire                   ir_jmp_o,                                       //jump instruction (any)
    output wire                   ir_jmp_ind_o,                                   //jump instruction (indirect addressing)
    output wire                   ir_jmp_dir_o,                                   //jump instruction (direct addressing)
    output wire                   ir_call_o,                                      //call instruction (any)
    output wire                   ir_call_ind_o,                                  //call instruction (indirect addressing)
    output wire                   ir_call_dir_o,                                  //call instruction (direct addressing)
    output wire                   ir_bra_o,                                       //branch instruction (any)
    output wire                   ir_bra_ind_o,                                   //branch instruction (indirect addressing)
    output wire                   ir_bra_dir_o,                                   //branch instruction (direct addressing)
    output wire                   ir_lit_o,                                       //literal instruction
    output wire                   ir_alu_o,                                       //ALU instruction (any)
    output wire                   ir_alu_x_x_o,                                   //ALU instruction (   x --   x )
    output wire                   ir_alu_xx_x_o,                                  //ALU instruction ( x x --   x )
    output wire                   ir_alu_x_xx_o,                                  //ALU instruction (   x -- x x )
    output wire                   ir_alu_xx_xx_o,                                 //ALU instruction ( x x -- x x )
    output wire                   ir_sop_o,                                       //stack operation
    output wire                   ir_fetch_o,                                     //memory read (any)
    output wire                   ir_fetch_ind_o,                                 //memory read (indirect addressing)
    output wire                   ir_fetch_dir_o,                                 //memory read (direct addressing)
    output wire                   ir_store_o,                                     //memory write (any)
    output wire                   ir_store_ind_o,                                 //memory write (indirect addressing)
    output wire                   ir_store_dir_o,                                 //memory write (direct addressing)
    output wire                   ir_ctrl_o,                                      //Control instruction (any)
    output wire                   ir_ctrl_ps_rst_o,                               //control instruction (reset parameter stack)
    output wire                   ir_ctrl_rs_rst_o,                               //control instruction (reset return stack)
    output wire                   ir_ctrl_irqen_we_o,                             //control instruction (change interrupt mask)
    output wire                   ir_ctrl_irqen_val_o,                            //control instruction (new interrupt mask value)
    output wire [13:0]            ir_dir_abs_adr_o,                               //direct absolute COF address
    output wire [12:0]            ir_dir_rel_adr_o,                               //direct relative COF address
    output wire [11:0]            ir_lit_val_o,                                   //literal value
    output wire [4:0]             ir_opr_o,                                       //ALU operator
    output wire [4:0]             ir_imm_op_o,                                    //immediate operand
    output wire [9:0]             ir_stp_o,                                       //stack transition pattern
    output wire [7:0]             ir_dir_mem_adr_o,                               //direct absolute data address
    output wire                   ir_sel_dir_abs_adr_o,                           //silect direct absolute address
    output wire                   ir_sel_dir_rel_adr_o,                           //select direct relative address
    output wire                   ir_sel_dir_mem_adr_o,                           //select direct data address
    output wire                   ir_sel_imm_op_o,                                //select immediate operand

    //Flow control interface
    input  wire                   fc_ir_capture_i,                                //capture current IR
    input  wire                   fc_ir_hoard_i,                                  //capture hoarded IR
    input  wire                   fc_ir_expend_i,                                 //hoarded IR -> current IR

    //Probe signals
    output wire [15:0]            prb_ir_cur_o,                                   //current instruction register
    output wire [15:0]            prb_ir_hoard_o);                                //hoarded instruction register

   //Internal signals
   //----------------
   //Instruction registers
   reg  [15:0]                    ir_cur_reg;                                     //current instruction register
   reg  [15:0]                    ir_hoard_reg;                                   //hoarded instruction register

   //Flip flops
   //----------
   //Current instruction register
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                          //asynchronous reset
          ir_cur_reg  <= {16{1'b0}};
        else if (sync_rst_i)                                                      //synchronous reset
          ir_cur_reg  <= {16{1'b0}};
        else if (fc_ir_capture_i | fc_ir_expend_i)                                //update IR
          ir_cur_reg  <= (({16{fc_ir_capture_i}} &  pbus_dat_i) |
                          ({16{fc_ir_expend_i}}  &  ir_hoard_reg));
      end // always @ (posedge async_rst_i or posedge clk_i)

   //Hoarded instruction register
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                          //asynchronous reset
          ir_hoard_reg  <= {16{1'b0}};
        else if (sync_rst_i)                                                      //synchronous reset
          ir_hoard_reg  <= {16{1'b0}};
        else if (fc_ir_hoard_i)                                                   //capture opcode
          ir_hoard_reg  <= pbus_dat_i;
      end // always @ (posedge async_rst_i or posedge clk_i)

   //Instruction decoder
   //-------------------
   assign ir_eow_o              = ~|(2'b10 ^ ir_cur_reg[15:14]);                  //end of word

   assign ir_jmp_o              = ~|(2'b11 ^ ir_cur_reg[15:14]);                  //jump instruction (any)
   assign ir_jmp_ind_o          = ir_jmp_o & ~ir_sel_dir_abs_adr_o;               //jump instruction (indirect addressing)
   assign ir_jmp_dir_o          = ir_jmp_o &  ir_sel_dir_abs_adr_o;               //jump instruction (direct addressing)

   assign ir_call_o             = ~|(2'b01 ^ ir_cur_reg[15:14]);                  //call instruction (any)
   assign ir_call_ind_o         = ir_call_o & ~ir_sel_dir_abs_adr_o;              //call instruction (indirect addressing)
   assign ir_call_dir_o         = ir_call_o &  ir_sel_dir_abs_adr_o;              //call instruction (direct addressing)

   assign ir_bra_o              = ~|(2'b01 ^ ir_cur_reg[14:13]);                  //branch instruction (any)
   assign ir_bra_ind_o          = ir_call_o & ~ir_sel_dir_rel_adr_o;              //branch instruction (indirect addressing)
   assign ir_bra_dir_o          = ir_call_o &  ir_sel_dir_rel_adr_o;              //branch instruction (direct addressing)

   assign ir_lit_o              = ~|(3'b001 ^ ir_cur_reg[14:12]);                 //literal instruction

   assign ir_alu_o              = ~|(4'b0001 ^ ir_cur_reg[14:11]);                //ALU instruction (any)
   assign ir_alu_x_x_o          = ir_alu_o &  ir_cur_reg[10] &  ir_sel_imm_op_o;  //ALU instruction (   x --   x )
   assign ir_alu_xx_x_o         = ir_alu_o &  ir_cur_reg[10] & ~ir_sel_imm_op_o;  //ALU instruction ( x x --   x )
   assign ir_alu_x_xx_o         = ir_alu_o & ~ir_cur_reg[10] &  ir_sel_imm_op_o;  //ALU instruction (   x -- x x )
   assign ir_alu_xx_xx_o        = ir_alu_o & ~ir_cur_reg[10] & ~ir_sel_imm_op_o;  //ALU instruction ( x x -- x x )

   assign ir_sop_o              = ~|(5'b00001 ^ ir_cur_reg[14:10]);               //stack operation

   assign ir_fetch_o            = ~|(7'b0000011 ^ ir_cur_reg[14:8]);              //memory read (any)
   assign ir_fetch_ind_o        = ir_fetch_o & ~ir_sel_dir_mem_adr_o;             //memory read (indirect addressing)
   assign ir_fetch_dir_o        = ir_fetch_o &  ir_sel_dir_mem_adr_o;             //memory read (direct addressing)

   assign ir_store_o            = ~|(7'b0000010 ^ ir_cur_reg[14:8]);              //memory write (any)
   assign ir_store_ind_o        = ir_store_o & ~ir_sel_dir_mem_adr_o;             //memory write (indirect addressing)
   assign ir_store_dir_o        = ir_store_o &  ir_sel_dir_mem_adr_o;             //memory write (direct addressing)

   assign ir_ctrl_o             = ~|(7'b0000001 ^ ir_cur_reg[14:8]);              //control instruction (any)
   assign ir_ctrl_ps_rst_o      = ir_ctrl_o & ir_cur_reg[2];                      //control instruction (reset parameter stack)
   assign ir_ctrl_rs_rst_o      = ir_ctrl_o & ir_cur_reg[3];                      //control instruction (reset return stack)
   assign ir_ctrl_irqen_we_o    = ir_ctrl_o & ir_cur_reg[1];                      //control instruction (change interrupt mask)
   assign ir_ctrl_irqen_val_o   =             ir_cur_reg[0];                      //control instruction (new interrupt mask value)

   assign ir_dir_abs_adr_o      = ir_cur_reg[13:0];                               //direct absolute COF address
   assign ir_dir_rel_adr_o      = ir_cur_reg[12:0];                               //direct relative COF address
   assign ir_lit_val_o          = ir_cur_reg[11:0];                               //literal value
   assign ir_opr_o              = ir_cur_reg[9:5];                                //ALU operator
   assign ir_imm_op_o           = ir_cur_reg[4:0];                                //immediate operand
   assign ir_stp_o              = ir_cur_reg[9:0];                                //stack transition pattern
   assign ir_dir_mem_adr_o      = ir_cur_reg[7:0];                                //direct absolute data address

   assign ir_sel_dir_abs_adr_o  = ~&ir_dir_abs_adr_o;                             //silect direct absolute address
   assign ir_sel_dir_rel_adr_o  = ~&ir_dir_rel_adr_o;                             //select direct relative address
   assign ir_sel_dir_mem_adr_o  = ~&ir_dir_mem_adr_o;                             //select direct data address
   assign ir_sel_imm_op_o       = |ir_imm_op_o;                                   //select immediate operand

   //Probe signals
   //-------------
   assign prb_ir_cur_o          = ir_cur_reg;                                     //current instruction register
   assign prb_ir_hoard_o        = ir_hoard_reg;                                   //hoarded instruction register

endmodule // N1_ir
