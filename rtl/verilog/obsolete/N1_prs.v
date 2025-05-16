//###############################################################################
//# N1 - Parameter and Return Stack                                             #
//###############################################################################
//#    Copyright 2018 - 2025 Dirk Heisswolf                                     #
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
//#    This module instantiates all levels of the parameter and the return      #
//#    stack.                                                                   #
//#    stack.                                                                   #
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
//#    - The lower stack resides in RAM to to implement a deep stack. Parameter #
//#      and return stack use a shared RAM block.                               #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 13, 2018                                                         #
//#      - Initial release                                                      #
//#   May 8, 2019                                                               #
//#      - Added RTY_I support to PBUS                                          #
//#   February 10, 2024                                                         #
//#      - New implementation                                                   #
//#   May 9, 2025                                                               #
//#      - New implementation                                                   #
//###############################################################################
`default_nettype none

module N1_prs
  #(parameter   IPS_DEPTH        = 4,                                                    //depth of the intermediate parameter stack
    parameter   IRS_DEPTH        = 2,                                                    //depth of the intermediate return stack
    parameter   LPRS_ADDR_WIDTH  = 14,                                                   //lower stack address width
    parameter   ROT_EXTENSION    = 1,                                                    //implement ROT extension
    localparam  PSD_WIDTH        = LPRS_ADDR_WIDTH+1,                                    //width of parameter stack depth register
    localparam  RSD_WIDTH        = LPRS_ADDR_WIDTH+1,                                    //width of return stack depth register
    localparam  UPRS_PROBE_WIDTH = PSD_WIDTH+RSD_WIDTH+80,                               //UPRS probes
    localparam  IPS_PROBE_WIDTH  = (IPS_DEPTH == 0) ?  1 : 17*IPS_DEPTH,                 //IPS probes
    localparam  IRS_PROBE_WIDTH  = (IRS_DEPTH == 0) ?  1 : 17*IRS_DEPTH,                 //IRS probes
    localparam  LPRS_PROBE_WIDTH = (2*LPRS_ADDR_WIDTH)+2,                                //LPRS probes
    localparam  PROBE_WIDTH      = UPRS_PROBE_WIDTH+                                     //width of the concatinated probe output
				   IPS_PROBE_WIDTH+
				   IRS_PROBE_WIDTH+
				   LPRS_PROBE_WIDTH)

   (//Clock and reset
    input  wire                         clk_i,                                           //module clock
    input  wire                         async_rst_i,                                     //asynchronous reset
    input  wire                         sync_rst_i,                                      //synchronous reset
										         
    //Upper parameter and return stack interface				         
    input  wire                         uprs_ps_clear_i,                                 //parameter stack clear request
    input  wire                         uprs_rs_clear_i,                                 //return stack clear request
    input  wire                         uprs_shift_i,                                    //stack shift request
    input  wire                         uprs_dat_2_ps0_i,                                //push data -> PS0
    input  wire                         uprs_dat_2_ps1_i,                                //push data -> PS1
    input  wire                         uprs_dat_2_rs0_i,                                //push data -> RS1
    input  wire                         uprs_ps3_2_ips_i,                                //PS3       -> IPS
    input  wire                         uprs_ips_2_ps3_i,                                //IPS       -> PS3
    input  wire                         uprs_ps2_2_ps3_i,                                //PS2       -> PS3
    input  wire                         uprs_ps3_2_ps2_i,                                //PS3       -> PS2
    input  wire                         uprs_ps0_2_ps2_i,                                //PS0       -> PS2 (ROT extension)
    input  wire                         uprs_ps1_2_ps2_i,                                //PS1       -> PS2
    input  wire                         uprs_ps2_2_ps1_i,                                //PS2       -> PS1
    input  wire                         uprs_ps0_2_ps1_i,                                //PS0       -> PS1
    input  wire                         uprs_ps1_2_ps0_i,                                //PS1       -> PS0
    input  wire                         uprs_ps2_2_ps0_i,                                //PS2       -> PS0 (ROT extension)
    input  wire                         uprs_rs0_2_ps0_i,                                //RS0       -> PS0
    input  wire                         uprs_ps0_2_rs0_i,                                //PS0       -> RS0
    input  wire                         uprs_irs_2_rs0_i,                                //IRS       -> RS0
    input  wire                         uprs_rs0_2_irs_i,                                //RS0       -> IRS
    input  wire [15:0]                  uprs_ps0_push_data_i,                            //PS0 push data
    input  wire [15:0]                  uprs_ps1_push_data_i,                            //PS1 push data
    input  wire [15:0]                  uprs_rs0_push_data_i,                            //RS0 push data
    output wire                         uprs_ps_clear_bsy_o,                             //parameter stack clear busy indicator
    output wire                         uprs_rs_clear_bsy_o,                             //return stack clear busy indicator
    output wire                         uprs_shift_bsy_o,                                //stack shift busy indicator
    output wire                         uprs_ps_uf_o,                                    //parameter stack underflow
    output wire                         uprs_ps_of_o,                                    //parameter stack overflow
    output wire                         uprs_rs_uf_o,                                    //return stack underflow
    output wire                         uprs_rs_of_o,                                    //return stack overflow
    output wire                         uprs_ps0_loaded_o,                               //PS0 contains data
    output wire                         uprs_ps1_loaded_o,                               //PS1 contains data
    output wire                         uprs_rs0_loaded_o,                               //RS0 contains data
    output wire [15:0]                  uprs_ps0_pull_data_o,                            //PS0 pull data
    output wire [15:0]                  uprs_ps1_pull_data_o,                            //PS1 pull data
    output wire [15:0]                  uprs_rs0_pull_data_o,                            //RS0 pull data
										         
    //Stack depths								         
    output wire [PSD_WIDTH-1:0]         psd_o,                                           //parameter stack depths
    output wire [RSD_WIDTH-1:0]         rsd_o,                                           //return stack depth
										         
    //Probe signals								         
    output wire [PROBE_WIDTH-1:0]       prb_prs_o);                                      //probe signals

   //Internal signals
   //-----------------
   //IPS interface
   wire                                 ips_clear_bsy;                                   //IPS clear busy indicator
   wire                                 ips_push_bsy;                                    //IPS push busy indicator
   wire                                 ips_pull_bsy;                                    //IPS pull busy indicator
   wire                                 ips_empty;                                       //IPS empty indicator
   wire                                 ips_full;                                        //IPS overflow indicator
   wire [15:0]                          ips_pull_data;                                   //IPS pull data
   wire                                 ips_clear;                                       //IPS clear request
   wire                                 ips_push;                                        //IPS push request
   wire                                 ips_pull;                                        //IPS pull request
   wire [15:0]                          ips_push_data;                                   //IPS push data
									                 
   //IRS interface							                 
   wire                                 irs_clear_bsy;                                   //IRS clear busy indicator
   wire                                 irs_push_bsy;                                    //IRS push busy indicator
   wire                                 irs_pull_bsy;                                    //IRS pull busy indicator
   wire                                 irs_empty;                                       //IRS empty indicator
   wire                                 irs_full;                                        //IRS overflow indicator
   wire [15:0]                          irs_pull_data;                                   //IRS pull data
   wire                                 irs_clear;                                       //IRS clear request
   wire                                 irs_push;                                        //IRS push request
   wire                                 irs_pull;                                        //IRS pull request
   wire [15:0]                          irs_push_data;                                   //IRS push data
   
   //LPS interface
   wire                                 lps_clear;                                       //clear request
   wire                                 lps_push;                                        //push request
   wire                                 lps_pull;                                        //pull request
   wire [15:0]                          lps_push_data;                                   //push request
   wire                                 lps_clear_bsy;                                   //clear request rejected
   wire                                 lps_push_bsy;                                    //push request rejected
   wire                                 lps_pull_bsy;                                    //pull request rejected
   wire                                 lps_empty;                                       //underflow indicator
   wire                                 lps_full;                                        //overflow indicator
   wire [15:0]                          lps_pull_data;                                   //pull data
                                                			                 
   //LRS interface                      				                 
   wire                                 lrs_clear;                                       //clear request
   wire                                 lrs_push;                                        //push request
   wire                                 lrs_pull;                                        //pull request
   wire [15:0]                          lrs_push_data;                                   //push request
   wire                                 lrs_clear_bsy;                                   //clear request rejected
   wire                                 lrs_push_bsy;                                    //push request rejected
   wire                                 lrs_pull_bsy;                                    //pull request rejected
   wire                                 lrs_empty;                                       //underflow indicator
   wire                                 lrs_full;                                        //overflow indicator
   wire [15:0]                          lrs_pull_data;                                   //pull data

   //Probe signals							                 
   wire [UPRS_PROBE_WIDTH-1:0] 		prb_uprs;                                        //UPRS probes
   wire [IPS_PROBE_WIDTH-1:0] 		prb_ips;                                         //IPS probes
   wire [IRS_PROBE_WIDTH-1:0] 		prb_irs;                                         //IRS probes
   wire [LPRS_PROBE_WIDTH-1:0] 		prb_lprs;                                        //LPRS probes

   //Upper parameter and return stack
   N1_uprs
     #(.PSD_WIDTH     (PSD_WIDTH),                                                       //width of parameter stack depth register
       .RSD_WIDTH     (RSD_WIDTH),                                                       //width of return stack depth register
       .ROT_EXTENSION (ROT_EXTENSION))                                                   //implement ROT extension
   uprs
     (//Clock and reset
      .clk_i                            (clk_i),                                         //module clock
      .async_rst_i                      (async_rst_i),                                   //asynchronous reset
      .sync_rst_i                       (sync_rst_i),                                    //synchronous reset
      //Upper parameter and return stack interface				         
      .uprs_ps_clear_i                  (uprs_ps_clear_i),                               //parameter stack clear request
      .uprs_rs_clear_i                  (uprs_rs_clear_i),                               //return stack clear request
      .uprs_shift_i                     (uprs_shift_i),                                  //stack shift request
      .uprs_dat_2_ps0_i                 (uprs_dat_2_ps0_i),                              //push data -> PS0
      .uprs_dat_2_ps1_i                 (uprs_dat_2_ps1_i),                              //push data -> PS1
      .uprs_dat_2_rs0_i                 (uprs_dat_2_rs0_i),                              //push data -> RS1
      .uprs_ps3_2_ips_i                 (uprs_ps3_2_ips_i),                              //PS3       -> IPS
      .uprs_ips_2_ps3_i                 (uprs_ips_2_ps3_i),                              //IPS       -> PS3
      .uprs_ps2_2_ps3_i                 (uprs_ps2_2_ps3_i),                              //PS2       -> PS3
      .uprs_ps3_2_ps2_i                 (uprs_ps3_2_ps2_i),                              //PS3       -> PS2
      .uprs_ps0_2_ps2_i                 (uprs_ps0_2_ps2_i),                              //PS0       -> PS2 (ROT extension)
      .uprs_ps1_2_ps2_i                 (uprs_ps1_2_ps2_i),                              //PS1       -> PS2
      .uprs_ps2_2_ps1_i                 (uprs_ps2_2_ps1_i),                              //PS2       -> PS1
      .uprs_ps0_2_ps1_i                 (uprs_ps0_2_ps1_i),                              //PS0       -> PS1
      .uprs_ps1_2_ps0_i                 (uprs_ps1_2_ps0_i),                              //PS1       -> PS0
      .uprs_ps2_2_ps0_i                 (uprs_ps2_2_ps0_i),                              //PS2       -> PS0 (ROT extension)
      .uprs_rs0_2_ps0_i                 (uprs_rs0_2_ps0_i),                              //RS0       -> PS0
      .uprs_ps0_2_rs0_i                 (uprs_ps0_2_rs0_i),                              //PS0       -> RS0
      .uprs_irs_2_rs0_i                 (uprs_irs_2_rs0_i),                              //IRS       -> RS0
      .uprs_rs0_2_irs_i                 (uprs_rs0_2_irs_i),                              //RS0       -> IRS
      .uprs_ps0_push_data_i             (uprs_ps0_push_data_i),                          //PS0 push data
      .uprs_ps1_push_data_i             (uprs_ps1_push_data_i),                          //PS1 push data
      .uprs_rs0_push_data_i             (uprs_rs0_push_data_i),                          //RS0 push data
      .uprs_ps_clear_bsy_o              (uprs_ps_clear_bsy_o),                           //parameter stack clear busy indicator
      .uprs_rs_clear_bsy_o              (uprs_rs_clear_bsy_o),                           //return stack clear busy indicator
      .uprs_shift_bsy_o                 (uprs_shift_bsy_o),                              //stack shift busy indicator
      .uprs_ps_uf_o                     (uprs_ps_uf_o),                                  //parameter stack underflow
      .uprs_ps_of_o                     (uprs_ps_of_o),                                  //parameter stack overflow
      .uprs_rs_uf_o                     (uprs_rs_uf_o),                                  //return stack underflow
      .uprs_rs_of_o                     (uprs_rs_of_o),                                  //return stack overflow
      .uprs_ps0_loaded_o                (uprs_ps0_loaded_o),                             //PS0 contains data
      .uprs_ps1_loaded_o                (uprs_ps1_loaded_o),                             //PS1 contains data
      .uprs_rs0_loaded_o                (uprs_rs0_loaded_o),                             //RS0 contains data
      .uprs_ps0_pull_data_o             (uprs_ps0_pull_data_o),                          //PS0 pull data
      .uprs_ps1_pull_data_o             (uprs_ps1_pull_data_o),                          //PS1 pull data
      .uprs_rs0_pull_data_o             (uprs_rs0_pull_data_o),                          //RS0 pull data
      //Stack depths								         
      .psd_o                            (psd_o),                                         //parameter stack depths
      .rsd_o                            (rsd_o),                                         //return stack depth
      //IPS interface
      .ips_clear_bsy_i                  (ips_clear_bsy),                                 //IPS clear busy indicator
      .ips_push_bsy_i                   (ips_push_bsy),                                  //IPS push busy indicator
      .ips_pull_bsy_i                   (ips_pull_bsy),                                  //IPS pull busy indicator
      .ips_empty_i                      (ips_empty),                                     //IPS empty indicator
      .ips_full_i                       (ips_full),                                      //IPS overflow indicator
      .ips_pull_data_i                  (ips_pull_data),                                 //IPS pull data
      .ips_clear_o                      (ips_clear),                                     //IPS clear request
      .ips_push_o                       (ips_push),                                      //IPS push request
      .ips_pull_o                       (ips_pull),                                      //IPS pull request
      .ips_push_data_o                  (ips_push_data),                                 //IPS push data
      //IRS interface 								         
      .irs_clear_bsy_i                  (irs_clear_bsy),                                 //IRS clear busy indicator
      .irs_push_bsy_i                   (irs_push_bsy),                                  //IRS push busy indicator
      .irs_pull_bsy_i                   (irs_pull_bsy),                                  //IRS pull busy indicator
      .irs_empty_i                      (irs_empty),                                     //IRS empty indicator
      .irs_full_i                       (irs_full),                                      //IRS overflow indicator
      .irs_pull_data_i                  (irs_pull_data),                                 //IRS pull data
      .irs_clear_o                      (irs_clear),                                     //IRS clear request
      .irs_push_o                       (irs_push),                                      //IRS push request
      .irs_pull_o                       (irs_pull),                                      //IRS pull request
      .irs_push_data_o                  (irs_push_data),                                 //IRS push data
      //Probe signals   							         
      .prb_uprs_o                       (prb_uprs));                                     //probe signals

   //Intermediate parameter stack
   N1_is
     #(.DEPTH (IPS_DEPTH))                                                               //depth of the IPS
   ips
     (//Clock and reset
      .clk_i                            (clk_i),                                         //module clock
      .async_rst_i                      (async_rst_i),                                   //asynchronous reset
      .sync_rst_i                       (sync_rst_i),                                    //synchronous reset
      //Interface to upper stack
      .us_clear_i			(ips_clear),                                     //UPS clear request
      .us_push_i			(ips_push),                                      //UPS push request
      .us_pull_i			(ips_pull),                                      //UPS pull request
      .us_push_data_i			(ips_push_data),                                 //UPS push data
      .us_clear_bsy_o			(ips_clear_bsy),                                 //UPS clear busy indicator
      .us_push_bsy_o			(ips_push_bsy),                                  //UPS push busy indicator
      .us_pull_bsy_o			(ips_pull_bsy),                                  //UPS pull busy indicator
      .us_empty_o			(ips_empty),                                     //UPS empty indicator
      .us_full_o			(ips_full),                                      //UPS overflow indicator
      .us_pull_data_o			(ips_pull_data),                                 //UPS pull data
      //Interface to lower stack
      .ls_clear_bsy_i			(lps_clear_bsy),                                 //LPS clear busy indicator
      .ls_push_bsy_i			(lps_push_bsy),                                  //LPS push busy indicator
      .ls_pull_bsy_i			(lps_pull_bsy),                                  //LPS pull busy indicator
      .ls_empty_i			(lps_empty),                                     //LPS empty indicator
      .ls_full_i			(lps_full),                                      //LPS overflow indicator
      .ls_pull_data_i			(lps_pull_data),                                 //LPS pull data
      .ls_clear_o			(lps_clear),                                     //LPS clear request
      .ls_push_o			(lps_push),                                      //LPS push request
      .ls_pull_o			(lps_pull),                                      //LPS pull request
      .ls_push_data_o			(lps_push_data),                                 //LPS push data
      //Probe signals
      .prb_is_o				(prb_ips));                                      //probe signals

   //Intermediate return stack
   N1_is
     #(.DEPTH (IRS_DEPTH))                                                               //depth of the IRS
   irs
     (//Clock and reset
      .clk_i                            (clk_i),                                         //module clock
      .async_rst_i                      (async_rst_i),                                   //asynchronous reset
      .sync_rst_i                       (sync_rst_i),                                    //synchronous reset
      //Interface to upper stack
      .us_clear_i			(irs_clear),                                     //UPS clear request
      .us_push_i			(irs_push),                                      //UPS push request
      .us_pull_i			(irs_pull),                                      //UPS pull request
      .us_push_data_i			(irs_push_data),                                 //UPS push data
      .us_clear_bsy_o			(irs_clear_bsy),                                 //UPS clear busy indicator
      .us_push_bsy_o			(irs_push_bsy),                                  //UPS push busy indicator
      .us_pull_bsy_o			(irs_pull_bsy),                                  //UPS pull busy indicator
      .us_empty_o			(irs_empty),                                     //UPS empty indicator
      .us_full_o			(irs_full),                                      //UPS overflow indicator
      .us_pull_data_o			(irs_pull_data),                                 //UPS pull data
      //Interface to lower stack
      .ls_clear_bsy_i			(lrs_clear_bsy),                                 //LPS clear busy indicator
      .ls_push_bsy_i			(lrs_push_bsy),                                  //LPS push busy indicator
      .ls_pull_bsy_i			(lrs_pull_bsy),                                  //LPS pull busy indicator
      .ls_empty_i			(lrs_empty),                                     //LPS empty indicator
      .ls_full_i			(lrs_full),                                      //LPS overflow indicator
      .ls_pull_data_i			(lrs_pull_data),                                 //LPS pull data
      .ls_clear_o			(lrs_clear),                                     //LPS clear request
      .ls_push_o			(lrs_push),                                      //LPS push request
      .ls_pull_o			(lrs_pull),                                      //LPS pull request
      .ls_push_data_o			(lrs_push_data),                                 //LPS push data
      //Probe signals
      .prb_is_o				(prb_irs));                                      //probe signals

   //Lower parameter and return stack
   N1_lprs
     #(.ADDR_WIDTH (LPRS_ADDR_WIDTH))                                                    //RAM address width
   lprs
     (//Clock and reset                                                                 
      .clk_i                            (clk_i),                                         //module clock
      .async_rst_i                      (async_rst_i),                                   //asynchronous reset
      .sync_rst_i                       (sync_rst_i),                                    //synchronous reset
      //Parameter stack interface
      .lps_clear_i			(lps_clear),                                     //clear request
      .lps_push_i			(lps_push),                                      //push request
      .lps_pull_i			(lps_pull),                                      //pull request
      .lps_push_data_i			(lps_push_data),                                 //push request
      .lps_clear_bsy_o			(lps_clear_bsy),                                 //clear request rejected
      .lps_push_bsy_o			(lps_push_bsy),                                  //push request rejected
      .lps_pull_bsy_o			(lps_pull_bsy),                                  //pull request rejected
      .lps_empty_o			(lps_empty),                                     //underflow indicator
      .lps_full_o			(lps_full),                                      //overflow indicator
      .lps_pull_data_o			(lps_pull_data),                                 //pull data
      //Parameter stack interface              					         
      .lrs_clear_i			(lrs_clear),                                     //clear request
      .lrs_push_i			(lrs_push),                                      //push request
      .lrs_pull_i			(lrs_pull),                                      //pull request
      .lrs_push_data_i			(lrs_push_data),                                 //push request
      .lrs_clear_bsy_o			(lrs_clear_bsy),                                 //clear request rejected
      .lrs_push_bsy_o			(lrs_push_bsy),                                  //push request rejected
      .lrs_pull_bsy_o			(lrs_pull_bsy),                                  //pull request rejected
      .lrs_empty_o			(lrs_empty),                                     //underflow indicator
      .lrs_full_o			(lrs_full),                                      //overflow indicator
      .lrs_pull_data_o			(lrs_pull_data),                                 //pull data
      //Probe signals								         
      .prb_lprs_o			(prb_lprs));                                     //Probe signals

   //Probe signals
   //-------------
   assign prb_prs_o = {prb_lprs,                                                         //concatinated probe signals 
		       prb_ips,  
		       prb_irs,  
		       prb_uprs};
		       

   // Probe signals
   //-------------------------------------------
   // lprs.lps.state_reg
   // lprs.lps.agu.lfsr_reg[LPRS_ADDR_WIDTH-1:0]
   // lprs.lrs.state_reg
   // lprs.lrs.agu.lfsr_reg[LPRS_ADDR_WIDTH-1:0]
   // ips.is_tags_reg[IPS_DEPTH-1:0]               !!! [0:0] if IPS_DEPTH == 0 !!!
   // ips.is_cells_reg[16*IPS_DEPTH-1:0]           !!! [0:0] if IPS_DEPTH == 0 !!!
   // irs.is_tags_reg[IRS_DEPTH-1:0]               !!! [0:0] if IRS_DEPTH == 0 !!!
   // irs.is_cells_reg[16*IRS_DEPTH-1:0]           !!! [0:0] if IRS_DEPTH == 0 !!!
   // uprs.psd_reg[15:0]
   // uprs.rsd_reg[15:0]
   // uprs.ps0_reg[15:0]
   // uprs.ps1_reg[15:0]
   // uprs.ps2_reg[15:0]
   // uprs.ps3_reg[15:0]
   // uprs.rs0_reg[15:0]

   //Assertions
   //----------
`ifdef FORMAL

`endif //  `ifdef FORMAL
  
endmodule // N1_prs
