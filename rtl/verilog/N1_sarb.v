//###############################################################################
//# N1 - Stack Bus Arbiter                                                      #
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
//#    This block merges the two Wishbone interfaces of the lower parameter and #
//#    return stacks into one.                                                  #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_sarb
  #(parameter   SP_WIDTH   = 12)                                       //width of a stack pointer

   (//Clock and reset
    input  wire                             clk_i,                     //module clock
    input  wire                             async_rst_i,               //asynchronous reset
    input  wire                             sync_rst_i,                //synchronous reset

    //Merged stack bus (wishbone)
    output reg                              sbus_cyc_o,                //bus cycle indicator       +-
    output reg                              sbus_stb_o,                //access request            |
    output reg                              sbus_we_o,                 //write enable              | initiator
    output reg  [SP_WIDTH-1:0]              sbus_adr_o,                //address bus               | to
    output reg  [15:0]                      sbus_dat_o,                //write data bus            | target
    output reg                              sbus_tga_ps_o,             //parameter stack access    |
    output reg                              sbus_tga_rs_o,             //return stack access       +-
    input  wire                             sbus_ack_i,                //bus cycle acknowledge     +-
    input  wire                             sbus_err_i,                //error indicator           | target
    input  wire                             sbus_rty_i,                //retry request             | to
    input  wire                             sbus_stall_i,              //access delay              | initiator
    input  wire [15:0]                      sbus_dat_i,                //read data bus             +-

    //Parameter stack bus (wishbone)
    input  wire                             ips_sarb_cyc_i,            //bus cycle indicator       +-
    input  wire                             ips_sarb_stb_i,            //access request            | initiator
    input  wire                             ips_sarb_we_i,             //write enable              | to
    input  wire [SP_WIDTH-1:0]              ips_sarb_adr_i,            //address bus               | target
    input  wire [15:0]                      ips_sarb_dat_i,            //write data bus            +-
    output reg                              ips_sarb_ack_o,            //bus cycle acknowledge     +-
    output reg                              ips_sarb_err_o,            //error indicator           | target
    output reg                              ips_sarb_rty_o,            //retry request             | to
    output reg                              ips_sarb_stall_o,          //access delay              | initiator
    output reg  [15:0]                      ips_sarb_dat_o,            //read data bus             +-

    //Return stack bus (wishbone)
    input  wire                             irs_sarb_cyc_i,            //bus cycle indicator       +-
    input  wire                             irs_sarb_stb_i,            //access request            | initiator
    input  wire                             irs_sarb_we_i,             //write enable              | to
    input  wire [SP_WIDTH-1:0]              irs_sarb_adr_i,            //address bus               | target
    input  wire [15:0]                      irs_sarb_dat_i,            //write data bus            +-
    output reg                              irs_sarb_ack_o,            //bus cycle acknowledge     +-
    output reg                              irs_sarb_err_o,            //error indicator           | target
    output reg                              irs_sarb_rty_o,            //retry request             | to
    output reg                              irs_sarb_stall_o,          //access delay              | initiator
    output reg  [15:0]                      irs_sarb_dat_o,            //read data bus             +-

    //Probe signals
    output wire [1:0]                       prb_sarb_state_o);         //FSM state

   //Internal Signals
   //----------------
   //Shortcuts
   wire        ips_sarb_req = ips_sarb_cyc_i & ips_sarb_stb_i;         //parameter stack bus request
   wire        irs_sarb_req = irs_sarb_cyc_i & irs_sarb_stb_i;         //return stack bus request
   wire        any_req   = irs_sarb_req   | irs_sarb_req;              //any bus request
   wire        any_ack   = sbus_ack_i|sbus_err_i|sbus_rty_i;           //any acknowledge
   //FSM
   reg  [1:0]  state_reg;                                              //state variable
   reg  [1:0]  state_next;                                             //next state

   //Finite state machine
   localparam STATE_IDLE       = 2'b00;                                //awaiting bus request (reset state)
   localparam STATE_PS_BUSY    = 2'b01;                                //awaiting bus acknowledge
   localparam STATE_RS_BUSY    = 2'b10;                                //awaiting bus acknowledge
   localparam STATE_INVALID    = 2'b11;                                //unreachable state
   always @*
     begin
        //Default outputs
        state_next    = state_reg;                                     //remain in current state

        ips_sarb_ack_o   = 1'b0;                                       //bus cycle acknowledge     +-
        ips_sarb_err_o   = 1'b0;                                       //error indicator           | target
        ips_sarb_rty_o   = 1'b0;                                       //retry request             | to
        ips_sarb_stall_o =sbus_stall_i;                                //access delay              | initiator
        ips_sarb_dat_o   =sbus_dat_i;                                  //read data bus             +-

        irs_sarb_ack_o   = 1'b0;                                       //bus cycle acknowledge     +-
        irs_sarb_err_o   = 1'b0;                                       //error indicator           | target
        irs_sarb_rty_o   = 1'b0;                                       //retry request             | to
        irs_sarb_stall_o =sbus_stall_i;                                //access delay              | initiator
        irs_sarb_dat_o   =sbus_dat_i;                                  //read data bus             +-

       sbus_cyc_o    = ips_sarb_cyc_i | irs_sarb_cyc_i;                //bus cycle indicator      +-
       sbus_stb_o    = ips_sarb_stb_i | irs_sarb_stb_i;                //access request           |
       sbus_we_o     = ips_sarb_req ? ips_sarb_we_i  : irs_sarb_we_i;  //write enable             | initiator
       sbus_adr_o    = ips_sarb_req ? ips_sarb_adr_i : irs_sarb_adr_i; //address bus              | to
       sbus_dat_o    = ips_sarb_req ? ips_sarb_dat_i : irs_sarb_dat_i; //write data bus           | target
       sbus_tga_ps_o = ips_sarb_req;                                   //parameter stack access   |
       sbus_tga_rs_o = ~ips_sarb_req;                                  //return stack access      +-

        case (state_reg)
          STATE_IDLE:                                                  //no ongoing bus cycle
            begin
               if (~sbus_stall_i)                                      //no stall
                 if (ips_sarb_req)                                     //PS bus request
                   state_next = STATE_PS_BUSY;                         //get acknowledge from PS bus
                 else if (irs_sarb_req)                                //RS bus request
                   state_next = STATE_RS_BUSY;                         //get acknowledge from PS bus
            end // case: STATE_IDLE

          STATE_PS_BUSY:                                               //wait for acknowledge from PS bus
            begin
               ips_sarb_ack_o   =sbus_ack_i;                           //propagate
               ips_sarb_err_o   =sbus_err_i;                           // acknowledges
               ips_sarb_rty_o   =sbus_rty_i;                           // to the PS bus

               if (any_ack)                                            //last bus cycle terminated
                 if (sbus_stall_i)                                     //stall from stack bus
                   state_next = STATE_IDLE;                            //no consecutive bus cycle
                 else
                   if (ips_sarb_req)                                   //PS bus request
                     state_next = STATE_PS_BUSY;                       //get acknowledge from PS bus
                   else if (irs_sarb_req)                              //RS bus request
                     state_next = STATE_RS_BUSY;                       //get acknowledge from PS bus
                   else                                                //no request
                     state_next = STATE_IDLE;                          //no consecutive bus cycle
            end // case: STATE_PS_BUSY

          STATE_RS_BUSY:                                               //wait for acknowledge from RS bus
            begin
               irs_sarb_ack_o   =sbus_ack_i;                           //propagate
               irs_sarb_err_o   =sbus_err_i;                           // acknowledges
               irs_sarb_rty_o   =sbus_rty_i;                           // to the RS bus

               if (any_ack)                                            //last bus cycle terminated
                 if (sbus_stall_i)                                     //stall from stack bus
                   state_next = STATE_IDLE;                            //no consecutive bus cycle
                 else
                   if (ips_sarb_req)                                   //PS bus request
                     state_next = STATE_PS_BUSY;                       //get acknowledge from PS bus
                   else if (irs_sarb_req)                              //RS bus request
                     state_next = STATE_RS_BUSY;                       //get acknowledge from PS bus
                   else                                                //no request
                     state_next = STATE_IDLE;                          //no consecutive bus cycle
            end // case: STATE_RS_BUSY

          STATE_INVALID:                                               //unreachable state
            begin
                state_next = STATE_IDLE;
            end // case: STATE_INVALID

        endcase // case (state_reg)
     end // always @ (state            or...

   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                  //asynchronous reset
       state_reg <= STATE_IDLE;
     else if (sync_rst_i)                                              //synchronous reset
       state_reg <= STATE_IDLE;
     else
       state_reg <= state_next;                                        //state transition

    //Probe signals
    //-------------
    assign prb_sarb_state_o = state_reg;                               //FSM state

endmodule // N1_sarb
