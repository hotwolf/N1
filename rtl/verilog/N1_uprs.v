//###############################################################################
//# N1 - Upper Parameter and Return Stack                                       #
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
//#    This module implements the upper stacks of the N1 processor. The upper   #
//#    stacks contain the top most cells of the partameter and the return       #
//#    stack. They provide direct access to their cells and are capable of      #
//#    performing stack operations.                                             #
//#                                                                             #
//#  Imm.  |                  Upper Stack                   |    Upper   | Imm. #
//#  Stack |                                                |    Stack   | St.  #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#      |<->|  PS3  |<=>|  PS2  |<=>|  PS1  |<=>|  PS0  |<===>|  RS0  |<->|    #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#                                                 TOS     |     TOS           #
//#                          Parameter Stack                | Return Stack      #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   September 25, 2019                                                        #
//#      - Initial release                                                      #
//#   February 5, 2024                                                          #
//#      - New implementation                                                   #
//#   May 4, 2025                                                               #
//#      - New implementation                                                   #
//###############################################################################
`default_nettype none

module N1_uprs
  #(parameter  ROT_EXTENSION =  1,                                               //implement ROT extension
    parameter  PSD_WIDTH     = 15,                                               //width of parameter stack depth register
    parameter  RSD_WIDTH     = 15,                                               //width of return stack depth register
    localparam PROBE_WIDTH   = PSD_WIDTH + RSD_WIDTH + 80)                       //width of the concatinated probe output

   (//Clock and reset
    input  wire                         clk_i,                                   //module clock
    input  wire                         async_rst_i,                             //asynchronous reset
    input  wire                         sync_rst_i,                              //synchronous reset

    //Upper parameter and return stack interface
    input  wire                         uprs_ps_clear_i,                         //parameter stack clear request
    input  wire                         uprs_rs_clear_i,                         //return stack clear request
    input  wire                         uprs_shift_i,                            //stack shift request
    input  wire                         uprs_imm_2_ps0_i,                        //immediate value -> PS0
    input  wire                         uprs_alu_2_ps0_i,                        //ALU             -> PS0
    input  wire                         uprs_wbi_2_ps0_i,                        //WBI             -> PS0
    input  wire                         uprs_fr_2_ps0_i,                         //FR              -> PS0
    input  wire                         uprs_excpt_2_ps0_i,                      //exception       -> PS0
    input  wire                         uprs_alu_2_ps1_i,                        //ALU             -> PS1
    input  wire                         uprs_pc_2_rs0_i,                         //PC              -> RS1
    input  wire                         uprs_ps3_2_ips_i,                        //PS3             -> IPS
    input  wire                         uprs_ips_2_ps3_i,                        //IPS             -> PS3
    input  wire                         uprs_ps2_2_ps3_i,                        //PS2             -> PS3
    input  wire                         uprs_ps3_2_ps2_i,                        //PS3             -> PS2
    input  wire                         uprs_ps0_2_ps2_i,                        //PS0             -> PS2 (ROT extension)
    input  wire                         uprs_ps1_2_ps2_i,                        //PS1             -> PS2
    input  wire                         uprs_ps2_2_ps1_i,                        //PS2             -> PS1
    input  wire                         uprs_ps0_2_ps1_i,                        //PS0             -> PS1
    input  wire                         uprs_ps1_2_ps0_i,                        //PS1             -> PS0
    input  wire                         uprs_ps2_2_ps0_i,                        //PS2             -> PS0 (ROT extension)
    input  wire                         uprs_rs0_2_ps0_i,                        //RS0             -> PS0
    input  wire                         uprs_ps0_2_rs0_i,                        //PS0             -> RS0
    input  wire                         uprs_irs_2_rs0_i,                        //IRS             -> RS0
    input  wire                         uprs_rs0_2_irs_i,                        //RS0             -> IRS
    input  wire [15:0]                  uprs_imm_2_ps0_push_data_i,              //PS0 immediate push data
    input  wire [15:0]                  uprs_alu_2_ps0_push_data_i,              //PS0 ALU push data
    input  wire [15:0]                  uprs_wbi_2_ps0_push_data_i,              //PS0 WBI push data
    input  wire [15:0]                  uprs_fr_2_ps0_push_data_i,               //PS0 FR push data
    input  wire [15:0]                  uprs_excpt_2_ps0_push_data_i,            //PS0 exception push data
    input  wire [15:0]                  uprs_alu_2_ps1_push_data_i,              //PS1 ALU push data
    input  wire [15:0]                  uprs_pc_2_rs0_push_data_i,               //RS0 PC push data
    output wire                         uprs_ps_clear_bsy_o,                     //parameter stack clear busy indicator
    output wire                         uprs_rs_clear_bsy_o,                     //return stack clear busy indicator
    output wire                         uprs_shift_bsy_o,                        //stack shift busy indicator
    output wire                         uprs_ps_uf_o,                            //parameter stack underflow
    output wire                         uprs_ps_of_o,                            //parameter stack overflow
    output wire                         uprs_rs_uf_o,                            //return stack underflow
    output wire                         uprs_rs_of_o,                            //return stack overflow
    output wire                         uprs_ps0_loaded_o,                       //PS0 contains data
    output wire                         uprs_ps1_loaded_o,                       //PS1 contains data
    output wire                         uprs_rs0_loaded_o,                       //RS0 contains data
    output wire [15:0]                  uprs_ps0_pull_data_o,                    //PS0 pull data
    output wire [15:0]                  uprs_ps1_pull_data_o,                    //PS1 pull data
    output wire [15:0]                  uprs_rs0_pull_data_o,                    //RS0 pull data

    //Stack depths
    output wire [PSD_WIDTH-1:0]         uprs_psd_o,                              //parameter stack depths
    output wire [RSD_WIDTH-1:0]         uprs_rsd_o,                              //return stack depth

    //IPS interface
    input  wire                         ips_clear_bsy_i,                         //IPS clear busy indicator
    input  wire                         ips_push_bsy_i,                          //IPS push busy indicator
    input  wire                         ips_pull_bsy_i,                          //IPS pull busy indicator
    input  wire                         ips_empty_i,                             //IPS empty indicator
    input  wire                         ips_full_i,                              //IPS overflow indicator
    input  wire [15:0]                  ips_pull_data_i,                         //IPS pull data
    output wire                         ips_clear_o,                             //IPS clear request
    output wire                         ips_push_o,                              //IPS push request
    output wire                         ips_pull_o,                              //IPS pull request
    output wire [15:0]                  ips_push_data_o,                         //IPS push data

    //IRS interface
    input  wire                         irs_clear_bsy_i,                         //IRS clear busy indicator
    input  wire                         irs_push_bsy_i,                          //IRS push busy indicator
    input  wire                         irs_pull_bsy_i,                          //IRS pull busy indicator
    input  wire                         irs_empty_i,                             //IRS empty indicator
    input  wire                         irs_full_i,                              //IRS overflow indicator
    input  wire [15:0]                  irs_pull_data_i,                         //IRS pull data
    output wire                         irs_clear_o,                             //IRS clear request
    output wire                         irs_push_o,                              //IRS push request
    output wire                         irs_pull_o,                              //IRS pull request
    output wire [15:0]                  irs_push_data_o,                         //IRS push data

    //Probe signals
    output wire [PSD_WIDTH-1:0]         prb_uprs_psd_o,                          //probed PSD
    output wire [RSD_WIDTH-1:0]         prb_uprs_rsd_o,                          //probed RSD
    output wire [15:0]                  prb_uprs_ps0_o,                          //probed PS0
    output wire [15:0]                  prb_uprs_ps1_o,                          //probed PS1
    output wire [15:0]                  prb_uprs_ps2_o,                          //probed PS2
    output wire [15:0]                  prb_uprs_ps3_o,                          //probed PS3
    output wire [15:0]                  prb_uprs_rs0_o);                         //probed RS0

   //Registers
   //---------
   //PS depth
   reg  [PSD_WIDTH-1:0]                 psd_reg;                                 //current PS depth
   wire [PSD_WIDTH-1:0]                 psd_next;                                //next PS depth
   wire                                 psd_we;                                  //PS depth write enable

   //RS depth
   reg  [RSD_WIDTH-1:0]                 rsd_reg;                                 //current RS depth
   wire [RSD_WIDTH-1:0]                 rsd_next;                                //next RS depth
   wire                                 rsd_we;                                  //RS depth write enable

   //P0
   reg  [15:0]                          ps0_reg;                                 //current P0 cell value
   wire [15:0]                          ps0_next;                                //next p0 cell value
   wire                                 ps0_we;                                  //P0 write enable

   //P1
   reg  [15:0]                          ps1_reg;                                 //current P1 cell value
   wire [15:0]                          ps1_next;                                //next P1 cell value
   wire                                 ps1_we;                                  //P1 write enable

   //P2
   reg  [15:0]                          ps2_reg;                                 //current P2 cell value
   wire [15:0]                          ps2_next;                                //next p2 cell value
   wire                                 ps2_we;                                  //P2 write enable

   //P3
   reg  [15:0]                          ps3_reg;                                 //current P3 cell value
   wire [15:0]                          ps3_next;                                //next P3 cell value
   wire                                 ps3_we;                                  //P3 write enable

   //R0
   reg  [15:0]                          rs0_reg;                                 //current R0 cell value
   wire [15:0]                          rs0_next;                                //next R0 cell value
   wire                                 rs0_we;                                  //R0 write enable

   //Internal signals
   //-----------------
   //Push data mux
   wire                                 uprs_dat_2_ps0;                          //push data -> PS0
   wire                                 uprs_dat_2_ps1;                          //push data -> PS1
   wire                                 uprs_dat_2_rs0;                          //push data -> RS1
   wire [15:0]                          uprs_ps0_push_data;                      //PS0 push data
   wire [15:0]                          uprs_ps1_push_data;                      //PS1 push data
   wire [15:0]                          uprs_rs0_push_data;                      //RS0 push data

   //ROT extension
   wire                                 uprs_ps0_2_ps2;                          //PS0 -> PS2 (ROT extension)
   wire                                 uprs_ps2_2_ps0;                          //PS2 -> PS0 (ROT extension)

   //Cell load status
   wire                                 ps0_loaded;                              //true if PSD>=1
   wire                                 ps1_loaded;                              //true if PSD>=2
   wire                                 ps2_loaded;                              //true if PSD>=3
   wire                                 ps3_loaded;                              //true if PSD>=4
   wire                                 ips_loaded;                              //true if PSD>=5
   wire                                 rs0_loaded;                              //true if RSD>=1
   wire                                 irs_loaded;                              //true if RSD>=2

   //Underflow and overflow indicators
   wire                                 ps_uf;                                   //PS underflow
   wire                                 ps_of;                                   //PS overflow
   wire                                 rs_uf;                                   //RS underflow
   wire                                 rs_of;                                   //RS overflow

   //Shift status
   wire                                 shift_valid;                             //no over or underflows
   wire                                 shift_bsy;                               //busy responses frm intermediate stacks

   //Clear requests
   wire                                 ps_clear;                                //acknowledged PS clear request
   wire                                 rs_clear;                                //acknowledged RS clear request

   //Stack depth updates
   wire                                 psd_inc;                                 //increment PS depth
   wire                                 psd_dec;                                 //decrement PS depth
   wire                                 rsd_inc;                                 //increment RS depth
   wire                                 rsd_dec;                                 //decrement RS depth

   //Push data mux
   assign uprs_dat_2_ps0     = uprs_imm_2_ps0_i  |                               //immediate value -> PS0
                               uprs_alu_2_ps0_i  |                               //ALU             -> PS0
                               uprs_wbi_2_ps0_i  |                               //WBI             -> PS0
                               uprs_fr_2_ps0_i   |                               //FR              -> PS0
                               uprs_excpt_2_ps0_i;                               //exception       -> PS0

   assign uprs_dat_2_ps1     = uprs_alu_2_ps1_i;                                 //ALU             -> PS1
   assign uprs_dat_2_rs0     = uprs_pc_2_rs0_i;                                  //PC              -> RS1
   assign uprs_ps0_push_data =
                     ({16{uprs_imm_2_ps0_i}}   & uprs_imm_2_ps0_push_data_i)   | //immediate value -> PS0
                     ({16{uprs_alu_2_ps0_i}}   & uprs_alu_2_ps0_push_data_i)   | //ALU             -> PS0
                     ({16{uprs_wbi_2_ps0_i}}   & uprs_wbi_2_ps0_push_data_i)   | //WBI             -> PS0
                     ({16{uprs_fr_2_ps0_i}}    & uprs_fr_2_ps0_push_data_i)    | //FR              -> PS0
                     ({16{uprs_excpt_2_ps0_i}} & uprs_excpt_2_ps0_push_data_i);  //exception       -> PS0
   assign uprs_ps1_push_data = uprs_alu_2_ps1_push_data_i;                       //ALU             -> PS1
   assign uprs_rs0_push_data = uprs_pc_2_rs0_push_data_i;                        //PC              -> RS1

   //Gated ROT extension signals
   assign uprs_ps0_2_ps2 = |ROT_EXTENSION & uprs_ps0_2_ps2_i;                    //PS0 -> PS2 (ROT extension)
   assign uprs_ps2_2_ps0 = |ROT_EXTENSION & uprs_ps2_2_ps0_i;                    //PS2 -> PS0 (ROT extension)

   //Cell load
   assign ips_loaded = ~ips_empty_i;                                             //true if PSD>4
   assign ps3_loaded = |psd_reg[PSD_WIDTH-1:2];                                  //true if PSD>3
   assign ps2_loaded = ps3_loaded | (psd_reg[1] & psd_reg[0]);                   //true if PSD>2
   assign ps1_loaded = ps3_loaded |  psd_reg[1];                                 //true if PSD>1
   assign ps0_loaded = ps3_loaded |  psd_reg[1] | psd_reg[0];                    //true if PSD>0
   assign irs_loaded = ~irs_empty_i;                                             //true if RSD>1
   assign rs0_loaded = |rsd_reg;                                                 //true if RSD>0

   //Parameter stack underflow condition
                  // PS3   PS2   PS1   PS0
                  // +-+   +-+   +-+   +-+
                  // | |<->|X|   |X|   |X|
                  // +-+   +-+   +-+   +-+
   assign ps_uf = (~ps3_loaded & ps2_loaded & uprs_ps3_2_ps2_i & uprs_ps2_2_ps3_i) |
                  // PS3   PS2   PS1   PS0
                  // +-+   +-+   +-+   +-+
                  // | |   | |<->|X|   |X|
                  // +-+   +-+   +-+   +-+
                  (~ps2_loaded & ps1_loaded & uprs_ps2_2_ps1_i & uprs_ps1_2_ps2_i) |
                  // PS3   PS2   PS1   PS0
                  // +-+   +-+   +-+   +-+
                  // | |   | |-+ |X| +>|X|
                  // +-+   +-+ | +-+ | +-+
                  //           +-----+
                  (~ps2_loaded & ps1_loaded & uprs_ps0_2_ps2                     ) |
                  // PS3   PS2   PS1   PS0
                  // +-+   +-+   +-+   +-+
                  // | |   | |   | |<->|X|
                  // +-+   +-+   +-+   +-+
                  (~ps1_loaded & ps0_loaded & uprs_ps0_2_ps1_i & uprs_ps1_2_ps0_i) |
                  // PS3   PS2   PS1   PS0
                  // +-+   +-+   +-+   +-+
                  // | |   | |<+ | | +-|X|
                  // +-+   +-+ | +-+ | +-+
                  //           +-----+
                  (~ps1_loaded & ps0_loaded & uprs_ps0_2_ps2                     ) |
                  //  PS3   PS2   PS1   PS0
                  //  +-+   +-+   +-+   +-+
                  //  | |   | |   | |<+ | |
                  //  +-+   +-+   +-+ | +-+
                  (~ps0_loaded              & uprs_dat_2_ps1                     ) |
                  // PS3   PS2   PS1   PS0   RS0
                  // +-+   +-+   +-+   +-+ | +-+
                  // | |   | |   | |   | |-->|X|
                  // +-+   +-+   +-+   +-+ | +-+
                  (~ps0_loaded & rs0_loaded & uprs_ps0_2_rs0_i                   );

   //Parameter stack overflow conditions
   assign ps_of = ips_full_i & ps3_loaded & uprs_ps3_2_ips_i;

   //Return stack underflow conditions
                  // PS3   PS2   PS1   PS0   RS0
                  // +-+   +-+   +-+   +-+ | +-+
                  // | |   | |   | |   |X|<--| |
                  // +-+   +-+   +-+   +-+ | +-+
   assign rs_uf =  ~rs0_loaded & ps0_loaded & uprs_rs0_2_ps0_i;

   //Parameter stack overflow conditions
   assign rs_of = irs_full_i & rs0_loaded & uprs_rs0_2_irs_i;

   //Valid shift
   assign shift_valid = ~|{ps_uf, ps_of, rs_uf, rs_of};

   //Delayed
   assign shift_bsy = (ps3_loaded & uprs_ps3_2_ips_i & ips_push_bsy_i) |
                      (ips_loaded & uprs_ips_2_ps3_i & ips_pull_bsy_i) |
                      (rs0_loaded & uprs_rs0_2_irs_i & irs_push_bsy_i) |
                      (irs_loaded & uprs_irs_2_rs0_i & irs_pull_bsy_i);

   //Parameter stack reset
   assign ps_clear = uprs_ps_clear_i & ~ips_clear_bsy_i;

   //Return stack reset
   assign rs_clear = uprs_rs_clear_i & ~irs_clear_bsy_i;

   //Parameter stack depth increment condition
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |<--|X|   |X|   |X|   |X|
                       // --+   +-+   +-+   +-+   +-+
   assign psd_inc    = (              ps3_loaded & uprs_ps3_2_ips_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |<--|X|   |X|   |X|
                       // --+   +-+   +-+   +-+   +-+
                       (~ps3_loaded & ps2_loaded & uprs_ps2_2_ps3_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |   | |<--|X|   |X|
                       // --+   +-+   +-+   +-+   +-+
                       (~ps2_loaded & ps1_loaded & uprs_ps1_2_ps2_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |   | |<+ |X| +-|X|
                       // --+   +-+   +-+ | +-+ | +-+
                       //                 +-----+
                       (~ps2_loaded & ps0_loaded & uprs_ps0_2_ps2  ) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |   | |   | |<--|X|
                       // --+   +-+   +-+   +-+   +-+
                       (~ps1_loaded & ps0_loaded & uprs_ps0_2_ps1_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |   | |   | |<+ |X|
                       // --+   +-+   +-+   +-+ | +-+
                       (~ps1_loaded              & uprs_dat_2_ps1  ) |
                       // IPS   PS3   PS2   PS1   PS0   RS0
                       // --+   +-+   +-+   +-+   +-+ | +-+
                       //   |   | |   | |   | |   | |<--|X|
                       // --+   +-+   +-+   +-+   +-+ | +-+
                       (~ps0_loaded & rs0_loaded & uprs_rs0_2_ps0_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |   | |   | |   | |<+
                       // --+   +-+   +-+   +-+   +-+ |
                       (~ps0_loaded              & uprs_dat_2_ps0  );

   //Parameter stack depth decrement condition
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //  X|-->|X|   |X|   |X|   |X|
                       // --+   +-+   +-+   +-+   +-+
   assign psd_dec    = (              ips_loaded & uprs_ips_2_ps3_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |-->|X|   |X|   |X|   |X|
                       // --+   +-+   +-+   +-+   +-+
                       (~ips_loaded & ps3_loaded & uprs_ips_2_ps3_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |-->|X|   |X|   |X|
                       // --+   +-+   +-+   +-+   +-+
                       (~ps3_loaded & ps2_loaded & uprs_ps3_2_ps2_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |   | |-->|X|   |X|
                       // --+   +-+   +-+   +-+   +-+
                       (~ps2_loaded & ps1_loaded & uprs_ps2_2_ps1_i) |
                       // IPS   PS3   PS2   PS1   PS0
                       // --+   +-+   +-+   +-+   +-+
                       //   |   | |   | |   | |-->|X|
                       // --+   +-+   +-+   +-+   +-+
                       (~ps1_loaded & ps0_loaded & uprs_ps0_2_ps1_i);

   //Return stack depth increment condition
                       //       RS0   IRS
                       //       +-+   +--
                       //       |X|-->|
                       //       +-+   +--
   assign rsd_inc    = (              rs0_loaded & uprs_rs0_2_irs_i) |
                       // PS0   RS0   IRS
                       // +-+ | +-+   +--
                       // |X|-->| |-->|
                       // +-+ | +-+   +--
                       (~rs0_loaded & ps0_loaded & uprs_ps0_2_rs0_i) |
                       //       RS0   IRS
                       //       +-+   +--
                       //     +>| |-->|
                       //     | +-+   +--
                       (~rs0_loaded              & uprs_dat_2_rs0  );

   //Return stack depth decrement condition
                       //       RS0   IRS
                       //       +-+   +--
                       //       |X|<--|X
                       //       +-+   +--
   assign rsd_dec    = (              irs_loaded & uprs_irs_2_rs0_i) |
                       //       RS0   IRS
                       //       +-+   +--
                       //       |X|<--|
                       //       +-+   +--
                       (~irs_loaded & rs0_loaded & uprs_irs_2_rs0_i);

   //PSD
   assign psd_next  = psd_reg + {{PSD_WIDTH-1{psd_dec}},1'b1};                   //next PS depth
   assign psd_we    = ~shift_bsy & shift_valid & (psd_inc | psd_dec);            //PS depth write enable

   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       psd_reg <= {PSD_WIDTH{1'b0}};
     else if (sync_rst_i)                                                        //synchronous reset
       psd_reg <= {PSD_WIDTH{1'b0}};
     else if (ps_clear)                                                          //soft reset
       psd_reg <= {PSD_WIDTH{1'b0}};
     else if (psd_we)                                                            //state transition
       psd_reg <= psd_next[PSD_WIDTH-1:0];

   assign uprs_psd_o = psd_reg;                                                  //PSD output

   //RSD
   assign rsd_next  = rsd_reg + {{RSD_WIDTH-1{rsd_dec}},1'b1};                   //next PS depth
   assign rsd_we    = ~shift_bsy & shift_valid & (rsd_inc | rsd_dec);            //PS depth write enable

   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       rsd_reg <= {RSD_WIDTH{1'b0}};
     else if (sync_rst_i)                                                        //synchronous reset
       rsd_reg <= {RSD_WIDTH{1'b0}};
     else if (ps_clear)                                                          //soft reset
       rsd_reg <= {RSD_WIDTH{1'b0}};
     else if (rsd_we)                                                            //state transition
       rsd_reg <= rsd_next[RSD_WIDTH-1:0];

   assign uprs_rsd_o = rsd_reg;                                                   //RSD output

   //PS
   assign ps0_next  = ({16{uprs_dat_2_ps0}}   & uprs_ps0_push_data)      |       //push data     -> PS0
                      ({16{uprs_ps1_2_ps0_i}} & ps1_reg)                 |       //PS1           -> PS0
                      ({16{uprs_ps2_2_ps0}}   & ps2_reg)                 |       //PS2           -> PS0 (ROT extension)
                      ({16{uprs_rs0_2_ps0_i}} & rs0_reg);                        //RS0           -> PS0
   assign ps0_we    = ~shift_bsy & shift_valid &
                      (uprs_dat_2_ps0                                    |       //push data     -> PS0
                       uprs_ps1_2_ps0_i                                  |       //PS1           -> PS0
                       uprs_ps2_2_ps0                                    |       //PS2           -> PS0 (ROT extension)
                       uprs_rs0_2_ps0_i);                                        //RS0           -> PS0

   assign ps1_next  = ({16{uprs_dat_2_ps1}}   & uprs_ps1_push_data)      |       //push data     -> PS1
                      ({16{uprs_ps2_2_ps1_i}} & ps2_reg)                 |       //PS2           -> PS1
                      ({16{uprs_ps0_2_ps1_i}} & ps0_reg);                        //PS0           -> PS1
   assign ps1_we    = ~shift_bsy & shift_valid &
                      (uprs_dat_2_ps1                                    |       //push data     -> PS1
                       uprs_ps2_2_ps1_i                                  |       //PS2           -> PS1
                       uprs_ps0_2_ps1_i);                                        //PS0           -> PS1

   assign ps2_next  = ({16{uprs_ps3_2_ps2_i}} & ps3_reg)                 |       //PS3           -> PS2
                      ({16{uprs_ps1_2_ps2_i}} & ps1_reg)                 |       //PS1           -> PS2
                      ({16{uprs_ps0_2_ps2}}   & ps0_reg);                        //PS0           -> PS2 (ROT extension)
   assign ps2_we    = ~shift_bsy & shift_valid &
                      (uprs_ps3_2_ps2_i                                  |       //PS3           -> PS2
                       uprs_ps1_2_ps2_i                                  |       //PS1           -> PS2
                       uprs_ps0_2_ps2);                                          //PS0           -> PS2 (ROT extension)

   assign ps3_next  = ({16{uprs_ips_2_ps3_i}} & ips_pull_data_i)         |       //IPS           -> PS3
                      ({16{uprs_ps2_2_ps3_i}} & ps2_reg);                        //PS2           -> PS3
   assign ps3_we    = ~shift_bsy & shift_valid &
                      (uprs_ips_2_ps3_i                                  |       //IPS           -> PS3
                       uprs_ps2_2_ps3_i);                                        //PS2           -> PS3

   //P0
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       ps0_reg <= 16'h0000;
     else if (sync_rst_i)                                                        //synchronous reset
       ps0_reg <= 16'h0000;
     else if (ps0_we)                                                            //state transition
       ps0_reg <= ps0_next;

   //P1
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       ps1_reg <= 16'h0000;
     else if (sync_rst_i)                                                        //synchronous reset
       ps1_reg <= 16'h0000;
     else if (ps1_we)                                                            //state transition
       ps1_reg <= ps1_next;

   //P2
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       ps2_reg <= 16'h0000;
     else if (sync_rst_i)                                                        //synchronous reset
       ps2_reg <= 16'h0000;
     else if (ps2_we)                                                            //state transition
       ps2_reg <= ps2_next;

   //P3
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       ps3_reg <= 16'h0000;
     else if (sync_rst_i)                                                        //synchronous reset
       ps3_reg <= 16'h0000;
     else if (ps3_we)                                                            //state transition
       ps3_reg <= ps3_next;

   //RS
   assign rs0_next  = ({16{uprs_dat_2_rs0}}    &  uprs_rs0_push_data)    |       //push data     -> RS0
                      ({16{uprs_ps0_2_rs0_i}}  &  ps0_reg)               |       //PS0           -> RS0
                      ({16{uprs_irs_2_rs0_i}}  &  irs_pull_data_i);              //IRS           -> RS0
   assign rs0_we    = ~shift_bsy & shift_valid &
                      (uprs_dat_2_rs0                                    |       //push data     -> RS0
                       uprs_ps0_2_rs0_i                                  |       //PS0           -> RS0
                       uprs_irs_2_rs0_i);                                        //IRS           -> RS0

   //RS0
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       rs0_reg <= 16'h0000;
     else if (sync_rst_i)                                                        //synchronous reset
       rs0_reg <= 16'h0000;
     else if (rs0_we)                                                            //state transition
       rs0_reg <= rs0_next;

    //IPS interface
    assign ips_clear_o     = uprs_ps_clear_i;                                    //IPS clear request
    assign ips_push_o      = uprs_ps3_2_ips_i & shift_valid;                     //IPS push request
    assign ips_pull_o      = uprs_ips_2_ps3_i & shift_valid;                     //IPS pull request
    assign ips_push_data_o = ps3_reg;                                            //IPS push data

    //IRS interface
    assign irs_clear_o     = uprs_rs_clear_i;                                    //IRS clear request
    assign irs_push_o      = uprs_rs0_2_irs_i & shift_valid;                     //IRS push request
    assign irs_pull_o      = uprs_irs_2_rs0_i & shift_valid;                     //IRS pull request
    assign irs_push_data_o = rs0_reg;                                            //IRS push data

   //Probe signals
   //-------------
   assign prb_uprs_psd_o   = psd_reg;                                            //probed PSD
   assign prb_uprs_rsd_o   = rsd_reg;                                            //probed RSD
   assign prb_uprs_ps0_o   = ps0_reg;                                            //probed PS0
   assign prb_uprs_ps1_o   = ps1_reg;                                            //probed PS1
   assign prb_uprs_ps2_o   = ps2_reg;                                            //probed PS2
   assign prb_uprs_ps3_o   = ps3_reg;                                            //probed PS3
   assign prb_uprs_rs0_o   = rs0_reg;                                            //probed RS0

   //Assertions
   //----------
`ifdef FORMAL
   //Input checks
   //------------
   //The IPS must be enpty whenever PSD <= 4
   assert(ips_uf_i ^  ips_loaded);

   //The IPS must not be overflowing when PSD <= 4
   assert(~ips_of_i |  ips_loaded);

   //The IRS must be enpty whenever RSD <= 1
   assert(irs_uf_i ^  irs_loaded);

   //The IRS must not be overflowing when RSD <= 4
   assert(~irs_of_i |  irs_loaded);

`endif

endmodule // N1_us
