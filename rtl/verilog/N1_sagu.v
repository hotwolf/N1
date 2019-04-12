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
  #(parameter   SP_WIDTH        =      12,                              //width of either stack pointer
    parameter   PS_RS_DIST      =      22)                              //safety sistance between PS and RS

   (//Stack bus (wishbone)
    output wire [SP_WIDTH-1:0]              sbus_adr_o,                 //address bus
    output wire                             sbus_tga_ps_o,              //parameter stack access
    output wire                             sbus_tga_rs_o,              //return stack access

    //Internal signals
    //----------------
    //DSP interface
    output wire                             sagu2dsp_psp_hold_o,        //maintain PSP
    output wire                             sagu2dsp_psp_op_sel_o,      //1:set new PSP, 0:add offset to PSP
    output wire [SP_WIDTH-1:0]              sagu2dsp_psp_offs_o,        //PSP offset
    output wire [SP_WIDTH-1:0]              sagu2dsp_psp_load_val_o,    //new PSP
    output wire                             sagu2dsp_rsp_hold_o,        //maintain RSP
    output wire                             sagu2dsp_rsp_op_sel_o,      //1:set new RSP, 0:add offset to RSP
    output wire [SP_WIDTH-1:0]              sagu2dsp_rsp_offs_o,        //relative address
    output wire [SP_WIDTH-1:0]              sagu2dsp_rsp_load_val_o,    //absolute address
    input  wire [SP_WIDTH-1:0]              dsp2sagu_psp_next_i,        //parameter stack pointer
    input  wire [SP_WIDTH-1:0]              dsp2sagu_rsp_next_i,        //return stack pointer

    //EXCPT  interface
    output wire                             sagu2excpt_psof_o,          //PS overflow
    output wire                             sagu2excpt_rsof_o,          //RS overflow

    //PRS interface
    input  wire                             prs2sagu_hold_i,            //maintain stack pointers
    input  wire                             prs2sagu_psp_rst_i,         //reset PSP
    input  wire                             prs2sagu_rsp_rst_i,         //reset RSP
    input  wire                             prs2sagu_stack_sel_i,       //1:RS, 0:PS
    input  wire                             prs2sagu_push_i,            //increment stack pointer
    input  wire                             prs2sagu_pull_i,            //decrement stack pointer
    input  wire                             prs2sagu_load_i,            //load stack pointer
    input  wire [SP_WIDTH-1:0]              prs2sagu_psp_load_val_i,    //parameter stack load value
    input  wire [SP_WIDTH-1:0]              prs2sagu_rsp_load_val_i);   //return stack load value

   //Stack bus
   //---------
   assign sbus_adr_o    = prs2sagu_stack_sel_i ? dsp2sagu_rsp_next_i :  //return stack access
                                                ~dsp2sagu_psp_next_i;   //parameter stack access
   assign sbus_tga_ps_o = ~prs2sagu_stack_sel_i;                        //parameter stack access
   assign sbus_tga_rs_o =  prs2sagu_stack_sel_i;                        //return stack access

   //DSP interface
   //-------------
   //PS
   assign sagu2dsp_psp_hold_o   = prs2sagu_hold_i    |                  //all stack pointers held
                                  prs2sagu_stack_sel_i;                 //RSP operation
   assign sagu2dsp_psp_op_sel_o = prs2sagu_psp_rst_i |                  //PSP reset
                                  prs2sagu_load_i;                      //load operation
   assign sagu2dsp_psp_offs_o   = (prs2sagu_push_i              ?       //push operation
                                   (prs2sagu_stack_sel_i        ?       //1:RS, 0:PS
                                    PS_RS_DIST[SP_WIDTH-1:0]    :       //safety distance
                                    {{SP_WIDTH-1{1'b0}}, 1'b1}) :       //increment
                                   {SP_WIDTH{1'b0}})            |       //show PSP

                                  (prs2sagu_pull_i              ?       //push operation
                                   (prs2sagu_stack_sel_i        ?       //1:RS, 0:PS
                                    {SP_WIDTH{1'b0}}            :       //show PSP
                                    {SP_WIDTH{1'b1}})           :       //decrement PSP
                                   {SP_WIDTH{1'b0}})            |       //show PSP

                                  (prs2sagu_load_i              ?       //push operation
                                   (prs2sagu_stack_sel_i        ?       //1:RS, 0:PS
                                    {SP_WIDTH{1'b0}}            :       //show PSP
                                    prs2sagu_psp_load_val_i)    :       //load PSP
                                   {SP_WIDTH{1'b0}});                   //show PSP

   assign sagu2dsp_psp_load_val_o   =  prs2sagu_load_i     ?            //load operation
                                   prs2sagu_psp_load_val_i :            //PSP load value
                                   {SP_WIDTH{1'b0}};                    //reset PSP

   //RS
   assign sagu2dsp_rsp_hold_o   = prs2sagu_hold_i    |                  //all stack pointers held
                                  ~prs2sagu_stack_sel_i;                //PSP operation
   assign sagu2dsp_rsp_op_sel_o = prs2sagu_rsp_rst_i |                  //RSP reset
                                  prs2sagu_load_i;                      //load operation


   assign sagu2dsp_rsp_offs_o   = (prs2sagu_push_i              ?       //push operation
                                   (prs2sagu_stack_sel_i        ?       //1:RS, 0:PS
                                    {{SP_WIDTH-1{1'b0}}, 1'b1}  :       //incremebnt
                                    PS_RS_DIST[SP_WIDTH-1:0])   :       //safety distance
                                   {SP_WIDTH{1'b0}})            |       //show RSP

                                  (prs2sagu_pull_i              ?       //push operation
                                   (prs2sagu_stack_sel_i        ?       //1:RS, 0:PS
                                    {SP_WIDTH{1'b1}}            :       //decrement RSP
                                    {SP_WIDTH{1'b0}})           :       //show RSP
                                   {SP_WIDTH{1'b0}})            |       //show RSP

                                  (prs2sagu_load_i              ?       //push operation
                                   (prs2sagu_stack_sel_i        ?       //1:RS, 0:PS
                                    prs2sagu_rsp_load_val_i     :       //load RSP
                                    {SP_WIDTH{1'b0}})           :       //show RSP
                                  {SP_WIDTH{1'b0}});                    //show RSP

   assign sagu2dsp_rsp_load_val_o   =  prs2sagu_load_i     ?            //load operation
                                   prs2sagu_rsp_load_val_i :            //RSP load value
                                   {SP_WIDTH{1'b0}};                    //reset RSP

   //EXCPT interface
   //---------------
   assign sagu2excpt_psof_o = &{(dsp2sagu_psp_next_i ^ dsp2sagu_rsp_next_i), //stack pointer collision
                                prs2sagu_push_i,                        //push operation
                               ~prs2sagu_stack_sel_i};                  //parameter stack operation
   assign sagu2excpt_rsof_o = &{(dsp2sagu_psp_next_i ^ dsp2sagu_rsp_next_i), //stack pointer collision
                                prs2sagu_push_i,                        //push operation
                               ~prs2sagu_stack_sel_i};                  //return stack operation

endmodule // N1_sagu
