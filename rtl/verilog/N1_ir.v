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
  #(parameter PBUS_DADR_OFFSET = 16'h0000,                                           //offset for direct program address
    parameter PBUS_MADR_OFFSET = 16'h0000)                                           //offset for direct memory address
   (//Clock and reset								     
    input wire                    clk_i,                                             //module clock
    input wire                    async_rst_i,                                       //asynchronous reset
    input wire                    sync_rst_i,                                        //synchronous reset
										     
    //Program bus (wishbone)							     
    output wire                   pbus_tga_cof_jmp_o,                                //COF jump              
    output wire                   pbus_tga_cof_call_o,                               //COF call              
    output wire                   pbus_tga_cof_bra_o,                                //COF conditional branch
    output wire                   pbus_tga_cof_ret_o,                                //COF return from call  
    output wire                   pbus_tga_dat_o,                                    //data access           
    output wire                   pbus_we_o,                                         //write enable             
    input  wire [15:0]            pbus_dat_i,                                        //read data bus

    //Internal interfaces
    //-------------------
    //ALU interface
    output wire [4:0]             ir2alu_opr_o,                                      //ALU operator
    output wire [4:0]             ir2alu_imm_op_o,                                   //immediate operand
    output wire                   ir2alu_imm_op_sel_o,                               //select immediate operand
										     
    //Flow control interface							     
    input  wire                   fc2ir_capture_i,                                   //capture current IR
    input  wire                   fc2ir_stash_i,                                     //capture stashed IR
    input  wire                   fc2ir_expend_i,                                    //stashed IR -> current IR
    input  wire                   fc2ir_force_eow_i,                                 //load EOW bit
    input  wire                   fc2ir_force_nop_i,                                 //load NOP instruction
    input  wire                   fc2ir_force_0call_i,                               //load 0 CALL instruction
    input  wire                   fc2ir_force_call_i,                                //load CALL instruction
    input  wire                   fc2ir_force_drop_i,                                //load DROP instruction
    input  wire                   fc2ir_force_fetch_i,                               //load FETCH instruction
    output wire                   ir2fc_bra_o,                                       //conditional branch
    output wire                   ir2fc_eow_o,                                       //end of word (EOW bit set)
    output wire                   ir2fc_eow_postpone_o,                              //EOW conflict detected
    output wire                   ir2fc_jmp_or_call_o,                               //jump or call instruction
    output wire                   ir2fc_mem_o,                                       //memory I/O
    output wire                   ir2fc_memrd_o,                                     //mreory read
    output wire                   ir2fc_scyc_o,                                      //single cycle instruction

    //Program bus AGU
    output wire [15:0]            ir2pagu_pagu_dadr_o,                               //direct absolute address              
    output wire [15:0]            ir2pagu_pagu_radr_o,                               //direct relative address             
    output wire [15:0]            ir2pagu_pagu_madr_o,                               //direct memory address              
    output wire                   ir2pagu_pagu_dadr_sel_o,                           //select direct absolute address              
    output wire                   ir2pagu_pagu_madr_sel_o,                           //select direct memory address              
										     
    //Parameter and return stack						     										     
    output wire [15:0]            ir2prs_lit_val_o,                                  //literal value
    output wire [7:0]             ir2prs_ups_tp_o,                                   //upper stack transition pattern
    output wire [1:0]             ir2prs_ips_tp_o,                                   //intermediate parameter stack transition pattern
    output wire [1:0]             ir2prs_irs_tp_o,                                   //intermediate return stack transition pattern
    output wire                   ir2prs_alu2ps0_o,                                  //ALU output -> PS0
    output wire                   ir2prs_alu2ps1_o,				     //ALU output -> PS1
    output wire                   ir2prs_dat2ps0_o,				     //read data  -> PS0
    output wire                   ir2prs_lit2ps0_o,				     //literal    -> PS0
    output wire                   ir2prs_pc2ps0_o,                                   //next PC    -> RS0       
    output wire                   ir2prs_ps_rst_o,                                   //reset parameter stack      
    output wire                   ir2prs_rs_rst_o,                                   //reset return stack   
    output wire                   ir2prs_psp_rd_o,                                   //read parameter stack pointer     
    output wire                   ir2prs_psp_wr_o,                                   //write parameter stack pointer     
    output wire                   ir2prs_rsp_rd_o,                                   //read return stack pointer     
    output wire                   ir2prs_rsp_wr_o,                                   //write return stack pointer     

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
   //Common decoder signals							     
   wire                           jmp_or_call;                                       //jump or call instruction
   wire                           pagu_indadr_sel;                                   //select direct absolute address              
   wire                           bra;                                               //conditional branch
   wire                           lit;                                               //literal
   wire                           alu_single;                                        //ALU with single cell result
   wire                           alu_double;                                        //ALU with double cell result
   wire                           imm_op_sel;                                        //select immediate operand
   wire                           stack_instr;                                       //stack instructions
   wire                           mem_instr;                                         //memory I/O instruction
   wire                           memrd;                                             //memory read
   wire                           madr_sel;                                          //select direct memory address              
   										     
   //Opcodes									     
   //-------									     
   localparam OPC_EOW   = 16'h8000;                                                  //EOW bit
   localparam OPC_0CALL = 16'h;							     //CALL to address 0
   localparam OPC_0JMP  = OPC_EOW | OPC_0CALL;					     //JUMP to address 0
   localparam OPC_CALL  = 16'h;							     //indirect CALL
   localparam OPC_DROP  = 16'h;							     //drop PS0
   localparam OPC_FETCH = 16'h;							     //fetch data from Dbus
   localparam OPC_NOP   = 16'h;                                                      //no operation 
   										     
   //Instruction register							     
   //--------------------							     
   assign ir_next = ({16{fc2ir_capture_i}}     & pbus_dat_i)   |                     //capture current IR
                    ({16{fc2ir_expend_i}}      & ir_stash_reg) |                     //stashed IR -> current IR
                    ({16{fc2ir_force_eow_i}}   & OPC_EOW)      |                     //load EOW bit
                    ({16{fc2ir_force_0call_i}} & OPC_0CALL)    |                     //load 0 CALL instruction
                    ({16{fc2ir_force_call_i}}  & OPC_CALL)     |                     //load CALL instruction
                    ({16{fc2ir_force_drop_i}}  & OPC_DROP)     |                     //load DROP instruction
                    ({16{fc2ir_force_fetch_i}} & OPC_FETCH)    |                     //load FETCH instruction
                    ({16{fc2ir_force_nop_i}}   & OPC_NOP);                           //load NOP instruction
   
   assign ir_we   = fc2ir_capture_i     |                                            //capture current IR
                    fc2ir_expend_i      |                                            //stashed IR -> current IR
                  //fc2ir_force_eow_i   |                                            //load EOW bit
                    fc2ir_force_0call_i |                                            //load 0 CALL instruction
                    fc2ir_force_call_i  |                                            //load CALL instruction
                    fc2ir_force_drop_i  |                                            //load DROP instruction
                    fc2ir_force_fetch_i |                                            //load FETCH instruction
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
   //Common decoder signals							     
   assign jmp_or_call             =     ir_reg[14];                                  //jump or call instruction
   assign pagu_indadr_sel         =    &ir_reg[13:0];                                //select direct absolute address              
   assign bra  	                  =  ~|{ir_reg[14:13] ^ 2'b01};                      //conditional branch
   assign lit  	                  =  ~|{ir_reg[14:12] ^ 3'b001};                     //literal
   assign alu_single  	          =  ~|{ir_reg[14:10] ^ 5'b00011};                   //ALU with single cell result
   assign alu_double  	          =  ~|{ir_reg[14:10] ^ 5'b00010};                   //ALU with double cell result
   assign imm_op_sel              =    |ir_reg[4:0];                                 //select immediate operand
   assign stack_instr             =  ~|{ir_reg[14:10] ^ 5'b00001};                   //stack instructions
   assign mem_instr	          =  ~|{ir_reg[14:9] ^ 6'b000001};                   //memory I/O instruction
   assign memrd  	          =     ir_reg[8];                                   //memory read
   assign madr_sel                =   ~&ir_reg[7:0];                                 //select direct memory address              
										     
   //Program bus
   assign pbus_tga_cof_jmp_o      = ~|{ir_reg[15:14] ^ 2'b11};                       //COF jump              
   assign pbus_tga_cof_call_o     = ~|{ir_reg[15:14] ^ 2'b01};                       //COF call              
   assign pbus_tga_cof_bra_o      = ~|{ir_reg[15:13] ^ 3'b001};;                     //COF conditional branch
   assign pbus_tga_cof_ret_o      = ~|{ir_reg[15:14] ^ 2'b10};                       //COF return from call  
   assign pbus_tga_dat_o          = ~|{ir_reg[14:9]  ^ 6'b000001};                   //data access           
   assign pbus_we_o	          = ~|{ir_reg[14:8]  ^ 7'b0000010};                  //write enable             
			          
   //ALU		          
   assign ir2alu_opr_o	          =   ir_reg[9:5];                                   //ALU operator
   assign ir2alu_imm_op_o         =   ir_reg[4:0];                                   //immediate operand
   assign ir2alu_imm_op_sel_o     = imm_op_sel;                                      //select immediate operand
			          
   //FC			          
   assign ir2fc_eow_o	          =     ir_reg[15];                                  //end of word (EOW bit set)
   assign ir2fc_eow_postpone_o    = (~|(ir_reg[14:10] ^ 5'b00001) & |ir_reg[2:0]) |  //stack instruction
			            (~|(ir_reg[14:8]  ^ 7'b0000001) &  ir_reg[5]) |  //return stack reset
			            (~|(ir_reg[14:0]  ^ 15'b0000000_00001011)     |  //set return stack pounter
			            (~|(ir_reg[14:0]  ^ 15'b0000000_00001010));      //determine return srack pointer
   assign ir2fc_bra_o	          = bra;                                             //conditional branch
   assign ir2fc_jmp_or_call_o     = jmp_or_call;                                     //jump or call instruction
   assign ir2fc_mem_o	          = mem_instr ;                                      //memory I/O
   assign ir2fc_memrd_o	          = memrd;                                           //memory read
   assign ir2fc_scyc_o	          =  ~|{ir_reg[14:13] ^ 2'b00} &                     //single cycle instruction
			              |{ir_reg[12:9] ^ 4'b0001};                     //

   //PAGU
   assign ir2pagu_pagu_dadr_o	  = {PBUS_DADR_OFFSET[15:14], ir_reg[13:0]};         //direct absolute address              
   assign ir2pagu_pagu_radr_o	  = {{2{ir_reg[12]}}, ir_reg[12:0]};                 //direct relative address             
   assign ir2pagu_pagu_madr_o	  = {PBUS_MADR_OFFSET[15:8], ir_reg[7:0]};           //direct memory address              
   assign ir2pagu_pagu_dadr_sel_o = ~pagu_indadr_sel&;                               //select direct absolute address              
   assign ir2pagu_pagu_madr_sel_o = madr_sel;                                        //select direct memory address              
   
   //PRS
   assign ir2prs_lit_val_o        = {{4{ir_reg[11]}}, ir_reg[11:0]};                 //literal value
   assign ir2prs_ups_tp_o         = ;                                                //upper stack transition pattern
   assign ir2prs_ips_tp_o         = ;                                   //push=10, pull=01
   assign ir2prs_irs_tp_o         = ;                                   //push=01, pull=10
   assign ir2prs_alu2ps0_o	  = ;                                  //ALU output -> PS0
   assign ir2prs_alu2ps1_o	  = ;				     //ALU output -> PS1
   assign ir2prs_dat2ps0_o	  = ;				     //read data  -> PS0
   assign ir2prs_lit2ps0_o	  = ;				     //literal    -> PS0
   assign ir2prs_pc2ps0_o	  = ;                                   //next PC    -> RS0       
   assign ir2prs_ps_rst_o	  = ;                                   //reset parameter stack      
   assign ir2prs_rs_rst_o	  = ;                                   //reset return stack   
   assign ir2prs_psp_rd_o         = ;                                 //read parameter stack pointer     
   assign ir2prs_psp_wr_o         = ;                                 //write parameter stack pointer     
   assign ir2prs_rsp_rd_o         = ;                                 //read return stack pointer     
   assign ir2prs_rsp_wr_o         = ;                                 //write return stack pointer     
   
   //Probe signals
   //-------------
   assign prb_ir_cur_o          = ir_cur_reg;                                        //current instruction register
   assign prb_ir_stash_o        = ir_stash_reg;                                      //stashed instruction register

endmodule // N1_ir
