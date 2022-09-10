/** @module : tb_mm_uart
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

module tb_mm_uart ();

parameter CLOCK_FREQUENCY = 25000000; // 25MHz
parameter BAUD_RATE       = 115200;
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 32;
parameter RX_ADDR = 32'h90000010;
parameter TX_ADDR = 32'h90000020;
parameter RX_READY_ADDR = 32'h90000014;
parameter TX_READY_ADDR = 32'h90000024;

reg clock;
reg reset;

// UART Rx/Tx
wire uart_rx;
wire uart_tx;

// Memory Mapped Port
reg  readEnable;
reg  writeEnable;
reg  [DATA_WIDTH/8-1:0] writeByteEnable;
reg  [ADDR_WIDTH-1:0] address;
reg  [DATA_WIDTH-1:0] writeData;
wire [DATA_WIDTH-1:0] readData;

assign uart_rx = uart_tx;

mm_uart #(
  .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
  .BAUD_RATE(BAUD_RATE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH),
  .RX_ADDR(RX_ADDR),
  .TX_ADDR(TX_ADDR),
  .RX_READY_ADDR(RX_READY_ADDR),
  .TX_READY_ADDR(TX_READY_ADDR)
) DUT (
  .clock(clock),
  .reset(reset),

  // UART Rx/Tx
  .uart_rx(uart_rx),
  .uart_tx(uart_tx),

  // Memory Mapped Port
  .readEnable(readEnable),
  .writeEnable(writeEnable),
  .writeByteEnable(writeByteEnable),
  .address(address),
  .writeData(writeData),
  .readData(readData)
);

always #20 clock = ~clock;


initial begin

  clock = 1'b1;
  reset = 1'b1;

  readEnable = 1'b0;
  writeEnable = 1'b0;
  writeByteEnable = 4'h0;
  address = 0;
  writeData = 0;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  readEnable = 1'b1;
  writeEnable = 1'b0;
  writeByteEnable = 4'h0;
  address = TX_READY_ADDR;
  writeData = 32'h000000ab;

  repeat (1) @ (posedge clock);
  #1
  if( readData !== 32'd1 ) begin
    $display("Error! Unexpected TX_READY signal.");
    $stop;
  end

  readEnable = 1'b1;
  writeEnable = 1'b0;
  writeByteEnable = 4'h0;
  address = RX_READY_ADDR;
  writeData = 32'h000000ab;

  repeat (1) @ (posedge clock);
  #1
  if( readData !== 32'd0 ) begin
    $display("Error! Unexpected RX_READY signal.");
    $stop;
  end

  readEnable = 1'b1;
  writeEnable = 1'b1;
  writeByteEnable = 4'h1;
  address = TX_ADDR;
  writeData = 32'h000000ab;

  repeat (1) @ (posedge clock);
  #1
  if( readData !== 32'd0 ) begin
    $display("Error! Unexpected TX signal.");
    $stop;
  end

  readEnable = 1'b1;
  writeEnable = 1'b0;
  writeByteEnable = 4'h0;
  address = RX_READY_ADDR;
  writeData = 32'h000000ab;

  repeat (1) @ (posedge clock);
  #1
  if( readData !== 32'd0 ) begin
    $display("Error! Unexpected RX_READY signal immediatly after TX.");
    $stop;
  end

  repeat (1) @ (posedge clock);

  wait( readData == 32'd1 );

  repeat (1) @ (posedge clock);

  readEnable = 1'b1;
  writeEnable = 1'b0;
  writeByteEnable = 4'h0;
  address = RX_ADDR;
  writeData = 32'h00000000;

  repeat (1) @ (posedge clock);
  #1
  if( readData !== 32'h000001ab ) begin
    $display("Error! Unexpected RX data.");
    $stop;
  end

  repeat (1) @ (posedge clock);
  $display("\ntb_mm_uart --> Test Passed!\n\n");
  $stop;

end

endmodule
