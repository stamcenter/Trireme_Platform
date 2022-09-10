/** @module : seven_stage_stall_unit
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

module seven_stage_stall_unit #(
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

wire d_mem_hazard;
wire i_mem_hazard;

// OR together different data memory hazards
assign d_mem_hazard = d_mem_issue_hazard | d_mem_recv_hazard;
// OR together different instruction memory hazards
assign i_mem_hazard = i_mem_issue_hazard | i_mem_recv_hazard;

/*******************************************************************************
 * Stall and Flush Priorities
 *
 * Hazards with higher priorities will have their associated operation
 * (stall or flush) output, overriding lower priority conditions. Only
 * fetch receive, decode and execute stages have both stall and flush
 * operations.
 *
 * Fetch Receive Pipe Priorities
 *
 * -- higher priority
 * #1 D-Memory Hazards    (Stall)
 * #2 Branch/JALR Hazards (Flush)
 * #3 True Data Hazards   (Stall)
 * #4 Execute Invalid     (Stall)
 * #4 JAL Hazards         (Flush)
 * #5 Solo Instr Hazards  (Flush) (implemented in Priv module for now)
 * #6 I-Memory Hazards    (Stall)
 * -- lower priority
 *
 * Decode Pipe Priorities
 *
 * -- higher priority
 * #1 D-Memory Hazards    (Stall)
 * #2 Branch/JALR Hazards (Flush)
 * #3 True Data Hazards   (Stall)
 * #4 Execute Invalid     (Stall)
 * #5 JAL Hazards         (Flush)
 * #6 Solo Instr Hazards  (Flush) (implemented in Priv module for now)
 * #7 I-Memory Hazards    (Flush)
 * -- lower priority
 *
 * Execute Pipe Priorities
 *
 * -- higher priority
 * #1 D-Memory Hazards    (Stall)
 * #2 True Data Hazards   (Flush)
 * #3 Branch/JALR Hazards (Flush)
 * #4 Execute Invalid     (Stall)
 * -- lower priority
 *
 * Note that the clog signal indicates that the instruction memory has
 * returned data that was not registered because of a pipeline stall in the
 * decode stage. In the event of a pipeline clog, the PC that was missed is sent
 * back to the PC register to issue the missed memory request again. When the
 * PC is sent back to the PC register, the Fetch Receive pipe must be flushed
 * to prevent the missed instruction from entering the pipeline twice.
 *
 ******************************************************************************/


assign stall_fetch_receive  = (d_mem_hazard & ~clog)                           |
                             (true_data_hazard & ~JALR_branch_hazard & ~clog)  |
                             (execute_invalid_hazard & ~JALR_branch_hazard & ~clog)  |
                             ( i_mem_recv_hazard & ~JALR_branch_hazard & ~JAL_hazard); // TODO add solo signal here. Should be ok without it though. Pipeline registers prioritize flushes over stalls
assign stall_decode         = d_mem_hazard |
                              (true_data_hazard & ~JALR_branch_hazard) |
                              (execute_invalid_hazard & ~JALR_branch_hazard);

assign stall_execute        = d_mem_hazard |
                              (execute_invalid_hazard & ~true_data_hazard & ~JALR_branch_hazard);

assign stall_memory_issue   = d_mem_hazard;
assign stall_memory_receive = d_mem_recv_hazard;


assign flush_fetch_receive = (JALR_branch_hazard & ~d_mem_hazard) |
                             (JAL_hazard & ~d_mem_hazard & ~true_data_hazard & ~execute_invalid_hazard) |
                             /*( i_mem_issue_hazard & ~JALR_branch_hazard & ~JAL_hazard) | */ // This line looks like a mistake. it checks higer priority flush signals instead of stall signals
                             ( i_mem_issue_hazard & ~d_mem_hazard & ~true_data_hazard & ~execute_invalid_hazard & ~i_mem_recv_hazard) |
                             clog;

assign flush_decode = (JALR_branch_hazard & ~d_mem_hazard) |
                      ((JAL_hazard | i_mem_recv_hazard) & ~execute_invalid_hazard & ~true_data_hazard & ~d_mem_hazard);

assign flush_execute = (true_data_hazard | JALR_branch_hazard)  & ~d_mem_hazard;

assign flush_memory_issue   = execute_invalid_hazard & ~d_mem_recv_hazard & ~d_mem_issue_hazard;
assign flush_memory_receive = ~d_mem_recv_hazard & d_mem_issue_hazard;

assign flush_writeback = d_mem_recv_hazard;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Seven Stage Stall Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| Stall Fetch Rec  [%b]", stall_fetch_receive);
    $display ("| Stall Decode     [%b]", stall_decode);
    $display ("| Stall Execute    [%b]", stall_execute);
    $display ("| Stall Memory Iss [%b]", stall_memory_issue);
    $display ("| Stall Memory Rec [%b]", stall_memory_receive);
    $display ("| Flush Fetch Rec  [%b]", flush_fetch_receive);
    $display ("| Flush Decode     [%b]", flush_decode);
    $display ("| Flush Execute    [%b]", flush_execute);
    $display ("| Flush Memory Rec [%b]", flush_memory_receive);
    $display ("| Flush Write Back [%b]", flush_writeback);
    $display ("| Clog             [%b]", clog);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
