/** @module : tb_timer
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
module tb_timer();

parameter DATA_WIDTH   = 32;
parameter ADDRESS_BITS = 32;
parameter MTIME_ADDR      = 32'h0020bff8;
parameter MTIME_ADDR_H    = 32'h0020bffC;
parameter MTIMECMP_ADDR   = 32'h00204000;
parameter MTIMECMP_ADDR_H = 32'h00204004;

reg clock;
reg reset;

reg readEnable;
reg writeEnable;
reg [DATA_WIDTH/8-1:0] writeByteEnable;
reg [ADDRESS_BITS-1:0] address;
reg [DATA_WIDTH-1:0] writeData;
wire [DATA_WIDTH-1:0] readData;

wire timer_interrupt;

timer #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MTIME_ADDR(MTIME_ADDR),
  .MTIME_ADDR_H(MTIME_ADDR_H),
  .MTIMECMP_ADDR(MTIMECMP_ADDR),
  .MTIMECMP_ADDR_H(MTIMECMP_ADDR_H)
) DUT (
  .clock(clock),
  .reset(reset),

  .readEnable(readEnable),
  .writeEnable(writeEnable),
  .writeByteEnable(writeByteEnable),
  .address(address),
  .writeData(writeData),
  .readData(readData),

  .timer_interrupt(timer_interrupt)
);

always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;

  readEnable = 1'b0;
  writeEnable = 1'b0;
  address = 32'd0;
  writeData = 32'd0;
  writeByteEnable = 4'b1111;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (10) @ (posedge clock);

  repeat (1) @ (posedge clock);
  readEnable = 1'b1;
  writeEnable = 1'b0;
  address = MTIME_ADDR;
  writeData = 32'd0;

  repeat (1) @ (posedge clock);
  #1
  if( readData !== 32'd11 ) begin
    $display("\nError: Unexpected mtime_l value!");
    $display("\ntb_timer --> Test Failed!\n\n");
    $stop();
  end
  repeat (1) @ (posedge clock);
  $display("\ntb_timer --> Test Passed!\n\n");
  $stop;
end

endmodule
