/** @module : tb_replacement_controller
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

module tb_replacement_controller();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter NUMBER_OF_WAYS = 4;
parameter INDEX_BITS     = 8;

reg clock, reset;
reg [INDEX_BITS-1 : 0] current_index;
reg [NUMBER_OF_WAYS-1 : 0]ways_in_use;
reg replacement_policy_select;
reg [log2(NUMBER_OF_WAYS)-1 : 0]current_access;
reg access_valid;
reg report;
wire [NUMBER_OF_WAYS-1 : 0]selected_way;


// Instantiate DUT
replacement_controller #(NUMBER_OF_WAYS, INDEX_BITS) DUT 
  (clock, reset, ways_in_use, current_index, replacement_policy_select, 
  current_access, access_valid, report, selected_way);

// Generate clock
always #5 clock = ~clock;


initial begin
	replacement_policy_select = 0; // LRU
  current_index = 1;
	report = 1;
	clock = 1;
	reset = 1;
	ways_in_use = 4'b0000;
	current_access = 0;
	access_valid = 0;
	
	#50 reset = 0;
	current_access = 0;
	access_valid = 1;
	#10;
	ways_in_use = 4'b0001;
	access_valid = 0;
	#10;
	current_access = 1;
	access_valid = 1;
	#10;
	ways_in_use = 4'b0011;
	access_valid = 0;
	#10;
	access_valid = 1;
	current_access = 2;
	#10;
	ways_in_use = 4'b0111;
	current_access = 3;
	#10;
	ways_in_use = 4'b1111;
	access_valid = 0;
	#10;
	access_valid = 1;
	current_access = 2;
	#10;
	current_access = 1;
	#10;
	current_access = 3;
	#10;
	current_access = 0;
	#10;
	current_access = 2;
	#10;
	access_valid = 0;
	#10 ways_in_use = 0;
end

//automated validation code
initial begin
  #50;
  if(selected_way != 4'b0001)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #15;
  if(selected_way != 4'b0010)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #20;
  if(selected_way != 4'b0100)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #20;
  if(selected_way != 4'b1000)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(selected_way != 4'b0001)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #40;
  if(selected_way != 4'b0100)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(selected_way != 4'b0010)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(selected_way != 4'b0010)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(selected_way != 4'b0001)begin
    $display("\ntb_replacement_controller --> Test Failed!\n\n");
    $stop;
  end

  #10;
  $display("\ntb_replacement_controller --> Test Passed!\n\n");
  $finish;
end

endmodule
