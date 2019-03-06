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
    output reg                               sbus_cyc_o,                           //bus cycle indicator       +-
    output reg                               sbus_stb_o,                           //access request            | initiator
    output reg                               sbus_we_o,                            //write enable              | to
    output wire [15:0]                       sbus_dat_o,                           //write data bus            | target
    input  wire                              sbus_ack_i,                           //bus cycle acknowledge     +-
    input  wire                              sbus_stall_i,                         //access delay              | initiator to initiator
    input  wire [15:0]                       sbus_dat_i,                           //read data bus             +-

    //Internal signals
    //----------------
    //ALU interface
    output wire [15:0]                       prs2alu_ps0_o,                        //current PS0 (TOS)
    output wire [15:0]                       prs2alu_ps1_o,                        //current PS1 (TOS+1)
    input  wire [15:0]                       alu2prs_ps0_next_i,                   //new PS0 (TOS)
    input  wire [15:0]                       alu2prs_ps1_next_i,                   //new PS1 (TOS+1)

     //DSP interface
    input  wire [15:0]                       dsp2prs_pc_i,                         //program counter
    input  wire [SP_WIDTH-1:0]               dsp2prs_psp_i,                        //parameter stack pointer (AGU output)
    input  wire [SP_WIDTH-1:0]               dsp2prs_rsp_i,                        //return stack pointer (AGU output)
								                   
    //EXCPT interface						                   
    output wire                              prs2excpt_psuf_o,                     //parameter stack underflow
    output wire                              prs2excpt_rsuf_o,                     //return stack underflow
    input  wire [15:0]                       excpt2prs_tc_i;                       //throw code
								                   
    //FC interface						                   
    output reg                               prs2fc_hold_o,                        //stacks not ready
    output wire                              prs2fc_ps0_true_o,                    //PS0 in non-zero	
    input  wire                              fc2prs_hold_i,                        //hold any state tran
    input  wire                              fc2prs_dat2ps0_i,                     //capture read data
    input  wire                              fc2prs_tc2ps0_i;                      //capture throw code
    input  wire                              fc2prs_isr2ps0_i;                     //capture ISR
							                   
    //IR interface						                   
    input  wire [15:0]                       ir2prs_lit_val_i,                     //literal value
    input  wire [7:0]                        ir2prs_ups_tp_i,                      //upper stack transition pattern
    input  wire [1:0]                        ir2prs_ips_tp_i,                      //10:push, 01:pull
    input  wire [1:0]                        ir2prs_irs_tp_i,                      //10:push, 01:pull
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
    input  wire                              ir2prs_rsp_wr_i,                      //write return stack pointer
								                   
    //SAGU interface						                   
    output reg                               prs2sagu_hold_o,                      //maintain stack pointers
    output reg                               prs2sagu_psp_rst_o,                   //reset PSP
    output reg                               prs2sagu_rsp_rst_o,                   //reset RSP
    output wire                              prs2sagu_stack_sel_o,                 //1:RS, 0:PS
    output reg                               prs2sagu_push_o,                      //increment stack pointer
    output reg                               prs2sagu_pull_o,                      //decrement stack pointer
    output reg                               prs2sagu_load_o,                      //load stack pointer
    output wire [SP_WIDTH-1:0]               prs2sagu_psp_next_o,                  //parameter stack load value
    output wire [SP_WIDTH-1:0]               prs2sagu_rsp_next_o,                  //return stack load value
    input  wire                              sagu2prs_lps_empty_i,                 //lower parameter stack is empty
    input  wire                              sagu2prs_lrs_empty_i,                 //lower return stack is empty

    //Probe signals
    output wire [3:0] 			     prb_state_o,                          //current state
    output wire [15:0]                       prb_rs0_o,                            //current RS0
    output wire [15:0]                       prb_ps0_o,                            //current PS0
    output wire [15:0]                       prb_ps1_o,                            //current PS1
    output wire [15:0]                       prb_ps2_o,                            //current PS2
    output wire [15:0]                       prb_ps3_o,                            //current PS3
    output wire                              prb_rs0_tag_o,                        //current RS0 tag
    output wire                              prb_ps0_tag_o,                        //current PS0 tag
    output wire                              prb_ps1_tag_o,                        //current PS1 tag
    output wire                              prb_ps2_tag_o,                        //current PS2 tag
    output wire                              prb_ps3_tag_o,                        //current PS3 tag
    output wire [(16*IPS_DEPTH)-1:0]         prb_ips_o,                            //current IPS
    output wire [IPS_DEPTH-1:0]              prb_ips_tags_o,                       //current IPS
    output wire [(16*IRS_DEPTH)-1:0]         prb_irs_o,                            //current IRS
    output wire [IRS_DEPTH-1:0]              prb_irs_tags_o);                      //current IRS
					     
   //Internal signals
   //-----------------
   //FSM
   reg  [3:0] 				     state_reg;                            //current state
   reg  [3:0] 				     state_next;                           //next state
   reg                                       fsm_idle;                             //FSM is in STATE_IDLE
   reg                                       fsm_stack_sel;                        //1:RS, 0:PS
   reg                                       fsm_ps_si;                            //shift PS in  (IPS -> UPS)
   reg                                       fsm_ps_so;                            //shift PS out (UPS -> IPS)
   reg                                       fsm_rs_si;                            //shift RS in  (IRS -> URS)
   reg                                       fsm_rs_so;                            //shift RS out (IRS -> URS)  
   reg                                       fsm_rs_dat2rs4;                       //capture read data
   wire                                      fsm_ps_load_trig;                     //PS load trigger
   wire                                      fsm_ps_unload_trig;                   //PS unload trigger
   wire                                      fsm_rs_load_trig;                     //RS load trigger
   wire                                      fsm_rs_unload_trig;                   //RS unload trigger
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
   assign rs0_next     = (fsm_rs_si            ? irs_reg[15:0]      : 16'h0000) |  //RS1 -> RS0
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[0] ? ps0_reg            : 16'h0000) |  //PS0 -> RS0
		           (ir2prs_irs_tp_i[0] ? irs_reg[15:0]      : 16'h0000) |  //RS1 -> RS0
		           (ir2prs_pc2rs0_i    ? dsp2prs_pc_i       : 16'h0000))); //PC  -> RS0
   assign rs0_tag_next = (fsm_rs_si            & irs_tags_reg[0])               |  //RS1 -> RS0
		         (fsm_idle             &  					        
			  ((ir2prs_ups_tp_i[0] & ps0_tag_reg)                   |  //PS0 -> RS0
			   (ir2prs_irs_tp_i[0] & irs_tags_reg[0])               |  //RS1 -> RS0
			    ir2prs_pc2rs0_i));                                     //PC  -> RS0
   assign rs0_we       = fsm_rs_so                                              |  //0   -> RS0
			 fsm_rs_si                                              |  //RS1 -> RS0
			 (fsm_idle & ~fc2prs_hold_i &			        
			  (ir2prs_rs_rst_i                                      |  //reset RS
			   ir2prs_ups_tp_i[0]                                   |  //PS0 -> RS0
			   ir2prs_irs_tp_i[0]                                   |  //RS1 -> RS0
			    ir2prs_pc2rs0_i));                                     //PC  -> RS0

   //PS0
   assign ps0_next     = (fsm_ps_si            ? ps1_reg            : 16'h0000) |  //PS1 -> PS0
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[1] ? rs0_reg            : 16'h0000) |  //RS0 -> PS0
			   (ir2prs_ups_tp_i[2] ? ps1_reg            : 16'h0000) |  //PS1 -> PS0
			   (ir2prs_alu2ps0_i   ? alu2prs_ps0_next_i : 16'h0000) |  //ALU -> PS0
			   (ir2prs_lit2ps0_i   ? ir2prs_lit_val_i   : 16'h0000) |  //LIT -> PS0
			   (fc2prs_dat2ps0_i   ? pbus_dat_i         : 16'h0000) |  //DAT -> PS0
			   (fc2prs_tc2ps0_i    ? excpt2prs_tc       : 16'h0000) |  //TC  -> PS0
			   (ir2prs_isr2ps0_i   ? irq_req_i          : 16'h0000))); //ISR -> PS0
   assign ps0_tag_next = (fsm_ps_si            & ps1_tag_reg)                   |  //PS1 -> PS0
		         ({16{fsm_idle}}       &  		            		      
		          ((ir2prs_ups_tp_i[1] & rs0_tag_reg)                   |  //RS0 -> PS0
			   (ir2prs_ups_tp_i[2] & ps1_tag_reg)                   |  //PS1 -> PS0
			    ir2prs_alu2ps0_i                                    |  //ALU -> PS0
			    ir2prs_dat2ps0_i                                    |  //DAT -> PS0
			    ir2prs_lit2ps0_i                                    |  //LIT -> PS0
			    ir2prs_vec2ps0_i));                                    //VEC -> PS0
   assign ps0_we       = fsm_ps_so                                              |  //0   -> PS0
			 fsm_ps_si                                              |  //PS1 -> PS0
			 (fsm_idle & ~fc2prs_hold_i &			        
		          (ir2prs_ps_rst_i                                      |  //reset PS
			   ir2prs_ups_tp_i[1]                                   |  //RS0 -> PS0
			   ir2prs_ups_tp_i[2]                                   |  //PS1 -> PS0
			   ir2prs_alu2ps0_i                                     |  //ALU -> PS0
			   ir2prs_dat2ps0_i                                     |  //DAT -> PS0
			   ir2prs_lit2ps0_i                                     |  //LIT -> PS0
			   ir2prs_vec2ps0_i));                                     //VEC -> PS0

   //PS1
   assign ps1_next     = (fsm_ps_so            ? ps0_reg            : 16'h0000) |  //PS0 -> PS1
		         (fsm_ps_si            ? ps2_reg            : 16'h0000) |  //PS2 -> PS1
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[3] ? ps0_reg            : 16'h0000) |  //PS0 -> PS1
			   (ir2prs_ups_tp_i[4] ? ps2_reg            : 16'h0000) |  //PS2 -> PS1
			   (ir2prs_alu2ps1_i   ? alu2prs_ps1_next_i : 16'h0000))); //ALU -> PS1
   assign ps1_tag_next = (fsm_ps_so            & ps0_tag_reg)                   |  //PS0 -> PS1
		         (fsm_ps_si            & ps2_tag_reg)                   |  //PS2 -> PS1
		         ({16{fsm_idle}}       &  		            		      
		          ((ir2prs_ups_tp_i[3] & ps0_tag_reg)                   |  //PS0 -> PS1
			   (ir2prs_ups_tp_i[4] & ps2_tag_reg)                   |  //PS2 -> PS1
			    ir2prs_alu2ps1_i));                                 |  //ALU -> PS1
   assign ps1_we       = fsm_ps_so                                              |  //PS0 -> PS1
		         fsm_ps_si                                              |  //PS2 -> PS1
			 (fsm_idle & ~fc2prs_hold_i &			        
		          (ir2prs_ps_rst_i                                      |  //reset PS
			   ir2prs_ups_tp_i[3]                                   |  //PS0 -> PS1
			   ir2prs_ups_tp_i[4]                                   |  //PS2 -> PS1
			   ir2prs_alu2ps1_i));                                     //ALU -> PS1

   //PS2
   assign ps2_next     = (fsm_ps_so            ? ps1_reg            : 16'h0000) |  //PS1 -> PS2
		         (fsm_ps_si            ? ps3_reg            : 16'h0000) |  //PS3 -> PS2
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[5] ? ps1_reg            : 16'h0000) |  //PS1 -> PS2
			   (ir2prs_ups_tp_i[6] ? ps3_reg            : 16'h0000))); //PS3 -> PS2
   assign ps2_tag_next = (fsm_ps_so            & ps1_tag_reg)                   |  //PS1 -> PS2
		         (fsm_ps_si            & ps3_tag_reg)                   |  //PS3 -> PS2
		         ({16{fsm_idle}}       &  		            		      
		          ((ir2prs_ups_tp_i[5] & ps1_tag_reg)                   |  //PS1 -> PS2
			   (ir2prs_ups_tp_i[6] & ps3_tag_reg)));                |  //PS3 -> PS2
   assign ps2_we       = fsm_ps_so                                              |  //PS1 -> PS2
		         fsm_ps_si                                              |  //PS3 -> PS2
			 (fsm_idle & ~fc2prs_hold_i &			        
		          (ir2prs_ps_rst_i                                      |  //reset PS
			   ir2prs_ups_tp_i[5]                                   |  //PS1 -> PS2
			   ir2prs_ups_tp_i[6]));                                   //PS3 -> PS2

   //PS3
   assign ps3_next     = (fsm_ps_so            ? ps2_reg            : 16'h0000) |  //PS2 -> PS3
		         (fsm_ps_si            ? ips_reg[15:0]      : 16'h0000) |  //PS4 -> PS3
		         ({16{fsm_idle}}       &  		            		      
		          ((ir2prs_ups_tp_i[7] ? ps2_reg            : 16'h0000) |  //PS2 -> PS3
			   (ir2prs_ips_tp_i[0] ? ips_reg[15:0]      : 16'h0000))); //PS4 -> PS3
   assign ps3_tag_next = (fsm_ps_so            & ps2_tag_reg)                   |  //PS2 -> PS3
		         (fsm_ps_si            & ips_tags_reg[0])               |  //PS4 -> PS3
		         ({16{fsm_idle}} &  		            		      
		          ((ir2prs_ups_tp_i[7] & ps2_tag_reg)                   |  //PS2 -> PS3
			   (ir2prs_ips_tp_i[0] & ips_tags_reg[0])));            |  //PS4 -> PS3
   assign ps3_we       = fsm_ps_so                                              |  //PS2 -> PS3
		         fsm_ps_si                                              |  //PS4 -> PS3
			 (fsm_idle & ~fc2prs_hold_i &			        
		          (ir2prs_ps_rst_i                                      |  //reset PS
			   ir2prs_ups_tp_i[7]                                   |  //PS2 -> PS3
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
          ps0_tag_reg <= 1'b1;                                                     //PS0 tag
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
          ps0_tag_reg <= 1'b1;                                                     //PS0 tag
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
   assign ips_next      = (fsm_ps_so ?                                             //shift out
			   {ips_reg[(16*IPS_DEPTH)-17:0], 16'h0000}             :  //PSn   -> PSn+1
		           {IPS_DEPTH{16'h0000}})                               |  //
		          (fsm_ps_si ?                                             //shift in
			   {16'h0000, ips_reg[(16*IPS_DEPTH)-1:16]}             :  //PSn+1 -> PSn
		           {IPS_DEPTH{16'h0000}})                               |  //
		          (fsm_dat2ps4 ?                                           //fetch read data
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
   assign ips_tags_next = (fsm_ps_so ?                                             //shift out
			   {ips_tags_reg[IPS_DEPTH-2:0], 1'b0}                  :  //PSn   -> PSn+1
		           {IPS_DEPTH{1'b0}})                                   |  //
		          (fsm_ps_si  ?                                            //shift in
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
   assign ips_we        = fsm_ps_so                                             |  //shift out
		          fsm_ps_si                                             |  //shift in
		          fsm_ps_dat2ps4                                        |  //fetch read data
		          fsm_ps_psp2ps4                                        |  //fetch read PSP
			  (fsm_idle &  	                                           //	            		      
			   (ir2prs_ps_rst_i                                     |  //reset PS
			    ir2prs_ips_tp_i[1]                                  |  //shift out
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
   assign irs_next      = (fsm_rs_so ?                                             //shift out
			   {irs_reg[(16*IRS_DEPTH)-17:0], 16'h0000}             :  //RSn   -> RSn+1
		           {IRS_DEPTH{16'h0000}})                               |  //
		          (fsm_rs_si  ?                                            //shift in
			   {16'h0000, irs_reg[(16*IRS_DEPTH)-1:16]}             :  //RSn+1 -> RSn
		           {IRS_DEPTH{16'h0000}})                               |  //
		          (fsm_dat2rs1 ?                                           //fetch read data
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
   assign irs_tags_next = (fsm_rs_so ?                                             //shift out
			   {irs_tags_reg[IRS_DEPTH-2:0], 1'b0}                  :  //RSn   -> RSn+1
		           {IRS_DEPTH{1'b0}})                                   |  //
		          (fsm_rs_si  ?                                          //shift in
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
   assign irs_we        = fsm_rs_so                                             |  //shift out
		          fsm_rs_si                                             |  //shift in
		          fsm_rs_dat2rs4                                        |  //fetch read data
		          fsm_rs_rsp2rs4                                        |  //fetch read RSP
			  (fsm_idle &  	                                           //	            		      
			   (ir2prs_rs_rst_i                                     |  //reset RS
			    ir2prs_irs_tp_i[1]                                  |  //shift out
			    ir2prs_irs_tp_i[0]));                                  //shift in

   //Flipflops
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

   //Finite state machine
   //--------------------
   //State encoding
   localparam STATE_IDLE = 4'b0000;

   //Load/unload trigger
   assign fsm_ps_load_trig   = ~prs2sagu_lps_empty_i &                             //IPS is not empty 
			       (~ips_tags_reg[0]     |                             //PS4 is mempty
				(~ips_tags_reg[1]    &                             //PS5 is empty
				 ir2prs_ips_tp_i[0])));                            //pull request
   assign fsm_ps_unload_trig = ips_tags_reg[IRS_DEPTH-1]  |                        //PSn is full
			       (ips_tags_reg[IRS_DEPTH-2] &                        //PSn-1 is full
			        ir2prs_ips_tp_i[1]);                               //push request
   assign fsm_rs_load_trig   = ~prs2sagu_lrs_empty_i &                             //IRS is not empty 
			       (~irs_tags_reg[0]     |                             //RS1 is mempty
				(~irs_tags_reg[1]    &                             //RS2 is empty
				 ir2prs_irs_tp_i[0])));                            //pull request
   assign fsm_rs_unload_trig = irs_tags_reg[IRS_DEPTH-1]  |                        //RSn is full
			       (irs_tags_reg[IRS_DEPTH-2] &                        //RSn-1 is full
			        ir2prs_irs_tp_i[1]);                               //push request
   
   //State transitions
   always @*
     begin
        //Default outputs
        fsm_idle		= 1'b0;                                            //FSM is in STATE_IDLE
        fsm_stack_sel           = 1'b0;                                            //1:RS, 0:PS
        fsm_ps_si		= 1'b0;                                            //shift PS in  (IPS -> UPS)
        fsm_ps_so		= 1'b0;                                            //shift PS out (UPS -> IPS)
        fsm_rs_si		= 1'b0;                                            //shift RS in  (IRS -> URS)
        fsm_rs_so		= 1'b0;                                            //shift RS out (IRS -> URS)  
        fsm_dat2rs4		= 1'b0;                                            //capture read data
        fsm_dat2rs1		= 1'b0;                                            //capture read data
        sbus_cyc_o		= 1'b0;                                            //bus cycle indicator
        sbus_stb_o		= 1'b0;                                            //access request       
        sbus_we_o               = 1'b0;                                            //write enable
        prs2fc_hold_o		= 1'b1;                                            //stacks not ready
        prs2sagu_hold_o		= 1'b0;                                            //maintain stack pointers
        prs2sagu_psp_rst_o	= 1'b0;                                            //reset PSP
        prs2sagu_rsp_rst_o	= 1'b0;                                            //reset RSP
        prs2sagu_push_o		= 1'b0;                                            //increment stack pointer
        prs2sagu_pull_o		= 1'b0;                                            //decrement stack pointer
        prs2sagu_load_o		= 1'b0;                                            //load stack pointer
        state_next              = state_reg;                                       //next state
	
	case (state_reg)
	  STATE_IDLE:
	    begin
	       fsm_idle		= 1'b1;                                            //FSM is in STATE_IDLE
               prs2fc_hold_o	= 1'b0;                                            //stacks ready
	       if (ir2prs_ps_rst_i | ir2prs_rs_rst_i)                              //reset requested
		 begin
		    prs2sagu_psp_rst_o = ir2prs_ps_rst_i;                          //reset IPS
		    prs2sagu_rsp_rst_o = ir2prs_rs_rst_i;                          //reset IRS
		 end
	       else if (fsm_ps_load_trig | fsm_ps_unload_trig)                     //PS adjustment required
		 begin
		    sbus_cyc_o	  = 1'b1;                                          //bus cycle indicator
		    sbus_stb_o	  = 1'b1;                                          //access request       
		    sbus_we_o     = fsm_ps_unload_trig;                            //write enable
		    fsm_stack_sel = 1'b0;                                          //select PS
		    state_next    = sbus_stall_i ? STATE_PS_STALL : STATE_PS_ACC;  //next state
		    



		 end
	       else if (fsm_rs_load_trig | fsm_rs_unload_trig)                     //RS adjustment required
		 begin
		    sbus_cyc_o	  = 1'b1;                                          //bus cycle indicator
		    sbus_stb_o	  = 1'b1;                                          //access request       
		    sbus_we_o     = fsm_rs_unload_trig;                            //write enable
		    fsm_stack_sel = 1'b1;                                          //select RS
		    state_next    = sbus_stall_i ? STATE_PS_STALL : STATE_PS_ACC;  //next state




		 end
	       else if (ir2prs_psp_rd_i |                                          //PSP read sequence triggered
		        ir2prs_psp_wr_i |                                          //PSP write sequence triggered
		        ir2prs_rsp_rd_i |                                          //RSP read sequence triggered
		        ir2prs_rsp_wr_i)                                           //RSP read sequence triggered
		 begin




		 end
	       


    input  wire                              ir2prs_ps_rst_i,                      //reset parameter stack
    input  wire                              ir2prs_rs_rst_i,                      //reset return stack
    input  wire                              ir2prs_psp_rd_i,                      //read parameter stack pointer
    input  wire                              ir2prs_psp_wr_i,                      //write parameter stack pointer
    input  wire                              ir2prs_rsp_rd_i,                      //read return stack pointer
    input  wire                              ir2prs_rsp_wr_i,                      //write return stack pointer

	  





	endcase // case (state_reg)
     end // always @ *

   //Flip flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                              //asynchronous reset
       state_reg <= STATE_IDLE;				                            
     else if (sync_rst_i)                                                          //synchronous reset
       state_reg <= STATE_IDLE;				                            
     else                                                                          //state transition
       state_reg <= state_next;

   //Exceptions
   //----------
   assign prs2excpt_psuf_o = (rs0_tag_reg & ~ps0_tag_reg & &ir2prs_ups_tp_i[1:0])| //invalid PS0 <-> RS0 swap  
			     (              ~ps0_tag_reg &  ir2prs_ups_tp_i[2]  )| //invalid shift to PS0
			     (ps0_tag_reg & ~ps1_tag_reg & &ir2prs_ups_tp_i[3:2])| //invalid PS1 <-> PS0 swap 
			     (ps1_tag_reg & ~ps2_tag_reg & &ir2prs_ups_tp_i[5:4])| //invalid PS2 <-> PS1 swap 
			     (ps2_tag_reg & ~ps3_tag_reg & &ir2prs_ups_tp_i[7:6]); //invalid PS3 <-> PS2 swap  
   assign prs2excpt_rsuf_o = (ps0_tag_reg & ~rs0_tag_reg & &ir2prs_ups_tp_i[1:0])| //invalid RS0 <-> PS0 swap;
 			     (              ~rs0_tag_reg &  ir2prs_irs_tp_i[0]  ); //invalid shift to RS0
 
   //Stack data outputs
   //------------------
   assign pbus_dat_o		= ps0_reg;                                         //write data bus
   assign sbus_dat_o            = fsm_stack_sel ?                                  //1:RS, 0:PS
				  irs_reg[(16*IRS_DEPTH)-1:16*(IRS_DEPTH-1)] :     //unload RS
				  ips_reg[(16*IPS_DEPTH)-1:16*(IPS_DEPTH-1)];      //unload PS
   assign prs2alu_ps0_o		= ps0_reg;                                         //current PS0 (TOS)
   assign prs2alu_ps1_o		= ps1_reg;                                         //current PS1 (TOS+1)
   assign prs2fc_ps0_true_o     = |ps0_reg;                                        //PS0 in non-zero	
   assign prs2sagu_psp_next_o	= ps0_reg[SP_WIDTH-1:0];                           //parameter stack load value
   assign prs2sagu_rsp_next_o	= ps0_reg[SP_WIDTH-1:0];                           //return stack load value

   //Other outputs
   //-------------
   assign prs2sagu_stack_sel_o	= fsm_stack_sel;                                   //1:RS, 0:PS
   
   //Probe signals
   //-------------
   assign prb_state_o		= state_reg;                                       //current state
   assign prb_rs0_o		= rs0_reg;                                         //current RS0
   assign prb_ps0_o		= ps0_reg;                                         //current PS0
   assign prb_ps1_o		= ps1_reg;                                         //current PS1
   assign prb_ps2_o		= ps2_reg;                                         //current PS2
   assign prb_ps3_o		= ps3_reg;                                         //current PS3
   assign prb_rs0_tag_o		= rs0_tag_reg;                                     //current RS0 tag
   assign prb_ps0_tag_o		= ps0_tag_reg;                                     //current PS0 tag
   assign prb_ps1_tag_o		= ps1_tag_reg;                                     //current PS1 tag
   assign prb_ps2_tag_o		= ps2_tag_reg;                                     //current PS2 tag
   assign prb_ps3_tag_o		= ps3_tag_reg;                                     //current PS3 tag
   assign prb_ips_o		= ips_reg;                                         //current IPS
   assign prb_ips_tags_o	= ips_tags_reg;                                    //current IPS
   assign prb_irs_o		= irs_reg;                                         //current IRS
   assign prb_irs_tags_o	= irs_tags_reg;                                    //current IRS
   
endmodule // N1_prs
