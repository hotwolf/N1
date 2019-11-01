//###############################################################################
//# N1 - Upper Stacks                                                           #
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
  #(parameter EXT_ROT  = 0)                                                            //ROT extension
   (//Clock and reset					                               
    input wire                            clk_i,                                       //module clock
    input wire                            async_rst_i,                                 //asynchronous reset
    input wire                            sync_rst_i,                                  //synchronous reset
					  		                                 
    //Program bus (wishbone)		  		                                 
    input  wire [15:0]                    pbus_dat_o,                                  //write data bus
    input  wire [15:0]                    pbus_dat_i,                                  //read data bus
										       
    //Internal signals								       
    //----------------								       
    //ALU interface								       
    output wire [15:0]                    s2alu_ps0_o,                                 //current PS0 (TOS)
    output wire [15:0]                    s2alu_ps1_o,                                 //current PS1 (TOS+1)
    input  wire [15:0]                    lu2us_ps0_next_i,                            //new PS0 (TOS)
    input  wire [15:0]                    lu2us_ps1_next_i,                            //new PS1 (TOS+1)
										       
    //Flow control interface							       
    output wire                           us2fc_ready_o,                               //stacks not ready
    output wire                           us2fc_ps_overflow_o,                         //PS overflow
    output wire                           us2fc_ps_underflow_o,                        //PS underflow
    output wire                           us2fc_rs_overflow_o,                         //RS overflow
    output wire                           us2fc_rs_underflow_o,                        //RS underflow
    output wire                           us2fc_ps0_false_o,                           //PS0 is zero
    input  wire                           fc2us_hold_i,                                //hold any state tran
    input  wire                           fc2us_dat2ps0_i,                             //capture read data
    input  wire                           fc2us_tc2ps0_i,                              //capture throw code
    input  wire                           fc2us_isr2ps0_i,                             //capture ISR
										       
    //IPS interface								       
    output wire                           us2ips_push_o,                               //push cell from US to IPS
    output wire                           us2ips_pull_o,                               //pull cell from US to IPS
    output wire                           us2ips_set_o,                                //set SP
    output wire                           us2ips_get_o,                                //get SP
    output wire                           us2ips_reset_o,                              //reset SP
    output wire [15:0]                    us2ips_push_data_o,                          //IS push data
    input  wire                           ips2us_ready_i,                              //IS is ready for the next command
    input  wire                           ips2us_overflow_i,                           //LS+IPS are full or overflowing
    input  wire                           ips2us_underflow_i,                          //LS+IPS are empty
    input  wire [15:0]                    ips2us_pull_data_i,                          //IPS pull data
										       
    //Instruction register interface						       
    input wire                            ir2us_alu2ps0_i,                             //ALU output  -> PS0
    input wire                            ir2us_alu2ps1_i,                             //ALU output  -> PS1
    input wire                            ir2us_lit2ps0_i,                             //literal     -> PS0
    input wire                            ir2us_pc2rs0_i,                              //PC          -> RS0
    input wire                            ir2us_ps_rst_i,                              //reset parameter stack
    input wire                            ir2us_rs_rst_i,                              //reset return stack
    input wire                            ir2us_psp_get_i,                             //read parameter stack pointer
    input wire                            ir2us_psp_set_i,                             //write parameter stack pointer
    input wire                            ir2us_rsp_get_i,                             //read return stack pointer
    input wire                            ir2us_rsp_set_i,                             //write return stack pointer
    input wire [15:0]                     ir2us_lit_val_i,                             //literal value
    input wire [9:0]                      ir2us_us_tp_i,                               //upper stack transition pattern

    //IRS interface
    output wire                           us2irs_push_o,                               //push cell from US to IRS
    output wire                           us2irs_pull_o,                               //pull cell from US to IRS
    output wire                           us2irs_set_o,                                //set SP
    output wire                           us2irs_get_o,                                //get SP
    output wire                           us2irs_reset_o,                              //reset SP
    output wire [15:0]                    us2irs_push_data_o,                          //IS push data
    input  wire                           irs2us_ready_i,                              //IS is ready for the next command
    input  wire                           irs2us_overflow_i,                           //LS+IRS are full or overflowing
    input  wire                           irs2us_underflow_i,                          //LS+IRS are empty
    input  wire [15:0]                    irs2us_pull_data_i,                          //IRS pull data
										       
    //Probe signals								       
    output wire [15:0]                    prb_us_p0_cell_o,                            //UPS cell P0
    output wire [15:0]                    prb_us_p1_cell_o,                            //UPS cell P1
    output wire [15:0]                    prb_us_p2_cell_o,                            //UPS cell P2
    output wire [15:0]                    prb_us_p3_cell_o,                            //UPS cell P3
    output wire [15:0]                    prb_us_r0_cell_o,                            //URS cell R0
    output wire                           prb_us_p0_tag_o,                             //UPS cell P0
    output wire                           prb_us_p1_tag_o,                             //UPS cell P1
    output wire                           prb_us_p2_tag_o,                             //UPS cell P2
    output wire                           prb_us_p3_tag_o,                             //UPS cell P3
    output wire                           prb_us_r0_tag_o,                             //URS cell R0
    output wire [3:0]                     prb_us_state_o);                             //state register
										       
   //P0										       
   reg                                    p0_cell_reg;                                 //current P0 cell value
   reg 					  p0_cell_next;                                //next p0 cell value   
   reg                                    p0_tag_reg;                                  //current P0 tag
   reg 					  p0_tag_next;                                 //next P0 tag   
   reg 					  p0_we;                                       //P0 write enable
   wire                                   move_alu_2_p0;                               //ALU  -> P0
   wire                                   move_p1_2_p0;                                //P1   -> P0
   wire                                   move_p2_2_p0;                                //P2   -> P0
   wire                                   move_pbus_2_p0;                              //PBUS -> P0
   wire                                   move_r0_2_p0;                                //R0   -> P0
   
   //P1
   reg                                    p1_cell_reg;                                 //current P1 cell value
   reg 					  p1_cell_next;                                //next P1 cell value   
   reg                                    p1_tag_reg;                                  //current P1 tag
   reg 					  p1_tag_next;                                 //next P1 tag   
   reg 					  p1_we;                                       //P1 write enable
   wire                                   move_alu_2_p1;                               //ALU  -> P1
   wire                                   move_p0_2_p1;                                //P0   -> P1
   wire                                   move_p2_2_p1;                                //P2   -> P1
 										       
   //P2										       
   reg                                    p2_cell_reg;                                 //current P2 cell value
   reg 					  p2_cell_next;                                //next p2 cell value   
   reg                                    p2_tag_reg;                                  //current P2 tag
   reg 					  p2_tag_next;                                 //next P2 tag   
   reg 					  p2_we;                                       //P2 write enable
   wire                                   move_p0_2_p2;                                //P0   -> P2
   wire                                   move_p1_2_p2;                                //P1   -> P2
   wire                                   move_p3_2_p2;                                //P3   -> P2
    										       
   //P3										       
   reg                                    p3_cell_reg;                                 //current P3 cell value
   reg 					  p3_cell_next;                                //next P3 cell value   
   reg                                    p3_tag_reg;                                  //current P3 tag
   reg 					  p3_tag_next;                                 //next P3 tag
   reg 					  p3_we;                                       //P3 write enable
   wire                                   move_ips_2_p3;                               //IPS  -> P1
   wire                                   move_p2_2_p3;                                //P3   -> P1
 										       
   //IPS
   wire                                   move_p3_2_ips;                               //P3  -> IPS

   //R0										       
   reg                                    r0_cell_reg;                                 //current R0 cell value
   reg 					  r0_cell_next;                                //next R0 cell value   
   reg                                    r0_tag_reg;                                  //current R0 tag
   reg 					  r0_tag_next;                                 //next R0 tag  
   reg 					  r0_we;                                       //R0 write enable  
   wire                                   move_irs_2_r0;                               //IRS -> R0
   wire                                   move_p0_2_r0;                                //P0  -> R0

   //IRS
   wire                                   move_r0_2_irs;                               //R0  -> IRS

   //Over and underflow conditions
   wire                                   ps_overflow;                                 //PS overflow
   wire                                   ps_underflow;                                //PS undrflow
   wire                                   rs_overflow;                                 //RS overflow
   wire                                   rs_underflow;                                //RS undrflow


										       
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
   //P0
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p0_cell_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       p0_cell_reg <= 16'h0000;
     else if (p0_we)                                                                   //state transition
       p0_cell_reg <= p0_cell_next;
  
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p0_tag_reg  <= 1'b0;
     else if (sync_rst_i)                                                              //synchronous reset
       p0_tag_reg  <= 1'b0;
     else if (p0_we)                                                                   //state transition
       p0_tag_reg  <= p0_tag_next;
  
   //P1
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p1_cell_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       p1_cell_reg <= 16'h0000;
     else if (p1_we)                                                                   //state transition
       p1_cell_reg <= p1_cell_next;
  
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p1_tag_reg  <= 1'b0;
     else if (sync_rst_i)                                                              //synchronous reset
       p1_tag_reg  <= 1'b0;
     else if (p1_we)                                                                   //state transition
       p1_tag_reg  <= p1_tag_next;
  
   //P2
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p2_cell_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       p2_cell_reg <= 16'h0000;
     else if (p2_we)                                                                   //state transition
       p2_cell_reg <= p2_cell_next;
  
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p2_tag_reg  <= 1'b0;
     else if (sync_rst_i)                                                              //synchronous reset
       p2_tag_reg  <= 1'b0;
     else if (p2_we)                                                                   //state transition
       p2_tag_reg  <= p2_tag_next;
  
    //P3
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p3_cell_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       p3_cell_reg <= 16'h0000;
     else if (p3_we)                                                                   //state transition
       p3_cell_reg <= p3_cell_next;
  
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       p3_tag_reg  <= 1'b0;
     else if (sync_rst_i)                                                              //synchronous reset
       p3_tag_reg  <= 1'b0;
     else if (p3_we)                                                                   //state transition
       p3_tag_reg  <= p3_tag_next;
  
   //R0
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       r0_cell_reg <= 16'h0000;
     else if (sync_rst_i)                                                              //synchronous reset
       r0_cell_reg <= 16'h0000;
     else if (r0_we)                                                                   //state transition
       r0_cell_reg <= r0_cell_next;
  
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       r0_tag_reg  <= 1'b0;
     else if (sync_rst_i)                                                              //synchronous reset
       r0_tag_reg  <= 1'b0;
     else if (r0_we)                                                                   //state transition
       r0_tag_reg  <= r0_tag_next;
  
   //FSM
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       state_reg <= STATE_IDLE;
     else if (sync_rst_i)                                                              //synchronous reset
       state_reg <= STATE_IDLE;
     else                                                                              //state transition
       state_reg <= state_next;
  
   //Probe signals
   //-------------
   assign prb_us_p0_cell_o = p0_cell_reg;                                              //UPS cell P0
   assign prb_us_p1_cell_o = p1_cell_reg;                                              //UPS cell P1
   assign prb_us_p2_cell_o = p2_cell_reg;                                              //UPS cell P2
   assign prb_us_p3_cell_o = p3_cell_reg;                                              //UPS cell P3
   assign prb_us_r0_cell_o = r0_cell_reg;                                              //URS cell R0
   assign prb_us_p0_tag_o  = p0_tag_reg;                                               //UPS cell P0
   assign prb_us_p1_tag_o  = p1_tag_reg;                                               //UPS cell P1
   assign prb_us_p2_tag_o  = p2_tag_reg;                                               //UPS cell P2
   assign prb_us_p3_tag_o  = p3_tag_reg;                                               //UPS cell P3
   assign prb_us_r0_tag_o  = r0_tag_reg;                                               //URS cell R0
   assign prb_us_state_o   = state_reg;                                                //state instruction register
   
endmodule // N1_us
