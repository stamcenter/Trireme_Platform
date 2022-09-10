/** @module : tb_uart_tx
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

`timescale 1ns/1ps
module tb_uart_tx();

parameter CLOCK_FREQUENCY = 25125000; // 100MHz
parameter BAUD_RATE       = 9600;


reg clock;
reg reset;
reg tx_valid;
reg [7:0] tx_data_in;
wire serial_tx;
wire tx_busy;

reg clock_baud;

localparam CLOCKS_PER_BIT = CLOCK_FREQUENCY/BAUD_RATE;

uart_tx #(
  .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
  .BAUD_RATE(BAUD_RATE)
) UUT (
  .clock(clock),
  .reset(reset),
  .tx_valid(tx_valid),
  .tx_data_in(tx_data_in),
  .serial_tx(serial_tx),
  .tx_busy(tx_busy)
);

always #20 clock = ~clock;

// 9600^-1/10^-9 = 104167 ns per tick
always #52083 clock_baud = ~clock_baud;

initial begin
  clock      = 1'b1;
  reset      = 1'b1;
  clock_baud = 1'b1;

  tx_valid   = 1'b0;
  tx_data_in = 8'h00;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (3) @ (posedge clock);

  tx_valid   = 1'b1;
  tx_data_in = 8'hCC;

  repeat (1) @ (posedge clock);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b1 ) begin
    $display("\nError! Unexpected busy signal.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  tx_valid   = 1'b0;
  tx_data_in = 8'h33;
  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b0 ) begin
    $display("\nError! Unexpected start bit.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b0 ) begin
    $display("\nError! Unexpected bit 0.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b0 ) begin
    $display("\nError! Unexpected bit 1.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b1 ) begin
    $display("\nError! Unexpected bit 2.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b1 ) begin
    $display("\nError! Unexpected bit 3.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b0 ) begin
    $display("\nError! Unexpected bit 4.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b0 ) begin
    $display("\nError! Unexpected bit 5.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b1 ) begin
    $display("\nError! Unexpected bit 6.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b1 ) begin
    $display("\nError! Unexpected bit 7.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b1 |
      serial_tx !== 1'b1 ) begin
    $display("\nError! Unexpected bit stop_bit.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock_baud);
  #1
  if( tx_busy   !== 1'b0 |
      serial_tx !== 1'b1 ) begin
    $display("\nError! Unexpected bit idle state.");
    $display("TX Busy: %b, Serial TX: %b", tx_busy, serial_tx);
    $display("\ntb_uart_tx --> Test Failed!\n\n");
    $stop;
  end

  repeat (1) @ (posedge clock);
  $display("\ntb_uart_tx --> Test Passed!\n\n");
  $stop;




end


endmodule
