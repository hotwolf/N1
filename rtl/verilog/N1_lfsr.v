//###############################################################################
//# N1 - Linear Feedback Shift Register                                         #
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
//#    This module implements a generic LFSR to be used in the N1's stack AGUs. #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 12, 2024                                                          #
//#      - Initial release                                                      #
//#   April 25, 2025                                                            #
//#      - removed limits                                                       #
//#      - added overrun/underrun indicators                                    #
//###############################################################################
`default_nettype none

module N1_lsfr
  #(parameter WIDTH           =  8,                                                               //LFSR width
    parameter INCLUDE_0       =  1,                                                               //cycle through 0
    parameter START_VAL       =  8'h01)                                                           //enable lower limit

   (//Clock and reset
    input  wire                             clk_i,                                                //module clock
    input  wire                             async_rst_i,                                          //asynchronous reset
    input  wire                             sync_rst_i,                                           //synchronous reset

    //LFSR status
    output wire [WIDTH-1:0]                 lfsr_val_o,                                           //LFSR value
    output wire [WIDTH-1:0]                 lfsr_inc_val_o,                                       //incremented LFSR value
    output wire [WIDTH-1:0]                 lfsr_dec_val_o,                                       //decremented LFSR value

    //LFSR control
    input  wire                             lfsr_restart_i,                                       //soft reset
    input  wire                             lfsr_inc_i,                                           //increment LFSR
    input  wire                             lfsr_dec_i,                                           //decrement LFSR

    //LFSR overrun/underrun indicators
    output  wire                            lfsr_or_o,                                            //overrun at next INC request
    output  wire                            lfsr_ur_o,                                            //underrun at next DEC request

    //Probe signals
    output wire [WIDTH-1:0]                  prb_lfsr_o);                                         //probe signals

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
   reg [WIDTH-1:0]                          lfsr_reg;                                             //LFSR

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

   //Shift register
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                             //asynchronous reset
       lfsr_reg <= START_VAL[WIDTH-1:0];                                                          //reset state
     else if (sync_rst_i)                                                                         //synchronous reset
       lfsr_reg <= START_VAL[WIDTH-1:0];                                                          //reset state
     else if (lfsr_restart_i)                                                                     //soft reset
       lfsr_reg <= START_VAL[WIDTH-1:0];                                                          //restart state
     else if (lfsr_inc_i ^ lfsr_dec_i)
       lfsr_reg <= (({WIDTH{lfsr_inc_i}} & inc_val)   |
                    ({WIDTH{lfsr_dec_i}} & dec_val));


   //Outputs
   //-------
   assign  lfsr_val_o              = lfsr_reg;                                                    //LFSR value
   assign  lfsr_inc_val_o          = inc_val;                                                     //incremented LFSR value
   assign  lfsr_dec_val_o          = dec_val;                                                     //decremented LFSR value
   assign  lfsr_or_o               = ~|(inc_val ^ START_VAL);                                     //LFSR overrun with next increment
   assign  lfsr_ur_o               = ~|(dec_val ^ START_VAL);                                     //LFSR underrun with next decrement

   //Probe signals
   //-------------
   assign  prb_lfsr_o              = lfsr_reg;                                                     //probe signals
   

    //Assertions
    //----------
`ifdef FORMAL
    //State consistency checks
    //------------------------
    always @(posedge clk_i) begin
       //After an increment "lfsr_reg" must hold the value of the prior "inc_val"
       N1_lsfr_sasrt1:
       assert (      ~async_rst_i     &
               $past(~async_rst_i     &
                     ~sync_rst_i      &
                     ~lfsr_restart_i  &
                      inc_i            ) ? ~|($past(inc_val) ^ lfsr_reg) : 1'b1);

       //After an increment "dec_val" must hold the value of the prior "lfsr_reg"
       N1_lsfr_sasrt2:
       assert (      ~async_rst_i     &
               $past(~async_rst_i     &
                     ~sync_rst_i      &
                     ~lfsr_restart_i  &
                      inc_i            ) ? ~|(dec_val ^ $past(lfsr_reg) : 1'b1);

       //After a decrement "lfsr_reg" must hold the value of the prior "dec_val"
       N1_lsfr_sasrt3:
       assert       ~async_rst_i      &
               ($past(~async_rst_i    &
                     ~sync_rst_i      &
                     ~lfsr_restart_i  &
                      dec_i            ) ? ~|($past(dec_val) ^ lfsr_reg) : 1'b1);

       //After a decrement "inc_val" must hold the value of the prior "lfsr_reg"
       N1_lsfr_sasrt4:
       assert (      ~async_rst_i     &
               $past(~async_rst_i     &
                     ~sync_rst_i      &
                     ~lfsr_restart_i  &
                      dec_i            ) ? ~|(inc_val ^ $past(lfsr_reg) : 1'b1);

       //No increment above the upper limit
       N1_lsfr_sasrt5:
       assert (      USE_UPPER_LIMIT  &
                     ~async_rst_i     &
               $past(~async_rst_i     &
                     ~sync_rst_i      &
                     ~lfsr_restart_i  &
                      inc_i            ) ? $stable(lfsr_reg) : 1'b1);

       //No decrement below the lower limit
       N1_lsfr_sasrt6:
       assert (      USE_LOWER_LIMIT  &
                     ~async_rst_i     &
               $past(~async_rst_i     &
                     ~sync_rst_i      &
                     ~lfsr_restart_i  &
                      dec_i            ) ? $stable(lfsr_reg) : 1'b1);

       //Soft reset
       N1_lsfr_sasrt7:
       assert ($past(lfsr_restart_i) ? ~|(lfsr_reg ^ RST_VAL[WIDTH-1:0]) : 1'b1);

    end // always @ (posedge clk_i)

`endif //  `ifdef FORMAL

endmodule // N1_lsfr
