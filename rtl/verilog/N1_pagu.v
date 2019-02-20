//###############################################################################
//# N1 - Program Bus Address Generation Unit                                    #
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
//#    (Pbus).                                                                  #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 20, 2019                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_pagu
   (//Interrupt interface
    input  wire [15:0]               irq_req_adr_i,          //requested interrupt vector

    //Internal interfaces
    //-------------------
    //DSP interface
    output wire                      pagu2dsp_abs_rel_b_o,   //1:absolute COF, 0:relative COF
    output wire [15:0]               pagu2dsp_rel_adr_o,     //relative COF address
    output wire [15:0]               pagu2dsp_abs_adr_o,     //absolute COF address
    input  wire [15:0]               dsp2pagu_pc_next_i,     //next program counter

    //IR interface
    input  wire                      ir2pagu_eow_i,          //end of word
    input  wire                      ir2pagu_jmp_or_cal_i,   //jump or call instruction
    input  wire                      ir2pagu_bra_i,          //conditional branch
    input  wire                      ir2pagu_scyc_i,         //single cycle instruction
    input  wire                      ir2pagu_rst_i,          //single cycle instruction
    input  wire                      ir2pagu_scyc_i,         //single cycle instruction
    input  wire                      ir2pagu_mem_i,          //memory I/O

    input  wire                      ir2pagu_sel_dadr_i,     //select absolute direct address
    input  wire [15:0]               ir2pagu_dadr_i,         //absolute direct address
    input  wire [15:0]               ir2pagu_radr_i,         //relative direct address
    input  wire                      ir2pagu_sel_iadr_i,     //select immediate address
    input  wire [15:0]               ir2pagu_iadr_i,         //immediate address

    //PRS interface
    input  wire [15:0]               prs2pagu_ps0_i,         //PS0
    input  wire [15:0]               prs2pagu_rs0_i);        //RS0

   //DSP control
   //-----------
   always @*
     begin
        //default
        pagu2dsp_abs_rel_b_o    =  1'b0;                     //1:absolute COF, 0:relative COF
        pagu2dsp_rel_adr_o      = 16'h0000;                  //relative COF address
        pagu2dsp_abs_adr_o      = 16'h0000;                  //absolute COF address

        //Jump or Call
        if (ir2pagu_jmp_or_cal_i)
          begin
             pagu2dsp_abs_rel_b_o = 1'b1;                    //drive absolute address
             pagu2dsp_abs_adr_o   = pagu2dsp_abs_adr_o   |   //make use of onehot encoding
                                    (ir2pagu_sel_dadr_i ?    //direct or indirect addressing
                                     ir2pagu_dadr_i     :    //direct address
                                     prs2pagu_ps0_i);        //indirect address
          end

        //Conditional branch
        if (ir2pagu_bra_i)
          begin
             pagu2dsp_rel_adr_o   = pagu2dsp_abs_adr_o |     //make use of onehot encoding
                                    (|prs2pagu_ps0_i ?       //branch or not
                                     ir2pagu_dadr_i  :       //branch address
                                     16'h0001);              //increment
          end

        //Single cycle instruction
        if (ir2pagu_scyc_i)
          if (ir2pagu_eow_i)
            //End of word (return from call)
            begin
               pagu2dsp_rel_adr_o = pagu2dsp_abs_adr_o |     //make use of onehot encoding
                                    prs2pagu_rs0_i);         //return address
            end
          else
            //Next instruction
            begin
               pagu2dsp_rel_adr_o   = pagu2dsp_abs_adr_o |   //make use of onehot encoding
                                      16'h0001);             //increment
            end

        //Memory IO
        if (ir2fc_mem_i)
          begin
             pagu2dsp_abs_rel_b_o = 1'b1;                    //drive absolute address
             pagu2dsp_abs_adr_o   = pagu2dsp_abs_adr_o   |   //make use of onehot encoding
                                    (ir2pagu_sel_iadr_i ?    //immediate or indirect addressing
                                     prs2pagu_ps0_i);        //indirect address
          end
     end // always @ *

endmodule // N1_pagu
