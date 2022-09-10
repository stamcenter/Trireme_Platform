/** @module : hazard_detection_unit_priv
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

module hazard_detection_unit_priv #(
  parameter CORE            = 0,
  parameter ADDRESS_BITS    = 32,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  input fetch_valid,
  input fetch_ready,
  input issue_request,
  input [ADDRESS_BITS-1:0] issue_PC,
  input [ADDRESS_BITS-1:0] fetch_address_in,
  input memory_valid,
  input memory_ready,

  input load_memory,
  input store_memory,
  input [ADDRESS_BITS-1:0] load_address,
  input [ADDRESS_BITS-1:0] memory_address_in,

  input [6:0] opcode_decode,
  input [6:0] opcode_execute,
  input branch_execute,

  input solo_instr_decode,
  input solo_instr_execute,
  input solo_instr_memory_issue,
  input solo_instr_memory_receive,
  input solo_instr_writeback,

  input i_mem_page_fault,
  input i_mem_access_fault,
  input d_mem_page_fault,
  input d_mem_access_fault,

  output i_mem_issue_hazard,
  output i_mem_recv_hazard,
  output d_mem_issue_hazard,
  output d_mem_recv_hazard,
  output JALR_branch_hazard,
  output JAL_hazard,
  output solo_instr_hazard,

  input scan
);

wire i_mem_recv_hazard_w;
wire d_mem_recv_hazard_w;

// When a page or access fault happens, stop wating on valid data from the
// memory hierarchy and let the instruction progress down the pipeline so the
// exception can be handled
assign i_mem_recv_hazard = i_mem_page_fault   ? 1'b0 :
                           i_mem_access_fault ? 1'b0 :
                           i_mem_recv_hazard_w;

assign d_mem_recv_hazard = d_mem_page_fault   ? 1'b0 :
                           d_mem_access_fault ? 1'b0 :
                           d_mem_recv_hazard_w;

hazard_detection_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) BASE_HAZARD_UNIT (
  .clock(clock),
  .reset(reset),
  .fetch_ready(fetch_ready),
  .fetch_valid(fetch_valid),
  .issue_request(issue_request),
  .issue_PC(issue_PC),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),

  .load_memory(load_memory),
  .store_memory(store_memory),
  .load_address(load_address),
  .memory_address_in(memory_address_in),

  .opcode_decode(opcode_decode),
  .opcode_execute(opcode_execute),
  .branch_execute(branch_execute),

  .solo_instr_decode(solo_instr_decode),
  .solo_instr_execute(solo_instr_execute),
  .solo_instr_memory_issue(solo_instr_memory_issue),
  .solo_instr_memory_receive(solo_instr_memory_receive),
  .solo_instr_writeback(solo_instr_writeback),

  .i_mem_issue_hazard(i_mem_issue_hazard),
  .i_mem_recv_hazard(i_mem_recv_hazard_w),
  .d_mem_issue_hazard(d_mem_issue_hazard),
  .d_mem_recv_hazard(d_mem_recv_hazard_w),
  .JALR_branch_hazard(JALR_branch_hazard),
  .JAL_hazard(JAL_hazard),
  .solo_instr_hazard(solo_instr_hazard),

  .scan(scan)
);


reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Privileged Hazard Detection Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| I-Mem Iss Hazard   [%b]", i_mem_issue_hazard);
    $display ("| I-Mem Recv Hazard  [%b]", i_mem_recv_hazard);
    $display ("| D-Mem Iss Hazard   [%b]", d_mem_issue_hazard);
    $display ("| D-Mem Recv Hazard  [%b]", d_mem_recv_hazard);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
