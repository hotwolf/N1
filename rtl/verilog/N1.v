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
//#    The N1 consists of seven subblocks:                                      #
//#       ALU -> Arithmetic Logic Unit                                          #
//#         This block performs arithmetic and logic operations. The            #
//#         implementation of multipliers and adders has been moved to the DSP  #
//#         block.                                                              #
//#       DSP -> DSP Cell Partition                                             #
//#         This block gathers logic from ALU, FC, IPS, and IRS, which can be   #
//#         directly mapped to FPGA DSP cells. The implementation of this block #
//#         is specific to the targeted FPGA architecture.                      #
//#       FC -> Flow Control                                                    #
//#         This block implements the main finite state machine of the N1       #
//#         processor, which controls the program execution.                    #
//#       IR -> Instruction Register and Decoder                                #
//#         This block captures the current instructions ond performs basic     #
//#         decoding.                                                           #
//#       PAGU -> Program Bus Address Generation Unit                           #
//#         This block contains some address generation logic for the program   #
//#         bus. It is an extension of the instruction regisister block.        #
//#       PRS -> Parameter and Return Stack                                     #
//#         This block implements all levels (upper, intermediate, and lower)   #
//#         of the parameter and the return stack.                              #
//#       SAGU -> Stack Bus Address Generation Unit                             #
//#         This block contains some address generation logic for the stack     #
//#         bus. It is an extension of the parameter and return stack  block.   #
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
  #(parameter SP_WIDTH         = 12,                                 //width of a stack pointer
    parameter IPS_DEPTH        =  8,                                 //depth of the intermediate parameter stack
    parameter IRS_DEPTH        =  8,                                 //depth of the intermediate return stack
    parameter PBUS_AADR_OFFSET = 16'h0000,                           //offset for direct program address
    parameter PBUS_MADR_OFFSET = 16'h0000)                           //offset for direct data address
   //  address							     
								     
   (//Clock and reset						     
    input  wire                              clk_i,                  //module clock
    input  wire                              async_rst_i,            //asynchronous reset
    input  wire                              sync_rst_i,             //synchronous reset
								     
    //Program bus (wishbone)					     
    output wire                              pbus_cyc_o,             //bus cycle indicator       +-
    output wire                              pbus_stb_o,             //access request            |
    output wire                              pbus_we_o,              //write enable              |
    output wire [15:0]                       pbus_adr_o,             //address bus               | 
    output wire [15:0]                       pbus_dat_o,             //write data bus            | initiator
    output wire                              pbus_tga_cof_jmp_o,     //COF jump                  | to	
    output wire                              pbus_tga_cof_cal_o,     //COF call                  | target   
    output wire                              pbus_tga_cof_bra_o,     //COF conditional branch    |
    output wire                              pbus_tga_cof_eow_o,     //COF return from call      |	    	
    output wire                              pbus_tga_dat_o,         //data access               | 
    input  wire                              pbus_ack_i,             //bus cycle                 +-
    input  wire                              pbus_err_i,             //error indicator           | target to
    input  wire                              pbus_stall_i,           //access delay              | initiator
    input  wire [15:0]                       pbus_dat_i,             //read data bus             +-

    //Stack bus (wishbone)
    output wire                              sbus_cyc_o,             //bus cycle indicator       +-
    output wire                              sbus_stb_o,             //access request            |
    output wire                              sbus_we_o,              //write enable              | initiator
    output wire [SP_WIDTH-1:0]               sbus_adr_o,             //address bus               | to
    output wire [15:0]                       sbus_dat_o,             //write data bus            | target
    output wire                              sbus_tga_ps_o,          //parameter stack access    |
    output wire                              sbus_tga_rs_o,          //return stack access       +-
    input  wire                              sbus_ack_i,             //bus cycle acknowledge     +-
    input  wire                              sbus_stall_i,           //access delay              | target to initiator
    input  wire [15:0]                       sbus_dat_i,             //read data bus             +-
								     
    //Interrupt interface					     
    output wire                              irq_ack_o,              //interrupt acknowledge
    input  wire [15:0]                       irq_vec_i,              //requested interrupt vector

    //Probe signals
    //Exception aggregator
    output wire [2:0]                        prb_excpt_o,            //exception tracker
    output wire                              prb_excpt_en_o,         //exception enable
    output wire                              prb_irq_en_o,           //interrupt enable

//  //Flow Controller
//  output wire [3:0]                        prb_fc_state_o,         //FSM state
//  //Intermediate parameter stack				     
//  output wire [IPS_DEPTH-1:0]              prb_ips_tags_o,         //intermediate stack cell tags
//  output wire [(IPS_DEPTH*16)-1:0]         prb_ips_cells_o,        //intermediate stack cells
//  output wire [SP_WIDTH-1:0]               prb_ips_lsp_o,          //lower stack pointer
//  output wire [1:0]                        prb_ips_state_o,        //FSM state
//  //Intermediate return stack					     
//  output wire [IRS_DEPTH-1:0]              prb_irs_tags_o,         //intermediate stack cell tags
//  output wire [(IRS_DEPTH*16)-1:0]         prb_irs_cells_o,        //intermediate stack cells
//  output wire [SP_WIDTH-1:0]               prb_irs_lsp_o,          //lower stack pointer
//  output wire [1:0]                        prb_irs_state_o,        //FSM state
//  //Stack bus arbiter						     
//  output wire [1:0]                        prb_sarb_state_o,       //FSM state
//  //Upper stacks						     
//  output wire [3:0]                        prb_us_ps_tags_o,       //intermediate stack cell tags
//  output wire [(4*16)-1:0]                 prb_us_ps_cells_o,      //intermediate stack cells
//  output wire                              prb_us_rs_tags_o,       //intermediate stack cell tags
//  output wire [15:0]                       prb_us_rs_cells_o,      //intermediate stack cells
//  output wire [1:0]                        prb_us_state_o);        //FSM state
    );
   
   //Internal interfaces
   //-------------------
   //ALU - Arithmetic Logic Unit
   //ALU -> DSP
   wire 				     alu2dsp_add_sel;        //1:sub, 0:add
   wire 				     alu2dsp_mul_sel;        //1:smul, 0:umul
   wire [15:0] 				     alu2dsp_add_op0;        //first operand for adder/subtractor
   wire [15:0] 				     alu2dsp_add_op1;        //second operand for adder/subtractor (zero if no operator selected)
   wire [15:0] 				     alu2dsp_mul_op0;        //first operand for multipliers
   wire [15:0] 				     alu2dsp_mul_op1;        //second operand dor multipliers (zero if no operator selected)
   //ALU -> PRS
   wire [15:0] 				     alu2prs_ps0_next;       //new PS0 (TOS)
   wire [15:0] 				     alu2prs_ps1_next;       //new PS1 (TOS+1)

   //DSP - DSP Cell Partition
   //DSP -> ALU
   wire [31:0]                              dsp2alu_add_res;         //result from adder
   wire [31:0]                              dsp2alu_mul_res;         //result from multiplier
