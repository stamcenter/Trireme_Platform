/** @module : five_stage_stall_unit
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

module five_stage_stall_unit #(
  parameter CORE            = 0,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input true_data_hazard,
  //input d_mem_hazard,
  input d_mem_issue_hazard,
  input d_mem_recv_hazard,
  input i_mem_hazard,
  input JALR_branch_hazard,
  input JAL_hazard,

  output stall_decode,
  output stall_execute,
  output stall_memory,

  output flush_decode,
  output flush_execute,
  output flush_writeback,

  input scan

);

wire d_mem_hazard;

// OR together different data memory hazards
assign d_mem_hazard = d_mem_issue_hazard | d_mem_recv_hazard;

/*******************************************************************************
 * Stall and Flush Priorities
 *
 * Hazards with higher priorities will have their associated operation
 * (stall or flush) output, overriding lower priority conditions. Only
 * decode and execute stages have both stall and flush operations.
 *
 * Decode Pipe Priorities
 *
 * -- higher priority
 * #1 D-Memory Hazards    (Stall)
 * #2 Branch/JALR Hazards (Flush)
 * #3 True Data Hazards   (Stall)
 * #4 JAL Hazards         (Flush)
 * #5 I-Memory Hazards    (Flush)
 * -- lower priority
 *
 * Execute Pipe Priorities
 *
 * -- higher priority
 * #1 D-Memory Hazards    (Stall)
 * #2 True Data Hazards   (Flush)
 * #3 Branch/JALR Hazards (Flush)
 * -- lower priority
 *
 ******************************************************************************/
assign stall_decode  = d_mem_hazard | (true_data_hazard & ~JALR_branch_hazard);
assign stall_execute = d_mem_hazard;
assign stall_memory  = d_mem_hazard;

assign flush_decode = (JALR_branch_hazard & ~d_mem_hazard) |
                      ((JAL_hazard | i_mem_hazard) & ~true_data_hazard & ~d_mem_hazard);

assign flush_execute = (true_data_hazard | JALR_branch_hazard)  & ~d_mem_hazard;
assign flush_writeback = d_mem_hazard;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Five Stage Stall Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| Stall Decode     [%b]", stall_decode);
    $display ("| Stall Execute    [%b]", stall_execute);
    $display ("| Stall Memory     [%b]", stall_memory);
    $display ("| Flush Decode     [%b]", flush_decode);
    $display ("| Flush Execute    [%b]", flush_execute);
    $display ("| Flush Write Back [%b]", flush_writeback);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
