//###############################################################################
//# N1 - Lower Parameter and Return Stack (Single Ported RAM)                   #
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
//#    This module implements the lower parameter and return stack, utilizing a #
//#    single ported RAM.                                                       #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   April 25, 2025                                                            #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_lprs
  #(parameter ADDR_WIDTH = 14)                                                        //RAM address width
   (//Clock and reset                                                                 
    input  wire                              clk_i,                                   //module clock
    input  wire                              async_rst_i,                             //asynchronous reset
    input  wire                              sync_rst_i,                              //synchronous reset

    //Parameter stack interface
    input  wire                              lps_clear_i,                             //clear request
    input  wire                              lps_push_i,                              //push request
    input  wire                              lps_pull_i,                              //pull request
    input  wire [15:0]                       lps_push_data_i,                         //push request
    output wire                              lps_clear_bsy_o,                         //clear request rejected
    output wire                              lps_push_bsy_o,                          //push request rejected
    output wire                              lps_pull_bsy_o,                          //pull request rejected
    output wire                              lps_full_o,                              //overflow indicator
    output wire                              lps_empty_o,                             //underflow indicator
    output wire [15:0]                       lps_pull_data_o,                         //pull data
                                             
    //Parameter stack interface              
    input  wire                              lrs_clear_i,                             //clear request
    input  wire                              lrs_push_i,                              //push request
    input  wire                              lrs_pull_i,                              //pull request
    input  wire [15:0]                       lrs_push_data_i,                         //push request
    output wire                              lrs_clear_bsy_o,                         //clear request rejected
    output wire                              lrs_push_bsy_o,                          //push request rejected
    output wire                              lrs_pull_bsy_o,                          //pull request rejected
    output wire                              lrs_full_o,                              //overflow indicator
    output wire                              lrs_empty_o,                             //underflow indicator
    output wire [15:0]                       lrs_pull_data_o,                         //pull data

    //Probe signals
    output wire [(2*ADDR_WIDTH)+1:0]         prb_lprs_o);                             //Probe signals

   //Internal signals
   //----------------
   //LPS
   wire                                      lpsmem_access_bsy;                       //access request rejected
   wire [15:0]                               lpsmem_rdata;                            //read data
   wire [ADDR_WIDTH-1:0]                     lpsmem_addr;                             //address
   wire                                      lpsmem_access;                           //access request
   wire                                      lpsmem_rwb;                              //data direction
   wire [15:0]                               lpsmem_wdata;                            //write data
   wire [ADDR_WIDTH-1:0]                     lps_tos;                                 //points to the TOS
   wire [ADDR_WIDTH:0]                       prb_lps;                                 //probe signals

   //LRS
   wire                                      lrsmem_access_bsy;                       //access request rejected
   wire [15:0]                               lrsmem_rdata;                            //read data
   wire [ADDR_WIDTH-1:0]                     lrsmem_addr;                             //address
   wire                                      lrsmem_access;                           //access request
   wire                                      lrsmem_rwb;                              //data direction
   wire [15:0]                               lrsmem_wdata;                            //write data
   wire [ADDR_WIDTH-1:0]                     lrs_tos;                                 //points to the TOS
   wire [ADDR_WIDTH:0]                       prb_lrs;                                 //probe signals
    
   //Memory
   wire [ADDR_WIDTH-1:0]                     spram_addr;                              //address
   wire                                      spram_access;                            //access request
   wire                                      spram_rwb;                               //data direction
   wire [15:0]                               spram_wdata;                             //write data
   wire [15:0]                               spram_rdata;                             //read data
    
   //LPS controller
   //--------------
   N1_ls
    #(.ADDR_WIDTH      (ADDR_WIDTH),                                                  //address width of the memory
      .STACK_DIRECTION (0))                                                           //1:grow stack upward, 0:grow stack downward
   lps
    (//Clock and reset
     .clk_i                                 (clk_i),                                  //module clock
     .async_rst_i                           (async_rst_i),                            //asynchronous reset
     .sync_rst_i                            (sync_rst_i),                             //synchronous reset
     //Stack interface                      
     .ls_clear_i                            (lps_clear_i),                            //clear request
     .ls_push_i                             (lps_push_i),                             //push request
     .ls_pull_i                             (lps_pull_i),                             //pull request
     .ls_push_data_i                        (lps_push_data_i),                        //push request
     .ls_clear_bsy_o                        (lps_clear_bsy_o),                        //clear request rejected
     .ls_push_bsy_o                         (lps_push_bsy_o),                         //push request rejected
     .ls_pull_bsy_o                         (lps_pull_bsy_o),                         //pull request rejected
     .ls_full_o                             (lps_full_o),                             //overflow indicator
     .ls_empty_o                            (lps_empty_o),                            //underflow indicator
     .ls_pull_data_o                        (lps_pull_data_o),                        //pull data
     //Memory interface                     
     .mem_access_bsy_i                      (lpsmem_access_bsy),                      //access request rejected
     .mem_rdata_i                           (lpsmem_rdata),                           //read data
     .mem_addr_o                            (lpsmem_addr),                            //address
     .mem_access_o                          (lpsmem_access),                          //access request
     .mem_rwb_o                             (lpsmem_rwb),                             //data direction
     .mem_wdata_o                           (lpsmem_wdata),                           //write data
     //Dynamic stack ranges                 
     .ls_tos_limit_i                        (lrs_tos),                                //address, which the LS must not reach
     .ls_tos_o                              (lps_tos),                                //points to the TOS
     //Probe signals                        
     .prb_ls_o                              (prb_lps));                               //FSM state
        
   //LRS controller
   //--------------
   N1_ls
    #(.ADDR_WIDTH      (ADDR_WIDTH),                                                  //address width of the memory
      .STACK_DIRECTION (0))                                                           //1:grow stack upward, 0:grow stack downward
   lrs
    (//Clock and reset
     .clk_i                                 (clk_i),                                  //module clock
     .async_rst_i                           (async_rst_i),                            //asynchronous reset
     .sync_rst_i                            (sync_rst_i),                             //synchronous reset
     //Stack interface                      
     .ls_clear_i                            (lrs_clear_i),                            //clear request
     .ls_push_i                             (lrs_push_i),                             //push request
     .ls_pull_i                             (lrs_pull_i),                             //pull request
     .ls_push_data_i                        (lrs_push_data_i),                        //push request
     .ls_clear_bsy_o                        (lrs_clear_bsy_o),                        //clear request rejected
     .ls_push_bsy_o                         (lrs_push_bsy_o),                         //push request rejected
     .ls_pull_bsy_o                         (lrs_pull_bsy_o),                         //pull request rejected
     .ls_full_o                             (lrs_full_o),                             //overflow indicator
     .ls_empty_o                            (lrs_empty_o),                            //underflow indicator
     .ls_pull_data_o                        (lrs_pull_data_o),                        //pull data
     //Memory interface                     
     .mem_access_bsy_i                      (lrsmem_access_bsy),                      //access request rejected
     .mem_rdata_i                           (lrsmem_rdata),                           //read data
     .mem_addr_o                            (lrsmem_addr),                            //address
     .mem_access_o                          (lrsmem_access),                          //access request
     .mem_rwb_o                             (lrsmem_rwb),                             //data direction
     .mem_wdata_o                           (lrsmem_wdata),                           //write data
     //Dynamic stack ranges                 
     .ls_tos_limit_i                        (lps_tos),                                //address, which the LS must not reach
     .ls_tos_o                              (lrs_tos),                                //points to the TOS
     //Probe signals                        
     .prb_ls_o                              (prb_lrs));                               //FSM state
        
   //Arbiter
   //-------
   assign  spram_addr        = lpsmem_access ? lpsmem_addr  : lrsmem_addr;
   assign  spram_access      = lpsmem_access | lrsmem_access;
   assign  spram_rwb         = lpsmem_access ? lpsmem_rwb   : lrsmem_rwb;
   assign  spram_wdata       = lpsmem_access ? lpsmem_wdata : lrsmem_wdata;

   assign  lpsmem_access_bsy = 1'b0;
   assign  lrsmem_access_bsy = lpsmem_access;
    
   assign  lpsmem_rdata      = spram_rdata;
   assign  lrsmem_rdata      = spram_rdata;
    
   //Memory
   //------
   N1_spram
    #(.ADDR_WIDTH      (ADDR_WIDTH))
   spram
    (//Clock and reset
     .clk_i                                 (clk_i),                                  //module clock
     //RAM interface
     .spram_addr_i                          (spram_addr),                             //address
     .spram_access_i                        (spram_access),                           //access request
     .spram_rwb_i                           (spram_rwb),                              //data direction
     .spram_wdata_i                         (spram_wdata),                            //write data
     .spram_rdata_o                         (spram_rdata));                           //read data

   //Probe signals
   //-------------
   assign  prb_lprs_o   = {prb_lps,  // 2*ADDR_WIDTH + 1 ... ADDR_WIDTH               //concatinated probes
                           prb_lrs}; //   ADDR_WIDTH     ... 0                                            

   //Bit                             instance   Signal 
   //-------------------------------------------------------------------
   //2*ADDR_WIDTH+1                  lps        state_reg
   //2*ADDR_WIDTH ... ADDR_WIDTH+1   lps.agu    lfsr_reg[ADDR_WIDTH-1:0}
   //ADDR_WIDTH                      lrs        state_reg
   //ADDR_WIDTH-1 ... 0              lrs.agu    lfsr_reg[ADDR_WIDTH-1:0}
   
endmodule // N1_lprs
