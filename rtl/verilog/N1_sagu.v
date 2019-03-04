//###############################################################################
//# N1 - Stack Bus Address Generation Unit                                      #
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
//#    This module provides addresses for the program bus (Pbus).               #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 27, 2019                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_sagu
  #(parameter   SP_WIDTH        =      12,                         //width of either stack pointer
    parameter   PS_RS_DIST      =      22)                         //safety sistance between PS and RS
								   
   (//Clock and reset						   
    input wire                               clk_i,                //module clock
    input wire                               async_rst_i,          //asynchronous reset
    input wire                               sync_rst_i,           //synchronous reset
								   
    //Stack bus (wishbone)					   
    output wire                              sbus_cyc_o,           //bus cycle indicator       +-
    output wire                              sbus_stb_o,           //access request            |
    output wire                              sbus_we_o,            //write enable              | initiator
    output wire [SP_WIDTH-1:0]               sbus_adr_o,           //address bus               | to
    output wire [15:0]                       sbus_dat_o,           //write data bus            | target
    output wire                              sbus_tga_ps_o,        //parameter stack access    |
    output wire                              sbus_tga_rs_o,        //return stack access       +-
    input  wire                              sbus_ack_i,           //bus cycle acknowledge     +-
    input  wire                              sbus_stall_i,         //access delay              | initiator
    input  wire [15:0]                       sbus_dat_i,           //read data bus             +-

    //ALU interface
    input  wire [15:0]                       alu2prs_ps0_next_i,   //new PS0 (TOS)
    input  wire [15:0]                       alu2prs_ps1_next_i,   //new PS1 (TOS+1)
    output wire [15:0]                       prs2alu_ps0_cur_o,    //current PS0 (TOS)
    output wire [15:0]                       prs2alu_ps1_cur_o,    //current PS1 (TOS+1)

    //Probe signals
 
    //Internal signals
    //----------------
    //DSP interface
    output wire                              sagu2dsp_psp_hold_o,  //keep PSP
    output wire [SP_WIDTH-1:0]               sagu2dsp_ps_aadr_o,   //PS absolute address
    output wire [SP_WIDTH-1:0]               sagu2dsp_ps_radr_o,   //PS relative address
    output wire                              sagu2dsp_ps_set_o,     //PS relative address
    output wire                              sagu2dsp_ps_add_o,     //PS relative address
    output wire                              sagu2dsp_ps_sub_o,     //PS relative address



    output wire                              sagu2dsp_psp_add_o,    //add offset to PSP
    output wire                              sagu2dsp_psp_sub_o,    //subtract offset from PSP
    output wire                              sagu2dsp_psp_load_o,   //load offset to PSP
    output wire                              sagu2dsp_psp_update_o, //update PSP
    output wire [SP_WIDTH-1:0]               sagu2dsp_rsp_offs_o,   //return stack pointer offset
    output wire                              sagu2dsp_rsp_add_o,    //add offset to RSP
    output wire                              sagu2dsp_rsp_sub_o,    //subtract offset from RSP
    output wire                              sagu2dsp_rsp_load_o,   //load offset to RSP
    output wire                              sagu2dsp_rsp_update_o, //update RSP
    input  wire [SP_WIDTH-1:0]               dsp2prs_psp_next_i,   //new lower parameter stack pointer
    input  wire [SP_WIDTH-1:0]               dsp2prs_rsp_next_i,   //new lower return stack pointer

    //EXCPT interface
    output wire                              prs2excpt_psof_o,     //parameter stack overflow
    output wire                              prs2excpt_rsof_o,     //return stack overflow

    //FC interface
    output wire                              prs2fc_hold_o,        //stacks not ready
    output wire                              prs2fc_ps0_true_o,    //PS0 in non-zero	
    input  wire                              fc2prs_hold_i,        //hold any state tran
    input  wire                              fc2prs_dat2ps0_i,     //capture read data
  
    //IR interface
    input  wire [15:0]                       ir2prs_lit_val_i,     //literal value
    input  wire [7:0]                        ir2prs_ups_tp_i,      //upper stack transition pattern
    input  wire [1:0]                        ir2prs_ips_tp_i,      //intermediate parameter stack transition pattern
    input  wire [1:0]                        ir2prs_irs_tp_i,      //intermediate return stack transition pattern
    input  wire                              ir2prs_alu2ps0_i,     //ALU output       -> PS0
    input  wire                              ir2prs_alu2ps1_i,     //ALU output       -> PS1
    input  wire                              ir2prs_dat2ps0_i,     //read data        -> PS0
    input  wire                              ir2prs_lit2ps0_i,     //literal          -> PS0
    input  wire                              ir2prs_ivec2ps0_i,    //interrupt vector -> PS0
    input  wire                              ir2prs_ps_rst_i,      //reset parameter stack
    input  wire                              ir2prs_rs_rst_i,      //reset return stack
    input  wire                              ir2prs_psp_rd_i,      //read parameter stack pointer
    input  wire                              ir2prs_psp_wr_i,      //write parameter stack pointer
    input  wire                              ir2prs_rsp_rd_i,      //read return stack pointer
    input  wire                              ir2prs_rsp_wr_i,      //write return stack pointer

							   




   //Internal signals
   //----------------
   //Upper and intermediate stacks
   reg  [(16*(IPS_DEPTH+IRS_DEPTH+5))-1:0]           ps_cells_reg;      //cell content
   wire [(16*(IPS_DEPTH+4))-1:0]           ps_cells_next;     //cell input
   reg  [IPS_DEPTH+3:0]                    ps_tags_reg;       //tag content
   wire [IPS_DEPTH+3:0]                    ps_tags_next;      //tag input
   wire [IPS_DEPTH+3:0]                    ps_we;             //write enable

   //Return stack
   reg  [(16*(IRS_DEPTH+1))-1:0]           rs_cells_reg;      //cell content
   wire [(16*(IRS_DEPTH+1))-1:0]           rs_cells_next;     //cell input
   reg  [IRS_DEPTH:0]                      rs_tags_reg;       //tag content
   wire [IRS_DEPTH:0]                      rs_tags_next;      //tag input
   wire [IRS_DEPTH:0]                      rs_we;             //write enable

   //Stack transition  

   //Stack underflow conditions
   wire 				   psuf_alu;           
   wire 				   psuf_shop;
   wire 				   rsuf_shop;
   wire 				   rsuf_eow;
   



   wire                                    fsm_update;        //perform IR operation
   wire                                    fsm_load;          //load cell from lower stack
   wire                                    fsm_unload;        //unload cell into lower stack
   wire                                    fsm_pack;          //move all cells into lower stack
   wire                                    fsm_unpack;        //retrive cells from lower stack 
      

endmodule // N1_sagu
