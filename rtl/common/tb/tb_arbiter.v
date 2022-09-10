/** @module : tb_arbiter
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

module tb_arbiter();

task print_state;
  begin
    $display("Requests       :%b", requests);
    $display("Granted access :%0d", grant);
    $display("Valid          :%0d", valid);
  end
endtask

parameter WIDTH = 8;
parameter ARB_TYPE = "PACKET";

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

reg clock;
reg reset;
reg [WIDTH-1 : 0] requests;
wire [log2(WIDTH)-1 : 0] grant;
wire valid;

// instantiate DUT
arbiter #(
  .WIDTH(WIDTH),
  .ARB_TYPE(ARB_TYPE)
) DUT (
  .clock(clock),
  .reset(reset),
  .requests(requests),
  .grant(grant),
  .valid(valid)
);

// generate clock
always #5 clock <= ~clock;

initial begin

	clock <= 1;
	reset <= 1;
	requests <= 8'b01101010;
	#45;
	reset <= 0;
  #1;
  if(grant != 1 || ~valid)begin
    $display("\ntb_arbiter --> Test Failed!\n\n");
    print_state();
    $stop;
  end
	#55;
	requests <= 8'b01101000;
  #1;
  if(grant != 3 || ~valid)begin
    $display("\ntb_arbiter --> Test Failed!\n\n");
    print_state();
    $stop;
  end
	#60;
	requests <= 8'b01100000;
  #1;
  if(grant != 5 || ~valid)begin
    $display("\ntb_arbiter --> Test Failed!\n\n");
    print_state();
    $stop;
  end
	#80;
	requests <= 8'b01101010;
  #1;
  if(grant != 5 || ~valid)begin
    $display("\ntb_arbiter --> Test Failed!\n\n");
    print_state();
    $stop;
  end
	#40;
	requests <= 8'b01001010;
  #1;
  if(grant != 6 || ~valid)begin
    $display("\ntb_arbiter --> Test Failed!\n\n");
    print_state();
    $stop;
  end
	#40;
	requests <= 8'b00001011;
  #1;
  if(grant != 0 || ~valid)begin
    $display("\ntb_arbiter --> Test Failed!\n\n");
    print_state();
    $stop;
  end
	#50;
	requests <= 8'b00001010;
  #1;
  if(grant != 1)begin
    $display("\ntb_arbiter --> Test Failed!\n\n");
    print_state();
    $stop;
  end
	#50;
	requests <= 8'b00000000;
  #1;
  if(grant != 0 || valid)begin
    $display("\ntb_arbiter --> Test Failed!\n\n");
    print_state();
    $stop;
  end

$display("\ntb_arbiter --> Test Passed!\n\n");
$stop;
end

endmodule
