//###############################################################################
//# N1 - Upper Stacks                                                           #
//###############################################################################
//#    Copyright 2018 Dirk Heisswolf                                            #
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
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_us
  #(localparam 16  = 16,   //cell width
    localparam 12   = 12)   //width of the stack transition pattern

   (//Clock and reset
    input wire                             clk_i,             //module clock
    input wire                             async_rst_i,       //asynchronous reset
    input wire                             sync_rst_i,        //synchronous reset

    //Program bus (wishbone)
    input  wire [15:0]                     pbus_dat_o,        //write data bus
    input  wire [15:0]                     pbus_dat_i,        //read data bus

    //Instruction decoder output
    input  wire             `               ir_eow_i,          //end of word
    input  wire                            ir_jmp_i,          //jump instruction (any)
    input  wire                            ir_jmp_ind_i,      //jump instruction (indirect addressing)
    input  wire                            ir_jmp_dir_i,      //jump instruction (direct addressing)
    input  wire                            ir_call_i,         //call instruction (any)
    input  wire                            ir_call_ind_i,     //call instruction (indirect addressing)
    input  wire                            ir_call_dir_i,     //call instruction (direct addressing)
    input  wire                            ir_bra_i,          //branch instruction (any)
    input  wire                            ir_bra_ind_i,      //branch instruction (indirect addressing)
    input  wire                            ir_bra_dir_i,      //branch instruction (direct addressing)
    input  wire                            ir_lit_i,          //literal instruction
    input  wire                            ir_alu_i,          //ALU instruction (any)
    input  wire                            ir_alu_x_x_i,      //ALU instruction (   x --   x )
    input  wire                            ir_alu_xx_x_i,     //ALU instruction ( x x --   x )
    input  wire                            ir_alu_x_xx_i,     //ALU instruction (   x -- x x )
    input  wire                            ir_alu_xx_xx_i,    //ALU instruction ( x x -- x x )
    input  wire                            ir_sop_i,          //stack operation
    input  wire                            ir_fetch_i,        //memory read (any)
    input  wire                            ir_fetch_ind_i,    //memory read (indirect addressing)
    input  wire                            ir_fetch_dir_i,    //memory read (direct addressing)
    input  wire                            ir_store_i,        //memory write (any)
    input  wire                            ir_store_ind_i,    //memory write (indirect addressing)
    input  wire                            ir_store_dir_i,    //memory write (direct addressing)
    input  wire [13:0]                     ir_abs_adr_i,      //direct absolute COF address
    input  wire [12:0]                     ir_rel_adr_i,      //direct relative COF address
    input  wire [11:0]                     ir_lit_val_i,      //literal value
    input  wire [4:0]                      ir_opr_i,          //ALU operator
    input  wire [4:0]                      ir_op_i,           //immediate operand
    input  wire [9:0]                      ir_stp_i,          //stack transition pattern
    input  wire [7:0]                      ir_mem_adr_i,      //direct absolute data address

    //Flow control - upper stack interface
    output wire                            fc_us_busy_o,      //upper stack is busy

    //Upper stack - ALU interface
    input  wire [15:0]                     us_alu_ps0_next_i, //new PS0 (TOS)
    input  wire [15:0]                     us_alu_ps1_next_i, //new PS1 (TOS+1)
    output wire [15:0]                     us_alu_ps0_cur_o,  //current PS0 (TOS)
    output wire [15:0]                     us_alu_ps1_cur_o,  //current PS1 (TOS+1)
    output wire [3:0]                      us_alu_pstat_o,    //UPS status
    output wire                            us_alu_rstat_o,    //URS status

    //Upper stack - intermediate parameter stack interface
    wire                                    us_ips_rst;         //reset stack
    wire                                    us_ips_psh;         //US  -> IRS
    wire                                    us_ips_pul;         //IRS -> US
    wire                                    us_ips_psh_ctag;    //upper stack cell tag
    wire [15:0]                             us_ips_psh_cell;    //upper stack cell
    wire                                    us_ips_busy;        //intermediate stack is busy
    wire                                    us_ips_pul_ctag;    //intermediate stack cell tag
    wire [15:0]                             us_ips_pul_cell;    //intermediate stack cell

    //Upper stack - intermediate return stack interface
    wire                                    us_irs_rst;         //reset stack
    wire                                    us_irs_psh;         //US  -> IRS
    wire                                    us_irs_pul;         //IRS -> US
    wire                                    us_irs_psh_ctag;    //upper stack tag
    wire [15:0]                             us_irs_psh_cell;    //upper stack data
    wire                                    us_irs_busy;        //intermediate stack is busy
    wire                                    us_irs_pul_ctag;    //intermediate stack tag
    wire [15:0]                             us_irs_pul_cell;    //intermediate stack data



    //IR interface
    input wire [15:0]                      ir_ps0_i,          //literal value
    input wire [15:0]                      ir_rs0_i,          //COF address

    input wire                             ir_ps_reset_i,     //reset stack
    input wire                             ir_rs_reset_i,     //reset stack

    input wire                             ir_pagu_to_rs0_i   //pbus_dat_i -> RS0
    input wire                             ir_ir_to_rs0_i     //opcode     -> RS0
    input wire                             ir_ps0_to_rs0_i    //PS0        -> RS0
    input wire                             ir_rs1_to_rs0_i    //RS1        -> RS0

    input wire                             ir_rs0_to_rs1_i    //RS0        -> RS1

    input wire                             ir_pbus_to_ps0_i   //pbus_dat_i -> PS0
    input wire                             ir_ir_to_ps0_i     //opcode     -> RS0
    input wire                             ir_alu_to_ps0_i    //ALU        -> PS0
    input wire                             ir_rs0_to_ps0_i    //RS0        -> PS0
    input wire                             ir_ps1_to_ps0_i    //PS1        -> PS0

    input wire                             ir_alu_to_ps1_i    //ALU        -> RS1
    input wire                             ir_ps0_to_ps1_i    //PS0        -> PS1
    input wire                             ir_ps2_to_ps1_i    //PS2        -> PS1

    input wire                             ir_ps1_to_ps2_i    //PS1        -> PS2
    input wire                             ir_ps3_to_ps2_i    //PS3        -> PS2

    input wire                             ir_ps2_to_ps3_i    //PS2        -> PS3
    input wire                             ir_ps4_to_ps3_i    //PS4        -> PS3

    input wire                             ir_ps3_to_ps4_i    //PS3        -> PS4

    //Flow control interface
    input wire                             fc_update_stacks_i //do stack transition

    //ALU interface
    input wire [15:0]            alu_ps0_i          //ALU output for PS0
    input wire [15:0]            alu_ps1_i          //overwrite PS1

    //Program AGU interface
    input wire [15:0]            pagu_pc_next_i     //PAGU output for S0

    //Dbus interface
    input  wire [15:0]           pbus_dat_i,        //read data

    //Upper stack interface
    output wire [16:0]             us_rs0_o           //RS0 (TOS)
    output wire [16:0]             us_ps0_o           //PS0 (TOS)
    output wire [16:0]             us_ps1_o           //PS1 (TOS+1)
    output wire [16:0]             us_ps2_o           //PS2 (TOS+2)
    output wire [16:0]             us_ps3_o           //PS3 (TOS+3)

    //Lower return stack interface
    input  wire [16:0]             irs_rs1_i,         //RS1 (TOS+1)

    //Lower parameter stack
    input  wire [16:0]             ips_ps4_i);        //PS4 (TOS+4)

   //Stack cells (MSB = tag)
   reg  [16:0]                     rs0_reg;           //RS0 (TOS)
   reg  [16:0]                     ps0_reg;           //PS0 (TOS)
   reg  [16:0]                     ps1_reg;           //PS1 (TOS+1)
   reg  [16:0]                     ps2_reg;           //PS2 (TOS+2)
   reg  [16:0]                     ps3_reg;           //PS3 (TOS+3)

   //RS0
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       rs0_reg <= {16+1{1'b0}};
     else if (sync_rst_i)                                     //synchronous reset
       rs0_reg <= {16+1{1'b0}};
     else if (fc_update_stacks_i &                            //stack transition
              |{ir_rs_reset,
                ps0_to_rs0,
                ir_to_rs0,
                ps0_to_rs0,
                rs1_to_rs0})
       rs0_reg <= ({16+1{ps0_to_rs0}}       & {1'b1, pagu_pc_next_i}) |
                  ({16+1{ir_to_rs0}}        & {1'b1, ir_rs0_i})       |
                  ({16+1{ps0_to_rs0}}       &        ps0_reg)         |
                  ({16+1{rs1_to_rs0}}       &        irs_rs1_i);

   //PS0 (TOS)
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       ps0_reg <= {16+1{1'b0}};
     else if (sync_rst_i)                                     //synchronous reset
       ps0_reg <= {16+1{1'b0}};
     else if (fc_update_stacks_i &                            //stack transition
              |{ir_ps_reset,
                ir_pbus_to_ps0_i,
                ir_ir_to_ps0_i,
                ir_alu_to_ps0_i,
                ir_rs0_to_ps0_i,
                ir_ps1_to_ps0_i})
       ps0_reg <= ({16+1{ir_pbus_to_ps0_i}} & {1'b1, pbus_dat_i}) |
                  ({16+1{ir_ir_to_ps0_i}}   & {1'b1, ir_ps0_i})   |
                  ({16+1{ir_alu_to_ps0_i}}  & {1'b1, alu_ps0_i})  |
                  ({16+1{ir_rs0_to_ps0_i}}  &        rs0_reg)     |
                  ({16+1{ir_ps1_to_ps0_i}}  &        ps1_rs1_i);

   //PS1
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       ps1_reg <= {16+1{1'b0}};
     else if (sync_rst_i)                                     //synchronous reset
       ps1_reg <= {16+1{1'b0}};
     else if (fc_update_stacks_i &                            //stack transition
              |{ir_ps_reset,
                ir_alu_to_ps1_i,
                ir_ps0_to_ps1_i,
                ir_ps2_to_ps1_i})
       ps1_reg <= ({16+1{ir_alu_to_ps1_i}}  & {1'b1, alu_ps1_i})  |
                  ({16+1{ir_ps0_to_ps1_i}}  &        ps0_reg)     |
                  ({16+1{ir_ps2_to_ps1_i}}  &        ps2_reg);

   //PS2
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       ps2_reg <= {16+1{1'b0}};
     else if (sync_rst_i)                                     //synchronous reset
       ps2_reg <= {16+1{1'b0}};
     else if (fc_update_stacks_i &                            //stack transition
              |{ir_ps_reset,
                ir_ps0_to_ps1_i,
                ir_ps2_to_ps1_i})
       ps2_reg <= ({16+1{ir_ps1_to_ps2_i}}  &        ps1_reg)     |
                  ({16+1{ir_ps3_to_ps2_i}}  &        ips_ps3_reg);

   //PS3
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       ps3_reg <= {16+1{1'b0}};
     else if (sync_rst_i)                                     //synchronous reset
       ps3_reg <= {16+1{1'b0}};
     else if (fc_update_stacks_i &                            //stack transition
              |{ir_ps_reset,
                ir_ps2_to_ps3_i,
                ir_ps4_to_ps3_i})
       ps3_reg <= ({16+1{ir_ps1_to_ps2_i}}  &        ps1_reg)     |
                  ({16+1{ir_ps3_to_ps2_i}}  &        ps3_reg);

   //Outputs
   assign us_rs0_o = rs0_reg;                                //RS0 (TOS)
   assign us_ps0_o = ps0_reg;                                //PS0 (TOS)
   assign us_ps3_o = ps1_reg;                                //PS1 (TOS+1)
   assign us_ps3_o = ps2_reg;                                //PS2 (TOS+2)
   assign us_ps3_o = ps3_reg;                                //PS3 (TOS+3)

endmodule // N1_us
