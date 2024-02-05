//###############################################################################
//# N1 - Upper Stacks                                                           #
//###############################################################################
//#    Copyright 2018 - 2024 Dirk Heisswolf                                     #
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
//#    This module implements the upper stacks of the N1 processor. The upper   #
//#    stacks contain the top most cells of the partameter and the return       #
//#    stack. They provide direct access to their cells and are capable of      #
//#    performing stack operations.                                             #
//#                                                                             #
//#  Imm.  |                  Upper Stack                   |    Upper   | Imm. #
//#  Stack |                                                |    Stack   | St.  #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#      |<->|  PS3  |<=>|  PS2  |<=>|  PS1  |<=>|  PS0  |<===>|  RS0  |<->|    #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#                                                 TOS     |     TOS           #
//#                          Parameter Stack                | Return Stack      #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 25, 2019                                                        #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_us
  #(parameter EXT_ROT           = 0,
    parameter STACK_DEPTH_WIDTH = 9)                                                //ROT extension
   (//Clock and reset                                                                  
    input wire                               clk_i,                                 //module clock
    input wire                               async_rst_i,                           //asynchronous reset
    input wire                               sync_rst_i,                            //synchronous reset
 
    //Stack outputs
    output wire                              us_ps0_o,                              //PS0
    output wire                              us_ps1_o,                              //PS1
    output wire                              us_rs0_o,                              //RS0

    //IR interface
    input  wire [15:0]                       ir2prs_ir_ps0_next_i,                  //IR output (literal value)
    input  wire                              ir2prs_ps0_required_i,                 //at least one cell on the PS required
    input  wire                              ir2prs_ps1_required_i,                 //at least two cells on the PS required
    input  wire                              ir2prs_rs0_required_i,                 //at least one cell on the RS rwquired
    input  wire                              ir2prs_ir_2_ps0_i,                     //IR output     -> PS0
    input  wire                              ir2prs_psd_2_ps0_i,                    //PS depth      -> PS0
    input  wire                              ir2prs_rsd_2_ps0_i,                    //RS depth      -> PS0
    input  wire                              ir2prs_excpt_2_ps0_i,                  //EXCPT output  -> PS0
    input  wire                              ir2prs_biu_2_ps0_i,                    //BI output     -> PS0
    input  wire                              ir2prs_alu_2_ps0_i,                    //ALU output    -> PS0
    input  wire                              ir2prs_alu_2_ps1_i,                    //ALU output    -> PS1
    input  wire                              ir2prs_ps0_2_rsd_i,                    //PS0           -> RS depth (clears RS)
    input  wire                              ir2prs_ps0_2_psd_i,                    //PS0           -> PS depth (clears PS)
    input  wire                              ir2prs_agu_2_rs0_i,                    //AGU output    -> RS0
    input  wire                              ir2us_ips_2_ps3_i,                     //IPS           -> PS3 
    input  wire                              ir2us_ps3_2_ips_i,                     //PS3           -> IPS 
    input  wire                              ir2us_ps3_2_ps2_i,                     //PS3           -> PS2 
    input  wire                              ir2us_ps2_2_ps3_i,                     //PS2           -> PS3 
    input  wire                              ir2us_ps2_2_ps1_i,                     //PS2           -> PS1 
    input  wire                              ir2us_ps1_2_ps2_i,                     //PS1           -> PS2 
    input  wire                              ir2us_ps1_2_ps0_i,                     //PS1           -> PS0 
    input  wire                              ir2us_ps0_2_ps1_i,                     //PS0           -> PS1 
    input  wire                              ir2us_ps2_2_ps0_i,                     //PS2           -> PS0 (ROT extension) 
    input  wire                              ir2us_ps0_2_ps2_i,                     //PS0           -> PS2 (ROT extension)
    input  wire                              ir2us_ps0_2_rs0_i,                     //PS0           -> RS0 
    input  wire                              ir2us_rs0_2_ps0_i,                     //RS0           -> PS0 
    input  wire                              ir2us_rs0_2_irs_i,                     //RS0           -> IRS 
    input  wire                              ir2us_irs_2_rs0_i,                     //IRS           -> RS0 
    output wire                              us2ir_bsy_o,                           //PS and RS stalled

    //ALU interface
    input wire [15:0]                        alu2prs_ps0_next_i,                    //ALU result (lower word)
    input wire [15:0]                        alu2prs_ps1_next_i,                    //ALU result (upper word)

    //AGU interface
    input wire [15:0]                        agu2prs_rs0_next_i,                    //PC

    //EXCPT interface
    output wire                              prs2excpt_psof_o,                      //parameter stack overflow
    output wire                              prs2excpt_psuf_o,                      //parameter stack underflow
    output wire                              prs2excpt_rsof_o,                      //return stack overflow
    output wire                              prs2excpt_rsuf_o,                      //return stack underflow
    input  wire [15:0]                       excpt2prs_ps0_next_i,                  //throw code

    //Bus interface
    input  wire [15:0]                       bi2prs_ps0_next_i,                     //read data
										       
    //IPS interface							       
    input  wire [15:0]                       ips2us_pull_data_i,                    //IPS pull data
    input  wire                              ips2us_push_bsy_i,                     //IPS push busy indicator
    input  wire                              ips2us_pull_bsy_i,                     //IPS pull busy indicator
    input  wire                              ips2us_empty_i,                        //IPS empty indicator
    input  wire                              ips2us_full_i,                         //IPS overflow indicator
    output wire [15:0]                       us2ips_push_data_o,                    //IPS push data
    output wire                              us2ips_push_o,                         //IPS push request
    output wire                              us2ips_pull_o,                         //IPS pull request
			       
    //IRS interface							       
    input  wire [15:0]                       irs2us_pull_data_i,                    //IRS pull data
    input  wire                              irs2us_push_bsy_i,                     //IRS push busy indicator
    input  wire                              irs2us_pull_bsy_i,                     //IRS pull busy indicator
    input  wire                              irs2us_empty_i,                        //IRS empty indicator
    input  wire                              irs2us_full_i,                         //IRS overflow indicator
    output wire [15:0]                       us2irs_push_data_o,                    //IRS push data
    output wire                              us2irs_push_o,                         //IRS push request
    output wire                              us2irs_pull_o,                         //IRS pull request
										       
    //Probe signals
    output wire [STACK_DEPTH_WIDTH-1:0]      prb_us_rsd_o,                          //RS depth
    output wire [STACK_DEPTH_WIDTH-1:0]      prb_us_psd_o,                          //PS depth
    output wire [15:0]                       prb_us_r0_o);                          //URS R0
    output wire [15:0]                       prb_us_p0_o,                           //UPS P0
    output wire [15:0]                       prb_us_p1_o,                           //UPS P1
    output wire [15:0]                       prb_us_p2_o,                           //UPS P2
    output wire [15:0]                       prb_us_p3_o);                          //URS R0
 										       
   //Registers
   //---------							       
  
   //PS depth				     					    
   wire [STACK_DEPTH_WIDTH-1:0]              psd_reg;                               //current PS depth
   wire [STACK_DEPTH_WIDTH-1:0]              psd_next;                              //next PS depth
   reg                                       psd_we;                                //PS depth write enable
					     
   //RS depth
   wire [STACK_DEPTH_WIDTH-1:0]              rsd_reg;                               //current RS depth
   wire [STACK_DEPTH_WIDTH-1:0]              rsd_next;                              //next RS depth
   reg                                       rsd_we;                                //RS depth write enable
					     					    
   //P0				     					    	       
   wire                                      ps0_reg;                               //current P0 cell value
   wire					     ps0_next;                              //next p0 cell value   
   reg 					     ps0_we;                                //P0 write enable
   					     
   //P1					     
   reg                                       ps1_reg;                               //current P1 cell value
   reg 					     ps1_next;                              //next P1 cell value   
   reg 					     ps1_we;                                //P1 write enable
					     
   //P2					     					    
   reg                                       ps2_reg;                               //current P2 cell value
   reg 					     ps2_next;                              //next p2 cell value   
   reg 					     ps2_we;                                //P2 write enable
					     
   //P3					     					    
   reg                                       ps3_reg;                               //current P3 cell value
   reg 					     ps3_next;                              //next P3 cell value   
   reg 					     ps3_we;                                //P3 write enable
  										       
   //R0				     					    	       
   reg                                       rs0_reg;                               //current R0 cell value
   reg 					     rs0_next;                              //next R0 cell value   
   reg 				             rs0_we;                                //R0 write enable  
 					     
   //Internal signals
   //-----------------
   wire                                      ps0_eq_0;                              //true if PS0==0
   wire                                      ps0_loaded;                            //true if PSD>=1
   wire                                      ps1_loaded;                            //true if PSD>=2
   wire                                      ps2_loaded;                            //true if PSD>=3
   wire                                      ps3_loaded;                            //true if PSD>=4
   wire                                      ips_loaded;                            //true if PSD>=5
   wire                                      rs0_loaded;                            //true if RSD>=1
   wire                                      irs_loaded;                            //true if RSD>=2
   wire                                      ps3_uf;                                //PS3 underflow
   wire                                      ps2_uf;                                //PS2 underflow
   wire                                      ps1_uf;                                //PS1 underflow
   wire                                      ps0_uf;                                //PS0 underflow
   wire                                      rs0_uf;                                //RS0 underflow
   wire                                      ps_uf;                                 //PS underflow
   wire                                      ps_of;                                 //PS overflow
   wire                                      rs_uf;                                 //RS underflow
   wire                                      rs_of;                                 //RS overflow
   wire                                      stall;                                 //stack operation stalled
   wire                                      ps_clr;                                //PS soft reset
   wire                                      rs_clr;                                //RS soft reset
    
   //Value checks  
   assign  ps0_eq_0     = ~|ps0_reg;                                                //true if PS0==0

   //Cell load
   assign  ips_loaded = psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h4} ? 1'b1 : 1'b0; //true if PSD>4
   assign  ps3_loaded = psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h3} ? 1'b1 : 1'b0; //true if PSD>3
   assign  ps2_loaded = psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h2} ? 1'b1 : 1'b0; //true if PSD>2
   assign  ps1_loaded = psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h1} ? 1'b1 : 1'b0; //true if PSD>1
   assign  ps0_loaded = psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h0} ? 1'b1 : 1'b0; //true if PSD>0
   assign  irs_loaded = irs_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h0} ? 1'b1 : 1'b0; //true if RSD>1
   assign  rs0_loaded = rsd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h0} ? 1'b1 : 1'b0; //true if RSD>0
   
   //Underflow checks
   assign  ps3_uf     = ~ps3_loaded &
			(( ir2us_ips_2_ps3_i & ~ir2us_ps3_2_ps2_i) |                //DROP rule
                         (~ir2us_ps3_2_ips_i &  ir2us_ps2_2_ps3_i) |                //DROP rule
                         ( ir2us_ps3_2_ps2_i &  ir2us_ps2_2_ps3_i));                //SWAP rule                         
   assign  ps2_uf     = ~ps2_loaded &
			(( ir2us_ps3_2_ps2_i & ~ir2us_ps2_2_ps1_i) |                //DROP rule
                         (~ir2us_ps2_2_ps3_i &  ir2us_ps1_2_ps2_i) |                //DROP rule
                         ( ir2us_ps3_2_ps2_i &  ir2us_ps2_2_ps3_i) |                //SWAP rule                         
                         ( ir2us_ps2_2_ps1_i &  ir2us_ps1_2_ps2_i) |                //SWAP rule                         
                         (~ir2us_ps2_2_ps3_i &  ir2us_ps0_2_ps2_i) |                //ROT  rule                         
                         (                      ir2us_ps2_2_ps0_i));                //ROT  rule                         
   assign  ps1_uf     = ~ps1_loaded &
			(( ir2us_ps2_2_ps1_i & ~ir2us_ps1_2_ps0_i) |                //DROP rule
                         (~ir2us_ps1_2_ps2_i &  ir2us_ps0_2_ps1_i) |                //DROP rule
                         ( ir2us_ps2_2_ps1_i &  ir2us_ps1_2_ps2_i) |                //SWAP rule                         
                         ( ir2us_ps1_2_ps0_i &  ir2us_ps0_2_ps1_i) |                //SWAP rule                         
                         (                      ir2us_ps0_2_ps2_i) |                //ROT  rule                         
                         (                      ir2us_ps2_2_ps0_i));                //ROT  rule                                                  
   assign  ps0_uf     = ~ps0_loaded &
			(( ir2us_ps1_2_0s0_i & ~ir2us_ps0_2_rs0_i) |                //DROP rule
                         (~ir2us_ps0_2_ps1_i &  ir2us_rs0_2_ps0_i) |                //DROP rule
                         ( ir2us_ps1_2_ps0_i &  ir2us_ps0_2_ps1_i) |                //SWAP rule                         
                         (                      ir2us_ps0_2_rs0_i) |                //Cross rule
                         (                      ir2us_ps0_2_ps2_i) |                //ROT  rule                         
                         (                      ir2us_ps2_2_ps0_i));                //ROT  rule                         
                          
   assign  rs0_uf     = ~ps0_loaded &
			(( ir2us_ps0_2_rs0_i & ~ir2us_rs0_2_irs_i) |                //DROP rule
                         (~ir2us_ps0_2_rs0_i &  ir2us_irs_2_rs0_i) |                //DROP rule
                         (                      ir2us_rs0_2_ps0_i));                //Cross rule
  
   //PS underflow
   assign  ps_uf      =  (ir2prs_ps0_required_i & ~ps0_loaded)     |                //one cell required
                         (ir2prs_ps1_required_i & ~ps1_loaded)     |                //two cells required 
                          ps3_uf                                   |                //PS3 underflow
                          ps2_uf                                   |                //PS2 underflow
                          ps1_uf                                   |                //PS1 underflow
                          ps0_uf;                                                   //PS0 underflow

   //PS overflow
   assign  ps_of      =    ir2us_ps3_2_ips_i & ips2us_full_i;                       //push onto full PS
  
   //RS underflow
   assign  rs_uf      = (ir2prs_rs0_required_i & ~rs0_loaded)      |
                         rs0_uf;                                                   //RS0 underflow

   //RS overflow
   assign  rs_of      =    ir2us_rs0_2_irs_i & irs2us_full_i;                       //push onto full RS
  
   //Stall
   assign  stall      =  (ir2us_ips_2_ps3_i & ips2us_pull_bsy_i)   |                //IPS -> PS3 stalled 
                         (ir2us_ps3_2_ips_i & ips2us_push_bsy_i)   |                //PS3 -> IPS stalled 
                         (ir2us_rs0_2_irs_i & irs2us_push_bsy_i)   |                //RS0 -> IRS stalled 
                         (ir2us_irs_2_rs0_i & irs2us_pull_bsy_i)   |                //IRS -> RS0 stalled 
                          ps_uf                                    |                //PS underflow
                          rs_uf;                                                    //RS underflow

   //Clear PS
   assign ps_clr      =   r2prs_ps0_2_psd_i & ps0_eq_0;                             //write zero to PSD

   //Clear RS
   assign rs_clr      =   r2prs_ps0_2_rsd_i & ps0_eq_0;                             //write zero to RSD
	     
   //PSD
   assign psd_next  =  psd_reg + {{STACK_DEPTH_WIDTH-1{ir2us_ips_2_ps3_i}},1'b1};
   assign psd_we    =  ~stall &
		       (ir2us_ips_2_ps3_i |
		        ir2us_ps3_2_ips_i);
   
   //RSD
   assign rsd_next  =  rsd_reg + {{STACK_DEPTH_WIDTH-1{ir2us_i3s_2_rs0_i}},1'b1};
   assign rsd_we    =  ~stall &
                       (ir2us_i3s_2_rs0_i |
                        ir2us_rs0_2_irs_i ); 
   
   //RS
   assign ps0_next  = ({16{   ir2prs_ir_2_ps0_i}} & ir2prs_ir_ps0_next_i) |         //IR output     -> PS0
                      ({16{  ir2prs_psd_2_ps0_i}} & psd_reg)              |         //PS depth      -> PS0
                      ({16{  ir2prs_rsd_2_ps0_i}} & rsd_reg)              |         //RS depth      -> PS0
                      ({16{ir2prs_excpt_2_ps0_i}} & excpt2prs_ps0_next_i) |         //EXCPT output  -> PS0
                      ({16{  ir2prs_biu_2_ps0_i}} & bi2prs_ps0_next_i)    |         //BI output     -> PS0
                      ({16{  ir2prs_alu_2_ps0_i}} & alu2prs_ps0_next_i)   |         //ALU output    -> PS0
                      ({16{   ir2us_ps1_2_ps0_i}} & ps1_reg)              |         //PS1           -> PS0 
                      ({16{   ir2us_ps2_2_ps0_i}} & ps2_reg)              |         //PS2           -> PS0 (ROT extension) 
                      ({16{   ir2us_rs0_2_ps0_i}} & rs0_reg);                       //RS0           -> PS0 
   assign ps0_we    = ~stall                                              &
                      (       ir2prs_ir_2_ps0_i                           |         //IR output     -> PS0
                             ir2prs_psd_2_ps0_i                           |         //PS depth      -> PS0
                             ir2prs_rsd_2_ps0_i                           |         //RS depth      -> PS0
                           ir2prs_excpt_2_ps0_i                           |         //EXCPT output  -> PS0
                             ir2prs_biu_2_ps0_i                           |         //BI output     -> PS0
                             ir2prs_alu_2_ps0_i                           |         //ALU output    -> PS0
                              ir2us_ps1_2_ps0_i                           |         //PS1           -> PS0 
                              ir2us_ps2_2_ps0_i                           |         //PS2           -> PS0 (ROT extension) 
                              ir2us_rs0_2_ps0_i);                                   //RS0           -> PS0 
   
   assign ps1_next  = ({16{  ir2prs_alu_2_ps1_i}} & alu2prs_ps1_next_i)   |         //ALU output    -> PS1
                      ({16{   ir2us_ps2_2_ps1_i}} & ps2_reg)              |         //PS2           -> PS1 
                      ({16{   ir2us_ps0_2_ps1_i}} & ps6_reg);                       //PS0           -> PS1 
   assign ps1_we    = ~stall                                              &
                      (      ir2prs_alu_2_ps1_i                           |         //ALU output    -> PS1
                              ir2us_ps2_2_ps1_i                           |         //PS2           -> PS1 
                              ir2us_ps0_2_ps1_i);                                   //PS0           -> PS1 

   assign ps2_next  = ({16{   ir2us_ps3_2_ps2_i}} & ps3_reg)              |         //PS3           -> PS2 
                      ({16{   ir2us_ps1_2_ps2_i}} & ps1_reg)              |         //PS1           -> PS2 
                      ({16{   ir2us_ps0_2_ps2_i}} & ps0_reg);                       //PS0           -> PS2 (ROT extension)
   assign ps2_we    = ~stall                                              &
                      (       ir2us_ps3_2_ps2_i                           |         //PS3           -> PS2 
                              ir2us_ps1_2_ps2_i                           |         //PS1           -> PS2 
                              ir2us_ps0_2_ps2_i);                                   //PS0           -> PS2 (ROT extension)

   assign ps3_next  = ({16{   ir2us_ips_2_ps3_i}} & ips2us_pull_data_i)   |         //IPS           -> PS3 
                      ({16{   ir2us_ps2_2_ps3_i}} & ps2_reg);                       //PS2           -> PS3 
   assign ps3_we    = ~stall                                              &
                      (       ir2us_ips_2_ps3_i                           |         //IPS           -> PS3 
                              ir2us_ps2_2_ps3_i);                                   //PS2           -> PS3 

   //RS 
   assign rs0_next  = ({16{  ir2prs_agu_2_rs0_i}} &  agu2prs_rs0_next_i)  |         //AGU output    -> RS0
                      ({16{   ir2us_ps0_2_rs0_i}} &  ps0_reg)             |         //PS0           -> RS0 
                      ({16{   ir2us_irs_2_rs0_i}} &  rs0_reg);                      //IRS           -> RS0 
   assign rs0_we    = ~stall                                              &
                      (      ir2prs_agu_2_rs0_i                           |         //AGU output    -> RS0
                              ir2us_ps0_2_rs0_i                           |         //PS0           -> RS0 
                              ir2us_irs_2_rs0_i);                                   //IRS           -> RS0 
 
   //Flip flops
   //-----------

   //RS depth
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       rsd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (sync_rst_i)                                                              //synchronous reset
       rsd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (rs_clr)                                                                  //soft reset
       rsd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (rs_depth_we)                                                             //state transition
       rsd_reg <= rs_depth_next;

  //PS depth
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       psd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (sync_rst_i)                                                              //synchronous reset
       psd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (ps_clr)                                                                  //soft reset
       psd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (ps_depth_we)                                                             //state transition
       psd_reg <= ps_depth_next;

   //R0
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       r0_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       r0_reg <= 16'h0000;
     else if (r0_we)                                                                   //state transition
       r0_reg <= r0_next;
  
   //P0
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p0_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       p0_reg <= 16'h0000;
     else if (p0_we)                                                                   //state transition
       p0_reg <= p0_next;
  
   //P1
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p1_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       p1_reg <= 16'h0000;
     else if (p1_we)                                                                   //state transition
       p1_reg <= p1_next;
  
   //P2
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p2_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       p2_reg <= 16'h0000;
     else if (p2_we)                                                                   //state transition
       p2_reg <= p2_next;
  
   //P3
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p3_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       p3_reg <= 16'h0000;
     else if (p3_we)                                                                   //state transition
       p3_reg <= p3_next;

   //Probe signals
   //-------------
   //Stack outputs
   assign  us_ps0_o            = ps0_reg;                                              //PS0
   assign  us_ps1_o            = ps1_reg;                                              //PS1
   assign  us_rs0_o            = rs0_reg;                                              //RS0
  
   //IR interface
   assign  us2ir_bsy_o         = stall;                                                //PS and RS stalled
			       
   //EXCPT interface	       
   assign  prs2excpt_psof_o    = rs_uf;                                                //parameter stack overflow
   assign  prs2excpt_psuf_o    = ps_uf;                                                //parameter stack underflow
   assign  prs2excpt_rsof_o    = rs_of;                                                //return stack overflow
   assign  prs2excpt_rsuf_o    = rs_uf;                                                //return stack underflow
			       
   //IPS interface	       						       
   assign  us2irs_push_data_o  = ps3_reg;                                              //IRS push data
   assign  us2irs_push_o       = ir2us_ps3_2_ips_i & ps3_loaded;                       //IRS push request
   assign  us2irs_pull_o       = ir2us_ips_2_ps3_i;                                    //IRS pull request
			       
   //IRS interface	       						       
   assign  us2irs_push_data_o  = rs0_reg;                                              //IRS push data
   assign  us2irs_push_o       = ir2us_rs0_2_irs_i & rs0_loaded;                       //IRS push request
   assign  us2irs_pull_o       =  ir2us_irs_2_rs0_i;                                   //IRS pull request
  
   //Probe signals
   //-------------
   assign  prb_us_rsd_o        = rs_depth_reg;                                         //RS depth
   assign  prb_us_psd_o        = ps_depth_reg;                                         //PS depth
   assign  prb_us_r0_o         = r0_reg;                                               //URS R0
   assign  prb_us_p0_o         = p0_reg;                                               //UPS P0
   assign  prb_us_p1_o         = p1_reg;                                               //UPS P1
   assign  prb_us_p2_o         = p2_reg;                                               //UPS P2
   assign  prb_us_p3_o         = p3_reg;                                               //UPS P3


   //Assertions
   //----------
`ifdef FORMAL
   //Input checks
   //------------
   //ir2us_ips_2_ps3_i and ir2us_ps3_2_ips_i must not be asserted at the same time 
   assert (&{~ir2us_ips_2_ps3_i & ~ir2us_ps3_2_ips_i} |
           &{ ir2us_ips_2_ps3_i & ~ir2us_ps3_2_ips_i} |
           &{~ir2us_ips_2_ps3_i &  ir2us_ps3_2_ips_i});

   //ir2us_rs0_2_irs_i and ir2us_irs_2_rs0_i must not be asserted at the same time
   assert (&{~ir2us_rs0_2_irs_i & ~ir2us_irs_2_rs0_i} |
           &{ ir2us_rs0_2_irs_i & ~ir2us_irs_2_rs0_i} |
           &{~ir2us_rs0_2_irs_i &  ir2us_irs_2_rs0_i});


   //If the ROT extension bypass towards PS2 is used, no other stack cells may be pushed onto PS2
   assert ir2us_ps0_2_ps2_i ? ~ir2us_ps3_2_ps2_i & ~ir2us_ps1_2_ps2_i : 1'b1;

   //If the ROT extension bypass towards PS2 is used, no other stack cells may be pushed onto PS2
   assert ir2us_ps0_2_ps2_i ? ~ir2us_ps3_2_ps2_i & ~ir2us_ps1_2_ps2_i : 1'b1;






   
endmodule // N1_us



		   


   
//   //Shift pattern decode
//   //      <9>        <8 7>       <6 5>       <4 3>       <2 | 1>        <0> 
//   //  ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +---
//   // IPS |<->|  PS3  |<=>|  PS2  |<=>|  PS1  |<=>|  PS0  |<===>|  RS0  |<->| IRS 
//   //  ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +---
//   //                         Parameter Stack                | Return Stack    
//   assign  shift_ips_2_ps3  = ir2prs_shiftpat_i[]                      //IPS -> PS3 
//   assign  shift_ps3_2_ips  = ir2prs_shiftpat_i[]                      //PS3 -> IPS 
//   assign  shift_ps3_2_ps2  = ir2prs_shiftpat_i[7]                      //PS3 -> PS2 
//   assign  shift_ps2_2_ps3  = ir2prs_shiftpat_i[8]                      //PS2 -> PS3 
//   assign  shift_ps2_2_ps1  = ir2prs_shiftpat_i[]                      //PS2 -> PS1 
//   assign  shift_ps1_2_ps2  = ir2prs_shiftpat_i[]                      //PS1 -> PS2 
//   assign  shift_ps1_2_ps0  = ir2prs_shiftpat_i[]                      //PS1 -> PS0 
//   assign  shift_ps0_2_ps1  = ir2prs_shiftpat_i[]                      //PS0 -> PS1 
//   assign  shift_ps2_2_ps0  = ir2prs_shiftpat_i[]                      //PS2 -> PS0 (ROT extension) 
//   assign  shift_ps0_2_ps2  = ir2prs_shiftpat_i[]                      //PS0 -> PS2 (ROT extension)
//   assign  shift_ps0_2_rs0  = ir2prs_shiftpat_i[]                      //PS0 -> RS0 
//   assign  shift_rs0_2_ps0  = ir2prs_shiftpat_i[]                      //RS0 -> PS0 
//   assign  shift_ips_2_ps3  = ir2prs_shiftpat_i[]                      //IPS -> PS3 
//   assign  shift_ps3_2_ips  = ir2prs_shiftpat_i[]                      //PS3 -> IPS 
//   assign  shift_rs0_2_irs  = ir2prs_shiftpat_i[]                      //RS0 -> IRS 
//   assign  shift_irs_2_rs0  = ir2prs_shiftpat_i[]                      //IRS -> RS0 

