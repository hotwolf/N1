//###############################################################################
//# N1 - Lower Stack Bus Arbiter                                                #
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

module N1_lsarb
  #(parameter   SP_WIDTH    =  8,                                //width of a stack pointer
    parameter   CELL_WIDTH  = 16)                                //cell width
							
   (//Clock and reset					
    input  wire                             clk_i,               //module clock
    input  wire                             async_rst_i,         //asynchronous reset
    input  wire                             sync_rst_i,          //synchronous reset

    //Parameter stack bus
    input  wire                             lpsbus_cyc_i,        //bus cycle indicator       +-
    input  wire                             lpsbus_stb_i,        //access request            | initiator
    input  wire                             lpsbus_we_i,         //write enable              | to
    input  wire [SP_WIDTH-1:0]              lpsbus_adr_i,        //address bus               | target
    input  wire [CELL_WIDTH-1:0]            lpsbus_dat_i,        //write data bus            +-
    output reg                              lpsbus_ack_o,        //bus cycle acknowledge     +-
    output reg                              lpsbus_err_o,        //error indicator           | target
    output reg                              lpsbus_rty_o,        //retry request             | to
    output reg                              lpsbus_stall_o,      //access delay              | initiator
    output reg  [CELL_WIDTH-1:0]            lpsbus_dat_o,        //read data bus             +-
							
    //Return stack bus					
    input  wire                             lrsbus_cyc_i,        //bus cycle indicator       +-
    input  wire                             lrsbus_stb_i,        //access request            | initiator
    input  wire                             lrsbus_we_i,         //write enable              | to
    input  wire [SP_WIDTH-1:0]              lrsbus_adr_i,        //address bus               | target
    input  wire [CELL_WIDTH-1:0]            lrsbus_dat_i,        //write data bus            +-
    output reg                              lrsbus_ack_o,        //bus cycle acknowledge     +-
    output reg                              lrsbus_err_o,        //error indicator           | target
    output reg                              lrsbus_rty_o,        //retry request             | to
    output reg                              lrsbus_stall_o,      //access delay              | initiator
    output reg  [CELL_WIDTH-1:0]            lrsbus_dat_o,        //read data bus             +-
							
    //Merged stack bus					
    output reg                              sbus_cyc_o,          //bus cycle indicator       +-
    output reg                              sbus_stb_o,          //access request            |
    output reg                              sbus_we_o,           //write enable              | initiator
    output reg  [SP_WIDTH-1:0]              sbus_adr_o,          //address bus               | to
    output reg  [CELL_WIDTH-1:0]            sbus_dat_o,          //write data bus            | target
    output reg                              sbus_tga_ps_o,       //parameter stack access    |
    output reg                              sbus_tga_rs_o,       //return stack access       +-
    input  wire                             sbus_ack_i,          //bus cycle acknowledge     +-
    input  wire                             sbus_err_i,          //error indicator           | target
    input  wire                             sbus_rty_i,          //retry request             | to
    input  wire                             sbus_stall_i,        //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]            sbus_dat_i);         //read data bus             +-
							
   //Internal Signals					
   //----------------					
   //Shortcuts						
   wire        lpsbus_req = lpsbus_cyc_i & lpsbus_stb_i;         //parameter stack bus request
   wire        lrsbus_req = lrsbus_cyc_i & lrsbus_stb_i;         //return stack bus request
   wire        any_req   = lrsbus_req   | lrsbus_req;            //any bus request
   wire        any_ack   = sbus_ack_i|lsbus_err_i|lsbus_rty_i;   //any acknowledge
   //FSM						
   reg  [1:0]  state_reg;                                        //state variable
   reg  [1:0]  state_next;                                       //next state
							
   //Finite state machine				
   localparam STATE_IDLE       = 2'b00;                          //awaiting bus request (reset state)
   localparam STATE_PS_BUSY    = 2'b01;                          //awaiting bus acknowledge
   localparam STATE_RS_BUSY    = 2'b10;                          //awaiting bus acknowledge
   localparam STATE_INVALID    = 2'b11;                          //unreachable state
   always @*						
     begin						
        //Default outputs				
        state_next    = state_reg;                               //remain in current state
							
        lpsbus_ack_o   = 1'b0;                                   //bus cycle acknowledge     +-
        lpsbus_err_o   = 1'b0;                                   //error indicator           | target
        lpsbus_rty_o   = 1'b0;                                   //retry request             | to
        lpsbus_stall_o =sbus_stall_i;                            //access delay              | initiator
        lpsbus_dat_o   =sbus_dat_i;                              //read data bus             +-
							
        lrsbus_ack_o   = 1'b0;                                   //bus cycle acknowledge     +-
        lrsbus_err_o   = 1'b0;                                   //error indicator           | target
        lrsbus_rty_o   = 1'b0;                                   //retry request             | to
        lrsbus_stall_o =sbus_stall_i;                            //access delay              | initiator
        lrsbus_dat_o   =sbus_dat_i;                              //read data bus             +-

       sbus_cyc_o    = lpsbus_cyc_i | lrsbus_cyc_i;              //bus cycle indicator      +-
       sbus_stb_o    = lpsbus_stb_i | lrsbus_stb_i;              //access request           |
       sbus_we_o     = lpsbus_req ? lpsbus_we_i  : lrsbus_we_i;  //write enable             | initiator
       sbus_adr_o    = lpsbus_req ? lpsbus_adr_i : lrsbus_adr_i; //address bus              | to
       sbus_dat_o    = lpsbus_req ? lpsbus_dat_i : lrsbus_dat_i; //write data bus           | target
       sbus_tga_ps_o = lpsbus_req;                               //parameter stack access   |
       sbus_tga_rs_o = ~lpsbus_req;                              //return stack access      +-

        case (state_reg)
          STATE_IDLE:                                            //no ongoing bus cycle
            begin					
               if (~sbus_stall_i)                                //no stall
                 if (lpsbus_req)                                 //PS bus request
                   state_next = STATE_PS_BUSY;                   //get acknowledge from PS bus
                 else if (lrsbus_req)                            //RS bus request
                   state_next = STATE_RS_BUSY;                   //get acknowledge from PS bus
            end // case: STATE_IDLE			
							
          STATE_PS_BUSY:                                         //wait for acknowledge from PS bus
            begin					
               lpsbus_ack_o   =sbus_ack_i;                       //propagate
               lpsbus_err_o   =sbus_err_i;                       // acknowledges
               lpsbus_rty_o   =sbus_rty_i;                       // to the PS bus
							
               if (any_ack)                                      //last bus cycle terminated
                 if (sbus_stall_i)                               //stall from stack bus
                   state_next = STATE_IDLE;                      //no consecutive bus cycle
                 else					
                   if (lpsbus_req)                               //PS bus request
                     state_next = STATE_PS_BUSY;                 //get acknowledge from PS bus
                   else if (lrsbus_req)                          //RS bus request
                     state_next = STATE_RS_BUSY;                 //get acknowledge from PS bus
                   else                                          //no request
                     state_next = STATE_IDLE;                    //no consecutive bus cycle
            end // case: STATE_PS_BUSY			
							
          STATE_RS_BUSY:                                         //wait for acknowledge from RS bus
            begin					
               lrsbus_ack_o   =sbus_ack_i;                       //propagate
               lrsbus_err_o   =sbus_err_i;                       // acknowledges
               lrsbus_rty_o   =sbus_rty_i;                       // to the RS bus
							
               if (any_ack)                                      //last bus cycle terminated
                 if (sbus_stall_i)                               //stall from stack bus
                   state_next = STATE_IDLE;                      //no consecutive bus cycle
                 else					
                   if (lpsbus_req)                               //PS bus request
                     state_next = STATE_PS_BUSY;                 //get acknowledge from PS bus
                   else if (lrsbus_req)                          //RS bus request
                     state_next = STATE_RS_BUSY;                 //get acknowledge from PS bus
                   else                                          //no request
                     state_next = STATE_IDLE;                    //no consecutive bus cycle
            end // case: STATE_RS_BUSY			
							
          STATE_INVALID:                                         //unreachable state
            begin					
                state_next = STATE_IDLE;		
            end // case: STATE_INVALID			
							
        endcase // case (state_reg)			
     end // always @ (state            or...		
							
   //State variable					
   always @(posedge async_rst_i or posedge clk_i)	
     if (async_rst_i)                                            //asynchronous reset
       state_reg <= STATE_IDLE;				
     else if (sync_rst_i)                                        //synchronous reset
       state_reg <= STATE_IDLE;				
     else						
       state_reg <= state_next;                                  //state transition

endmodule // N1_sarb