// //DSP -> FC
// wire [15:0]                              dsp2fc_next_pc;      //result
// //DSP -> IPS
// wire [SP_WIDTH-1:0]                      dsp2ips_lsp;         //lower stack pointer
// //DSP -> IRS
// wire [SP_WIDTH-1:0]                      dsp2irs_lsp;         //lower stack pointer
//
   //EXCPT - Exception Aggregator
   //EXCPT -> FC
   wire                                     excpt2fc_excpt;          //exception to be handled
   wire                                     excpt2fc_irq;            //exception to be handled
   //EXCPT -> PRS
   wire [15:0]                              excpt2prs_tc;            //throw code






   
// //FC - Flow Control
// //FC -> DSP
// wire                                     fc2dsp_abs_rel_b;    //1:absolute COF, 0:relative COF
// wire                                     fc2dsp_update;       //update PC
// wire [15:0]                              fc2dsp_rel_adr;      //relative COF address
// wire [15:0]                              fc2dsp_abs_adr;      //rabsolute COF address
// //FC -> IR
// wire                                     fc2ir_capture;       //capture current IR
// wire                                     fc2ir_hoard;         //capture hoarded IR
// wire                                     fc2ir_expend;        //hoarded IR -> current IR
//
// //IPS - Intermediate (and Lower) Parameter Stack
// //IPS -> ALU
// wire [IPS_DEPTH-1:0]                     ips2alu_tags;        //cell tags
// wire [SP_WIDTH-1:0]                      ips2alu_lsp;         //lower stack pointer
// //IPS -> DSP
// wire                                     ips2dsp_psh;         //push (decrement address)
// wire                                     ips2dsp_pul;         //pull (increment address)
// wire                                     ips2dsp_rst;         //reset AGU
// //IPS -> EXCPT
// wire                                     ips2excpt_buserr;    //bus error
// //IPS -> SARB
// wire                                     ips2sarb_cyc;        //bus cycle indicator       +-
// wire                                     ips2sarb_stb;        //access request            | initiator
// wire                                     ips2sarb_we;         //write enable              | to
// wire [`SP_WIDTH-1:0]                     ips2sarb_adr;        //address bus               | target
// wire [15:0]                              ips2sarb_dat;        //write data bus            +-
// //IPS -> US
// wire                                     ips2us_busy;         //intermediate stack is busy
// wire                                     ips2us_pul_ctag;     //intermediate stack cell tag
// wire [15:0]                              ips2us_pul_cell;     //intermediate stack cell
//
   //IR - Instruction Register and Decoder
   //IR -> ALU
   wire [4:0]                               ir2alu_opr;              //ALU operator
   wire [4:0]                               ir2alu_opd;              //immediate operand
   wire                                     ir2alu_opd_sel;          //select (stacked) operand
