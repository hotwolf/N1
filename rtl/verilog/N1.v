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
  #(parameter   SP_WIDTH   =  8,                                 //width of a stack pointer
    parameter   IPS_DEPTH  =  8,                                 //depth of the intermediate parameter stack
    parameter   IPS_DEPTH  =  8,                                 //depth of the intermediate return stack





    parameter   RST_ADR    = 'h0000,                             //address of first instruction
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

    //Program bus (wishbone)
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

    //Stack bus (wishbone)
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
    input wire [PC_WIDTH-1:0]                irq_vec_i,          //requested interrupt vector

    //Probe signals
    //Intermediate parameter stack
    output wire [IPS_DEPTH-1:0]              prb_ips_ctags_o,    //intermediate stack cell tags
    output wire [(IPS_DEPTH*CELL_WIDTH)-1:0] prb_ips_cells_o,    //intermediate stack cells
    output wire [SP_WIDTH-1:0]               prb_ips_sp_o,       //stack pointer
    output wire [1:0]                        prb_ips_state_o,    //FSM state
    //Intermediate return stack
    output wire [IS_DEPTH-1:0]               prb_irs_ctags_o,    //intermediate stack cell tags
    output wire [(IRS_DEPTH*CELL_WIDTH)-1:0] prb_irs_cells_o,    //intermediate stack cells
    output wire [SP_WIDTH-1:0]               prb_irs_sp_o,       //stack pointer
    output wire [1:0]                        prb_irs_state_o,    //FSM state
    //Stack bus arbiter
    output wire [1:0]                        prb_sarb_state_o);  //FSM state

   //Local parameters
   //----------------

   //Internal interfaces
   //-------------------
   //Flow control - intruction register interface
   wire                                      fc_ir_capture;      //capture current IR
   wire                                      fc_ir_hoard;        //capture hoarded IR
   wire                                      fc_ir_expend;       //hoarded IR -> current IR
   wire [15:0]                               fc_ir_opcode;       //opcode to capture

   //Flow control - upper stack interface
   wire                                      fc_us_update;       //do stack transition
   wire                                      fc_us_busy;         //upper stack is busy

   //Flow control - ALU interface
   wire [CELL_WIDTH-1:0]                     fc_alu_tc;          //throw code

   //Flow control - hard macro interface
   wire                                      fc_hm_abs_rel_b;    //1:absolute COF, 0:relative COF
   wire                                      fc_hm_update;       //update PC
   wire [PC_WIDTH-1:0]                       fc_hm_rel_adr;      //relative COF address
   wire [PC_WIDTH-1:0]                       fc_hm_abs_adr;      //absolute COF address
   wire [PC_WIDTH-1:0]                       fc_hm_next_pc;      //next PC

   //Instruction register - ALU interface
   wire [4:0]                                ir_alu_opr_i;       //ALU operator
   wire [4:0]                                ir_alu_immop_i;     //immediade operand
   wire                                      ir_alu_use_immop_o; //use immediate operand

   //Instruction register - upper stack interface
   wire [STP_WIDTH-1:0]                      ir_us_rtc;          //return from call
   wire [STP_WIDTH-1:0]                      ir_us_stp;          //stack transition pattern
   wire [CELL_WIDTH-1:0]                     ir_us_ps0_next;     //literal value
   wire [CELL_WIDTH-1:0]                     ir_us_rs0_next;     //COF address

   //ALU - Hard macro interface
   wire                                      alu_hm_sub_add_b;   //1:op1 - op0, 0:op1 + op0
   wire                                      alu_hm_smul_umul_b; //1:signed, 0:unsigned
   wire [CELL_WIDTH-1:0]                     alu_hm_add_op0;     //first operand for adder/subtractor
   wire [CELL_WIDTH-1:0]                     alu_hm_add_op1;     //second operand for adder/subtractor (zero if no operator selected)
   wire [CELL_WIDTH-1:0]                     alu_hm_mul_op0;     //first operand for multipliers
   wire [CELL_WIDTH-1:0]                     alu_hm_mul_op1;     //second operand dor multipliers (zero if no operator selected)
   wire [(2*CELL_WIDTH)-1:0]                 alu_hm_add_res;     //result from adder
   wire [(2*CELL_WIDTH)-1:0]                 alu_hm_mul_res;     //result from multiplier

   //Upper stack - ALU interface
   wire [CELL_WIDTH-1:0]                     us_alu_ps0_next;    //new PS0 (TOS)
   wire [CELL_WIDTH-1:0]                     us_alu_ps1_next;    //new PS1 (TOS+1)
   wire [CELL_WIDTH-1:0]                     us_alu_ps0_cur;     //current PS0 (TOS)
   wire [CELL_WIDTH-1:0]                     us_alu_ps1_cur;     //current PS1 (TOS+1)
   wire [UPS_STAT_WIDTH-1:0]                 us_alu_pstat;       //UPS status
   wire [URS_STAT_WIDTH-1:0]                 us_alu_rstat;       //URS status

   //Upper stack - intermediate parameter stack interface
   wire                                      us_ips_rst;         //reset stack
   wire                                      us_ips_psh;         //US  -> IRS
   wire                                      us_ips_pul;         //IRS -> US
   wire                                      us_ips_psh_ctag;    //upper stack cell tag
   wire [CELL_WIDTH-1:0]                     us_ips_psh_cell;    //upper stack cell
   wire                                      us_ips_busy;        //intermediate stack is busy
   wire                                      us_ips_pul_ctag;    //intermediate stack cell tag
   wire [CELL_WIDTH-1:0]                     us_ips_pul_cell;    //intermediate stack cell
								 
   //Upper stack - intermediate return stack interface		 
   wire                                      us_irs_rst;         //reset stack
   wire                                      us_irs_psh;         //US  -> IRS
   wire                                      us_irs_pul;         //IRS -> US
   wire                                      us_irs_psh_ctag;    //upper stack tag
   wire [CELL_WIDTH-1:0]                     us_irs_psh_cell;    //upper stack data
   wire                                      us_irs_busy;        //intermediate stack is busy
   wire                                      us_irs_pul_ctag;    //intermediate stack tag
   wire [CELL_WIDTH-1:0]                     us_irs_pul_cell;    //intermediate stack data

   //Intermediate parameter stack - exception interface
   wire                                      ips_excpt_buserr;   //bus error

   //Intermediate parameter stack - stack bus arbiter interface (wishbone)
   wire                                      ips_sarb_cyc;       //bus cycle indicator       +-
   wire                                      ips_sarb_stb;       //access request            | initiator
   wire                                      ips_sarb_we;        //write enable              | to
   wire [SP_WIDTH-1:0]                       ips_sarb_adr;       //address bus               | target
   wire [CELL_WIDTH-1:0]                     ips_sarb_wdat;      //write data bus            +-
   wire                                      ips_sarb_ack;       //bus cycle acknowledge     +-
   wire                                      ips_sarb_err;       //error indicator           | target
   wire                                      ips_sarb_rty;       //retry request             | to
   wire                                      ips_sarb_stall;     //access delay              | initiator
   wire [CELL_WIDTH-1:0]                     ips_sarb_rdat;      //read data bus             +-

   //Intermediate return stack - ALU interface
   wire [IPS_DEPTH-1:0]                      ips_alu_ctags;      //cell tags
   wire [SP_WIDTH-1:0]                       ips_alu_lsp_o,      //lower stack pointer

   //Intermediate parameter stack - hard macro interface
   wire                                      ips_hm_psh;         //push (decrement address)
   wire                                      ips_hm_pul;         //pull (increment address)
   wire                                      ips_hm_rst;         //reset AGU
   wire [SP_WIDTH-1:0]                       ips_hm_sp;          //stack pointer

   //Intermediate return stack - exception interface
   wire                                      ips_excpt_buserr;   //bus error

   //Intermediate return stack - stack bus arbiter interface (wishbone)
   wire                                      irs_sarb_cyc;       //bus cycle indicator       +-
   wire                                      irs_sarb_stb;       //access request            | initiator
   wire                                      irs_sarb_we;        //write enable              | to
   wire [SP_WIDTH-1:0]                       irs_sarb_adr;       //address bus               | target
   wire [CELL_WIDTH-1:0]                     irs_sarb_wdat;      //write data bus            +-
   wire                                      irs_sarb_ack;       //bus cycle acknowledge     +-
   wire                                      irs_sarb_err;       //error indicator           | target
   wire                                      irs_sarb_rty;       //retry request             | to
   wire                                      irs_sarb_stall;     //access delay              | initiator
   wire [CELL_WIDTH-1:0]                     irs_sarb_rdat;      //read data bus             +-

   //Intermediate return stack - ALU interface
   wire [IPS_DEPTH-1:0]                      irs_alu_ctags;      //cell tags
   wire [SP_WIDTH-1:0]                       irs_alu_lsp_o,      //lower stack pointer
   
   //Intermediate return stack - hard macro interface
   wire                                      irs_hm_psh;         //push (increment address)
   wire                                      irs_hm_pul;         //pull (decrement address)
   wire                                      irs_hm_rst;         //reset AGU
   wire [SP_WIDTH-1:0]                       irs_hm_sp;          //result




   //Flow control
   //------------



   //Instruction register
   //--------------------


   //Exception tracker
   //-----------------


   //Arithmetic logic unit
   //---------------------




   //Upper stack
   //-----------
   N1_us
     #(.SP_WIDTH (SP_WIDTH))
   us
     (//Clock and reset
      .clk_i                    (clk_i),                         //module clock
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset







      
      );




   //Intermediate parameter stack
   //----------------------------
   N1_is
     #(.SP_WIDTH (SP_WIDTH),                                     //width of the parameter stack pointer
       .IS_WIDTH (IPS_WIDTH))                                    //depth of the intermediate parameter stack
   ips
     (//Clock and reset
      .clk_i                    (clk_i),                         //module clock
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset

      //Upper stack - intermediate parameter stack interface
      .us_is_rst_i		(us_ips_rst),                    //reset stack
      .us_is_psh_i		(us_ips_psh),                    //US  -> IPS
      .us_is_pul_i		(us_ips_pul),                    //IPS -> US
      .us_is_psh_tag_i		(us_ips_psh_tag),                //upper stack tag
      .us_is_psh_dat_i		(us_ips_psh_dat),                //upper stack data
      .us_is_busy_o		(us_ips_busy),                   //intermediate stack is busy
      .us_is_pul_ctag_o		(us_ips_pul_ctag),               //intermediate stack cell tag
      .us_is_pul_cell_o		(us_ips_pul_cell),               //intermediate stack cell
 
      //Intermediate parameter stack - exception interface
      .is_excpt_buserr_o	(ips_excpt_buserr),              //bus error

      //Intermediate parameter stack - stack bus arbiter interface (wishbone)
      .is_sarb_cyc_o		(ips_sarb_cyc),                  //bus cycle indicator       +-
      .is_sarb_stb_o		(ips_sarb_stb),                  //access request            | initiator
      .is_sarb_we_o		(ips_sarb_we),                   //write enable              | to
      .is_sarb_adr_o		(ips_sarb_adr),                  //address bus               | target
      .is_sarb_dat_o		(ips_sarb_wdat),                 //write data bus            +-
      .is_sarb_ack_i		(ips_sarb_ack),                  //bus cycle acknowledge     +-
      .is_sarb_err_i		(ips_sarb_err),                  //error indicator           | target
      .is_sarb_rty_i		(ips_sarb_rty),                  //retry request             | to
      .is_sarb_stall_i		(ips_sarb_stall),                //access delay              | initiator
      .is_sarb_dat_i		(ips_sarb_rdat),                 //read data bus             +-

      //Intermediate return stack - ALU interface
      .is_alu_ctags_o           (ips_alu_ctags),                 //cell tags

       //Intermediate parameter stack - hard macro interface
      .is_hm_psh_o		(ips_hm_psh),                    //push (decrement address)
      .is_hm_pul_o		(ips_hm_pul),                    //pull (increment address)
      .is_hm_rst_o		(ips_hm_rst),                    //reset AGU
      .is_hm_sp_i		(ips_hm_sp),                     //stack pointer

      //Probe signals
      .prb_is_ctags_o		(prb_ips_ctags_o),               //intermediate stack cell tags
      .prb_is_cells_o		(prb_ips_cells_o),               //intermediate stack cells
      .prb_is_sp_o		(prb_ips_sp_o),                  //stack pointer
      .prb_is_state_o		(prb_ips_state_o));              //FSM state

   //Intermediate return stack
   //-------------------------
   N1_is
     #(.SP_WIDTH (SP_WIDTH),                                     //width of the return stack pointer
       .IS_WIDTH (IRS_WIDTH))                                    //depth of the intermediate return stack
   irs
     (//Clock and reset
      .clk_i                    (clk_i),                         //module clock
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset

      //Upper stack - intermediate return stack interface
      .us_is_rst_i		(us_irs_rst),                    //reset stack
      .us_is_psh_i		(us_irs_psh),                    //US  -> IRS
      .us_is_pul_i		(us_irs_pul),                    //IRS -> US
      .us_is_psh_dtag_i		(us_irs_psh_ctag),               //upper stack cell tag
      .us_is_psh_cell_i		(us_irs_psh_cell),               //upper stack cell
      .us_is_busy_o		(us_irs_busy),                   //intermediate stack is busy
      .us_is_pul_ctag_o		(us_irs_pul_ctag),               //intermediate stack ctag
      .us_is_pul_cell_o		(us_irs_pul_cell),               //intermediate stack cell
 
      //Intermediate return stack - exception interface
      .is_excpt_buserr_o	(irs_excpt_buserr),              //bus error

      //Intermediate return stack - stack bus arbiter interface (wishbone)
      .is_sarb_cyc_o		(irs_sarb_cyc),                  //bus cycle indicator       +-
      .is_sarb_stb_o		(irs_sarb_stb),                  //access request            | initiator
      .is_sarb_we_o		(irs_sarb_we),                   //write enable              | to
      .is_sarb_adr_o		(irs_sarb_adr),                  //address bus               | target
      .is_sarb_dat_o		(irs_sarb_wdat),                 //write data bus            +-
      .is_sarb_ack_i		(irs_sarb_ack),                  //bus cycle acknowledge     +-
      .is_sarb_err_i		(irs_sarb_err),                  //error indicator           | target
      .is_sarb_rty_i		(irs_sarb_rty),                  //retry request             | to
      .is_sarb_stall_i		(irs_sarb_stall),                //access delay              | initiator
      .is_sarb_dat_i		(irs_sarb_rdat),                 //read data bus             +-

      //Intermediate return stack - ALU interface
      .is_alu_ctags_o           (irs_alu_ctags),                  //content tags

      //Intermediate return stack - hard macro interface
      .is_hm_psh_o		(irs_hm_psh),                    //push (decrement address)
      .is_hm_pul_o		(irs_hm_pul),                    //pull (increment address)
      .is_hm_rst_o		(irs_hm_rst),                    //reset AGU
      .is_hm_sp_i		(irs_hm_sp),                     //stack pointer

      //Probe signals
      .prb_is_ctags_o		(prb_irs_ctags_o),               //intermediate stack cell tags
      .prb_is_cells_o		(prb_irs_cells_o),               //intermediate stack cells
      .prb_is_sp_o		(prb_irs_sp_o),                  //stack pointer
      .prb_is_state_o		(prb_irs_state_o));              //FSM state

   //Stack bus arbiter
   //-----------------
   N1_sarb
     #(.SP_WIDTH (SP_WIDTH))                                     //width of each stack pointer
   sarb
     (//Clock and reset
      .clk_i                    (clk_i),                         //module clock
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset

      //Merged stack bus (wishbone)				       	
      .sbus_cyc_o		(sbus_cyc_o),                    //bus cycle indicator       +-
      .sbus_stb_o		(sbus_stb_o),                    //access request            |
      .sbus_we_o		(sbus_we_o),                     //write enable              | initiator
      .sbus_adr_o		(sbus_adr_o),                    //address bus               | to
      .sbus_dat_o		(sbus_dat_o),                    //write data bus            | target
      .sbus_tga_ps_o		(sbus_tga_ps_o),                 //parameter stack access    |
      .sbus_tga_rs_o		(sbus_tga_rs_o),                 //return stack access       +-
      .sbus_ack_i		(sbus_ack_i),                    //bus cycle acknowledge     +-
      .sbus_err_i		(sbus_err_i),                    //error indicator           | target
      .sbus_rty_i		(sbus_rty_i),                    //retry request             | to
      .sbus_stall_i		(sbus_stall_i),                  //access delay              | initiator
      .sbus_dat_i		(sbus_dat_i),                    //read data bus             +-
      
      //Parameter stack bus (wishbone)				       
      .ips_sarb_cyc_i		(ips_sarb_cyc),                  //bus cycle indicator       +-
      .ips_sarb_stb_i		(ips_sarb_stb),                  //access request            | initiator
      .ips_sarb_we_i		(ips_sarb_we),                   //write enable              | to
      .ips_sarb_adr_i		(ips_sarb_adr),                  //address bus               | target
      .ips_sarb_dat_i		(ips_sarb_wdat),                 //write data bus            +-
      .ips_sarb_ack_o		(ips_sarb_ack),                  //bus cycle acknowledge     +-
      .ips_sarb_err_o		(ips_sarb_err),                  //error indicator           | target
      .ips_sarb_rty_o		(ips_sarb_rty),                  //retry request             | to
      .ips_sarb_stall_o		(ips_sarb_stall),                //access delay              | initiator
      .ips_sarb_dat_o		(ips_sarb_rdat),                 //read data bus             +-
      							         
      //Return stack bus (wishbone)			         	       
      .irs_sarb_cyc_i		(irs_sarb_cyc),                  //bus cycle indicator       +-
      .irs_sarb_stb_i		(irs_sarb_stb),                  //access request            | initiator
      .irs_sarb_we_i		(irs_sarb_we),                   //write enable              | to
      .irs_sarb_adr_i		(irs_sarb_adr),                  //address bus               | target
      .irs_sarb_dat_i		(irs_sarb_wdat),                 //write data bus            +-
      .irs_sarb_ack_o		(irs_sarb_ack),                  //bus cycle acknowledge     +-
      .irs_sarb_err_o		(irs_sarb_err),                  //error indicator           | target
      .irs_sarb_rty_o		(irs_sarb_rty),                  //retry request             | to
      .irs_sarb_stall_o		(irs_sarb_stall),                //access delay              | initiator
      .irs_sarb_dat_o		(irs_sarb_rdat),                 //read data bus             +-
      
      //Probe signals						       
      .prb_sarb_state_o		(prb_sarb_state_o));             //FSM state
   
   //Hard macros
   //-----------
   N1_hm
     #(.SP_WIDTH (SP_WIDTH))                                     //width of each stack pointer
   hm
     (//Clock and reset
      .clk_i                    (clk_i),                         //module clock
      .async_rst_i              (async_rst_i),                   //asynchronous reset
      .sync_rst_i               (sync_rst_i),                    //synchronous reset

      //Flow control interface (program counter)
      .fc_hm_abs_rel_b_i        (fc_hm_abs_rel_b),               //1:absolute COF, 0:relative COF
      .fc_hm_update_i           (fc_hm_update),                  //update PC
      .fc_hm_rel_adr_i          (fc_hm_rel_adr),                 //relative COF address
      .fc_hm_abs_adr_i          (fc_hm_abs_adr),                 //absolute COF address
      .fc_hm_next_pc_o          (fc_hm_next_pc),                 //result

      //ALU interface (adder and multiplier)
      .alu_hm_sub_add_b_i       (alu_hm_sub_add_b),              //1:op1 - op0, 0:op1 + op0
      .alu_hm_smul_umul_b_i     (alu_hm_smul_umul_b),            //1:signed, 0:unsigned
      .alu_hm_add_op0_i         (alu_hm_add_op0),                //first operand for adder/subtractor
      .alu_hm_add_op1_i         (alu_hm_add_op1),                //second operand for adder/subtractor (zero if no operator selected)
      .alu_hm_mul_op0_i         (alu_hm_mul_op0),                //first operand for multipliers
      .alu_hm_mul_op1_i         (alu_hm_mul_op1),                //second operand dor multipliers (zero if no operator selected)
      .alu_hm_add_res_o         (alu_hm_add_res),                //result from adder
      .alu_hm_mul_res_o         (alu_hm_mul_res),                //result from multiplier

      //Intermediate parameter stack interface (AGU, stack grows towards lower addresses)
      .ips_hm_psh_i             (ips_hm_psh),                    //push (decrement address)
      .ips_hm_pul_i             (ips_hm_pul),                    //pull (increment address)
      .ips_hm_rst_i             (ips_hm_rst),                    //reset AGU
      .ips_hm_sp_o              (ips_hm_sp),                     //stack pointer

      //Intermediate return stack interface (AGU, stack grows tpwardshigher addresses)
      .irs_hm_psh_i             (irs_hm_psh),                    //push (increment address)
      .irs_hm_pul_i             (irs_hm_pul),                    //pull (decrement address)
      .irs_hm_rst_i             (irs_hm_rst),                    //reset AGU
      .irs_hm_sp_o              (irs_hm_sp));                    //stack pointer

endmodule // N1
