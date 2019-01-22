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
  #(localparam CELL_WIDTH     = 16,   //cell width
    localparam OPERATOR_WIDTH = 5,    //width of the operator field
    localparam IMMOP_WIDTH    = 5)    //width of immediate values
 
   (//Clock and reset
    //---------------
    //input wire                           clk_i,            //module clock
    //input wire                           async_rst_i,      //asynchronous reset
    //input wire                           sync_rst_i,       //synchronous reset

    //IR interface				            
    output wire [OPERATOR_WIDTH-1:0] ir_alu_operator,        //ALU operator
    output wire [IMMOP_WIDTH:0]      ir_alu_immop,           //immediade operand
 
    


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
    output wire 		     hip_alu_add_o, //op1 + op0
    output wire 		     hip_alu_sub_o, //op1 - op0
    output wire 		     hip_alu_umul_o, //op1 * op0 (unsigned)
    output wire 		     hip_alu_smul_o, //op1 * op0 (signed)
    output wire [CELL_WIDTH-1:0]     hip_alu_op0_o, //first operand
    output wire [CELL_WIDTH-1:0]     hip_alu_op1_o, //second operand
    input wire [(2*CELL_WIDTH)-1:0]  hip_alu_i,             //result


    

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
   //Immediate operands 
   wire [CELL_WIDTH-1:0] uimm = {{  CELL_WIDTH-IMMOP_WIDTH{1'b0}},                         ir_alu_immop}; //unsigned immediate operand
   wire [CELL_WIDTH-1:0] simm = {{1+CELL_WIDTH-IMMOP_WIDTH{ ir_alu_immop[IMMOP_WIDTH-1]}}, ir_alu_immop}; //signed immediate operand
   wire [CELL_WIDTH-1:0] oimm = {{1+CELL_WIDTH-IMMOP_WIDTH{~ir_alu_immop[IMMOP_WIDTH-1}},  ir_alu_immop}; //unsigned immediate operand
   wire                  imm_is_zero = ~|ir_alu_immop;                                                 //immediate operand is zero

   //Operators
   wire                  opr_add  = ~|(ir_alu_operator ^ ALU_ADD);  //addition
   wire                  opr_sub  = ~|(ir_alu_operator ^ ALU_SUB);  //subtracttion
   wire                  opr_umul = ~|(ir_alu_operator ^ ALU_UMUL); //unsigned multiplication
   wire                  opr_smul = ~|(ir_alu_operator ^ ALU_SMUL); //signed multiplication
   wire                  opr_and  = ~|(ir_alu_operator ^ ALU_AND);  //logic AND
   wire                  opr_or   = ~|(ir_alu_operator ^ ALU_OR);   //logic OR
   wire                  opr_xor  = ~|(ir_alu_operator ^ ALU_XOR);  //logic XOR
   wire                  opr_neg  = ~|(ir_alu_operator ^ ALU_NEG);  //2's complement
   wire                  opr_lsr  = ~|(ir_alu_operator ^ ALU_LSR);  //logic right shift
   wire                  opr_asr  = ~|(ir_alu_operator ^ ALU_ASR);  //arithmetic right shift
   wire                  opr_lsl  = ~|(ir_alu_operator ^ ALU_LSL);  //logic left shift



   //Immediate operands 
   assign uimm        = {{  CELL_WIDTH-IMMOP_WIDTH{1'b0}},                         ir_alu_immop}; //unsigned immediate operand
   assign simm        = {{1+CELL_WIDTH-IMMOP_WIDTH{ ir_alu_immop[IMMOP_WIDTH-1]}}, ir_alu_immop[IMMOP_WIDTH-2:0]}; //signed immediate operand
   assign oimm        = {{1+CELL_WIDTH-IMMOP_WIDTH{~ir_alu_immop[IMMOP_WIDTH-1}},  ir_alu_immop[IMMOP_WIDTH-2:0]}; //unsigned immediate operand
   assign imm_is_zero = ~|ir_alu_immop;                                                 //immediate operand is zero

   //Operators
   assign opr_add     = ~|(ir_alu_operator ^ ALU_ADD);  //addition
   assign opr_sub     = ~|(ir_alu_operator ^ ALU_SUB);  //subtracttion
   assign opr_umul    = ~|(ir_alu_operator ^ ALU_UMUL); //unsigned multiplication
   assign opr_smul    = ~|(ir_alu_operator ^ ALU_SMUL); //signed multiplication
   assign opr_and     = ~|(ir_alu_operator ^ ALU_AND);  //logic AND
   assign opr_or      = ~|(ir_alu_operator ^ ALU_OR);   //logic OR
   assign opr_xor     = ~|(ir_alu_operator ^ ALU_XOR);  //logic XOR
   assign opr_neg     = ~|(ir_alu_operator ^ ALU_NEG);  //2's complement
   assign opr_lsr     = ~|(ir_alu_operator ^ ALU_LSR);  //logic right shift
   assign opr_asr     = ~|(ir_alu_operator ^ ALU_ASR);  //arithmetic right shift
   assign opr_lsl     = ~|(ir_alu_operator ^ ALU_LSL);  //logic left shift


















   //Hard IP interface (adders and multipliers)
   //Adder/Subtractor:
   //  PS0 + uimm
   //  PS1 + PS0
   //  PS0 - uimm
   //  PS1 - PS0
   //    0 - PS0  
   assign alu_add_o     = opr_add;                                     //op1 + op0
   assign alu_sub_o     = opr_sub |opr_neg;                            //op1 - op0
   assign alu_add_op1_o = opr_add |opr_sub  ?                          //op1 is zero
			  (imm_is_zero       ? us_ps1_i : us_ps0_i) :  // if no operator
                          {CELL_WIDTH{1'b0}};                          // is selected
   assign alu_add_op0_o = ~imm_is_zero | opr_neg ? us_ps0_i : uimm;        //op0
   //Multipliers:
   //  PS0 * uimm (unsigned)
   //  PS0 * PS1  (unsigned)
   //  PS0 * simm (signed)
   //  PS0 * PS1  (signed)
   assign alu_umul_o    = opr_umul;                                    //op1 * op0 (unsigned)
   assign alu_smul_o    = opr_smul;                                    //op1 * op0 (signed)
   assign alu_mul_op1_o = opr_umul | opr_smul ? us_ps1_i :             //op1 is zero if no
			                        {CELL_WIDTH{1'b0}};    // operator is selected
   assign alu_mul_op0_o =  imm_is_zero ? us_ps0_i :                    //op0      
			   (opr_smul   ? simm : uimm);                 //

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