// //IR -> FC
   //IR -> EXCPT
   wire                                     ir2excpt_except_en;      //enable exceptions
   wire                                     ir2excpt_irq_en;         //enable interrupts
   wire                                     ir2excpt_irq_dis;        //disable interrupts




// //IR -> US
// 
// //IRS - Intermediate (and Lower) Return Stack
// //IRS -> ALU
// wire [IRS_DEPTH-1:0]                     irs2alu_tags;        //cell tags
// wire [SP_WIDTH-1:0]                      irs2alu_lsp;         //lower stack pointer
// //IRS -> DSP
// wire                                     irs2dsp_psh;         //push (increment address)
// wire                                     irs2dsp_pul;         //pull (decrement address)
// wire                                     irs2dsp_rst;         //reset AGU
// //IRS -> EXCPT
// wire                                     irs2excpt_buserr;    //bus error
// //IRS -> SARB
// wire                                     irs2sarb_cyc;        //bus cycle indicator       +-
// wire                                     irs2sarb_stb;        //access request            | initiator
// wire                                     irs2sarb_we;         //write enable              | to
// wire [`SP_WIDTH-1:0]                     irs2sarb_adr;        //address bus               | target
// wire [15:0]                              irs2sarb_dat;        //write data bus            +-
// //IRS -> US
// wire                                     irs2us_busy;         //intermediate stack is busy
// wire                                     irs2us_pul_ctag;     //intermediate stack cell tag
// wire [15:0]                              irs2us_pul_cell;     //intermediate stack cell

   //PRS - Parameter and Return Stack 
   //PRS -> EXCPT					    
   wire                                     prs2excpt_psof;       //PS overflow
   wire                                     prs2excpt_psuf;       //PS underflow
   wire                                     prs2excpt_rsof;       //RS overflow
   wire                                     prs2excpt_rsuf;       //RS underflow
		


			    
