//###############################################################################
//# N1 - Formal Testbench - Upper Stacks                                        #
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
//#    This is the the formal testbench for the upper stack block.              #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   January 5, 2019                                                           #
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

module ftb_N1_is
   (//Clock and reset
    input  wire                             clk_i,                 //module clock
    input  wire                             async_rst_i,           //asynchronous reset
    input  wire                             sync_rst_i,            //synchronous reset

    //Upper stack - intermediate stack interface
    input  wire                             us_is_rst_i,           //reset stack
    input  wire                             us_is_psh_i,           //US  -> IRS
    input  wire                             us_is_pul_i,           //IRS -> US
    input  wire                             us_is_psh_ctag_i,      //upper stack cell tag
    input  wire [15:0]                      us_is_psh_cell_i,      //upper stack cell
    output wire                             us_is_busy_o,          //intermediate stack is busy
    output wire                             us_is_pul_ctag_o,      //intermediate stack cell tag
    output wire [15:0]                      us_is_pul_cell_o,      //intermediate stack cell

    //Intermediate stack - exception interface
    output wire                             is_excpt_buserr_o,     //bus error

    //Intermediate stack - stack bus arbiter interface (wishbone)
    output wire                             is_sarb_cyc_o,         //bus cycle indicator       +-
    output wire                             is_sarb_stb_o,         //access request            | initiator
    output wire                             is_sarb_we_o,          //write enable              | to
    output wire [`SP_WIDTH-1:0]             is_sarb_adr_o,         //address bus               | target
    output wire [15:0]                      is_sarb_dat_o,         //write data bus            +-
    input  wire                             is_sarb_ack_i,         //bus cycle acknowledge     +-
    input  wire                             is_sarb_err_i,         //error indicator           | target
    input  wire                             is_sarb_rty_i,         //retry request             | to
    input  wire                             is_sarb_stall_i,       //access delay              | initiator
    input  wire [15:0]                      is_sarb_dat_i,         //read data bus             +-

    //Intermediate return stack - ALU interface
    output wire [`IS_DEPTH-1:0]             is_alu_ctags_o,        //cell tags
    output wire [`SP_WIDTH-1:0]             is_alu_lsp_o,          //lower stack pointer

    //Intermediate stack - hard macro interface
    output wire                             is_dsp_psh_o,          //push (decrement address)
    output wire                             is_dsp_pul_o,          //pull (increment address)
    output wire                             is_dsp_rst_o,          //reset AGU
    input  wire [`SP_WIDTH-1:0]             is_dsp_sp_i,           //stack pointer

    //Probe signals
    output wire [`IS_DEPTH-1:0]             prb_is_ctags_o,        //intermediate stack cell tags
    output wire [(`IS_DEPTH*16)-1:0]        prb_is_cells_o,        //intermediate stack cells
    output wire [`SP_WIDTH-1:0]             prb_is_sp_o,           //stack pointer
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

      //Upper stack - intermediate stack interface
      .us_is_rst_i              (us_is_rst_i),                     //reset stack
      .us_is_psh_i              (us_is_psh_i),                     //US  -> IRS
      .us_is_pul_i              (us_is_pul_i),                     //IRS -> US
      .us_is_psh_ctag_i         (us_is_psh_ctag_i),                //upper stack cell tag
      .us_is_psh_cell_i         (us_is_psh_cell_i),                //upper stack cell
      .us_is_busy_o             (us_is_busy_o),                    //intermediate stack is busy
      .us_is_pul_ctag_o         (us_is_pul_ctag_o),                //intermediate stack cell tag
      .us_is_pul_cell_o         (us_is_pul_cell_o),                //intermediate stack cell

      //Intermediate stack - exception interface
      .is_excpt_buserr_o        (is_excpt_buserr_o),               //bus error

      //Intermediate stack - stack bus arbiter interface           (wishbone)
      .is_sarb_cyc_o            (is_sarb_cyc_o),                   //bus cycle indicator       +-
      .is_sarb_stb_o            (is_sarb_stb_o),                   //access request            | initiator
      .is_sarb_we_o             (is_sarb_we_o),                    //write enable              | to
      .is_sarb_adr_o            (is_sarb_adr_o),                   //address bus               | target
      .is_sarb_dat_o            (is_sarb_dat_o),                   //write data bus            +-
      .is_sarb_ack_i            (is_sarb_ack_i),                   //bus cycle acknowledge     +-
      .is_sarb_err_i            (is_sarb_err_i),                   //error indicator           | target
      .is_sarb_rty_i            (is_sarb_rty_i),                   //retry request             | to
      .is_sarb_stall_i          (is_sarb_stall_i),                 //access delay              | initiator
      .is_sarb_dat_i            (is_sarb_dat_i),                   //read data bus             +-

      //Intermediate return stack - ALU interface
      .is_alu_ctags_o           (is_alu_ctags_o),                  //cell tags
      .is_alu_lsp_o             (is_alu_lsp_o),                    //lower stack pointer

      //Intermediate stack - hard macro interface
      .is_dsp_psh_o             (is_dsp_psh_o),                    //push (decrement address)
      .is_dsp_pul_o             (is_dsp_pul_o),                    //pull (increment address)
      .is_dsp_rst_o             (is_dsp_rst_o),                    //reset AGU
      .is_dsp_sp_i              (is_dsp_sp_i),                     //stack pointer

      //Probe signals
      .prb_is_ctags_o           (prb_is_ctags_o),                  //intermediate stack cell tags
      .prb_is_cells_o           (prb_is_cells_o),                  //intermediate stack cells
      .prb_is_sp_o              (prb_is_sp_o),                     //stack pointer
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
