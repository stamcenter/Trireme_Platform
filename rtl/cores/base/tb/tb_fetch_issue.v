/** @module : tb_fetch_issue
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

module tb_fetch_issue();

parameter RESET_PC         =  0;
parameter ADDRESS_BITS     = 32;

reg  clock;
reg  reset;
reg  [1:0] next_PC_select;
reg  [ADDRESS_BITS-1:0] target_PC;
wire [ADDRESS_BITS-1:0] issue_PC;

// instruction cache interface
wire [ADDRESS_BITS-1:0] i_mem_read_address;

reg  scan;

//instantiate DUT
fetch_issue #(
  .RESET_PC(RESET_PC),
  .ADDRESS_BITS(ADDRESS_BITS)
) DUT (
  .clock(clock),
  .reset(reset),
  .next_PC_select(next_PC_select),
  .target_PC(target_PC),
  .issue_PC(issue_PC),
  .i_mem_read_address(i_mem_read_address),
  .scan(scan)
);

// generate clock signal
always #5 clock = ~clock;

initial begin
  clock  = 1;
  reset  = 1;
  next_PC_select = 0;
  target_PC      = 0;
  scan           = 0;

  repeat (3) @ (posedge clock);
  reset          = 1'b0;
  next_PC_select = 0;

  repeat (1) @ (posedge clock);
  #1
  if(issue_PC !== 4)begin
    $display("\nTest 1 Error!");
    $display("\ntb_fetch_issue --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock);
  #1
  if(issue_PC !== 8)begin
    $display("\nTest 2 Error!");
    $display("\ntb_fetch_issue --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock);
  #1
  if(issue_PC !== 32'd12)begin
    $display("\nTest 3 Error!");
    $display("\ntb_fetch_issue --> Test Failed!\n\n");
    $stop;
  end

  next_PC_select = 2'b10;
  target_PC      = 32'h8000;
  repeat (1) @ (posedge clock);
  #1
  if(issue_PC != 32'h8000)begin
    $display("\nTest 4 Error!");
    $display("\ntb_fetch_issue --> Test Failed!\n\n");
    $stop;
  end

  next_PC_select = 0;

  repeat (1) @ (posedge clock);
  $display("\ntb_fetch_issue --> Test Passed!\n\n");
  $stop;

end

endmodule
