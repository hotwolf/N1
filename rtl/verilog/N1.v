//###############################################################################
//# N1 - Top Level                                                              #
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
//#    This is the top level block of the N1 processor.                         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1
  #(parameter  RST_ADR        = 'h0000,  //address of first instruction
    parameter  CELL_WIDTH     = 16,      //width of a cell
    localparam OPCODE_WIDTH   = 16,      //width of an opcode
    parameter  PBUS_ADR_WIDTH = 14,      //address width of the program bus
    parameter  DBUS_ADR_WIDTH = 16,      //address width of the data bus
    parameter  SBUS_ADR_WIDTH =  8)      //address width of the stack bus

   (//Clock and reset
    //---------------
    input wire                             clk_i,            //module clock
    input wire                             async_rst_i,      //asynchronous reset
    input wire                             sync_rst_i,       //synchronous reset

    //Program bus
    //-----------
    output wire                            pbus_cyc_o,       //bus cycle indicator       +-
    output wire                            pbus_stb_o,       //access request            | initiator to target
    output wire [PBUS_ADR_WIDTH-1:0]       pbus_adr_o,       //address bus               +-
    input  wire                            pbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                            pbus_err_i,       //error indicator           | target
    input  wire                            pbus_rty_i,       //retry request             | to
    input  wire                            pbus_stall_i,     //access delay              | initiator
    input  wire [PBUS_DAT_WIDTH-1:0]       pbus_dat_i,       //read data bus             +-

    //Data bus
    //--------
    output wire                            dbus_cyc_o,       //bus cycle indicator       +-
    output wire                            dbus_stb_o,       //access request            | initiator
    output wire                            dbus_we_o,        //write enable              | to	    
    output wire [(CELL_WIDTH/8)-1:0]       dbus_sel_o,       //write data selects        | target   
    output wire [DBUS_ADR_WIDTH-1:0]       dbus_adr_o,       //address bus               |
    output wire [CELL_WIDTH-1:0]           dbus_dat_o,       //write data bus            +-
    input  wire                            dbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                            dbus_err_i,       //error indicator           | target
    input  wire                            dbus_rty_i,       //retry request             | to
    input  wire                            dbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]           dbus_dat_i,       //read data bus             +-

    //Stack bus
    //---------
    output wire                            sbus_cyc_o,       //bus cycle indicator       +-
    output wire                            sbus_stb_o,       //access request            | initiator
    output wire                            sbus_we_o,        //write enable              | to
    output wire [SBUS_ADR_WIDTH-1:0]       sbus_adr_o,       //address bus               | target
    output wire [CELL_WIDTH-1:0]           sbus_dat_o,       //write data bus            +-
    input  wire                            sbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                            sbus_err_i,       //error indicator           | target
    input  wire                            sbus_rty_i,       //retry request             | to
    input  wire                            sbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]           sbus_dat_i,       //read data bus             +-

    //Interrupt interface
    //-------------------
    output wire                            irq_ack_o,        //interrupt acknowledge           
    input  wire [PBUS_ADR_WIDTH-1:0]       irq_vec_i,        //requested interrupt vector 

    //Communication interface    
    //-----------------------
    output wire                            com_tx_req_o,     //TX request
    output wire [COM_DAT_WIDTH-1:0]        com_tx_dat_o,     //TX data                      
    input  wire                            com_rx_req_i,     //RX request
    output wire [COM_DAT_WIDTH-1:0]        com_tx_dat_o,     //RX data                          
    );


   

   //Main finite state machine
   //-------------------------
       
   

   



endmodule // N1
