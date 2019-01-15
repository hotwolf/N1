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
  #(parameter   RST_ADR    = 'h0000,                             //address of first instruction
    parameter   EXCPT_ADR  = 15'h0000,                           //address of the exception handler
    parameter   SP_WIDTH   =  8,                                 //width of a stack pointer
    parameter   SP_WIDTH   =  8,                                 //width of a stack pointer
    localparam  CELL_WIDTH = 16,                                 //width of a cell
    localparam  PC_WIDTH   = 15,                                 //width of the program counter
    localparam  UPS_DEPTH  =  5,                                 //depth of the upper parameter stack
    localparam  IPS_DEPTH  =  8,                                 //depth of the immediate parameter stack
    localparam  URS_DEPTH  =  1,                                 //depth of the upper return stack
    localparam  IRS_DEPTH  =  8)                                 //depth of the immediate return stack

   (//Clock and reset
    input  wire                              clk_i,              //module clock
    input  wire                              async_rst_i,        //asynchronous reset
    input  wire                              sync_rst_i,         //synchronous reset

    //Program bus
    output wire                              pbus_cyc_o,         //bus cycle indicator       +-
    output wire                              pbus_stb_o,         //access request            |
    output wire                              pbus_we_o,          //write enable              |
    output wire [(CELL_WIDTH/8)-1:0]         pbus_sel_o,         //write data selects        |
    output wire [PC_WIDTH-1:0]               pbus_adr_o,         //address bus               |
    output wire [CELL_WIDTH-1:0]             pbus_dat_o,         //write data bus            | initiator
    output wire                              pbus_tga_jmp_imm_o, //immediate jump            | to
    output wire                              pbus_tga_jmp_ind_o, //indirect jump             | target
    output wire                              pbus_tga_cal_imm_o, //immediate call            |
    output wire                              pbus_tga_cal_ind_o, //indirect call             |
    output wire                              pbus_tga_bra_imm_o, //immediate branch          |
    output wire                              pbus_tga_bra_ind_o, //indirect branch           |
    output wire                              pbus_tga_dat_imm_o, //immediate data access     |
    output wire                              pbus_tga_dat_ind_o, //indirect data access      +-
    input  wire                              pbus_ack_i,         //bus cycle                 +-
    input  wire                              pbus_err_i,         //error indicator           | target
    input  wire                              pbus_rty_i,         //retry request             | to
    input  wire                              pbus_stall_i,       //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]             pbus_dat_i,         //read data bus             +-

    //Stack bus
    output wire                              sbus_cyc_o,         //bus cycle indicator       +-
    output wire                              sbus_stb_o,         //access request            |
    output wire                              sbus_we_o,          //write enable              | initiator
    output wire [SP_WIDTH-1:0]               sbus_adr_o,         //address bus               | to
    output wire [CELL_WIDTH-1:0]             sbus_dat_o,         //write data bus            | target
    output wire                              sbus_tga_ps_o,      //parameter stack access    |
    output wire                              sbus_tga_rs_o,      //return stack access       +-
    input  wire                              sbus_ack_i,         //bus cycle acknowledge     +-
    input  wire                              sbus_err_i,         //error indicator           | target
    input  wire                              sbus_rty_i,         //retry request             | to
    input  wire                              sbus_stall_i,       //access delay              | initiator
    input  wire [CELL_WIDTH-1:0]             sbus_dat_i,         //read data bus             +-

    //Interrupt interface
    output wire                              irq_ack_o,          //interrupt acknowledge
    input  wire [PC_WIDTH-1:0]               irq_vec_i,          //requested interrupt vector

    //Probe signals
    //Program counter
    output wire [PC_WIDTH-1:0]               prb_pc_next_o,      //next program counter
    //Instruction register
    output wire [CELL_WIDTH-1:0]             prb_ir_o,           //instruction register
    //Parameter stack
    output wire [(UPS_DEPTH*CELL_WIDTH)-1:0] prb_ups_o,          //upper parameter stack content
    output wire [UPS_DEPTH-1:0]              prb_ups_stat_o,     //upper parameter stack status
    output wire [(IPS_DEPTH*CELL_WIDTH)-1:0] prb_ips_o,          //intermediate parameter stack content
    output wire [IPS_DEPTH-1:0]              prb_ips_stat_o,     //intermediate parameter stack status
    output wire [SP_WIDTH-1:0]               prb_lps_sp_o,       //lower parameter stack pointer
    //Return stack
    output wire [(URS_DEPTH*CELL_WIDTH)-1:0] prb_urs_o,          //upper return stack content
    output wire [URS_DEPTH-1:0]              prb_urs_stat_o,     //upper return stack status
    output wire [(IRS_DEPTH*CELL_WIDTH)-1:0] prb_irs_o,          //intermediate return stack content
    output wire [IRS_DEPTH-1:0]              prb_irs_stat_o,     //intermediate return stack status
    output wire [SP_WIDTH-1:0]               prb_lrs_sp_o);      //lower return stack pointer

   //Internal Signals
   //----------------
   //Lower parameter stack AGU (stack grows lower addresses)
   wire                                      lps_agu_psh;        //push (decrement address)
   wire                                      lps_agu_pul;        //pull (increment address)
   wire                                      lps_agu_rst;        //reset AGU
   wire [SP_WIDTH-1:0]                       lps_agu;            //result

   //Lower return stack AGU (stack grows higher addresses)
   wire                                      lrs_agu_psh;        //push (increment address)
   wire                                      lrs_agu_pul;        //pull (decrement address)
   wire                                      lrs_agu_rst;        //reset AGU
   wire [SP_WIDTH-1:0]                       lrs_agu;            //result

   //Program Counter
   wire                                      pc_rel;             //add address offset
   wire                                      pc_abs;             //drive absolute address
   wire                                      pc_update;          //update PC
   wire [PC_WIDTH-1:0]                       pc_rel_adr;         //relative COF address
   wire [PC_WIDTH-1:0]                       pc_abs_adr;         //absolute COF address
   wire [PC_WIDTH-1:0]                       pc_next;            //result

   //ALU
   wire                                      alu_add;            //op1 + op0
   wire                                      alu_sub;            //op1 - op0
   wire                                      alu_umul;           //op1 * op0 (unsigned)
   wire                                      alu_smul;           //op1 * op0 (signed)
   wire [CELL_WIDTH-1:0]                     alu_op0;            //first operand
   wire [CELL_WIDTH-1:0]                     alu_op1;            //second operand
   wire [(2*CELL_WIDTH)-1:0]                 alu);               //result

   //Soft IP partition
   //-----------------
   N1_soft
     #(.RST_ADR   (RST_ADR),                                     //address of first instruction
       .EXCPT_ADR (EXCPT_ADR),                                   //address of the exception handler
       .SP_WIDTH  (SP_WIDTH))                                    //width of a stack pointer
   N1_soft
     (//Clock and reset
      .clk_i                    (clk_i),                         //module clock
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset

     //Program bus
     .pbus_cyc_o                (pbus_cyc_o),                    //bus cycle indicator       +-
     .pbus_stb_o                (pbus_stb_o),                    //access request            | initiator to target
     .pbus_adr_o                (pbus_adr_o),                    //address bus               |
     .pbus_tga_imadr_o          (pbus_tga_imadr_o),              //immediate (short) address +-
     .pbus_ack_i                (pbus_ack_i),                    //bus cycle acknowledge     +-
     .pbus_err_i                (pbus_err_i),                    //error indicator           | target
     .pbus_rty_i                (pbus_rty_i),                    //retry request             | to
     .pbus_stall_i              (pbus_stall_i),                  //access delay              | initiator
     .pbus_dat_i                (pbus_dat_i),                    //read data bus             +-

     //Data bus
     .dbus_cyc_o                (dbus_cyc_o),                    //bus cycle indicator       +-
     .dbus_stb_o                (dbus_stb_o),                    //access request            |
     .dbus_we_o                 (dbus_we_o),                     //write enable              | initiator
     .dbus_sel_o                (dbus_sel_o),                    //write data selects        | to
     .dbus_adr_o                (dbus_adr_o),                    //address bus               | target
     .dbus_dat_o                (dbus_dat_o),                    //write data bus            |
     .dbus_tga_imadr_o          (dbus_tga_imadr_o),              //immediate (short) address +-
     .dbus_ack_i                (dbus_ack_i),                    //bus cycle acknowledge     +-
     .dbus_err_i                (dbus_err_i),                    //error indicator           | target
     .dbus_rty_i                (dbus_rty_i),                    //retry request             | to
     .dbus_stall_i              (dbus_stall_i),                  //access delay              | initiator
     .dbus_dat_i                (dbus_dat_i),                    //read data bus             +-

     //Stack bus
     .sbus_cyc_o                (sbus_cyc_o),                    //bus cycle indicator       +-
     .sbus_stb_o                (sbus_stb_o),                    //access request            |
     .sbus_we_o                 (sbus_we_o),                     //write enable              | initiator
     .sbus_adr_o                (sbus_adr_o),                    //address bus               | to
     .sbus_dat_o                (sbus_dat_o),                    //write data bus            | target
     .sbus_tga_ps_o             (sbus_tga_ps_o),                 //parameter stack access    |
     .sbus_tga_rs_o             (sbus_tga_rs_o),                 //return stack access       +-
     .sbus_ack_i                (sbus_ack_i),                    //bus cycle acknowledge     +-
     .sbus_err_i                (sbus_err_i),                    //error indicator           | target
     .sbus_rty_i                (sbus_rty_i),                    //retry request             | to
     .sbus_stall_i              (sbus_stall_i),                  //access delay              | initiator
     .sbus_dat_i                (sbus_dat_i),                    //read data bus             +-

     //Interrupt interface
     .irq_ack_o                 (irq_ack_o),                     //interrupt acknowledge
     .irq_vec_i                 (irq_vec_i),                     //requested interrupt vector

     //Hard IP interface
     //Lower parameter stack AGU (stack grows lower addresses)
     .lps_agu_psh_o             (lps_agu_psh),                   //push (decrement address)
     .lps_agu_pul_o             (lps_agu_pul),                   //pull (increment address)
     .lps_agu_rst_o             (lps_agu_rst),                   //reset AGU
     .lps_agu_i                 (lps_agu),                       //result
     //Lower return stack AGU (stack grows higher addresses)
     .lrs_agu_psh_o             (lrs_agu_psh),                   //push (increment address)
     .lrs_agu_pul_o             (lrs_agu_pul),                   //pull (decrement address)
     .lrs_agu_rst_o             (lrs_agu_rst),                   //reset AGU
     .lrs_agu_i                 (lrs_agu),                       //result
     //Program Counter
     .pc_rel_o                  (pc_rel),                        //add address offset
     .pc_abs_o                  (pc_abs),                        //drive absolute address
     .pc_update_o               (pc_update),                     //update PC
     .pc_rel_adr_o              (pc_rel_adr),                    //relative COF address
     .pc_abs_adr_o              (pc_abs_adr),                    //absolute COF address
     .pc_next_i                 (pc_next),                       //result
     //ALU
     .alu_add_o                 (alu_add),                       //op1 + op0
     .alu_sub_o                 (alu_sub),                       //op1 - op0
     .alu_umul_o                (alu_umul),                      //op1 * op0 (unsigned)
     .alu_smul_o                (alu_smul),                      //op1 * op0 (signed)
     .alu_op0_o                 (alu_op0),                       //first operand
     .alu_op1_o                 (alu_op1),                       //second operand
     .alu_i                     (alu),                           //result

     //Probe signals
     //Program counter
     .prb_pc_next_o             (prb_pc_next_o),                 //next program counter
     //Instruction register
     .prb_ir_o                  (prb_ir_o),                      //instruction register
     //Parameter stack
     .prb_ups_o                 (prb_ups_o),                     //upper parameter stack content
     .prb_ups_stat_o            (prb_ups_stat_o),                //upper parameter stack status
     .prb_ips_o                 (prb_ips_o),                     //intermediate parameter stack content
     .prb_ips_stat_o            (prb_ips_stat_o),                //intermediate parameter stack status
     .prb_lps_sp_o              (prb_lps_sp_o),                  //lower parameter stack pointer
     //Return stack
     .prb_urs_o                 (prb_urs_o),                     //upper parameter stack content
     .prb_urs_stat_o            (prb_urs_stat_o),                //upper parameter stack status
     .prb_irs_o                 (prb_irs_o),                     //intermediate parameter stack content
     .prb_lrs_sp_o              (prb_lrs_sp_o),                  //lower return stack pointer
     .prb_irs_stat_o            (prb_irs_stat_o));               //intermediate parameter stack status

   //Hard IP partition
   //-----------------
   N1_hard
     #(.SP_WIDTH (SP_WIDTH))                                     //width of a stack pointer
   N1_hard
     (//Clock and reset
      .clk_i                    (clk_i),                         //module clock
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset

      //Lower parameter stack AGU (stack grows lower addresses)
      .lps_agu_psh_i            (lps_agu_psh),                   //push (decrement address)
      .lps_agu_pul_i            (lps_agu_pul),                   //pull (increment address)
      .lps_agu_rst_i            (lps_agu_rst),                   //reset AGU
      .lps_agu_o                (lps_agu),                       //result

      //Lower return stack AGU (stack grows higher addresses)
      .lrs_agu_psh_i            (lrs_agu_psh),                   //push (increment address)
      .lrs_agu_pul_i            (lrs_agu_pul),                   //pull (decrement address)
      .lrs_agu_rst_i            (lrs_agu_rst),                   //reset AGU
      .lrs_agu_o                (lrs_agu),                       //result

      //Program Counter
      .pc_abs_i                 (pc_abs),                        //drive absolute address (relative otherwise)
      .pc_update_i              (pc_update),                     //update PC
      .pc_rel_adr_i             (pc_rel_adr),                    //relative COF address
      .pc_abs_adr_i             (pc_abs_adr),                    //absolute COF address
      .pc_next_o                (pc_next),                       //result

      //ALU
      .alu_add_i                (alu_add),                       //op1 + op0
      .alu_sub_i                (alu_sub),                       //op1 - op0
      .alu_umul_i               (alu_umul),                      //op1 * op0 (unsigned)
      .alu_smul_i               (alu_smul),                      //op1 * op0 (signed)
      .alu_op0_i                (alu_op0),                       //first operand
      .alu_op1_i                (alu_op1),                       //second operand
      .alu_o                    (alu);                           //result

endmodule // N1
