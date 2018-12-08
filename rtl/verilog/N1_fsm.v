//###############################################################################
//# N1 - Finite State Machine                                                   #
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
//#    This module implements the N1 processor's finite state machine (FSM).    #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_fsm
   (//Clock and reset
    //---------------
    input wire                             clk_i,            //module clock
    input wire                             async_rst_i,      //asynchronous reset
    input wire                             sync_rst_i,       //synchronous reset

    //Program bus
    //-----------
    output wire                            pbus_cyc_o,       //bus cycle indicator       +-
    output wire                            pbus_stb_o,       //access request            | initiator to target
    input  wire                            pbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                            pbus_err_i,       //error indicator           | target to
    input  wire                            pbus_rty_i,       //retry request             | initiator
    input  wire                            pbus_stall_i,     //access delay              +-


    


    
    );


   

   


   

endmodule // N1_fsm
