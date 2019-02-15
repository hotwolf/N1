//###############################################################################
//# N1 - Parameter and Return Stack                                             #
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
//#    This module implements all levels of the parameter and the return stack. #
//#    These levels are:                                                        #
//#    - The upper stack, which provides direct access to the most cells and    #
//#      which is capable of performing stack operations.                       #
//#                                                                             #
//#  Imm.  |                  Upper Stack                   |    Upper   | Imm. #
//#  Stack |                                                |    Stack   | St.  #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#      |<->|  PS3  |<=>|  PS2  |<=>|  PS1  |<=>|  PS0  |<===>|  RS0  |<->|    #
//#   ---+   +-------+   +-------+   +-------+   +-------+  |  +-------+   +--  #
//#                                                 TOS     |     TOS           #
//#                          Parameter Stack                | Return Stack      #
//#                                                                             #
//#    - The intermediate stack serves as a buffer between the upper and the    #
//#      lower stack. It is designed to handle smaller fluctuations in stack    #
//#      content, minimizing accesses to the lower stack.                       #
//#                                                                             #
//#        Upper Stack           Intermediate Stack                             #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+---+                     #
//#       |   |   |   |<=>| 0 | 1 | 2 | 3 | 4 |   |n-1| n |                     #
//#    ...+---+---+---+   +---+---+---+---+---+...+---+-+-+                     #
//#                         ^                           |                       #
//#                         |                           v     +----------+      #
//#                       +-+-----------------------------+   |   RAM    |      #
//#                       |        RAM Controller         |<=>| (Lower   |      #
//#                       +-------------------------------+   |   Stack) |      #
//#                                                           +----------+      #
//#                                                                             #
//#    - The lower stack resides in RAM to to implement a deep stack.           #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 13, 2018                                                         #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_prs
  #(parameter   SP_WIDTH        =      12,                         //width of the stack pointer
    parameter   IPS_DEPTH       =       8,                         //depth of the intermediate parameter stack
    parameter   IPS_DEPTH       =       8)                         //depth of the intermediate return stack
								   
   (//Clock and reset						   
    input wire                               clk_i,                //module clock
    input wire                               async_rst_i,          //asynchronous reset
    input wire                               sync_rst_i,           //synchronous reset
					     			   
    //Program bus (wishbone)		     			   
    input  wire [15:0]                       pbus_dat_o,           //write data bus
    input  wire [15:0]                       pbus_dat_i,           //read data bus
								   
    //Stack bus (wishbone)					   
    output wire                              sbus_cyc_o,           //bus cycle indicator       +-
    output wire                              sbus_stb_o,           //access request            |
    output wire                              sbus_we_o,            //write enable              | initiator
    output wire [SP_WIDTH-1:0]               sbus_adr_o,           //address bus               | to
    output wire [15:0]                       sbus_dat_o,           //write data bus            | target
    output wire                              sbus_tga_ps_o,        //parameter stack access    |
    output wire                              sbus_tga_rs_o,        //return stack access       +-
    input  wire                              sbus_ack_i,           //bus cycle acknowledge     +-
    input  wire                              sbus_err_i,           //error indicator           | target
    input  wire                              sbus_rty_i,           //retry request             | to
    input  wire                              sbus_stall_i,         //access delay              | initiator
    input  wire [15:0]                       sbus_dat_i,           //read data bus             +-

    //ALU interface
    input  wire [15:0]                       alu2prs_ps0_next_i,   //new PS0 (TOS)
    input  wire [15:0]                       alu2prs_ps1_next_i,   //new PS1 (TOS+1)
    output wire [15:0]                       prs2alu_ps0_cur_o,    //current PS0 (TOS)
    output wire [15:0]                       prs2alu_ps1_cur_o,    //current PS1 (TOS+1)

    //DSP cell partition interface


    input  wire [SP_WIDTH-1:0]               dsp2prs_psp_next_i,   //new lower parameter stack pointer
    input  wire [SP_WIDTH-1:0]               dsp2prs_rsp_next_i,   //new lower return stack pointer
    output wire [SP_WIDTH-1:0]               prs2dsp_psp_offs_o,   //parameter stack pointer offset
    output wire                              prs2dsp_psp_add_o,    //add offset to PSP
    output wire                              prs2dsp_psp_sub_o,    //subtract offset from PSP
    output wire                              prs2dsp_psp_load_o,   //load offset to PSP
    output wire                              prs2dsp_psp_update_o, //update PSP
    output wire [SP_WIDTH-1:0]               prs2dsp_rsp_offs_o,   //return stack pointer offset
    output wire                              prs2dsp_rsp_add_o,    //add offset to RSP
    output wire                              prs2dsp_rsp_sub_o,    //subtract offset from RSP
    output wire                              prs2dsp_rsp_load_o,   //load offset to RSP
    output wire                              prs2dsp_rsp_update_o, //update RSP

    //Flow control interface
    input  wire [15:0]                       fc2prs_pc_next_i      //AGU output
    input wire                               fc2prs_stall_i,       //program execution is stalled
								   
    output wire                              prs2fc_stall_o,       //stack operation is stalled
								   
    output wire                              prs2fc_err_psof_o,    //parameter stack overflow
    output wire                              prs2fc_err_psuf_o,    //parameter stack underflow
    output wire                              prs2fc_err_rsof_o,    //return stack overflow
    output wire                              prs2fc_err_rsuf_o,    //return stack underflow
    output wire                              prs2fc_err_bus_o,     //bus error




    //Instruction register interface

    input  wire [15:0]                     ir2prs_lit_val_i,  //literal value



    //Instruction decoder output
    input  wire                            ir_eow_i,          //end of word
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
    input  wire                            ir_alu_imm_i,     //ALU instruction ( x x --   x )
    input  wire                            ir_alu_dbl_i,     //ALU instruction ( x x --   x )
    input  wire                            ir_alu_xx_x_i,     //ALU instruction ( x x --   x )
    input  wire                            ir_alu_x_xx_i,     //ALU instruction (   x -- x x )
    input  wire                            ir_alu_xx_xx_i,    //ALU instruction ( x x -- x x )
    input  wire                            ir2prs_sop_i,          //stack operation
    input  wire                            ir_fetch_i,        //memory read (any)
    input  wire                            ir_fetch_ind_i,    //memory read (indirect addressing)
    input  wire                            ir_fetch_dir_i,    //memory read (direct addressing)
    input  wire                            ir_store_i,        //memory write (any)
    input  wire                            ir_store_ind_i,    //memory write (indirect addressing)
    input  wire                            ir2prs_store_dir_i,    //memory write (direct addressing)
    input  wire [13:0]                     ir_abs_adr_i,      //direct absolute COF address
    input  wire [12:0]                     ir_rel_adr_i,      //direct relative COF address
    input  wire [11:0]                     ir_lit_val_i,      //literal value
    input  wire [4:0]                      ir_opr_i,          //ALU operator
    input  wire [4:0]                      ir_op_i,           //immediate operand
    input  wire [9:0]                      ir2prs_stp_i,          //stack transition pattern
    input  wire [7:0]                      ir_mem_adr_i);     //direct absolute data address
 
   //Internal signals
   //----------------
   //Parameter stack
   reg  [(16*(IPS_DEPTH+4))-1:0]           ps_cells_reg;      //cell content
   wire [(16*(IPS_DEPTH+4))-1:0]           ps_cells_next;     //cell input
   reg  [IPS_DEPTH+3:0]                    ps_tags_reg;       //tag content
   wire [IPS_DEPTH+3:0]                    ps_tags_next;      //tag input
   wire [IPS_DEPTH+3:0]                    ps_we;             //write enable

   //Return stack
   reg  [(16*(IRS_DEPTH+1))-1:0]           rs_cells_reg;      //cell content
   wire [(16*(IRS_DEPTH+1))-1:0]           rs_cells_next;     //cell input
   reg  [IRS_DEPTH:0]                      rs_tags_reg;       //tag content
   wire [IRS_DEPTH:0]                      rs_tags_next;      //tag input
   wire [IRS_DEPTH:0]                      rs_we;             //write enable

   //Stack transition  

   //Stack underflow conditions
   wire 				   psuf_alu;           
   wire 				   psuf_shop;
   wire 				   rsuf_shop;
   wire 				   rsuf_eow;
   



   wire                                    fsm_update;        //perform IR operation
   wire                                    fsm_load;          //load cell from lower stack
   wire                                    fsm_unload;        //unload cell into lower stack
   wire                                    fsm_pack;          //move all cells into lower stack
   wire                                    fsm_unpack;        //retrive cells from lower stack 
      
   //Stack data path
   //----------------
   always @*
     begin
	//Logic initialization
	ps_cells_next = {IPS_DEPTH+4{16'h0000}};              //cell input
	ps_tags_next  = {IPS_DEPTH+4{1'b0}};                  //tag input
        ps_we         = {IPS_DEPTH+4{1'b0}};                  //write enable
        ps_uf         = 1'b0;                                 //underflow
						              
	rs_cells_next = {IRS_DEPTH+1{16'h0000}};              //cell input
	rs_tags_next  = {IRS_DEPTH+1{1'b0}};                  //tag input
        rs_we         = {IRS_DEPTH+1{1'b0}};                  //write enable
        rs_uf         = 1'b0;                                 //underflow	

	//Stack operation
	if (ir2prs_sop_i)
	  begin
	     //Stack underflows
	     ps_uf                = ps_uf |
				    ( ir2prs_stp_i[2]   & ~rs_tags_reg[0])                  | //empty shift from RS0
				    (&ir2prs_stp_i[4:3] & ~ps_tags_reg[1] & ps_tags_reg[0]) | //invalid swap PS1<->PS0
				    (&ir2prs_stp_i[6:5] & ~ps_tags_reg[2] & ps_tags_reg[1]) | //invalid swap PS2<->PS1
				    (&ir2prs_stp_i[8:7] & ~ps_tags_reg[3] & ps_tags_reg[2]);  //invalid swap PS3<->PS2
             rs_uf                = rs_uf |
                                    ( ir2prs_stp_i[1]   & ~rp_tags_reg[0]);                   //empty shift from PS0
 
	     //PS0
	     ps_cells_next[15:0]  = ps_cells_next[15:0]                          |
				    ({16{ir2prs_stp_i[2]}} & rs_cells_reg[15:0]) |
				    ({16{ir2prs_stp_i[3]}} & ps_cells_reg[31:16]);
	     ps_tags_next[0]      = ps_tags_next[0]                              | 
				    ir2prs_stp_i[2]                              |
                                    (ir2prs_stp_i[3] & ps_tags_reg[1]);
             ps_we[0]             = fsm_update & |ir2prs_stp_i[2:3];
	     
	     //PS1		   
	     ps_cells_next[31:16] = ps_cells_next[31:16]                         |
				    ({16{ir2prs_stp_i[4]}} & ps_cells_reg[15:0]) |
				    ({16{ir2prs_stp_i[5]}} & ps_cells_reg[47:32]);
	     ps_tags_next[1]      = ps_tags_next[1]                              | 
				    (ir2prs_stp_i[4] & ps_tags_reg[0])           |
                                    (ir2prs_stp_i[5] & ps_tags_reg[2]);
             ps_we[1]             = fsm_update & |ir2prs_stp_i[4:5];
	     
	     //PS2		   
	     ps_cells_next[47:32] = ps_cells_next[47:32]                         |
				    ({16{ir2prs_stp_i[6]}} & ps_cells_reg[31:16])|
				    ({16{ir2prs_stp_i[7]}} & ps_cells_reg[63:48]);
	     ps_tags_next[2]      = ps_tags_next[2]                              | 
				    (ir2prs_stp_i[6] & ps_tags_reg[1])           |
                                    (ir2prs_stp_i[7] & ps_tags_reg[3]);
             ps_we[2]             = fsm_update & |ir2prs_stp_i[6:7];
	     
	     //PS3		   
	     ps_cells_next[63:48] = ps_cells_next[63:48]                          |
				    ({16{ir2prs_stp_i[8]}} & ps_cells_reg[47:32]) |
				    ({16{ir2prs_stp_i[9] & 
					 ~ir2prs_stp_i[8]}} & ps_cells_reg[78:64]);
	     ps_tags_next[3]      = ps_tags_next[3]                               | 
				    (ir2prs_stp_i[8] & ps_tags_reg[2])            |
                                    (ir2prs_stp_i[9] & ps_tags_reg[4]);
             ps_we[3]             = fsm_update & |ir2prs_stp_i[8:9];
	     
	     //PS4...PSn		   
	     ps_cells_next[(16*(IPS_DEPTH+4))-1:64] = ps_cells_next[(16*(IPS_DEPTH+4))-1:64] |
	        (ir2prs_stp_i[8] ? ps_cells_reg[(16*(IPS_DEPTH+3))-1:48] :
		                   {16'h0000, ps_cells_reg[(16*(IPS_DEPTH+4))-1:80]});
	     ps_tags_next[IPS_DEPTH+3:4] = ps_tags_next[IPS_DEPTH+3:4]                       |
	        (ir2prs_stp_i[8] ? ps_tags_reg[IPS_DEPTH+2:3] : 
		                   {1'b0, ps_tags_reg[IPS_DEPTH+4:5]});
	     ps_we[IPS_DEPTH+3:4] = ps_we[IPS_DEPTH+3:4]                                     | 
                                    {IPS_DEPTH{fsm_update & ir2prs_stp_i[9]}};

	     //RS0
	     rs_cells_next[15:0]  = rs_cells_next[15:0]                          |
				    ({16{ir2prs_stp_i[0]
					~ir2prs_stp_i[1]}} & rs_cells_reg[31:16])|
				    ({16{ir2prs_stp_i[1]}} & ps_cells_reg[15:0]);
	     rs_tags_next[0]      = ps_tags_next[0]                              | 
				    (ir2prs_stp_i[1] & ps_tags_reg[0])           |
                                    (ir2prs_stp_i[0] & rs_tags_reg[1]);
             rs_we[0]             = fsm_update & |ir2prs_stp_i[1:0];

	     //RS1...RSn
	     rs_cells_next[(16*(IRS_DEPTH+1))-1:16] = ps_cells_next[(16*(IRS_DEPTH+1))-1:16] |
	        (ir2prs_stp_i[1] ? rs_cells_reg[(16*IRS_DEPTH)-1:0] :
		                   {16'h0000, ps_cells_reg[(16*(IRS_DEPTH+1))-1:32]});
	     rs_tags_next[IRS_DEPTH:1] = rs_tags_next[IRS_DEPTH:1]                           |
	        (ir2prs_stp_i[1] ? rs_tags_reg[IRS_DEPTH-1:0] : 
		                   {1'b0, rs_tags_reg[IRS_DEPTH:1]});
	     rs_we[IRS_DEPTH:1] = rs_we[IRS_DEPTH:1]                                         | 
                                    {IPS_DEPTH{fsm_update & ir2prs_stp_i[0]}};

	  end // if (ir2prs_sop_i)
	
	//ALU operation
	if (ir2prs_alu_any_i)
	  begin
	     //Stack underflows
	     ps_uf                = ps_uf | 
				    ~ps_tags_reg[0] |
				    (~ps_tags_reg[1] & ir2prs_alu_imm_i);

	     //PS0
	     ps_cells_next[15:0]  = ps_cells_next[15:0]                          |
				    alu2prs_ps0_next_i;
	     ps_tags_next[0]      = 1'b1;
	     ps_we[0]             = fsm_update;
	     
	     //PS1
	     ps_cells_next[15:0]  = ps_cells_next[15:0]                          |
				    alu2prs_ps0_next_i;



	     
				    
	     ps_cells_next[15:0]  = ps_cells_next[15:0]                          |
				    ({16{ir2prs_stp_i[2]}} & rs_cells_reg[15:0]) |
				    ({16{ir2prs_stp_i[3]}} & ps_cells_reg[31:16]);
	     ps_tags_next[0]      = ps_tags_next[0]                              | 
				    ir2prs_stp_i[2]                              |
                                    (ir2prs_stp_i[3] & ps_tags_reg[1]);
             ps_we[0]             = fsm_update & |ir2prs_stp_i[2:3];


  //PS0				 
   assign ps_cells_next[15:0] = rs_cells_reg[15:0]  & {16{ ir2prs_sop_i & ir2prs_stp_i[2]}} | //RS0  -> PS0
                                ps_cells_reg[31:16] & {16{(ir2prs_sop_i & ir2prs_stp_i[3]) |  //PS1  -> PS0
							   ir2prs_store_dir_i          |
							   unpack}}                     |
                                alu2prs_ps0_next_i  & {16{ ir2prs_alu_any_i}}           | //ALU  -> PS0
                                ir2prs_lit_val_i    & {16{ ir2prs_lit_i}}               | //LIT  -> PS0
                                pbus_dat_i          & {16{ ir2prs_fetch_any_i}};          //pbus -> PS0
         

				
   assign ps_tags_next[0]     = (ir2prs_sop_i & ir2prs_stp_i[2])

   assign ps_we[0]            = 

   
   
   //Upper stacks
   reg  [16:0]                             rs0_reg;           //RS0 (TOS)
   reg  [16:0]                             ps0_reg;           //PS0 (TOS)
   reg  [16:0]                             ps1_reg;           //PS1 (TOS+1)
   reg  [16:0]                             ps2_reg;           //PS2 (TOS+2)
   reg  [16:0]                             ps3_reg;           //PS3 (TOS+3)
   wire                                    rs0_next;          //RS0 input
   wire                                    ps0_next;          //PS0 input
   wire                                    ps1_next;          //PS1 input
   wire                                    ps2_next;          //PS2 input
   wire                                    ps3_next;          //PS3 input
   reg                                     rs0_tag_reg;       //RS0 tag
   reg                                     ps0_tag_reg;       //PS0 tag
   reg                                     ps1_tag_reg;       //PS1 tag
   reg                                     ps2_tag_reg;       //PS2 tag
   reg                                     ps3_tag_reg;       //PS3 tag
   wire                                    rs0_tag_next;      //RS0 tag input
   wire                                    ps0_tag_next;      //PS0 tag input
   wire                                    ps1_tag_next;      //PS1 tag input
   wire                                    ps2_tag_next;      //PS2 tag input
   wire                                    ps3_tag_next;      //PS3 tag input
   wire                                    rs0_we;            //RS0 write enable
   wire                                    ps0_we;            //PS0 write enable
   wire                                    ps1_we;            //PS1 write enable
   wire                                    ps2_we;            //PS2 write enable
   wire                                    ps3_we;            //PS3 write enable

   //Intermediate parameter stack
   reg  [16:0]                             ps4_reg;           //RS0 (TOS)
   reg  [16:0]                             ps4_tag_reg;           //RS0 (TOS)
   




   reg  [(16*IPS_DEPTH)-1:0] 		   ips_reg;           //cells
   reg  [(16*IPS_DEPTH)-1:0] 		   ips_next;          //cell inputs
   reg  [IPS_DEPTH-1:0] 		   ips_tag_reg;       //tags
   reg  [IPS_DEPTH-1:0] 		   ips_tag_next;      //tag inputs
   reg  [IPS_DEPTH-1:0] 		   ips_tag_we;        //write enables
   
   //Intermediate return stack
   reg  [(16*IRS_DEPTH)-1:0] 		   irs_reg;           //cells
   reg  [(16*IRS_DEPTH)-1:0] 		   irs_next;          //cell inputs
   reg  [IRS_DEPTH-1:0] 		   irs_tag_reg;       //tags
   reg  [IRS_DEPTH-1:0] 		   irs_tag_next;      //tag inputs
   reg  [IRS_DEPTH-1:0] 		   irs_tag_we;        //write enables
   
   //Finite state machine
   reg [3:0] 				   state_reg;         //state variable
   reg [3:0] 				   state_next;        //next state
   

   




   
   //Upper stack connectivity
   //------------------------
   //RS0
   assign rs0_next     = (irs_reg[15:0]      & {16{}}) |
                         (ps0_reg            & {16{}}) |
                         (fc2prs_pc_next_i   & {16{}});

   assign rs0_tag_next = (irs_tag_reg[0]     & ()) |
                         (ps0_tag_reg        & ()) |
 					       ();

   assign rs0_we       = ;  		 
					 
   //PS0				 
   assign ps0_next     = (ps1_reg            & {16{}}) |
                         (rs0_reg            & {16{}}) | 
                           (pbus_dat_i         & {16{}}) | 
                         (alu2prs_ps0_next_i & {16{}}) | 
                         (ir2prs_lit_val_i   & {16{}});

   assign ps0_tag_next = (ps1_tag_reg        & ()) |
                         (rs0_tag_reg        & ()) |
   					       ()  |
   					       ()  |
 					       ();
  
   assign ps0_we       = ;  		 
					 
   //PS1 input
   assign ps1_next     = (ps2_reg            & {16{}}) |
                         (ps0_reg            & {16{}}) |
                         (alu2prs_ps1_next_i & {16{}}); 

   assign ps1_tag_next = (ps2_tag_reg        & ()) |
                         (ps0_tag_reg        & ()) |
 					       ();
   assign ps1_we       = ;  		 
					 
   //PS2 input
   assign ps2_next     = (ps3_reg            & {16{}}) |
                         (ps1_reg            & {16{}}) |;
		       
   assign ps2_tag_next = (ps3_tag_reg        & ()) |
                         (ps1_tag_reg        & ()) |
 					       ();
   assign ps2_we       = ;  		 
		       			 
   //PS3 input	       
   assign ps3_next     = (ips_reg[15:0]      & {16{}}) |
                         (ps2_reg            & {16{}}) |;
    
   assign ps3_tag_next = (ips_tag_reg[0]     & ()) |
                         (ps3_tag_reg        & ()) |
 				 	       (); 			 
   assign ps2_we       = ;  		 
		       			 









   
   
   //Upper stack flipflops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       begin
	  rs0_reg     <= 16'h0000;                            //RS0 (TOS)
	  ps0_reg     <= 16'h0000;                            //PS0 (TOS)
	  ps1_reg     <= 16'h0000;                            //PS1 (TOS+1)
	  ps2_reg     <= 16'h0000;                            //PS2 (TOS+2)
          ps3_reg     <= 16'h0000;                            //PS3 (TOS+3)
          rs0_tag_reg <= 1'b0;                                //RS0 tag
          ps0_tag_reg <= 1'b0;                                //PS0 tag
          ps1_tag_reg <= 1'b0;                                //PS1 tag
          ps2_tag_reg <= 1'b0;                                //PS2 tag
          ps3_tag_reg <= 1'b0;                                //PS3 tag
       end
     else if (sync_rst_i)                                     //synchronous reset
       begin
	  rs0_reg     <= 16'h0000;                            //RS0 (TOS)
	  ps0_reg     <= 16'h0000;                            //PS0 (TOS)
	  ps1_reg     <= 16'h0000;                            //PS1 (TOS+1)
	  ps2_reg     <= 16'h0000;                            //PS2 (TOS+2)
          ps3_reg     <= 16'h0000;                            //PS3 (TOS+3)
          rs0_tag_reg <= 1'b0;                                //RS0 tag
          ps0_tag_reg <= 1'b0;                                //PS0 tag
          ps1_tag_reg <= 1'b0;                                //PS1 tag
          ps2_tag_reg <= 1'b0;                                //PS2 tag
          ps3_tag_reg <= 1'b0;                                //PS3 tag
       end
     else
       begin
	  if (rs0_we)     rs0_reg     <= rs0_next;            //RS0 (TOS)
	  if (ps0_we)     ps0_reg     <= ps0_next;            //PS0 (TOS)
	  if (ps1_we)     ps1_reg     <= ps1_next;            //PS1 (TOS+1)
	  if (ps2_we)     ps2_reg     <= ps2_next;            //PS2 (TOS+2)
          if (ps3_we)     ps3_reg     <= ps3_next;            //PS3 (TOS+3)
          if (rs0_tag_we) rs0_tag_reg <= rs0_tag_next;        //RS0 tag
          if (ps0_tag_we) ps0_tag_reg <= ps0_tag_next;        //PS0 tag
          if (ps1_tag_we) ps1_tag_reg <= ps1_tag_next;        //PS1 tag
          if (ps2_tag_we) ps2_tag_reg <= ps2_tag_next;        //PS2 tag
          if (ps3_tag_we) ps3_tag_reg <= ps3_tag_next;        //PS3 tag
       end
	  
   //Intermediate parameter stack flip flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       begin
	  ips_reg     <= {IPS_DEPTH{16'h0000}};               //cells
          ips_tag_reg <= {IPS_DEPTH{1'b0}};                   //tags
       end
     else if (sync_rst_i)                                     //synchronous reset
       begin
	  ips_reg     <= {IPS_DEPTH{16'h0000}};               //cells
          ips_tag_reg <= {IPS_DEPTH{1'b0}};                   //tags
       end
     else
       begin
	  for (i=0; i<(16*IPS_DEPTH); i=i+1)                  //cells
	    if (ips_we[i/16]) ips_reg[i] <= ips_next[i];      //
	  for (i=0; i<IPS_DEPTH); i=i+1)                      //tags
	    if (ips_we[i]) ips_tag_reg[i] <= ips_tag_next[i]; //
       end
   
   //Intermediate return stack flip flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       begin
	  irs_reg     <= {IRS_DEPTH{16'h0000}};               //cells
          irs_tag_reg <= {IRS_DEPTH{1'b0}};                   //tags
       end
     else if (sync_rst_i)                                     //synchronous reset
       begin
	  irs_reg     <= {IRS_DEPTH{16'h0000}};               //cells
          irs_tag_reg <= {IRS_DEPTH{1'b0}};                   //tags
       end
     else
       begin
	  for (i=0; i<(16*IRS_DEPTH); i=i+1)                  //cells
	    if (irs_we[i/16]) irs_reg[i] <= irs_next[i];      //
	  for (i=0; i<IRS_DEPTH); i=i+1)                      //tags
	    if (irs_we[i]) irs_tag_reg[i] <= irs_tag_next[i]; //
       end
   
   //Finite state machine flip flops
   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                         //asynchronous reset
       state_reg <= STATE_RESET;
     else if (sync_rst_i)                                     //synchronous reset
       state_reg <= STATE_RESET;
     else                                                     //state transition
       state_reg <= state_next;

endmodule // N1_prs
