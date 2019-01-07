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

module N1_stackarb
  #(parameter   SP_WIDTH    =  8,                             //width of a stack pointer
    parameter   CELL_WIDTH  = 16)                             //width of a cell

   (//Clock and reset
    //---------------
    input  wire                             clk_i,            //module clock
    input  wire                             async_rst_i,      //asynchronous reset
    input  wire                             sync_rst_i,       //synchronous reset

    //Parameter stack bus
    input  wire                             psbus_cyc_i,      //bus cycle indicator       +-
    input  wire                             psbus_stb_i,      //access request            | initiator
    input  wire                             psbus_we_i,	      //write enable              | to	   
    input  wire [SP_WIDTH-1:0]              psbus_adr_i,      //address bus               | target    
    input  wire [CELL_WIDTH-1:0]            psbus_dat_i,      //write data bus            +-
    output wire                             psbus_ack_o,      //bus cycle acknowledge     +-
    output wire                             psbus_err_o,      //error indicator           | target
    output wire                             psbus_rty_o,      //retry request             | to
    output wire                             psbus_stall_o,    //access delay              | initiator
    output wire [CELL_WIDTH-1:0]            psbus_dat_o,      //read data bus             +-

    //Return stack bus
    input  wire                             rsbus_cyc_i,      //bus cycle indicator       +-
    input  wire                             rsbus_stb_i,      //access request            | initiator
    input  wire                             rsbus_we_i,	      //write enable              | to	   
    input  wire [SP_WIDTH-1:0]              rsbus_adr_i,      //address bus               | target    
    input  wire [CELL_WIDTH-1:0]            rsbus_dat_i,      //write data bus            +-
    output wire                             rsbus_ack_o,      //bus cycle acknowledge     +-
    output wire                             rsbus_err_o,      //error indicator           | target
    output wire                             rsbus_rty_o,      //retry request             | to
    output wire                             rsbus_stall_o,    //access delay              | initiator
    output wire [CELL_WIDTH-1:0]            rsbus_dat_o,      //read data bus             +-
 
     //Merged stack bus
    output wire                             sbus_cyc_o,       //bus cycle indicator       +-
    output wire                             sbus_stb_o,       //access request            | 
    output wire                             sbus_we_o,        //write enable              | initiator
    output wire [SP_WIDTH-1:0]              sbus_adr_o,       //address bus               | to	    
    output wire [CELL_WIDTH-1:0]            sbus_dat_o,       //write data bus            | target   
    output wire                             sbus_tga_ps_o,    //parameter stack access    |
    output wire                             sbus_tga_rs_o,    //return stack access       +-
    input  wire                             sbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                             sbus_err_i,       //error indicator           | target
    input  wire                             sbus_rty_i,       //retry request             | to
    input  wire                             sbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]            sbus_dat_i);      //read data bus             +-

   //Internal Signals
   //----------------
   //Incoming requests
   wire psbus_req      = psbus_cyc_i & psbus_stb_i;           //parameter stack bus
   wire rsbus_req      = rsbus_cyc_i & rsbus_stb_i;           //return stack bus
   //Arbitrated requests (parameter stack has higher priority)
   wire psbus_arb      =  psbus_req;                          //parameter stack bus
   wire rsbus_arb      = ~psbus_req & rsbus_req;              //return stack bus
   //Captured requests
   reg  psbus_cap_reg;                                        //parameter stack bus
   reg  rsbus_cap_reg;                                        //return stack bus
   //FSM
   reg                state_reg;                              //state variable
   reg                state_next;                             //next state
   //Control signals
   reg                capture;                                //capture arbitrated request
   reg                psbus_active;                           //activity indicator
   reg                rsbus_active;                           //activity indicator

   //Counters
   integer            i, j, k, l, m, n, o, p;

   //Captured request
   always @(posedge async_rst_i or posedge clk_i)
     if(async_rst_i)                                          //asynchronous reset
       begin
	  psbus_cap_reg <= 1'b0;                              //parameter stack bus
	  rsbus_cap_reg <= 1'b0;                              //return stack bus
       end
     else if(sync_rst_i)                                      //synchronous reset
       begin
	  psbus_cap_reg <= 1'b0;                              //parameter stack bus
	  rsbus_cap_reg <= 1'b0;                              //return stack bus
       end
     else if (capture)
       begin
	  psbus_cap_reg <= psbus_arb;                         //parameter stack bus
	  rsbus_cap_reg <= rsbus_arb;                         //return stack bus
       end

   //Plain signal propagation to the initiator buses
   assign psbus_dat_o   = sbus_dat_i;                         //read data bus
   assign rsbus_dat_o   = sbus_dat_i;                         //read data bus

   //Multiplexed signal propagation to the initiator buses
   assign psbus_ack_o   = sbus_ack_i & psbus_cap_reg;         //bus cycle acknowledge
   assign rsbus_ack_o   = sbus_ack_i & rsbus_cap_reg;         //bus cycle acknowledge
   assign psbus_err_o   = sbus_err_i & psbus_cap_reg;         //error indicator
   assign rsbus_err_o   = sbus_err_i & rsbus_cap_reg;         //error indicator
   assign psbus_rty_o   = sbus_rty_i & psbus_cap_reg;         //retry request
   assign rsbus_rty_o   = sbus_rty_i & rsbus_cap_reg;         //retry request

   //Multiplexed signal propagation to the target bus  
   assign sbus_we_o     =  rsbus_active ? rsbus_we_i  : psbus_we_i;  //write enable
   assign sbus_adr_o    =  rsbus_active ? rsbus_adr_i : psbus_adr_i; //address bus
   assign sbus_dat_o    =  rsbus_active ? rsbus_dat_i : psbus_dat_i; //write data bus
   assign sbus_tga_ps_o = ~rsbus_active;                             //parameter stack access
   assign sbus_tga_rs_o =  rsbus_active;                             //return stack access

   //Finite state machine
   parameter STATE_IDLE       = 1'b0;  //awaiting bus request (reset state)
   parameter STATE_BUSY       = 1'b1;  //awaiting bus acknowledge
   always @*
     begin
        //Default outputs
        state_next    = state_reg;                                      //remain in current state

        psbus_ack_o   = sbus_ack_i;      //bus cycle acknowledge     +-
        psbus_err_o   = sbus_err_i;      //error indicator           | target
        psbus_rty_o   = sbus_rty_i;      //retry request             | to
        psbus_stall_o = sbus_stall_i;    //access delay              | initiator
        psbus_dat_o   = sbus_dat_i;      //read data bus             +-
        
        rsbus_ack_o   = sbus_ack_i;      //bus cycle acknowledge     +-
        rsbus_err_o   = sbus_err_i;      //error indicator           | target
        rsbus_rty_o   = sbus_rty_i;      //retry request             | to
        rsbus_stall_o = sbus_stall_i;    //access delay              | initiator
        rsbus_dat_o   = sbus_dat_i;      //read data bus             +-
        
        sbus_cyc_o    = ;       //bus cycle indicator       +-
        sbus_stb_o    = ;       //access request            | 
        sbus_we_o     = ;        //write enable              | initiator
        sbus_adr_o    = ;       //address bus               | to	    
        sbus_dat_o    = ;       //write data bus            | target   
        sbus_tga_ps_o = ;    //parameter stack access    |
        sbus_tga_rs_o = ;    //return stack access       +-








        sbus_cyc_o  = 1'b0;                                           //target bus idle
        sbus_stb_o  = 1'b0;                                           //no target bus request
        itr_stall_o = {ITR_CNT{tgt_stall_i}};                         //propagate stall from target
        cyc_sel     = arb_req;                                        //propagate signals of arbitrated initiator
        capture_req = 1'b0;                                           //don't capture arbitrated request
        case (state_reg)
          STATE_IDLE:
            begin
               if (any_req)                                           //new bus request
                 begin
                    tgt_cyc_o   = 1'b1;                               //signal bus activity
                    tgt_stb_o   = 1'b1;                               //propagate new bus request
                 end
               if (any_req & ~tgt_stall_i)                            //new bus request, no stall
                 begin
                    state_next  = STATE_BUSY;                         //wait for acknowledge
                 end
               if (any_req & ~tgt_stall_i & ~locked)                  //new bus request, no stall, not locked
                 begin
                    itr_stall_o = ~arb_req;                           //stall all other initiators
                    capture_req = 1'b1;                               //capture arbitrated request
                 end
               if (any_req & ~tgt_stall_i & locked)                   //new bus request, no stall, locked
                 begin
                    itr_stall_o = ~cur_itr_reg;                       //stall all other initiators
                    cyc_sel     =  cur_itr_reg;                       //propagate signals of arbitrated initiator
                 end
            end // case: STATE_IDLE
          STATE_BUSY:
            begin
               tgt_cyc_o   = 1'b1;                                    //signal bus activity
               if (any_ack & any_req & ~tgt_stall_i)                  //request acknowleged, new bus request, no stall
                 begin
                    tgt_stb_o   = 1'b1;                               //request target bus
                 end
               if (any_ack & any_req & ~tgt_stall_i & ~locked)       //request acknowleged, new bus request, no stall, not locked
                 begin
                    itr_stall_o = ~cyc_sel;                          //stall all other initiators
                    cyc_sel     =  arb_req;                          //propagate signals of arbitrated initiator
                    capture_req = 1'b1;                              //capture arbitrated request
                 end
               if (any_ack & any_req & ~tgt_stall_i & locked)       //request acknowleged, new bus request, no stall, locked
                 begin
                    itr_stall_o = ~cur_itr_reg;                     //stall all other initiators
                    cyc_sel     =  cur_itr_reg;                     //propagate signals of arbitrated initiator
                 end
               if (any_ack & (~any_req | tgt_stall_i))              //request acknowleged, no bus request or stall
                 begin
                    state_next  = STATE_IDLE;                       //go to idle state
                 end
               if (~any_ack)                                          //no acknowlege
                 begin
                    itr_stall_o = ~cur_itr_reg;                       //stall all other initiators
                    cyc_sel     =  cur_itr_reg;                       //propagate signals of captured initiator
                 end
            end // case: STATE_BUSY
        endcase // case (state_reg)
     end // always @ (state            or...

   //State variable
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                 //asynchronous reset
       state_reg <= STATE_IDLE;
     else if (sync_rst_i)                                             //synchronous reset
       state_reg <= STATE_IDLE;
     else if(1)
       state_reg <= state_next;                                       //state transition

endmodule // N1_stackarb
    
