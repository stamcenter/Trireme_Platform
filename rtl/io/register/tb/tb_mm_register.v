/** @module : tb_mm_register
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

module tb_mm_register();

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 8;

reg  clock;
reg  reset;

// Output register value
wire [DATA_WIDTH*1-1:0] register1;
wire [DATA_WIDTH*2-1:0] register2;

// Memory Mapped Port
reg  readEnable1;
reg  writeEnable1;
reg  readEnable2;
reg  writeEnable2;
reg  [DATA_WIDTH/8-1:0] writeByteEnable;
reg  [ADDR_WIDTH-1:0] address;
reg  [DATA_WIDTH-1:0] writeData;
wire [DATA_WIDTH-1:0] readData1;
wire [DATA_WIDTH-1:0] readData2;


mm_register #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH),
  .NUM_REGS(1)
) DUT1 (
  .clock(clock),
  .reset(reset),

  // Output register value
  .register(register1),

  // Memory Mapped Port
  .readEnable(readEnable1),
  .writeEnable(writeEnable1),
  .writeByteEnable(writeByteEnable),
  .address(address),
  .writeData(writeData),
  .readData(readData1)

);

mm_register #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH),
  .NUM_REGS(2)
) DUT2 (
  .clock(clock),
  .reset(reset),

  // Output register value
  .register(register2),

  // Memory Mapped Port
  .readEnable(readEnable2),
  .writeEnable(writeEnable2),
  .writeByteEnable(writeByteEnable),
  .address(address),
  .writeData(writeData),
  .readData(readData2)

);


always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;

  readEnable1  = 1'b0;
  writeEnable1 = 1'b0;
  readEnable2  = 1'b0;
  writeEnable2 = 1'b0;
  writeByteEnable = 4'hf;
  address   = 8'h00;
  writeData = 32'h00000000;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);


  writeEnable1 = 1'b1;
  writeData    = 32'hAAAAAAAA;

  repeat (1) @ (posedge clock);
  #1
  if( register1 !== 32'hAAAAAAAA         |
      register2 !== 64'h0000000000000000 ) begin
    $display("%h, %h", register1, register2);
    $display("\nError: Unexpected register 1 value!");
    $display("\ntb_mm_register --> Test Failed!\n\n");
    $stop();
  end

  writeEnable1 = 1'b0;
  writeEnable2 = 1'b1;
  writeData    = 32'hBBBBBBBB;

  repeat (1) @ (posedge clock);
  #1
  if( register1 !== 32'hAAAAAAAA         |
      register2 !== 64'h00000000BBBBBBBB ) begin
    $display("\nError: Unexpected register2[0] value!");
    $display("\ntb_mm_register --> Test Failed!\n\n");
    $stop();
  end

  writeEnable2 = 1'b1;
  address      = 8'h1;
  writeData    = 32'hCCCCCCCC;

  repeat (1) @ (posedge clock);
  #1
  if( register1 !== 32'hAAAAAAAA         |
      register2 !== 64'hCCCCCCCCBBBBBBBB ) begin
    $display("\nError: Unexpected register2[1] value!");
    $display("\ntb_mm_register --> Test Failed!\n\n");
    $stop();
  end

  writeEnable2 = 1'b0;

  readEnable1  = 1'b1;
  readEnable2  = 1'b1;
  address      = 8'h0;

  repeat (1) @ (posedge clock);
  #1
  if( readData1 !== 32'hAAAAAAAA |
      readData2 !== 32'hBBBBBBBB ) begin
    $display("\nError: Unexpected read data values!");
    $display("\ntb_mm_register --> Test Failed!\n\n");
    $stop();
  end

  repeat (1) @ (posedge clock);

  $display("\ntb_mm_register --> Test Passed!\n\n");
  $stop();

end

endmodule
