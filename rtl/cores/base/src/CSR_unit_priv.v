/** @module : CSR_unit_priv
 *  @author : Secure, Trusted, and Assured Microelectronics (STAM) Center

 *  Copyright (c) 2022 Trireme (STAM/SCAI/ASU)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.

 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */

module CSR_unit_priv #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter ADDRESS_BITS = 32,
  parameter HART_ID = 0,
  parameter PAGE_MODE_BITS = DATA_WIDTH == 32 ? 1 : 4,
  parameter ASID_BITS      = DATA_WIDTH == 32 ? 4 : 16,
  parameter PPN_BITS       = DATA_WIDTH == 32 ? 22 : 44,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  input CSR_read_en,
  input CSR_write_en,
  input CSR_set_en,
  input CSR_clear_en,

  input [11:0] CSR_address,
  // Write data or set/clear mask from either RS1 or imm.
  input [DATA_WIDTH-1:0] CSR_write_data,

  input m_ext_interrupt,
  input s_ext_interrupt,
  input software_interrupt,
  input timer_interrupt,

  input m_ret,
  input s_ret,
  input u_ret,

  input                    exception,
  input [             3:0] exception_code,
  input [ADDRESS_BITS-1:0] trap_PC,
  input [ADDRESS_BITS-1:0] exception_addr,
  input [            31:0] exception_instr,

  output                  CSR_read_data_valid,
  output [DATA_WIDTH-1:0] CSR_read_data,

  output                    intr_branch,
  output                    trap_branch,
  output [ADDRESS_BITS-1:0] trap_target,

  output reg [1:0] priv,

  // MSTATUS CSR outputs
  output [1:0] mstatus_MPP,
  output       mstatus_SUM,
  output       mstatus_MXR,
  output       mstatus_MPRV,

  // SATP CSR outputs
  output [PAGE_MODE_BITS-1:0] satp_MODE,
  output [ASID_BITS-1     :0] satp_ASID,
  output [PPN_BITS-1      :0] satp_PT_base_PPN,


  input scan
);

// Privilege Levels
localparam MACHINE    = 2'b11;
localparam SUPERVISOR = 2'b01;
localparam USER       = 2'b00;

// Paging Modes
localparam BARE =  0;
localparam SV32 =  1;
localparam SV39 =  8;
localparam SV48 =  9;
localparam SV57 = 10; // Not standardized yet
localparam SV64 = 11; // Not standardized yet


localparam MHARTID_ADDRESS    = 12'hF14;

localparam MSTATUS_ADDRESS    = 12'h300;
localparam MISA_ADDRESS       = 12'h301;
localparam MEDELEG_ADDRESS    = 12'h302;
localparam MIDELEG_ADDRESS    = 12'h303;
localparam MIE_ADDRESS        = 12'h304;
localparam MTVEC_ADDRESS      = 12'h305;
localparam MCOUNTEREN_ADDRESS = 12'h306;
localparam MSCRATCH_ADDRESS   = 12'h340;
localparam MEPC_ADDRESS       = 12'h341;
localparam MCAUSE_ADDRESS     = 12'h342;
localparam MTVAL_ADDRESS      = 12'h343;
localparam MIP_ADDRESS        = 12'h344;

localparam SSTATUS_ADDRESS    = 12'h100;
localparam SEDELEG_ADDRESS    = 12'h102;
localparam SIDELEG_ADDRESS    = 12'h103;
localparam SIE_ADDRESS        = 12'h104;
localparam STVEC_ADDRESS      = 12'h105;
localparam SCOUNTEREN_ADDRESS = 12'h106;
localparam SSCRATCH_ADDRESS   = 12'h140;
localparam SEPC_ADDRESS       = 12'h141;
localparam SCAUSE_ADDRESS     = 12'h142;
localparam STVAL_ADDRESS      = 12'h143;
localparam SIP_ADDRESS        = 12'h144;
localparam SATP_ADDRESS       = 12'h180;

// Privilege Register
wire [1:0] next_priv;

// MSTATUS
reg uie;
reg sie_bit;
reg mie_bit;
reg upie;
reg spie;
reg mpie;
reg spp;
reg [1:0] mpp;
reg [1:0] fs;
reg [1:0] xs;
reg mprv;
reg sum;
reg mxr;
reg tvm;
reg tw;
reg tsr;
reg [1:0] sxl; // RV64 only
reg [1:0] uxl; // RV64 only
reg sd;

wire next_uie;
wire next_sie_bit;
wire next_mie_bit;
wire next_upie;
wire next_spie;
wire next_mpie;
wire next_spp;
wire [1:0] next_mpp;
wire [1:0] next_fs;
wire [1:0] next_xs;
wire next_mprv;
wire next_sum;
wire next_mxr;
wire next_tvm;
wire next_tw;
wire next_tsr;
wire [1:0] next_sxl; // RV64 only
wire [1:0] next_uxl; // RV64 only
wire next_sd;

wire [DATA_WIDTH-1:0] mstatus;
wire [DATA_WIDTH-1:0] mstatus_wr_data;
wire                  mstatus_addr;

// MEDELG
reg  [DATA_WIDTH-1:0] medeleg;
wire [DATA_WIDTH-1:0] next_medeleg;
wire                  medeleg_addr;

