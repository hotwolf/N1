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
  #(parameter AWIDTH           =  8)                                                              //RAM address width

   (//Clock and reset
    input  wire                             clk_i,                                                //module clock
    input  wire                             async_rst_i,                                          //asynchronous reset
    input  wire                             sync_rst_i,                                           //synchronous reset

    //Interface to the immediate stack
    input  wire [15:0]                      ps_push_data_i,                                       //parameter stack push data
    input  wire [15:0]                      rs_push_data_i,                                       //return stack push data
    input  wire                             ps_push_i,                                            //parameter stack push request
    input  wire                             rs_push_i,                                            //return stack push request
    input  wire                             ps_pull_i,                                            //parameter stack pull request
    input  wire                             rs_pull_i,                                            //return stack pull request
    input  wire                             ps_rst_i,                                             //parameter stack reset request
    input  wire                             rs_rst_i,                                             //return stack reset request
    output wire [15:0]                      ps_pull_data_del_o,                                   //parameter stack delayed pull data (available one cycle after the pull request)
    output wire [15:0]                      rs_pull_data_del_o,                                   //return stack delayed pull data (available one cycle after the pull request)
  //output wire                             ps_pull_data_val_o,                                   //parameter stack pull data valid indicator
  //output wire                             rs_pull_data_val_o,                                   //return stack pull data valid indicator
    output wire                             ps_push_bsy_o,                                        //parameter stack push busy indicator
    output wire                             rs_push_bsy_o,                                        //return stack push busy indicator
    output wire                             ps_pull_bsy_o,                                        //parameter stack pull busy indicator
    output wire                             rs_pull_bsy_o,                                        //return stack pull busy indicator

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






    //Parameter stack
    //----------------

    //AGU (LFSR)
    N1_lsfr 
      #(.WIDTH(8),                                                                         //address width
        .INCLUDE_0(1),                                                                     //cycle through 0
        .RST_VAL(8'h01),                                                                   //reset value
        .USE_UPPER_LIMIT =  1(1),                                                               //enable upper limit
        .USE_LOWER_LIMIT =  1(1))                                                               //enable lower limit
    N1_ls_ps_agu  
       (//Clock and reset
        .clk_i,                                                //module clock
        .async_rst_i,                                          //asynchronous reset
        .sync_rst_i,                                           //synchronous reset
        //LFSR status
        .lfsr_val_o,                                           //LFSR value
        .inc_val_o,                                            //incremented LFSR value
        .dec_val_o,                                            //decremented LFSR value
        .at_upper_limit_o,                                     //LFSR is at upper limit
        .at_lower_limit_o,                                     //LFSR is at lower limit
        //LFSR control
        input  wire                             .soft_rst_i,                                           //soft reset
    input  wire                                 .inc_i,                                                //increment LFSR
    input  wire                                 .dec_i,                                                //decrement LFSR   
        //LFSR limits
        .upper_limit_i,                                        //upper limit
        .lower_limit_i);                                       //lower limit

 






   
   


					    
   //Internal parameters
   //-------------------
   //                                  33222222 22221111 111111
   //                                  10987654 32109876 54321098 76543210
   localparam TABS = (WIDTH ==  2) ? 'b00000000_00000000_00000000_00000011 :
                     (WIDTH ==  3) ? 'b00000000_00000000_00000000_00000110 :
                     (WIDTH ==  4) ? 'b00000000_00000000_00000000_00001100 :
                     (WIDTH ==  5) ? 'b00000000_00000000_00000000_00010100 :
                     (WIDTH ==  6) ? 'b00000000_00000000_00000000_00110000 :
                     (WIDTH ==  7) ? 'b00000000_00000000_00000000_01100000 :
                     (WIDTH ==  8) ? 'b00000000_00000000_00000000_10111000 :
                     (WIDTH ==  9) ? 'b00000000_00000000_00000001_00010000 :
                     (WIDTH == 10) ? 'b00000000_00000000_00000010_01000000 :
                     (WIDTH == 11) ? 'b00000000_00000000_00000101_00000000 :
                     (WIDTH == 12) ? 'b00000000_00000000_00001110_00000000 :
                     (WIDTH == 13) ? 'b00000000_00000000_00011100_10000000 :
                     (WIDTH == 14) ? 'b00000000_00000000_00111000_00000010 :
                     (WIDTH == 15) ? 'b00000000_00000000_01100000_00000000 :
                     (WIDTH == 16) ? 'b00000000_00000000_11010000_00001000 :
                     (WIDTH == 17) ? 'b00000000_00000001_00100000_00000000 :
                     (WIDTH == 18) ? 'b00000000_00000010_00000100_00000000 :
                     (WIDTH == 19) ? 'b00000000_00000111_00100000_00000000 :
                     (WIDTH == 20) ? 'b00000000_00001001_00000000_00000000 :
                     (WIDTH == 21) ? 'b00000000_00010100_00000000_00000000 :
                     (WIDTH == 22) ? 'b00000000_00110000_00000000_00000000 :
                     (WIDTH == 23) ? 'b00000000_01000010_00000000_00000000 :
                     (WIDTH == 24) ? 'b00000000_11100001_00000000_00000000 :
                     (WIDTH == 25) ? 'b00000001_00100000_00000000_00000000 :
                     (WIDTH == 26) ? 'b00000010_00000000_00000000_00100011 :
                     (WIDTH == 27) ? 'b00000100_00000000_00000000_00010011 :
                     (WIDTH == 28) ? 'b00001001_00000000_00000000_00000000 :
                     (WIDTH == 29) ? 'b00010100_00000000_00000000_00000000 :
                     (WIDTH == 30) ? 'b00100000_00000000_00000000_00100101 :
                     (WIDTH == 31) ? 'b01001000_00000000_00000000_00000000 :
                                     'b00000000_00000000_00000000_00000000;

   //Internal registers
   //-----------------
   reg [WIDTH-1:0] 			    lfsr_reg;                                             //LFSR
    
   //Internal signals
   //----------------
   //Increment calculation
   wire                                     inc_feedback_without_0;                               //increment feeback without 0
   wire                                     inc_feedback_with_0;                                  //increment feeback with 0
   wire                                     inc_feedback;                                         //increment feedback
   wire [WIDTH-1:0]                         inc_val;                                              //increment value

   //Decrement calculation
   wire                                     dec_feedback_without_0;                               //increment feeback without 0
   wire                                     dec_feedback_with_0;                                  //increment feeback with 0
   wire                                     dec_feedback;                                         //increment feedback
   wire [WIDTH-1:0]                         dec_val;                                              //increment value

   //Limit check
   wire                                     at_upper_limit;                                       //LFSR is at upper limit
   wire                                     at_lower_limit;                                       //LFSR is at lower limit
   wire                                     inc_within_limit;                                     //increment if below upper limit
   wire                                     dec_within_limit;                                     //decrement if above lower limit

   //Logic
   //-----
   //Increment calculation
   assign  inc_feedback_without_0  = ^(lfsr_reg & TABS[WIDTH-1:0]);
   assign  inc_feedback_with_0     = inc_feedback_without_0 ^ ~|lfsr_reg[WIDTH-2:0];
   assign  inc_feedback            = INCLUDE_0 ? inc_feedback_with_0 : inc_feedback_without_0;
   assign  inc_val                 = {lfsr_reg[WIDTH-2:0],inc_feedback};
     
   //Decrement calculation
   assign  dec_feedback_without_0  = ^(lfsr_reg & {TABS[WIDTH-2:0],1'b1});
   assign  dec_feedback_with_0     = dec_feedback_without_0 ^ ~|lfsr_reg[WIDTH-1:1];
   assign  dec_feedback            = INCLUDE_0 ? dec_feedback_with_0 : dec_feedback_without_0;
   assign  dec_val                 = {dec_feedback,lfsr_reg[WIDTH-1:1]};
     
   //Limit check
   assign  at_upper_limit          = ~|(lfsr_reg ^ upper_limit_i);
   assign  at_lower_limit          = ~|(lfsr_reg ^ lower_limit_i);
   assign  inc_within_limit        = inc_i & ~(at_upper_limit & |USE_UPPER_LIMIT);                       
   assign  dec_within_limit        = dec_i & ~(at_lower_limit & |USE_LOWER_LIMIT);   
    
   //Shift register
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       lfsr_reg <= RST_VAL[WIDTH-1:0];                                                            //reset state
     else if (sync_rst_i)                                                                         //synchronous reset
       lfsr_reg <= RST_VAL[WIDTH-1:0];                                                            //reset state
     else if (soft_rst_i       |
              inc_within_limit |
              dec_within_limit)
       lfsr_reg <= (({WIDTH{      soft_rst_i}} & RST_VAL[WIDTH-1:0]) |
                    ({WIDTH{inc_within_limit}} & inc_val)            |
                    ({WIDTH{dec_within_limit}} & dec_val));

   
   //Outputs
   //-------
   assign  lfsr_val_o              = lfsr_reg;                                                    //LFSR value
   assign  inc_val_o               = inc_val;                                                     //incremented LFSR value
   assign  dec_val_o               = dec_val;                                                     //decremented LFSR value
   assign  at_upper_limit_o        = at_upper_limit;                                              //LFSR is at upper limit
   assign  at_lower_limit_o        = at_lower_limit;                                              //LFSR is at lower limit

endmodule // N1_lsfr
