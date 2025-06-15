//###############################################################################
//# N1 - Wishbone Interface with Arbiter                                        #
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
//#    This module connects two memory interfaces to a Wishbone bus. The        #
//#    arbitration has a fixed priority.                                        #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   May 14, 2025                                                              #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_wbi
  #(parameter   ADDR_WIDTH  = 14)                                                      //RAM address width

   (//Clock and reset
    input  wire                              clk_i,                                    //module clock
    input  wire                              async_rst_i,                              //asynchronous reset
    input  wire                              sync_rst_i,                               //synchronous reset

    //High priority memory interface
    input  wire [ADDR_WIDTH-1:0]             hiprio_addr_i,                            //address
    input  wire                              hiprio_access_i,                          //access request
    input  wire                              hiprio_rwb_i,                             //data direction
    input  wire [15:0]                       hiprio_wdata_i,                           //write data
    output wire                              hiprio_access_bsy_o,                      //access request rejected
    output wire [15:0]                       hiprio_rdata_o,                           //read data
    output wire                              hiprio_rdata_del_o,                       //read data delay

    //Low priority memory interface
    input  wire [ADDR_WIDTH-1:0]             loprio_addr_i,                            //address
    input  wire                              loprio_access_i,                          //access request
    input  wire                              loprio_rwb_i,                             //data direction
    input  wire [15:0]                       loprio_wdata_i,                           //write data
    output wire                              loprio_access_bsy_o,                      //access request rejected
    output wire [15:0]                       loprio_rdata_o,                           //read data
    output wire                              loprio_rdata_del_o,                       //read data delay

    //Bus error
    output wire                              wbi_bus_error,                            //bus error

    //Wishbone bus
    input  wire                              wb_ack_i,                                 //bus cycle acknowledge
    input  wire                              wb_err_i,              		       //bus error
    input  wire                              wb_stall_i,                               //access delay
    input  wire [15:0]                       wb_dat_i,                                 //read data bus
    output wire                              wb_cyc_o,                                 //bus cycle indicator
    output wire                              wb_stb_o,                                 //access request
    output wire                              wb_we_o,                                  //write enable
    output wire                              wb_tga_hiprio_o,                          //access from high prio interface
    output wire                              wb_tga_loprio_o,                          //access from low prio interface
    output wire [ADDR_WIDTH-1:0]             wb_adr_o,                                 //address bus
    output wire [15:0]                       wb_dat_o);                                //write data bus

   //Internal signals
   //----------------
   reg                                       cyc_reg;                                  //FF to drive Wishbone compliant CYC_O

   //Arbiter
   //-------
   assign wb_stb_o            = hiprio_access_i ?  hiprio_access_i :  loprio_access_i; //access request
   assign wb_we_o             = hiprio_access_i ? ~hiprio_rwb_i    : ~loprio_rwb_i;    //write enable
   assign wb_tga_hiprio_o     =  hiprio_access_i;                                      //access from high prio interface
   assign wb_tga_loprio_o     = ~hiprio_access_i;                                      //access from low prio interface
   assign wb_adr_o            = hiprio_access_i ?  hiprio_addr_i   :  loprio_addr_i;   //address bus
   assign wb_dat_o            = hiprio_access_i ?  hiprio_wdata_i  :  loprio_wdata_i;  //write data bus

   assign hiprio_access_bsy_o = wb_stall_i;                                            //access request rejected
   assign hiprio_rdata_o      = wb_dat_i;                                              //read data
   assign hiprio_rdata_del_o  = ~wb_ack_i;                                             //read data delay

   assign loprio_access_bsy_o = hiprio_access_i | wb_stall_i;                          //access request rejected
   assign loprio_rdata_o      = wb_dat_i;                                              //read data
   assign loprio_rdata_del_o  = ~wb_ack_i;                                             //read data delay

   //Generate Wishbone compliant CYC_O outout
   assign wb_cyc_o            = wb_stb_o | cyc_reg;                                    //bus cycle indicator

    //Bus error
    assign wbi_bus_error      = cyc_reg & wb_err_i;                                    //bus error
   
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                                  //asynchronous reset
       cyc_reg <= 1'b0;                                                                //reset state
     else if (sync_rst_i)                                                              //synchronous reset
       cyc_reg <= 1'b0;                                                                //reset state
     else if (wb_stb_o)                                                                //start of cycle
       cyc_reg <= 1'b1;                                                                //signal access cycle
     else if (wb_ack_i)                                                                //start of cycle
       cyc_reg <= 1'b0;                                                                //stop signaling access cycle

endmodule // N1_wbi
