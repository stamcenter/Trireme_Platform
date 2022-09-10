/** @module : tb_writeback_unit_CSR
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

module tb_writeback_unit_CSR();

reg clock;
reg reset;
reg opWrite;
reg opSel;
reg CSR_read_data_valid;
reg [4:0] opReg;
reg [31:0] ALU_result;
reg [31:0] CSR_read_data;
reg [31:0] memory_data;

wire write;
wire [4:0] write_reg;
wire [31:0] write_data;

reg  scan;

writeback_unit_CSR #(
  .CORE(0),
  .DATA_WIDTH(32)
) writeback (
  .clock(clock),
  .reset(reset),

  .opWrite(opWrite),
  .opSel(opSel),
  .CSR_read_data_valid(CSR_read_data_valid),
  .opReg(opReg),
  .ALU_result(ALU_result),
  .CSR_read_data(CSR_read_data),
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
  opWrite       = 1;
  opSel         = 0;
  opReg         = 0;
  ALU_result    = 2;
  CSR_read_data = 1;
  CSR_read_data_valid = 1'b0;
  memory_data   = 0;
  scan        = 0;

  repeat (3) @ (posedge clock);
  reset = 0;
  repeat (1) @ (posedge clock);


  if( write      != 1 |
      write_data != 2 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: ALU Writeback failed!");
    $display("\ntb_writeback_unit_CSR --> Test Failed!\n\n");
    $stop();
  end

  CSR_read_data_valid = 1'b1;

  repeat (1) @ (posedge clock);

  if( write      != 1 |
      write_data != 1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: CSR Writeback failed!");
    $display("\ntb_writeback_unit_CSR --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_writeback_unit_CSR --> Test Passed!\n\n");
  $stop();

end

endmodule
