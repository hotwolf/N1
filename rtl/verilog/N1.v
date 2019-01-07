//###############################################################################
//# N1 - Top Level                                                              #
//###############################################################################
//#    Copyright 2018 - 2019 Dirk Heisswolf                                     #
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
  #(parameter   RST_ADR     = 'h0000,                        //address of first instruction
    parameter   SP_WIDTH    =  8,                            //width of a stack pointer
    localparam  CELL_WIDTH  = 16,                            //width of a cell
    localparam  PC_WIDTH    = 14,                            //width of the program counter
    localparam  PSUP_DEPTH  = 5,                             //depth of the upper parameter stack 
    localparam  PSIM_DEPTH  = 8,                             //depth of the immediate parameter stack
    localparam  PSUP_DEPTH  = 1,                             //depth of the upper return stack 
    localparam  PSIM_DEPTH  = 8)                             //depth of the immediate return stack

   (//Clock and reset
    input  wire                            clk_i,            //module clock
    input  wire                            async_rst_i,      //asynchronous reset
    input  wire                            sync_rst_i,       //synchronous reset

    //Program bus
    output wire                            pbus_cyc_o,       //bus cycle indicator       +-
    output wire                            pbus_stb_o,       //access request            | initiator to target
    output wire [PC_WIDTH-1:0]             pbus_adr_o,       //address bus               |
    output wire                            pbus_tga_imadr_o, //immediate (short) address +-	    
    input  wire                            pbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                            pbus_err_i,       //error indicator           | target
    input  wire                            pbus_rty_i,       //retry request             | to
    input  wire                            pbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]           pbus_dat_i,       //read data bus             +-

    //Data bus
    output wire                            dbus_cyc_o,       //bus cycle indicator       +-
    output wire                            dbus_stb_o,       //access request            | 
    output wire                            dbus_we_o,        //write enable              | initiator
    output wire [(CELL_WIDTH/8)-1:0]       dbus_sel_o,       //write data selects        | to	    
    output wire [CELL_WIDTH-1:0]           dbus_adr_o,       //address bus               | target   
    output wire [CELL_WIDTH-1:0]           dbus_dat_o,       //write data bus            |
    output wire                            dbus_tga_imadr_o, //immediate (short) address +-	    
    input  wire                            dbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                            dbus_err_i,       //error indicator           | target
    input  wire                            dbus_rty_i,       //retry request             | to
    input  wire                            dbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]           dbus_dat_i,       //read data bus             +-

    //Stack bus
    output wire                            sbus_cyc_o,       //bus cycle indicator       +-
    output wire                            sbus_stb_o,       //access request            | 
    output wire                            sbus_we_o,        //write enable              | initiator
    output wire [SP_WIDTH-1:0]             sbus_adr_o,       //address bus               | to	    
    output wire [CELL_WIDTH-1:0]           sbus_dat_o,       //write data bus            | target   
    output wire                            sbus_tga_ps_o,    //parameter stack access    |
    output wire                            sbus_tga_rs_o,    //return stack access       +-
    input  wire                            sbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                            sbus_err_i,       //error indicator           | target
    input  wire                            sbus_rty_i,       //retry request             | to
    input  wire                            sbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]           sbus_dat_i,       //read data bus             +-

    //Interrupt interface
    //-------------------
    output wire                            irq_ack_o,        //interrupt acknowledge           
    input  wire [PC_WIDTH-1:0]             irq_vec_i,        //requested interrupt vector 

    //Probe signals
    //-------------
    //Program counter   
    output wire [PC_WIDTH-1:0]             prb_pc_o,         //program counter
    //Instruction register  
    output wire [CELL_WIDTH-1:0]           prb_ir_o,         //instruction register
    //Parameter stack
    output wire [PSUP_DEPTH-1:0]           prb_psup_stat_o,  //upper parameter stack status
    output wire [PSIM_DEPTH-1:0]           prb_psim_stat_o,  //intermediate parameter stack status
    output wire [SP_WIDTH-1:0]             prb_pslo_sp_o,    //lower parameter stack pointer
    //Return stack
    output wire [RSUP_DEPTH-1:0]           prb_rsup_stat_o,  //upper return stack status
    output wire [RSIM_DEPTH-1:0]           prb_rsim_stat_o,  //intermediate return stack status
    output wire [SP_AWIDTH-1:0]            prb_rslo_sp_o);   //lower return stack pointer
    
   
   //Internal Signals
   //----------------
   
   //Parameter stack bus
   wire 				   psbus_cyc;       //bus cycle indicator       +-
   wire 				   psbus_stb;       //access request            | initiator
   wire 				   psbus_we;        //write enable              | to	   
   wire [SP_WIDTH-1:0] 			   psbus_adr;       //address bus               | target    
   wire [CELL_WIDTH-1:0] 		   psbus_wdat;      //write data bus            +-
   wire 				   psbus_ack;       //bus cycle acknowledge     +-
   wire 				   psbus_err;       //error indicator           | target
   wire 				   psbus_rty;       //retry request             | to
   wire 				   psbus_stall;     //access delay              | initiator
   wire [CELL_WIDTH-1:0] 		   psbus_rdat;      //read data bus             +-

   //Return stack bus
   wire 				   rsbus_cyc;       //bus cycle indicator       +-
   wire 				   rsbus_stb;       //access request            | initiator
   wire 				   rsbus_we;        //write enable              | to	   
   wire [SP_WIDTH-1:0] 			   rsbus_adr;       //address bus               | target    
   wire [CELL_WIDTH-1:0] 		   rsbus_wdat;      //write data bus            +-
   wire 				   rsbus_ack;       //bus cycle acknowledge     +-
   wire 				   rsbus_err;       //error indicator           | target
   wire 				   rsbus_rty;       //retry request             | to
   wire 				   rsbus_stall;     //access delay              | initiator
   wire [CELL_WIDTH-1:0] 		   rsbus_rdat;      //read data bus             +-

				    





   //Stack bus arbiter
   //-----------------
   N1_stackarb
     #(.SP_WIDTH   (SP_WIDTH),
       .CELL_WIDTH (CELL_WIDTH))
   N1_stackarb
     (//Clock and reset
      .clk_i		(clk_i),           //module clock
      .async_rst_i	(async_rst_i),     //asynchronous reset
      .sync_rst_i	(sync_rst_i),      //synchronous reset
      
     //Parameter stack bus
     .psbus_cyc_i	(psbus_cyc),       //bus cycle indicator       +-
     .psbus_stb_i	(psbus_stb),       //access request            | initiator
     .psbus_we_i	(psbus_we),        //write enable              | to	   
     .psbus_adr_i	(psbus_adr),       //address bus               | target    
     .psbus_dat_i	(psbus_wdat),      //write data bus            +-
     .psbus_ack_o	(psbus_ack),       //bus cycle acknowledge     +-
     .psbus_err_o	(psbus_err),       //error indicator           | target
     .psbus_rty_o	(psbus_rty),       //retry request             | to
     .psbus_stall_o	(psbus_stall),     //access delay              | initiator
     .psbus_dat_o	(psbus_rdat),      //read data bus             +-

     //Return stack bus
     .rsbus_cyc_i	(rsbus_cyc),       //bus cycle indicator       +-
     .rsbus_stb_i	(rsbus_stb),       //access request            | initiator
     .rsbus_we_i	(rsbus_we),        //write enable              | to	   
     .rsbus_adr_i	(rsbus_adr),       //address bus               | target    
     .rsbus_dat_i	(rsbus_wdat),      //write data bus            +-
     .rsbus_ack_o	(rsbus_ack),       //bus cycle acknowledge     +-
     .rsbus_err_o	(rsbus_err),       //error indicator           | target
     .rsbus_rty_o	(rsbus_rty),       //retry request             | to
     .rsbus_stall_o	(rsbus_stall),     //access delay              | initiator
     .rsbus_dat_o	(rsbus_rdat),      //read data bus             +-
 
     //Merged stack bus
     .sbus_cyc_o	(sbus_cyc_o),       //bus cycle indicator      +-
     .sbus_stb_o	(sbus_stb_o),       //access request           | 
     .sbus_we_o		(sbus_we_o),        //write enable             | initiator
     .sbus_adr_o	(sbus_adr_o),       //address bus              | to	    
     .sbus_dat_o	(sbus_dat_o),       //write data bus           | target   
     .sbus_tga_ps_o	(sbus_tga_ps_o),    //parameter stack access   |
     .sbus_tga_rs_o	(sbus_tga_rs_o),    //return stack access      +-
     .sbus_ack_i	(sbus_ack_i),       //bus cycle acknowledge    +-
     .sbus_err_i	(sbus_err_i),       //error indicator          | target
     .sbus_rty_i	(sbus_rty_i),       //retry request            | to
     .sbus_stall_i	(sbus_stall_i),     //access delay             | initiator
     .sbus_dat_i	(sbus_dat_i));      //read data bus            +-
 
   

