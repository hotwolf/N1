//###############################################################################
//# N1 - Formal Testbench - Intermediate and Lower Stack                        #
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
//#    This is the the formal testbench for the intermediate and lower stack    #
//#    block.                                                                   #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 5, 2019                                                           #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

//DUT configuration
//=================
//Default parameter stack configuration
//-------------------------------------
`ifdef CONF_PS_DEFAULT
`endif

//Default return stack configuration
//----------------------------------
`ifdef CONF_RS_DEFAULT
`define LS_START  12'h000  //return stack grows towards higher addresses
`endif

//Fall back
//---------
`ifndef SP_WIDTH
`define SP_WIDTH       12
`endif
`ifndef IS_DEPTH
`define IS_DEPTH        8
`endif
`ifndef LS_START
`define LS_START  12'hfff
`endif

module ftb_N1_is
   (//Clock and reset
    input  wire                             clk_i,                 //module clock
    input  wire                             async_rst_i,           //asynchronous reset
    input  wire                             sync_rst_i,            //synchronous reset

    //ALU interface
    output wire [`IS_DEPTH-1:0]             is2alu_tags_o,         //cell tags
    output wire [`SP_WIDTH-1:0]             is2alu_lsp_o,          //lower stack pointer

    //DSP partition interface
    input  wire [`SP_WIDTH-1:0]             dsp2is_lsp_i,          //lower stack pointer
    output wire                             is2dsp_psh_o,          //push (decrement address)
    output wire                             is2dsp_pul_o,          //pull (increment address)
    output wire                             is2dsp_rst_o,          //reset AGU

    //Exception aggregator interface
    output wire                             is2excpt_buserr_o,     //bus error

    //Stack bus arbiter interface
    output wire                             is2sarb_cyc_o,         //bus cycle indicator       +-
    output wire                             is2sarb_stb_o,         //access request            | initiator
    output wire                             is2sarb_we_o,          //write enable              | to
    output wire [`SP_WIDTH-1:0]             is2sarb_adr_o,         //address bus               | target
    output wire [15:0]                      is2sarb_dat_o,         //write data bus            +-
    input  wire                             sarb2is_ack_i,         //bus cycle acknowledge     +-
    input  wire                             sarb2is_err_i,         //error indicator           | target
    input  wire                             sarb2is_rty_i,         //retry request             | to
    input  wire                             sarb2is_stall_i,       //access delay              | initiator
    input  wire [15:0]                      sarb2is_dat_i,         //read data bus             +-

    //Upper stack interface
    input  wire                             us2is_rst_i,           //reset stack
    input  wire                             us2is_psh_i,           //US -> IS
    input  wire                             us2is_pul_i,           //IS -> US
    input  wire                             us2is_psh_ctag_i,      //upper stack cell tag
    input  wire [15:0]                      us2is_psh_cell_i,      //upper stack cell
    output wire                             is2us_busy_o,          //intermediate stack is busy
    output wire                             is2us_pul_ctag_o,      //intermediate stack cell tag
    output wire [15:0]                      is2us_pul_cell_o,      //intermediate stack cell

    //Probe signals
    output wire [`IS_DEPTH-1:0]             prb_is_tags_o,         //intermediate stack cell tags
    output wire [(`IS_DEPTH*16)-1:0]        prb_is_cells_o,        //intermediate stack cells
    output wire [`SP_WIDTH-1:0]             prb_is_lsp_o,          //lower stack pointer
    output wire [1:0]                       prb_is_state_o);       //FSM state

   //Instantiation
   //=============
   N1_is
     #(.SP_WIDTH (`SP_WIDTH),                                      //width of the stack pointer
       .IS_DEPTH (`IS_DEPTH),                                      //depth of the intermediate stack
       .LS_START (`LS_START))                                      //stack pointer value of the empty lower stack
   DUT
     (//Clock and reset
      .clk_i                    (clk_i),                           //module clock
      .async_rst_i              (async_rst_i),                     //asynchronous reset
      .sync_rst_i               (sync_rst_i),                      //synchronous reset

      //ALU interface
      .is2alu_tags_o            (is2alu_tags_o),                   //cell tags
      .is2alu_lsp_o             (is2alu_lsp_o),                    //lower stack pointer

      //DSP partition interface
      .dsp2is_lsp_i             (dsp2is_lsp_i),                    //lower stack pointer
      .is2dsp_psh_o             (is2dsp_psh_o),                    //push (decrement address)
      .is2dsp_pul_o             (is2dsp_pul_o),                    //pull (increment address)
      .is2dsp_rst_o             (is2dsp_rst_o),                    //reset AGU

      //Exception aggregator interface
      .is2excpt_buserr_o        (is2excpt_buserr_o),               //bus error

      //Stack bus arbiter interface
      .is2sarb_cyc_o            (is2sarb_cyc_o),                   //bus cycle indicator       +-
      .is2sarb_stb_o            (is2sarb_stb_o),                   //access request            | initiator
      .is2sarb_we_o             (is2sarb_we_o),                    //write enable              | to
      .is2sarb_adr_o            (is2sarb_adr_o),                   //address bus               | target
      .is2sarb_dat_o            (is2sarb_dat_o),                   //write data bus            +-
      .sarb2is_ack_i            (sarb2is_ack_i),                   //bus cycle acknowledge     +-
      .sarb2is_err_i            (sarb2is_err_i),                   //error indicator           | target
      .sarb2is_rty_i            (sarb2is_rty_i),                   //retry request             | to
      .sarb2is_stall_i          (sarb2is_stall_i),                 //access delay              | initiator
      .sarb2is_dat_i            (sarb2is_dat_i),                   //read data bus             +-

      //Upper stack interface
      .us2is_rst_i              (us2is_rst_i),                     //reset stack
      .us2is_psh_i              (us2is_psh_i),                     //US -> IS
      .us2is_pul_i              (us2is_pul_i),                     //IS -> US
      .us2is_psh_ctag_i         (us2is_psh_ctag_i),                //upper stack cell tag
      .us2is_psh_cell_i         (us2is_psh_cell_i),                //upper stack cell
      .is2us_busy_o             (is2us_busy_o),                    //intermediate stack is busy
      .is2us_pul_ctag_o         (is2us_pul_ctag_o),                //intermediate stack cell tag
      .is2us_pul_cell_o         (is2us_pul_cell_o),                //intermediate stack cell

      //Probe signals
      .prb_is_tags_o            (prb_is_tags_o),                   //intermediate stack cell tags
      .prb_is_cells_o           (prb_is_cells_o),                  //intermediate stack cells
      .prb_is_lsp_o             (prb_is_lsp_o),                    //lower stack pointer
      .prb_is_state_o           (prb_is_state_o));                 //FSM state

`ifdef FORMAL
   //Testbench signals

   //Abbreviations

   //SYSCON constraints
   //===================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i                    (clk_i),                           //module clock
      .sync_i                   (1'b1),                            //clock enable
      .async_rst_i              (async_rst_i),                     //asynchronous reset
      .sync_rst_i               (sync_rst_i),                      //synchronous reset
      .gated_clk_o              ());                               //gated clock

`endif //  `ifdef FORMAL

endmodule // ftb_N1_is