// //SARB - Stack Bus Arbiter
// //SARB -> IPS
// wire                                     sarb2ips_ack;        //bus cycle acknowledge     +-
// wire                                     sarb2ips_err;        //error indicator           | target
// wire                                     sarb2ips_rty;        //retry request             | to
// wire                                     sarb2ips_stall;      //access delay              | initiator
// wire [15:0]                              sarb2ips_dat;        //read data bus             +-
// //SARB -> IRS
// wire                                     sarb2irs_ack;        //bus cycle acknowledge     +-
// wire                                     sarb2irs_err;        //error indicator           | target
// wire                                     sarb2irs_rty;        //retry request             | to
// wire                                     sarb2irs_stall;      //access delay              | initiator
// wire [15:0]                              sarb2irs_dat;        //read data bus             +-
//
// //US - Upper Stacks
// //US -> ALU
// wire [15:0]                              us2alu_ps0_cur;      //current PS0 (TOS)
// wire [15:0]                              us2alu_ps1_cur;      //current PS1 (TOS+1)
// wire [3:0]                               us2alu_ptags;        //UPS tags
// wire                                     us2alu_rtags;        //URS tags
// //US -> IPS
// wire                                     us2ips_rst;          //reset stack
// wire                                     us2ips_psh;          //US  -> IRS
// wire                                     us2ips_pul;          //IRS -> US
// wire                                     us2ips_psh_ctag;     //upper stack cell tag
// wire [15:0]                              us2ips_psh_cell;     //upper stack cell
// //US -> IRS
// wire                                     us2irs_rst;          //reset stack
// wire                                     us2irs_psh;          //US  -> IRS
// wire                                     us2irs_pul;          //IRS -> US
// wire                                     us2irs_psh_ctag;     //upper stack cell tag
// wire [15:0]                              us2irs_psh_cell;     //upper stack cell

   //ALU
   //---
   N1_alu
   alu
   (//DSP interface
    .alu2dsp_add_sel_o            (alu2dsp_add_sel),                 //1:sub, 0:add
    .alu2dsp_mul_sel_o            (alu2dsp_mul_sel),                 //1:smul, 0:umul
    .alu2dsp_add_op0_o            (alu2dsp_add_op0),                 //first operand for adder/subtractor
    .alu2dsp_add_op1_o            (alu2dsp_add_op1),                 //second operand for adder/subtractor (zero if no operator selected)
    .alu2dsp_mul_op0_o            (alu2dsp_mul_op0),                 //first operand for multipliers
    .alu2dsp_mul_op1_o            (alu2dsp_mul_op1),                 //second operand dor multipliers (zero if no operator selected)
    .dsp2alu_add_res_i            (dsp2alu_add_res),                 //result from adder
    .dsp2alu_mul_res_i            (dsp2alu_mul_res),                 //result from multiplier
  				  				     								     
    //IR interface		  				     
    .ir2alu_opr_i                 (ir2alu_opr),                      //ALU operator
    .ir2alu_opd_i                 (ir2alu_opd),                      //immediate operand
    .ir2alu_opd_sel_i             (ir2alu_opd_sel),                  //select (stacked) operand
  								     
     //PRS interface					     
    .alu2prs_ps0_next_o           (alu2prs_ps0_next),                  //new PS0 (TOS)
    .alu2prs_ps1_next_o           (alu2prs_ps1_next),                  //new PS1 (TOS+1)
    .prs2alu_ps0_i                (prs2alu_ps0),                     //current PS0 (TOS)
    .prs2alu_ps1_i                (prs2alu_ps1));                    //current PS1 (TOS+1)
  
   //DSP
   //---
   N1_dsp
     #(.SP_WIDTH (SP_WIDTH))                                         //width of a stack pointer
   dsp								     
     (//Clock and reset						     
      .clk_i                      (clk_i),                           //module clock
      .async_rst_i                (async_rst_i),                     //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                      //synchronous reset
  								     
      //ALU interface						     
      .dsp2alu_add_res_o          (dsp2alu_add_res),                 //result from adder
      .dsp2alu_mul_res_o          (dsp2alu_mul_res),                 //result from multiplier
      .alu2dsp_add_sel_i          (alu2dsp_add_sel),                 //1:sub, 0:add
      .alu2dsp_mul_sel_i          (alu2dsp_mul_sel),                 //1:smul, 0:umul
      .alu2dsp_add_op0_i          (alu2dsp_add_op0),                 //first operand for adder/subtractor
      .alu2dsp_add_op1_i          (alu2dsp_add_op1),                 //second operand for adder/subtractor (zero if no operator selected)
      .alu2dsp_mul_op0_i          (alu2dsp_mul_op0),                 //first operand for multipliers
      .alu2dsp_mul_op1_i          (alu2dsp_mul_op1),                 //second operand dor multipliers (zero if no operator selected)
  
//    //Flow control interface (program counter)
//    .fc2dsp_abs_rel_b_i         (fc2dsp_abs_rel_b),            //1:absolute COF, 0:relative COF
//    .fc2dsp_update_i            (fc2dsp_update),               //update PC
//    .fc2dsp_rel_adr_i           (fc2dsp_rel_adr),              //relative COF address
//    .fc2dsp_abs_adr_i           (fc2dsp_abs_adr),              //absolute COF address
//    .dsp2fc_next_pc_o           (dsp2fc_next_pc),              //result
//
//    //Intermediate parameter stack interface (AGU, stack grows towards lower addresses)
//    .ips2dsp_psh_i              (ips2dsp_psh),                 //push (decrement address)
//    .ips2dsp_pul_i              (ips2dsp_pul),                 //pull (increment address)
//    .ips2dsp_rst_i              (ips2dsp_rst),                 //reset AGU
//    .dsp2ips_lsp_o              (dsp2ips_lsp),                 //lower stack pointer
//
//    //Intermediate return stack interface (AGU, stack grows towardshigher addresses)
//    .irs2dsp_psh_i              (irs2dsp_psh),                 //push (increment address)
//    .irs2dsp_pul_i              (irs2dsp_pul),                 //pull (decrement address)
//    .irs2dsp_rst_i              (irs2dsp_rst),                 //reset AGU
//    .dsp2irs_lsp_o              (dsp2irs_lsp));                //lower stack pointer
      );
       
   //EXCPT
   //-----
   N1_excpt
   excpt
   (//Clock and reset
    input wire                       clk_i,                  //module clock
    input wire                       async_rst_i,            //asynchronous reset
    input wire                       sync_rst_i,             //synchronous reset

    //Interrupt interface
    input  wire [15:0]               irq_req_adr_i,          //requested interrupt vector

    //Internal interfaces
    //-------------------
    //FC interface
    output wire                      excpt2fc_excpt_o,       //exception to be handled
    output wire                      excpt2fc_irq_o,         //exception to be handled
    input  wire                      fc2excpt_excpt_dis_i,   //disable exceptions
    input  wire                      fc2excpt_irq_dis_i,     //disable interrupts
    input  wire                      fc2excpt_buserr_i,      //pbus error

    //IR interface
    input  wire                      ir2excpt_except_en_i,   //enable exceptions
    input  wire                      ir2excpt_irq_en_i,      //enable interrupts
    input  wire                      ir2excpt_irq_dis_i,     //disable interrupts

    //PRS interface
    output wire [15:0]               excpt2prs_tc_o,         //throw code
    input  wire                      prs2excpt_psof_i,       //PS overflow
    input  wire                      prs2excpt_psuf_i,       //PS underflow
    input  wire                      prs2excpt_rsof_i,       //RS overflow
    input  wire                      prs2excpt_rsuf_i,       //RS underflow

    //Probe signals
    output wire [2:0]                prb_excpt_o,            //exception tracker
    output wire                      prb_excpt_en_o,         //exception enable
    output wire                      prb_irq_en_o);          //interrupt enable



       

