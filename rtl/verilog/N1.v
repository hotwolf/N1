//###############################################################################
//# N1 - Top Level                                                              #
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
//#    This is the top level block of the N1 processor.                         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1
  #(parameter   RST_ADR    = 'h0000,                           //address of first instruction
    parameter   SP_WIDTH   =  8,                               //width of a stack pointer
    localparam  CELL_WIDTH = 16,                               //width of a cell
    localparam  PC_WIDTH   = 14,                               //width of the program counter
    localparam  UPS_DEPTH  = 5,                                //depth of the upper parameter stack 
    localparam  IPS_DEPTH  = 8,                                //depth of the immediate parameter stack
    localparam  URS_DEPTH  = 1,                                //depth of the upper return stack 
    localparam  IRS_DEPTH  = 8)                                //depth of the immediate return stack

   (//Clock and reset
    input  wire                              clk_i,            //module clock
    input  wire                              async_rst_i,      //asynchronous reset
    input  wire                              sync_rst_i,       //synchronous reset
					     
    //Program bus			     
    output wire                              pbus_cyc_o,       //bus cycle indicator       +-
    output wire                              pbus_stb_o,       //access request            | initiator to target
    output wire [PC_WIDTH-1:0]               pbus_adr_o,       //address bus               |
    output wire                              pbus_tga_imadr_o, //immediate (short) address +-	    
    input  wire                              pbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                              pbus_err_i,       //error indicator           | target
    input  wire                              pbus_rty_i,       //retry request             | to
    input  wire                              pbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]             pbus_dat_i,       //read data bus             +-
					     
    //Data bus				     
    output wire                              dbus_cyc_o,       //bus cycle indicator       +-
    output wire                              dbus_stb_o,       //access request            | 
    output wire                              dbus_we_o,        //write enable              | initiator
    output wire [(CELL_WIDTH/8)-1:0]         dbus_sel_o,       //write data selects        | to	    
    output wire [CELL_WIDTH-1:0]             dbus_adr_o,       //address bus               | target   
    output wire [CELL_WIDTH-1:0]             dbus_dat_o,       //write data bus            |
    output wire                              dbus_tga_imadr_o, //immediate (short) address +-	    
    input  wire                              dbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                              dbus_err_i,       //error indicator           | target
    input  wire                              dbus_rty_i,       //retry request             | to
    input  wire                              dbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]             dbus_dat_i,       //read data bus             +-
					     
    //Stack bus				     
    output wire                              sbus_cyc_o,       //bus cycle indicator       +-
    output wire                              sbus_stb_o,       //access request            | 
    output wire                              sbus_we_o,        //write enable              | initiator
    output wire [SP_WIDTH-1:0]               sbus_adr_o,       //address bus               | to	    
    output wire [CELL_WIDTH-1:0]             sbus_dat_o,       //write data bus            | target   
    output wire                              sbus_tga_ps_o,    //parameter stack access    |
    output wire                              sbus_tga_rs_o,    //return stack access       +-
    input  wire                              sbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                              sbus_err_i,       //error indicator           | target
    input  wire                              sbus_rty_i,       //retry request             | to
    input  wire                              sbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]             sbus_dat_i,       //read data bus             +-
					     
    //Interrupt interface		     
    output wire                              irq_ack_o,        //interrupt acknowledge           
    input  wire [PC_WIDTH-1:0]               irq_vec_i,        //requested interrupt vector 
					     
    //Probe signals			     
    //Program counter   		     
    output wire [PC_WIDTH-1:0]               prb_pc_o,         //program counter
    //Instruction register  		     
    output wire [CELL_WIDTH-1:0]             prb_ir_o,         //instruction register
    //Parameter stack
    output wire [(UPS_DEPTH*CELL_WIDTH)-1:0] prb_ups_o,        //upper parameter stack content          
    output wire [UPS_DEPTH-1:0]              prb_ups_stat_o,   //upper parameter stack status
    output wire [(IPS_DEPTH*CELL_WIDTH)-1:0] prb_ips_o,        //intermediate parameter stack content          
    output wire [IPS_DEPTH-1:0]              prb_ips_stat_o,   //intermediate parameter stack status
    output wire [SP_WIDTH-1:0]               prb_lps_sp_o,     //lower parameter stack pointer
    //Return stack
    output wire [(URS_DEPTH*CELL_WIDTH)-1:0] prb_urs_o,        //upper parameter stack content          
    output wire [URS_DEPTH-1:0]              prb_urs_stat_o,   //upper parameter stack status
    output wire [(IRS_DEPTH*CELL_WIDTH)-1:0] prb_irs_o,        //intermediate parameter stack content          
    output wire [IRS_DEPTH-1:0]              prb_irs_stat_o,   //intermediate parameter stack status
    output wire [SP_WIDTH-1:0]               prb_lrs_sp_o);    //lower parameter stack pointer

   //Internal Signals
   //----------------

   //Intermediate parameter stack interface
   wire [CELL_WIDTH-1:0] 		   ips_tos;          //data output: IS->US
   wire                                    ips_filled;       //immediate stack holds data
   wire                                    ips_psh_rdy;      //ready for push operation
   wire                                    ips_pul_rdy;      //ready for pull operation
   wire [CELL_WIDTH-1:0]                   ips_tos;          //data input: IS<-US
   wire                                    ips_psh;          //push data to TOS
   wire                                    ips_pul;          //pull data from TOS

   //Intermediate return stack interface
   wire [CELL_WIDTH-1:0] 		   irs_tos;          //data output: IS->US
   wire                                    irs_filled;       //immediate stack holds data
   wire                                    irs_psh_rdy;      //ready for push operation
   wire                                    irs_pul_rdy;      //ready for pull operation
   wire [CELL_WIDTH-1:0]                   irs_tos;          //data input: IS<-US
   wire                                    irs_psh;          //push data to TOS
   wire                                    irs_pul;          //pull data from TOS
					
   //Lower parameter stack bus
   wire 				   lpsbus_cyc;       //bus cycle indicator       +-
   wire 				   lpsbus_stb;       //access request            | initiator
   wire 				   lpsbus_we;        //write enable              | to	   
   wire [SP_WIDTH-1:0] 			   lpsbus_adr;       //address bus               | target    
   wire [CELL_WIDTH-1:0] 		   lpsbus_wdat;      //write data bus            +-
   wire 				   lpsbus_ack;       //bus cycle acknowledge     +-
   wire 				   lpsbus_err;       //error indicator           | target
   wire 				   lpsbus_rty;       //retry request             | to
   wire 				   lpsbus_stall;     //access delay              | initiator
   wire [CELL_WIDTH-1:0] 		   lpsbus_rdat;      //read data bus             +-
							     
   //Lower return stack bus				     	     
   wire 				   lrsbus_cyc;       //bus cycle indicator       +-
   wire 				   lrsbus_stb;       //access request            | initiator
   wire 				   lrsbus_we;        //write enable              | to	   
   wire [SP_WIDTH-1:0] 			   lrsbus_adr;       //address bus               | target    
   wire [CELL_WIDTH-1:0] 		   lrsbus_wdat;      //write data bus            +-
   wire 				   lrsbus_ack;       //bus cycle acknowledge     +-
   wire 				   lrsbus_err;       //error indicator           | target
   wire 				   lrsbus_rty;       //retry request             | to
   wire 				   lrsbus_stall;     //access delay              | initiator
   wire [CELL_WIDTH-1:0] 		   lrsbus_rdat;      //read data bus             +-

   //Exceptions
   wire                                    excpt_lpsbus;     //PS bus error
   wire                                    excpt_lrsbus;     //RS bus error

   //Lower return stack AGU
   wire [SP_WIDTH:0]                       lrs_agu_sp;       //current address
   wire                                    lrs_agu_inc;      //increment address
   wire                                    lrs_agu_dec;      //decrement address
   wire [SP_WIDTH:0]                       lrs_agu_res;      //result






   


   //Intermediate parameter stack
   //----------------------------
   N1_is
     #(.SP_WIDTH   (SP_WIDTH),                               //width of a stack pointer
    .CELL_WIDTH      = 16,                                   //cell width
    .IS_DEPTH        =  8,                                   //depth of the intermediate stack
    .LS_GROW_UPWARDS =  0)                                   //grow lower stack towards lower addresses
   N1_ips				                     
     (//Clock and reset			                     
      .clk_i		(clk_i),                             //module clock
      .async_rst_i	(async_rst_i),                       //asynchronous reset
      .sync_rst_i	(sync_rst_i),                        //synchronous reset
					                     
      //Intermediate stack interface	                     
      .is_tos_o		(ips_tos),                           //data output: IS->US
      .is_filled_o      (ips_filled),
      .is_psh_rdy_o	(ips_psh_rdy),                       //ready for push operation
      .is_pul_rdy_o	(ips_pul_rdy),                       //ready for pull operation
      .is_tos_i	        (ips_tos),                           //data input: IS<-US
      .is_psh_i	        (ips_psh),                           //push data to TOS
      .is_pul_i	        (ips_pul),                           //pull data from TOS
  
      //Lower stack bus
      .lsbus_cyc_o	(lpsbus_cyc),                        //bus cycle indicator      +-
      .lsbus_stb_o	(lpsbus_stb),                        //access request           | initiator 
      .lsbus_we_o	(lpsbus_we),                         //write enable             | to	   
      .lsbus_adr_o	(lpsbus_adr),                        //address bus              | target    
      .lsbus_dat_o	(lpsbus_dat),                        //write data bus           +-
      .lsbus_ack_i	(lpsbus_ack),                        //bus cycle acknowledge    +-
      .lsbus_err_i	(lpsbus_err),                        //error indicator          | target
      .lsbus_rty_i	(lpsbus_rty),                        //retry request            | to
      .lsbus_stall_i	(lpsbus_stall),                      //access delay             | initiator
      .lsbus_dat_i	(lpsbus_dat),                        //read data bus            +-
 
      //Exceptions
      .excpt_lsbus_o    (excpt_lpsbus),                      //bus error
  
      //External address in-/decrementer
      .sagu_sp_o         (lps_agu_sp),                        //current address
      .sagu_inc_o        (lps_agu_inc),                       //increment address
      .sagu_dec_o        (lps_agu_dec),                       //decrement address
      .sagu_res_i        (lps_agu_res),                       //result

      //Probe signals
      .prb_is_o         (prb_ips_o),                         //intermediate stack content
      .prb_is_stat_o    (prb_ips_stat_o),                    //intermediate stack status
      .prb_ls_sp_o      (prb_lps_sp_o));                     //lower stack pointer

   //Intermediate return stack
   //-------------------------
   N1_is
     #(.SP_WIDTH   (SP_WIDTH),                               //width of a stack pointer
    .CELL_WIDTH      = 16,                                   //cell width
    .IS_DEPTH        =  8,                                   //depth of the intermediate stack
    .LS_GROW_UPWARDS =  1)                                   //grow lower stack towards higher addresses
   N1_irs				                     
     (//Clock and reset			                     
      .clk_i		(clk_i),                             //module clock
      .async_rst_i	(async_rst_i),                       //asynchronous reset
      .sync_rst_i	(sync_rst_i),                        //synchronous reset
					                     
      //Intermediate stack interface	                     
      .is_tos_o		(irs_tos),                           //data output: IS->US
      .is_filled_o      (irs_filled),
      .is_psh_rdy_o	(irs_psh_rdy),                       //ready for push operation
      .is_pul_rdy_o	(irs_pul_rdy),                       //ready for pull operation
      .is_tos_i	        (irs_tos),                           //data input: IS<-US
      .is_psh_i	        (irs_psh),                           //push data to TOS
      .is_pul_i	        (irs_pul),                           //pull data from TOS
  
      //Lower stack bus
      .lsbus_cyc_o	(lrsbus_cyc),                        //bus cycle indicator      +-
      .lsbus_stb_o	(lrsbus_stb),                        //access request           | initiator 
      .lsbus_we_o	(lrsbus_we),                         //write enable             | to	   
      .lsbus_adr_o	(lrsbus_adr),                        //address bus              | target    
      .lsbus_dat_o	(lrsbus_dat),                        //write data bus           +-
      .lsbus_ack_i	(lrsbus_ack),                        //bus cycle acknowledge    +-
      .lsbus_err_i	(lrsbus_err),                        //error indicator          | target
      .lsbus_rty_i	(lrsbus_rty),                        //retry request            | to
      .lsbus_stall_i	(lrsbus_stall),                      //access delay             | initiator
      .lsbus_dat_i	(lrsbus_dat),                        //read data bus            +-
 
      //Exceptions
      .excpt_lsbus_o    (excpt_lrsbus),                      //bus error
  
      //External address in-/decrementer
      .sagu_sp_o         (lrs_agu_sp),                        //current address
      .sagu_inc_o        (lrs_agu_inc),                       //increment address
      .sagu_dec_o        (lrs_agu_dec),                       //decrement address
      .sagu_res_i        (lrs_agu_res),                       //result

      //Probe signals
      .prb_is_o         (prb_irs_o),                         //intermediate stack content
      .prb_is_stat_o    (prb_irs_stat_o),                    //intermediate stack status
      .prb_ls_sp_o      (prb_lrs_sp_o));                     //lower stack pointer

   //Parameter and return stack AGU (...to be replaced by DSP cells)
   //---------------------------------------------------------------
   assign lps_agu_res = lps_agu_sp + {{SP_WIDTH-1{lps_agu_dec}},(lps_agu_inc|lps_agu_dec)};
   assign lrs_agu_res = lrs_agu_sp + {{SP_WIDTH-1{lrs_agu_dec}},(lrs_agu_inc|lrs_agu_dec)};
     
   //Lower stack bus arbiter
   //-----------------------
   N1_lsarb
     #(.SP_WIDTH   (SP_WIDTH),                               //width of a stack pointer
       .CELL_WIDTH (CELL_WIDTH))                             //cell width
   N1_lsarb				                     
     (//Clock and reset			                     
      .clk_i		(clk_i),                             //module clock
      .async_rst_i	(async_rst_i),                       //asynchronous reset
      .sync_rst_i	(sync_rst_i),                        //synchronous reset
      					                     
     //Lower arameter stack bus		                     
     .lpsbus_cyc_i	(lpsbus_cyc),                        //bus cycle indicator      +-
     .lpsbus_stb_i	(lpsbus_stb),                        //access request           | initiator
     .lpsbus_we_i	(lpsbus_we),                         //write enable             | to	   
     .lpsbus_adr_i	(lpsbus_adr),                        //address bus              | target    
     .lpsbus_dat_i	(lpsbus_wdat),                       //write data bus           +-
     .lpsbus_ack_o	(lpsbus_ack),                        //bus cycle acknowledge    +-
     .lpsbus_err_o	(lpsbus_err),                        //error indicator          | target
     .lpsbus_rty_o	(lpsbus_rty),                        //retry request            | to
     .lpsbus_stall_o	(lpsbus_stall),                      //access delay             | initiator
     .lpsbus_dat_o	(lpsbus_rdat),                       //read data bus            +-
					                     
     //Lower return stack bus			                    
     .lrsbus_cyc_i	(lrsbus_cyc),                        //bus cycle indicator      +-
     .lrsbus_stb_i	(lrsbus_stb),                        //access request           | initiator
     .lrsbus_we_i	(lrsbus_we),                         //write enable             | to	   
     .lrsbus_adr_i	(lrsbus_adr),                        //address bus              | target    
     .lrsbus_dat_i	(lrsbus_wdat),                       //write data bus           +-
     .lrsbus_ack_o	(lrsbus_ack),                        //bus cycle acknowledge    +-
     .lrsbus_err_o	(lrsbus_err),                        //error indicator          | target
     .lrsbus_rty_o	(lrsbus_rty),                        //retry request            | to
     .lrsbus_stall_o	(lrsbus_stall),                      //access delay             | initiator
     .lrsbus_dat_o	(lrsbus_rdat),                       //read data bus            +-
 
     //Merged stack bus
     .sbus_cyc_o	(sbus_cyc_o),                        //bus cycle indicator      +-
     .sbus_stb_o	(sbus_stb_o),                        //access request           | 
     .sbus_we_o	        (sbus_we_o),                         //write enable             | initiator
     .sbus_adr_o	(sbus_adr_o),                        //address bus              | to	    
     .sbus_dat_o	(sbus_dat_o),                        //write data bus           | target   
     .sbus_tga_ps_o	(sbus_tga_ps_o),                     //parameter stack access   |
     .sbus_tga_rs_o	(sbus_tga_rs_o),                     //return stack access      +-
     .sbus_ack_i	(sbus_ack_i),                        //bus cycle acknowledge    +-
     .sbus_err_i	(sbus_err_i),                        //error indicator          | target
     .sbus_rty_i	(sbus_rty_i),                        //retry request            | to
     .sbus_stall_i	(sbus_stall_i),                      //access delay             | initiator
     .sbus_dat_i	(sbus_dat_i));                       //read data bus            +-
 
   

