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
    input  wire                              ir2us_ips_2_ps3_i,                     //IPS           -> PS3 
    input  wire                              ir2us_ps3_2_ips_i,                     //PS3           -> IPS 
    input  wire                              ir2us_rs0_2_irs_i,                     //RS0           -> IRS 
    input  wire                              ir2us_irs_2_rs0_i,                     //IRS           -> RS0 

    output wire                              us2ir_ps_push_bsy_o,                   //PS push requests stalled
    output wire                              us2ir_ps_pull_o,                       //PS pull requests stalled
    output wire                              us2ir_rs_push_bsy_o,                   //RS push stalled
    output wire                              us2ir_rs_pull_bsy_o,                   //PS pull stalled

    output wire                              us2ir_bsy_o,                           //PS and RS stalled

    //ALU interface
    input wire [15:0]                        alu2prs_ps0_next_i,                    //ALU result (lower word)
    input wire [15:0]                        alu2prs_ps1_next_i,                    //ALU result (upper word)

    //AGU interface
    input wire [15:0]                        agu2prs_rs0_next_i,                    //PC

    //EXCPT interface
    output reg                               prs2excpt_psof_o,                      //parameter stack overflow
    output reg                               prs2excpt_psuf_o,                      //parameter stack underflow
    output reg                               prs2excpt_rsof_o,                      //return stack overflow
    output reg                               prs2excpt_rsuf_o,                      //return stack underflow
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
    output wire [15:0]                       prb_us_r0_cell_o);                     //URS R0
    output wire [15:0]                       prb_us_p0_cell_o,                      //UPS P0
    output wire [15:0]                       prb_us_p1_cell_o,                      //UPS P1
    output wire [15:0]                       prb_us_p2_cell_o,                      //UPS P2
    output wire [15:0]                       prb_us_p3_cell_o);                     //URS R0
 										       
   //Registers
   //---------							       
  
   //PS depth				     					    
   reg  [STACK_DEPTH_WIDTH-1:0]              psd_reg;                               //current PS depth
   reg  [STACK_DEPTH_WIDTH-1:0]              psd_next;                              //next PS depth
   reg                                       psd_we;                                //PS depth write enable
					     
   //RS depth
   reg  [STACK_DEPTH_WIDTH-1:0]              rsd_reg;                               //current RS depth
   reg  [STACK_DEPTH_WIDTH-1:0]              rsd_next;                              //next RS depth
   reg                                       rsd_we;                                //RS depth write enable
					     					    
   //P0				     					    	       
   reg                                       ps0_reg;                               //current P0 cell value
   reg 					     ps0_next;                              //next p0 cell value   
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
 


   wire                                      ps_uf;                                 //PS underflow
   wire                                      rs_uf;                                 //RS underflow
  

   

   //Value checks
   assign  ps0_eq_0     = ~|rs0_reg;                                                 //true if PS0==0

   //Cell load
   assign  ips_loaded   =  psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h4};             //true if PSD>4
   assign  ps3_loaded   =  psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h3};             //true if PSD>3
   assign  ps2_loaded   =  psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h2};             //true if PSD>2
   assign  ps1_loaded   =  psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h1};             //true if PSD>1
   assign  ps0_loaded   =  psd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h0};             //true if PSD>0
   assign  irs_loaded   =  irs_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h0};             //true if RSD>1
   assign  rs0_loaded   =  rsd_reg > {{STACK_DEPTH_WIDTH-3{1'b0}},3'h0};             //true if RSD>0












   
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

   
   //Swap requests
   assign  swap_PS0_PS1 =
   assign  swap_PS1_PS2 =
   assign  swap_PS2_PS3 =

   //ROT extension

   assign  swap_PS0_PS2 =

   
   
   //Underflow checks
   assign  ps_uf       = (ir2prs_ps0_required_i                  & ~ps0_loaded              ) | //one cell required
                         (ir2prs_ps1_required_i                  & ~ps1_loaded              ) | //one cell required
                         (ir2us_ps0_2_rs0_i                      & ~ps0_loaded              ) | //push to RS
                         (ir2us_ps0_2_ps1_i &  ir2us_ps1_2_ps0_i & (ps0_loaded ^ ps1_loaded)) | //swap PS0 and PS1 
                         (ir2us_ps1_2_ps2_i &  ir2us_ps2_2_ps1_i & (ps1_loaded ^ ps2_loaded)) | //swap PS1 and PS2 
                         (ir2us_ps2_2_ps3_i &  ir2us_ps3_2_ps2_i & (ps2_loaded ^ ps3_loaded)) | //swap PS2 and PS3 
                         (ir2us_ps0_2_ps2_i &  ir2us_ps2_2_ps0_i & (ps0_loaded ^ ps2_loaded)) | //swap PS0 and PS2 (ROT extension)
                         (ir2us_ps0_2_ps2_i & ~ir2us_ps0_2_ps1_i & (ps0_loaded ^ ps1_loaded)) | //move PS0 to  PS2 (ROT extension)



   


   wire                                      prs_stalled;                           //stack operation stalled




   wire                                      ps_clr;                                //clear PS
   wire                                      rs_clr;                                //clear RS
    







   


   //Stall check
   

   

   FALSCH!!!!!
   
   assign  prs_bsy     = (ir2us_irs_2_rs0_i & irs2us_pull_bsy_i)  &                 //pull from IRS stalled
                         (ir2us_rs0_2_irs_i & irs2us_push_bsy_i)  &                 //push to IRS stalled
                         (ir2us_ips_2_ps3_i & ips2us_pull_bsy_i)  &                 //pull from IPS stalled
                         (ir2us_ps3_2_ips_i & ips2us_push_bsy_i);                   //push to IPS stalled


   
   //Stack clear requests
   assign  ps_clr      = ir2prs_psd_2_ps0_i & ps0_eq_0;                             //clear PS
   assign  rs_clr      = ir2prs_rsd_2_ps0_i & ps0_eq_0;                             //clear RS
 
   //Stack depth
   assign  psd_next    = ps_clr ? {STACK_DEPTH_WIDTH{1'b0}} :                       //clear PS
                         psd_reg + {{STACK_DEPTH_WIDTH-1{ir2us_ips_2_ps3_i}},1'b1}; //increment or decrement
   assign  rsd_next    = rs_clr ? {STACK_DEPTH_WIDTH{1'b0}} :                       //clear RS
                         rsd_reg + {{STACK_DEPTH_WIDTH-1{ir2us_irs_2_rs0_i}},1'b1}; //increment or decrement

   //Stack cells
   assign  rs0_next    = ({16{  ir2prs_agu_2_rs0_i}} & agu2prs_rs0_next_i)   |      //AGU output    -> RS0
	  	         ({16{   ir2us_ps0_2_rs0_i}} & rs0_reg)              |      //PS0           -> RS0 
	 	         ({16{   ir2us_irs_2_rs0_i}} & irs2us_pull_data_i);         //IRS           -> RS0 
   		        
   assign  ps0_next    = ({16{  ir2prs_lit_2_ps0_i}} & ir2prs_ps0_next_i)    |      //IR output     -> PS0    
                         ({16{  ir2prs_psd_2_ps0_i}} & psd_reg)              |      //PS depth      -> PS0
                         ({16{  ir2prs_rsd_2_ps0_i}} & rsd_reg)              |      //RS depth      -> PS0
                         ({16{ir2prs_excpt_2_ps0_i}} & excpt2prs_ps0_next_i) |      //EXCPT output  -> PS0
                         ({16{   ir2prs_bi_2_ps0_i}} & bi2prs_ps0_next_i)    |      //BI output     -> PS0
                         ({16{  ir2prs_alu_2_ps0_i}} & alu2prs_ps0_next_i)   |      //ALU output    -> PS0
                         ({16{   ir2us_ps1_2_ps0_i}} & ps1_reg)              |      //PS1           -> PS0  
                         ({16{   ir2us_rs0_2_ps0_i}} & rs0_reg)              |      //RS0           -> PS0
	      (EXT_ROT ? ({16{   ir2us_ps2_2_ps0_i}} & ps2_reg) : 16'h0000);        //PS2           -> PS0 (ROT extension) 
		       
   assign  ps1_next    = ({16{   ir2prs_alu_2_ps1_i}} & alu2prs_ps1_next_i)  |      //ALU output    -> PS1
                         ({16{    ir2us_ps2_2_ps1_i}} & ps2_reg)             |      //PS2           -> PS1     
                         ({16{    ir2us_ps0_2_ps1_i}} & ps0_reg);                   //PS0           -> PS1  
		       
   assign  ps2_next    = ({16{    ir2us_ps3_2_ps2_i}} & ps3_reg)             |      //PS3           -> PS2     
                         ({16{    ir2us_ps0_2_ps2_i}} & ps1_reg)             |      //PS1           -> PS2  
	      (EXT_ROT ? ({16{    ir2us_ps0_2_ps2_i}} & ps0_reg) : 16'h0000);       //PS0           -> PS2 (ROT extension) 
		       
   assign  ps3_next    = ({16{   ir2us_ps2_2_rs3_i}} & rs0_reg)              |      //PS2           -> PS3 
	 	         ({16{   ir2us_ips_2_ps3_i}} & irs2us_pull_data_i);         //IPS           -> PS3 








                      ({16{}} & ) |        
                      ({16{}} & ) |        





















										       
   //Program bus (wishbone)		  		                                 
   //----------------------							       
   assign pbus_dat_o           = p0_cell_reg;                                          //P0 is the only write data source
			       							       
   //ALU interface	       							       
   //-------------	       							       
   assign s2alu_ps0_o          = p0_cell_reg;                                          //current PS0 (TOS)
   assign s2alu_ps1_o          = p1_cell_reg;                                          //current PS1 (TOS+1)
										       
   //Flow control interface							       
   //----------------------							       
   assign us2fc_ready_o        = (~p3_tag_reg | ips2us_ready_i) &                      //propagate readiness from IPS
			         (~r0_tag_reg | irs2us_ready_i) &                      //propagate readiness from IRS
			         1'b1;                                                 //FSM is ready
										       
   assign us2fc_ps_overflow_o  = 1'b0;                                                 //PS overflow
   assign us2fc_ps_underflow_o = 1'b0;                                                 //PS underflow
   assign us2fc_rs_overflow_o  = 1'b0;                                                 //RS overflow
   assign us2fc_rs_underflow_o = 1'b0;                                                 //RS underflow
										       
   //IPS interface								       
   //----------------------							       
   assign us2ips_push_o        = 1'b0;                                                 //push cell from US to IPS
   assign us2ips_pull_o        = 1'b0;                                                 //pull cell from US to IPS
   assign us2ips_set_o         = 1'b0;                                                 //set SP
   assign us2ips_get_o         = 1'b0;                                                 //get SP
   assign us2ips_reset_o       = 1'b0;                                                 //reset SP
   assign us2ips_push_data_o   = p3_cell_reg;                                          //IS push data
										       
   //IRS interface								       
   //----------------------							       
   assign us2irs_push_o        = 1'b0;                                                 //push cell from US to IRS
   assign us2irs_pull_o        = 1'b0;                                                 //pull cell from US to IRS
   assign us2irs_set_o         = 1'b0;                                                 //set SP
   assign us2irs_get_o         = 1'b0;                                                 //get SP
   assign us2irs_reset_o       = 1'b0;                                                 //reset SP
   assign us2irs_push_data_o   = r0_cell_reg;                                          //IS push data

  
   //Transition decoding
   //-------------------
   //
   //
   //
   //
   //
   //
   
   
   assign move_alu_2_p0        =  ir2us_alu2ps0_i;                                     //ALU  -> P0
   assign move_p1_2_p0         =  (|EXT_ROT) ?  ir2us_us_tp_i[3] & ~ir2us_us_tp_i[2] : //P1   -> P0
                                                ir2us_us_tp_i[3];                      //
   assign move_p2_2_p0         =  (|EXT_ROT) ?  ir2us_us_tp_i[3] &  ir2us_us_tp_i[2] : //P2   -> P0
			                        1'b0;                                  //
   assign move_pbus_2_p0       =  ir2us_pbus2ps0_i;                                    //PBUS -> P0
   assign move_r0_2_p0         =  (|EXT_ROT) ? ~ir2us_us_tp_i[3] &  ir2us_us_tp_i[2] : //R0   -> P0
                                                                    ir2us_us_tp_i[2];  //
			       
   assign move_alu_2_p1        =  ir2us_alu2ps1_i;                                     //ALU  -> P1
   assign move_p0_2_p1         =  ir2us_us_tp_i[4];                                    //P0   -> P1
   assign move_p2_2_p1         =  ir2us_us_tp_i[5];                                    //P2   -> P1
			       
   assign move_p0_2_p2         =  (|EXT_ROT) ?  ir2us_us_tp_i[7] &  ir2us_us_tp_i[6] : //P0   -> P2
			                        1'b0;                                  //
   assign move_p1_2_p2         =  (|EXT_ROT) ? ~ir2us_us_tp_i[7] &  ir2us_us_tp_i[6] : //P1   -> P2
                                                                    ir2us_us_tp_i[6];  //
   assign move_p3_2_p2         =  (|EXT_ROT) ?  ir2us_us_tp_i[7] & ~ir2us_us_tp_i[6] : //P3   -> P2
                                                ir2us_us_tp_i[7];                      //
			       
   assign move_ips_2_p3        =                ir2us_us_tp_i[9] & ~ir2us_us_tp_i[8];  //IPS  -> P1
   assign move_p2_2_p3         =                                    ir2us_us_tp_i[8];  //P3   -> P1

   assign move_p3_2_ips        =                ir2us_us_tp_i[9] &  ir2us_us_tp_i[8];  //P3   -> IPS
			       
   assign move_irs_2_r0        =               ~ir2us_us_tp_i[1] &  ir2us_us_tp_i[0];  //IRS -> R0
   assign move_p0_2_r0         =                ir2us_us_tp_i[1];                      //P0  -> R0

   assign move_r0_2_irs        =                ir2us_us_tp_i[1] &  ir2us_us_tp_i[0];  //R0  -> IRS

   //Over and underflow conditions
   //-----------------------------
   //PS overflow
   assign ps_overflow  =  move_p3_2_ips    &                                            //shift P3 to IPS 
			  p3_tag_reg       &                                            //P3 holds data
			  ips2us_overflow_i;                                            //IPS overflow

   //PS underflow
   assign ps_underflow = ( ~p3_tag_reg               & move_ips_2_p3 & ~move_p3_2_p2) | //invalid P3 drop			  
			 ( ~p2_tag_reg               & move_p3_2_p2  & ~move_p2_2_p1) | //invalid P2 drop			  
			 ( ~p1_tag_reg               & move_p2_2_p1  & ~move_p1_2_p0) | //invalid P1 drop			  
			 ( ~p0_tag_reg               & move_p1_2_p0)                  | //invalid P0 drop			  
			 (~(p1_tag_reg & p0_tag_reg) & move_p0_2_p2)                  | //invalid P0 nip
			 ( ~p2_tag_reg               & move_p0_2_p2)                  | //invalid P2 ocer 			  
			 (~(p3_tag_reg & p2_tag_reg) & move_p3_2_p2  & move_p2_2_p3)  | //invalid P3<->P2 swap
			 (~(p2_tag_reg & p1_tag_reg) & move_p2_2_p1  & move_p1_2_p2)  | //invalid P2<->P1 swap
			 (~(p1_tag_reg & p0_tag_reg) & move_p1_2_p1  & move_p0_2_p1)  | //invalid P1<->P0 swap
			 ( ~p0_tag_reg               & move_p0_2_r0);                   //invalid P0->R0 shift

   //RS overflow
   assign rs_overflow  =  move_r0_2_irs    &                                            //shift R0 to IRS 
			  r0_tag_reg       &                                            //R0 holds data
			  irs2us_overflow_i;                                            //IRS overflow

   //RS underflow
   assign rs_underflow =  ( ~r0_tag_reg               & move_irs_2_r0)                 | //invalid R0 drop		
                          ( ~p0_tag_reg               & move_r0_2_p0);                   //invalid R0->P0 shift

   //US data paths
   //-------------
   //P0
   assign p0_cell_next = ;                                //next p0 cell value   
                         ({16{move_alu_2_p0}}  & ) |;                               //ALU  -> P0
                         ({16{move_p1_2_p0}}  & ) |;                               //ALU  -> P0
                         ({16{move_p1_2_p0}}  & ) |;                                //P1   -> P0
                         ({16{move_p2_2_p0}}  & ) |;                                //P2   -> P0
                         ({16{move_pbus_2_p0}}  & ) |;                              //PBUS -> P0
                         ({16{move_r0_2_p0}}  & ) |;                                //R0   -> P0



   assign p0_tag_next  = ;                                 //next P0 tag   

   wire                                   move_alu_2_p0;                               //ALU  -> P0
   wire                                   move_p1_2_p0;                                //P1   -> P0
   wire                                   move_p2_2_p0;                                //P2   -> P0
   wire                                   move_pbus_2_p0;                              //PBUS -> P0
   wire                                   move_r0_2_p0;                                //R0   -> P0







   assign p0_we        = ;                                       //P0 write enable


   
   
    //Flip flops
   //-----------

   //RS depth
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       rsd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (sync_rst_i)                                                              //synchronous reset
       rsd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (rs_rst)                                                                  //soft reset
       rsd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (rs_depth_we)                                                             //state transition
       rsd_reg <= rs_depth_next;

  //PS depth
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       psd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (sync_rst_i)                                                              //synchronous reset
       psd_reg <= {[STACK_DEPTH_WIDTH{1'b0}};
     else if (ps_rst)                                                                  //soft reset
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
   assign  prb_us_rsd_o      = rs_depth_reg;                                           //RS depth
   assign  prb_us_psd_o      = ps_depth_reg;                                           //PS depth
   assign  prb_us_r0_o       = r0_reg;                                                 //URS R0
   assign  prb_us_p0_o       = p0_reg;                                                 //UPS P0
   assign  prb_us_p1_o       = p1_reg;                                                 //UPS P1
   assign  prb_us_p2_o       = p2_reg;                                                 //UPS P2
   assign  prb_us_p3_o       = p3_reg;                                                 //UPS P3
   
endmodule // N1_us
