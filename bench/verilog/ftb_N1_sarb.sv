//###############################################################################
//# WbXbc - Formal Testbench - Bus Arbiter                                      #
//###############################################################################
//#    Copyright 2018 Dirk Heisswolf                                            #
//#    This file is part of the WbXbc project.                                  #
//#                                                                             #
//#    WbXbc is free software: you can redistribute it and/or modify            #
//#    it under the terms of the GNU General Public License as published by     #
//#    the Free Software Foundation, either version 3 of the License, or        #
//#    (at your option) any later version.                                      #
//#                                                                             #
//#    WbXbc is distributed in the hope that it will be useful,                 #
//#    but WITHOUT ANY WARRANTY; without even the implied warranty of           #
//#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
//#    GNU General Public License for more details.                             #
//#                                                                             #
//#    You should have received a copy of the GNU General Public License        #
//#    along with WbXbc.  If not, see <http://www.gnu.org/licenses/>.           #
//###############################################################################
//# Description:                                                                #
//#    This is the the formal testbench for the WbXbc_arbiter component.        #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   October 16, 2018                                                          #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

//DUT configuration
//=================
//Default configuration
//---------------------
`ifdef CONF_DEFAULT
`endif

//Fall back
//---------
`ifndef ITR_CNT
`define ITR_CNT     4
`endif
`ifndef ADR_WIDTH
`define ADR_WIDTH   16
`endif
`ifndef DAT_WIDTH
`define DAT_WIDTH   16
`endif
`ifndef SEL_WIDTH
`define SEL_WIDTH   2
`endif
`ifndef TGA_WIDTH
`define TGA_WIDTH   1
`endif
`ifndef TGC_WIDTH
`define TGC_WIDTH   1
`endif
`ifndef TGRD_WIDTH
`define TGRD_WIDTH  1
`endif
`ifndef TGWD_WIDTH
`define TGWD_WIDTH  1
`endif

