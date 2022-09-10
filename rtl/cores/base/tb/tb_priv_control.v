/** @module : tb_priv_control
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

module tb_priv_control();

parameter CORE            = 0;
parameter ADDRESS_BITS    = 20;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

parameter  [6:0]R_TYPE  = 7'b0110011,
                I_TYPE  = 7'b0010011,
                STORE   = 7'b0100011,
                LOAD    = 7'b0000011,
                BRANCH  = 7'b1100011,
                JALR    = 7'b1100111,
                JAL     = 7'b1101111,
                AUIPC   = 7'b0010111,
                LUI     = 7'b0110111,
                FENCES  = 7'b0001111,
                SYSTEM  = 7'b1110011;

parameter MACHINE    = 2'b11;
parameter SUPERVISOR = 2'b01;
parameter USER       = 2'b00;


reg clock;
reg reset;
reg [6:0] opcode_decode;
reg [2:0] funct3; // decode
reg [6:0] funct7; // decode

reg [4:0] rs1; // decode
reg [4:0] rs2; // decode

reg [1:0] priv;
reg       intr_branch;
reg       trap_branch;

reg load_memory_receive;
reg store_memory_receive;

reg CSR_read_en_base;
reg CSR_write_en_base;
reg CSR_set_en_base;
reg CSR_clear_en_base;
reg regWrite_base;
// The priviledge level required to access a CSR
reg [1:0] CSR_priv_level;

reg [ADDRESS_BITS-1:0] issue_PC;
reg [ADDRESS_BITS-1:0] inst_PC_fetch_receive;
reg [ADDRESS_BITS-1:0] inst_PC_decode;
reg [ADDRESS_BITS-1:0] inst_PC_execute;
reg [ADDRESS_BITS-1:0] inst_PC_memory_issue;
reg [ADDRESS_BITS-1:0] inst_PC_memory_receive;

reg m_ret_memory_receive;
reg s_ret_memory_receive;
reg u_ret_memory_receive;

reg i_mem_page_fault;
reg i_mem_access_fault;
reg d_mem_page_fault;
reg d_mem_access_fault;

reg is_emulated_instruction;
reg exception;

wire exception_fetch_receive;
wire exception_decode;
wire exception_execute;
wire exception_memory_issue;
wire exception_memory_receive;

wire [3:0] exception_code_fetch_receive;
wire [3:0] exception_code_decode;
wire [3:0] exception_code_execute;
wire [3:0] exception_code_memory_issue;
wire [3:0] exception_code_memory_receive;

wire m_ret_decode;
wire s_ret_decode;
wire u_ret_decode;

wire [ADDRESS_BITS-1:0] trap_PC;

wire CSR_read_en;
wire CSR_write_en;
wire CSR_set_en;
wire CSR_clear_en;
wire regWrite;

// TLB invalidate signals from sfence.vma
wire       tlb_invalidate;
wire [1:0] tlb_invalidate_mode;

reg  scan;


priv_control #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  .clock(clock),
  .reset(reset),
  .opcode_decode(opcode_decode),
  .funct3(funct3), // decode
  .funct7(funct7), // decode

  .rs1(rs1), // decode
  .rs2(rs2), // decode

  .priv(priv),
  .intr_branch(intr_branch),
  .trap_branch(trap_branch),

  .load_memory_receive(load_memory_receive),
  .store_memory_receive(store_memory_receive),

  .CSR_read_en_base(CSR_read_en_base),
  .CSR_write_en_base(CSR_write_en_base),
  .CSR_set_en_base(CSR_set_en_base),
  .CSR_clear_en_base(CSR_clear_en_base),
  .regWrite_base(regWrite_base),
  .CSR_priv_level(CSR_priv_level),

  .issue_PC(issue_PC),
  .inst_PC_fetch_receive(inst_PC_fetch_receive),
  .inst_PC_decode(inst_PC_decode),
  .inst_PC_execute(inst_PC_execute),
  .inst_PC_memory_issue(inst_PC_memory_issue),
  .inst_PC_memory_receive(inst_PC_memory_receive),

  .m_ret_memory_receive(m_ret_memory_receive),
  .s_ret_memory_receive(s_ret_memory_receive),
  .u_ret_memory_receive(u_ret_memory_receive),

  .i_mem_page_fault(i_mem_page_fault),
  .i_mem_access_fault(i_mem_access_fault),
  .d_mem_page_fault(d_mem_page_fault),
  .d_mem_access_fault(d_mem_access_fault),

  .is_emulated_instruction(is_emulated_instruction),
  .exception(exception),

  .exception_fetch_receive(exception_fetch_receive),
  .exception_decode(exception_decode),
  .exception_execute(exception_execute),
  .exception_memory_issue(exception_memory_issue),
  .exception_memory_receive(exception_memory_receive),

  .exception_code_fetch_receive(exception_code_fetch_receive),
  .exception_code_decode(exception_code_decode),
  .exception_code_execute(exception_code_execute),
  .exception_code_memory_issue(exception_code_memory_issue),
  .exception_code_memory_receive(exception_code_memory_receive),

  .m_ret_decode(m_ret_decode),
  .s_ret_decode(s_ret_decode),
  .u_ret_decode(u_ret_decode),

  .trap_PC(trap_PC),

  .CSR_read_en(CSR_read_en),
  .CSR_write_en(CSR_write_en),
  .CSR_set_en(CSR_set_en),
  .CSR_clear_en(CSR_clear_en),
  .regWrite(regWrite),

  .tlb_invalidate(tlb_invalidate),
  .tlb_invalidate_mode(tlb_invalidate_mode),

  .scan(scan)
);



always #5 clock = ~clock;

initial begin
  clock         = 1'b1;
  reset         = 1'b1;

  opcode_decode = R_TYPE;
  funct3        = 3'b000;
  funct7        = 7'b0000000;
  rs1           = 5'b00000;
  rs2           = 5'b00000;

  priv          = 2'b11;
  intr_branch   = 1'b0;
  trap_branch   = 1'b0;

  load_memory_receive  = 1'b0;
  store_memory_receive = 1'b0;

  CSR_read_en_base  = 1'b0;
  CSR_write_en_base = 1'b0;
  CSR_set_en_base   = 1'b0;
  CSR_clear_en_base = 1'b0;
  regWrite_base     = 1'b0;
  CSR_priv_level  = 2'b00;

  issue_PC               = 0;
  inst_PC_fetch_receive  = 0;
  inst_PC_decode         = 0;
  inst_PC_execute        = 0;
  inst_PC_memory_issue   = 0;
  inst_PC_memory_receive = 0;

  m_ret_memory_receive = 1'b0;
  s_ret_memory_receive = 1'b0;
  u_ret_memory_receive = 1'b0;

  i_mem_page_fault   = 1'b0;
  i_mem_access_fault = 1'b0;
  d_mem_page_fault   = 1'b0;
  d_mem_access_fault = 1'b0;

  is_emulated_instruction = 1'b0;
  exception = 1'b0;

  scan = 1'b0;



  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);
  #1
  if( exception_fetch_receive        !== 1'b0  |
      exception_decode               !== 1'b0  |
      exception_execute              !== 1'b0  |
      exception_memory_issue         !== 1'b0  |
      exception_memory_receive       !== 1'b0  |
      exception_code_fetch_receive   !== 4'h0  |
      exception_code_decode          !== 4'h0  |
      exception_code_execute         !== 4'h0  |
      exception_code_memory_issue    !== 4'h0  |
      exception_code_memory_receive  !== 4'h0  |
      m_ret_decode                   !== 1'b0  |
      s_ret_decode                   !== 1'b0  |
      u_ret_decode                   !== 1'b0  |
      trap_PC                        !== 64'd0 |
      CSR_read_en                    !== 1'b0  |
      CSR_write_en                   !== 1'b0  |
      CSR_set_en                     !== 1'b0  |
      CSR_clear_en                   !== 1'b0  |
      regWrite                       !== 1'b0  ) begin


    $display("Error: Unexpected control signals after reset!");
    $display("\ntb_priv_control --> Test Failed!\n\n");
    $stop();
  end

  // ecall from supervisor mode
  opcode_decode = SYSTEM;
  funct3        = 3'b000;
  funct7        = 7'b0000000;
  rs1           = 5'b00000;
  rs2           = 5'b00000;

  priv = SUPERVISOR;

  repeat (1) @ (posedge clock);
  #1
  if( m_ret_decode          !== 1'b0 |
      s_ret_decode          !== 1'b0 |
      u_ret_decode          !== 1'b0 |
      trap_branch           !== 1'b0 |
      exception_decode      !== 1'b1 |
      exception_code_decode !== 4'h9 ) begin

    $display("%b %b %b %b %h", m_ret_decode, s_ret_decode, u_ret_decode, exception_decode, exception_code_decode);
    $display("Error: Unexpected control signals for supervisor ECALL!");
    $display("\ntb_priv_control --> Test Failed!\n\n");
    $stop();
  end

  // m_ret
  opcode_decode = SYSTEM;
  funct3        = 3'b000;
  funct7        = 7'b0011000;
  rs1           = 5'b00000;
  rs2           = 5'b00010;

  priv = MACHINE;

  repeat (1) @ (posedge clock);
  #1
  if( m_ret_decode          !== 1'b1 |
      s_ret_decode          !== 1'b0 |
      u_ret_decode          !== 1'b0 |
      trap_branch           !== 1'b0 |
      exception_decode      !== 1'b0 |
      exception_code_decode !== 4'h0 ) begin

    $display("Error: Unexpected control signals for MRET!");
    $display("\ntb_priv_control --> Test Failed!\n\n");
    $stop();
  end

  // s_ret
  opcode_decode = SYSTEM;
  funct3        = 3'b000;
  funct7        = 7'b0001000;
  rs1           = 5'b00000;
  rs2           = 5'b00010;

  priv = SUPERVISOR;

  repeat (1) @ (posedge clock);
  #1
  if( m_ret_decode          !== 1'b0 |
      s_ret_decode          !== 1'b1 |
      u_ret_decode          !== 1'b0 |
      trap_branch           !== 1'b0 |
      exception_decode      !== 1'b0 |
      exception_code_decode !== 4'h0 ) begin

    $display("Error: Unexpected control signals for SRET!");
    $display("\ntb_priv_control --> Test Failed!\n\n");
    $stop();
  end

  // Illegal CSR access
  opcode_decode = SYSTEM;
  funct3        = 3'b001;
  funct7        = 7'b0001000; // A machine level CSR
  rs1           = 5'b00000;
  rs2           = 5'b00000;

  priv = SUPERVISOR;

  CSR_read_en_base  = 1'b1;
  CSR_write_en_base = 1'b1;
  CSR_set_en_base   = 1'b0;
  CSR_clear_en_base = 1'b0;
  CSR_priv_level  = 2'b11;

  repeat (1) @ (posedge clock);
  #1
  if( CSR_read_en  !== 1'b0 |
      CSR_write_en !== 1'b0 |
      CSR_set_en   !== 1'b0 |
      CSR_clear_en !== 1'b0 |
      regWrite     !== 1'b0 ) begin

    $display("Error: Unexpected control signals for illegal CSR access!");
    $display("\ntb_priv_control --> Test Failed!\n\n");
    $stop();
  end

  CSR_read_en_base  = 1'b0;
  CSR_write_en_base = 1'b0;
  CSR_set_en_base   = 1'b0;
  CSR_clear_en_base = 1'b0;
  CSR_priv_level  = 2'b00;


  // I-mem Page fault
  i_mem_page_fault = 1'b1;
  repeat (1) @ (posedge clock);
  #1
  if(exception_fetch_receive      !== 1'b1 |
     exception_code_fetch_receive !== 4'hC ) begin
    $display("Error: Unexpected excetion signals for I-mem Page Fault!");
    $display("\ntb_priv_control --> Test Failed!\n\n");
    $stop();
  end

  i_mem_page_fault = 1'b0;

  // D-mem Page fault
  d_mem_page_fault = 1'b1;
  load_memory_receive = 1'b1;
  repeat (1) @ (posedge clock);
  #1
  if(exception_memory_receive      !== 1'b1 |
     exception_code_memory_receive !== 4'hd ) begin
    $display("Error: Unexpected excetion signals for D-mem Page Fault!");
    $display("\ntb_priv_control --> Test Failed!\n\n");
    $stop();
  end

  d_mem_page_fault = 1'b0;
  load_memory_receive = 1'b0;

  repeat (10) @ (posedge clock);
  $display("\ntb_priv_control --> Test Passed!\n\n");
  $stop();

end

endmodule