// MIDELEG
// Do not support delegating machine interrupts
// Only delegate supervisor and user interrupts
localparam [DATA_WIDTH-1:0] MIDELEG_MASK = { {DATA_WIDTH-12{1'b0}}, 12'h222};
reg  [DATA_WIDTH-1:0] mideleg;
wire [DATA_WIDTH-1:0] next_mideleg;
wire                  mideleg_addr;

// MIE
reg  [DATA_WIDTH-1:0] mie;
wire [DATA_WIDTH-1:0] next_mie;
wire                  mie_addr;

// MTVEC
localparam MTVEC_DEFAULT = { 30'h00000400, 2'b00};
reg  [DATA_WIDTH-1:0]   mtvec;
wire [DATA_WIDTH-1:0]   next_mtvec;
wire                    mtvec_addr;

// MSCRATCH
reg  [DATA_WIDTH-1:0] mscratch;
wire [DATA_WIDTH-1:0] next_mscratch;
wire                  mscratch_addr;

// MEPC
reg  [DATA_WIDTH-1:0]   mepc;
wire [DATA_WIDTH-1:0]   next_mepc;
wire                    mepc_addr;

// MCAUSE
localparam [DATA_WIDTH-1:0] MCAUSE_MASK = {1'b1, {DATA_WIDTH-5{1'b0}}, 4'hF};
reg  [DATA_WIDTH-1:0] mcause;
wire [DATA_WIDTH-1:0] next_mcause;
wire                  mcause_addr;

// MTVAL
reg  [DATA_WIDTH-1:0] mtval;
wire [DATA_WIDTH-1:0] next_mtval;
wire                  mtval_addr;
wire                  m_addr_except;
wire                  m_instr_except;

// MIP
// Mask for writeable bits
localparam [DATA_WIDTH-1:0] MIP_MASK = {{DATA_WIDTH-12{1'b0}}, 12'h333};
reg  [DATA_WIDTH-1:0] mip;
reg                   seip_hw;
wire [DATA_WIDTH-1:0] next_mip;
wire [DATA_WIDTH-1:0] mip_read;
wire                  mip_addr;
wire [DATA_WIDTH-1:0] new_intr_mip;

wire ssip;
wire msip;
wire stip;
wire mtip;
wire seip;
wire meip;

// MHARTID
wire                  mhartid_addr;

// MISA
wire [DATA_WIDTH-1:0] misa;
wire                  misa_addr;


// SSTATUS
wire [DATA_WIDTH-1:0] sstatus;
wire                  sstatus_addr;

// SIE
reg  [DATA_WIDTH-1:0] sie;
wire [DATA_WIDTH-1:0] next_sie;
wire                  sie_addr;

// STVEC
localparam STVEC_DEFAULT = { 30'h00000400, 2'b00};
reg  [DATA_WIDTH-1:0]   stvec;
wire [DATA_WIDTH-1:0]   next_stvec;
wire                    stvec_addr;

// SCOUNTEREN

// SSCRATCH
reg  [DATA_WIDTH-1:0] sscratch;
wire [DATA_WIDTH-1:0] next_sscratch;
wire                  sscratch_addr;

// SEPC
reg  [DATA_WIDTH-1:0]   sepc;
wire [DATA_WIDTH-1:0]   next_sepc;
wire                    sepc_addr;

// SCAUSE
localparam [DATA_WIDTH-1:0] SCAUSE_MASK = {1'b1, {DATA_WIDTH-5{1'b0}}, 4'hF};
reg  [DATA_WIDTH-1:0] scause;
wire [DATA_WIDTH-1:0] next_scause;
wire                  scause_addr;

// STVAL
reg  [DATA_WIDTH-1:0] stval;
wire [DATA_WIDTH-1:0] next_stval;
wire                  stval_addr;
wire                  s_addr_except;
wire                  s_instr_except;

// SIP
// Mask for writeable bits
localparam [DATA_WIDTH-1:0] SIP_MASK = {{DATA_WIDTH-12{1'b0}}, 12'h333};
wire [DATA_WIDTH-1:0] sip;
wire [DATA_WIDTH-1:0] sip_read;
wire                  sip_addr;


// SATP
// For now only one virtual paging mode is supported. Select the proper value
// based on the DATA_WIDTH parameter
localparam SVXX = DATA_WIDTH == 32 ? SV32 : SV39;

reg  [DATA_WIDTH-1:0] satp;
wire [DATA_WIDTH-1:0] next_satp;
wire                  satp_addr;
wire                  valid_satp_mode;


// Interrupt enable checking logic
wire enable_mei;
wire enable_msi;
wire enable_mti;
wire enable_sei;
wire enable_ssi;
wire enable_sti;
wire take_mei;
wire take_msi;
wire take_mti;
wire take_sei;
wire take_ssi;
wire take_sti;
wire                  m_intr_en;
wire                  s_intr_en;
wire                  m_interrupt;
wire                  s_interrupt;
wire                  m_exception;
wire                  s_exception;
wire                  m_trap;
wire                  s_trap;
wire                  u_trap;


////////////////////////////////////////////////////////////////////////////////
// Privilege Register (Not visible to software                                //
////////////////////////////////////////////////////////////////////////////////

assign next_priv = m_trap ? MACHINE     :
                   s_trap ? SUPERVISOR  :
                   u_trap ? USER        :
                   m_ret  ? mpp         :
                   s_ret  ? {1'b0, spp} :
                   priv;

always@(posedge clock) begin
  if(reset) begin
    priv <= MACHINE;
  end else begin
    priv <= next_priv;
  end
end

////////////////////////////////////////////////////////////////////////////////
// mstatus CSR                                                                //
////////////////////////////////////////////////////////////////////////////////

generate
  if(DATA_WIDTH == 64) begin
    assign next_uxl  = 2'b10; // Hard wire XLEN to 64
    assign next_sxl  = 2'b10; // Hard wire XLEN to 64
    assign mstatus = {sd, 27'd0, sxl, uxl, 9'd0, tsr, tw, tvm, mxr, sum, mprv,
      xs, fs, mpp, 2'd0, spp, mpie, 1'b0, spie, upie, mie_bit, 1'b0, sie_bit, uie};
    assign sstatus = {sd, 29'd0, uxl, 12'd0, mxr, sum, 1'b0,
      xs, fs, 4'd0, spp, 2'b0, spie, upie, 2'b0, sie_bit, uie};

  end
  else begin
    assign next_uxl  = 2'd0;
    assign next_sxl  = 2'd0;
    assign mstatus = {sd, 8'd0, tsr, tw, tvm, mxr, sum, mprv,
      xs, fs, mpp, 2'd0, spp, mpie, 1'b0, spie, upie, mie_bit, 1'b0, sie_bit, uie};
    assign sstatus = {sd, 11'd0, mxr, sum, 1'b0,
      xs, fs, 4'd0, spp, 2'b0, spie, upie, 2'b0, sie_bit, uie};

  end
endgenerate

assign mstatus_addr = (CSR_address == MSTATUS_ADDRESS);
assign sstatus_addr = (CSR_address == SSTATUS_ADDRESS);

assign mstatus_wr_data = CSR_write_en ? CSR_write_data            :
                         CSR_set_en   ? CSR_write_data  | mstatus :
                         CSR_clear_en ? ~CSR_write_data & mstatus :
                         mstatus;

assign next_uie = u_ret  ? upie : // User trap return
                  u_trap ? 1'b0 : // User trap
                  mstatus_addr ? mstatus_wr_data[0] :
                  sstatus_addr ? mstatus_wr_data[0] :
                  uie;

assign next_sie_bit = s_ret  ? spie : // Supervisor trap return
                      s_trap ? 1'b0 : // Supervisor trap
                      mstatus_addr ? mstatus_wr_data[1] :
                      sstatus_addr ? mstatus_wr_data[1] :
                      sie_bit;

assign next_mie_bit = m_ret  ? mpie : // Machine trap return
                      m_trap ? 1'b0 : // Machine trap
                      mstatus_addr ? mstatus_wr_data[3] : mie_bit;

assign next_upie = u_ret  ? 1'b1 : // User trap return
                   u_trap ? uie  : // User trap
                   mstatus_addr ? mstatus_wr_data[4] :
                   sstatus_addr ? mstatus_wr_data[4] :
                   upie;

assign next_spie = s_ret  ? 1'b1    : // Supervisor trap return
                   s_trap ? sie_bit : // Supervisor trap
                   mstatus_addr ? mstatus_wr_data[5] :
                   sstatus_addr ? mstatus_wr_data[5] :
                   spie;

assign next_mpie = m_ret  ? 1'b1     : // Machine trap return
                   m_trap ? mie_bit  : // Machine trap
                   mstatus_addr ? mstatus_wr_data[7] : mpie;

assign next_spp  = s_ret  ? USER[0] : // Supervisor trap return
                   s_trap ? priv[0] : // Supervisor trap
                   mstatus_addr ? mstatus_wr_data[8] :
                   sstatus_addr ? mstatus_wr_data[8] :
                   spp;

assign next_mpp  = m_ret  ? USER : // Machine trap return
                   m_trap ? priv : // Machine trap
                   mstatus_addr ? mstatus_wr_data[12:11] : mpp;


assign next_fs   = mstatus_addr ? mstatus_wr_data[14:13] :
                   sstatus_addr ? mstatus_wr_data[14:13] :
                   fs;
assign next_xs   = mstatus_addr ? mstatus_wr_data[16:15] :
                   sstatus_addr ? mstatus_wr_data[16:15] :
                   xs;
assign next_mprv = mstatus_addr ? mstatus_wr_data[17] : mprv;
assign next_sum  = mstatus_addr ? mstatus_wr_data[18] :
                   sstatus_addr ? mstatus_wr_data[18] :
                   sum;
assign next_mxr  = mstatus_addr ? mstatus_wr_data[19] :
                   sstatus_addr ? mstatus_wr_data[19] :
                   mxr;

assign next_tvm  = mstatus_addr ? mstatus_wr_data[20] : tvm;
assign next_tw   = mstatus_addr ? mstatus_wr_data[21] : tw;
assign next_tsr  = mstatus_addr ? mstatus_wr_data[22] : tsr;

assign next_sd   = mstatus_addr ? mstatus_wr_data[DATA_WIDTH-1] :
                   sstatus_addr ? mstatus_wr_data[DATA_WIDTH-1] :
                   sd;

always@(posedge clock) begin
  if(reset) begin
   {sd, sxl, uxl, tsr, tw, tvm, mxr, sum, mprv, xs, fs, mpp, spp, mpie, spie, upie, mie_bit, sie_bit, uie} <=
     {DATA_WIDTH{1'b0}};
  end
  else begin
    {sd, sxl, uxl, tsr, tw, tvm, mxr, sum, mprv, xs, fs, mpp, spp, mpie, spie, upie, mie_bit, sie_bit, uie} <=
      {next_sd, next_sxl, next_uxl, next_tsr, next_tw, next_tvm, next_mxr,
      next_sum, next_mprv, next_xs, next_fs, next_mpp, next_spp, next_mpie,
      next_spie, next_upie, next_mie_bit, next_sie_bit, next_uie};
  end
end

// Assign outputs
assign mstatus_MPP  = mpp;
assign mstatus_SUM  = sum;
assign mstatus_MXR  = mxr;
assign mstatus_MPRV = mprv;

////////////////////////////////////////////////////////////////////////////////
// medeleg CSR                                                                //
////////////////////////////////////////////////////////////////////////////////

assign medeleg_addr = (CSR_address == MEDELEG_ADDRESS);

                      // If this CSR is not selected for write/modify
assign next_medeleg = !medeleg_addr  ? medeleg                   :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data            :
                      CSR_set_en     ? CSR_write_data  | medeleg :
                      CSR_clear_en   ? ~CSR_write_data & medeleg :
                      medeleg;

always@(posedge clock) begin
  if(reset) begin
    medeleg <= {DATA_WIDTH{1'b0}};
  end else begin
    medeleg <= next_medeleg;
  end
end

////////////////////////////////////////////////////////////////////////////////
// mideleg CSR                                                                //
////////////////////////////////////////////////////////////////////////////////

assign mideleg_addr = (CSR_address == MIDELEG_ADDRESS);

                      // If this CSR is not selected for write/modify
assign next_mideleg = !mideleg_addr  ? mideleg                 :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data              & MIDELEG_MASK:
                      CSR_set_en     ? (CSR_write_data  | mideleg) & MIDELEG_MASK :
                      CSR_clear_en   ? (~CSR_write_data & mideleg) & MIDELEG_MASK :
                      mideleg;

always@(posedge clock) begin
  if(reset) begin
    mideleg <= {DATA_WIDTH{1'b0}};
  end else begin
    mideleg <= next_mideleg;
  end
end

////////////////////////////////////////////////////////////////////////////////
// mie CSR                                                                    //
////////////////////////////////////////////////////////////////////////////////

assign mie_addr = (CSR_address == MIE_ADDRESS);

                      // If this CSR is not selected for write/modify
assign next_mie     = !mie_addr      ? mie                   :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data        :
                      CSR_set_en     ? CSR_write_data  | mie :
                      CSR_clear_en   ? ~CSR_write_data & mie :
                      mie;

always@(posedge clock) begin
  if(reset) begin
    mie <= {DATA_WIDTH{1'b0}};
  end else begin
    mie <= next_mie;
  end
end


////////////////////////////////////////////////////////////////////////////////
// mtvec CSR                                                                  //
////////////////////////////////////////////////////////////////////////////////

// Hard-wire the mode field to 0 (Direct mode) but allow writes to the BASE
// field for different interrupt handler locations.


assign mtvec_addr    = (CSR_address == MTVEC_ADDRESS);

                       // If this CSR is not selected for write/modify
assign next_mtvec    = !mtvec_addr ? mtvec :
                       // If this CSR is selected for write/modify
                       CSR_write_en ? CSR_write_data          :
                       CSR_set_en   ? CSR_write_data  | mtvec :
                       CSR_clear_en ? ~CSR_write_data & mtvec :
                       mtvec;

always@(posedge clock) begin
  if(reset) begin
    mtvec <= MTVEC_DEFAULT;
  end else begin
    mtvec <= {next_mtvec[DATA_WIDTH-1:2], 2'b00};
  end
end

////////////////////////////////////////////////////////////////////////////////
// mcounteren CSR                                                             //
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// mscratch CSR                                                               //
////////////////////////////////////////////////////////////////////////////////

assign mscratch_addr = (CSR_address == MSCRATCH_ADDRESS);

                      // If this CSR is not selected for write/modify
assign next_mscratch = !mscratch_addr ? mscratch                   :
                       // If this CSR is selected for write/modify
                       CSR_write_en   ? CSR_write_data             :
                       CSR_set_en     ? CSR_write_data  | mscratch :
                       CSR_clear_en   ? ~CSR_write_data & mscratch :
                       mscratch;

always@(posedge clock) begin
  if(reset) begin
    mscratch <= {DATA_WIDTH{1'b0}};
  end else begin
    mscratch <= next_mscratch;
  end
end

////////////////////////////////////////////////////////////////////////////////
// mepc CSR                                                                   //
////////////////////////////////////////////////////////////////////////////////

assign mepc_addr    = (CSR_address == MEPC_ADDRESS);

                      // Save the interrupted PC when a machine mode trap is taken
assign next_mepc    = m_trap         ? trap_PC                 :
                      // If this CSR is not selected for write/modify
                      !mepc_addr     ? mepc                    :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data          :
                      CSR_set_en     ? CSR_write_data  | mepc  :
                      CSR_clear_en   ? ~CSR_write_data & mepc  :
                      mepc;

always@(posedge clock) begin
  if(reset) begin
    mepc <= {DATA_WIDTH{1'b0}};
  end else begin
    mepc <= {next_mepc[DATA_WIDTH-1:2], 2'b00};
  end
end

////////////////////////////////////////////////////////////////////////////////
// mcause CSR                                                                 //
////////////////////////////////////////////////////////////////////////////////

assign mcause_addr    = (CSR_address == MCAUSE_ADDRESS);


assign next_mcause  = // Exceptions
                      m_exception             ? { {DATA_WIDTH-4{1'b0}}, exception_code} :
                      // Machine Interrupts
                      take_msi & ~mideleg[ 3] ? (1<<DATA_WIDTH-1) + 3  : // M Software
                      take_mti & ~mideleg[ 7] ? (1<<DATA_WIDTH-1) + 7  : // M Timer
                      take_mei & ~mideleg[11] ? (1<<DATA_WIDTH-1) + 11 : // M External
                      // Supervisor Interrupts
                      take_ssi & ~mideleg[ 1] ? (1<<DATA_WIDTH-1) + 1  : // S Software
                      take_sti & ~mideleg[ 5] ? (1<<DATA_WIDTH-1) + 5  : // S Timer
                      take_sei & ~mideleg[ 9] ? (1<<DATA_WIDTH-1) + 9  : // S External
                      // If this CSR is not selected for write/modify
                      !mcause_addr   ? mcause                 :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data             & MCAUSE_MASK :
                      CSR_set_en     ? (CSR_write_data  | mcause) & MCAUSE_MASK :
                      CSR_clear_en   ? (~CSR_write_data & mcause) & MCAUSE_MASK :
                      mcause;

always@(posedge clock) begin
  if(reset) begin
    mcause <= {DATA_WIDTH{1'b0}};
  end else begin
    mcause <= next_mcause;
  end
end

////////////////////////////////////////////////////////////////////////////////
// mtval CSR                                                                  //
////////////////////////////////////////////////////////////////////////////////

assign mtval_addr = (CSR_address == MTVAL_ADDRESS);

assign m_addr_except = m_exception & (
  (exception_code == 4'd0 ) | // Instruction Addr Misaligned
  (exception_code == 4'd1 ) | // Instruction Access Fault
  (exception_code == 4'd3 ) | // Breakpoint
  (exception_code == 4'd4 ) | // Load Address Misaligned
  (exception_code == 4'd5 ) | // Load Access Fault
  (exception_code == 4'd6 ) | // Store Address Misaligned
  (exception_code == 4'd7 ) | // Store Access Fault
  (exception_code == 4'd12) | // Instruction Page Fault
  (exception_code == 4'd13) | // Load Page Fault
  (exception_code == 4'd15)   // Store Page Fault
);

assign m_instr_except = m_exception & (exception_code == 4'd2); // Illegal Instruction

assign next_mtval   = m_addr_except  ? exception_addr                           :
                      m_instr_except ? {{DATA_WIDTH-32{1'b0}}, exception_instr} :
                      m_interrupt    ? {DATA_WIDTH{1'b0}}                       :
                      // If this CSR is not selected for write/modify
                      !mtval_addr    ? mtval                                    :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data                           :
                      CSR_set_en     ? CSR_write_data  | mtval                  :
                      CSR_clear_en   ? ~CSR_write_data & mtval                  :
                      mtval;

always@(posedge clock) begin
  if(reset) begin
    mtval <= {DATA_WIDTH{1'b0}};
  end else begin
    mtval <= next_mtval;
  end
end


////////////////////////////////////////////////////////////////////////////////
// mip CSR                                                                    //
////////////////////////////////////////////////////////////////////////////////

assign mip_addr = (CSR_address == MIP_ADDRESS);
assign sip_addr = (CSR_address == SIP_ADDRESS);

// Set pending bit for new interrupt
assign msip = software_interrupt;
assign mtip = timer_interrupt;

assign meip = take_mei & ~mideleg[11] ? 1'b0    : // Automatically unset pending bit
              m_ext_interrupt         ? 1'b1  : // Set pending bit for new interrupt
              mip[11];

// No writes by the hardware
assign ssip = mip[ 1];

// No writes by the hardware
assign stip = mip[ 5];

// No writes by the hardware
assign seip = mip[ 9];

assign new_intr_mip = {{DATA_WIDTH-12{1'b0}}, meip, 1'b0, seip,   1'b0, mtip, 1'b0, stip,   1'b0, msip, 1'b0, ssip,   1'b0};
assign sip          = {{DATA_WIDTH-12{1'b0}}, 1'b0, 1'b0, mip[9], 1'b0, 1'b0, 1'b0, mip[5], 1'b0, 1'b0, 1'b0, mip[1], 1'b0} & mideleg;

assign mip_read = mip | { {DATA_WIDTH-10{1'b0}}, seip_hw, 9'd0};
assign sip_read = sip | { {DATA_WIDTH-10{1'b0}}, seip_hw, 9'd0};

assign next_mip    =  mip_addr & CSR_write_en   ? (CSR_write_data)        & MIP_MASK :
                      mip_addr & CSR_set_en     ? (CSR_write_data  | mip) & MIP_MASK :
                      mip_addr & CSR_clear_en   ? (~CSR_write_data & mip) & MIP_MASK :
                      sip_addr & CSR_write_en   ? (CSR_write_data)        & SIP_MASK :
                      sip_addr & CSR_set_en     ? (CSR_write_data  | sip) & SIP_MASK :
                      sip_addr & CSR_clear_en   ? (~CSR_write_data & sip) & SIP_MASK :
                      new_intr_mip;


always@(posedge clock) begin
  if(reset) begin
    mip     <= {DATA_WIDTH{1'b0}};
    seip_hw <= 1'b0;
  end else begin
    mip     <= next_mip;
    seip_hw <= take_sei        ? 1'b0 :
               s_ext_interrupt ? 1'b1 :
               seip_hw;
  end
end

////////////////////////////////////////////////////////////////////////////////
// mhartid CSR                                                                //
////////////////////////////////////////////////////////////////////////////////
assign mhartid_addr = (CSR_address == MHARTID_ADDRESS);

////////////////////////////////////////////////////////////////////////////////
// mhartid CSR                                                                //
////////////////////////////////////////////////////////////////////////////////
assign misa_addr = (CSR_address == MISA_ADDRESS);
assign misa = {DATA_WIDTH{1'b0}}; // not implemented (Allowed by specification)

////////////////////////////////////////////////////////////////////////////////
// sstatus CSR                                                                //
////////////////////////////////////////////////////////////////////////////////
// implemented in mstatus section

////////////////////////////////////////////////////////////////////////////////
// sedeleg CSR                                                                //
////////////////////////////////////////////////////////////////////////////////
// Unimplemented because user-mode traps are not supported

////////////////////////////////////////////////////////////////////////////////
// sideleg CSR                                                                //
////////////////////////////////////////////////////////////////////////////////
// Unimplemented because user-mode traps are not supported

////////////////////////////////////////////////////////////////////////////////
// sie CSR                                                                    //
////////////////////////////////////////////////////////////////////////////////

assign sie_addr = (CSR_address == SIE_ADDRESS);

                      // If this CSR is not selected for write/modify
assign next_sie     = !sie_addr      ? sie                   :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data        :
                      CSR_set_en     ? CSR_write_data  | sie :
                      CSR_clear_en   ? ~CSR_write_data & sie :
                      sie;

always@(posedge clock) begin
  if(reset) begin
    sie <= {DATA_WIDTH{1'b0}};
  end else begin
    sie <= next_sie;
  end
end


////////////////////////////////////////////////////////////////////////////////
// stvec CSR                                                                  //
////////////////////////////////////////////////////////////////////////////////

// Hard-wire the mode field to 0 (Direct mode) but allow writes to the BASE
// field for different interrupt handler locations.


assign stvec_addr    = (CSR_address == STVEC_ADDRESS);

                       // If this CSR is not selected for write/modify
assign next_stvec    = !stvec_addr ? stvec :
                       // If this CSR is selected for write/modify
                       CSR_write_en ? CSR_write_data          :
                       CSR_set_en   ? CSR_write_data  | stvec :
                       CSR_clear_en ? ~CSR_write_data & stvec :
                       stvec;

always@(posedge clock) begin
  if(reset) begin
    stvec <= MTVEC_DEFAULT;
  end else begin
    stvec <= {next_stvec[DATA_WIDTH-1:2], 2'b00};
  end
end


////////////////////////////////////////////////////////////////////////////////
// sscratch CSR                                                               //
////////////////////////////////////////////////////////////////////////////////

assign sscratch_addr = (CSR_address == SSCRATCH_ADDRESS);

                      // If this CSR is not selected for write/modify
assign next_sscratch = !sscratch_addr ? sscratch                   :
                       // If this CSR is selected for write/modify
                       CSR_write_en   ? CSR_write_data             :
                       CSR_set_en     ? CSR_write_data  | sscratch :
                       CSR_clear_en   ? ~CSR_write_data & sscratch :
                       sscratch;

always@(posedge clock) begin
  if(reset) begin
    sscratch <= {DATA_WIDTH{1'b0}};
  end else begin
    sscratch <= next_sscratch;
  end
end



////////////////////////////////////////////////////////////////////////////////
// sepc CSR                                                                   //
////////////////////////////////////////////////////////////////////////////////

assign sepc_addr    = (CSR_address == SEPC_ADDRESS);

                      // Save the interrupted PC when a supervisor mode trap is taken
assign next_sepc    = s_trap         ? trap_PC                 :
                      // If this CSR is not selected for write/modify
                      !sepc_addr     ? sepc                    :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data          :
                      CSR_set_en     ? CSR_write_data  | sepc  :
                      CSR_clear_en   ? ~CSR_write_data & sepc  :
                      sepc;

always@(posedge clock) begin
  if(reset) begin
    sepc <= {DATA_WIDTH{1'b0}};
  end else begin
    sepc <= {next_sepc[DATA_WIDTH-1:2], 2'b00};
  end
end

////////////////////////////////////////////////////////////////////////////////
// scause CSR                                                                 //
////////////////////////////////////////////////////////////////////////////////

assign scause_addr    = (CSR_address == SCAUSE_ADDRESS);


assign next_scause  = // Exceptions
                      s_exception    ? { {DATA_WIDTH-4{1'b0}}, exception_code} :
                      // Supervisor Interrupts
                      take_ssi & mideleg[1] ? (1<<DATA_WIDTH-1) + 1  : // S Software
                      take_sti & mideleg[5] ? (1<<DATA_WIDTH-1) + 5  : // S Timer
                      take_sei & mideleg[9] ? (1<<DATA_WIDTH-1) + 9  : // S External
                      // If this CSR is not selected for write/modify
                      !scause_addr   ? scause                 :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data             & SCAUSE_MASK :
                      CSR_set_en     ? (CSR_write_data  | scause) & SCAUSE_MASK :
                      CSR_clear_en   ? (~CSR_write_data & scause) & SCAUSE_MASK :
                      scause;

always@(posedge clock) begin
  if(reset) begin
    scause <= {DATA_WIDTH{1'b0}};
  end else begin
    scause <= next_scause;
  end
end


////////////////////////////////////////////////////////////////////////////////
// stval CSR                                                                  //
////////////////////////////////////////////////////////////////////////////////

assign stval_addr = (CSR_address == STVAL_ADDRESS);

assign s_addr_except = s_exception & (
  (exception_code == 4'd0 ) | // Instruction Addr Misaligned
  (exception_code == 4'd1 ) | // Instruction Access Fault
  (exception_code == 4'd3 ) | // Breakpoint
  (exception_code == 4'd4 ) | // Load Address Misaligned
  (exception_code == 4'd5 ) | // Load Access Fault
  (exception_code == 4'd6 ) | // Store Address Misaligned
  (exception_code == 4'd7 ) | // Store Access Fault
  (exception_code == 4'd12) | // Instruction Page Fault
  (exception_code == 4'd13) | // Load Page Fault
  (exception_code == 4'd15)   // Store Page Fault
);

assign s_instr_except = s_exception & (exception_code == 4'd2); // Illegal Instruction

assign next_stval   = s_addr_except  ? exception_addr                           :
                      s_instr_except ? {{DATA_WIDTH-32{1'b0}}, exception_instr} :
                      s_interrupt    ? {DATA_WIDTH{1'b0}}                       :
                      // If this CSR is not selected for write/modify
                      !stval_addr    ? stval                                    :
                      // If this CSR is selected for write/modify
                      CSR_write_en   ? CSR_write_data                           :
                      CSR_set_en     ? CSR_write_data  | stval                  :
                      CSR_clear_en   ? ~CSR_write_data & stval                  :
                      stval;

always@(posedge clock) begin
  if(reset) begin
    stval <= {DATA_WIDTH{1'b0}};
  end else begin
    stval <= next_stval;
  end
end

////////////////////////////////////////////////////////////////////////////////
// sip CSR                                                                    //
////////////////////////////////////////////////////////////////////////////////
// implemented with MIP CSR

////////////////////////////////////////////////////////////////////////////////
// satp CSR                                                                   //
////////////////////////////////////////////////////////////////////////////////
assign satp_addr = (CSR_address == SATP_ADDRESS);

                      // If this CSR is not selected for write/modify
assign next_satp = !satp_addr   ? satp                   :
                   // If this CSR is selected for write/modify
                   CSR_write_en ? CSR_write_data         :
                   CSR_set_en   ? CSR_write_data  | satp :
                   CSR_clear_en ? ~CSR_write_data & satp :
                   satp;

assign valid_satp_mode = (next_satp[DATA_WIDTH-1 -: PAGE_MODE_BITS] == BARE) |
                         (next_satp[DATA_WIDTH-1 -: PAGE_MODE_BITS] == SVXX);

always@(posedge clock) begin
  if(reset) begin
    satp <= {DATA_WIDTH{1'b0}};
  end
  else if(valid_satp_mode) begin
    // Do not write invalid translation modes
    satp <= next_satp;
  end
end

// Assign outputs
assign satp_MODE        = satp[DATA_WIDTH-1 -: PAGE_MODE_BITS];
assign satp_ASID        = satp[PPN_BITS +: ASID_BITS];
assign satp_PT_base_PPN = satp[PPN_BITS-1:0];

////////////////////////////////////////////////////////////////////////////////
// Interrupt enable checking logic                                            //
////////////////////////////////////////////////////////////////////////////////

assign m_intr_en   = (priv != 2'b11) | ( (priv == MACHINE) & mstatus[3]);
assign s_intr_en   = (priv == 2'b00) | ( (priv == SUPERVISOR) & mstatus[1]);

assign enable_mei = (m_intr_en & ~mideleg[11]) | (s_intr_en & mideleg[11]);
assign enable_msi = (m_intr_en & ~mideleg[ 3]) | (s_intr_en & mideleg[ 3]);
assign enable_mti = (m_intr_en & ~mideleg[ 7]) | (s_intr_en & mideleg[ 7]);
assign enable_sei = (m_intr_en & ~mideleg[ 9]) | (s_intr_en & mideleg[ 9]);
assign enable_ssi = (m_intr_en & ~mideleg[ 1]) | (s_intr_en & mideleg[ 1]);
assign enable_sti = (m_intr_en & ~mideleg[ 5]) | (s_intr_en & mideleg[ 5]);

// TODO Check appropriate [m,s]ie bit
assign take_mei = enable_mei & mip_read[11] & mie[11];
assign take_msi = enable_msi & mip_read[ 3] & mie[ 3] & (~take_mei);
assign take_mti = enable_mti & mip_read[ 7] & mie[ 7] & (~take_mei & ~take_msi);
assign take_sei = enable_sei & mip_read[ 9] & mie[ 9] & (~take_mei & ~take_msi & ~take_mti);
assign take_ssi = enable_ssi & mip_read[ 1] & mie[ 1] & (~take_mei & ~take_msi & ~take_mti & ~take_sei);
assign take_sti = enable_sti & mip_read[ 5] & mie[ 5] & (~take_mei & ~take_msi & ~take_mti & ~take_sei & ~take_ssi);

assign m_interrupt = |( {    take_mei,    take_msi,    take_mti,    take_sei,    take_ssi,    take_sti} &
                       ~{ mideleg[11], mideleg[ 3], mideleg[ 7], mideleg[ 9], mideleg[ 1], mideleg[ 5]}
                      );
assign s_interrupt = |( {    take_mei,    take_msi,    take_mti,    take_sei,    take_ssi,    take_sti} &
                        { mideleg[11], mideleg[ 3], mideleg[ 7], mideleg[ 9], mideleg[ 1], mideleg[ 5]}
                      );

assign m_exception =  exception & (priv[1] | ~medeleg[exception_code]);
assign s_exception = ~priv[1] & (exception &  medeleg[exception_code]);

assign m_trap = m_interrupt | m_exception;
assign s_trap = s_interrupt | s_exception;
assign u_trap = 1'b0;

// Interrupt signal for control logic input
assign trap_branch = m_trap | s_trap | u_trap | m_ret | s_ret | u_ret;
assign intr_branch = m_interrupt | s_interrupt;

// This is control logic,  but it is easier to put here than output all *tvec
// and *epc register values
assign trap_target = m_trap ? mtvec  :
                     s_trap ? stvec  :
                     m_ret  ? mepc   :
                     s_ret  ? sepc   :
                     {ADDRESS_BITS{1'b0}};


////////////////////////////////////////////////////////////////////////////////
// CSR Read Mux - Must be after all CSR variables are declared                //
////////////////////////////////////////////////////////////////////////////////

// CSR Read Data - Reads happen before instruction executes
assign CSR_read_data = mstatus_addr          ? mstatus          :
                       medeleg_addr          ? medeleg          :
                       mideleg_addr          ? mideleg          :
                       mie_addr              ? mie              :
                       mtvec_addr            ? mtvec            :
                       mscratch_addr         ? mscratch         :
                       mepc_addr             ? mepc             :
                       mepc_addr             ? mepc             :
                       mcause_addr           ? mcause           :
                       mtval_addr            ? mtval            :
                       mip_addr              ? mip_read         :
                       mhartid_addr          ? HART_ID          :
                       misa_addr             ? misa             :
                       sstatus_addr          ? sstatus          :
                       sie_addr              ? sie              :
                       stvec_addr            ? stvec            :
                       sscratch_addr         ? sscratch         :
                       sepc_addr             ? sepc             :
                       scause_addr           ? scause           :
                       stval_addr            ? stval            :
                       sip_addr              ? sip_read         :
                       satp_addr             ? satp             :
                       {DATA_WIDTH{1'b0}};

assign CSR_read_data_valid = CSR_read_en & (
  mstatus_addr    |
  medeleg_addr    |
  mideleg_addr    |
  mie_addr        |
  mtvec_addr      |
  mscratch_addr   |
  mepc_addr       |
  mepc_addr       |
  mcause_addr     |
  mtval_addr      |
  mip_addr        |
  mhartid_addr    |
  misa_addr       |
  sstatus_addr    |
  sie_addr        |
  stvec_addr      |
  sscratch_addr   |
  sepc_addr       |
  scause_addr     |
  stval_addr      |
  sip_addr        |
  satp_addr
);

////////////////////////////////////////////////////////////////////////////////

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Privileged CSR Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| CSR read data       [%h]", CSR_read_data);
    $display ("| CSR read data valid [%h]", CSR_read_data_valid);
    $display ("| priv    [%h]", priv);
    $display ("| mstatus [%h]", mstatus);
    $display ("| medeleg [%h]", medeleg);
    $display ("| mideleg [%h]", mideleg);
    $display ("| mie     [%h]", mie);
    $display ("| mtvec   [%h]", mtvec);
    $display ("| mscratch[%h]", mscratch);
    $display ("| mepc    [%h]", mepc);
    $display ("| mcause  [%h]", mcause);
    $display ("| mtval   [%h]", mtval);
    $display ("| mip     [%h]", mip);
    $display ("| sstatus [%h]", sstatus);
    $display ("| sie     [%h]", sie);
    $display ("| stvec   [%h]", stvec);
    $display ("| sscratch[%h]", sscratch);
    $display ("| sepc    [%h]", sepc);
    $display ("| scause  [%h]", scause);
    $display ("| stval   [%h]", stval);
    $display ("| sip     [%h]", sip);
    $display ("| satp    [%h]", satp);
    $display ("| intr branch [%b]", intr_branch);
    $display ("| trap branch [%b]", trap_branch);
    $display ("| trap target [%h]", trap_target);
    $display ("----------------------------------------------------------------------");
  end
end


endmodule
