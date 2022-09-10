/** @module : tb_CSR_unit_priv
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

module tb_CSR_unit_priv();

parameter CORE = 0;
parameter DATA_WIDTH = 64;
parameter ADDRESS_BITS = 64;
parameter HART_ID = 1;
parameter PAGE_MODE_BITS =  4;
parameter ASID_BITS      = 16;
parameter PPN_BITS       = 44;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

localparam MACHINE    = 2'b11;
localparam SUPERVISOR = 2'b01;
localparam USER       = 2'b00;

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

reg clock;
reg reset;

reg CSR_read_en;
reg CSR_write_en;
reg CSR_set_en;
reg CSR_clear_en;

reg [11:0] CSR_address;
reg [DATA_WIDTH-1:0] CSR_write_data;

reg m_ext_interrupt;
reg s_ext_interrupt;
reg software_interrupt;
reg timer_interrupt;

reg m_ret;
reg s_ret;
reg u_ret;

reg                    exception;
reg [             3:0] exception_code;
reg [ADDRESS_BITS-1:0] trap_PC;
reg [ADDRESS_BITS-1:0] exception_addr;
reg [            31:0] exception_instr;

wire                    intr_branch;
wire                    trap_branch;
wire [ADDRESS_BITS-1:0] trap_target;

wire                  CSR_read_data_valid;
wire [DATA_WIDTH-1:0] CSR_read_data;

wire [1:0] priv;

// MSTATUS CSR outputs
wire [1:0] mstatus_MPP;
wire       mstatus_SUM;
wire       mstatus_MXR;
wire       mstatus_MPRV;

// SATP CSR outputs
wire [PAGE_MODE_BITS-1:0] satp_MODE;
wire [ASID_BITS-1     :0] satp_ASID;
wire [PPN_BITS-1      :0] satp_PT_base_PPN;

reg scan;


CSR_unit_priv #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .HART_ID(HART_ID),
  .PAGE_MODE_BITS(PAGE_MODE_BITS),
  .ASID_BITS(ASID_BITS),
  .PPN_BITS(PPN_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  .clock(clock),
  .reset(reset),

  .CSR_read_en(CSR_read_en),
  .CSR_write_en(CSR_write_en),
  .CSR_set_en(CSR_set_en),
  .CSR_clear_en(CSR_clear_en),

  .CSR_address(CSR_address),
  // Write data or set/clear mask from either RS1 or imm.
  .CSR_write_data(CSR_write_data),

  .m_ext_interrupt(m_ext_interrupt),
  .s_ext_interrupt(s_ext_interrupt),
  .software_interrupt(software_interrupt),
  .timer_interrupt(timer_interrupt),

  .m_ret(m_ret),
  .s_ret(s_ret),
  .u_ret(u_ret),

  .exception(exception),
  .exception_code(exception_code),
  .trap_PC(trap_PC),
  .exception_addr(exception_addr),
  .exception_instr(exception_instr),

  .intr_branch(intr_branch),
  .trap_branch(trap_branch),
  .trap_target(trap_target),

  .CSR_read_data_valid(CSR_read_data_valid),
  .CSR_read_data(CSR_read_data),

  .priv(priv),

  // MSTATUS CSR outputs
  .mstatus_MPP(mstatus_MPP),
  .mstatus_SUM(mstatus_SUM),
  .mstatus_MXR(mstatus_MXR),
  .mstatus_MPRV(mstatus_MPRV),

  // SATP CSR outputs
  .satp_MODE(satp_MODE),
  .satp_ASID(satp_ASID),
  .satp_PT_base_PPN(satp_PT_base_PPN),

  .scan(scan)

);

always #5 clock = ~clock;


initial begin
  clock = 1'b1;
  reset = 1'b1;

  CSR_read_en  = 1'b0;
  CSR_write_en = 1'b0;
  CSR_set_en   = 1'b0;
  CSR_clear_en = 1'b0;

  CSR_address    = 12'h000;
  CSR_write_data = 64'd0;

  m_ext_interrupt = 1'b0;
  s_ext_interrupt = 1'b0;
  software_interrupt = 1'b0;
  timer_interrupt = 1'b0;

  m_ret = 1'b0;
  s_ret = 1'b0;
  u_ret = 1'b0;

  exception       = 1'b0;
  exception_code  = 4'h0;
  trap_PC         = 64'd0;
  exception_addr  = 64'd0;
  exception_instr = 32'd0;

  scan = 1'b0;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (4) @ (posedge clock);


  ///////////////
  // PRIV Test //
  ///////////////

  // Write USER privilege level to mstatus.mpp
  CSR_clear_en     = 1'b1;
  CSR_address    = MSTATUS_ADDRESS;
  CSR_write_data = 64'h0000_0000_0000_1800;

  repeat (1) @ (posedge clock);
  #1
  if( DUT.mpp  !== 2'b00 |
      DUT.priv !== 2'b11 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Bad mstatus.mpp or privilege after mstatus write!");
    $display("\ntb_CSR_unit_priv --> Test Failed!\n\n");
    $stop();
  end

  // Enter user mode by writing to mstatus.mpp and executing m_ret
  CSR_clear_en = 1'b0;

  ///////////////////
  // SATP Test     //
  ///////////////////
  CSR_write_en   = 1'b1;
  CSR_address    = SATP_ADDRESS;
  CSR_write_data = 64'h8AAA_A000_0000_0000;

  repeat (1) @ (posedge clock);
  #1
  if( DUT.satp !== 64'h8AAA_A000_0000_0000 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Bad satp write data!");
    $display("\ntb_CSR_unit_priv --> Test Failed!\n\n");
    $stop();
  end

  CSR_write_en   = 1'b0;
  CSR_read_en    = 1'b1;
  CSR_address    = SATP_ADDRESS;

  repeat (1) @ (posedge clock);
  #1
  if( CSR_read_data       !== 64'h8AAA_A000_0000_0000 |
      CSR_read_data_valid !== 1'b1                    ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Bad satp read data!");
    $display("\ntb_CSR_unit_priv --> Test Failed!\n\n");
    $stop();
  end

  $display("SATP Test Passed!");


  repeat (10) @ (posedge clock);
  $display("\ntb_CSR_unit_priv --> Test Passed!\n\n");
  $stop();

end

endmodule
