//###############################################################################
//# N1 - Intermediate Stack                                                     #
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
//#    This module implements the intermediate stack of the N1 processor. The   #
//#    intermediate stack receives push or pull requests from the upper stack.  #
//#    If possible these requests are executed on internal storage. In case of  #
//#    over or underflows, the requests are executed on the lower stack, which  #
//#    resides in RAM                                   .                       #
//#                                                                             #
//#        Upper Stack           Intermediate Stack                             #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+---+                     #
//#       |   |   |   |<=>|   |   |   |   |   |   |   |   |                     #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+-+-+                     #
//#                         ^                           |                       #
//#                         |                           v     +----------+      #
//#                       +-+-----------------------------+   |   RAM    |      #
//#                       |        RAM Controller         |<=>| (Lower   |      #
//#                       +-------------------------------+   |   Stack) |      #
//#                                                           +----------+      #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 3, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_is
  #(parameter   SP_WIDTH     =  8,                             //width of a stack pointer
    parameter   CELL_WIDTH   = 16,                             //cell width
    parameter   IS_DEPTH     =  8,                             //depth of the intermediate stack
    parameter   LS_DIR       =  0)                             //0=lower stack grows towards lower addresses
                                                               //1=lower stack grows towards higher addresses

   (//Clock and reset
    input wire 				    clk_i,             //module clock
    input wire 				    async_rst_i,       //asynchronous reset
    input wire 				    sync_rst_i,        //synchronous reset

    //Intermediate stack interface
    output reg  [CELL_WIDTH-1:0]            is_tos_o,          //data output: IS->US
    output reg                              is_filled_o,       //immediate stack holds data
    output  reg                             is_busy_o,         //RAM controller is busy
    input  reg  [CELL_WIDTH-1:0]            is_tos_i,          //data input: IS<-US
    input  reg                              is_psh_i,          //push data to TOS
    input  reg                              is_pul_i,          //pull data from TOS
  
    //Lower stack bus
    output reg                              lsbus_cyc_o,       //bus cycle indicator       +-
    output reg                              lsbus_stb_o,       //access request            | initiator 
    output reg                              lsbus_we_o,        //write enable              | to	       
    output reg  [SP_WIDTH-1:0]              lsbus_adr_o,       //address bus               | target    
    output reg  [CELL_WIDTH-1:0]            lsbus_dat_o,       //write data bus            +-
    input  wire                             lsbus_ack_i,       //bus cycle acknowledge     +-
    input  wire                             lsbus_err_i,       //error indicator           | target
    input  wire                             lsbus_rty_i,       //retry request             | to
    input  wire                             lsbus_stall_i,     //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]            lsbus_dat_i);      //read data bus             +-

    //Exceptions
    output wire                             excpt_lsbus_o,     //bus error
  
    //External address in-/decrementer
    output wire [SP_WIDTH:0]                agu_sp_o,          //current address
    output wire                             agu_inc_o,         //increment address
    output wire                             agu_dec_o,         //decrement address
    input  wire [SP_WIDTH:0]                agu_res_i,         //result

    //Probe signals
    output wire [IS_DEPTH-1:0]              prb_is_stat_o,     //intermediate stack status
    output wire [SP_WIDTH-1:0]              prb_ls_sp_o);      //lower stack pointer


   //Internal Signals					
   //----------------					
   //Shortcuts						
   wire 				    is_filled;         //IS content indicator
   wire 				    ls_filled;         //LS content indicator
                     
   
   //Internal regiters
   reg  [(IS_DEPTH*CELL_WIDTH)-1:0]        is_reg;             //intermediate stack content          
   reg  [IS_DEPTH-1:0]                     is_stat_reg;        //intermediate stack status
   reg                                     is_we;              //intermediate stack write enable      
   reg  [SP_WIDTH-1:0]                     ls_sp_reg;          //lower stack pointer
   reg  [SP_WIDTH-1:0]                     ls_sp_we;           //lower stack pointer write enable
   //FSM						
   reg  [1:0]  state_reg;                                      //state variable
   reg  [1:0]  state_next;                                     //next state

   //Shortcut assignments
   assign is_filled = is_stat_reg[0];                          //IS is filled 
   assign ls_filled = ~&{ls_sp_reg ^ {SP_WIDTH{|LS_DIR}});     //LS is filled 
   


   


   

   //Intermediate stack					
   //------------------					
   //TOS
   assign is_tos_o    = is_reg[CELL_WIDTH-1:0];                //TOS at lower indexes


   //IS content indicator
   assign is_filled_o = is_stat_reg[0];                        //IS is filled 
   

   //Busy condition
   assign is_busy_o   = (~is_stat_reg[0] & ls_filled) |        //LS pull required  
                        ( is_stat_reg[IS_DEPTH-1]);            //LS push required
   
    //
   





   

   //State variable					
   always @(posedge async_rst_i or posedge clk_i)	
     if (async_rst_i)                                            //asynchronous reset
       state_reg <= STATE_IDLE;				
     else if (sync_rst_i)                                        //synchronous reset
       state_reg <= STATE_IDLE;				
     else						
       state_reg <= state_next;                                  //state transition




    //					
 

   //Lower stack
   //-----------					



   //Finite state machine				
   localparam STATE_IDLE       = 2'b00;                          //awaiting bus request (reset state)
   localparam STATE_PS_BUSY    = 2'b01;                          //awaiting bus acknowledge
   localparam STATE_RS_BUSY    = 2'b10;                          //awaiting bus acknowledge
   localparam STATE_INVALID    = 2'b11;                          //unreachable state
   always @*						
     begin						
        //Default outputs				
        state_next    = state_reg;                               //remain in current state
							
  

        case (state_reg)
          STATE_IDLE:                                            //no ongoing bus cycle
            begin					
	       





	       //Unload LS
	       
   



	       


	       
   
endmodule // N1_is