// //FC
// //--
//
//
// //IPS
// //---
// N1_is
//   #(.SP_WIDTH (SP_WIDTH),                                     //width of the stack pointer
//     .IS_DEPTH (IPS_DEPTH),                                    //depth of the intermediate stack
//     .LS_START ({SP_WIDTH{1'b1}}))                             //stack pointer value of the empty lower stack
// ips
//   (//Clock and reset
//    .clk_i                    (clk_i),                         //module clock
//    .async_rst_i              (async_rst_i),                   //asynchronous reset
//    .sync_rst_i               (sync_rst_i),                    //synchronous reset
//
//    //ALU interface
//    .is2alu_tags_o            (ips2alu_tags),                  //cell tags
//    .is2alu_lsp_o             (ips2alu_lsp),                   //lower stack pointer
//
//    //DSP partition interface
//    .dsp2is_lsp_i             (dsp2ips_lsp),                   //lower stack pointer
//    .is2dsp_psh_o             (ips2dsp_psh),                   //push (decrement address)
//    .is2dsp_pul_o             (ips2dsp_pul),                   //pull (increment address)
//    .is2dsp_rst_o             (ips2dsp_rst),                   //reset AGU
//
//    //Exception aggregator interface
//    .is2excpt_buserr_o        (ips2excpt_buserr),              //bus error
//
//    //Stack bus arbiter interface
//    .is2sarb_cyc_o            (ips2sarb_cyc),                  //bus cycle indicator       +-
//    .is2sarb_stb_o            (ips2sarb_stb),                  //access request            | initiator
//    .is2sarb_we_o             (ips2sarb_we),                   //write enable              | to
//    .is2sarb_adr_o            (ips2sarb_adr),                  //address bus               | target
//    .is2sarb_dat_o            (ips2sarb_dat),                  //write data bus            +-
//    .sarb2is_ack_i            (sarb2ips_ack),                  //bus cycle acknowledge     +-
//    .sarb2is_err_i            (sarb2ips_err),                  //error indicator           | target
//    .sarb2is_rty_i            (sarb2ips_rty),                  //retry request             | to
//    .sarb2is_stall_i          (sarb2ips_stall),                //access delay              | initiator
//    .sarb2is_dat_i            (sarb2ips_dat),                  //read data bus             +-
//
//    //Upper stack interface
//    .us2is_rst_i              (us2ips_rst),                    //reset stack
//    .us2is_psh_i              (us2ips_psh),                    //US -> IS
//    .us2is_pul_i              (us2ips_pul),                    //IS -> US
//    .us2is_psh_ctag_i         (us2ips_psh_ctag),               //upper stack cell tag
//    .us2is_psh_cell_i         (us2ips_psh_cell),               //upper stack cell
//    .is2us_busy_o             (ips2us_busy),                   //intermediate stack is busy
//    .is2us_pul_ctag_o         (ips2us_pul_ctag),               //intermediate stack cell tag
//    .is2us_pul_cell_o         (ips2us_pul_cell),               //intermediate stack cell
//
//    //Probe signals
//    .prb_is_tags_o            (prb_ips_tags_o),                //intermediate stack cell tags
//    .prb_is_cells_o           (prb_ips_cells_o),               //intermediate stack cells
//    .prb_is_lsp_o             (prb_ips_lsp_o),                 //lower stack pointer
//    .prb_is_state_o           (prb_ips_state_o));              //FSM state
//
// //IR
// //--
//
//
//
// //IRS
// //---
// N1_is
//   #(.SP_WIDTH (SP_WIDTH),                                     //width of the stack pointer
//     .IS_DEPTH (IRS_DEPTH),                                    //depth of the intermediate stack
//     .LS_START ({SP_WIDTH{1'b0}}))                             //stack pointer value of the empty lower stack
// irs
//   (//Clock and reset
//    .clk_i                    (clk_i),                         //module clock
//    .async_rst_i              (async_rst_i),                   //asynchronous reset
//    .sync_rst_i               (sync_rst_i),                    //synchronous reset
//
//    //ALU interface
//    .is2alu_tags_o            (irs2alu_tags),                  //cell tags
//    .is2alu_lsp_o             (irs2alu_lsp),                   //lower stack pointer
//
//    //DSP partition interface
//    .dsp2is_lsp_i             (dsp2irs_lsp),                   //lower stack pointer
//    .is2dsp_psh_o             (irs2dsp_psh),                   //push (decrement address)
//    .is2dsp_pul_o             (irs2dsp_pul),                   //pull (increment address)
//    .is2dsp_rst_o             (irs2dsp_rst),                   //reset AGU
//
//    //Exception aggregator interface
//    .is2excpt_buserr_o        (irs2excpt_buserr),              //bus error
//
//    //Stack bus arbiter interface
//    .is2sarb_cyc_o            (irs2sarb_cyc),                  //bus cycle indicator       +-
//    .is2sarb_stb_o            (irs2sarb_stb),                  //access request            | initiator
//    .is2sarb_we_o             (irs2sarb_we),                   //write enable              | to
//    .is2sarb_adr_o            (irs2sarb_adr),                  //address bus               | target
//    .is2sarb_dat_o            (irs2sarb_dat),                  //write data bus            +-
//    .sarb2is_ack_i            (sarb2irs_ack),                  //bus cycle acknowledge     +-
//    .sarb2is_err_i            (sarb2irs_err),                  //error indicator           | target
//    .sarb2is_rty_i            (sarb2irs_rty),                  //retry request             | to
//    .sarb2is_stall_i          (sarb2irs_stall),                //access delay              | initiator
//    .sarb2is_dat_i            (sarb2irs_dat),                  //read data bus             +-
//
//    //Upper stack interface
//    .us2is_rst_i              (us2irs_rst),                    //reset stack
//    .us2is_psh_i              (us2irs_psh),                    //US -> IS
//    .us2is_pul_i              (us2irs_pul),                    //IS -> US
//    .us2is_psh_ctag_i         (us2irs_psh_ctag),               //upper stack cell tag
//    .us2is_psh_cell_i         (us2irs_psh_cell),               //upper stack cell
//    .is2us_busy_o             (irs2us_busy),                   //intermediate stack is busy
//    .is2us_pul_ctag_o         (irs2us_pul_ctag),               //intermediate stack cell tag
//    .is2us_pul_cell_o         (irs2us_pul_cell),               //intermediate stack cell
//
//    //Probe signals
//    .prb_is_tags_o            (prb_irs_tags_o),                //intermediate stack cell tags
//    .prb_is_cells_o           (prb_irs_cells_o),               //intermediate stack cells
//    .prb_is_lsp_o             (prb_irs_lsp_o),                 //lower stack pointer
//    .prb_is_state_o           (prb_irs_state_o));              //FSM state



      
   //PRS
   //---
   N1_prs
     #(.SP_WIDTH (SP_WIDTH))
   prs
     (//Clock and reset
      .clk_i                      (clk_i),                         //module clock
      .async_rst_i                (async_rst_i),                   //asynchronous reset
      .sync_rst_i                 (sync_rst_i),                    //synchronous reset
      
      //ALU interface					     
      .prs2alu_ps0_o              (prs2alu_ps0),                   //current PS0 (TOS)
      .prs2alu_ps1_o              (prs2alu_ps1),                   //current PS1 (TOS+1)
      .alu2prs_ps0_next_i         (alu2prs_ps0_next),              //new PS0 (TOS)
      .alu2prs_ps1_next_i         (alu2prs_ps1_next),              //new PS1 (TOS+1)




      

      );

   
