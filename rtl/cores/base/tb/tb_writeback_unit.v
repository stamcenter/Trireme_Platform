/** @module : tb_writeback_unit
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

module tb_writeback_unit ();

reg clock;
reg reset;
reg opWrite;
reg opSel;
reg [4:0] opReg;
reg [31:0] ALU_result;
reg [31:0] memory_data;

wire write;
wire [4:0] write_reg;
wire [31:0] write_data;

reg  scan;

writeback_unit #(
  .CORE(0),
  .DATA_WIDTH(32)
) writeback (
  .clock(clock),
  .reset(reset),

  .opWrite(opWrite),
  .opSel(opSel),
  .opReg(opReg),
  .ALU_result(ALU_result),
  .memory_data(memory_data),

  .write(write),
  .write_reg(write_reg),
  .write_data(write_data),

  .scan(scan)
);


// Clock generator
always #1 clock = ~clock;

initial begin
  clock         = 0;
  reset         = 1;
  opWrite       = 0;
  opSel         = 0;
  opReg         = 0;
  ALU_result    = 0;
  memory_data   = 0;
  scan        = 0;

  #10 reset = 0;
  repeat (1) @ (posedge clock);

  opWrite       = 1;
  opSel         = 0;
  opReg         = 3;
  ALU_result    = 5;
  memory_data   = 9;
  repeat (1) @ (posedge clock);

  if( write      != 1 |
      write_reg  != 3 |
      write_data != 5 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: ALU Writeback failed!");
    $display("\ntb_writeback_unit --> Test Failed!\n\n");
    $stop();
  end


  opWrite       = 0;
  opSel         = 1;
  opReg         = 0;
  ALU_result    = 4;
  memory_data   = 8;
  repeat (1) @ (posedge clock);

  if( write      != 0 |
      write_reg  != 0 |
      write_data != 8 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Memory Writeback failed!");
    $display("\ntb_writeback_unit --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_writeback_unit --> Test Passed!\n\n");
  $stop();

end

endmodule
