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
//#    This is the top level block of the N1 processor. Please see the manual   #
//#    (N1/doc/N1_manual.pdf) for detailed information on usage and             #
//#    implementation of this IP.                                               #
//#                                                                             #
//#    The N1 has five external interfaces:                                     #
//#       Clocks and Reset                                                      #
//#         This interface consists of three signals:                           #
//#           clk_i       - A common clock input                                #
//#           sync_rst_i  - A synchronous reset input                           #
//#           async_rst_i - An asynchronous reset input                         #
//#         Only one of the two reset options must be supported by the SoC. The #
//#         other one can be tied to zero.                                      #
//#       Program Bus                                                           #
//#         This is a pipelined Wishbone interface to connect to the program    #
//#         and data memory. Program and data share a common address space of   #
//#         128Kbyte, accessible only in 16bit entities. The naming convention  #
//#         for program bus signals is: "pbus_<wishbone signal name>"           #
//#       Stack Bus                                                             #
//#         This is a pipelined Wishbone interface to connect to the stack      #
//#         memory. The Stack memory holds the lower parameter and return       #
//#         stacks. Program and stack memory are organized in separate address  #
//#         spaces. The size of the stack space is controlled by the parameter  #
//#         "SP_WIDTH" (stack pointer width). Stack memory can only be accessed #
//#         in 16bit entities. The naming convention for stack bus signals is:  #
//#         "sbus_<wishbone signal name>"                                       #
//#       Interrupt Interface                                                   #
//#         The N1 processor does not contain an interrupt controller, but it   #
//#         offers a simple interface to connect to an external one. The        #
//#         interface consists of two signals:                                  #
//#            irq_req_adr_i - An interrupt requrst input, which provides the   #
//#                            address of the current interrupt to the N1       #
//#                            processor. Any non-zero value is regarded as     #
//#                            interrupt request. Unserviced interrupt requests #
//#                            may be replaced by as higer priority interrupt   #
//#                            requests.                                        #
//#            irq_ack_o     - This signal acknowledges the current interrupt   #
//#                            request, as soon as it has been serviced.        #
//#       Probe signals                                                         #
//#         Probe signals provide access to the internal state of the N1        #
//#         processor. The output signals are not to be used for SoC            #
//#         integration. Their sole purpose is to simplify formal verification  #
//#         and software emulation. This interface may change for every future  #
//#         revision of the N1 processor. The signal naming convention is       #
//#         "prb_<originating subblock>_<register base name>_o"                 #
//#                                                                             #
//#    The N1 consists of eight subblocks:                                      #
//#       ALU -> Arithmetic Logic Unit                                          #
//#         This block performs arithmetic and logic operations. The            #
//#         implementation of multipliers and adders has been moved to the DSP  #
//#         block.                                                              #
//#       DSP -> DSP Cell Partition                                             #
//#         This block gathers logic from ALU, FC, IPS, and IRS, which can be   #
//#         directly mapped to FPGA DSP cells. The implementation of this block #
//#         is specific to the targeted FPGA architecture.                      #
//#       EXCPT -> Exception Aggregator                                         #
//#         This block tracks internal exceptions (stack over/underflows or bus #
//#         errors) and provides information.                                   #
//#       FC -> Flow Controller                                                 #
//#         This block implements the main finite state machine of the N1       #
//#         processor, which controls the program execution.                    #
//#       IPS -> Intermediate (and Lower) Parameter Stack                       #
//#         This block implements the intermediate and the lower parameter      #
//#         stack.                                                              #
//#       IR -> Instruction Register and Decoder                                #
//#         This block captures the current instructions ond performs basic     #
//#         decoding.                                                           #
//#       IRS -> Intermediate (and Lower) Return Stack                          #
//#         This block implements the intermediate and the lower return stack.  #
//#       SARB -> Stack Bus Arbiter                                             #
//#         This block merges bus transactions of the lower parameter and       #
//#         return stacks on to one common stack bus (sbus).                    #
//#       US -> Upper Stacks                                                    #
//#         This block implemnts both the upper parameter stack and the upper   #
//#         return stack.                                                       #
//#                                                                             #
//#    Internal interfaces, interconnecting the subblocks of the N1 processor,  #
//#    abide the following signal naming convention:                            #
//#    "<source block>2<sink block>_<decriptive name>_<i/o>"                    #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1
  #(parameter   SP_WIDTH   = 12,                                 //width of a stack pointer
    parameter   IPS_DEPTH  =  8,                                 //depth of the intermediate parameter stack
    parameter   IRS_DEPTH  =  8)                                 //depth of the intermediate return stack

   (//Clock and reset
    input  wire                              clk_i,              //module clock
    input  wire                              async_rst_i,        //asynchronous reset
    input  wire                              sync_rst_i,         //synchronous reset

    //Program bus (wishbone)
    output wire                              pbus_cyc_o,         //bus cycle indicator       +-
    output wire                              pbus_stb_o,         //access request            |
    output wire                              pbus_we_o,          //write enable              |
    output wire [15:0]                       pbus_adr_o,         //address bus               |
    output wire [15:0]                       pbus_dat_o,         //write data bus            |
    output wire                              pbus_tga_jmp_dir_o, //direct jump               | initiator
    output wire                              pbus_tga_jmp_ind_o, //indirect jump             | to	
    output wire                              pbus_tga_cal_dir_o, //direct call               | target   
    output wire                              pbus_tga_cal_ind_o, //indirect call             |
    output wire                              pbus_tga_bra_dir_o, //direct branch             |
    output wire                              pbus_tga_bra_ind_o, //indirect branch           |
    output wire                              pbus_tga_dat_dir_o, //direct data access        |
    output wire                              pbus_tga_dat_ind_o, //indirect data access      +-
    input  wire                              pbus_ack_i,         //bus cycle                 +-
    input  wire                              pbus_err_i,         //error indicator           | target
    input  wire                              pbus_rty_i,         //retry request             | to
    input  wire                              pbus_stall_i,       //access delay              | initiator
    input  wire [15:0]                       pbus_dat_i,         //read data bus             +-

    //Stack bus (wishbone)
    output wire                              sbus_cyc_o,         //bus cycle indicator       +-
    output wire                              sbus_stb_o,         //access request            |
    output wire                              sbus_we_o,          //write enable              | initiator
    output wire [SP_WIDTH-1:0]               sbus_adr_o,         //address bus               | to
    output wire [15:0]                       sbus_dat_o,         //write data bus            | target
    output wire                              sbus_tga_ps_o,      //parameter stack access    |
    output wire                              sbus_tga_rs_o,      //return stack access       +-
    input  wire                              sbus_ack_i,         //bus cycle acknowledge     +-
    input  wire                              sbus_err_i,         //error indicator           | target
    input  wire                              sbus_rty_i,         //retry request             | to
    input  wire                              sbus_stall_i,       //access delay              | initiator
    input  wire [15:0]                       sbus_dat_i,         //read data bus             +-

    //Interrupt interface
    output wire                              irq_ack_o,          //interrupt acknowledge
    input wire [15:0]                        irq_req_adr_i,      //requested interrupt vector

    //Probe signals
    //Exception aggregator
    //Flow Controller
    output wire [3:0]                        prb_fc_state_o,     //FSM state
    //Intermediate parameter stack
    output wire [IPS_DEPTH-1:0]              prb_ips_ctags_o,    //intermediate stack cell tags
    output wire [(IPS_DEPTH*16)-1:0]         prb_ips_cells_o,    //intermediate stack cells
    output wire [SP_WIDTH-1:0]               prb_ips_lsp_o,      //lower stack pointer
    output wire [1:0]                        prb_ips_state_o,    //FSM state
    //Intermediate return stack
    output wire [IRS_DEPTH-1:0]              prb_irs_ctags_o,    //intermediate stack cell tags
    output wire [(IRS_DEPTH*16)-1:0]         prb_irs_cells_o,    //intermediate stack cells
    output wire [SP_WIDTH-1:0]               prb_irs_lsp_o,      //lower stack pointer
    output wire [1:0]                        prb_irs_state_o,    //FSM state
    //Stack bus arbiter
    output wire [1:0]                        prb_sarb_state_o,   //FSM state
    //Upper stacks
    output wire [3:0]                        prb_us_ps_ctags_o,  //intermediate stack cell tags
    output wire [(4*16)-1:0]                 prb_us_ps_cells_o,  //intermediate stack cells
    output wire                              prb_us_rs_ctags_o,  //intermediate stack cell tags
    output wire [15:0]                       prb_us_rs_cells_o,  //intermediate stack cells
    output wire [1:0]                        prb_us_state_o);    //FSM state
    
   //Internal interfaces
   //-------------------
   //ALU
   //ALU -> DSP
   wire                                     alu2dsp_sub_add_b;   //1:op1 - op0, 0:op1 + op0
   wire                                     alu2dsp_smul_umul_b; //1:signed, 0:unsigned
   wire [15:0]                              alu2dsp_add_op0;     //first operand for adder/subtractor
   wire [15:0]                              alu2dsp_add_op1;     //second operand for adder/subtractor (zero if no operator selected)
   wire [15:0]                              alu2dsp_mul_op0;     //first operand for multipliers
   wire [15:0]                              alu2dsp_mul_op1;     //second operand dor multipliers (zero if no operator selected)
   //ALU -> US
   wire [15:0]                              alu2us_ps0_next;     //new PS0 (TOS)
   wire [15:0]                              alu2us_ps1_next;     //new PS1 (TOS+1)
   
   //DSP
   //DSP -> ALU
   wire [31:0]                              dsp2alu_add_res;     //result from adder
   wire [31:0]                              dsp2alu_mul_res;     //result from multiplier


   //DSP -> FC
   wire [15:0]                              dsp2fc_next_pc;      //result

   //DSP -> IPS
   wire [SP_WIDTH-1:0]                      dsp2ips_lsp;         //lower stack pointer
   //DSP -> IRS
   wire [SP_WIDTH-1:0]                      dsp2irs_lsp;         //lower stack pointer



   
   
   //EXCPT
   //EXCPT -> ALU   
   wire [15:0]                              excpt2alu_tc;        //throw code

   //FC
   //FC -> DSP
   wire                                     fc2dsp_abs_rel_b;    //1:absolute COF, 0:relative COF
   wire                                     fc2dsp_update;       //update PC
   wire [15:0]                              fc2dsp_rel_adr;      //relative COF address
   wire [15:0]                              fc2dsp_abs_adr;      //rabsolute COF address
 
   //IPS
   //IPS -> ALU
   wire [IPS_DEPTH-1:0]                     ips2alu_tags;        //cell tags
   wire [SP_WIDTH-1:0]                      ips2alu_lsp;         //lower stack pointer

   //IPS -> DSP
   wire                                     ips2dsp_psh;         //push (decrement address)
   wire                                     ips2dsp_pul;         //pull (increment address)
   wire                                     ips2dsp_rst;         //reset AGU

   //IR
   //IR -> ALU
   wire [4:0]                               ir2alu_opr;          //ALU operator
   wire [4:0]                               ir2alu_imm_op;       //immediate operand
   wire                                     ir2alu_sel_imm_op;   //select immediate operand

   //IRS
   //IRS -> ALU
   wire [IRS_DEPTH-1:0]                     irs2alu_tags;        //cell tags
   wire [SP_WIDTH-1:0]                      irs2alu_lsp;         //lower stack pointer
   //IRS -> DSP
   wire                                     irs2dsp_psh;         //push (increment address)
   wire                                     irs2dsp_pul;         //pull (decrement address)
   wire                                     irs2dsp_rst;         //reset AGU

   //SARB
   
   //US
   //US -> ALU
   wire [15:0]                              us2alu_ps0_cur;      //current PS0 (TOS)
   wire [15:0]                              us2alu_ps1_cur;      //current PS1 (TOS+1)
   wire [3:0]                               us2alu_ptags;        //UPS tags
   wire                                     us2alu_rtags;        //URS tags





   //ALU
   //---
   N1_alu
     #(.SP_WIDTH  (`SP_WIDTH),                                   //width of the stack pointer
       .IPS_DEPTH (`IPS_DEPTH),                                  //depth of the intermediate parameter stack
       .IRS_DEPTH (`IRS_DEPTH))                                  //depth of the intermediate return stack
   DUT
   (//DSP cell interface
    .alu2dsp_sub_add_b_o        (alu2dsp_sub_add_b),             //1:op1 - op0, 0:op1 + op0
    .alu2dsp_smul_umul_b_o      (alu2dsp_smul_umul_b),           //1:signed, 0:unsigned
    .alu2dsp_add_op0_o          (alu2dsp_add_op0),               //first operand for adder/subtractor
    .alu2dsp_add_op1_o          (alu2dsp_add_op1),               //second operand for adder/subtractor (zero if no operator selected)
    .alu2dsp_mul_op0_o          (alu2dsp_mul_op0),               //first operand for multipliers
    .alu2dsp_mul_op1_o          (alu2dsp_mul_op1),               //second operand dor multipliers (zero if no operator selected)
    .dsp2alu_add_res_i          (dsp2alu_add_res),               //result from adder
    .dsp2alu_mul_res_i          (dsp2alu_mul_res),               //result from multiplier

    //Exception interface
    .excpt2alu_tc_i             (excpt2alu_tc),                  //throw code

    //Intermediate parameter stack interface
    .ips2alu_tags_i             (ips2alu_tags),                  //cell tags
    .ips2alu_lsp_i              (ips2alu_lsp),                   //lower stack pointer

    //IR interface
    .ir2alu_opr_i               (ir2alu_opr),                    //ALU operator
    .ir2alu_imm_op_i            (ir2alu_imm_op),                 //immediate operand
    .ir2alu_sel_imm_op_i        (ir2alu_sel_imm_op),             //select immediate operand

    //Intermediate return stack interface
    .irs2alu_tags_i             (irs2alu_tags),                  //cell tags
    .irs2alu_lsp_i              (irs2alu_lsp),                   //lower stack pointer

     //Upper stack interface
    .alu2us_ps0_next_o          (alu2us_ps0_next),               //new PS0 (TOS)
    .alu2us_ps1_next_o          (alu2us_ps1_next),               //new PS1 (TOS+1)
    .us2alu_ps0_cur_i           (us2alu_ps0_cur),                //current PS0 (TOS)
    .us2alu_ps1_cur_i           (us2alu_ps1_cur),                //current PS1 (TOS+1)
    .us2alu_ptags_i             (us2alu_ptags),                  //UPS tags
    .us2alu_rtags_i             (us2alu_rtags));                 //URS tags

   //DSP
   //---
   N1_dsp
     #(.SP_WIDTH (SP_WIDTH))                                     //width of a stack pointer
   dsp
     (//Clock and reset
      .clk_i                      (clk_i),                       //module clock
      .async_rst_i                (async_rst_i),                 //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                  //synchronous reset

      //ALU interface
      .alu2dsp_sub_add_b_i        (alu2dsp_sub_add_b),           //1:op1 - op0, 0:op1 + op0
      .alu2dsp_smul_umul_b_i      (alu2dsp_smul_umul_b),         //1:signed, 0:unsigned
      .alu2dsp_add_op0_i          (alu2dsp_add_op0),             //first operand for adder/subtractor
      .alu2dsp_add_op1_i          (alu2dsp_add_op1),             //second operand for adder/subtractor (zero if no operator selected)
      .alu2dsp_mul_op0_i          (alu2dsp_mul_op0),             //first operand for multipliers
      .alu2dsp_mul_op1_i          (alu2dsp_mul_op1),             //second operand dor multipliers (zero if no operator selected)
      .dsp2alu_add_res_o          (dsp2alu_add_res),             //result from adder
      .dsp2alu_mul_res_o          (dsp2alu_mul_res),             //result from multiplier

      //Flow control interface (program counter)
      .fc2dsp_abs_rel_b_i         (fc2dsp_abs_rel_b),            //1:absolute COF, 0:relative COF
      .fc2dsp_update_i            (fc2dsp_update),               //update PC
      .fc2dsp_rel_adr_i           (fc2dsp_rel_adr),              //relative COF address
      .fc2dsp_abs_adr_i           (fc2dsp_abs_adr),              //absolute COF address
      .dsp2fc_next_pc_o           (dsp2fc_next_pc),              //result

      //Intermediate parameter stack interface (AGU, stack grows towards lower addresses)
      .ips2dsp_psh_i              (ips2dsp_psh),                 //push (decrement address)
      .ips2dsp_pul_i              (ips2dsp_pul),                 //pull (increment address)
      .ips2dsp_rst_i              (ips2dsp_rst),                 //reset AGU
      .dsp2ips_lsp_o              (dsp2ips_lsp),                 //lower stack pointer

      //Intermediate return stack interface (AGU, stack grows towardshigher addresses)
      .irs2dsp_psh_i              (irs2dsp_psh),                 //push (increment address)
      .irs2dsp_pul_i              (irs2dsp_pul),                 //pull (decrement address)
      .irs2dsp_rst_i              (irs2dsp_rst),                 //reset AGU
      .dsp2irs_lsp_o              (dsp2irs_lsp));                //lower stack pointer

   //EXCPT
   //-----


   //FC
   //--


   //IPS
   //---



   //IRS
   //---


   //SARB
   //----


   //US
   //---



   

  
endmodule // N1
