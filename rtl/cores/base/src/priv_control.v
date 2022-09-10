/** @module : priv_control
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

module priv_control #(
  parameter CORE            = 0,
  parameter ADDRESS_BITS    = 20,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input [6:0] opcode_decode,
  input [2:0] funct3, // decode
  input [6:0] funct7, // decode

  input [4:0] rs1, // decode
  input [4:0] rs2, // decode

  input [1:0] priv,
  input       intr_branch,
  input       trap_branch,

  input load_memory_receive, // memRead_memory_receive
  input store_memory_receive, // memWrite_memory_receive

  input CSR_read_en_base,
  input CSR_write_en_base,
  input CSR_set_en_base,
  input CSR_clear_en_base,
  input regWrite_base,
  // The priviledge level required to access a CSR
  input [1:0] CSR_priv_level,

  input [ADDRESS_BITS-1:0] issue_PC,
  input [ADDRESS_BITS-1:0] inst_PC_fetch_receive,
  input [ADDRESS_BITS-1:0] inst_PC_decode,
  input [ADDRESS_BITS-1:0] inst_PC_execute,
  input [ADDRESS_BITS-1:0] inst_PC_memory_issue,
  input [ADDRESS_BITS-1:0] inst_PC_memory_receive,

  input m_ret_memory_receive,
  input s_ret_memory_receive,
  input u_ret_memory_receive,

  input i_mem_page_fault,
  input i_mem_access_fault,
  input d_mem_page_fault,
  input d_mem_access_fault,

  input is_emulated_instruction,
  input exception,

  output exception_fetch_receive,
  output exception_decode,
  output exception_execute,
  output exception_memory_issue,
  output exception_memory_receive,

  output [3:0] exception_code_fetch_receive,
  output [3:0] exception_code_decode,
  output [3:0] exception_code_execute,
  output [3:0] exception_code_memory_issue,
  output [3:0] exception_code_memory_receive,

  output m_ret_decode,
  output s_ret_decode,
  output u_ret_decode,

  output [ADDRESS_BITS-1:0] trap_PC,

  output CSR_read_en,
  output CSR_write_en,
  output CSR_set_en,
  output CSR_clear_en,
  output regWrite,

  // TLB invalidate signals from sfence.vma
  output       tlb_invalidate,
  output [1:0] tlb_invalidate_mode,

  input  scan
);

localparam [6:0]R_TYPE  = 7'b0110011,
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

localparam MACHINE    = 2'b11;
localparam SUPERVISOR = 2'b01;
localparam USER       = 2'b00;

wire ecall;

wire allow_CSR_access;
wire illegal_CSR_access;

wire [ADDRESS_BITS-1:0] interrupted_PC;

assign m_ret_decode = (priv == MACHINE)    & (opcode_decode == SYSTEM) &
  (funct3 == 3'b000) & (funct7 == 7'b0011000) & (rs2 == 5'b00010);
assign s_ret_decode = (priv >= SUPERVISOR) & (opcode_decode == SYSTEM) &
  (funct3 == 3'b000) & (funct7 == 7'b0001000) & (rs2 == 5'b00010);
assign u_ret_decode = 1'b0; // User mode traps not supported

assign ecall = (opcode_decode == SYSTEM) & (funct3 == 3'b000) &
  (funct7 == 7'b0000000) & (rs2 == 5'b00000) & (rs1 == 5'b00000);

// Exception Signals
assign exception_fetch_receive  = i_mem_page_fault | i_mem_access_fault;
assign exception_decode         = ecall | is_emulated_instruction | illegal_CSR_access;
assign exception_execute        = 1'b0;
assign exception_memory_issue   = 1'b0;
assign exception_memory_receive = d_mem_page_fault | d_mem_access_fault;

// Exception Code Generation
assign exception_code_fetch_receive  = i_mem_page_fault   ? 4'hC :
                                       i_mem_access_fault ? 4'h1 :
                                       4'h0;
assign exception_code_decode         = ecall & (priv == USER      ) ? 4'h8 :
                                       ecall & (priv == SUPERVISOR) ? 4'h9 :
                                       ecall & (priv == MACHINE   ) ? 4'hB :
                                       is_emulated_instruction      ? 4'h2 :
                                       illegal_CSR_access           ? 4'h2 :
                                       4'h0;
assign exception_code_execute        = 4'h0;
assign exception_code_memory_issue   = 4'h0;
assign exception_code_memory_receive = d_mem_page_fault   & load_memory_receive  ? 4'hD : // Load Page Fault
                                       d_mem_access_fault & load_memory_receive  ? 4'h5 : // Load Access Fault
                                       d_mem_page_fault   & store_memory_receive ? 4'hF : // Store Page Fault
                                       d_mem_access_fault & store_memory_receive ? 4'h7 : // Store Access Fault
                                       4'h0;

assign interrupted_PC = ~inst_PC_memory_receive[0] ? inst_PC_memory_receive :
                        ~inst_PC_memory_issue[0]   ? inst_PC_memory_issue   :
                        ~inst_PC_execute[0]        ? inst_PC_execute        :
                        ~inst_PC_decode[0]         ? inst_PC_decode         :
                        ~inst_PC_fetch_receive[0]  ? inst_PC_fetch_receive  :
                        issue_PC;

// This is the PC value that goes into [m|s]epc
assign trap_PC = intr_branch                ? interrupted_PC         :
                 inst_PC_memory_receive;

// TODO: this will not be needed unless memory exceptions can happen in more
// than one stage.
//assign exception_addr = generated_address_execute

// Check CSR access against privilege
assign allow_CSR_access = (priv >= CSR_priv_level);

assign CSR_read_en  = CSR_read_en_base  & allow_CSR_access;
assign CSR_write_en = CSR_write_en_base & allow_CSR_access;
assign CSR_set_en   = CSR_set_en_base   & allow_CSR_access;
assign CSR_clear_en = CSR_clear_en_base & allow_CSR_access;

assign illegal_CSR_access = ~allow_CSR_access & (CSR_read_en_base | CSR_write_en_base | CSR_set_en_base | CSR_clear_en_base);

// The regWrite signal from the CSR_control module should be replaced with
// this version of the signal that checks the privilege level
assign regWrite = CSR_read_en | regWrite_base;


// sfence.vma control signal generation
assign tlb_invalidate = (opcode_decode == SYSTEM) & (funct3 == 3'b000) & (funct7 == 7'b0001001);
assign tlb_invalidate_mode[0] = (rs1 != 5'd0);
assign tlb_invalidate_mode[1] = (rs2 != 5'd0);


reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Privileged Control Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| m_ret_decode   [%b]", m_ret_decode);
    $display ("| s_ret_decode   [%b]", s_ret_decode);
    $display ("| u_ret_decode   [%b]", u_ret_decode);
    $display ("| exception      FR [%b]", exception_fetch_receive);
    $display ("| exception_code FR [%h]", exception_code_fetch_receive);
    $display ("| exception      D  [%b]", exception_decode);
    $display ("| exception_code D  [%h]", exception_code_decode);
    $display ("| exception      EX [%b]", exception_execute);
    $display ("| exception_code EX [%h]", exception_code_execute);
    $display ("| exception      MI [%b]", exception_memory_issue);
    $display ("| exception_code MI [%h]", exception_code_memory_issue);
    $display ("| exception      MR [%b]", exception_memory_receive);
    $display ("| exception_code MR [%h]", exception_code_memory_receive);
    $display ("| CSR_read_en    [%b]", CSR_read_en);
    $display ("| CSR_write_en   [%b]", CSR_write_en);
    $display ("| CSR_set_en     [%b]", CSR_set_en);
    $display ("| CSR_clear_en   [%b]", CSR_clear_en);
    $display ("| regWrite       [%b]", regWrite);
    $display ("----------------------------------------------------------------------");
  end
end
endmodule
