//###############################################################################
//# N1 - Formal Testbench - Stack Bus Address Generation Unit                   #
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
//#    This is the the formal testbench for the stack bus AGU.                  #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   March 5, 2019                                                             #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

//DUT configuration
//=================
//Default configuration
//---------------------
`ifdef CONF_DEFAULT
`endif

//Fall back
//---------
`ifndef SP_WIDTH
`define SP_WIDTH  12
`endif
`ifndef PS_RS_DIST
`define PS_RS_DIST  22
`endif

module ftb_N1_sagu

   (//Stack bus (wishbone)
    output wire [`SP_WIDTH-1:0]             sbus_adr_o,               //address bus
    output wire                             sbus_tga_ps_o,            //parameter stack access
    output wire                             sbus_tga_rs_o,            //return stack access

    //Internal signals
    //----------------
    //DSP interface
    output wire                             sagu2dsp_psp_hold_o,      //maintain PSP
    output wire                             sagu2dsp_psp_op_sel_o,    //1:set new PSP, 0:add offset to PSP
    output wire [`SP_WIDTH-1:0]             sagu2dsp_psp_offs_o,      //PSP offset
    output wire [`SP_WIDTH-1:0]             sagu2dsp_psp_load_val_o,  //new PSP
    output wire                             sagu2dsp_rsp_hold_o,      //maintain RSP
    output wire                             sagu2dsp_rsp_op_sel_o,    //1:set new RSP, 0:add offset to RSP
    output wire [`SP_WIDTH-1:0]             sagu2dsp_rsp_offs_o,      //relative address
    output wire [`SP_WIDTH-1:0]             sagu2dsp_rsp_load_val_o,  //absolute address
    input  wire [`SP_WIDTH-1:0]             dsp2sagu_psp_next_i,      //parameter stack pointer
    input  wire [`SP_WIDTH-1:0]             dsp2sagu_rsp_next_i,      //return stack pointer

    //EXCPT  interface
    output wire                             sagu2excpt_psof_o,        //PS overflow
    output wire                             sagu2excpt_rsof_o,        //RS overflow

    //PRS interface
    input  wire                             prs2sagu_hold_i,          //maintain stack pointers
    input  wire                             prs2sagu_psp_rst_i,       //reset PSP
    input  wire                             prs2sagu_rsp_rst_i,       //reset RSP
    input  wire                             prs2sagu_stack_sel_i,     //1:RS, 0:PS
    input  wire                             prs2sagu_push_i,          //increment stack pointer
    input  wire                             prs2sagu_pull_i,          //decrement stack pointer
    input  wire                             prs2sagu_load_i,          //load stack pointer
    input  wire [`SP_WIDTH-1:0]             prs2sagu_psp_load_val_i,  //parameter stack load value
    input  wire [`SP_WIDTH-1:0]             prs2sagu_rsp_load_val_i); //return stack load value

   //Instantiation
   //=============
   N1_sagu
     #(.SP_WIDTH   (`SP_WIDTH),                                       //width of either stack pointer
       .PS_RS_DIST (`PS_RS_DIST))                                     //safety distance between PS and RS
   DUT
   (//Stack bus (wishbone)
      .sbus_adr_o               (sbus_adr_o),                         //address bus
      .sbus_tga_ps_o            (sbus_tga_ps_o),                      //parameter stack access
      .sbus_tga_rs_o            (sbus_tga_rs_o),                      //return stack access

      //DSP interface
      .sagu2dsp_psp_hold_o      (sagu2dsp_psp_hold_o),                //maintain PSP
      .sagu2dsp_psp_op_sel_o    (sagu2dsp_psp_op_sel_o),              //1:set new PSP, 0:add offset to PSP
      .sagu2dsp_psp_offs_o      (sagu2dsp_psp_offs_o),                //PSP offset
      .sagu2dsp_psp_load_val_o  (sagu2dsp_psp_load_val_o),            //new PSP
      .sagu2dsp_rsp_hold_o      (sagu2dsp_rsp_hold_o),                //maintain RSP
      .sagu2dsp_rsp_op_sel_o    (sagu2dsp_rsp_op_sel_o),              //1:set new RSP, 0:add offset to RSP
      .sagu2dsp_rsp_offs_o      (sagu2dsp_rsp_offs_o),                //relative address
      .sagu2dsp_rsp_load_val_o  (sagu2dsp_rsp_load_val_o),            //absolute address
      .dsp2sagu_psp_next_i      (dsp2sagu_psp_next_i),                //parameter stack pointer
      .dsp2sagu_rsp_next_i      (dsp2sagu_rsp_next_i),                //return stack pointer

      //EXCPT  interface
      .sagu2excpt_psof_o        (sagu2excpt_psof_o),                  //PS overflow
      .sagu2excpt_rsof_o        (sagu2excpt_rsof_o),                  //RS overflow

      //PRS interface
      .prs2sagu_hold_i          (prs2sagu_hold_i),                    //maintain stack pointers
      .prs2sagu_psp_rst_i       (prs2sagu_psp_rst_i),                 //reset PSP
      .prs2sagu_rsp_rst_i       (prs2sagu_rsp_rst_i),                 //reset RSP
      .prs2sagu_stack_sel_i     (prs2sagu_stack_sel_i),               //1:RS, 0:PS
      .prs2sagu_push_i          (prs2sagu_push_i),                    //increment stack pointer
      .prs2sagu_pull_i          (prs2sagu_pull_i),                    //decrement stack pointer
      .prs2sagu_load_i          (prs2sagu_load_i),                    //load stack pointer
      .prs2sagu_psp_load_val_i  (prs2sagu_psp_load_val_i),            //parameter stack load value
      .prs2sagu_rsp_load_val_i  (prs2sagu_rsp_load_val_i));           //return stack load value

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

`endif //  `ifdef FORMAL

endmodule // ftb_N1_sagu