//   //Flow control
//   //------------
//   N1_flowctrl 
//     #(.RST_ADR(RST_ADR)) 
//   N1_flowctrl
//   (//Clock and reset
//    //---------------
//    .clk_i		(clk_i),            //module clock
//    .async_rst_i	(async_rst_i),      //asynchronous reset
//    .sync_rst_i		(sync_rst_i),       //synchronous reset
//
//    //Program bus
//    //-----------
//    .pbus_cyc_o		(pbus_cyc_o),       //bus cycle indicator       +-
//    .pbus_stb_o		(pbus_stb_o),       //access request            | initiator to target
//    .pbus_adr_o		(pbus_adr_o),       //address bus               +-
//    .pbus_ack_i		(pbus_ack_i),       //bus cycle acknowledge     +-
//    .pbus_err_i		(pbus_err_i),       //error indicator           | target
//    .pbus_rty_i		(pbus_rty_i),       //retry request             | to
//    .pbus_stall_i	(pbus_stall_i),     //access delay              | initiator
//  //.pbus_dat_i		(pbus_dat_i),       //read data bus             +-
//   
//    //Interrupt interface
//    //-------------------
//    .irq_ack_o		(irq_ack_o),        //interrupt acknowledge           
//    .irq_vec_i		(irq_vec_i),       //requested interrupt vector 


   


endmodule // N1