module ftb_WbXbc_arbiter
   (//Clock and reset
    //---------------
    input wire                               clk_i,            //module clock
    input wire                               async_rst_i,      //asynchronous reset
    input wire                               sync_rst_i,       //synchronous reset

    //Initiator interface
    //-------------------
    input  wire [`ITR_CNT-1:0]               itr_cyc_i,        //bus cycle indicator       +-
    input  wire [`ITR_CNT-1:0]               itr_stb_i,        //access request            |
    input  wire [`ITR_CNT-1:0]               itr_we_i,         //write enable              |
    input  wire [`ITR_CNT-1:0]               itr_lock_i,       //uninterruptable bus cycle |
    input  wire [(`ITR_CNT*`SEL_WIDTH)-1:0]  itr_sel_i,        //write data selects        | initiator
    input  wire [(`ITR_CNT*`ADR_WIDTH)-1:0]  itr_adr_i,        //address bus               | to
    input  wire [(`ITR_CNT*`DAT_WIDTH)-1:0]  itr_dat_i,        //write data bus            | target
    input  wire [(`ITR_CNT*`TGA_WIDTH)-1:0]  itr_tga_i,        //address tags              |
    input  wire [`ITR_CNT-1:0]               itr_tga_prio_i,   //access priorities         |
    input  wire [(`ITR_CNT*`TGC_WIDTH)-1:0]  itr_tgc_i,        //bus cycle tags            |
    input  wire [(`ITR_CNT*`TGWD_WIDTH)-1:0] itr_tgd_i,        //write data tags           +-
    output wire [`ITR_CNT-1:0]               itr_ack_o,        //bus cycle acknowledge     +-
    output wire [`ITR_CNT-1:0]               itr_err_o,        //error indicator           | target
    output wire [`ITR_CNT-1:0]               itr_rty_o,        //retry request             | to
    output wire [`ITR_CNT-1:0]               itr_stall_o,      //access delay              | initiator
    output wire [(`ITR_CNT*`DAT_WIDTH)-1:0]  itr_dat_o,        //read data bus             |
    output wire [(`ITR_CNT*`TGRD_WIDTH)-1:0] itr_tgd_o,        //read data tags            +-

    //Target interface
    //----------------
    output wire                              tgt_cyc_o,        //bus cycle indicator       +-
    output wire                              tgt_stb_o,        //access request            |
    output wire                              tgt_we_o,         //write enable              |
    output wire                              tgt_lock_o,       //uninterruptable bus cycle |
    output wire [`SEL_WIDTH-1:0]             tgt_sel_o,        //write data selects        | initiator
    output wire [`ADR_WIDTH-1:0]             tgt_adr_o,        //write data selects        | to
    output wire [`DAT_WIDTH-1:0]             tgt_dat_o,        //write data bus            | target
    output wire [`TGA_WIDTH-1:0]             tgt_tga_o,        //address tags              |
    output wire [`TGC_WIDTH-1:0]             tgt_tgc_o,        //bus cycle tags            |
    output wire [`TGWD_WIDTH-1:0]            tgt_tgd_o,        //write data tags           +-
    input  wire                              tgt_ack_i,        //bus cycle acknowledge     +-
    input  wire                              tgt_err_i,        //error indicator           | target
    input  wire                              tgt_rty_i,        //retry request             | to
    input  wire                              tgt_stall_i,      //access delay              | initiator
    input  wire [`DAT_WIDTH-1:0]             tgt_dat_i,        //read data bus             |
    input  wire [`TGRD_WIDTH-1:0]            tgt_tgd_i);       //read data tags            +-

   //DUT
   //===
   WbXbc_arbiter
     #(.ITR_CNT   (`ITR_CNT),                            //number of initiator addresses
       .ADR_WIDTH (`ADR_WIDTH),                          //width of the address bus
       .DAT_WIDTH (`DAT_WIDTH),                          //width of each data bus
       .SEL_WIDTH (`SEL_WIDTH),                          //number of data select lines
       .TGA_WIDTH (`TGA_WIDTH),                          //number of propagated address tags
       .TGC_WIDTH (`TGC_WIDTH),                          //number of propagated cycle tags
       .TGRD_WIDTH(`TGRD_WIDTH),                         //number of propagated read data tags
       .TGWD_WIDTH(`TGWD_WIDTH))                         //number of propagated write data tags
   DUT
     (//Clock and reset
      //---------------
      .clk_i            (clk_i),                         //module clock
      .async_rst_i      (async_rst_i),                   //asynchronous reset
      .sync_rst_i       (sync_rst_i),                    //synchronous reset

      //Initiator interface
      //-------------------
      .itr_cyc_i        (itr_cyc_i),                     //bus cycle indicator       +-
      .itr_stb_i        (itr_stb_i),                     //access request            |
      .itr_we_i         (itr_we_i),                      //write enable              |
      .itr_lock_i       (itr_lock_i),                    //uninterruptable bus cycle |
      .itr_sel_i        (itr_sel_i),                     //write data selects        | initiator
      .itr_adr_i        (itr_adr_i),                     //address bus               | to
      .itr_dat_i        (itr_dat_i),                     //write data bus            | target
      .itr_tga_i        (itr_tga_i),                     //address tags              |
      .itr_tga_prio_i   (itr_tga_prio_i),                //access priorities         |
      .itr_tgc_i        (itr_tgc_i),                     //bus cycle tags            |
      .itr_tgd_i        (itr_tgd_i),                     //write data tags           +-
      .itr_ack_o        (itr_ack_o),                     //bus cycle acknowledge     +-
      .itr_err_o        (itr_err_o),                     //error indicator           | target
      .itr_rty_o        (itr_rty_o),                     //retry request             | to
      .itr_stall_o      (itr_stall_o),                   //access delay              | initiator
      .itr_dat_o        (itr_dat_o),                     //read data bus             |
      .itr_tgd_o        (itr_tgd_o),                     //read data tags            +-

      //Target interface
      //----------------
      .tgt_cyc_o        (tgt_cyc_o),                     //bus cycle indicator       +-
      .tgt_stb_o        (tgt_stb_o),                     //access request            |
      .tgt_we_o         (tgt_we_o),                      //write enable              |
      .tgt_lock_o       (tgt_lock_o),                    //uninterruptable bus cycle |
      .tgt_sel_o        (tgt_sel_o),                     //write data selects        | initiator
      .tgt_adr_o        (tgt_adr_o),                     //write data selects        | to
      .tgt_dat_o        (tgt_dat_o),                     //write data bus            | target
      .tgt_tga_o        (tgt_tga_o),                     //address tags              |
      .tgt_tgc_o        (tgt_tgc_o),                     //bus cycle tags            |
      .tgt_tgd_o        (tgt_tgd_o),                     //write data tags           +-
      .tgt_ack_i        (tgt_ack_i),                     //bus cycle acknowledge     +-
      .tgt_err_i        (tgt_err_i),                     //error indicator           | target
      .tgt_rty_i        (tgt_rty_i),                     //retry request             | to
      .tgt_stall_i      (tgt_stall_i),                   //access delay              | initiator
      .tgt_dat_i        (tgt_dat_i),                     //read data bus             |
      .tgt_tgd_i        (tgt_tgd_i));                    //read data tags            +-

`ifdef FORMAL
   //Testbench signals
   wire [`ITR_CNT-1:0]  wb_itr_mon_fsm_reset;            //FSM in RESET
   wire [`ITR_CNT-1:0]  wb_itr_mon_fsm_idle;             //FSM in IDLE
   wire [`ITR_CNT-1:0]  wb_itr_mon_fsm_busy;             //FSM in BUSY
   wire                 wb_tgt_mon_fsm_reset;            //FSM in RESET
   wire                 wb_tgt_mon_fsm_idle;             //FSM in IDLE
   wire                 wb_tgt_mon_fsm_busy;             //FSM in BUSY
   wire [`ITR_CNT-1:0]  wb_pass_through_fsm_reset;       //FSM in RESET
   wire [`ITR_CNT-1:0]  wb_pass_through_fsm_idle;        //FSM in IDLE
   wire [`ITR_CNT-1:0]  wb_pass_through_fsm_busy;        //FSM in READ or WRITE

   //Initiator address tags
   integer              i;
   reg [((`TGA_WIDTH+1)*`ITR_CNT)-1:0] itr_tga;
   always @*
     begin
        for (i=0; i<`ITR_CNT; i=i+1)
          itr_tga[((i+1)*(`TGA_WIDTH+1))-1:i*(`TGA_WIDTH+1)] =
               {itr_tga_prio_i[i],
                itr_tga_i[((i+1)*`TGA_WIDTH)-1:i*`TGA_WIDTH]};
     end

   //Initiator selection
   integer              j;
   reg [`ITR_CNT-1:0] itr_sel;
   always @*
     begin
        itr_sel = {`ITR_CNT{1'b0}};
        for (j=(`ITR_CNT-1); j>=0; j=j-1) //low prio requests
          if (req[j] & ~itr_tga_prio_i[j])
            itr_sel = 1 << j;
        for (j=(`ITR_CNT-1); j>=0; j=j-1) //high prio requests
          if (req[j] & itr_tga_prio_i[j])
            itr_sel = 1 << j;
     end

   //Abbreviations
   wire                  rst     = |{async_rst_i, sync_rst_i};           //reset
   wire [`ITR_CNT-1:0]   req     = ~itr_stall_o & itr_cyc_i & itr_stb_i; //request
   wire [`ITR_CNT-1:0]   ack     =  itr_ack_o | itr_err_o | itr_rty_o;   //acknowledge
   wire                  tgt_req = ~tgt_stall_i & tgt_cyc_o & tgt_stb_o; //request
   wire                  tgt_ack =  tgt_ack_i | tgt_err_i | tgt_rty_i;   //acknowledge

   //SYSCON constraints
   //===================
   wb_syscon wb_syscon
     (//Clock and reset
      //---------------
      .clk_i            (clk_i),                         //module clock
      .sync_i           (1'b1),                          //clock enable
      .async_rst_i      (async_rst_i),                   //asynchronous reset
      .sync_rst_i       (sync_rst_i),                    //synchronous reset
      .gated_clk_o      ());                             //gated clock

   //Protocol assertions
   //===================
   //Initiator interfaces
   wb_itr_mon
     #(.ADR_WIDTH (`ADR_WIDTH),                          //width of the address bus
       .DAT_WIDTH (`DAT_WIDTH),                          //width of each data bus
       .SEL_WIDTH (`SEL_WIDTH),                          //number of data select lines
       .TGA_WIDTH (`TGA_WIDTH + 1),                      //number of propagated address tags
       .TGC_WIDTH (`TGC_WIDTH),                          //number of propagated cycle tags
       .TGRD_WIDTH(`TGRD_WIDTH),                         //number of propagated read data tags
       .TGWD_WIDTH(`TGWD_WIDTH))                         //number of propagated write data tags
   wb_itr_mon[`ITR_CNT-1:0]
     (//Clock and reset
      //---------------
      .clk_i            (clk_i),                         //module clock
      .async_rst_i      (async_rst_i),                   //asynchronous reset
      .sync_rst_i       (sync_rst_i),                    //synchronous reset

      //Initiator interface
      //-------------------
      .itr_cyc_i        (itr_cyc_i),                     //bus cycle indicator       +-
      .itr_stb_i        (itr_stb_i),                     //access request            |
      .itr_we_i         (itr_we_i),                      //write enable              |
      .itr_lock_i       (itr_lock_i),                    //uninterruptable bus cycle |
      .itr_sel_i        (itr_sel_i),                     //write data selects        | initiator
      .itr_adr_i        (itr_adr_i),                     //address bus               | to
      .itr_dat_i        (itr_dat_i),                     //write data bus            | target
      .itr_tga_i        (itr_tga),                       //address tags              |
      .itr_tgc_i        (itr_tgc_i),                     //bus cycle tags            |
      .itr_tgd_i        (itr_tgd_i),                     //write data tags           +-
      .itr_ack_o        (itr_ack_o),                     //bus cycle acknowledge     +-
      .itr_err_o        (itr_err_o),                     //error indicator           | target
      .itr_rty_o        (itr_rty_o),                     //retry request             | to
      .itr_stall_o      (itr_stall_o),                   //access delay              | initiator
      .itr_dat_o        (itr_dat_o),                     //read data bus             |
      .itr_tgd_o        (itr_tgd_o),                     //read data tags            +-

     //Testbench status signals
     //------------------------
     .tb_fsm_reset      (wb_itr_mon_fsm_reset),          //FSM in RESET state
     .tb_fsm_idle       (wb_itr_mon_fsm_idle),           //FSM in IDLE state
     .tb_fsm_busy       (wb_itr_mon_fsm_busy));          //FSM in BUSY state

   //Target interface
   wb_tgt_mon
     #(.ADR_WIDTH (`ADR_WIDTH),                          //width of the address bus
       .DAT_WIDTH (`DAT_WIDTH),                          //width of each data bus
       .SEL_WIDTH (`SEL_WIDTH),                          //number of data select lines
       .TGA_WIDTH (`TGA_WIDTH),                          //number of propagated address tags
       .TGC_WIDTH (`TGC_WIDTH),                          //number of propagated cycle tags
       .TGRD_WIDTH(`TGRD_WIDTH),                         //number of propagated read data tags
       .TGWD_WIDTH(`TGWD_WIDTH))                         //number of propagated write data tags
   wb_tgt_mon
     (//Clock and reset
      //---------------
      .clk_i            (clk_i),                         //module clock
      .async_rst_i      (async_rst_i),                   //asynchronous reset
      .sync_rst_i       (sync_rst_i),                    //synchronous reset

      //Target interface
      //----------------
      .tgt_cyc_o        (tgt_cyc_o),                     //bus cycle indicator       +-
      .tgt_stb_o        (tgt_stb_o),                     //access request            |
      .tgt_we_o         (tgt_we_o),                      //write enable              |
      .tgt_lock_o       (tgt_lock_o),                    //uninterruptable bus cycle |
      .tgt_sel_o        (tgt_sel_o),                     //write data selects        | initiator
      .tgt_adr_o        (tgt_adr_o),                     //write data selects        | to
      .tgt_dat_o        (tgt_dat_o),                     //write data bus            | target
      .tgt_tga_o        (tgt_tga_o),                     //address tags              |
      .tgt_tgc_o        (tgt_tgc_o),                     //bus cycle tags            |
      .tgt_tgd_o        (tgt_tgd_o),                     //write data tags           +-
      .tgt_ack_i        (tgt_ack_i),                     //bus cycle acknowledge     +-
      .tgt_err_i        (tgt_err_i),                     //error indicator           | target
      .tgt_rty_i        (tgt_rty_i),                     //retry request             | to
      .tgt_stall_i      (tgt_stall_i),                   //access delay              | initiator
      .tgt_dat_i        (tgt_dat_i),                     //read data bus             |
      .tgt_tgd_i        (tgt_tgd_i),                     //read data tags            +-

     //Testbench status signals
     //------------------------
     .tb_fsm_reset      (wb_tgt_mon_fsm_reset),          //FSM in RESET state
     .tb_fsm_idle       (wb_tgt_mon_fsm_idle),           //FSM in IDLE state
     .tb_fsm_busy       (wb_tgt_mon_fsm_busy));          //FSM in BUSY state

   //Pass-through assertions
   //=======================
   wb_pass_through
     #(.ADR_WIDTH (`ADR_WIDTH),                          //width of the address bus
       .DAT_WIDTH (`DAT_WIDTH),                          //width of each data bus
       .SEL_WIDTH (`SEL_WIDTH),                          //number of data select lines
       .TGA_WIDTH (`TGA_WIDTH),                          //number of propagated address tags
       .TGC_WIDTH (`TGC_WIDTH),                          //number of propagated cycle tags
       .TGRD_WIDTH(`TGRD_WIDTH),                         //number of propagated read data tags
       .TGWD_WIDTH(`TGWD_WIDTH))                         //number of propagated write data tags
   wb_pass_through[`ITR_CNT-1:0]
     (//Assertion control
      //-----------------
      .pass_through_en  (itr_sel),

      //Clock and reset
      //---------------
      .clk_i            (clk_i),                         //module clock
      .async_rst_i      (async_rst_i),                   //asynchronous reset
      .sync_rst_i       (sync_rst_i),                    //synchronous reset

      //Initiator interface
      //-------------------
      .itr_cyc_i        (itr_cyc_i),                     //bus cycle indicator       +-
      .itr_stb_i        (itr_stb_i),                     //access request            |
      .itr_we_i         (itr_we_i),                      //write enable              |
      .itr_lock_i       (itr_lock_i),                    //uninterruptable bus cycle | initiator
      .itr_sel_i        (itr_sel_i),                     //write data selects        | initiator
      .itr_adr_i        (itr_adr_i),                     //address bus               | to
      .itr_dat_i        (itr_dat_i),                     //write data bus            | target
      .itr_tga_i        (itr_tga_i),                     //address tags              |
      .itr_tgc_i        (itr_tgc_i),                     //bus cycle tags            |
      .itr_tgd_i        (itr_tgd_i),                     //write data tags           +-
      .itr_ack_o        (itr_ack_o),                     //bus cycle acknowledge     +-
      .itr_err_o        (itr_err_o),                     //error indicator           | target
      .itr_rty_o        (itr_rty_o),                     //retry request             | to
      .itr_stall_o      (itr_stall_o),                   //access delay              | initiator
      .itr_dat_o        (itr_dat_o),                     //read data bus             |
      .itr_tgd_o        (itr_tgd_o),                     //read data tags            +-

      //Target interface
      //----------------
      .tgt_cyc_o        ({`ITR_CNT{tgt_cyc_o}}),         //bus cycle indicator       +-
      .tgt_stb_o        ({`ITR_CNT{tgt_stb_o}}),         //access request            |
      .tgt_we_o         ({`ITR_CNT{tgt_we_o}}),          //write enable              |
      .tgt_lock_o       ({`ITR_CNT{tgt_lock_o}}),        //uninterruptable bus cycle |
      .tgt_sel_o        ({`ITR_CNT{tgt_sel_o}}),         //write data selects        | initiator
      .tgt_adr_o        ({`ITR_CNT{tgt_adr_o}}),         //write data selects        | to
      .tgt_dat_o        ({`ITR_CNT{tgt_dat_o}}),         //write data bus            | target
      .tgt_tga_o        ({`ITR_CNT{tgt_tga_o}}),         //address tags              |
      .tgt_tgc_o        ({`ITR_CNT{tgt_tgc_o}}),         //bus cycle tags            |
      .tgt_tgd_o        ({`ITR_CNT{tgt_tgd_o}}),         //write data tags           +-
      .tgt_ack_i        ({`ITR_CNT{tgt_ack_i}}),         //bus cycle acknowledge     +-
      .tgt_err_i        ({`ITR_CNT{tgt_err_i}}),         //error indicator           | target
      .tgt_rty_i        ({`ITR_CNT{tgt_rty_i}}),         //retry request             | to
      .tgt_stall_i      ({`ITR_CNT{tgt_stall_i}}),       //access delay              | initiator
      .tgt_dat_i        ({`ITR_CNT{tgt_dat_i}}),         //read data bus             |
      .tgt_tgd_i        ({`ITR_CNT{tgt_tgd_i}}),         //read data tags            +-

     //Testbench status signals
     //------------------------
     .tb_fsm_reset      (wb_pass_through_fsm_reset),     //FSM in RESET state
     .tb_fsm_idle       (wb_pass_through_fsm_idle),      //FSM in IDLE state
     .tb_fsm_busy       (wb_pass_through_fsm_busy));     //FSM in BUSY state

   //Initiator select assertions
   //===========================
   //Only one initiator access is allowed at a time
   integer         k, l;
   always @(posedge clk_i)
     begin
        for (k=0; k<`ITR_CNT; k=k+1)
        for (l=0; l<`ITR_CNT; l=l+1)
        if (k != l)
          begin
             //Only one initiator request
             if (req[k]) assert (~req[l]);
             //Only one ongoing target access
             if (wb_itr_mon_fsm_busy[k]) assert (~wb_itr_mon_fsm_busy[l]);
          end
     end // always @*

   //Monitor state assertions
   //========================
   always @*
     begin
        //Reset states of monitors must be aligned
        assert(&{wb_itr_mon_fsm_reset, wb_tgt_mon_fsm_reset, wb_pass_through_fsm_reset} |
              ~|{wb_itr_mon_fsm_reset, wb_tgt_mon_fsm_reset, wb_pass_through_fsm_reset});

        //If target is idle, all initiators must be idle
        if (wb_tgt_mon_fsm_idle) assert (&wb_itr_mon_fsm_idle);

        //If target is busy, one initiator must be busy
        if (wb_tgt_mon_fsm_busy) assert (|wb_itr_mon_fsm_busy);

        //State of pass-through and initiator monitors must be aligned
        assert(~|(wb_itr_mon_fsm_idle ^ wb_pass_through_fsm_idle));
        assert(~|(wb_itr_mon_fsm_busy ^ wb_pass_through_fsm_busy));
     end // always @ *

   //Cover all target accesses
   //=========================
   integer   m;
   always @(posedge clk_i)
     for (m=0; m<`ITR_CNT; m=m+1)
       begin
          cover (wb_itr_mon_fsm_busy[m] & $past(wb_itr_mon_fsm_idle[m]));
          cover (wb_itr_mon_fsm_busy[m] & $past(wb_itr_mon_fsm_busy[m]));
          cover (wb_itr_mon_fsm_idle[m] & $past(wb_itr_mon_fsm_busy[m]));
       end // for (m=0; m<`ITR_CNT; m=m+1)

`ifdef FORMAL_K_INDUCT
   //Enforce a reachable state within the k-intervall
   //================================================
   parameter tcnt_max   = (`FORMAL_K_INDUCT/2)-1;
   integer   tcnt       = tcnt_max;

   always @(posedge clk_i)
     begin
        //Decrement step counter
        if ((tcnt > tcnt_max) || (tcnt <= 0))
          tcnt = tcnt_max;

        tcnt = tcnt - 1;

        //Enforce reachable state
        if (tcnt == 0)
          //assume(rst);   //reset
          assume( rst                                     |   //reset or
                (wb_tgt_mon_fsm_idle & |req & ~|itr_lock_i)); //request
     end // always @ ($global_clock)

`endif //  `ifdef FORMAL_KVAL

`endif //  `ifdef FORMAL

endmodule // ftb_WbXbc_arbiter
