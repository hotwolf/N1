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
//#       EXCPT -> Exception and Interrupt Aggregator                           #
//#         This block tracks exceptions and monitors interrupts.               #
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
//#    "<source>2<sink>_<decriptive name>_<i/o>"                                #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//#   May 8, 2019                                                               #
//#      - Added RTY_I support to PBUS                                          #
//#      - Updated overflow monitoring                                          #
//###############################################################################
`default_nettype none

module N1
  #(parameter SP_WIDTH         = 12,                                 //width of a stack pointer
    parameter IPS_DEPTH        =  8,                                 //depth of the intermediate parameter stack
    parameter IRS_DEPTH        =  8,                                 //depth of the intermediate return stack
    parameter PBUS_AADR_OFFSET = 16'h0000,                           //offset for direct program address
    parameter PBUS_MADR_OFFSET = 16'h0000,                           //offset for direct data address
    parameter PS_RS_DIST       = 22)                                 //safety distance between PS and RS

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
    input  wire                              pbus_ack_i,             //bus cycle acknowledge     +-
    input  wire                              pbus_err_i,             //error indicator           | target
    input  wire                              pbus_rty_i,             //retry request             | to
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
    input  wire [15:0]                       irq_req_i,              //requested interrupt vector

    //Probe signals
    //DSP - DSP macro container
    output wire [15:0]                       prb_dsp_pc_o,           //PC
    output wire [SP_WIDTH-1:0]               prb_dsp_psp_o,          //PSP
    output wire [SP_WIDTH-1:0]               prb_dsp_rsp_o,          //RSP
    //EXCPT - Exception aggregator
    output wire [2:0]                        prb_excpt_o,            //exception tracker
    output wire                              prb_excpt_en_o,         //exception enable
    output wire                              prb_irq_en_o,           //interrupt enable
    //FC - Flow control
    output wire [2:0]                        prb_fc_state_o,         //state variable
    output wire                              prb_fc_pbus_acc_o,      //ongoing bus access
    //IR - Instruction register
    output wire [15:0]                       prb_ir_o,               //current instruction register
    output wire [15:0]                       prb_ir_stash_o,         //stashed instruction register
    //PAGU - Program bus AGU
    output wire [15:0]                       prb_pagu_prev_adr_o,        //address register
    //PRS - Parameter and return stack
    output wire [2:0]                        prb_state_task_o,       //current state
    output wire [1:0]                        prb_state_sbus_o,       //current state
    output wire [15:0]                       prb_rs0_o,              //current RS0
    output wire [15:0]                       prb_ps0_o,              //current PS0
    output wire [15:0]                       prb_ps1_o,              //current PS1
    output wire [15:0]                       prb_ps2_o,              //current PS2
    output wire [15:0]                       prb_ps3_o,              //current PS3
    output wire                              prb_rs0_tag_o,          //current RS0 tag
    output wire                              prb_ps0_tag_o,          //current PS0 tag
    output wire                              prb_ps1_tag_o,          //current PS1 tag
    output wire                              prb_ps2_tag_o,          //current PS2 tag
    output wire                              prb_ps3_tag_o,          //current PS3 tag
    output wire [(16*IPS_DEPTH)-1:0]         prb_ips_o,              //current IPS
    output wire [IPS_DEPTH-1:0]              prb_ips_tags_o,         //current IPS tags
    output wire [(16*IRS_DEPTH)-1:0]         prb_irs_o,              //current IRS
    output wire [IRS_DEPTH-1:0]              prb_irs_tags_o,         //current IRS tags
    //SAGU - Stack bus AGU
    output wire                              prb_sagu_of_o,          //overflow condition
    output wire                              prb_sagu_ps_o,          //PS operation
    output wire                              prb_sagu_rs_o);         //RS operation

   //Internal interfaces
   //-------------------
   //ALU - Arithmetic logic unit
   //ALU -> DSP
   wire                                      alu2dsp_add_sel;        //1:sub, 0:add
   wire                                      alu2dsp_mul_sel;        //1:smul, 0:umul
   wire [15:0]                               alu2dsp_add_opd0;       //first operand for adder/subtractor
   wire [15:0]                               alu2dsp_add_opd1;       //second operand for adder/subtractor (zero if no operator selected)
   wire [15:0]                               alu2dsp_mul_opd0;       //first operand for multipliers
   wire [15:0]                               alu2dsp_mul_opd1;       //second operand dor multipliers (zero if no operator selected)
   //ALU -> PRS
   wire [15:0]                               alu2prs_ps0_next;       //new PS0 (TOS)
   wire [15:0]                               alu2prs_ps1_next;       //new PS1 (TOS+1)

   //DSP - DSP cell partition
   //DSP -> ALU
   wire [31:0]                              dsp2alu_add_res;         //result from adder
   wire [31:0]                              dsp2alu_mul_res;         //result from multiplier
   //DSP -> PAGU
   wire [15:0]                              dsp2pagu_adr;            //AGU output
   //DSP -> PRS
   wire [SP_WIDTH-1:0]                      dsp2prs_psp;             //parameter stack pointer
   wire [SP_WIDTH-1:0]                      dsp2prs_rsp;             //return stack pointer
   //DSP -> SAGU
   wire [SP_WIDTH-1:0]                      dsp2sagu_psp_next;       //parameter stack pointer
   wire [SP_WIDTH-1:0]                      dsp2sagu_rsp_next;       //return stack pointer

   //EXCPT - Exception aggregator
   //EXCPT -> FC
   wire                                     excpt2fc_excpt;          //exception to be handled
   wire                                     excpt2fc_irq;            //exception to be handled
   //EXCPT -> PRS
   wire [15:0]                              excpt2prs_tc;            //throw code

   //FC - Flow control
   //FC -> DSP
   wire                                     fc2dsp_pc_hold;          //maintain PC
   wire                                     fc2dsp_radr_inc;         //increment relative address
   //FC -> EXCPT
   wire                                     fc2excpt_excpt_clr;      //clear and disable exceptions
   wire                                     fc2excpt_irq_dis;        //disable interrupts
   wire                                     fc2excpt_buserr;         //invalid pbus access
   //FC -> IR
   wire                                     fc2ir_capture;           //capture current IR
   wire                                     fc2ir_stash;             //capture stashed IR
   wire                                     fc2ir_expend;            //stashed IR -> current IR
   wire                                     fc2ir_force_eow;         //load EOW bit
   wire                                     fc2ir_force_0call;       //load 0 CALL instruction
   wire                                     fc2ir_force_call;        //load CALL instruction
   wire                                     fc2ir_force_drop;        //load DROP instruction
   wire                                     fc2ir_force_nop;         //load NOP instruction
   //FC -> PAGU
   wire                                     fc2pagu_prev_adr_hold;       //maintain stored address
   wire                                     fc2pagu_prev_adr_sel;        //0:AGU output, 1:previous address
   //FC -> PRS
   wire                                     fc2prs_hold;             //hold any state tran
   wire                                     fc2prs_dat2ps0;          //capture read data
   wire                                     fc2prs_tc2ps0;           //capture throw code
   wire                                     fc2prs_isr2ps0;          //capture ISR

   //IR - Instruction Register and Decoder
   //IR -> ALU
   wire [4:0]                               ir2alu_opr;              //ALU operator
   wire [4:0]                               ir2alu_opd;              //immediate operand
   wire                                     ir2alu_opd_sel;          //select (stacked) operand
   //IR -> FC
   wire                                     ir2fc_eow;               //end of word (EOW bit set)
   wire                                     ir2fc_eow_postpone;      //EOW conflict detected
   wire                                     ir2fc_jump_or_call;      //either JUMP or CALL
   wire                                     ir2fc_bra;               //conditonal BRANCG instruction
   wire                                     ir2fc_scyc;              //linear flow
   wire                                     ir2fc_mem;               //memory I/O
   wire                                     ir2fc_mem_rd;            //memory read
   wire                                     ir2fc_madr_sel;          //select (indirect) data address
   //IR -> EXCPT
   wire                                     ir2excpt_excpt_en;       //enable exceptions
   wire                                     ir2excpt_excpt_dis;      //disable exceptions
   wire                                     ir2excpt_irq_en;         //enable interrupts
   wire                                     ir2excpt_irq_dis;        //disable interrupts
   //IR -> PAGU
   wire                                     ir2pagu_eow;             //end of word (EOW bit)
   wire                                     ir2pagu_eow_postpone;    //postpone EOW
   wire                                     ir2pagu_jmp_or_cal;      //jump or call instruction
   wire                                     ir2pagu_bra;             //conditional branch
   wire                                     ir2pagu_scyc;            //single cycle instruction
   wire                                     ir2pagu_mem;             //memory I/O
   wire                                     ir2pagu_aadr_sel;        //select (indirect) absolute address
   wire                                     ir2pagu_madr_sel;        //select (indirect) data address
   wire [13:0]                              ir2pagu_aadr;            //direct absolute address
   wire [12:0]                              ir2pagu_radr;            //direct relative address
   wire [7:0]                               ir2pagu_madr;            //direct memory address
   //IR -> PRS
   wire                                     ir2prs_alu2ps0;          //ALU output  -> PS0
   wire                                     ir2prs_alu2ps1;          //ALU output  -> PS1
   wire                                     ir2prs_dat2ps0;          //read data   -> PS0
   wire                                     ir2prs_lit2ps0;          //literal     -> PS0
   wire                                     ir2prs_pc2rs0;           //PC          -> RS0
   wire                                     ir2prs_ps_rst;           //reset parameter stack
   wire                                     ir2prs_rs_rst;           //reset return stack
   wire                                     ir2prs_psp_get;          //read parameter stack pointer
   wire                                     ir2prs_psp_set;          //write parameter stack pointer
   wire                                     ir2prs_rsp_get;          //read return stack pointer
   wire                                     ir2prs_rsp_set;          //write return stack pointer
   wire [15:0]                              ir2prs_lit_val;          //literal value
   wire [7:0]                               ir2prs_us_tp;            //upper stack transition pattern
   wire [1:0]                               ir2prs_ips_tp;           //10:push, 01:pull
   wire [1:0]                               ir2prs_irs_tp;           //10:push, 01:pull

   //PAGU - Program bus address generation unit
   //PAGU -> DSP
   wire                                     pagu2dsp_adr_sel;        //1:absolute COF, 0:relative COF
   wire [15:0]                              pagu2dsp_aadr;           //absolute COF address
   wire [15:0]                              pagu2dsp_radr;           //relative COF address
   //PAGU -> PRS
   wire [15:0]                              pagu2prs_prev_adr;           //address register output

   //PRS - Parameter and return stack
   //PRS -> ALU
   wire [15:0]                              prs2alu_ps0;             //current PS0 (TOS)
   wire [15:0]                              prs2alu_ps1;             //current PS1 (TOS+1)
  //PRS -> EXCPT
   wire                                     prs2excpt_psuf;          //PS underflow
   wire                                     prs2excpt_rsuf;          //RS underflow
   //PRS -> FC
   wire                                     prs2fc_hold;             //stacks not ready
   wire                                     prs2fc_ps0_false;        //PS0 is zero
   //PRS -> PAGU
   wire [15:0]                              prs2pagu_ps0;            //PS0
   wire [15:0]                              prs2pagu_rs0;            //RS0
   //PRS -> SAGU
   wire                                     prs2sagu_hold;           //maintain stack pointers
   wire                                     prs2sagu_psp_rst;        //reset PSP
   wire                                     prs2sagu_rsp_rst;        //reset RSP
   wire                                     prs2sagu_stack_sel;      //1:RS, 0:PS
   wire                                     prs2sagu_push;           //increment stack pointer
   wire                                     prs2sagu_pull;           //decrement stack pointer
   wire                                     prs2sagu_load;           //load stack pointer
   wire [SP_WIDTH-1:0]                      prs2sagu_psp_load_val;   //parameter stack load value
   wire [SP_WIDTH-1:0]                      prs2sagu_rsp_load_val;   //return stack load value

   //SAGU - Stack bus address generation unit
   //SAGU -> DSP
   wire                                     sagu2dsp_psp_hold;       //maintain PSP
   wire                                     sagu2dsp_psp_op_sel;     //1:set new PSP, 0:add offset to PSP
   wire [SP_WIDTH-1:0]                      sagu2dsp_psp_offs;       //PSP offset
   wire [SP_WIDTH-1:0]                      sagu2dsp_psp_load_val;   //new PSP
   wire                                     sagu2dsp_rsp_hold;       //maintain RSP
   wire                                     sagu2dsp_rsp_op_sel;     //1:set new RSP, 0:add offset to RSP
   wire [SP_WIDTH-1:0]                      sagu2dsp_rsp_offs;       //relative address
   wire [SP_WIDTH-1:0]                      sagu2dsp_rsp_load_val;   //absolute address
   //SAGU -> EXCPT
   wire                                     sagu2excpt_psof;         //PS overflow
   wire                                     sagu2excpt_rsof;         //RS overflow

   //ALU - Arithmetic logic unit
   //---------------------------
   N1_alu
   alu
   (//DSP interface
    .alu2dsp_add_sel_o          (alu2dsp_add_sel),                  //1:sub, 0:add
    .alu2dsp_mul_sel_o          (alu2dsp_mul_sel),                  //1:smul, 0:umul
    .alu2dsp_add_opd0_o         (alu2dsp_add_opd0),                 //first operand for adder/subtractor
    .alu2dsp_add_opd1_o         (alu2dsp_add_opd1),                 //second operand for adder/subtractor (zero if no operator selected)
    .alu2dsp_mul_opd0_o         (alu2dsp_mul_opd0),                 //first operand for multipliers
    .alu2dsp_mul_opd1_o         (alu2dsp_mul_opd1),                 //second operand dor multipliers (zero if no operator selected)
    .dsp2alu_add_res_i          (dsp2alu_add_res),                  //result from adder
    .dsp2alu_mul_res_i          (dsp2alu_mul_res),                  //result from multiplier

    //IR interface
    .ir2alu_opr_i               (ir2alu_opr),                       //ALU operator
    .ir2alu_opd_i               (ir2alu_opd),                       //immediate operand
    .ir2alu_opd_sel_i           (ir2alu_opd_sel),                   //select (stacked) operand

     //PRS interface
    .alu2prs_ps0_next_o         (alu2prs_ps0_next),                  //new PS0 (TOS)
    .alu2prs_ps1_next_o         (alu2prs_ps1_next),                  //new PS1 (TOS+1)
    .prs2alu_ps0_i              (prs2alu_ps0),                       //current PS0 (TOS)
    .prs2alu_ps1_i              (prs2alu_ps1));                      //current PS1 (TOS+1)

   //DSP - DSP cell partition
   //------------------------
   N1_dsp
     #(.SP_WIDTH (SP_WIDTH))                                         //width of a stack pointer
   dsp
     (//Clock and reset
      .clk_i                    (clk_i),                             //module clock
      .async_rst_i              (async_rst_i),                       //asynchronous reset
      .sync_rst_i               (sync_rst_i),                        //synchronous reset

      //ALU interface
      .dsp2alu_add_res_o        (dsp2alu_add_res),                   //result from adder
      .dsp2alu_mul_res_o        (dsp2alu_mul_res),                   //result from multiplier
      .alu2dsp_add_sel_i        (alu2dsp_add_sel),                   //1:sub, 0:add
      .alu2dsp_mul_sel_i        (alu2dsp_mul_sel),                   //1:smul, 0:umul
      .alu2dsp_add_opd0_i       (alu2dsp_add_opd0),                  //first operand for adder/subtractor
      .alu2dsp_add_opd1_i       (alu2dsp_add_opd1),                  //second operand for adder/subtractor (zero if no operator selected)
      .alu2dsp_mul_opd0_i       (alu2dsp_mul_opd0),                  //first operand for multipliers
      .alu2dsp_mul_opd1_i       (alu2dsp_mul_opd1),                  //second operand dor multipliers (zero if no operator selected)

      //FC interface
      .fc2dsp_pc_hold_i         (fc2dsp_pc_hold),                    //maintain PC
      .fc2dsp_radr_inc_i        (fc2dsp_radr_inc),                   //increment relative address

      //PAGU interface
      .dsp2pagu_adr_o           (dsp2pagu_adr),                      //program AGU output
      .pagu2dsp_adr_sel_i       (pagu2dsp_adr_sel),                  //1:absolute COF, 0:relative COF
      .pagu2dsp_aadr_i          (pagu2dsp_aadr),                     //absolute COF address
      .pagu2dsp_radr_i          (pagu2dsp_radr),                     //relative COF address

      //PRS interface
      .dsp2prs_psp_o            (dsp2prs_psp),                       //parameter stack pointer
      .dsp2prs_rsp_o            (dsp2prs_rsp),                       //return stack pointer

      //SAGU interface
      .dsp2sagu_psp_next_o      (dsp2sagu_psp_next),                 //parameter stack pointer
      .dsp2sagu_rsp_next_o      (dsp2sagu_rsp_next),                 //return stack pointer
      .sagu2dsp_psp_hold_i      (sagu2dsp_psp_hold),                 //maintain PSP
      .sagu2dsp_psp_op_sel_i    (sagu2dsp_psp_op_sel),               //1:set new PSP, 0:add offset to PSP
      .sagu2dsp_psp_offs_i      (sagu2dsp_psp_offs),                 //PSP offset
      .sagu2dsp_psp_load_val_i  (sagu2dsp_psp_load_val),             //new PSP
      .sagu2dsp_rsp_hold_i      (sagu2dsp_rsp_hold),                 //maintain RSP
      .sagu2dsp_rsp_op_sel_i    (sagu2dsp_rsp_op_sel),               //1:set new RSP, 0:add offset to RSP
      .sagu2dsp_rsp_offs_i      (sagu2dsp_rsp_offs),                 //relative address
      .sagu2dsp_rsp_load_val_i  (sagu2dsp_rsp_load_val),             //absolute address

      //Probe signals
      .prb_dsp_pc_o             (prb_dsp_pc_o),                      //PC
      .prb_dsp_psp_o            (prb_dsp_psp_o),                     //PSP
      .prb_dsp_rsp_o            (prb_dsp_rsp_o));                    //RSP

   //EXCPT - Exception aggregator
   //----------------------------
   N1_excpt
   excpt
     (//Clock and reset
      .clk_i                    (clk_i),                             //module clock
      .async_rst_i              (async_rst_i),                       //asynchronous reset
      .sync_rst_i               (sync_rst_i),                        //synchronous reset

      //Interrupt interface
      .irq_req_i                (irq_req_i),                         //requested ISR

      //FC interface
      .excpt2fc_excpt_o         (excpt2fc_excpt),                    //exception to be handled
      .excpt2fc_irq_o           (excpt2fc_irq),                      //exception to be handled
      .fc2excpt_excpt_clr_i     (fc2excpt_excpt_clr),                //clear and disable exceptions
      .fc2excpt_irq_dis_i       (fc2excpt_irq_dis),                  //disable interrupts
      .fc2excpt_buserr_i        (fc2excpt_buserr),                   //pbus error

      //IR interface
      .ir2excpt_excpt_en_i      (ir2excpt_excpt_en),                 //enable exceptions
      .ir2excpt_excpt_dis_i     (ir2excpt_excpt_dis),                //disable exceptions
      .ir2excpt_irq_en_i        (ir2excpt_irq_en),                   //enable interrupts
      .ir2excpt_irq_dis_i       (ir2excpt_irq_dis),                  //disable interrupts

      //PRS interface
      .excpt2prs_tc_o           (excpt2prs_tc),                      //throw code
      .prs2excpt_psuf_i         (prs2excpt_psuf),                    //PS underflow
      .prs2excpt_rsuf_i         (prs2excpt_rsuf),                    //RS underflow

      //SAGU interface
      .sagu2excpt_psof_i        (sagu2excpt_psof),                   //PS overflow
      .sagu2excpt_rsof_i        (sagu2excpt_rsof),                   //RS overflow

      //Probe signals
      .prb_excpt_o              (prb_excpt_o),                       //exception tracker
      .prb_excpt_en_o           (prb_excpt_en_o),                    //exception enable
      .prb_irq_en_o             (prb_irq_en_o));                     //interrupt enable

   //FC - Flow control
   //-----------------
   N1_fc
   fc
     (//Clock and reset
      .clk_i                    (clk_i),                             //module clock
      .async_rst_i              (async_rst_i),                       //asynchronous reset
      .sync_rst_i               (sync_rst_i),                        //synchronous reset

      //Program bus
      .pbus_cyc_o               (pbus_cyc_o),                        //bus cycle indicator       +-
      .pbus_stb_o               (pbus_stb_o),                        //access request            | initiator to target
      .pbus_ack_i               (pbus_ack_i),                        //bus acknowledge           +-
      .pbus_err_i               (pbus_err_i),                        //error indicator           | target to
      .pbus_rty_i               (pbus_rty_i),                        //retry request             | initiator
      .pbus_stall_i             (pbus_stall_i),                      //access delay              +-

      //Interrupt interface
      .irq_ack_o                (irq_ack_o),                         //interrupt acknowledge

      //DSP interface
      .fc2dsp_pc_hold_o         (fc2dsp_pc_hold),                    //maintain PC
      .fc2dsp_radr_inc_o        (fc2dsp_radr_inc),                   //increment relative address

      //IR interface
      .fc2ir_capture_o          (fc2ir_capture),                     //capture current IR
      .fc2ir_stash_o            (fc2ir_stash),                       //capture stashed IR
      .fc2ir_expend_o           (fc2ir_expend),                      //stashed IR -> current IR
      .fc2ir_force_eow_o        (fc2ir_force_eow),                   //load EOW bit
      .fc2ir_force_0call_o      (fc2ir_force_0call),                 //load 0 CALL instruction
      .fc2ir_force_call_o       (fc2ir_force_call),                  //load CALL instruction
      .fc2ir_force_drop_o       (fc2ir_force_drop),                  //load DROP instruction
      .fc2ir_force_nop_o        (fc2ir_force_nop),                   //load NOP instruction
      .ir2fc_eow_i              (ir2fc_eow),                         //end of word (EOW bit set)
      .ir2fc_eow_postpone_i     (ir2fc_eow_postpone),                //EOW conflict detected
      .ir2fc_jump_or_call_i     (ir2fc_jump_or_call),                //either JUMP or CALL
      .ir2fc_bra_i              (ir2fc_bra),                         //conditonal BRANCH instruction
      .ir2fc_scyc_i             (ir2fc_scyc),                        //linear flow
      .ir2fc_mem_i              (ir2fc_mem),                         //memory I/O
      .ir2fc_mem_rd_i           (ir2fc_mem_rd),                      //memory read
      .ir2fc_madr_sel_i         (ir2fc_madr_sel),                    //direct memory address

      //PAGU interface
      .fc2pagu_prev_adr_hold_o  (fc2pagu_prev_adr_hold),             //maintain stored address
      .fc2pagu_prev_adr_sel_o   (fc2pagu_prev_adr_sel),              //0:AGU output, 1:previous address

      //PRS interface
      .fc2prs_hold_o            (fc2prs_hold),                       //hold any state tran
      .fc2prs_dat2ps0_o         (fc2prs_dat2ps0),                    //capture read data
      .fc2prs_tc2ps0_o          (fc2prs_tc2ps0),                     //capture throw code
      .fc2prs_isr2ps0_o         (fc2prs_isr2ps0),                    //capture ISR
      .prs2fc_hold_i            (prs2fc_hold),                       //stacks not ready
      .prs2fc_ps0_false_i       (prs2fc_ps0_false),                  //PS0 is zero

      //EXCPT interface
      .fc2excpt_excpt_clr_o     (fc2excpt_excpt_clr),                //clear and disable exceptions
      .fc2excpt_irq_dis_o       (fc2excpt_irq_dis),                  //disable interrupts
      .fc2excpt_buserr_o        (fc2excpt_buserr),                   //invalid pbus access
      .excpt2fc_excpt_i         (excpt2fc_excpt),                    //exception to be handled
      .excpt2fc_irq_i           (excpt2fc_irq),                      //exception to be handled

      //Probe signals
      .prb_fc_state_o           (prb_fc_state_o),                    //state variable
      .prb_fc_pbus_acc_o        (prb_fc_pbus_acc_o));                //ongoing bus access

   //IR - Instruction Register and Decoder
   //-------------------------------------
   N1_ir
   ir
     (//Clock and reset
      .clk_i                    (clk_i),                             //module clock
      .async_rst_i              (async_rst_i),                       //asynchronous reset
      .sync_rst_i               (sync_rst_i),                        //synchronous reset

      //Program bus (wishbone)
      .pbus_tga_cof_jmp_o       (pbus_tga_cof_jmp_o),                //COF jump
      .pbus_tga_cof_cal_o       (pbus_tga_cof_cal_o),                //COF call
      .pbus_tga_cof_bra_o       (pbus_tga_cof_bra_o),                //COF conditional branch
      .pbus_tga_cof_eow_o       (pbus_tga_cof_eow_o),                //COF return from call
      .pbus_tga_dat_o           (pbus_tga_dat_o),                    //data access
      .pbus_we_o                (pbus_we_o),                         //write enable
      .pbus_dat_i               (pbus_dat_i),                        //read data bus

      //ALU interface
      .ir2alu_opr_o             (ir2alu_opr),                        //ALU operator
      .ir2alu_opd_o             (ir2alu_opd),                        //immediate operand
      .ir2alu_opd_sel_o         (ir2alu_opd_sel),                    //select immediate operand

      //EXCPT interface
      .ir2excpt_excpt_en_o      (ir2excpt_excpt_en),                 //enable exceptions
      .ir2excpt_excpt_dis_o     (ir2excpt_excpt_dis),                //disable exceptions
      .ir2excpt_irq_en_o        (ir2excpt_irq_en),                   //enable interrupts
      .ir2excpt_irq_dis_o       (ir2excpt_irq_dis),                  //disable interrupts

      //FC interface
      .ir2fc_eow_o              (ir2fc_eow),                         //end of word (EOW bit set)
      .ir2fc_eow_postpone_o     (ir2fc_eow_postpone),                //EOW conflict detected
      .ir2fc_jump_or_call_o     (ir2fc_jump_or_call),                //either JUMP or CALL
      .ir2fc_bra_o              (ir2fc_bra),                         //conditonal BRANCG instruction
      .ir2fc_scyc_o             (ir2fc_scyc),                        //linear flow
      .ir2fc_mem_o              (ir2fc_mem),                         //memory I/O
      .ir2fc_mem_rd_o           (ir2fc_mem_rd),                      //memory read
      .ir2fc_madr_sel_o         (ir2fc_madr_sel),                    //select (indirect) data address
      .fc2ir_capture_i          (fc2ir_capture),                     //capture current IR
      .fc2ir_stash_i            (fc2ir_stash),                       //capture stashed IR
      .fc2ir_expend_i           (fc2ir_expend),                      //stashed IR -> current IR
      .fc2ir_force_eow_i        (fc2ir_force_eow),                   //load EOW bit
      .fc2ir_force_0call_i      (fc2ir_force_0call),                 //load 0 CALL instruction
      .fc2ir_force_call_i       (fc2ir_force_call),                  //load CALL instruction
      .fc2ir_force_drop_i       (fc2ir_force_drop),                  //load DROP instruction
      .fc2ir_force_nop_i        (fc2ir_force_nop),                   //load NOP instruction

      //PAGU interface
      .ir2pagu_eow_o            (ir2pagu_eow),                       //end of word (EOW bit)
      .ir2pagu_eow_postpone_o   (ir2pagu_eow_postpone),              //postpone EOW
      .ir2pagu_jmp_or_cal_o     (ir2pagu_jmp_or_cal),                //jump or call instruction
      .ir2pagu_bra_o            (ir2pagu_bra),                       //conditional branch
      .ir2pagu_scyc_o           (ir2pagu_scyc),                      //single cycle instruction
      .ir2pagu_mem_o            (ir2pagu_mem),                       //memory I/O
      .ir2pagu_aadr_sel_o       (ir2pagu_aadr_sel),                  //select (indirect) absolute address
      .ir2pagu_madr_sel_o       (ir2pagu_madr_sel),                  //select (indirect) memory address
      .ir2pagu_aadr_o           (ir2pagu_aadr),                      //direct absolute address
      .ir2pagu_radr_o           (ir2pagu_radr),                      //direct relative address
      .ir2pagu_madr_o           (ir2pagu_madr),                      //direct memory address

      //PRS interface
      .ir2prs_alu2ps0_o         (ir2prs_alu2ps0),                    //ALU output  -> PS0
      .ir2prs_alu2ps1_o         (ir2prs_alu2ps1),                    //ALU output  -> PS1
      .ir2prs_lit2ps0_o         (ir2prs_lit2ps0),                    //literal     -> PS0
      .ir2prs_pc2rs0_o          (ir2prs_pc2rs0),                     //PC          -> RS0
      .ir2prs_ps_rst_o          (ir2prs_ps_rst),                     //reset parameter stack
      .ir2prs_rs_rst_o          (ir2prs_rs_rst),                     //reset return stack
      .ir2prs_psp_get_o         (ir2prs_psp_get),                    //read parameter stack pointer
      .ir2prs_psp_set_o         (ir2prs_psp_set),                    //write parameter stack pointer
      .ir2prs_rsp_get_o         (ir2prs_rsp_get),                    //read return stack pointer
      .ir2prs_rsp_set_o         (ir2prs_rsp_set),                    //write return stack pointer
      .ir2prs_lit_val_o         (ir2prs_lit_val),                    //literal value
      .ir2prs_us_tp_o           (ir2prs_us_tp),                      //upper stack transition pattern
      .ir2prs_ips_tp_o          (ir2prs_ips_tp),                     //10:push              (), 01:pull
      .ir2prs_irs_tp_o          (ir2prs_irs_tp),                     //10:push              (), 01:pull

      //Probe signals
      .prb_ir_o                 (prb_ir_o),                          //current instruction register
      .prb_ir_stash_o           (prb_ir_stash_o));                   //stashed instruction register

   //PAGU - Program bus address generation unit
   //------------------------------------------
   N1_pagu
     #(.PBUS_AADR_OFFSET (PBUS_AADR_OFFSET),                         //offset for direct program address
       .PBUS_MADR_OFFSET (PBUS_MADR_OFFSET))                         //offset for direct data
   pagu
     (//Clock and reset
      .clk_i                    (clk_i),                             //module clock
      .async_rst_i              (async_rst_i),                       //asynchronous reset
      .sync_rst_i               (sync_rst_i),                        //synchronous reset

      //Program bus (wishbone)
      .pbus_adr_o               (pbus_adr_o),                        //address bus

      //DSP interface
      .pagu2dsp_adr_sel_o       (pagu2dsp_adr_sel),                  //1:absolute COF, 0:relative COF
      .pagu2dsp_radr_o          (pagu2dsp_radr),                     //relative COF address
      .pagu2dsp_aadr_o          (pagu2dsp_aadr),                     //absolute COF address
      .dsp2pagu_adr_i           (dsp2pagu_adr),                      //AGU output

      //FC interface
      .fc2pagu_prev_adr_hold_i  (fc2pagu_prev_adr_hold),             //maintain stored address
      .fc2pagu_prev_adr_sel_i   (fc2pagu_prev_adr_sel),              //0:AGU output, 1:previous address

      //IR interface
      .ir2pagu_eow_i            (ir2pagu_eow),                       //end of word (EOW bit)
      .ir2pagu_eow_postpone_i   (ir2pagu_eow_postpone),              //postpone EOW
      .ir2pagu_jmp_or_cal_i     (ir2pagu_jmp_or_cal),                //jump or call instruction
      .ir2pagu_bra_i            (ir2pagu_bra),                       //conditional branch
      .ir2pagu_scyc_i           (ir2pagu_scyc),                      //single cycle instruction
      .ir2pagu_mem_i            (ir2pagu_mem),                       //memory I/O
      .ir2pagu_aadr_sel_i       (ir2pagu_aadr_sel),                  //select (indirect) absolute address
      .ir2pagu_madr_sel_i       (ir2pagu_madr_sel),                  //select (indirect) data address
      .ir2pagu_aadr_i           (ir2pagu_aadr),                      //direct absolute address
      .ir2pagu_radr_i           (ir2pagu_radr),                      //direct relative address
      .ir2pagu_madr_i           (ir2pagu_madr),                      //direct memory address

      //PRS interface
      .pagu2prs_prev_adr_o      (pagu2prs_prev_adr),                 //address register output
      .prs2pagu_ps0_i           (prs2pagu_ps0),                      //PS0
      .prs2pagu_rs0_i           (prs2pagu_rs0),                      //RS0

      //Probe signals
      .prb_pagu_prev_adr_o      (prb_pagu_prev_adr_o));              //address register


   //PRS - Parameter and return stack
   //--------------------------------
   N1_prs
     #(.SP_WIDTH (SP_WIDTH))                                         //width of either stack pointer
   prs
     (//Clock and reset
      .clk_i                    (clk_i),                             //module clock
      .async_rst_i              (async_rst_i),                       //asynchronous reset
      .sync_rst_i               (sync_rst_i),                        //synchronous reset

      //Program bus (wishbone)
      .pbus_dat_o               (pbus_dat_o),                        //write data bus
      .pbus_dat_i               (pbus_dat_i),                        //read data bus

      //Stack bus (wishbone)
      .sbus_cyc_o               (sbus_cyc_o),                        //bus cycle indicator       +-
      .sbus_stb_o               (sbus_stb_o),                        //access request            | initiator
      .sbus_we_o                (sbus_we_o),                         //write enable              | to
      .sbus_dat_o               (sbus_dat_o),                        //write data bus            | target
      .sbus_ack_i               (sbus_ack_i),                        //bus cycle acknowledge     +-
      .sbus_stall_i             (sbus_stall_i),                      //access delay              | target to initiator
      .sbus_dat_i               (sbus_dat_i),                        //read data bus             +-

      //Interrupt interface
      .irq_req_i                (irq_req_i),                         //requested interrupt vector

      //ALU interface
      .prs2alu_ps0_o            (prs2alu_ps0),                       //current PS0 (TOS)
      .prs2alu_ps1_o            (prs2alu_ps1),                       //current PS1 (TOS+1)
      .alu2prs_ps0_next_i       (alu2prs_ps0_next),                  //new PS0 (TOS)
      .alu2prs_ps1_next_i       (alu2prs_ps1_next),                  //new PS1 (TOS+1)

      //DSP interface
      .dsp2prs_psp_i            (dsp2prs_psp),                       //parameter stack pointer (AGU output)
      .dsp2prs_rsp_i            (dsp2prs_rsp),                       //return stack pointer (AGU output)

      //EXCPT interface
      .prs2excpt_psuf_o         (prs2excpt_psuf),                    //parameter stack underflow
      .prs2excpt_rsuf_o         (prs2excpt_rsuf),                    //return stack underflow
      .excpt2prs_tc_i           (excpt2prs_tc),                      //throw code

      //FC interface
      .prs2fc_hold_o            (prs2fc_hold),                       //stacks not ready
      .prs2fc_ps0_false_o       (prs2fc_ps0_false),                  //PS0 is zero
      .fc2prs_hold_i            (fc2prs_hold),                       //hold any state tran
      .fc2prs_dat2ps0_i         (fc2prs_dat2ps0),                    //capture read data
      .fc2prs_tc2ps0_i          (fc2prs_tc2ps0),                     //capture throw code
      .fc2prs_isr2ps0_i         (fc2prs_isr2ps0),                    //capture ISR

      //IR interface
      .ir2prs_lit_val_i         (ir2prs_lit_val),                    //literal value
      .ir2prs_us_tp_i           (ir2prs_us_tp),                      //upper stack transition pattern
      .ir2prs_ips_tp_i          (ir2prs_ips_tp),                     //10:push, 01:pull
      .ir2prs_irs_tp_i          (ir2prs_irs_tp),                     //10:push, 01:pull
      .ir2prs_alu2ps0_i         (ir2prs_alu2ps0),                    //ALU output  -> PS0
      .ir2prs_alu2ps1_i         (ir2prs_alu2ps1),                    //ALU output  -> PS1
      .ir2prs_lit2ps0_i         (ir2prs_lit2ps0),                    //literal     -> PS0
      .ir2prs_pc2rs0_i          (ir2prs_pc2rs0),                     //PC          -> RS0
      .ir2prs_ps_rst_i          (ir2prs_ps_rst),                     //reset parameter stack
      .ir2prs_rs_rst_i          (ir2prs_rs_rst),                     //reset return stack
      .ir2prs_psp_get_i         (ir2prs_psp_get),                    //read parameter stack pointer
      .ir2prs_psp_set_i         (ir2prs_psp_set),                    //write parameter stack pointer
      .ir2prs_rsp_get_i         (ir2prs_rsp_get),                    //read return stack pointer
      .ir2prs_rsp_set_i         (ir2prs_rsp_set),                    //write return stack pointer

      //PAGU interface
      .prs2pagu_ps0_o           (prs2pagu_ps0),                      //PS0
      .prs2pagu_rs0_o           (prs2pagu_rs0),                      //RS0
      .pagu2prs_prev_adr_i      (pagu2prs_prev_adr),                 //address register output

      //SAGU interface
      .prs2sagu_hold_o          (prs2sagu_hold),                     //maintain stack pointer
      .prs2sagu_psp_rst_o       (prs2sagu_psp_rst),                  //reset PSP
      .prs2sagu_rsp_rst_o       (prs2sagu_rsp_rst),                  //reset RSP
      .prs2sagu_stack_sel_o     (prs2sagu_stack_sel),                //1:RS, 0:PS
      .prs2sagu_push_o          (prs2sagu_push),                     //increment stack pointer
      .prs2sagu_pull_o          (prs2sagu_pull),                     //decrement stack pointer
      .prs2sagu_load_o          (prs2sagu_load),                     //load stack pointer
      .prs2sagu_psp_load_val_o  (prs2sagu_psp_load_val),             //parameter stack load value
      .prs2sagu_rsp_load_val_o  (prs2sagu_rsp_load_val),             //return stack load value

      //Probe signals
      .prb_state_task_o         (prb_state_task_o),                  //current state
      .prb_state_sbus_o         (prb_state_sbus_o),                  //current state
      .prb_rs0_o                (prb_rs0_o),                         //current RS0
      .prb_ps0_o                (prb_ps0_o),                         //current PS0
      .prb_ps1_o                (prb_ps1_o),                         //current PS1
      .prb_ps2_o                (prb_ps2_o),                         //current PS2
      .prb_ps3_o                (prb_ps3_o),                         //current PS3
      .prb_rs0_tag_o            (prb_rs0_tag_o),                     //current RS0 tag
      .prb_ps0_tag_o            (prb_ps0_tag_o),                     //current PS0 tag
      .prb_ps1_tag_o            (prb_ps1_tag_o),                     //current PS1 tag
      .prb_ps2_tag_o            (prb_ps2_tag_o),                     //current PS2 tag
      .prb_ps3_tag_o            (prb_ps3_tag_o),                     //current PS3 tag
      .prb_ips_o                (prb_ips_o),                         //current IPS
      .prb_ips_tags_o           (prb_ips_tags_o),                    //current IPS
      .prb_irs_o                (prb_irs_o),                         //current IRS
      .prb_irs_tags_o           (prb_irs_tags_o));                   //current IRS

   //SAGU - Stack bus address generation unit
   //----------------------------------------
   N1_sagu
     #(.SP_WIDTH   (SP_WIDTH),                                       //width of either stack pointer
       .PS_RS_DIST (PS_RS_DIST))                                     //safety distance between PS and RS
   sagu
     (//Clock and reset
      .clk_i                    (clk_i),                             //module clock
      .async_rst_i              (async_rst_i),                       //asynchronous reset
      .sync_rst_i               (sync_rst_i),                        //synchronous reset

      //Stack bus (wishbone)
      .sbus_adr_o               (sbus_adr_o),                        //address bus
      .sbus_tga_ps_o            (sbus_tga_ps_o),                     //parameter stack access
      .sbus_tga_rs_o            (sbus_tga_rs_o),                     //return stack access

      //DSP interface
      .sagu2dsp_psp_hold_o      (sagu2dsp_psp_hold),                 //maintain PSP
      .sagu2dsp_psp_op_sel_o    (sagu2dsp_psp_op_sel),               //1:set new PSP, 0:add offset to PSP
      .sagu2dsp_psp_offs_o      (sagu2dsp_psp_offs),                 //PSP offset
      .sagu2dsp_psp_load_val_o  (sagu2dsp_psp_load_val),             //new PSP
      .sagu2dsp_rsp_hold_o      (sagu2dsp_rsp_hold),                 //maintain RSP
      .sagu2dsp_rsp_op_sel_o    (sagu2dsp_rsp_op_sel),               //1:set new RSP, 0:add offset to RSP
      .sagu2dsp_rsp_offs_o      (sagu2dsp_rsp_offs),                 //relative address
      .sagu2dsp_rsp_load_val_o  (sagu2dsp_rsp_load_val),             //absolute address
      .dsp2sagu_psp_next_i      (dsp2sagu_psp_next),                 //parameter stack pointer
      .dsp2sagu_rsp_next_i      (dsp2sagu_rsp_next),                 //return stack pointer

      //EXCPT  interface
      .sagu2excpt_psof_o        (sagu2excpt_psof),                   //PS overflow
      .sagu2excpt_rsof_o        (sagu2excpt_rsof),                   //RS overflow

      //PRS interface
      .prs2sagu_hold_i          (prs2sagu_hold),                     //maintain stack pointers
      .prs2sagu_psp_rst_i       (prs2sagu_psp_rst),                  //reset PSP
      .prs2sagu_rsp_rst_i       (prs2sagu_rsp_rst),                  //reset RSP
      .prs2sagu_stack_sel_i     (prs2sagu_stack_sel),                //1:RS, 0:PS
      .prs2sagu_push_i          (prs2sagu_push),                     //increment stack pointer
      .prs2sagu_pull_i          (prs2sagu_pull),                     //decrement stack pointer
      .prs2sagu_load_i          (prs2sagu_load),                     //load stack pointer
      .prs2sagu_psp_load_val_i  (prs2sagu_psp_load_val),             //parameter stack load value
      .prs2sagu_rsp_load_val_i  (prs2sagu_rsp_load_val),             //return stack load value

      //Probe signals
      .prb_sagu_of_o            (prb_sagu_of_o),                     //overflow condition
      .prb_sagu_ps_o            (prb_sagu_ps_o),                     //PS operation
      .prb_sagu_rs_o            (prb_sagu_rs_o));                    //RS operation

endmodule // N1
