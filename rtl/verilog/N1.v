//###############################################################################
//# N1 - Top Level                                                              #
//###############################################################################
//#    Copyright 2018 - 2025 Dirk Heisswolf                                     #
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
//#   May 15, 2025                                                              #
//#      - New implementation                                                   #
//###############################################################################
`default_nettype none

// Supported N1 variants:
//-------------------------------------------------------------------------------
// DEFAULT       - Standard configuration foe evaluation and software development
//-------------------------------------------------------------------------------
// iCE40UP5K_1C  - Single core configuration for ICE40 targets
//-------------------------------------------------------------------------------
module N1
  #(parameter  VARIANT          = "DEFAULT"                            		//machne configuration
    //Core configuration					       		
    localparam ROT_EXTENSION    = VARIANT=="iCE40UP5K_1C" ?        1 : 		//ROT extension
                                  VARIANT=="MINIMAL"      ?        0 :
                                                                   1,  		
    localparam PC_EXTENSION     = VARIANT=="iCE40UP5K_1C" ?        1 : 		//PC extension
                                  VARIANT=="MINIMAL"      ?        0 :
                                                                   1,  		
    localparam INT_EXTENSION    = VARIANT=="iCE40UP5K_1C" ?        1 : 		//interrupt extension
                                  VARIANT=="MINIMAL"      ?        0 :
                                                                   1,  		
    localparam KEY_EXTENSION    = VARIANT=="iCE40UP5K_1C" ?        1 : 		//KEY/EMIT extension
                                  VARIANT=="MINIMAL"      ?        0 :
                                                                   1,  		
    localparam START_ADDR       = VARIANT=="iCE40UP5K_1C" ? 16'h0100 : 		//reset and interrupt start address
                                  VARIANT=="MINIMAL"      ? 16'h0000 :
                                                            16'h0000,  		
    localparam IMM_PADDR_OFFS   = VARIANT=="iCE40UP5K_1C" ? 16'h0000 : 		//offset for immediate program address
                                  VARIANT=="MINIMAL"      ? 16'h0000 :
                                                            16'h0000,  		
    localparam IMM_DADDR_OFFS   = VARIANT=="iCE40UP5K_1C" ? 16'h00ff : 		//offset for immediate data address
                                  VARIANT=="MINIMAL"      ? 16'h00ff :
                                                            16'h00ff,  		 
    localparam IPS_DEPTH        = VARIANT=="iCE40UP5K_1C" ?        4 : 		//depth of the intermediate parameter stack
                                  VARIANT=="MINIMAL"      ?        0 :
                                                                   4,  		
    localparam IRS_DEPTH        = VARIANT=="iCE40UP5K_1C" ?        4 : 		//depth of the intermediate return stack
                                  VARIANT=="MINIMAL"      ?        0 :
                                                                   4,  		
    localparam SBUS_ADDR_WIDTH  = VARIANT=="iCE40UP5K_1C" ?       14 : 		//address width of the stack bus 
                                  VARIANT=="MINIMAL"      ?        8 :
                                                                  14,  		
    //Derived parameters					       		
    localparam PSD_WIDTH        = SBUS_ADDR_WIDTH+1,                   		//width of parameter stack depth register
    localparam RSD_WIDTH        = SBUS_ADDR_WIDTH+1,                   		//width of return stack depth register
    localparam IPS_STACK_WIDTH  = (IPS_DEPTH == 0) ? 16 : 16*IPS_DEPTH,		//width of the IPS cell probes
    localparam IPS_TAG_WIDTH    = (IPS_DEPTH == 0) ?  1 :    IPS_DEPTH,	        //width of the IPS tag probes
    localparam IRS_STACK_WIDTH  = (IRS_DEPTH == 0) ? 16 : 16*IRS_DEPTH,		//width of the IPS cell probes
    localparam IRS_TAG_WIDTH    = (IRS_DEPTH == 0) ?  1 :    IRS_DEPTH)  	//width of the IPS tag probes
   
  
   (//Clock and reset
    input  wire                              clk_i,                   		//module clock
    input  wire                              async_rst_i,             		//asynchronous reset
    input  wire                              sync_rst_i,              		//synchronous reset
								      		
    //Program bus (wishbone)					      		
    input  wire                              pbus_ack_i,              		//bus cycle acknowledge     +-
    input  wire                              pbus_err_i,              		//bus error                 | target to
    input  wire                              pbus_stall_i,            		//access delay              | initiator
    input  wire [15:0]                       pbus_dat_i,              		//read data bus             +-
    output wire                              pbus_cyc_o,              		//bus cycle indicator       +-
    output wire                              pbus_stb_o,              		//access request            |
    output wire                              pbus_we_o,               		//write enable              | initiator
    output wire                              pbus_tga_opc_o,          		//opcode fetch              | to
    output wire                              pbus_tga_dat_o,          		//data access               | target
    output wire [15:0]                       pbus_adr_o,              		//address bus               | 
    output wire [15:0]                       pbus_dat_o,              		//write data bus            +-
								      		
    //Stack bus (wishbone)					      		
    input  wire                              sbus_ack_i,              		//bus cycle acknowledge     +-
    input  wire                              sbus_err_i,              		//bus error                 | target to
    input  wire                              sbus_stall_i,            		//access delay              | initiator
    input  wire [15:0]                       sbus_dat_i,              		//read data bus             +-
    output wire                              sbus_cyc_o,              		//bus cycle indicator       +-
    output wire                              sbus_stb_o,              		//access request            |
    output wire                              sbus_we_o,               		//write enable              | initiator
    output wire                              sbus_tga_ps_o,           		//PS push/pull              | to
    output wire                              sbus_tga_rs_o,           		//RS push/pull              | target
    output wire [SBUS_ADDR_WIDTH:0]          sbus_adr_o,              		//address bus               |
    output wire [15:0]                       sbus_dat_o,              		//write data bus            +-
 								      		
    //Interrupt interface					      		
    input  wire [15:0]                       irq_req_i,               		//requested interrupt vector
    output wire                              irq_ack_o,               		//interrupt acknowledge
								      		
    //I/O interface						      		
    input  wire                              io_push_bsy_i,           		//push request reject
    input  wire                              io_pull_bsy_i,           		//pull request reject
    input  wire [15:0]                       io_pull_data_i,          		//pull data
    output wire                              io_push_o,               		//push request
    output wire                              io_pull_o,               		//pull request
    output wire [15:0]                       io_push_data_o,          		//push request
								      		
    //Probe signals						      		
 								      		
								      		
    output wire [2:0]                        prb_fr_ien_o,            		//FR   - interrupt enable (interrupt extension)
								      		
    output wire [PSD_WIDTH-1:0]              prb_uprs_psd_o,                    //UPRS - probed PSD
    output wire [RSD_WIDTH-1:0]              prb_uprs_rsd_o,                    //UPRS - probed RSD
    output wire [15:0]                       prb_uprs_ps0_o,                    //UPRS - probed PS0
    output wire [15:0]                       prb_uprs_ps1_o,                    //UPRS - probed PS1
    output wire [15:0]                       prb_uprs_ps2_o,                    //UPRS - probed PS2
    output wire [15:0]                       prb_uprs_ps3_o,                    //UPRS - probed PS3
    output wire [15:0]                       prb_uprs_rs0_o);                   //UPRS - probed RS0

    output wire [IPS_STACK_WIDTH-1:0]        prb_ips_cells_o,                   //IPS  - probed cells
    output wire [IPS_TAG_WIDTH-1:0]          prb_ips_tags_o,                    //IPS  - probed tags
  					    		      			       
    output wire [IRS_STACK_WIDTH-1:0]        prb_irs_cells_o,                   //IRS  _ probed cells
    output wire [IRS_TAG_WIDTH-1:0]          prb_irs_tags_o,                    //IRS  _ probed tags
										       
    output wire                              prb_lps_state_o,         		//LPS  - probed FSM state
    output wire [15:0]                       prb_lps_tosbuf_o,        		//LPS  - probed TOS buffer
    output wire [SBUS_ADDR_WIDTH:0]          prb_lps_agu_o,           		//LPS  - probed AGU address output
 										       
    output wire                              prb_lrs_state_o,         		//LRS  - probed FSM state
    output wire [15:0]                       prb_lrs_tosbuf_o,        		//LRS  - probed TOS buffer
    output wire [SBUS_ADDR_WIDTH:0]          prb_lrs_agu_o,           		//LRS  - probed AGU address output
 
   

);


   //Internal interfaces
   //-------------------

   //UPRS
   wire                                      uprs_ps_clear;                     //parameter stack clear request
   wire                                      uprs_rs_clear;                     //return stack clear request
   wire                                      uprs_shift;                        //stack shift request
   wire                                      uprs_imm_2_ps0;                    //immediate value -> PS0
   wire                                      uprs_alu_2_ps0;                    //ALU             -> PS0
   wire                                      uprs_wbi_2_ps0;                    //WBI             -> PS0
   wire                                      uprs_fr_2_ps0;                     //FR              -> PS0
   wire                                      uprs_excpt_2_ps0;                  //exception       -> PS0
   wire                                      uprs_alu_2_ps1;                    //ALU             -> PS1
   wire                                      uprs_pc_2_rs0;                     //PC              -> RS1
   wire                                      uprs_ps3_2_ips;                    //PS3       -> IPS
   wire                                      uprs_ips_2_ps3;                    //IPS       -> PS3
   wire                                      uprs_ps2_2_ps3;                    //PS2       -> PS3
   wire                                      uprs_ps3_2_ps2;                    //PS3       -> PS2
   wire                                      uprs_ps0_2_ps2;                    //PS0       -> PS2 (ROT extension)
   wire                                      uprs_ps1_2_ps2;                    //PS1       -> PS2
   wire                                      uprs_ps2_2_ps1;                    //PS2       -> PS1
   wire                                      uprs_ps0_2_ps1;                    //PS0       -> PS1
   wire                                      uprs_ps1_2_ps0;                    //PS1       -> PS0
   wire                                      uprs_ps2_2_ps0;                    //PS2       -> PS0 (ROT extension)
   wire                                      uprs_rs0_2_ps0;                    //RS0       -> PS0
   wire                                      uprs_ps0_2_rs0;                    //PS0       -> RS0
   wire                                      uprs_irs_2_rs0;                    //IRS       -> RS0
   wire                                      uprs_rs0_2_irs;                    //RS0       -> IRS
   wire                                      uprs_ps_clear_bsy;                 //parameter stack clear busy indicator
   wire                                      uprs_rs_clear_bsy;                 //return stack clear busy indicator
   wire                                      uprs_shift_bsy;                    //stack shift busy indicator
   wire                                      uprs_ps_uf;                        //parameter stack underflow
   wire                                      uprs_ps_of;                        //parameter stack overflow
   wire                                      uprs_rs_uf;                        //return stack underflow
   wire                                      uprs_rs_of;                        //return stack overflow
   wire                                      uprs_ps0_loaded;                   //PS0 contains data
   wire                                      uprs_ps1_loaded;                   //PS1 contains data
   wire                                      uprs_rs0_loaded;                   //RS0 contains data
   wire [15:0]                               uprs_imm_2_ps0_push_data;          //PS0 immediate push data
   wire [15:0]                               uprs_alu_2_ps0_push_data;          //PS0 ALU push data
   wire [15:0]                               uprs_wbi_2_ps0_push_data;          //PS0 WBI push data
   wire [15:0]                               uprs_fr_2_ps0_push_data;           //PS0 FR push data
   wire [15:0]                               uprs_excpt_2_ps0_push_data;        //PS0 exception push data
   wire [15:0]                               uprs_alu_2_ps1_push_data;          //PS1 ALU push data
   wire [15:0]                               uprs_pc_2_rs0_push_data;           //RS0 PC push data
  				             					
   wire [PSD_WIDTH-1:0]                      uprs_psd;                          //parameter stack depths
   wire [RSD_WIDTH-1:0]                      uprs_rsd;                          //return stack depth

   //IPS
   wire                                      ips_clear;                         //clear request
   wire                                      ips_push;                          //push request
   wire                                      ips_pull;                          //pull request
   wire [15:0]                               ips_push_data;                     //push data
   wire                                      ips_clear_bsy;                     //clear busy indicator
   wire                                      ips_push_bsy;                      //push busy indicator
   wire                                      ips_pull_bsy;                      //pull busy indicator
   wire                                      ips_empty;                         //empty indicator
   wire                                      ips_full;                          //overflow indicator
   wire [15:0]                               ips_pull_data;                     //pull data

   //IRS
   wire                                      irs_clear;                         //clear request
   wire                                      irs_push;                          //push request
   wire                                      irs_pull;                          //pull request
   wire [15:0]                               irs_push_data;                     //push data
   wire                                      irs_clear_bsy;                     //clear busy indicator
   wire                                      irs_push_bsy;                      //push busy indicator
   wire                                      irs_pull_bsy;                      //pull busy indicator
   wire                                      irs_empty;                         //empty indicator
   wire                                      irs_full;                          //overflow indicator
   wire [15:0]                               irs_pull_data;                     //pull data

   //LPS
   wire                                      lps_clear;                         //clear request
   wire                                      lps_push;                          //push request
   wire                                      lps_pull;                          //pull request
   wire [15:0]                               lps_push_data;                     //push request
   wire                                      lps_clear_bsy;                     //clear request rejected
   wire                                      lps_push_bsy;                      //push request rejected
   wire                                      lps_pull_bsy;                      //pull request rejected
   wire                                      lps_empty;                         //underflow indicator
   wire                                      lps_full;                          //overflow indicator
   wire [15:0]                               lps_pull_data;                     //pull data

   wire                                      lpsmem_access_bsy;                 //access request rejected
   wire [15:0]                               lpsmem_rdata;                      //read data
   wire                                      lpsmem_rdata_del;                  //read data delay
   wire [SBUS_ADDR_WIDTH-1:0]                lpsmem_addr;                       //address
   wire                                      lpsmem_access;                     //access request
   wire                                      lpsmem_rwb;                        //data direction
   wire [15:0]                               lpsmem_wdata;                      //write data

   wire [SBUS_ADDR_WIDTH-1:0]                lps_tos;                           //points to the TOS

   //LRS
   wire                                      lrs_clear;                         //clear request
   wire                                      lrs_push;                          //push request
   wire                                      lrs_pull;                          //pull request
   wire [15:0]                               lrs_push_data;                     //push request
   wire                                      lrs_clear_bsy;                     //clear request rejected
   wire                                      lrs_push_bsy;                      //push request rejected
   wire                                      lrs_pull_bsy;                      //pull request rejected
   wire                                      lrs_empty;                         //underflow indicator
   wire                                      lrs_full;                          //overflow indicator
   wire [15:0]                               lrs_pull_data;  

   wire                                      lrsmem_access_bsy;                 //access request rejected
   wire [15:0]                               lrsmem_rdata;                      //read data
   wire                                      lrsmem_rdata_del;                  //read data delay
   wire [SBUS_ADDR_WIDTH-1:0]                lrsmem_addr;                       //address
   wire                                      lrsmem_access;                     //access request
   wire                                      lrsmem_rwb;                        //data direction
   wire [15:0]                               lrsmem_wdata;                      //write data

   wire [SBUS_ADDR_WIDTH-1:0]                lrs_tos;                           //points to the TOS
  







   //Function registers
   //------------------
   N1_fr
     #(.INT_EXTENSION 			(INT_EXTENSION),                            //interrupt extension
       .KEY_EXTENSION 			(KEY_EXTENSION),                            //KEY/EMIT extension
       .PSD_WIDTH     			(PSD_WIDTH),                                //width of parameter stack depth register
       .RSD_WIDTH     			(RSD_WIDTH))                                //width of return stack depth register
   fr
     (//Clock and reset
      .clk_i				(clk_i),                                    //module clock
      .async_rst_i			(async_rst_i),                              //asynchronous reset
      .sync_rst_i			(sync_rst_i),                               //synchronous reset
      //Function register interface
      .fr_addr_i			(),                                //address
      .fr_set_i				(),                                 //write request
      .fr_get_i				(),                                 //read request
      .fr_set_data_i			(),                            //write data
      .fr_set_bsy_o			(),                             //write request reject
      .fr_get_bsy_o			(),                             //read request reject
      .fr_get_data_o			(),                            //read data
      //I/O interface
      .io_push_bsy_i			(io_push_bsy_i),                            //push request reject
      .io_pull_bsy_i			(io_pull_bsy_i),                            //pull request reject
      .io_pull_data_i			(io_pull_data_i),                           //pull data
      .io_push_o			(io_push_o),                                //push request
      .io_pull_o			(io_pull_o),                                //pull request
      .io_push_data_o			(io_push_data_o),                           //push data
      //UPRS interface
      .uprs_psd_i			(uprs_psd),                                 //parameter stack depths
      .uprs_rsd_i			(uprs_rsd),                                 //return stack depth
      .uprs_ps_clear_bsy_i		(uprs_ps_clear_bsy),                        //parameter stack clear busy indicator
      .uprs_rs_clear_bsy_i		(uprs_rs_clear_bsy),                        //return stack clear busy indicator
      .uprs_ps_clear_o			(uprs_ps_clear),                            //parameter stack clear request
      .uprs_rs_clear_o			(uprs_rs_clear),                            //return stack clear request
      //PC interface
      .pc_prev_i                        (),                                //previous PC
      //Exception interface
      .excpt_ien_i                      (),                              //interrupts enabled
      .excpt_ien_set_o                  (),                          //interrupts enabled
      .excpt_ien_clear_o                ());                       //interrupts enabled
   

















   //ALU - Arithmetic logic unit
   //---------------------------
   N1_alu alu
     (//IR interface
      .ir2alu_opr_i			(),                                //ALU operator
      .ir2alu_opd_i			(),                                //immediate operand
      //UPRS interface                       
      .uprs_alu_2_ps0_push_data_o	(uprs_alu_2_ps0_push_data),                 //new PS0 (TOS)
      .uprs_alu_2_ps1_push_data_o	(uprs_alu_2_ps1_push_data),                 //new PS1 (TOS+1)
      .uprs_ps0_pull_data_i		(uprs_ps0_pull_data),                       //current PS0 (TOS)
      .uprs_ps1_pull_data_i		(uprs_ps1_pull_data));                      //current PS1 (TOS+1)

   //PC - Program Counter
   //--------------------
   N1_pc
     #(.PC_EXTENSION                    (PC_EXTENSION),                             //program counter extension
       .INT_EXTENSION                   (INT_EXTENSION))                            //interrupt extension
       .IMM_PADDR_OFFS                  (IMM_PADDR_OFFS))                           //offset for immediate program address
   pc
     (//Clock and reset
      .clk_i				(clk_i),                                    //module clock
      .async_rst_i			(async_rst_i),                              //asynchronous reset
      .sync_rst_i			(sync_rst_i),                               //synchronous reset
      //FE interface
      .fe2pc_update_i                   (),               //switch to next address
      //IR interface
      .ir2pc_abs_addr_i                 (),             //absolute address
      .ir2pc_rel_addr_i                 (),             //absolute address
      .ir2pc_call_or_jump_i             (),         //call or jump instruction
      .ir2pc_branch_i                   (),               //branch instruction
      .ir2pc_return_i                   (),               //return
      //UPRS interface
      .uprs_ps0_pull_data_i             (),         //PS0 pull data
      .uprs_rs0_pull_data_i             (),                    //RS0 pull data
      //PC outputs
      .pc_next_o                        (),                    //program AGU output
      .pc_prev_o                        (),                    //previous PC
      //Probe signals
      .prb_pc_cur_o                     (),                 //probed current PC
      .prb_pc_prev_o                    ());               //probed previous PC

   //WBI - Wishbone bus interface
   //----------------------------
   N1_wbi
     #(.ADDR_WIDTH                      (16))                                       //RAM address width
   pbi
     (//Clock and reset
      .clk_i				(clk_i),                                    //module clock
      .async_rst_i			(async_rst_i),                              //asynchronous reset
      .sync_rst_i			(sync_rst_i),                               //synchronous reset
      //High priority memory interface (data bus)
      .hiprio_addr_i			(),                            //address
      .hiprio_access_i			(),                          //access request
      .hiprio_rwb_i			(),                             //data direction
      .hiprio_wdata_i			(),                           //write data
      .hiprio_access_bsy_o		(),                      //access request rejected
      .hiprio_rdata_o			(),                           //read data
      .hiprio_rdata_del_o		(),                       //read data delay
      //Low priority memory interface (instruction bus)
      .loprio_addr_i			(),                            //address
      .loprio_access_i			(),                          //access request
      .loprio_rwb_i			(1'b1),                             //data direction
      .loprio_wdata_i			(),                           //write data
      .loprio_access_bsy_o		(),                      //access request rejected
      .loprio_rdata_o			(),                           //read data
      .loprio_rdata_del_o		(),                       //read data delay
      //Wishbone bus
      .wb_ack_i				(pbus_ack_i),                               //bus cycle acknowledge
      .wb_stall_i			(pbus_stall_i),                             //access delay
      .wb_dat_i				(pbus_dat_i),                               //read data bus
      .wb_cyc_o				(pbus_cyc_o),                               //bus cycle indicator
      .wb_stb_o				(pbus_stb_o),                               //access request
      .wb_we_o				(pbus_we_o),                                //write enable
      .wb_tga_hiprio_o			(pbus_tga_dat_o),                           //access from high prio interface
      .wb_tga_loprio_o			(pbus_tga_opc_o),                           //access from low prio interface
      .wb_adr_o				(pbus_adr_o),                               //address bus
      .wb_dat_o				(pbus_dat_o));                              //write data bus








   
   //UPRS - Upper parameter and return stack
   //---------------------------------------
   N1_uprs
     #(.ROT_EXTENSION                   (ROT_EXTENSION),                            //implement ROT extension
       .PSD_WIDTH                       (PSD_WIDTH),                                //width of parameter stack depth register
       .RSD_WIDTH                       (RSD_WIDTH))                                //width of return stack depth register
   uprs
     (//Clock and reset
      .clk_i                            (clk_i),                                    //module clock
      .async_rst_i                      (async_rst_i),                              //asynchronous reset
      .sync_rst_i                       (sync_rst_i),                               //synchronous reset
      //Upper parameter and return stack interface				    
      .uprs_ps_clear_i                  (uprs_ps_clear),                            //parameter stack clear request
      .uprs_rs_clear_i                  (uprs_rs_clear),                            //return stack clear request
      .uprs_shift_i                     (uprs_shift),                               //stack shift request
      .uprs_imm_2_ps0_i			(uprs_imm_2_ps0),                           //immediate value -> PS0
      .uprs_alu_2_ps0_i			(uprs_alu_2_ps0),                           //ALU             -> PS0
      .uprs_wbi_2_ps0_i			(uprs_wbi_2_ps0),                           //WBI             -> PS0
      .uprs_fr_2_ps0_i			(uprs_fr_2_ps0),                            //FR              -> PS0
      .uprs_excpt_2_ps0_i		(uprs_excpt_2_ps0),                         //exception       -> PS0
      .uprs_alu_2_ps1_i			(uprs_alu_2_ps1),                           //ALU             -> PS1
      .uprs_pc_2_rs0_i			(uprs_pc_2_rs0),                            //PC              -> RS1
      .uprs_ps3_2_ips_i                 (uprs_ps3_2_ips),                           //PS3             -> IPS
      .uprs_ips_2_ps3_i                 (uprs_ips_2_ps3),                           //IPS             -> PS3
      .uprs_ps2_2_ps3_i                 (uprs_ps2_2_ps3),                           //PS2             -> PS3
      .uprs_ps3_2_ps2_i                 (uprs_ps3_2_ps2),                           //PS3             -> PS2
      .uprs_ps0_2_ps2_i                 (uprs_ps0_2_ps2),                           //PS0             -> PS2 (ROT extension)
      .uprs_ps1_2_ps2_i                 (uprs_ps1_2_ps2),                           //PS1             -> PS2
      .uprs_ps2_2_ps1_i                 (uprs_ps2_2_ps1),                           //PS2             -> PS1
      .uprs_ps0_2_ps1_i                 (uprs_ps0_2_ps1),                           //PS0             -> PS1
      .uprs_ps1_2_ps0_i                 (uprs_ps1_2_ps0),                           //PS1             -> PS0
      .uprs_ps2_2_ps0_i                 (uprs_ps2_2_ps0),                           //PS2             -> PS0 (ROT extension)
      .uprs_rs0_2_ps0_i                 (uprs_rs0_2_ps0),                           //RS0             -> PS0
      .uprs_ps0_2_rs0_i                 (uprs_ps0_2_rs0),                           //PS0             -> RS0
      .uprs_irs_2_rs0_i                 (uprs_irs_2_rs0),                           //IRS             -> RS0
      .uprs_rs0_2_irs_i                 (uprs_rs0_2_irs),                           //RS0             -> IRS
      .uprs_imm_2_ps0_push_data_i	(uprs_imm_2_ps0_push_data),                 //PS0 immediate push data
      .uprs_alu_2_ps0_push_data_i	(uprs_alu_2_ps0_push_data),                 //PS0 ALU push data
      .uprs_wbi_2_ps0_push_data_i	(uprs_wbi_2_ps0_push_data),                 //PS0 WBI push data
      .uprs_fr_2_ps0_push_data_i	(uprs_fr_2_ps0_push_data),                  //PS0 FR push data
      .uprs_excpt_2_ps0_push_data_i	(uprs_excpt_2_ps0_push_data),               //PS0 exception push data
      .uprs_alu_2_ps1_push_data_i	(uprs_alu_2_ps1_push_data),                 //PS1 ALU push data
      .uprs_pc_2_rs0_push_data_i	(uprs_pc_2_rs0_push_data),                  //RS0 PC push data
      .uprs_ps_clear_bsy_o              (uprs_ps_clear_bsy),                        //parameter stack clear busy indicator
      .uprs_rs_clear_bsy_o              (uprs_rs_clear_bsy),                        //return stack clear busy indicator
      .uprs_shift_bsy_o                 (uprs_shift_bsy),                           //stack shift busy indicator
      .uprs_ps_uf_o                     (uprs_ps_uf),                               //parameter stack underflow
      .uprs_ps_of_o                     (uprs_ps_of),                               //parameter stack overflow
      .uprs_rs_uf_o                     (uprs_rs_uf),                               //return stack underflow
      .uprs_rs_of_o                     (uprs_rs_of),                               //return stack overflow
      .uprs_ps0_loaded_o                (uprs_ps0_loaded),                          //PS0 contains data
      .uprs_ps1_loaded_o                (uprs_ps1_loaded),                          //PS1 contains data
      .uprs_rs0_loaded_o                (uprs_rs0_loaded),                          //RS0 contains data
      .uprs_ps0_pull_data_o             (uprs_ps0_pull_data),                       //PS0 pull data
      .uprs_ps1_pull_data_o             (uprs_ps1_pull_data),                       //PS1 pull data
      .uprs_rs0_pull_data_o             (uprs_rs0_pull_data),                       //RS0 pull data
      //Stack depths								    
      .psd_o                            (uprs_psd),                                 //parameter stack depths
      .rsd_o                            (uprs_rsd),                                 //return stack depth
      //IPS interface
      .ips_clear_bsy_i                  (ips_clear_bsy),                            //IPS clear busy indicator
      .ips_push_bsy_i                   (ips_push_bsy),                             //IPS push busy indicator
      .ips_pull_bsy_i                   (ips_pull_bsy),                             //IPS pull busy indicator
      .ips_empty_i                      (ips_empty),                                //IPS empty indicator
      .ips_full_i                       (ips_full),                                 //IPS overflow indicator
      .ips_pull_data_i                  (ips_pull_data),                            //IPS pull data
      .ips_clear_o                      (ips_clear),                                //IPS clear request
      .ips_push_o                       (ips_push),                                 //IPS push request
      .ips_pull_o                       (ips_pull),                                 //IPS pull request
      .ips_push_data_o                  (ips_push_data),                            //IPS push data
      //IRS interface 								    
      .irs_clear_bsy_i                  (irs_clear_bsy),                            //IRS clear busy indicator
      .irs_push_bsy_i                   (irs_push_bsy),                             //IRS push busy indicator
      .irs_pull_bsy_i                   (irs_pull_bsy),                             //IRS pull busy indicator
      .irs_empty_i                      (irs_empty),                                //IRS empty indicator
      .irs_full_i                       (irs_full),                                 //IRS overflow indicator
      .irs_pull_data_i                  (irs_pull_data),                            //IRS pull data
      .irs_clear_o                      (irs_clear),                                //IRS clear request
      .irs_push_o                       (irs_push),                                 //IRS push request
      .irs_pull_o                       (irs_pull),                                 //IRS pull request
      .irs_push_data_o                  (irs_push_data),                            //IRS push data
      //Probe signals   							    
      .prb_uprs_psd_o                   (prb_uprs_psd_o),                           //probed PSD
      .prb_uprs_rsd_o                   (prb_uprs_rsd_o),                           //probed RSD
      .prb_uprs_ps0_o                   (prb_uprs_ps0_o),                           //probed PS0
      .prb_uprs_ps1_o                   (prb_uprs_ps1_o),                           //probed PS1
      .prb_uprs_ps2_o                   (prb_uprs_ps2_o),                           //probed PS2
      .prb_uprs_ps3_o                   (prb_uprs_ps3_o),                           //probed PS3
      .prb_uprs_rs0_o                   (prb_uprs_rs0_o));                          //probed RS0

   //IPS - Intermediate parameter stack
   //----------------------------------
   N1_is
     #(.DEPTH                           (IPS_DEPTH))                                //depth of the IPS
   ips
     (//Clock and reset
      .clk_i                            (clk_i),                                    //module clock
      .async_rst_i                      (async_rst_i),                              //asynchronous reset
      .sync_rst_i                       (sync_rst_i),                               //synchronous reset
      //Interface to upper stack
      .is_clear_i			(ips_clear),                                //IPS clear request
      .is_push_i			(ips_push),                                 //IPS push request
      .is_pull_i			(ips_pull),                                 //IPS pull request
      .is_push_data_i			(ips_push_data),                            //IPS push data
      .is_clear_bsy_o			(ips_clear_bsy),                            //IPS clear busy indicator
      .is_push_bsy_o			(ips_push_bsy),                             //IPS push busy indicator
      .is_pull_bsy_o			(ips_pull_bsy),                             //IPS pull busy indicator
      .is_empty_o			(ips_empty),                                //IPS empty indicator
      .is_full_o			(ips_full),                                 //IPS overflow indicator
      .is_pull_data_o			(ips_pull_data),                            //IPS pull data
      //Interface to lower stack
      .ls_clear_bsy_i			(lps_clear_bsy),                            //LPS clear busy indicator
      .ls_push_bsy_i			(lps_push_bsy),                             //LPS push busy indicator
      .ls_pull_bsy_i			(lps_pull_bsy),                             //LPS pull busy indicator
      .ls_empty_i			(lps_empty),                                //LPS empty indicator
      .ls_full_i			(lps_full),                                 //LPS overflow indicator
      .ls_pull_data_i			(lps_pull_data),                            //LPS pull data
      .ls_clear_o			(lps_clear),                                //LPS clear request
      .ls_push_o			(lps_push),                                 //LPS push request
      .ls_pull_o			(lps_pull),                                 //LPS pull request
      .ls_push_data_o			(lps_push_data),                            //LPS push data
      //Probe signals
      .prb_is_cells_o                   (prb_ips_cells_o),                          //probed cells
      .prb_is_tags_o                    (prb_ips_tags_o));                          //probed tags

   //IRS - Intermediate return stack
   //-------------------------------
   N1_is
     #(.DEPTH                           (IRS_DEPTH))                                //depth of the IRS
   irs
     (//Clock and reset
      .clk_i                            (clk_i),                                    //module clock
      .async_rst_i                      (async_rst_i),                              //asynchronous reset
      .sync_rst_i                       (sync_rst_i),                               //synchronous reset
      //Interface to upper stack
      .is_clear_i			(irs_clear),                                //IRS clear request
      .is_push_i			(irs_push),                                 //IRS push request
      .is_pull_i			(irs_pull),                                 //IRS pull request
      .is_push_data_i			(irs_push_data),                            //IRS push data
      .is_clear_bsy_o			(irs_clear_bsy),                            //IRS clear busy indicator
      .is_push_bsy_o			(irs_push_bsy),                             //IRS push busy indicator
      .is_pull_bsy_o			(irs_pull_bsy),                             //IRS pull busy indicator
      .is_empty_o			(irs_empty),                                //IRS empty indicator
      .is_full_o			(irs_full),                                 //IRS overflow indicator
      .is_pull_data_o			(irs_pull_data),                            //IRS pull data
      //Interface to lower stack
      .ls_clear_bsy_i			(lrs_clear_bsy),                            //LRS clear busy indicator
      .ls_push_bsy_i			(lrs_push_bsy),                             //LRS push busy indicator
      .ls_pull_bsy_i			(lrs_pull_bsy),                             //LRS pull busy indicator
      .ls_empty_i			(lrs_empty),                                //LRS empty indicator
      .ls_full_i			(lrs_full),                                 //LRS overflow indicator
      .ls_pull_data_i			(lrs_pull_data),                            //LRS pull data
      .ls_clear_o			(lrs_clear),                                //LRS clear request
      .ls_push_o			(lrs_push),                                 //LRS push request
      .ls_pull_o			(lrs_pull),                                 //LRS pull request
      .ls_push_data_o			(lrs_push_data),                            //LRS push data
      //Probe signals
      .prb_is_cells_o                   (prb_irs_cells_o),                          //probed cells
      .prb_is_tags_o                    (prb_irs_tags_o));                          //probed tags

   //LPS - Lower parameter stack
   //---------------------------
   N1_ls
    #(.ADDR_WIDTH                       (SBUS_ADDR_WIDTH),                          //address width of the memory
      .STACK_DIRECTION                  (1))                                        //1:grow stack upward, 0:grow stack downward
   lps										    
    (//Clock and reset								    
     .clk_i                             (clk_i),                                    //module clock
     .async_rst_i                       (async_rst_i),                              //asynchronous reset
     .sync_rst_i                        (sync_rst_i),                               //synchronous reset
     //Stack interface                  					    
     .ls_clear_i                        (lps_clear),                                //clear request
     .ls_push_i                         (lps_push),                                 //push request
     .ls_pull_i                         (lps_pull),                                 //pull request
     .ls_push_data_i                    (lps_push_data),                            //push request
     .ls_clear_bsy_o                    (lps_clear_bsy),                            //clear request rejected
     .ls_push_bsy_o                     (lps_push_bsy),                             //push request rejected
     .ls_pull_bsy_o                     (lps_pull_bsy),                             //pull request rejected
     .ls_empty_o                        (lps_empty),                                //underflow indicator
     .ls_full_o                         (lps_full),                                 //overflow indicator
     .ls_pull_data_o                    (lps_pull_data),                            //pull data
     //Memory interface                 					    
     .mem_access_bsy_i                  (lpsmem_access_bsy),                        //access request rejected
     .mem_rdata_i                       (lpsmem_rdata),                             //read data
     .mem_rdata_del_i                   (lrsmem_rdata_del),                         //read data delay
     .mem_addr_o                        (lpsmem_addr),                              //address
     .mem_access_o                      (lpsmem_access),                            //access request
     .mem_rwb_o                         (lpsmem_rwb),                               //data direction
     .mem_wdata_o                       (lpsmem_wdata),                             //write data
     //Dynamic stack ranges             					    
     .ls_tos_limit_i                    (lrs_tos),                                  //address, which the LS must not reach
     .ls_tos_o                          (lps_tos),                                  //points to the TOS
     //Probe signals                    					    
     .prb_ls_state_o                    (prb_lps_state_o),                          //probed FSM state
     .prb_ls_tosbuf_o                   (prb_lps_tosbuf_o),                         //TOS buffer
     .prb_ls_agu_o                      (prb_lps_agu_o));                           //probed AGU address output
        									    
   //LRS - Lower return stack							    
   //------------------------							    
   N1_ls									    
    #(.ADDR_WIDTH                       (SBUS_ADDR_WIDTH),                          //address width of the memory
      .STACK_DIRECTION                  (0))                                        //1:grow stack upward, 0:grow stack downward
   lrs										    
    (//Clock and reset								    
     .clk_i                             (clk_i),                                    //module clock
     .async_rst_i                       (async_rst_i),                              //asynchronous reset
     .sync_rst_i                        (sync_rst_i),                               //synchronous reset
     //Stack interface                  					    
     .ls_clear_i                        (lrs_clear),                                //clear request
     .ls_push_i                         (lrs_push),                                 //push request
     .ls_pull_i                         (lrs_pull),                                 //pull request
     .ls_push_data_i                    (lrs_push_data),                            //push request
     .ls_clear_bsy_o                    (lrs_clear_bsy),                            //clear request rejected
     .ls_push_bsy_o                     (lrs_push_bsy),                             //push request rejected
     .ls_pull_bsy_o                     (lrs_pull_bsy),                             //pull request rejected
     .ls_empty_o                        (lrs_empty),                                //underflow indicator
     .ls_full_o                         (lrs_full),                                 //overflow indicator
     .ls_pull_data_o                    (lrs_pull_data),                            //pull data
     //Memory interface                 					    
     .mem_access_bsy_i                  (lrsmem_access_bsy),                        //access request rejected
     .mem_rdata_i                       (lrsmem_rdata),                             //read data
     .mem_rdata_del_i                   (lrsmem_rdata_del),                         //read data delay
     .mem_addr_o                        (lrsmem_addr),                              //address
     .mem_access_o                      (lrsmem_access),                            //access request
     .mem_rwb_o                         (lrsmem_rwb),                               //data direction
     .mem_wdata_o                       (lrsmem_wdata),                             //write data
     //Dynamic stack ranges             					    
     .ls_tos_limit_i                    (lps_tos),                                  //address, which the LS must not reach
     .ls_tos_o                          (lrs_tos),                                  //points to the TOS
     //Probe signals                    
     .prb_ls_state_o                    (prb_lrs_state_o),                          //probed FSM state
     .prb_ls_tosbuf_o                   (prb_lrs_tosbuf_o),                         //TOS buffer
     .prb_ls_agu_o                      (prb_lrs_agu_o));                           //probed AGU address output
 
   //SBI - Stack bus interface
   N1_wbi
     #(.ADDR_WIDTH                      (SBUS_ADDR_WIDTH))                                       //RAM address width
   sbi
     (//Clock and reset
      .clk_i				(clk_i),                                    //module clock
      .async_rst_i			(async_rst_i),                              //asynchronous reset
      .sync_rst_i			(sync_rst_i),                               //synchronous reset
      //High priority memory interface (parameter stack)
      .hiprio_addr_i			(lpsmem_addr),                              //address
      .hiprio_access_i			(lpsmem_access),                            //access request
      .hiprio_rwb_i			(lpsmem_rwb),                               //data direction
      .hiprio_wdata_i			(lpsmem_wdata),                             //write data
      .hiprio_access_bsy_o		(lpsmem_access_bsy),                        //access request rejected
      .hiprio_rdata_o			(lpsmem_rdata),                             //read data
      .hiprio_rdata_del_o		(lrsmem_rdata_del),                         //read data delay
      //Low priority memory interface (return stack)				    
      .loprio_addr_i			(lrsmem_addr),                              //address
      .loprio_access_i			(lrsmem_access),                            //access request
      .loprio_rwb_i			(lrsmem_rwb),                               //data direction
      .loprio_wdata_i			(lrsmem_wdata),                             //write data
      .loprio_access_bsy_o		(lrsmem_access_bsy),                        //access request rejected
      .loprio_rdata_o			(lrsmem_rdata),                             //read data
      .loprio_rdata_del_o		(lrsmem_rdata_del),                         //read data delay
      //Wishbone bus
      .wb_ack_i				(sbus_ack_i),                               //bus cycle acknowledge
      .wb_stall_i			(sbus_stall_i),                             //access delay
      .wb_dat_i				(sbus_dat_i),                               //read data bus
      .wb_cyc_o				(sbus_cyc_o),                               //bus cycle indicator
      .wb_stb_o				(sbus_stb_o),                               //access request
      .wb_we_o				(sbus_we_o),                                //write enable
      .wb_tga_hiprio_o			(sbus_tga_ps_o),                            //access from high prio interface
      .wb_tga_loprio_o			(sbus_tga_ls_o),                            //access from low prio interface
      .wb_adr_o				(sbus_adr_o),                               //address bus
      .wb_dat_o				(sbus_dat_o));                              //write data bus





















   
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
   //DSP -> LS
   wire                                     dsp2ls_overflow,         //stacks overlap
   wire                                     dsp2ls_sp_carry,         //carry of inc/dec operation
   wire [SP_WIDTH-1:0]                      dsp2ls_sp_next,          //next PSP or RSP

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
   wire                                     fc2pagu_prev_adr_hold;   //maintain stored address
   wire                                     fc2pagu_prev_adr_sel;    //0:AGU output, 1:previous address
   //FC -> PRS
   wire                                     fc2prs_hold;             //hold any state tran
   wire                                     fc2prs_dat2ps0;          //capture read data
   wire                                     fc2prs_tc2ps0;           //capture throw code
   wire                                     fc2prs_isr2ps0;          //capture ISR

   //IPS - Intermediate parameter stack
   //IPS -> LS
   wire                                     ips2ls_push;             //push cell from IS to LS
   wire                                     ips2ls_pull;             //pull cell from IS to LS
   wire                                     ips2ls_set;              //set SP
   wire                                     ips2ls_get;              //get SP
   wire                                     ips2ls_reset;            //reset SP
   wire [15:0]                              ips2ls_push_data;        //LS push data
   //IPS -> US   		            
   wire                                     ips2us_ready;            //IS is ready for the next command
   wire                                     ips2us_overflow;         //LS+IS are full or overflowing
   wire                                     ips2us_underflow;        //LS+IS are empty
   wire [15:0]                              ips2us_pull_data;        //IS pull data
   
   //IR - Instruction register and decoder
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

   //IPS - Intermediate return stack
   //IRS -> LS
   wire                                     irs2ls_push;             //push cell from IS to LS
   wire                                     irs2ls_pull;             //pull cell from IS to LS
   wire                                     irs2ls_set;              //set SP
   wire                                     irs2ls_get;              //get SP
   wire                                     irs2ls_reset;            //reset SP
   wire [15:0]                              irs2ls_push_data;        //LS push data
   //IRS -> US   		            
   wire                                     irs2us_ready;            //IS is ready for the next command
   wire                                     irs2us_overflow;         //LS+IS are full or overflowing
   wire                                     irs2us_underflow;        //LS+IS are empty
   wire [15:0]                              irs2us_pull_data;        //IS pull data

   //LS - Lower stack
   //LS -> IPS
   wire                                     ls2ips_ready;            //LS is ready for the next command
   wire                                     ls2ips_overflow;         //LS is full or overflowing
   wire                                     ls2ips_underflow;        //LS empty
   wire [15:0]                              ls2ips_pull_data;        //LS pull data
   //LS -> IRS
   wire                                     ls2irs_ready;            //LS is ready for the next command
   wire                                     ls2irs_overflow;         //LS is full or overflowing
   wire                                     ls2irs_underflow;        //LS empty
   wire [15:0]                              ls2irs_pull_data;        //LS pull data
      
   //PAGU - Program bus address generation unit
   //PAGU -> DSP
   wire                                     pagu2dsp_adr_sel;        //1:absolute COF, 0:relative COF
   wire [15:0]                              pagu2dsp_aadr;           //absolute COF address
   wire [15:0]                              pagu2dsp_radr;           //relative COF address
   //PAGU -> PRS
   wire [15:0]                              pagu2prs_prev_adr;       //address register output

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

   //US - Upper stack
   //US -> IPS
   wire                                     us2ips_push;             //push cell from US to IS
   wire                                     us2ips_pull;             //pull cell from US to IS
   wire                                     us2ips_set;              //set SP
   wire                                     us2ips_get;              //get SP
   wire                                     us2ips_reset;            //reset SP
   wire [15:0]                              us2ips_push_data;        //IS push data
   //US -> IRS
   wire                                     us2irs_push;             //push cell from US to IS
   wire                                     us2irs_pull;             //pull cell from US to IS
   wire                                     us2irs_set;              //set SP
   wire                                     us2irs_get;              //get SP
   wire                                     us2irs_reset;            //reset SP
   wire [15:0]                              us2irs_push_data;        //IS push data
   
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

      //LS interface
      .dsp2ls_overflow_o	(dsp2ls_overflow),                   //stacks overlap
      .dsp2ls_sp_carry_o	(dsp2ls_sp_carry),                   //carry of inc/dec operation
      .dsp2ls_sp_next_o		(dsp2ls_sp_next),                    //next PSP or RSP
      .ls2dsp_sp_opr_i		(ls2dsp_sp_opr),                     //0:inc, 1:dec
      .ls2dsp_sp_sel_i		(ls2dsp_sp_sel),                     //0:PSP, 1:RSP
      .ls2dsp_psp_i		(ls2dsp_psp),                        //PSP
      .ls2dsp_rsp_i		(ls2dsp_rsp),                        //RSP

      //PAGU interface
      .dsp2pagu_adr_o           (dsp2pagu_adr),                      //program AGU output
      .pagu2dsp_adr_sel_i       (pagu2dsp_adr_sel),                  //1:absolute COF, 0:relative COF
      .pagu2dsp_aadr_i          (pagu2dsp_aadr),                     //absolute COF address
      .pagu2dsp_radr_i          (pagu2dsp_radr),                     //relative COF address

      //Probe signals
      .prb_dsp_pc_o             (prb_dsp_pc_o));                     //PC

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

   //IPS - Intermediate parameter stack
   //----------------------------------
   N1_is
     #(.IS_DEPTH  (IPS_DEPTH),                                       //depth of the IS (must be >=2)
       .IS_BYPASS (IPS_BYPASS))                                      //conncet the LS directly to the US
   ips
   (//Clock and reset
    .clk_i			(clk_i),                             //module clock
    .async_rst_i		(async_rst_i),                       //asynchronous reset
    .sync_rst_i			(sync_rst_i),                        //synchronous reset
    
    //LS interface
    .is2ls_push_o		(ips2ls_push),                       //push cell from IS to LS
    .is2ls_pull_o		(ips2ls_pull),                       //pull cell from IS to LS
    .is2ls_set_o		(ips2ls_set),                        //set SP
    .is2ls_get_o		(ips2ls_get),                        //get SP
    .is2ls_reset_o		(ips2ls_reset),                      //reset SP
    .is2ls_push_data_o		(ips2ls_push_data),                  //LS push data
    .ls2is_ready_i		(ls2ips_ready),                      //LS is ready for the next command
    .ls2is_overflow_i		(ls2ips_overflow),                   //LS is full or overflowing
    .ls2is_underflow_i		(ls2ips_underflow),                  //LS empty
    .ls2is_pull_data_i		(ls2ips_pull_data),                  //LS pull data
		
    //US interface
    .is2us_ready_o		(ips2us_ready),                      //IS is ready for the next command
    .is2us_overflow_o		(ips2us_overflow),                   //LS+IS are full or overflowing
    .is2us_underflow_o		(ips2us_underflow),                  //LS+IS are empty
    .is2us_pull_data_o		(ips2us_pull_data),                  //IS pull data
    .us2is_push_i		(us2ips_push),                       //push cell from US to IS
    .us2is_pull_i		(us2ips_pull),                       //pull cell from US to IS
    .us2is_set_i		(us2ips_set),                        //set SP
    .us2is_get_i		(us2ips_get),                        //get SP
    .us2is_reset_i		(us2ips_reset),                      //reset SP
    .us2is_push_data_i		(us2ips_push_data),                  //IS push data
		
    //Probe signals	
    .prb_ips_cells_o		(prb_ips_cells),                     //current IS cells
    .prb_ips_tags_o		(prb_ips_tags),                      //current IS tags
    .prb_ips_state_o		(prb_ips_state));                    //current state
   
   //IR - Instruction register and decoder
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




































   
endmodule // N1
