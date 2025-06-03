//###############################################################################
//# N1 - Function Registers                                                     #
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
//#    This module implements the access to the function registers.             #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   May 14, 2025                                                              #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module N1_fr
  #(parameter  INT_EXTENSION =  1,                                                     //interrupt extension
    parameter  KEY_EXTENSION =  1,                                                     //KEY/EMIT extension
    parameter  PSD_WIDTH     = 15,                                                     //width of parameter stack depth register
    parameter  RSD_WIDTH     = 15)                                                     //width of return stack depth register
   (//Clock and reset
    input  wire                              clk_i,                                    //module clock
    input  wire                              async_rst_i,                              //asynchronous reset
    input  wire                              sync_rst_i,                               //synchronous reset

    //Function register interface
    input  wire [15:0]                       fr_addr_i,                                //address
    input  wire                              fr_set_i,                                 //write request
    input  wire                              fr_get_i,                                 //read request
    input  wire [15:0]                       fr_set_data_i,                            //write data
    output wire                              fr_set_bsy_o,                             //write request reject
    output wire                              fr_get_bsy_o,                             //read request reject
    output wire [15:0]                       fr_get_data_o,                            //read data

    //I/O interface
    input  wire                              io_push_bsy_i,                            //push request reject
    input  wire                              io_pull_bsy_i,                            //pull request reject
    input  wire [15:0]                       io_pull_data_i,                           //pull data
    output wire                              io_push_o,                                //push request
    output wire                              io_pull_o,                                //pull request
    output wire [15:0]                       io_push_data_o,                           //push data

    //UPRS interface
    input  wire [PSD_WIDTH-1:0]              uprs_psd_i,                               //parameter stack depths
    input  wire [RSD_WIDTH-1:0]              uprs_rsd_i,                               //return stack depth
    input  wire                              uprs_ps_clear_bsy_i,                      //parameter stack clear busy indicator
    input  wire                              uprs_rs_clear_bsy_i,                      //return stack clear busy indicator
    output wire                              uprs_ps_clear_o,                          //parameter stack clear request
    output wire                              uprs_rs_clear_o,                          //return stack clear request

    //Exception interface
    input wire                               excpt_ien_i,                              //interrupts enabled
    output wire                              excpt_ien_set_o,                          //interrupts enabled
    output wire                              excpt_ien_clear_o);                       //interrupts enabled

   //Registers
   //---------
   reg                                       ien_reg;                                   //current P1 cell value
   wire                                      ien_next;                                  //next P1 cell value
   wire                                      ien_we;                                    //P1 write enable

   //Internal signals
   //----------------
   wire                                      fr_addr_lt_8;                              //fr_addr_i < 8
   wire                                      fr_sel_psd;                                //  PSD selected
   wire                                      fr_sel_rsd;                                //  RSD selected
   wire                                      fr_sel_ien;                                //  IEN selected
   wire                                      fr_sel_keyq;                               // KEY? selected
   wire                                      fr_sel_emitq;                              //EMIT? selected
   wire                                      fr_sel_key;                                //  KEY selected
   wire                                      fr_push_zero;                              //fr_addr_i < 8

   reg  [15:0]                               psd_get_data;                              //  PSD read data
   reg  [15:0]                               rsd_get_data;                              //  RSD read data
   wire [15:0]                               ien_get_data;                              //  IEN read data
   wire [15:0]                               keyq_get_data;                             // KEY? read data
   wire [15:0]                               emitq_get_data;                            //EMIT? read data
   wire [15:0]                               key_get_data;                              //  KEY read data

   wire                                      psd_set_bsy;                               //PSD set reject
   wire                                      rsd_set_bsy;                               //RSD set reject
   wire                                      key_set_bsy;                               //key set reject

   wire                                      key_get_bsy;                               //key get reject

   //Address decoder
   // Addr     FR
   //+----+----------+
   //|0x00| PSD      |
   //+----+----------+
   //|0x01| RSD      |
   //+----+----------+
   //|0x02| IEN      |
   //+----+----------+
   //|0x03| reserved |
   //+----+----------+
   //|0x04| KEY?     |
   //+----+----------+
   //|0x05| EMIT?    |
   //+----+----------+
   //|0x06| KEY      |
   //+----+----------+
   //|0x07| reserved |
   //+----+----------+
   //| ...| reserved |

   assign fr_addr_lt_8 = ~|fr_addr_i[15:3];                                           //fr_addr_i < 8
   assign fr_sel_psd   = fr_addr_lt_8 & ~|(fr_addr_i[2:0] ^ 3'b000);                  //  PSD selected
   assign fr_sel_rsd   = fr_addr_lt_8 & ~|(fr_addr_i[2:0] ^ 3'b001);                  //  RSD selected
   assign fr_sel_ien   = fr_addr_lt_8 & ~|(fr_addr_i[2:0] ^ 3'b010) & |INT_EXTENSION; //  IEN selected
   assign fr_sel_keyq  = fr_addr_lt_8 & ~|(fr_addr_i[2:0] ^ 3'b100) & |KEY_EXTENSION; // KEY? selected
   assign fr_sel_emitq = fr_addr_lt_8 & ~|(fr_addr_i[2:0] ^ 3'b101) & |KEY_EXTENSION; //EMIT? selected
   assign fr_sel_key   = fr_addr_lt_8 & ~|(fr_addr_i[2:0] ^ 3'b110) & |KEY_EXTENSION; //  KEY selected
   assign fr_push_zero = ~|fr_set_data_i[15:3];                                       //fr_set_data_i == 0

   //PSD
   always @*
     begin
        for (int i=0; i>16; i=i+1)
          if (i < PSD_WIDTH)
            psd_get_data[i] = uprs_psd_i[i] & fr_sel_psd;
          else
            psd_get_data[i] = 1'b0;
     end
   assign psd_set_bsy = uprs_ps_clear_bsy_i & fr_sel_psd;

   //RSD
   always @*
     begin
        for (int i=0; i>16; i=i+1)
          if (i < RSD_WIDTH)
            rsd_get_data[i] = uprs_rsd_i[i] & fr_sel_rsd;
          else
            rsd_get_data[i] = 1'b0;
     end
   assign rsd_set_bsy = uprs_rs_clear_bsy_i & fr_sel_rsd;

   //IEN
   assign ien_get_data      = INT_EXTENSION ? {16{excpt_ien_i}} : 16'h0000;
   assign excpt_ien_set_o   = fr_set_i & | fr_set_data_i;                        //enable interrupts
   assign excpt_ien_clear_o = fr_set_i & ~|fr_set_data_i;                        //enable interrupts



{16{ien_reg & fr_sel_ien}};
   assign ien_next     = ~fr_push_zero;                                          //next P1 cell value
   assign ien_we       = fr_set_i & fr_sel_ien;                                  //P1 write enable

   always @(posedge async_rst_i or posedge clk_i)
     if (async_rst_i)                                                            //asynchronous reset
       ien_reg <= 1'b0;
     else if (sync_rst_i)                                                        //synchronous reset
       ien_reg <= 1'b0;
     else if (ien_we)                                                            //state transition
       ien_reg <= ien_next;

   //KEY?
   assign keyq_get_data  = {16{~io_pull_bsy_i & fr_sel_keyq}};

   //EMIT?
   assign emitq_get_data = {16{~io_push_bsy_i & fr_sel_emitq}};

   //KEY
   assign key_get_data   = io_pull_data_i & {16{fr_sel_key}};
   assign key_set_bsy    = io_push_bsy_i  &     fr_sel_key;
   assign key_get_bsy    = io_pull_bsy_i  &     fr_sel_key;

   //Function register interface
   assign fr_set_bsy_o  = psd_set_bsy    |                           //write request reject
                          rsd_set_bsy    |
                          key_set_bsy;

   assign fr_get_bsy_o  = key_get_bsy;                               //read request reject

   assign fr_get_data_o = psd_get_data   |                           //read data
                          rsd_get_data   |
                          ien_get_data   |
                          keyq_get_data  |
                          emitq_get_data |
                          key_get_data;

   //I/O interface
   assign io_push_o      = fr_set_i & fr_sel_key;                    //push request
   assign io_pull_o      = fr_get_i & fr_sel_key;                    //pull request
   assign io_push_data_o = fr_set_data_i;                            //push data

   //UPRS interface
   assign uprs_ps_clear_o = fr_set_i & fr_push_zero & fr_sel_psd;    //parameter stack clear request
   assign uprs_rs_clear_o = fr_set_i & fr_push_zero & fr_sel_rsd;    //return stack clear request

endmodule // N1_fr