//   //Flow control
//   //------------
//   N1_flowctrl 
//     #(.RST_ADR(RST_ADR)) 
//   N1_flowctrl
//   (//Clock and reset
//    //---------------
//    .clk_i		(clk_i),            //module clock
//    .async_rst_i	(async_rst_i),      //asynchronous reset
//    .sync_rst_i		(sync_rst_i),       //synchronous reset
//
//    //Program bus
//    //-----------
//    .pbus_cyc_o		(pbus_cyc_o),       //bus cycle indicator       +-
//    .pbus_stb_o		(pbus_stb_o),       //access request            | initiator to target
//    .pbus_adr_o		(pbus_adr_o),       //address bus               +-
//    .pbus_ack_i		(pbus_ack_i),       //bus cycle acknowledge     +-
//    .pbus_err_i		(pbus_err_i),       //error indicator           | target
//    .pbus_rty_i		(pbus_rty_i),       //retry request             | to
//    .pbus_stall_i	(pbus_stall_i),     //access delay              | initiator
//  //.pbus_dat_i		(pbus_dat_i),       //read data bus             +-
//   
//    //Interrupt interface
//    //-------------------
//    .irq_ack_o		(irq_ack_o),        //interrupt acknowledge           
//    .irq_vec_i		(irq_vec_i),       //requested interrupt vector 


   


endmodule // N1
