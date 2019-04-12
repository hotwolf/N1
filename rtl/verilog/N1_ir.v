//###############################################################################
//# N1 - Instruction Register                                                   #
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
    input wire                    clk_i,                                             //module clock
    input wire                    async_rst_i,                                       //asynchronous reset
    input wire                    sync_rst_i,                                        //synchronous reset

    //Program bus (wishbone)
    output wire                   pbus_tga_cof_jmp_o,                                //COF jump
    output wire                   pbus_tga_cof_cal_o,                                //COF call
    output wire                   pbus_tga_cof_bra_o,                                //COF conditional branch
    output wire                   pbus_tga_cof_eow_o,                                //COF return from call
    output wire                   pbus_tga_dat_o,                                    //data access
    output wire                   pbus_we_o,                                         //write enable
    input  wire [15:0]            pbus_dat_i,                                        //read data bus

    //Internal interfaces
    //-------------------
    //ALU interface
    output wire [4:0]             ir2alu_opr_o,                                      //ALU operator
    output wire [4:0]             ir2alu_opd_o,                                      //immediate operand
    output wire                   ir2alu_opd_sel_o,                                  //select immediate operand

    //EXCPT interface
    output wire                   ir2excpt_excpt_en_o,                               //enable exceptions
    output wire                   ir2excpt_excpt_dis_o,                              //disable exceptions
    output wire                   ir2excpt_irq_en_o,                                 //enable interrupts
    output wire                   ir2excpt_irq_dis_o,                                //disable interrupts

    //FC interface
    output wire                   ir2fc_eow_o,                                       //end of word (EOW bit set)
    output wire                   ir2fc_eow_postpone_o,                              //EOW conflict detected
    output wire                   ir2fc_jump_or_call_o,                              //either JUMP or CALL
    output wire                   ir2fc_bra_o,                                       //conditonal BRANCG instruction
    output wire                   ir2fc_scyc_o,                                      //linear flow
    output wire                   ir2fc_mem_o,                                       //memory I/O
    output wire                   ir2fc_mem_rd_o,                                    //memory read
    output wire                   ir2fc_madr_sel_o,                                  //select (indirect) data address
    input  wire                   fc2ir_capture_i,                                   //capture current IR
    input  wire                   fc2ir_stash_i,                                     //capture stashed IR
    input  wire                   fc2ir_expend_i,                                    //stashed IR -> current IR
    input  wire                   fc2ir_force_eow_i,                                 //load EOW bit
    input  wire                   fc2ir_force_0call_i,                               //load 0 CALL instruction
    input  wire                   fc2ir_force_call_i,                                //load CALL instruction
    input  wire                   fc2ir_force_drop_i,                                //load DROP instruction
    input  wire                   fc2ir_force_nop_i,                                 //load NOP instruction

    //PAGU interface
    output wire                   ir2pagu_eow_o,                                     //end of word (EOW bit)
    output wire                   ir2pagu_eow_postpone_o,                            //postpone EOW
    output wire                   ir2pagu_jmp_or_cal_o,                              //jump or call instruction
    output wire                   ir2pagu_bra_o,                                     //conditional branch
    output wire                   ir2pagu_scyc_o,                                    //single cycle instruction
    output wire                   ir2pagu_mem_o,                                     //memory I/O
    output wire                   ir2pagu_aadr_sel_o,                                //select (indirect) absolute address
    output wire                   ir2pagu_madr_sel_o,                                //select (indirect) memory address
    output wire [13:0]            ir2pagu_aadr_o,                                    //direct absolute address
    output wire [12:0]            ir2pagu_radr_o,                                    //direct relative address
    output wire [7:0]             ir2pagu_madr_o,                                    //direct memory address

    //PRS interface
    output wire                   ir2prs_alu2ps0_o,                                  //ALU output  -> PS0
    output wire                   ir2prs_alu2ps1_o,                                  //ALU output  -> PS1
    output wire                   ir2prs_lit2ps0_o,                                  //literal     -> PS0
    output wire                   ir2prs_pc2rs0_o,                                   //PC          -> RS0
    output wire                   ir2prs_ps_rst_o,                                   //reset parameter stack
    output wire                   ir2prs_rs_rst_o,                                   //reset return stack
    output wire                   ir2prs_psp_get_o,                                  //read parameter stack pointer
    output wire                   ir2prs_psp_set_o,                                  //write parameter stack pointer
    output wire                   ir2prs_rsp_get_o,                                  //read return stack pointer
    output wire                   ir2prs_rsp_set_o,                                  //write return stack pointer
    output wire [15:0]            ir2prs_lit_val_o,                                  //literal value
    output wire [7:0]             ir2prs_us_tp_o,                                    //upper stack transition pattern
    output wire [1:0]             ir2prs_ips_tp_o,                                   //10:push, 01:pull
    output wire [1:0]             ir2prs_irs_tp_o,                                   //10:push, 01:pull

    //Probe signals
    output wire [15:0]            prb_ir_o,                                          //current instruction register
    output wire [15:0]            prb_ir_stash_o);                                   //stashed instruction register

   //Internal signals
   //----------------
   //Instruction register
   reg  [15:0]                    ir_reg;                                            //current instruction register
   wire [15:0]                    ir_next;                                           //next instruction register
   wire                           ir_we;                                             //write enable
   //Stashed nstruction register
   reg  [15:0]                    ir_stash_reg;                                      //current instruction register
   //Instruction types
   wire                           instr_eow;                                         //end of word
   wire                           instr_jump;                                        //JUMP instruction
   wire                           instr_call;                                        //CALL instruction
   wire                           instr_jump_or_call;                                //either JUMP or CALL
   wire                           instr_bra;                                         //conditonal BRANCG instruction
   wire                           instr_lit;                                         //LITERAL instruction
   wire                           instr_alu;                                         //ALU instruction
   wire                           instr_alu_1cell;                                   //ALU instruction with single cell result
   wire                           instr_alu_2cell;                                   //ALU instruction with double cell result
   wire                           instr_stack;                                       //stack instruction
   wire                           instr_mem;                                         //memory I/O
   wire                           instr_mem_rd;                                      //memory read
   wire                           instr_mem_wr;                                      //memory wrute
   wire                           instr_ctrl;                                        //any control instruction
   wire                           instr_ctrl_conc;                                   //concurrent control instruction
   wire                           instr_ctrl_psp;                                    //sequential control instruction (PSP operation)
   wire                           instr_ctrl_psp_get;                                //sequential control instruction (PSP read)
   wire                           instr_ctrl_psp_set;                                //sequential control instruction (PSP write)
   wire                           instr_ctrl_rsp;                                    //sequential control instruction (RSP operation)
   wire                           instr_ctrl_rsp_get;                                //sequential control instruction (RSP read)
   wire                           instr_ctrl_rsp_set;                                //sequential control instruction (RSP WRITE)
   wire                           instr_scyc;                                        //single cycle instruction
   //Embedded arguments
   wire [13:0]                    arg_aadr;                                          //absolute address
   wire [12:0]                    arg_radr;                                          //relative address
   wire [11:0]                    arg_lit;                                           //literal value
   wire [4:0]                     arg_opr;                                           //ALU operator
   wire [4:0]                     arg_opd;                                           //ALU operand
   wire [9:0]                     arg_stp;                                           //stack transition pattern
   wire [7:0]                     arg_madr;                                          //memory address
   wire [7:0]                     arg_act;                                           //concurrent control action
   //Indirect argument selection
   wire                           aadr_sel;                                          //use absolute address from TOS
   wire                           opd_sel;                                           //use ALU operand from TOS
   wire                           madr_sel;                                          //use memory address from TOS
   //Concurrent actions
   wire                           act_irq_en;                                        //enable interrupts
   wire                           act_irq_dis;                                       //disable interrupts
   wire                           act_excpt_en;                                      //enable exceptions
   wire                           act_excpt_dis;                                     //disable exceptions
   wire                           act_ps_rst;                                        //reset parameter stack
   wire                           act_rs_rst;                                        //reset return stack
   //End of word
   wire                           eow_postpone;                                      //postpone execution of EOW

   //Opcodes
   //-------
   localparam OPC_EOW   = 16'h8000;                                                  //EOW bit
   localparam OPC_0CALL = 16'h4000;                                                  //CALL to address 0
   localparam OPC_0JMP  = OPC_EOW | OPC_0CALL;                                       //JUMP to address 0
   localparam OPC_CALL  = 16'h7FFF;                                                  //indirect CALL
   localparam OPC_DROP  = 16'h06A0;                                                  //drop PS0
   localparam OPC_NOP   = 16'h0400;                                                  //no operation

   //Instruction register
   //--------------------
   assign ir_next = ({16{fc2ir_capture_i}}     & pbus_dat_i)   |                     //capture current IR
                    ({16{fc2ir_expend_i}}      & ir_stash_reg) |                     //stashed IR -> current IR
                    ({16{fc2ir_force_eow_i}}   & OPC_EOW)      |                     //load EOW bit
                    ({16{fc2ir_force_0call_i}} & OPC_0CALL)    |                     //load 0 CALL instruction
                    ({16{fc2ir_force_call_i}}  & OPC_CALL)     |                     //load CALL instruction
                    ({16{fc2ir_force_drop_i}}  & OPC_DROP)     |                     //load DROP instruction
                    ({16{fc2ir_force_nop_i}}   & OPC_NOP);                           //load NOP instruction

   assign ir_we   = fc2ir_capture_i     |                                            //capture current IR
                    fc2ir_expend_i      |                                            //stashed IR -> current IR
                  //fc2ir_force_eow_i   |                                            //load EOW bit
                    fc2ir_force_0call_i |                                            //load 0 CALL instruction
                    fc2ir_force_call_i  |                                            //load CALL instruction
                    fc2ir_force_drop_i  |                                            //load DROP instruction
                    fc2ir_force_nop_i;                                               //load NOP instruction

   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                             //asynchronous reset
          ir_reg  <= OPC_0JMP;
        else if (sync_rst_i)                                                         //synchronous reset
          ir_reg  <= OPC_0JMP;
        else if (ir_we)                                                              //update IR
          ir_reg  <= ir_next;
      end // always @ (posedge async_rst_i or posedge clk_i)

   //Stashed instruction register
   //----------------------------
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                             //asynchronous reset
          ir_stash_reg  <= 16'h0000;
        else if (sync_rst_i)                                                         //synchronous reset
          ir_stash_reg  <= 16'h0000;
        else if (fc2ir_stash_i)                                                      //update stashed IR
          ir_stash_reg  <= pbus_dat_i;
      end // always @ (posedge async_rst_i or posedge clk_i)

   //Instruction decoder
   //-------------------
   //Instruction types
   assign instr_eow                =    ir_reg[15];                                  //end of word
   assign instr_jump               = ~|{ir_reg[15:14] ^ 2'b11};                      //JUMP instruction
   assign instr_call               = ~|{ir_reg[15:14] ^ 2'b01};                      //CALL instruction
   assign instr_jump_or_call       =    ir_reg[14];                                  //either JUMP or CALL
   assign instr_bra                = ~|{ir_reg[14:13] ^  2'b01};                     //conditonal BRANCG instruction
   assign instr_lit                = ~|{ir_reg[14:12] ^  3'b001};                    //LITERAL instruction
   assign instr_alu                = ~|{ir_reg[14:11] ^  4'b0001};                   //ALU instruction
   assign instr_alu_1cell          = ~|{ir_reg[14:10] ^  5'b00011};                  //ALU instruction with single cell result
   assign instr_alu_2cell          = ~|{ir_reg[14:10] ^  5'b00010};                  //ALU instruction with double cell result
   assign instr_stack              = ~|{ir_reg[14:10] ^  5'b00001};                  //stack instruction
   assign instr_mem                = ~|{ir_reg[14:9]  ^  6'b000001};                 //memory I/O
   assign instr_mem_rd             = ~|{ir_reg[14:8]  ^  7'b0000011};                //memory read
   assign instr_mem_wr             = ~|{ir_reg[14:8]  ^  7'b0000010};                //memory wrute
   assign instr_ctrl               = ~|{ir_reg[14:9]  ^  6'b000000};                 //any control instruction
   assign instr_ctrl_conc          = ~|{ir_reg[14:8]  ^  7'b0000001};                //concurrent control instruction
   assign instr_ctrl_psp           =  ~|ir_reg[14:8] &    ir_reg[1];                 //sequential control instruction (PSP operation)
   assign instr_ctrl_psp_get       =  ~|ir_reg[14:8] & ~|{ir_reg[1:0] ^ 2'b11};      //sequential control instruction (PSP read)
   assign instr_ctrl_psp_set       =  ~|ir_reg[14:8] & ~|{ir_reg[1:0] ^ 2'b10};      //sequential control instruction (PSP write)
   assign instr_ctrl_rsp           =  ~|ir_reg[14:8] &   ~ir_reg[1];                 //sequential control instruction (RSP operation)
   assign instr_ctrl_rsp_get       =  ~|ir_reg[14:8] & ~|{ir_reg[1:0] ^ 2'b01};      //sequential control instruction (RSP read)
   assign instr_ctrl_rsp_set       =  ~|ir_reg[14:8] & ~|{ir_reg[1:0] ^ 2'b00};      //sequential control instruction (RSP WRITE)
   assign instr_scyc               =  ~instr_jump_or_call &                          //no JUMP or CALL
                                      ~instr_bra &                                   //no BRANCH
                                      ~instr_mem;                                    //no memory I/O
   //Single cycle instruction
   //Embedded arguments
   assign arg_aadr                 = ir_reg[13:0];                                   //absolute address
   assign arg_radr                 = ir_reg[12:0];                                   //relative address
   assign arg_lit                  = ir_reg[11:0];                                   //literal value
   assign arg_opr                  = ir_reg[9:5];                                    //ALU operator
   assign arg_opd                  = ir_reg[4:0];                                    //ALU operand
   assign arg_stp                  = ir_reg[9:0];                                    //stack transition pattern
   assign arg_madr                 = ir_reg[7:0];                                    //memory address
   assign arg_act                  = ir_reg[7:0];                                    //concurrent control action
   //Indirect argument selection
   assign aadr_sel                 = &arg_aadr;                                      //use absolute address from TOS
   assign opd_sel                  = ~|arg_opd;                                      //use ALU operand from TOS
   assign madr_sel                 = &arg_madr;                                      //use memory address from TOS
   //Concurrent actions
   assign act_irq_en               = ir_reg[0];                                      //enable interrupts
   assign act_irq_dis              = ir_reg[1];                                      //disable interrupts
   assign act_excpt_en             = ir_reg[2];                                      //enable exceptions
   assign act_excpt_dis            = ir_reg[3];                                      //disable exceptions
   assign act_ps_rst               = ir_reg[4];                                      //reset parameter stack
   assign act_rs_rst               = ir_reg[5];                                      //reset return stack
   //End of word
   assign eow_postpone             = (instr_stack & |ir_reg[2:0]) |                  //postpone execution of EOW
                                     (instr_ctrl & act_rs_rst)    |                  //
                                      instr_ctrl_rsp;                                //

   //Program bus
   assign pbus_tga_cof_jmp_o      = instr_jump;                                      //COF jump
   assign pbus_tga_cof_cal_o      = instr_call;                                      //COF call
   assign pbus_tga_cof_bra_o      = instr_bra;                                       //COF conditional branch
   assign pbus_tga_cof_eow_o      = instr_eow & ~instr_jump_or_call & ~eow_postpone; //COF return from call
   assign pbus_tga_dat_o          = instr_mem;                                       //data access
   assign pbus_we_o               = instr_mem_wr;                                    //write enable

   //ALU
   assign ir2alu_opr_o            = arg_opr;                                         //ALU operator
   assign ir2alu_opd_o            = arg_opd;                                         //immediate operand
   assign ir2alu_opd_sel_o        = opd_sel;                                         //select immediate operand

   //EXCPT interface
   assign ir2excpt_excpt_en_o     = act_excpt_en;                                    //enable exceptions
   assign ir2excpt_excpt_dis_o    = act_excpt_dis;                                   //disable exceptions
   assign ir2excpt_irq_en_o       = act_irq_en;                                      //enable interrupts
   assign ir2excpt_irq_dis_o      = act_irq_dis;                                     //disable interrupts

   //FC
   assign ir2fc_eow_o             = instr_eow;                                       //end of word (EOW bit set)
   assign ir2fc_eow_postpone_o    = eow_postpone;                                    //postpone EOW execution
   assign ir2fc_jump_or_call_o    = instr_jump_or_call;                              //JUMP or CALL instruction
   assign ir2fc_bra_o             = instr_bra;                                       //conditional BRANCH
   assign ir2fc_scyc_o            = instr_scyc;                                      //single cycle instruction
   assign ir2fc_mem_o             = instr_mem;                                       //memory I/O
   assign ir2fc_mem_rd_o          = ir_reg[8];                                       //memory read
   assign ir2fc_madr_sel_o        = madr_sel;                                        //direct memory addressing

   //PAGU
   assign ir2pagu_eow_o           = instr_eow;                                       //end of word (EOW bit)
   assign ir2pagu_eow_postpone_o  = eow_postpone;                                    //postpone EOW
   assign ir2pagu_jmp_or_cal_o    = instr_jump_or_call;                              //jump or call instruction
   assign ir2pagu_bra_o           = instr_bra;                                       //conditional branch
   assign ir2pagu_scyc_o          = instr_scyc;                                      //single cycle instruction
   assign ir2pagu_mem_o           = instr_mem;                                       //memory I/O
   assign ir2pagu_aadr_sel_o      = aadr_sel;                                        //select direct absolute address
   assign ir2pagu_madr_sel_o      = madr_sel;                                        //select direct memory address
   assign ir2pagu_aadr_o          = arg_aadr;                                        //direct absolute address
   assign ir2pagu_radr_o          = arg_radr;                                        //direct relative address
   assign ir2pagu_madr_o          = arg_madr;                                        //direct memory address

   //PRS
   assign ir2prs_lit_val_o        = {{4{arg_lit[11]}}, arg_lit};                     //literal value
   assign ir2prs_us_tp_o          = (((instr_jump_or_call &  aadr_sel) |             //JUMP or CALL with indirect addressing
                                       instr_bra                       |             //single cell ALU instruction with stacked operands
                                      (instr_alu_1cell    &  opd_sel)  |             //single cell ALU instruction with stacked operands
                                      (instr_mem_wr       &  madr_sel)) ?            //write with indirect addressing
                                                              8'b01010100 : 8'h00) | //pull from PS
                                    (( instr_lit                       |             //literal
                                      (instr_alu_2cell    & ~opd_sel)) ?             //double cell ALU instruction with embedded operands
                                                              8'b10101000 : 8'h00) | //push to PS
                                    (  instr_stack ?         arg_stp[8:1] : 8'h00);  //STACK instruction
   assign ir2prs_ips_tp_o         = (((instr_jump_or_call &  aadr_sel) |             //JUMP or CALL with indirect addressing
                                       instr_bra                       |             //single cell ALU instruction with stacked operands
                                      (instr_alu_1cell    &  opd_sel)  |             //single cell ALU instruction with stacked operands
                                      (instr_mem_wr       &  madr_sel)) ?            //write with indirect addressing
                                                                    2'b01 : 2'b00) | //pull from PS
                                    (( instr_lit                       |             //literal
                                      (instr_alu_2cell    & ~opd_sel)) ?             //double cell ALU instruction with embedded operands
                                                                    2'b10 : 2'b00) | //push to PS
                                    ( instr_stack ?                                  //STACK instruction
                                               {arg_stp[9] &  arg_stp[8],            //stack transition pattern
                                                arg_stp[9] & ~arg_stp[8]} : 2'b00);  //
   assign ir2prs_irs_tp_o         = ((instr_eow & instr_scyc & ~eow_postpone) ?      //end of word
                                                                    2'b10 : 2'b00) | //pull from RS
                                    ( instr_call ?                                   //CALL instruction
                                                                    2'b01 : 2'b00) | //push to RS
                                    ( instr_stack ?                                  //STACK instruction
                                               {~arg_stp[1] & arg_stp[0],            //stack transition pattern
                                                 arg_stp[1] & arg_stp[0]} : 2'b00);  //
   assign ir2prs_alu2ps0_o        = instr_alu;                                       //ALU output  -> PS0
   assign ir2prs_alu2ps1_o        = instr_alu_2cell;                                 //ALU output  -> PS1
   assign ir2prs_lit2ps0_o        = instr_lit;                                       //literal     -> PS0
   assign ir2prs_pc2rs0_o         = instr_call;                                      //PC          -> RS0
   assign ir2prs_ps_rst_o         = instr_ctrl_conc & act_ps_rst;                    //reset parameter stack
   assign ir2prs_rs_rst_o         = instr_ctrl_conc & act_rs_rst;                    //reset return stack
   assign ir2prs_psp_get_o        = instr_ctrl_psp_get;                              //read parameter stack pointer
   assign ir2prs_psp_set_o        = instr_ctrl_psp_set;                              //write parameter stack pointer
   assign ir2prs_rsp_get_o        = instr_ctrl_rsp_get;                              //read return stack pointer
   assign ir2prs_rsp_set_o        = instr_ctrl_rsp_set;                              //write return stack pointer

   //Probe signals
   //-------------
   assign prb_ir_o                = ir_reg;                                          //current instruction register
   assign prb_ir_stash_o          = ir_stash_reg;                                    //stashed instruction register

endmodule // N1_ir
