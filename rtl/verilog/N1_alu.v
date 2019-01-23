//###############################################################################
//# N1 - Arithmetic Logic Unit                                                  #
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
//#    This module implements the N1's Arithmetic logic unit (ALU). The         #
//#    following operations are supported:                                      #
//#    op1   *    op0                                                           #
//#    op1   +    op0                                                           #
//#    op1   -    op0  or op0    -   imm                                        #
//#    op1  AND   op0                                                           #
//#    op1 LSHIFT op0     op0 LSHIFT imm                                        #
//#                                                                             #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   December 4, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_alu
  #(localparam CELL_WIDTH  = 16,   //cell width
    localparam OPR_WIDTH   = 5,    //width of the operator field
    localparam IMMOP_WIDTH = 5)    //width of immediate values
 
   (//Clock and reset
    //---------------
    //input wire                           clk_i,            //module clock
    //input wire                           async_rst_i,      //asynchronous reset
    //input wire                           sync_rst_i,       //synchronous reset

    //IR interface				            
    output wire [OPERATOR_WIDTH-1:0] ir_alu_opr_i,        //ALU operator
    output wire [IMMOP_WIDTH:0]      ir_alu_immop_i,           //immediade operand
 
    


    //Upper stack interface
    output wire [CELL_WIDTH:0] 	     us_ps0_o,               //PS0 (TOS)
    output wire [CELL_WIDTH:0] 	     us_ps1_o,               //PS1 (TOS+1)
     							      
   
    
    






    
    //Interface to the upper stacks
    //-----------------------------
    input wire [3:0] 		     ps_stat_up_i, //stack status
    input wire [CELL_WIDTH-1:0]      alu_op0_i, //1st operand
    input wire [CELL_WIDTH-1:0]      alu_op1_i, //2nd operand
    output wire [(2*CELL_WIDTH)-1:0] alu_res_o, //result

    //Interface to the intermediate stacks
    //------------------------------------
    input wire [ISTACK_DEPTH-1:0]    ps_stat__im_i, //stack status

    //Interface to the lower stacks
    //-----------------------------
    input wire [SBUS_ADR_WIDTH-1:0]  ps_stat_lo_i, //stack status

    

    
    //Hard IP interface		     
    output wire 		     alu_hm_add_o,           //op1 + op0
    output wire 		     alu_hm_sub_o,           //op1 - op0
    output wire 		     alu_hm_umul_o,          //op1 * op0 (unsigned)
    output wire 		     alu_hm_smul_o,          //op1 * op0 (signed)
    output wire [CELL_WIDTH-1:0]     alu_hm_add_op0_o,       //first operand for adder
    output wire [CELL_WIDTH-1:0]     alu_hm_add_op1_o,       //second operand for adder
    output wire [CELL_WIDTH-1:0]     alu_hm_mul_op0_o,       //first operand for multiplier
    output wire [CELL_WIDTH-1:0]     alu_hm_mul_op1_o,       //second operand for multiplier
    input wire  [(2*CELL_WIDTH)-1:0] alu_hm_add_i,           //result from adder
    input wire  [(2*CELL_WIDTH)-1:0] alu_hm_mul_i,           //result from multiplier


    

    ); 

   //Operator encoding
   //-----------------  
   localparam ALU_ADD          = 5'b0000;
   localparam ALU_SUB          = 5'b0000;
   localparam ALU_UMUL         = 5'b0000;
   localparam ALU_SMUL         = 5'b0000;
   localparam ALU_AND          = 5'b0000;
   localparam ALU_OR           = 5'b0000;
   localparam ALU_XOR          = 5'b0000;
   localparam ALU_ADD          = 5'b0000;
   localparam ALU_ADD          = 5'b0000;
   
      
   //Internal signals
   //----------------  
   //Intermediate operands
   wire                      imm_is_zero;                    //immediate operand is zero
   wire [CELL_WIDTH-1:0]     uimm;                           //unsigned immediate operand   (1..31)
   wire [CELL_WIDTH-1:0]     simm;                           //signed immediate operand   (-16..-1,1..15)
   wire [CELL_WIDTH-1:0]     oimm;                           //shifted immediate oprtand  (-15..15)
   //Adder
   wire [(2*CELL_WIDTH)-1:0] add_out;                        //adder output
   //Comparator
   wire                      cmp_eq;                         //equals comparator output		     
   wire                      cmp_neq;                        //not-equals comparator output          
   wire                      cmp_lt_unsig;                   //unsigned lower_than comparator output 
   wire                      cmp_gt_sig                      //signed greater-than comparator output 
   wire                      cmp_gt_unsig;                   //unsigned greater_than comparator output
   wire                      cmp_lt_sig;                     //signed lower-than comparator output   
   wire                      cmp_eq;                         //equals comparator output		     
   wire                      cmp_neq;                        //not-equals comparator output          
   wire                      cmp_mexed;                      //multiplexed comparator outputs          
   wire [(2*CELL_WIDTH)-1:0] cmp_out;                        //comparator output   
   //Multiplier
   wire [(2*CELL_WIDTH)-1:0] mul_out;                        //multiplier output

  
 

   //Immediate operands
   //------------------  
   assign imm_is_zero = ~|ir_alu_immop;                                                                            //immediate operand is zero
   assign uimm        = {{  CELL_WIDTH-IMMOP_WIDTH{1'b0}},                         ir_alu_immop};                  //unsigned immediate operand   (1..31)
   assign simm        = {{1+CELL_WIDTH-IMMOP_WIDTH{ ir_alu_immop[IMMOP_WIDTH-1]}}, ir_alu_immop[IMMOP_WIDTH-2:0]}; //signed immediate operand   (-16..-1,1..15)
   assign oimm        = {{1+CELL_WIDTH-IMMOP_WIDTH{~ir_alu_immop[IMMOP_WIDTH-1}},  ir_alu_immop[IMMOP_WIDTH-2:0]}; //shifted immediate oprtand  (-15..15)

   //Hard IP adder
   //-------------
   //Inputs
   assign alu_hw_sub_add_b_o = |ir_alu_opr_i[3:1];           //0:op1 + op0, 1:op1 + op0 
   assign alu_hw_add_op0_o   = ir_alu_opr_i[0] ? (imm_is_zero ? us_ps0_i : oimm) :
                                                 (imm_is_zero ? us_ps1_i : us_ps0_i);
   assign alu_hw_add_op1_o   = ir_alu_opr_i[0] ? (imm_is_zero ? us_ps1_i : us_ps0_i) :
                                                 (imm_is_zero ? us_ps0_i : uimm);
   //Result
   assign add_out            = ~|ir_alu_opr_i[4:2] ? {{CELL_WIDTH{alu_hw_add_i[CELL_WIDTH]}}, alu_hw_add_i[CELL_WIDTH-1:0]} :
                                                     {2*CELL_WIDTH{1'b0}};

   //Comparator
   //----------
   assign cmp_eq          = ~|alu_hw_add_i[CELL_WIDTH-1:0];  //equals comparator output		     
   assign cmp_neq         = ~cmp_eq;                         //not-equals comparator output          
   assign cmp_lt_unsig    =   alu_hw_add_i[CELL_WIDTH];	     //unsigned lower_than comparator output 
   assign cmp_gt_sig      =   alu_hw_add_i[CELL_WIDTH-1];    //signed greater-than comparator output 
   assign cmp_gt_unsig    =   ~|{lt_unsig, cmp_eq};          //unsigned greater_than comparator output
   assign cmp_lt_sig      =   ~|{gt_sig,   cmp_eq};          //signed lower-than comparator output   
   assign cmp_muxed       = (&{ir_alu_opr_i^5'b11011}                &  cmp_lt_unsig) |
                            (&{ir_alu_opr_i^5'b11010}                &  cmp_gt_sig)   |
                            (&{ir_alu_opr_i^5'b11001}                &  cmp_gt_unsig) |
                            (&{ir_alu_opr_i^5'b11000}                &  cmp_lt_sig)   |
                            (&{ir_alu_opr_i[CELL_WIDTH-1:1]^4'b1011} &  cmp_eq)       |
                            (&{ir_alu_opr_i[CELL_WIDTH-1:1]^4'b1010} &  cmp_neq);
   assign cmp_our         = {2*CELL_WIDTH{cmp_muxed}};

   //Hard IP multiplier
   //------------------
   //Inputs
   assign alu_smul_umul_b_0 = ir_alu_opr_i[1];;              //0:signed, 1:unsigned
   assign alu_add_op0_o     = &{ir_alu_opr_i[4:2]^3'b100) ? us_ps0_i : {CELL_WIDTH{1'b0}};
   assign alu_add_op1_o     = imm_is_zero ? us_ps1_i :
                              (ir_alu_opr_i[0] ?  simm : uimm);           
   //Result
   assign mul_out           = alu_hw_mul_i;





   //Bitwise logic
   //AND
   wire [CELL_WIDTH-1:0]     op0_and = opr_and ? us_ps0_i :            //first operand
			                         {CELL_WIDTH{1'b0}};   //
   wire [CELL_WIDTH-1:0]     op1_and = imm_is_zero ? us_ps1_i :        //second operand
			                             simm;             //
   wire [(2*CELL_WIDTH)-1:0] res_and =  {{CELL_WIDTH{1'b0}},           //result
                                         op0_and & op1_and};           //      
   //OR
   wire [CELL_WIDTH-1:0]     op0_or  = us_ps0_i;                       //first operand
   wire [CELL_WIDTH-1:0]     op1_or  = imm_is_zero ? us_ps1_i :        //second operand
			                             uimm;             //
   wire [(2*CELL_WIDTH)-1:0] res_or  =  {{CELL_WIDTH{1'b0}},           //result
					 (opr_or ?		       //   			 
                                            (op0_and & op1_and) :      //      
                                            {CELL_WIDTH{1'b0}})};      //
   //XOR
   wire [CELL_WIDTH-1:0]     op0_xor = us_ps0_i;                       //first operand
   wire [CELL_WIDTH-1:0]     op1_xor = imm_is_zero ? us_ps1_i :        //second operand
			                             simm;             //
   wire [(2*CELL_WIDTH)-1:0] res_xor =  {{CELL_WIDTH{1'b0}},           //result
					 (opr_xor ?		       //   			 
                                            (op0_and & op1_and) :      //      
                                            {CELL_WIDTH{1'b0}})};      //
   
   //Barrel shifter
   //Right shift
   wire [CELL_WIDTH-1:0]     op0_lsr = us_ps0_i;                       //first operand
   wire [CELL_WIDTH-1:0]     op1_lsr = imm_is_zero ? us_ps1_i :        //second operand
			                             uimm;             //
   wire                      msb_lsr = opr_asr ? op0_lsr[CELL_WIDTH] : //MSB of first operand
			                         1'b0;                 //
   wire [CELL_WIDTH-1:0]     sh0_lsr = op1_lsr[0] ?                    //shift 1 bit
 			               {msb_lsr,                       //
					op0_lsr[CELL_WIDTH-1:1]} :     //
			               op0_lsr;                        //
   wire [CELL_WIDTH-1:0]     sh1_lsr = op1_lsr[1] ?                    //shift 2 bits
 			               {{2{msb_lsr}},                  //
					sh0_lsr[CELL_WIDTH-1:2]} :     //
			                sh0_lsr;                       //
   wire [CELL_WIDTH-1:0]     sh2_lsr = op1_lsr[2] ?                    //shift 4 bits
 			               {{4{msb_lsr}},                  //
					sh1_lsr[CELL_WIDTH-1:4]} :     //
			                sh1_lsr;                       //
   wire [CELL_WIDTH-1:0]     sh3_lsr = op1_lsr[3] ?                    //shift 8 bits
 			               {{8{msb_lsr}},                  //
					sh2_lsr[CELL_WIDTH-1:8]} :     //
			                sh2_lsr;                       //
   wire [CELL_WIDTH-1:0]     sh4_lsr = |op1_lsr[5:4] ?                 //shift 16 bits
 			               {16{msb_lsr}} :                 //
			                sh3_lsr;                       //   
   wire [(2*CELL_WIDTH)-1:0] res_lsr = {{CELL_WIDTH{1'b0}},            //result
                                        ((opr_lsr | opr_asr) ?         //
					 sh4_lsr : {CELL_WIDTH{1'b0}}};//
   //Left shift
   wire [CELL_WIDTH-1:0]     op0_lsl = us_ps0_i;                       //first operand
   wire [CELL_WIDTH-1:0]     op1_lsl = imm_is_zero ? us_ps1_i :        //second operand
			                             uimm;             //
   
   wire [(2*CELL_WIDTH)-1:0] sh0_lsl = op1_lsl[0] ?                    //shift 1 bit
                                       {{CELL_WIDTH-1{1'b0}},          //
                                         op0_lsl, 1'b0} :              //
                                       {{CELL_WIDTH{1'b0}}, op0_lsl};  //
   wire [(2*CELL_WIDTH)-1:0] sh1_lsl = op1_lsl[1] ?                    //shift 2 bits
                                       {sh0_lsl[(2*CELL_WIDTH)-3:0],   //
                                        2'b0} :                        //
                                       sh0_lsl;                        //
   wire [(2*CELL_WIDTH)-1:0] sh2_lsl = op1_lsl[2] ?                    //shift 4 bits
                                       {sh0_lsl[(2*CELL_WIDTH)-5:0],   //
                                        4'h0} :                        //
                                       sh1_lsl;                        //
   wire [(2*CELL_WIDTH)-1:0] sh3_lsl = op1_lsl[3] ?                    //shift 8 bits
                                       {sh0_lsl[(2*CELL_WIDTH)-9:0],   //
                                        8'h00} :                       //
                                       sh2_lsl;                        //
   wire [(2*CELL_WIDTH)-1:0] sh3_lsl = op1_lsl[5] ?                    //shift 16 bits
                                       {sh0_lsl[(2*CELL_WIDTH)-16:0],  //
                                        16'h0000} :                    //
                                       sh3_lsl;                        //
   wire [(2*CELL_WIDTH)-1:0] sh4_lsl = (~opr_lsl | op1_lsl[5]) ?       //shift 32 bits
                                       32'h00000000 :                  //
                                       sh3_lsl;                        //

   //Comparisons


   


endmodule // N1_alu
