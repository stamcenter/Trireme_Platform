/** @module : seven_stage_priv_stall_unit
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

module seven_stage_priv_stall_unit #(
  parameter CORE            = 0,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input true_data_hazard,
  input execute_invalid_hazard,
  input d_mem_issue_hazard,
  input d_mem_recv_hazard,
  input i_mem_issue_hazard,
  input i_mem_recv_hazard,
  input JALR_branch_hazard,
  input JAL_hazard,
  input trap_hazard,
  input solo_instr_hazard,

  input clog,

  output stall_fetch_receive,
  output stall_decode,
  output stall_execute,
  output stall_memory_issue,
  output stall_memory_receive,

  output flush_fetch_receive,
  output flush_decode,
  output flush_execute,
  output flush_memory_issue,
  output flush_memory_receive,
  output flush_writeback,

  input scan

);

wire flush_fetch_receive_base;
wire flush_decode_base;
wire flush_execute_base;
wire flush_memory_issue_base;
wire flush_memory_receive_base;
wire flush_writeback_base;

wire flush_fetch_receive_priv;
wire flush_decode_priv;

assign flush_fetch_receive  = flush_fetch_receive_base  | flush_fetch_receive_priv;
assign flush_decode         = flush_decode_base         | flush_decode_priv;
assign flush_execute        = flush_execute_base        | trap_hazard;
assign flush_memory_issue   = flush_memory_issue_base   | trap_hazard;
assign flush_memory_receive = flush_memory_receive_base | trap_hazard;
assign flush_writeback      = flush_writeback_base      | trap_hazard;

assign flush_fetch_receive_priv = trap_hazard |
  (solo_instr_hazard & ~d_mem_issue_hazard & ~d_mem_recv_hazard & ~true_data_hazard & ~JAL_hazard);

assign flush_decode_priv = trap_hazard |
  (solo_instr_hazard & ~d_mem_issue_hazard & ~d_mem_recv_hazard & ~true_data_hazard);


// Replace base fetch receive with new logic that includes solo_instr_hazard
assign stall_fetch_receive = (d_mem_issue_hazard & ~clog)                     |
                             (d_mem_recv_hazard  & ~clog)                     |
                             (true_data_hazard & ~JALR_branch_hazard & ~clog) |
                             (execute_invalid_hazard & ~JALR_branch_hazard & ~clog)  |
                             ( i_mem_recv_hazard & ~JALR_branch_hazard & ~JAL_hazard & ~solo_instr_hazard);


seven_stage_stall_unit #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) BASE_STALL_UNIT (
  .clock(clock),
  .reset(reset),
  .true_data_hazard(true_data_hazard),
  .execute_invalid_hazard(execute_invalid_hazard),
  .d_mem_issue_hazard(d_mem_issue_hazard),
  .d_mem_recv_hazard(d_mem_recv_hazard),
  .i_mem_issue_hazard(i_mem_issue_hazard),
  .i_mem_recv_hazard(i_mem_recv_hazard),
  .JALR_branch_hazard(JALR_branch_hazard),
  .JAL_hazard(JAL_hazard),

  .clog(clog),

  .stall_fetch_receive(),
  .stall_decode(stall_decode),
  .stall_execute(stall_execute),
  .stall_memory_issue(stall_memory_issue),
  .stall_memory_receive(stall_memory_receive),

  .flush_fetch_receive(flush_fetch_receive_base),
  .flush_decode(flush_decode_base),
  .flush_execute(flush_execute_base),
  .flush_memory_issue(flush_memory_issue_base),
  .flush_memory_receive(flush_memory_receive_base),
  .flush_writeback(flush_writeback_base),

  .scan(scan)
);


reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Privileged Seven Stage Stall Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| Flush Fetch Rec  [%b]", flush_fetch_receive);
    $display ("| Flush Decode     [%b]", flush_decode);
    $display ("| Flush Execute    [%b]", flush_execute);
    $display ("| Flush Memory Rec [%b]", flush_memory_receive);
    $display ("| Flush Write Back [%b]", flush_writeback);
    $display ("| Stall Fetch Rec  [%b]", stall_fetch_receive);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
