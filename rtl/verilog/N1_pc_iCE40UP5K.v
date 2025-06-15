//###############################################################################
//# N1 - Program Counter (Address Accumulator)                                  #
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
//#    This module implements a 16 bit accumulator for address calculationsu    #
//#    utilizing a DSP cell (SB_MAC16) instance of the Lattice iCE40UP5K FPGA.  #
//#                                                                             #
//#    The combinational logic address output (pc_addr_o) is intended to be     #
//#    used as memory address. The (internal) accumulator register can serve as #
//#    program counter.                                                         #
//#                                                                             #
//#    This partition is to be replaced for other target architectures.         #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   February 12, 2024                                                         #
//#      - Initial release                                                      #
//#   May 15, 2025                                                              #
//#      - New naming                                                           #
//#   June 2, 2025                                                              #
//#      - Capturing previous PC for interruptable instructions                 #
//###############################################################################
`default_nettype none

module N1_pc
  #(parameter  PC_EXTENSION     =        1,                               //program counter extension
    parameter  INT_EXTENSION    =        1,                               //interrupt extension
    parameter  IMM_PADDR_OFFS   = 16'h0000)                               //offset for immediate program address
   (//Clock and reset
    input  wire                             clk_i,                        //module clock
    input  wire                             async_rst_i,                  //asynchronous reset
    input  wire                             sync_rst_i,                   //synchronous reset

    //FE interface
    input  wire                             fe2pc_update_i,               //switch to next address

    //IR interface
    input  wire [13:0]                      ir2pc_abs_addr_i,             //absolute address
    input  wire [12:0]                      ir2pc_rel_addr_i,             //absolute address
    input  wire                             ir2pc_call_or_jump_i,         //call or jump instruction
    input  wire                             ir2pc_branch_i,               //branch instruction
    input  wire                             ir2pc_return_i,               //return

    //UPRS interface
    input  wire [15:0]                      uprs_ps0_pull_data_i,         //PS0 pull data
    input  wire [15:0]                      uprs_rs0_pull_data_i,                    //RS0 pull data

    //PC outputs
    output wire [15:0]                      pc_next_o,                    //program AGU output
    output wire [15:0]                      pc_prev_o,                    //previous PC

    //Probe signals
    output wire [15:0]                      prb_pc_cur_o,                 //probed current PC
    output wire [15:0]                      prb_pc_prev_o);               //probed previous PC

   //Internal signals
   //----------------
   //Address selection
   wire                                     jmp_sel                       //call or jump address selected
   wire                                     bra_sel                       //branch address selected
   wire                                     ret_sel                       //return address selected
   wire                                     inc_sel                       //address increment selected
   wire [15:0]                              abs_addr;                     //absolute address
   wire [15:0]                              rel_addr;                     //relative address

   //Accumulator signals
   reg  [15:0]                              pc_mirror_reg;                //program counter
   reg  [15:0]                              pc_prev_reg;                  //previous program counter
   wire [31:0]                              acc_out;                      //accumulator output

   //Address selection
   assign jmp_sel     = ir2pc_call_or_jump_i;                             //call or jump address selected
   assign bra_sel     = ir2pc_branch_i & |uprs_ps0_pull_data_i;           //branch address selected
   assign ret_sel     = ~jmp_sel & ~bra_sel &  ir2pc_return_i;            //return address selected
   assign inc_sel     = ~jmp_sel & ~bra_sel & ~ir2pc_return_i;            //address increment selected
   
   assign abs_addr    = ({16{jmp_sel}} &                                                   //jump or call
		      	  (&ir2pc_abs_addr_i ? uprs_ps0_pull_data_i :                      //PS0
                                               {IMM_PADDR_OFFS[15:14],ir2pc_abs_addr_i}) | //immediate address  
		      	({16{ret_sel}} &                                                   //return
		      	 uprs_rs0_pull_data_i));		                	   //RS0

   assign rel_addr    = ({16{bra_sel}} &                                                   //branch
                         {{3{ir2pc_rel_addr_i[12]}},ir2pc_rel_addr_i});                    //relative address

   //SB_MAC16 cell for the AGU accumulator
   //-------------------------------------
   //The "Hi" part of the SB_MAC32 is unused
   //The "Lo" part of the SB_MAC32 implements accumulator for the AGU
   //The output hold register implement the program counter
   //The AGU output is unregistered (= next address)
   SB_MAC16
     #(.NEG_TRIGGER              (1'b0),                                  //Clock edge -> posedge
       .C_REG                    (1'b0),                                  //C0         -> C input unregistered
       .A_REG                    (1'b0),                                  //C1         -> A input unregistered
       .B_REG                    (1'b0),                                  //C2         -> B input unregistered
       .D_REG                    (1'b0),                                  //C3         -> D input unregistered
       .TOP_8x8_MULT_REG         (1'b1),                                  //C4         -> keep unused signals quiet
       .BOT_8x8_MULT_REG         (1'b1),                                  //C5         -> keep unused signals quiet
       .PIPELINE_16x16_MULT_REG1 (1'b1),                                  //C6         -> keep unused signals quiet
       .PIPELINE_16x16_MULT_REG2 (1'b1),                                  //C7         -> keep unused signals quiet
       .TOPOUTPUT_SELECT         (2'b00),                                 //C8,C9      -> unregistered output
       .TOPADDSUB_LOWERINPUT     (2'b00),                                 //C10,C11    -> plain adder
       .TOPADDSUB_UPPERINPUT     (1'b1),                                  //C12        -> connect to op0
       .TOPADDSUB_CARRYSELECT    (2'b00),                                 //C13,C14    -> no carry
       .BOTOUTPUT_SELECT         (2'b00),                                 //C15,C16    -> unregistered output
       .BOTADDSUB_LOWERINPUT     (2'b00),                                 //C17,C18    -> plain adder
       .BOTADDSUB_UPPERINPUT     (1'b1),                                  //C19        -> connect to program counter
       .BOTADDSUB_CARRYSELECT    (2'b11),                                 //C20,C21    -> add carry via CI input
       .MODE_8x8                 (1'b1),                                  //C22        -> power safe
       .A_SIGNED                 (1'b0),                                  //C23        -> unsigned
       .B_SIGNED                 (1'b0))                                  //C24        -> unsigned
   SB_MAC16_acc
     (.CLK                       (clk_i),                                 //clock input
      .CE                        (1'b1),                                  //clock enable
      .C                         (16'h0000),                              //unused
      .A                         (16'h0000),                              //unused
      .B                         (rel_addr),                              //relative COF address
      .D                         (abs_addr),                              //absolute COF address
      .AHOLD                     (1'b1),                                  //keep hold register stable
      .BHOLD                     (1'b1),                                  //keep hold register stable
      .CHOLD                     (1'b1),                                  //keep hold register stable
      .DHOLD                     (1'b1),                                  //keep hold register stable
      .IRSTTOP                   (1'b1),                                  //keep hold register in reset
      .IRSTBOT                   (1'b1),                                  //keep hold register in reset
      .ORSTTOP                   (1'b1),                                  //keep hold register in reset
      .ORSTBOT                   (|{async_rst_i,sync_rst_i}),             //use common reset
      .OLOADTOP                  (1'b0),                                  //no bypass
      .OLOADBOT                  (pc_sel_i),                              //absolute COF
      .ADDSUBTOP                 (1'b0),                                  //subtract
      .ADDSUBBOT                 (1'b0),                                  //always use adder
      .OHOLDTOP                  (1'b1),                                  //keep hold register stable
      .OHOLDBOT                  (~fe2pc_change_i),                       //update PC
      .CI                        (inc_sel),                               //address increment
      .ACCUMCI                   (1'b0),                                  //no carry
      .SIGNEXTIN                 (1'b0),                                  //no sign extension
      .O                         (acc_out),                               //result
      .CO                        (),                                      //ignore carry output
      .ACCUMCO                   (),                                      //carry bit determines upper word
      .SIGNEXTOUT                ());                                     //ignore sign extension output

   //Mirrored PC
   always @(posedge async_rst_i or posedge clk_i)
     begin
        if (async_rst_i)                                                  //asynchronous reset
          begin
             pc_mirror_reg      <= 16'h0000;                              //start address
             pc_prev_reg        <= 16'h0000;                              //start address
          end
        else if (sync_rst_i)                                              //synchronous reset
          begin
             pc_mirror_reg      <= 16'h0000;                              //start address
             pc_prev_reg        <= 16'h0000;                              //start address
          end
        else if (~pc_pc_hold_i)                                           //update PC
          begin
             pc_mirror_reg      <= acc_outt[15:0];                        //current PC
             pc_prev_reg <= PC_EXTENSION|INT_EXTENSION ? pc_reg :         //previous PC
			                                 16'h0000;
          end
     end // always @ (posedge async_rst_i or posedge clk_i)

   assign pc_next_o     = acc_out[15:0];                                  //opcode fetch address
   assign pc_prev_o     = pc_prev_reg;                                    //return address

   //Probe signals
   assign prb_pc_cur_o  = pc_mirror_reg;                                  //current PC
   assign prb_pc_prev_o = pc_prev_reg;                                    //previous PC

endmodule // N1_pc

