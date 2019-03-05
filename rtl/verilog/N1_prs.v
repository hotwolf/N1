//###############################################################################
//# N1 - Parameter and Return Stack                                             #
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
//#    This module implements all levels of the parameter and the return stack. #
//#    These levels are:                                                        #
//#    - The upper stack, which provides direct access to the most cells and    #
//#      which is capable of performing stack operations.                       #
//#                                                                             #
//#  Imm.  |                  Upper Stack                   |    Upper   | Imm. #
//#  Stack |                                                |    Stack   | St.  #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#      |<->|  PS3  |<=>|  PS2  |<=>|  PS1  |<=>|  PS0  |<===>|  RS0  |<->|    #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#                                                 TOS     |     TOS           #
//#                          Parameter Stack                | Return Stack      #
//#                                                                             #
//#    - The intermediate stack serves as a buffer between the upper and the    #
//#      lower stack. It is designed to handle smaller fluctuations in stack    #
//#      content, minimizing accesses to the lower stack.                       #
//#                                                                             #
//#        Upper Stack           Intermediate Stack                             #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+---+                     #
//#       |   |   |   |<=>| 0 | 1 | 2 | 3 | 4 |   |n-1| n |                     #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+-+-+                     #
//#                         ^                           |                       #
//#                         |                           v     +----------+      #
//#                       +-+-----------------------------+   |   RAM    |      #
//#                       |        RAM Controller         |<=>| (Lower   |      #
//#                       +-------------------------------+   |   Stack) |      #
//#                                                           +----------+      #
//#                                                                             #
//#    - The lower stack resides in RAM to to implement a deep stack.           #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 13, 2018                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_prs
  #(parameter   SP_WIDTH        =      12,                                         //width of the stack pointer
    parameter   IPS_DEPTH       =       8,                                         //depth of the intermediate parameter stack
    parameter   IPS_DEPTH       =       8)                                         //depth of the intermediate return stack
								                   
   (//Clock and reset						                   
    input wire                               clk_i,                                //module clock
    input wire                               async_rst_i,                          //asynchronous reset
    input wire                               sync_rst_i,                           //synchronous reset
					     			                   
    //Program bus (wishbone)		     			                   
    input  wire [15:0]                       pbus_dat_o,                           //write data bus
    input  wire [15:0]                       pbus_dat_i,                           //read data bus
								                   
    //Stack bus (wishbone)					                   
    output wire                              sbus_cyc_o,                           //bus cycle indicator       +-
    output wire                              sbus_stb_o,                           //access request            |
    output wire                              sbus_we_o,                            //write enable              | initiator
    output wire [15:0]                       sbus_dat_o,                           //write data bus            | target
    input  wire                              sbus_ack_i,                           //bus cycle acknowledge     +-
    input  wire                              sbus_stall_i,                         //access delay              | initiator
    input  wire [15:0]                       sbus_dat_i,                           //read data bus             +-

    //Probe signals
 
    //Internal signals
    //----------------
    //ALU interface
    input  wire [15:0]                       alu2prs_ps0_next_i,                   //new PS0 (TOS)
    input  wire [15:0]                       alu2prs_ps1_next_i,                   //new PS1 (TOS+1)
    output wire [15:0]                       prs2alu_ps0_o,                        //current PS0 (TOS)
    output wire [15:0]                       prs2alu_ps1_o,                        //current PS1 (TOS+1)

     //DSP interface
    input  wire [15:0]                       dsp2prs_pc_i,                         //program counter
    input  wire [SP_WIDTH-1:0]               dsp2prs_psp_i,                        //parameter stack pointer (AGU output)
    input  wire [SP_WIDTH-1:0]               dsp2prs_rsp_i,                        //return stack pointer (AGU output)
								                   
    //EXCPT interface						                   
    output wire                              prs2excpt_psuf_o,                     //parameter stack underflow
    output wire                              prs2excpt_rsuf_o,                     //return stack underflow
    input  wire [15:0]                       excpt2prs_tc;                         //throw code
								                   
    //FC interface						                   
    output wire                              prs2fc_hold_o,                        //stacks not ready
    output wire                              prs2fc_ps0_true_o,                    //PS0 in non-zero	
    input  wire                              fc2prs_hold_i,                        //hold any state tran
    input  wire                              fc2prs_dat2ps0_i,                     //capture read data
  								                   
    //IR interface						                   
    input  wire [15:0]                       ir2prs_lit_val_i,                     //literal value
    input  wire [7:0]                        ir2prs_ups_tp_i,                      //upper stack transition pattern
    input  wire [1:0]                        ir2prs_ips_tp_i,                      //intermediate parameter stack transition pattern
    input  wire [1:0]                        ir2prs_irs_tp_i,                      //intermediate return stack transition pattern
    input  wire                              ir2prs_alu2ps0_i,                     //ALU output  -> PS0
    input  wire                              ir2prs_alu2ps1_i,                     //ALU output  -> PS1
    input  wire                              ir2prs_dat2ps0_i,                     //read data   -> PS0
    input  wire                              ir2prs_lit2ps0_i,                     //literal     -> PS0
    input  wire                              ir2prs_isr2ps0_i,                     //ISR address -> PS0
    input  wire                              ir2prs_tc2ps0_i,                      //throw code  -> PS0
    input  wire                              ir2prs_pc2rs0_i,                      //PC          -> RS0
    input  wire                              ir2prs_ps_rst_i,                      //reset parameter stack
    input  wire                              ir2prs_rs_rst_i,                      //reset return stack
    input  wire                              ir2prs_psp_rd_i,                      //read parameter stack pointer
    input  wire                              ir2prs_psp_wr_i,                      //write parameter stack pointer
    input  wire                              ir2prs_rsp_rd_i,                      //read return stack pointer
    input  wire                              ir2prs_rsp_wr_i);                     //write return stack pointer
								                   
    //SAGU interface						                   
    output wire                              prs2sagu_hold_o,                      //maintain stack pointers
    output wire                              prs2sagu_psp_rst_o,                   //reset PSP
    output wire                              prs2sagu_rsp_rst_o,                   //reset RSP
    output wire                              prs2sagu_stack_sel_o,                 //1:RS, 0:PS
    output wire                              prs2sagu_push_o,                      //increment stack pointer
    output wire                              prs2sagu_pull_o,                      //decrement stack pointer
    output wire                              prs2sagu_load_o,                      //load stack pointer
    output wire [SP_WIDTH-1:0]               prs2sagu_psp_next_o,                  //parameter stack load value
    output wire [SP_WIDTH-1:0]               prs2sagu_rsp_next_o,                  //return stack load value
    input  wire                              prs2sagu_lps_empty_i,                 //lower parameter stack is empty
    input  wire                              prs2sagu_lrs_empty_i);                //lower return stack is empty

   //Internal signals
   //-----------------

   //Upper stack
   reg  [15:0]                               rs0_reg;                              //current RS0
   reg  [15:0]                               ps0_reg;                              //current PS0
   reg  [15:0]                               ps1_reg;                              //current PS1
   reg  [15:0]                               ps2_reg;                              //current PS2
   reg  [15:0]                               ps3_reg;                              //current PS3
   reg  [15:0]                               rs0_next;                             //next RS0
   reg  [15:0]                               ps0_next;                             //next PS0
   reg  [15:0]                               ps1_next;                             //next PS1
   reg  [15:0]                               ps2_next;                             //next PS2
   reg  [15:0]                               ps3_next;                             //next PS3
   reg                                       rs0_tag_reg;                          //current RS0 tag
   reg                                       ps0_tag_reg;                          //current PS0 tag
   reg                                       ps1_tag_reg;                          //current PS1 tag
   reg                                       ps2_tag_reg;                          //current PS2 tag
   reg                                       ps3_tag_reg;                          //current PS3 tag
   reg                                       rs0_tag_next;                         //next RS0 tag
   reg                                       ps0_tag_next;                         //next PS0 tag
   reg                                       ps1_tag_next;                         //next PS1 tag
   reg                                       ps2_tag_next;                         //next PS2 tag
   reg                                       ps3_tag_next;                         //next PS3 tag
   reg                                       rs0_we;                               //write enable
   reg                                       ps0_we;                               //write enable
   reg                                       ps1_we;                               //write enable
   reg                                       ps2_we;                               //write enable
   reg                                       ps3_we;                               //write enable
   //Intermediate parameter stack				                   
   reg  [(16*IPS_DEPTH)-1:0]                 ips_reg;                              //current IPS
   reg  [(16*IPS_DEPTH)-1:0]                 ips_next;                             //next IPS
   reg  [IPS_DEPTH-1:0]                      ips_tags_reg;                         //current IPS
   reg  [IPS_DEPTH-1:0]                      ips_tags_next;                        //next IPS
   reg                                       ips_we;                               //write enable  
   //Intermediate parameter stack				                   
   reg  [(16*IRS_DEPTH)-1:0]                 irs_reg;                              //current IRS
   reg  [(16*IRS_DEPTH)-1:0]                 irs_next;                             //next IRS
   reg  [IRS_DEPTH-1:0]                      irs_tags_reg;                         //current IRS
   reg  [IRS_DEPTH-1:0]                      irs_tags_next;                        //next IRS
   reg                                       irs_we;                               //write enable
   


   //Upper stack
   //-----------
   //RS0
   assign rs0_next     = (fsm_rs_shin          ? irs_reg[15:0]      : 16'h0000) |  //RS1 -> RS0
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[0] ? ps0_reg            : 16'h0000) |  //PS0 -> RS0
		           (ir2prs_irs_tp_i[0] ? irs_reg[15:0]      : 16'h0000) |  //RS1 -> RS0
		           (ir2prs_pc2rs0_i    ? dsp2prs_pc_i       : 16'h0000))); //PC  -> RS0
   assign rs0_tag_next = (fsm_rs_shin          & irs_tags_reg[0])               |  //RS1 -> RS0
		         (fsm_idle &  					        
			  ((ir2prs_ups_tp_i[0] & ps0_tag_reg)                   |  //PS0 -> RS0
			   (ir2prs_irs_tp_i[0] & irs_tags_reg[0])               |  //RS1 -> RS0
			    ir2prs_pc2rs0_i));                                     //PC  -> RS0
   assign rs0_we       = fsm_rs_shout                                           |  //0   -> RS0
			 fsm_rs_shin                                            |  //RS1 -> RS0
			 (fsm_idle & ~fc2prs_hold_i &			        
			  (ir2prs_ups_tp_i[0]                                   |  //PS0 -> RS0
			   ir2prs_irs_tp_i[0]                                   |  //RS1 -> RS0
			    ir2prs_pc2rs0_i));                                     //PC  -> RS0                         //PC  -> RS0

   //PS0
   assign ps0_next     = (fsm_ps_shin          ? ps1_reg            : 16'h0000) |  //PS1 -> PS0
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[1] ? rs0_reg            : 16'h0000) |  //RS0 -> PS0
			   (ir2prs_ups_tp_i[2] ? ps1_reg            : 16'h0000) |  //PS1 -> PS0
			   (ir2prs_alu2ps0_i   ? alu2prs_ps0_next_i : 16'h0000) |  //ALU -> PS0
			   (ir2prs_dat2ps0_i   ? pbus_dat_i         : 16'h0000) |  //DAT -> PS0
			   (ir2prs_lit2ps0_i   ? ir2prs_lit_val_i   : 16'h0000) |  //LIT -> PS0
			   (ir2prs_vec2ps0_i   ? irq_vec_i          : 16'h0000))); //VEC -> PS0
   assign ps0_tag_next = (fsm_ps_shin          & ps1_tag_reg)                   |  //PS1 -> PS0
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[1] & rs0_tag_reg)                   |  //RS0 -> PS0
			   (ir2prs_ups_tp_i[2] & ps1_tag_reg)                   |  //PS1 -> PS0
			    ir2prs_alu2ps0_i                                    |  //ALU -> PS0
			    ir2prs_dat2ps0_i                                    |  //DAT -> PS0
			    ir2prs_lit2ps0_i                                    |  //LIT -> PS0
			    ir2prs_vec2ps0_i));                                    //VEC -> PS0
   assign ps0_we       = fsm_ps_shout                                           |  //0   -> PS0
			 fsm_ps_shin                                            |  //PS1 -> PS0
			 (fsm_idle & ~fc2prs_hold_i &			        
		          (ir2prs_ups_tp_i[1]                                   |  //RS0 -> PS0
			   ir2prs_ups_tp_i[2]                                   |  //PS1 -> PS0
			   ir2prs_alu2ps0_i                                     |  //ALU -> PS0
			   ir2prs_dat2ps0_i                                     |  //DAT -> PS0
			   ir2prs_lit2ps0_i                                     |  //LIT -> PS0
			   ir2prs_vec2ps0_i));                                     //VEC -> PS0

   //PS1
   assign ps1_next     = (fsm_ps_shout         ? ps0_reg            : 16'h0000) |  //PS0 -> PS1
		         (fsm_ps_shin          ? ps2_reg            : 16'h0000) |  //PS2 -> PS1
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[3] ? ps0_reg            : 16'h0000) |  //PS0 -> PS1
			   (ir2prs_ups_tp_i[4] ? ps2_reg            : 16'h0000) |  //PS2 -> PS1
			   (ir2prs_alu2ps1_i   ? alu2prs_ps1_next_i : 16'h0000))); //ALU -> PS1
   assign ps1_tag_next = (fsm_ps_shout         & ps0_tag_reg)                   |  //PS0 -> PS1
		         (fsm_ps_shin          & ps2_tag_reg)                   |  //PS2 -> PS1
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[3] & ps0_tag_reg)                   |  //PS0 -> PS1
			   (ir2prs_ups_tp_i[4] & ps2_tag_reg)                   |  //PS2 -> PS1
			    ir2prs_alu2ps1_i));                                 |  //ALU -> PS1
   assign ps1_we       = fsm_ps_shout                                           |  //PS0 -> PS1
		         fsm_ps_shin                                            |  //PS2 -> PS1
			 (fsm_idle & ~fc2prs_hold_i &			        
		          (ir2prs_ups_tp_i[3]                                   |  //PS0 -> PS1
			   ir2prs_ups_tp_i[4]                                   |  //PS2 -> PS1
			   ir2prs_alu2ps1_i));                                     //ALU -> PS1

   //PS2
   assign ps2_next     = (fsm_ps_shout         ? ps1_reg            : 16'h0000) |  //PS1 -> PS2
		         (fsm_ps_shin          ? ps3_reg            : 16'h0000) |  //PS3 -> PS2
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[5] ? ps1_reg            : 16'h0000) |  //PS1 -> PS2
			   (ir2prs_ups_tp_i[6] ? ps3_reg            : 16'h0000))); //PS3 -> PS2
   assign ps2_tag_next = (fsm_ps_shout         & ps1_tag_reg)                   |  //PS1 -> PS2
		         (fsm_ps_shin          & ps3_tag_reg)                   |  //PS3 -> PS2
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[5] & ps1_tag_reg)                   |  //PS1 -> PS2
			   (ir2prs_ups_tp_i[6] & ps3_tag_reg)));                |  //PS3 -> PS2
   assign ps2_we       = fsm_ps_shout                                           |  //PS1 -> PS2
		         fsm_ps_shin                                            |  //PS3 -> PS2
			 (fsm_idle & ~fc2prs_hold_i &			        
		          (ir2prs_ups_tp_i[5]                                   |  //PS1 -> PS2
			   ir2prs_ups_tp_i[6]));                                   //PS3 -> PS2

   //PS3
   assign ps3_next     = (fsm_ps_shout         ? ps2_reg            : 16'h0000) |  //PS2 -> PS3
		         (fsm_ps_shin          ? ips_reg[15:0]      : 16'h0000) |  //PS4 -> PS3
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[7] ? ps2_reg            : 16'h0000) |  //PS2 -> PS3
			   (ir2prs_ips_tp_i[0] ? ips_reg[15:0]      : 16'h0000))); //PS4 -> PS3
   assign ps3_tag_next = (fsm_ps_shout         & ps2_tag_reg)                   |  //PS2 -> PS3
		         (fsm_ps_shin          & ips_tags_reg[0])                   |  //PS4 -> PS3
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[7] & ps2_tag_reg)                   |  //PS2 -> PS3
			   (ir2prs_ips_tp_i[0] & ips_tags_reg[0])));            |  //PS4 -> PS3
   assign ps3_we       = fsm_ps_shout                                           |  //PS2 -> PS3
		         fsm_ps_shin                                            |  //PS4 -> PS3
			 (fsm_idle & ~fc2prs_hold_i &			        
		          (ir2prs_ups_tp_i[7]                                   |  //PS2 -> PS3
			   ir2prs_ips_tp_i[0]));                                   //PS4 -> PS3

   //Flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                              //asynchronous reset
       begin						                           
	  rs0_reg     <= 16'h0000;                                                 //RS0 (TOS)
	  ps0_reg     <= 16'h0000;                                                 //PS0 (TOS)
	  ps1_reg     <= 16'h0000;                                                 //PS1 (TOS+1)
	  ps2_reg     <= 16'h0000;                                                 //PS2 (TOS+2)
          ps3_reg     <= 16'h0000;                                                 //PS3 (TOS+3)
          rs0_tag_reg <= 1'b0;                                                     //RS0 tag
          ps0_tag_reg <= 1'b0;                                                     //PS0 tag
          ps1_tag_reg <= 1'b0;                                                     //PS1 tag
          ps2_tag_reg <= 1'b0;                                                     //PS2 tag
          ps3_tag_reg <= 1'b0;                                                     //PS3 tag
       end						                           
     else if (sync_rst_i)                                                          //synchronous reset
       begin						                           
	  rs0_reg     <= 16'h0000;                                                 //RS0 (TOS)
	  ps0_reg     <= 16'h0000;                                                 //PS0 (TOS)
	  ps1_reg     <= 16'h0000;                                                 //PS1 (TOS+1)
	  ps2_reg     <= 16'h0000;                                                 //PS2 (TOS+2)
          ps3_reg     <= 16'h0000;                                                 //PS3 (TOS+3)
          rs0_tag_reg <= 1'b0;                                                     //RS0 tag
          ps0_tag_reg <= 1'b0;                                                     //PS0 tag
          ps1_tag_reg <= 1'b0;                                                     //PS1 tag
          ps2_tag_reg <= 1'b0;                                                     //PS2 tag
          ps3_tag_reg <= 1'b0;                                                     //PS3 tag
       end						                           
     else						                           
       begin						                           
	  if (rs0_we) rs0_reg     <= rs0_next;                                     //RS0 (TOS)
	  if (ps0_we) ps0_reg     <= ps0_next;                                     //PS0 (TOS)
	  if (ps1_we) ps1_reg     <= ps1_next;                                     //PS1 (TOS+1)
	  if (ps2_we) ps2_reg     <= ps2_next;                                     //PS2 (TOS+2)
          if (ps3_we) ps3_reg     <= ps3_next;                                     //PS3 (TOS+3)
          if (rs0_we) rs0_tag_reg <= rs0_tag_next;                                 //RS0 tag
          if (ps0_we) ps0_tag_reg <= ps0_tag_next;                                 //PS0 tag
          if (ps1_we) ps1_tag_reg <= ps1_tag_next;                                 //PS1 tag
          if (ps2_we) ps2_tag_reg <= ps2_tag_next;                                 //PS2 tag
          if (ps3_we) ps3_tag_reg <= ps3_tag_next;                                 //PS3 tag
       end

   //Intermediate parameter stack
   //----------------------------
   assign ips_next      = (fsm_ps_shout ?                                          //shift out
			   {ips_reg[(16*IPS_DEPTH)-17:0], 16'h0000}             :  //PSn   -> PSn+1
		           {IPS_DEPTH{16'h0000}})                               |  //
		          (fsm_ps_shin  ?                                          //shift in
			   {16'h0000, ips_reg[(16*IPS_DEPTH)-1:16]}             :  //PSn+1 -> PSn
		           {IPS_DEPTH{16'h0000}})                               |  //
		          (fsm_ps_dat2ps4 ?                                        //fetch read data
			   {{IPS_DEPTH-1{16'h0000}}, sbus_dat_i}                :  //DAT -> PS4
		           {IPS_DEPTH{16'h0000}})                               |  //
		          (fsm_ps_psp2ps4 ?                                        //fetch PSP
			   {{IPS_DEPTH-1{16'h0000}}, dsp2prs_psp_next_i}        :  //DAT -> PS4
		           {IPS_DEPTH{16'h0000}})                               |  //
			  ({16*IPS_DEPTH{fsm_idle}} &  	                           //
			   (ir2prs_ips_tp_i[1] ?                                   //shift out
			    {ips_reg[(16*IPS_DEPTH)-17:0], 16'h0000}            :  //PSn   -> PSn+1
		            {IPS_DEPTH{16'h0000}})                              |  //
			   (ir2prs_ips_tp_i[0] ?                                   //shift in
			    {16'h0000, ips_reg[(16*IPS_DEPTH)-1:16]}            :  //PSn+1 -> PSn
		            {IPS_DEPTH{16'h0000}}));                               //
   assign ips_tags_next = (fsm_ps_shout ?                                          //shift out
			   {ips_tags_reg[IPS_DEPTH-2:0], 1'b0}                  :  //PSn   -> PSn+1
		           {IPS_DEPTH{1'b0}})                                   |  //
		          (fsm_ps_shin  ?                                          //shift in
			   {1'b0, ips_tags_reg[IPS_DEPTH-1:1]}                  :  //PSn+1 -> PSn
		           {IPS_DEPTH{1'b0}})                                   |  //
		          (fsm_ps_dat2ps4 ?                                        //fetch read data
			   {{IPS_DEPTH-1{1'b0}}, 1'b1}                          :  //DAT -> PS4
		           {IPS_DEPTH{1'b0}})                                   |  //
		          (fsm_ps_psp2ps4 ?                                       //fetch read PSP
			   {{IPS_DEPTH-1{1'b0}}, 1'b1}                          :  //DAT -> PS4
		           {IPS_DEPTH{1'b0}})                                   |  //
			  ({IPS_DEPTH{fsm_idle}} &  	                           //	            		      
			   (ir2prs_ips_tp_i[1] ?                                   //shift out
			    {ips_tags_reg[IPS_DEPTH-2:0], 1'b0}                 :  //PSn   -> PSn+1
		            {IPS_DEPTH{1'b0}})                                  |  //
			   (ir2prs_ips_tp_i[0] ?                                   //shift in
			    {1'b0, ips_tags_reg[IPS_DEPTH-1:1]}                 :  //PSn+1 -> PSn
		            {IPS_DEPTH{1'b0}}));                                |  //
   assign ips_we        = fsm_ps_shout                                          |  //shift out
		          fsm_ps_shin                                           |  //shift in
		          fsm_ps_dat2ps4                                        |  //fetch read data
		          fsm_ps_psp2ps4                                        |  //fetch read PSP
			  (fsm_idle &  	                                           //	            		      
			   (ir2prs_ips_tp_i[1]                                  |  //shift out
			    ir2prs_ips_tp_i[0]));                                  //shift in

   //Flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                              //asynchronous reset
       begin						                           
	  ips_reg      <= {IRS_DEPTH{16'h0000}};                                   //cells
	  ips_tags_reg <= {IRS_DEPTH{1'b1}};                                       //tags
       end						                           
     else if (sync_rst_i)                                                          //synchronous reset
       begin						                           
	  ips_reg      <= {IRS_DEPTH{16'h0000}};                                   //cells
	  ips_tags_reg <= {IRS_DEPTH{1'b1}};                                       //tags
       end						                           
     else if (ips_we)						                           
       begin						                           
 	  ips_reg      <= ips_next;                                                //cells
	  ips_tags_reg <= ips_tags_next;                                           //tags
      end

   //Intermediate return stack
   //-------------------------
   assign irs_next      = (fsm_rs_shout ?                                          //shift out
			   {irs_reg[(16*IRS_DEPTH)-17:0], 16'h0000}             :  //RSn   -> RSn+1
		           {IRS_DEPTH{16'h0000}})                               |  //
		          (fsm_rs_shin  ?                                          //shift in
			   {16'h0000, irs_reg[(16*IRS_DEPTH)-1:16]}             :  //RSn+1 -> RSn
		           {IRS_DEPTH{16'h0000}})                               |  //
		          (fsm_rs_dat2rs4 ?                                        //fetch read data
			   {{IRS_DEPTH-1{16'h0000}}, sbus_dat_i}                :  //DAT -> RS4
		           {IRS_DEPTH{16'h0000}})                               |  //
		          (fsm_rs_rsp2rs4 ?                                        //fetch RSP
			   {{IRS_DEPTH-1{16'h0000}}, dsp2prs_rsp_next_i}        :  //DAT -> RS4
		           {IRS_DEPTH{16'h0000}})                               |  //
			  ({16*IRS_DEPTH{fsm_idle}} &  	                           //
			   (ir2prs_irs_tp_i[1] ?                                   //shift out
			    {irs_reg[(16*IRS_DEPTH)-17:0], 16'h0000}            :  //RSn   -> RSn+1
		            {IRS_DEPTH{16'h0000}})                              |  //
			   (ir2prs_irs_tp_i[0] ?                                   //shift in
			    {16'h0000, irs_reg[(16*IRS_DEPTH)-1:16]}            :  //RSn+1 -> RSn
		            {IRS_DEPTH{16'h0000}}));                               //
   assign irs_tags_next = (fsm_rs_shout ?                                          //shift out
			   {irs_tags_reg[IRS_DEPTH-2:0], 1'b0}                  :  //RSn   -> RSn+1
		           {IRS_DEPTH{1'b0}})                                   |  //
		          (fsm_rs_shin  ?                                          //shift in
			   {1'b0, irs_tags_reg[IRS_DEPTH-1:1]}                  :  //RSn+1 -> RSn
		           {IRS_DEPTH{1'b0}})                                   |  //
		          (fsm_rs_dat2rs4 ?                                        //fetch read data
			   {{IRS_DEPTH-1{1'b0}}, 1'b1}                          :  //DAT -> RS4
		           {IRS_DEPTH{1'b0}})                                   |  //
		          (fsm_rs_rsp2rs4 ?                                       //fetch read RSP
			   {{IRS_DEPTH-1{1'b0}}, 1'b1}                          :  //DAT -> RS4
		           {IRS_DEPTH{1'b0}})                                   |  //
			  ({IRS_DEPTH{fsm_idle}} &  	                           //	            		      
			   (ir2prs_irs_tp_i[1] ?                                   //shift out
			    {irs_tags_reg[IRS_DEPTH-2:0], 1'b0}                 :  //RSn   -> RSn+1
		            {IRS_DEPTH{1'b0}})                                  |  //
			   (ir2prs_irs_tp_i[0] ?                                   //shift in
			    {1'b0, irs_tags_reg[IRS_DEPTH-1:1]}                 :  //RSn+1 -> RSn
		            {IRS_DEPTH{1'b0}}));                                |  //
   assign irs_we        = fsm_rs_shout                                          |  //shift out
		          fsm_rs_shin                                           |  //shift in
		          fsm_rs_dat2rs4                                        |  //fetch read data
		          fsm_rs_rsp2rs4                                        |  //fetch read RSP
			  (fsm_idle &  	                                           //	            		      
			   (ir2prs_irs_tp_i[1]                                  |  //shift out
			    ir2prs_irs_tp_i[0]));                                  //shift in

   //Flipflors
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                              //asynchronous reset
       begin						                           
	  irs_reg      <= {IRS_DEPTH{16'h0000}};                                   //cells
	  irs_tags_reg <= {IRS_DEPTH{1'b1}};                                       //tags
       end						                           
     else if (sync_rst_i)                                                          //synchronous reset
       begin						                           
	  irs_reg      <= {IRS_DEPTH{16'h0000}};                                   //cells
	  irs_tags_reg <= {IRS_DEPTH{1'b1}};                                       //tags
       end						                           
     else if (irs_we)						                           
       begin						                           
 	  irs_reg      <= irs_next;                                                //cells
	  irs_tags_reg <= irs_tags_next;                                           //tags
      end









   



  
   //Finite state machine flip flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       state_reg <= STATE_RESET;
     else if (sync_rst_i)                                     //synchronous reset
       state_reg <= STATE_RESET;
     else                                                     //state transition
       state_reg <= state_next;

endmodule // N1_prs
