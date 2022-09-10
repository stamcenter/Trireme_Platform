/** @module : tb_seven_stage_priv_stall_unit
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

module tb_seven_stage_priv_stall_unit();

parameter CORE            = 0;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

reg clock;
reg reset;
reg true_data_hazard;
reg execute_invalid_hazard;
reg d_mem_issue_hazard;
reg d_mem_recv_hazard;
reg i_mem_issue_hazard;
reg i_mem_recv_hazard;
reg JALR_branch_hazard;
reg JAL_hazard;
reg trap_hazard;
reg solo_instr_hazard;

reg clog;

wire stall_fetch_receive;
wire stall_decode;
wire stall_execute;
wire stall_memory_issue;
wire stall_memory_receive;

wire flush_fetch_receive;
wire flush_decode;
wire flush_execute;
wire flush_memory_issue;
wire flush_memory_receive;
wire flush_writeback;


reg scan;

seven_stage_priv_stall_unit #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
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
  .trap_hazard(trap_hazard),
  .solo_instr_hazard(solo_instr_hazard),

  .clog(clog),

  .stall_fetch_receive(stall_fetch_receive),
  .stall_decode(stall_decode),
  .stall_execute(stall_execute),
  .stall_memory_issue(stall_memory_issue),
  .stall_memory_receive(stall_memory_receive),

  .flush_fetch_receive(flush_fetch_receive),
  .flush_decode(flush_decode),
  .flush_execute(flush_execute),
  .flush_memory_issue(flush_memory_issue),
  .flush_memory_receive(flush_memory_receive),
  .flush_writeback(flush_writeback),

  .scan(scan)
);


always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;
  true_data_hazard = 1'b0;
  execute_invalid_hazard = 1'b0;
  d_mem_issue_hazard = 1'b0;
  d_mem_recv_hazard = 1'b0;
  i_mem_issue_hazard = 1'b0;
  i_mem_recv_hazard = 1'b0;
  JALR_branch_hazard = 1'b0;
  JAL_hazard = 1'b0;
  trap_hazard = 1'b0;
  solo_instr_hazard = 1'b0;
  clog = 1'b0;

  repeat (1) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  if( stall_fetch_receive  != 1'b0 |
      stall_decode         != 1'b0 |
      stall_execute        != 1'b0 |
      stall_memory_issue   != 1'b0 |
      stall_memory_receive != 1'b0 |
      flush_fetch_receive  != 1'b0 |
      flush_decode         != 1'b0 |
      flush_execute        != 1'b0 |
      flush_memory_issue   != 1'b0 |
      flush_memory_receive != 1'b0 |
      flush_writeback      != 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Stalls and flush should all be 0!");
    $display("\ntb_seven_stage_priv_stall_unit --> Test Failed!\n\n");
    $stop();
  end

  true_data_hazard = 1'b0;
  d_mem_issue_hazard = 1'b0;
  d_mem_recv_hazard = 1'b0;
  i_mem_issue_hazard = 1'b0;
  i_mem_recv_hazard = 1'b0;
  JALR_branch_hazard = 1'b0;
  JAL_hazard = 1'b0;
  trap_hazard = 1'b1;
  clog = 1'b0;

  repeat (1) @ (posedge clock);

  if( stall_fetch_receive  != 1'b0 |
      stall_decode         != 1'b0 |
      stall_execute        != 1'b0 |
      stall_memory_issue   != 1'b0 |
      stall_memory_receive != 1'b0 |
      flush_fetch_receive  != 1'b1 |
      flush_decode         != 1'b1 |
      flush_execute        != 1'b1 |
      flush_memory_issue   != 1'b1 |
      flush_memory_receive != 1'b1 |
      flush_writeback      != 1'b1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: All flush signals should be high during trap hazard!");
    $display("\ntb_seven_stage_priv_stall_unit --> Test Failed!\n\n");
    $stop();
  end

  repeat (1) @ (posedge clock);
  $display("\ntb_seven_stage_priv_stall_unit --> Test Passed!\n\n");
  $stop();

end

always@(posedge clock) begin
  if(stall_decode & flush_decode) begin
    $display("\nError: Stall and Flush decode are both 1!");
    $display("\ntb_seven_stage_priv_stall_unit --> Test Failed!\n\n");
    $stop();
  end
  if(stall_execute & flush_execute) begin
    $display("\nError: Stall and Flush execute are both 1!");
    $display("\ntb_seven_stage_priv_stall_unit --> Test Failed!\n\n");
    $stop();
  end

end


endmodule
