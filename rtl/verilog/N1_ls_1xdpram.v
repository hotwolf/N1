//###############################################################################
//# N1 - Lower Parameter and Return Stack (Dual Ported RAM)                     #
//###############################################################################
//#    Copyright 2018 - 2023 Dirk Heisswolf                                     #
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
//#    single (ICE40 sysMEM style) dual ported RAM.                             #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 13, 2024                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_ls_1xdpram
  #(parameter AWIDTH =  8)                                                                        //RAM address width
   (//Clock and reset
    input  wire                             clk_i,                                                //module clock
    input  wire                             async_rst_i,                                          //asynchronous reset
    input  wire                             sync_rst_i,                                           //synchronous reset

    //Soft reset
    input  wire                             us2ls_ps_clr_i,                                       //clear PS
    input  wire                             us2ls_rs_clr_i,                                       //clear RS

    //Interface to the immediate stack
    input  wire [15:0]                      ips2ls_push_data_i,                                   //parameter stack push data
    input  wire [15:0]                      irs2ls_push_data_i,                                   //return stack push data
    input  wire                             ips2ls_push_i,                                        //parameter stack push request
    input  wire                             irs2ls_push_i,                                        //return stack push request
    input  wire                             ips2ls_pull_i,                                        //parameter stack pull request
    input  wire                             irs2ls_pull_i,                                        //return stack pull request
    output wire [15:0]                      ls2ips_pull_data_del_o,                               //parameter stack delayed pull data (available one cycle after the pull request)
    output wire [15:0]                      ls2irs_pull_data_del_o,                               //return stack delayed pull data (available one cycle after the pull request)
    output wire                             ls2ips_push_bsy_o,                                    //parameter stack push busy indicator
    output wire                             ls2irs_push_bsy_o,                                    //return stack push busy indicator
    output wire                             ls2ips_pull_bsy_o,                                    //parameter stack pull busy indicator
    output wire                             ls2irs_pull_bsy_o,                                    //return stack pull busy indicator
    output wire                             ls2ips_empty_o,                                       //parameter stack empty indicator
    output wire                             ls2irs_empty_o,                                       //return stack empty indicator
    output wire                             ls2ips_full_o,                                        //parameter stack full indicator
    output wire                             ls2irs_full_o,                                        //return stack full indicator

    //RAM interface
    input  wire [15:0]                      ram2ls_rdata_i,                                       //read data
    output wire [AWIDTH-1:0]                ls2ram_raddr_o,                                       //read address
    output wire [AWIDTH-1:0]                ls2ram_waddr_o,                                       //write address
    output wire [15:0]                      ls2ram_wdata_o,                                       //write data
    output wire                             ls2ram_re_o,                                          //read enable
    output wire                             ls2ram_we_o,                                          //write enable

    //Probe signals
    output wire [AWIDTH-1:0]                prb_ps_addr_o,                                        //parameter stack address probe
    output wire [AWIDTH-1:0]                prb_rs_addr_o);                                       //return stack address probe

   //Internal signals
   //----------------
   //Parameter stack
   wire [AWIDTH-1:0]                       ps_addr;                                              //parameter stack addess
   wire [AWIDTH-1:0]                       ps_inc_addr;                                          //incremented parameter stack addess
   wire [AWIDTH-1:0]                       ps_dec_addr;                                          //decremented parameter stack addess
   wire                                    ps_full;                                              //parameter stack full indicator
   wire                                    ps_empty;                                             //parameter stack empty dicator

   //Return stack
   wire [AWIDTH-1:0]                       rs_addr;                                              //return stack addess
   wire [AWIDTH-1:0]                       rs_inc_addr;                                          //incremented return stack addess
   wire [AWIDTH-1:0]                       rs_dec_addr;                                          //decremented return stack addess
   wire                                    rs_full;                                              //return stack full indicator
   wire                                    rs_empty;                                             //return stack empty dicator

   //Parameter stack (grows with LSFR increment starting  at 1)
   //----------------------------------------------------------
   assign  ls2ips_full_o      = ps_full;                                                         //parameter stack overflow (=return stack overflow)
   assign  ls2ips_push_bsy_o  = ps_full;                                                         //parameter stack push busy indicator
   assign  ls2ips_pull_bsy_o  = ps_empty;                                                        //parameter stack pull busy indicator
   assign  ls2ips_empty_o     = ps_empty;                                                        //parameter stack empty indicator

   //AGU (LFSR)
   N1_lsfr
     #(.WIDTH                 (8),                                                               //address width
       .INCLUDE_0             (1),                                                               //cycle through 0
       .RST_VAL               (8'h01),                                                           //reset value
       .USE_UPPER_LIMIT       (1),                                                               //enable upper limit
       .USE_LOWER_LIMIT       (1))                                                               //enable lower limit
   N1_ls_ps_agu
      (//Clock and reset
       .clk_i                 (clk_i),                                                           //module clock
       .async_rst_i           (async_rst_i),                                                     //asynchronous reset
       .sync_rst_i            (sync_rst_i),                                                      //synchronous reset
       //LFSR status
       .lfsr_val_o            (ps_addr),                                                         //parameter stack addess (points to the next free space)
       .lfsr_inc_val_o        (ps_inc_addr),                                                     //incremented parameter stack addess
       .lfsr_dec_val_o        (ps_dec_addr),                                                     //decremented parameter stack addess
       .lfsr_at_upper_limit_o (ps_full),                                                         //parameter stack address is at upper limit
       .lfsr_at_lower_limit_o (ps_empty),                                                        //parameter stack address is at lower limit
       //LFSR control
       .lfsr_soft_rst_i       (us2ls_ps_clr_i),                                                  //clear PS
       .lfsr_inc_i            (ips2ls_push_i),                                                   //increment parameter stack address
       .lfsr_dec_i            (ips2ls_pull_i),                                                   //decrement parameter stack address
       //LFSR limits
       .lfsr_upper_limit_i    (rs_dec_addr),                                                     //upper limit
       .lfsr_lower_limit_i    (8'h01));                                                          //lower limit

   //Return stack (grows with LSFR decrement starting  at 0)
   //-------------------------------------------------------
   assign  ls2irs_full_o      = ps_full;                                                         //return stack overflow (=parameter stack overflow)
 //assign  ls2irs_full_o      = rs_full;                                                         //return stack overflow (=parameter stack overflow)
   assign  ls2irs_push_bsy_o  = ips2ls_push_i | ps_full;                                         //return stack push busy indicator
 //assign  ls2irs_push_bsy_o  = ips2ls_push_i | rs_full;                                         //return stack push busy indicator
   assign  ls2irs_pull_bsy_o  = ips2ls_pull_i | rs_empty;                                        //return stack pull busy indicator
   assign  ls2irs_empty_o     = rs_empty;                                                        //return stack empty indicator

   //AGU (LFSR)
   N1_lsfr
     #(.WIDTH                 (8),                                                               //address width
       .INCLUDE_0             (1),                                                               //cycle through 0
       .RST_VAL               (8'h00),                                                           //reset value
       .USE_UPPER_LIMIT       (1),                                                               //enable upper limit
       .USE_LOWER_LIMIT       (1))                                                               //enable lower limit
   N1_ls_rs_agu
      (//Clock and reset
       .clk_i                 (clk_i),                                                           //module clock
       .async_rst_i           (async_rst_i),                                                     //asynchronous reset
       .sync_rst_i            (sync_rst_i),                                                      //synchronous reset
       //LFSR status
       .lfsr_val_o            (rs_addr),                                                         //return stack addess (points to the next free space)
       .lfsr_inc_val_o        (rs_inc_addr),                                                     //incremented return stack addess
       .lfsr_dec_val_o        (rs_dec_addr),                                                     //decremented return stack addess
       .lfsr_at_upper_limit_o (rs_empty),                                                        //LFSR is at upper limit
       .lfsr_at_lower_limit_o (rs_full),                                                         //LFSR is at lower limit
       //LFSR control
       .lfsr_soft_rst_i       (us2ls_rs_clr_i),                                                  //clear RS
       .lfsr_inc_i            (irs2ls_pull_i & ~ips2ls_pull_i),                                  //increment LFSR
       .lfsr_dec_i            (irs2ls_push_i & ~ips2ls_push_i),                                  //decrement LFSR
       //LFSR limits
       .lfsr_upper_limit_i    (8'h00),                                                           //upper limit
       .lfsr_lower_limit_i    (ps_inc_addr));                                                    //lower limit

   //RAM interface
   //-------------
   //Read (PS has priority over RS)
   assign  ls2ram_raddr_o         =  ips2ls_pull_i ? ps_dec_addr : rs_inc_addr;                  //read address
   assign  ls2ram_re_o            =  ips2ls_pull_i | irs2ls_pull_i;                              //read enable
   assign  ls2ips_pull_data_del_o =  ram2ls_rdata_i;                                             //parameter stack delayed pull data (available one cycle after the pull request)
   assign  ls2irs_pull_data_del_o =  ram2ls_rdata_i;                                             //return stack delayed pull data (available one cycle after the pull request)

   //Write (PS has priority over RS)
   assign  ls2ram_waddr_o         =  ips2ls_push_i ? ps_addr            : rs_addr;               //write address
   assign  ls2ram_wdata_o         =  ips2ls_push_i ? ips2ls_push_data_i : irs2ls_push_data_i;    //write data
   assign  ls2ram_we_o            = (ips2ls_push_i | irs2ls_push_i) & ~ps_full;                  //write enable

   //Probe signals
   //-------------
   assign  prb_ps_addr_o          = ps_addr;                                                     //parameter stack address probe
   assign  prb_rs_addr_o          = rs_addr;                                                     //return stack address probe

   //Assertions
   //----------
`ifdef FORMAL
   //Input checks
   //------------
   //Inputs ps_push_i and ps_pull_i must be mutual exclusive
   assert(&{~ps_push_i, ~ips2ls_pull_i} |
          &{ ps_push_i, ~ips2ls_pull_i} |
          &{~ps_push_i,  ips2ls_pull_i});

   //Inputs rs_rst_i, rs_push_i, and rs_pull_i must be mutual exclusive
   assert(&{~rs_push_i, ~irs2ls_pull_i} |
          &{ rs_push_i, ~irs2ls_pull_i} |
          &{~rs_push_i,  irs2ls_pull_i});

`endif //  `ifdef FORMAL

endmodule // N1_ls_dpram
