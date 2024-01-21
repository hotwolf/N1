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

module N1_ls_dpram
  #(parameter AWIDTH =  8)                                                                        //RAM address width

   (//Clock and reset
    input  wire                             clk_i,                                                //module clock
    input  wire                             async_rst_i,                                          //asynchronous reset
    input  wire                             sync_rst_i,                                           //synchronous reset

    //Soft reset
    input  wire                             ps_rst_i,                                             //parameter stack reset request
    input  wire                             rs_rst_i,                                             //return stack reset request

    //Interface to the immediate stack
    input  wire [15:0]                      ps_push_data_i,                                       //parameter stack push data
    input  wire [15:0]                      rs_push_data_i,                                       //return stack push data
    input  wire                             ps_push_i,                                            //parameter stack push request
    input  wire                             rs_push_i,                                            //return stack push request
    input  wire                             ps_pull_i,                                            //parameter stack pull request
    input  wire                             rs_pull_i,                                            //return stack pull request
    output wire [15:0]                      ps_pull_data_del_o,                                   //parameter stack delayed pull data (available one cycle after the pull request)
    output wire [15:0]                      rs_pull_data_del_o,                                   //return stack delayed pull data (available one cycle after the pull request)
    output wire                             ps_push_bsy_o,                                        //parameter stack push busy indicator
    output wire                             rs_push_bsy_o,                                        //return stack push busy indicator
    output wire                             ps_pull_bsy_o,                                        //parameter stack pull busy indicator
    output wire                             rs_pull_bsy_o,                                        //return stack pull busy indicator
    output wire                             ps_empty_o,                                           //parameter stack empty indicator
    output wire                             rs_empty_o,                                           //return stack empty indicator
    output wire                             prs_full_o,                                           //parameter and return stack full indicator

    //RAM interface
    input  wire [15:0]                      ram_rdata_i,                                          //read data
    output wire [AWIDTH-1:0]                ram_raddr_o,                                          //read address
    output wire [AWIDTH-1:0]                ram_waddr_o,                                          //write address
    output wire [15:0]                      ram_wdata_o,                                          //write data
    output wire                             ram_re_o,                                             //read enable
    output wire                             ram_we_o,                                             //write enable

    //Probe signals
    output wire [AWIDTH-1:0]                prb_ps_addr_o,                                        //parameter stack address probe
    output wire [AWIDTH-1:0]                prb_rs_addr_o);                                       //return stack address probe

    //Internal signals
    //----------------
    //Parameter stack
    wire [AWIDTH-1:0] 			    ps_addr;                                              //parameter stack addess	      	    
    wire [AWIDTH-1:0]                       ps_inc_addr;                                          //incremented parameter stack addess
    wire [AWIDTH-1:0]                       ps_dec_addr;                                          //decremented parameter stack addess
    wire                                    ps_full;                                              //parameter stack full indicator
    wire                                    ps_empty;                                             //parameter stack empty dicator

    //Return stack
    wire [AWIDTH-1:0] 			    rs_addr;                                              //return stack addess		    
    wire [AWIDTH-1:0]                       rs_inc_addr;                                          //incremented return stack addess
    wire [AWIDTH-1:0]                       rs_dec_addr;                                          //decremented return stack addess
    wire                                    rs_full;                                              //return stack full indicator
    wire                                    rs_empty;                                             //return stack empty dicator
												  
    //Parameter stack (grows with LSFR increment starting  at 1)
    //----------------------------------------------------------
    assign  prs_full_o     = ps_full;                                                             //parameter stack overflow (=return stack overflow)
    assign  ps_push_bsy_o  = ps_full;                                                             //parameter stack push busy indicator
    assign  ps_pull_bsy_o  = ps_empty;                                                            //parameter stack pull busy indicator
    assign  ps_empty_o     = ps_empty;                                                            //parameter stack empty indicator
   
    //AGU (LFSR)
    N1_lsfr 
      #(.WIDTH            (8),                                                                    //address width
        .INCLUDE_0        (1),                                                                    //cycle through 0
        .RST_VAL          (8'h01),                                                                //reset value
        .USE_UPPER_LIMIT  (1),                                                                    //enable upper limit
        .USE_LOWER_LIMIT  (1))                                                                    //enable lower limit
    N1_ls_ps_agu  
       (//Clock and reset
        .clk_i            (clk_i),                                                                //module clock
        .async_rst_i      (async_rst_i),                                                          //asynchronous reset
        .sync_rst_i       (sync_rst_i),                                                           //synchronous reset
        //LFSR status
        .lfsr_val_o       (ps_addr),                                                              //parameter stack addess (points to the next free space)		      
        .inc_val_o        (ps_inc_addr),                                                          //incremented parameter stack addess
        .dec_val_o        (ps_dec_addr),                                                          //decremented parameter stack addess
        .at_upper_limit_o (ps_full),                                                              //parameter stack address is at upper limit
        .at_lower_limit_o (ps_empty),                                                             //parameter stack address is at lower limit
        //LFSR control
        .soft_rst_i       (ps_rst_i),                                                             //soft reset
        .inc_i            (ps_push_i),                                                            //increment parameter stack address
        .dec_i            (ps_pull_i),                                                            //decrement parameter stack address   
        //LFSR limits
        .upper_limit_i    (rs_dec_addr),                                                          //upper limit
        .lower_limit_i    (8'h01));                                                               //lower limit

    //Return stack (grows with LSFR decrement starting  at 0)
    //-------------------------------------------------------
    assign  rs_push_bsy_o  = ps_push_i | ps_full;                                                 //return stack push busy indicator
    assign  rs_pull_bsy_o  = ps_pull_i | rs_empty;                                                //return stack pull busy indicator
    assign  rs_empty_o     = rs_empty;                                                            //return stack empty indicator

    //AGU (LFSR)
    N1_lsfr 
      #(.WIDTH            (8),                                                                    //address width
        .INCLUDE_0        (1),                                                                    //cycle through 0
        .RST_VAL          (8'h00),                                                                //reset value
        .USE_UPPER_LIMIT  (1),                                                                    //enable upper limit
        .USE_LOWER_LIMIT  (1))                                                                    //enable lower limit
    N1_ls_rs_agu  
       (//Clock and reset
        .clk_i            (clk_i),                                                                //module clock
        .async_rst_i      (async_rst_i),                                                          //asynchronous reset
        .sync_rst_i       (sync_rst_i),                                                           //synchronous reset
        //LFSR status
        .lfsr_val_o       (rs_addr),                                                              //return stack addess (points to the next free space)	   
        .inc_val_o        (rs_inc_addr),                                                          //incremented return stack addess
        .dec_val_o        (rs_dec_addr),                                                          //decremented return stack addess
        .at_upper_limit_o (rs_empty),                                                             //LFSR is at upper limit
        .at_lower_limit_o (rs_full),                                                              //LFSR is at lower limit
        //LFSR control
        .soft_rst_i       (rs_rst_i),                                                             //soft reset
        .inc_i            (rs_pull_i & ~ps_pull_i),                                               //increment LFSR
        .dec_i            (rs_push_i & ~ps_push_i),                                               //decrement LFSR   
        //LFSR limits
        .upper_limit_i    (8'h00),                                                                //upper limit
        .lower_limit_i    (ps_inc_addr));                                                         //lower limit

    //RAM interface 
    //-------------
    //Read (PS has priority over RS)
    assign  ram_raddr_o        =  ps_pull_i ? ps_dec_addr : rs_inc_addr;                          //read address
    assign  ram_re_o           =  ps_pull_i | rs_pull_i;                                          //read enable
    assign  ps_pull_data_del_o =  ram_rdata_i;                                                    //parameter stack delayed pull data (available one cycle after the pull request)
    assign  rs_pull_data_del_o =  ram_rdata_i;                                                    //return stack delayed pull data (available one cycle after the pull request)
    
    //Write (PS has priority over RS)
    assign  ram_waddr_o        =  ps_push_i ? ps_addr        : rs_addr;                           //write address
    assign  ram_wdata_o        =  ps_push_i ? ps_push_data_i : rs_push_data_i;                    //write data
    assign  ram_we_o           = (ps_push_i | rs_push_i) & ~ps_full;                              //write enable
 
    //Probe signals
    //-------------
    assign  prb_ps_addr_o      = ps_addr;                                                         //parameter stack address probe
    assign  prb_rs_addr_o      = rs_addr;                                                         //return stack address probe

    //Assertions
    //----------
`ifdef FORMAL
    //Input checks
    //------------
    //Inputs ps_rst_i, ps_push_i, and ps_pull_i must be mutual exclusive
    assert (&{~ps_rst_i, ~ps_push_i, ~ps_pull_i} |
            &{ ps_rst_i, ~ps_push_i, ~ps_pull_i} |
            &{~ps_rst_i,  ps_push_i, ~ps_pull_i} |
            &{~ps_rst_i, ~ps_push_i,  ps_pull_i});

    //Inputs rs_rst_i, rs_push_i, and rs_pull_i must be mutual exclusive
    assert (&{~rs_rst_i, ~rs_push_i, ~rs_pull_i} |
            &{ rs_rst_i, ~rs_push_i, ~rs_pull_i} |
            &{~rs_rst_i,  rs_push_i, ~rs_pull_i} |
            &{~rs_rst_i, ~rs_push_i,  rs_pull_i});

`endif //  `ifdef FORMAL
  
endmodule // N1_ls_dpram
