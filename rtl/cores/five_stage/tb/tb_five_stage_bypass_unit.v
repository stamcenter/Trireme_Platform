/** @module : tb_five_stage_bypass_unit
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

module tb_five_stage_bypass_unit();

parameter CORE            = 0;
parameter DATA_WIDTH      = 32;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

reg clock;
reg reset;

reg true_data_hazard;

reg rs1_hazard_execute;
reg rs1_hazard_memory;
reg rs1_hazard_writeback;

reg rs2_hazard_execute;
reg rs2_hazard_memory;
reg rs2_hazard_writeback;

wire [1:0] rs1_data_bypass;
wire [1:0] rs2_data_bypass;

reg scan;

five_stage_bypass_unit #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  .clock(clock),
  .reset(reset),

  .true_data_hazard(true_data_hazard),

  .rs1_hazard_execute(rs1_hazard_execute),
  .rs1_hazard_memory(rs1_hazard_memory),
  .rs1_hazard_writeback(rs1_hazard_writeback),

  .rs2_hazard_execute(rs2_hazard_execute),
  .rs2_hazard_memory(rs2_hazard_memory),
  .rs2_hazard_writeback(rs2_hazard_writeback),

  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),

  .scan(scan)
);

always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;

  true_data_hazard = 1'b0;

  rs1_hazard_execute = 1'b0;
  rs1_hazard_memory = 1'b0;
  rs1_hazard_writeback = 1'b0;

  rs2_hazard_execute = 1'b0;
  rs2_hazard_memory = 1'b0;
  rs2_hazard_writeback = 1'b0;

  scan = 1'b0;

  repeat (1) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  if( rs1_data_bypass != 2'b00 |
      rs2_data_bypass != 2'b00 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Bypassing should not be active!");
    $display("\ntb_five_stage_bypass_unit --> Test Failed!\n\n");
    $stop();
  end

  true_data_hazard = 1'b0;

  rs1_hazard_execute = 1'b1;
  rs1_hazard_memory = 1'b0;
  rs1_hazard_writeback = 1'b0;

  rs2_hazard_execute = 1'b1;
  rs2_hazard_memory = 1'b0;
  rs2_hazard_writeback = 1'b0;

  repeat (1) @ (posedge clock);

  if( rs1_data_bypass != 2'b01 |
      rs2_data_bypass != 2'b01 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Execute data should be forwarded!");
    $display("\ntb_five_stage_bypass_unit --> Test Failed!\n\n");
    $stop();
  end

  true_data_hazard = 1'b0;

  rs1_hazard_execute = 1'b0;
  rs1_hazard_memory = 1'b1;
  rs1_hazard_writeback = 1'b0;

  rs2_hazard_execute = 1'b0;
  rs2_hazard_memory = 1'b0;
  rs2_hazard_writeback = 1'b1;

  repeat (1) @ (posedge clock);

  if( rs1_data_bypass != 2'b10 |
      rs2_data_bypass != 2'b11 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Memory data should be forwarded to RS1 and");
    $display("       writeback data should be forwarded to RS2!");
    $display("\ntb_five_stage_bypass_unit --> Test Failed!\n\n");
    $stop();
  end

  true_data_hazard = 1'b1;

  rs1_hazard_execute = 1'b0;
  rs1_hazard_memory = 1'b1;
  rs1_hazard_writeback = 1'b0;

  rs2_hazard_execute = 1'b0;
  rs2_hazard_memory = 1'b0;
  rs2_hazard_writeback = 1'b1;


  repeat (1) @ (posedge clock);

  if( rs1_data_bypass != 2'b00 |
      rs2_data_bypass != 2'b00 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Bypassing should not be active during true data hazards!");
    $display("\ntb_five_stage_bypass_unit --> Test Failed!\n\n");
    $stop();
  end

  repeat (1) @ (posedge clock);
  $display("\ntb_five_stage_bypass_unit --> Test Passed!\n\n");
  $stop();

end

endmodule
