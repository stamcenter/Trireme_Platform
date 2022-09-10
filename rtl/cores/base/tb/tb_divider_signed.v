/** @module : tb_divider_signed
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

module tb_divider_signed();

parameter DIV_SIZE=8;
parameter SIGNED="True";
//Adds FRACTION_BITS bits to the quotient as fixed point fraction bits
parameter FRACTION_BITS=0;

integer n;
integer d;

reg  clock;
reg  reset;
reg  ready_i;
reg  start;
reg  [DIV_SIZE-1:0] numerator;
reg  [DIV_SIZE-1:0] denominator;
wire signed [DIV_SIZE-1:0] numerator_s;
wire signed [DIV_SIZE-1:0] denominator_s;
wire [DIV_SIZE+FRACTION_BITS-1:0] quotient;
wire [DIV_SIZE-1:0] remainder;
wire valid;
wire ready_o;

reg signed [DIV_SIZE+FRACTION_BITS-1:0] expected_quotient;
reg signed [DIV_SIZE-1:0] expected_r;

assign numerator_s   = numerator;
assign denominator_s = denominator;

divider #(
  .DIV_SIZE(DIV_SIZE),
  .SIGNED(SIGNED),
  //Adds FRACTION_BITS bits to the quotient as fixed point fraction bits
  .FRACTION_BITS(FRACTION_BITS)
) DUT (
  .clock(clock),
  .reset(reset),
  .ready_i(ready_i),
  .start(start),
  .numerator(numerator),
  .denominator(denominator),
  .quotient(quotient),
  .remainder(remainder),
  .valid(valid),
  .ready_o(ready_o)
);


always #5 clock = ~clock;

reg [2:0] test;

initial begin
  clock       = 1'b1;
  reset       = 1'b1;
  ready_i     = 1'b1;
  start       = 1'b0;
  numerator   = 8'd0;
  denominator = 8'd0;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);


  // Positive divide by Positive
  numerator   = 29;
  denominator = 10;

  expected_quotient = 2;
  expected_r        = 9;
  start       = 1'b1;

  repeat (1) @ (posedge clock);
  start       = 1'b0;

  wait(valid);
  #1
  if( quotient  !== expected_quotient |
      remainder !== expected_r        ) begin

    $display("%d/%d",numerator, denominator);
    $display("\nError: Unexpected Division Result for %d/%d!",numerator, denominator);
    $display("Quotient: %d, Expected Quotient: %d", quotient, expected_quotient);
    $display("Remainder: %d, Expected Remainder: %d", remainder, expected_r);
    $display("\ntb_divider_signed --> Test Failed!\n\n");
    $stop();
  end

  $display("29/10 Test Passed!");

  repeat (1) @ (posedge clock);

  // Negative divide by Positive
  numerator   = -29;
  denominator = 10;

  expected_quotient = -2;
  expected_r        = -9; // Remainder keeps sign of numerator
  start       = 1'b1;

  repeat (1) @ (posedge clock);
  start       = 1'b0;

  wait(valid);
  #1
  if( quotient  !== expected_quotient |
      remainder !== expected_r        ) begin

    $display("%h/%h",numerator, denominator);
    $display("\nError: Unexpected Division Result for %h/%h!",numerator, denominator);
    $display("Quotient: %h, Expected Quotient: %h", quotient, expected_quotient);
    $display("Remainder: %h, Expected Remainder: %h", remainder, expected_r);
    $display("\ntb_divider_signed --> Test Failed!\n\n");
    $stop();
  end

  $display("-29/10 Test Passed!");


  repeat (1) @ (posedge clock);

  // Positive divide by Negative
  numerator   = 29;
  denominator = -10;

  expected_quotient = -2;
  expected_r        = 9; // Remainder keeps sign of numerator
  start       = 1'b1;

  repeat (1) @ (posedge clock);
  start       = 1'b0;

  wait(valid);
  #1
  if( quotient  !== expected_quotient |
      remainder !== expected_r        ) begin

    $display("%h/%h",numerator, denominator);
    $display("\nError: Unexpected Division Result for %h/%h!",numerator, denominator);
    $display("Quotient: %h, Expected Quotient: %h", quotient, expected_quotient);
    $display("Remainder: %h, Expected Remainder: %h", remainder, expected_r);
    $display("\ntb_divider_signed --> Test Failed!\n\n");
    $stop();
  end

  $display("29/-10 Test Passed!");

  repeat (1) @ (posedge clock);

  // Positive divide by Negative
  numerator   = -29;
  denominator = -10;

  expected_quotient = 2;
  expected_r        = -9; // Remainder keeps sign of numerator
  start       = 1'b1;

  repeat (1) @ (posedge clock);
  start       = 1'b0;

  wait(valid);
  #1
  if( quotient  !== expected_quotient |
      remainder !== expected_r        ) begin

    $display("%h/%h",numerator, denominator);
    $display("\nError: Unexpected Division Result for %h/%h!",numerator, denominator);
    $display("Quotient: %h, Expected Quotient: %h", quotient, expected_quotient);
    $display("Remainder: %h, Expected Remainder: %h", remainder, expected_r);
    $display("\ntb_divider_signed --> Test Failed!\n\n");
    $stop();
  end

  $display("-29/-10 Test Passed!");

  repeat (1) @ (posedge clock);

  // Test division by 0
  numerator   = 1;
  denominator = 0;

  expected_quotient = {DIV_SIZE{1'b1}};
  expected_r        = numerator;
  start       = 1'b1;

  repeat (1) @ (posedge clock);
  start       = 1'b0;

  wait(valid);
  #1
  if( quotient  !== expected_quotient |
      remainder !== expected_r        ) begin

    $display("%d/%d",numerator, denominator);
    $display("\nError: Unexpected Division Result for %d/%d!",numerator, denominator);
    $display("Quotient: %d, Expected Quotient: %d", quotient, expected_quotient);
    $display("Remainder: %d, Expected Remainder: %d", remainder, expected_r);
    $display("\ntb_divider_unsigned --> Test Failed!\n\n");
    $stop();
  end

  $display("1/0 Test Passed!");

  repeat (1) @ (posedge clock);

  // Test overflow
  numerator   = 8'h80;
  denominator = 8'hff;

  expected_quotient = 8'h80;
  expected_r        = 0;
  start       = 1'b1;

  repeat (1) @ (posedge clock);
  start       = 1'b0;

  wait(valid);
  #1
  if( quotient  !== expected_quotient |
      remainder !== expected_r        ) begin

    $display("%d/%d",numerator, denominator);
    $display("\nError: Unexpected Division Result for %d/%d!",numerator, denominator);
    $display("Quotient: %d, Expected Quotient: %d", quotient, expected_quotient);
    $display("Remainder: %d, Expected Remainder: %d", remainder, expected_r);
    $display("\ntb_divider_unsigned --> Test Failed!\n\n");
    $stop();
  end

  $display("-128/-1 (Overflow) Test Passed!");

  repeat (1) @ (posedge clock);
  $display("\ntb_divider_signed --> Test Passed!\n\n");
  $stop();
end


endmodule
