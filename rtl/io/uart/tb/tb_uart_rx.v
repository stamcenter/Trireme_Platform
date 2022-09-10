/** @module : tb_uart_rx
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
module tb_uart_rx();

parameter CLOCK_FREQUENCY = 25125000; // 100MHz
parameter BAUD_RATE       = 9600;

reg clock;
reg reset;

reg serial_rx;
wire rx_valid;
wire [7:0] rx_data;

reg clock_baud;

localparam CLOCKS_PER_BIT = CLOCK_FREQUENCY/BAUD_RATE;

uart_rx #(
  .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
  .BAUD_RATE(BAUD_RATE)
) UUT (
  .clock(clock),
  .reset(reset),

  .serial_rx(serial_rx),
  .rx_valid(rx_valid),
  .rx_data(rx_data)
);


always #20 clock = ~clock;

// 9600^-1/10^-9 = 104167 ns per tick
always #52083 clock_baud = ~clock_baud;

initial begin
  clock = 1'b1;
  reset = 1'b1;
  clock_baud = 1'b1;

  serial_rx = 1'b1;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock_baud);
  // Start bit
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 0
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 1
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 2
  serial_rx = 1'b1;
  repeat (1) @ (posedge clock_baud);
  // Data bit 3
  serial_rx = 1'b1;
  repeat (1) @ (posedge clock_baud);
  // Data bit 4
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 5
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 6
  serial_rx = 1'b1;
  repeat (1) @ (posedge clock_baud);
  // Data bit 7
  serial_rx = 1'b1;
  repeat (1) @ (posedge clock_baud);
  // Stop bit
  serial_rx = 1'b1;

  repeat (3) @ (posedge clock_baud);
  // Start bit
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 0
  serial_rx = 1'b1;
  repeat (1) @ (posedge clock_baud);
  // Data bit 1
  serial_rx = 1'b1;
  repeat (1) @ (posedge clock_baud);
  // Data bit 2
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 3
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 4
  serial_rx = 1'b1;
  repeat (1) @ (posedge clock_baud);
  // Data bit 5
  serial_rx = 1'b1;
  repeat (1) @ (posedge clock_baud);
  // Data bit 6
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Data bit 7
  serial_rx = 1'b0;
  repeat (1) @ (posedge clock_baud);
  // Stop bit
  serial_rx = 1'b1;

  repeat (3) @ (posedge clock_baud);
  $display("\nError! Timeout");
  $display("\ntb_uart_rx --> Test Failed!\n\n");
  $stop();

end

initial begin
  wait(rx_valid) begin
    if( rx_valid !== 1'b1  |
        rx_data  !== 8'hCC ) begin
      $display("\nError! Unexpected data 1");
      $display("Valid: %b, Data: %h", rx_valid, rx_data);
      $display("\ntb_uart_rx --> Test Failed!\n\n");
      $stop;
    end

    repeat (1) @ (posedge clock);
    #1
    if( rx_valid !== 1'b0  |
        rx_data  !== 8'h00 ) begin
      $display("\nError! Unexpected idle 1");
      $display("Valid: %b, Data: %h", rx_valid, rx_data);
      $display("\ntb_uart_rx --> Test Failed!\n\n");
      $stop;
    end
  end

  wait(rx_valid) begin
    if( rx_valid !== 1'b1  |
        rx_data  !== 8'h33 ) begin
      $display("\nError! Unexpected data 2");
      $display("Valid: %b, Data: %h", rx_valid, rx_data);
      $display("\ntb_uart_rx --> Test Failed!\n\n");
      $stop;
    end

    repeat (1) @ (posedge clock);
    #1
    if( rx_valid !== 1'b0  |
        rx_data  !== 8'h00 ) begin
      $display("\nError! Unexpected idle 2");
      $display("Valid: %b, Data: %h", rx_valid, rx_data);
      $display("\ntb_uart_rx --> Test Failed!\n\n");
      $stop;
    end
  end

  repeat (1) @ (posedge clock);
  $display("\ntb_uart_rx --> Test Passed!\n\n");
  $stop;

end

endmodule