//
// //SARB
// //----
// N1_sarb
//   #(.SP_WIDTH (SP_WIDTH))
// sarb
//   (//Clock and reset
//    .clk_i                    (clk_i),                         //module clock
//    .async_rst_i              (async_rst_i),                   //asynchronous reset
//    .sync_rst_i               (sync_rst_i),                    //synchronous reset
//
//    //Merged stack bus (wishbone)
//    .sbus_cyc_o               (sbus_cyc_o),                    //bus cycle indicator       +-
//    .sbus_stb_o               (sbus_stb_o),                    //access request            |
//    .sbus_we_o                (sbus_we_o),                     //write enable              | initiator
//    .sbus_adr_o               (sbus_adr_o),                    //address bus               | to
//    .sbus_dat_o               (sbus_dat_o),                    //write data bus            | target
//    .sbus_tga_ps_o            (sbus_tga_ps_o),                 //parameter stack access    |
//    .sbus_tga_rs_o            (sbus_tga_rs_o),                 //return stack access       +-
//    .sbus_ack_i               (sbus_ack_i),                    //bus cycle acknowledge     +-
//    .sbus_err_i               (sbus_err_i),                    //error indicator           | target
//    .sbus_rty_i               (sbus_rty_i),                    //retry request             | to
//    .sbus_stall_i             (sbus_stall_i),                  //access delay              | initiator
//    .sbus_dat_i               (sbus_dat_i),                    //read data bus             +-
//
//    //Parameter stack bus (wishbone)
//    .ips2sarb_cyc_i           (ips2sarb_cyc),                  //bus cycle indicator       +-
//    .ips2sarb_stb_i           (ips2sarb_stb),                  //access request            | initiator
//    .ips2sarb_we_i            (ips2sarb_we),                   //write enable              | to
//    .ips2sarb_adr_i           (ips2sarb_adr),                  //address bus               | target
//    .ips2sarb_dat_i           (ips2sarb_dat),                  //write data bus            +-
//    .sarb2ips_ack_o           (sarb2ips_ack),                  //bus cycle acknowledge     +-
//    .sarb2ips_err_o           (sarb2ips_err),                  //error indicator           | target
//    .sarb2ips_rty_o           (sarb2ips_rty),                  //retry request             | to
//    .sarb2ips_stall_o         (sarb2ips_stall),                //access delay              | initiator
//    .sarb2ips_dat_o           (sarb2ips_dat),                  //read data bus             +-
//
//    //Return stack bus (wishbone)
//    .irs2sarb_cyc_i           (irs2sarb_cyc),                  //bus cycle indicator       +-
//    .irs2sarb_stb_i           (irs2sarb_stb),                  //access request            | initiator
//    .irs2sarb_we_i            (irs2sarb_we),                   //write enable              | to
//    .irs2sarb_adr_i           (irs2sarb_adr),                  //address bus               | target
//    .irs2sarb_dat_i           (irs2sarb_dat),                  //write data bus            +-
//    .sarb2irs_ack_o           (sarb2irs_ack),                  //bus cycle acknowledge     +-
//    .sarb2irs_err_o           (sarb2irs_err),                  //error indicator           | target
//    .sarb2irs_rty_o           (sarb2irs_rty),                  //retry request             | to
//    .sarb2irs_stall_o         (sarb2irs_stall),                //access delay              | initiator
//    .sarb2irs_dat_o           (sarb2irs_dat),                  //read data bus             +-
//
//    //Probe signals
//    .prb_sarb_state_o         (prb_sarb_state_o));             //FSM state
//
// //US
// //---






endmodule // N1
