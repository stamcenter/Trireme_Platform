/** @module : tb_empty_way_select
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

module tb_empty_way_select();

task print_state;
  begin
    $display("Ways in use   :%b", ways_in_use);
    $display("Next empty way:%b", next_empty_way);
    $display("Valid         :%b", valid);
  end
endtask

parameter WIDTH = 8;

reg [WIDTH-1:0] ways_in_use;
wire [WIDTH-1:0] next_empty_way;
wire valid;

// Instantiate DUT
empty_way_select #(WIDTH) DUT (ways_in_use, next_empty_way, valid);

initial begin
	ways_in_use = 8'b00000000;
  #10	ways_in_use = 8'b00000001;
  #10	ways_in_use = 8'b00000011;
  #10	ways_in_use = 8'b00000111;
  #10	ways_in_use = 8'b00001001;
  #10	ways_in_use = 8'b01110010;
  #10	ways_in_use = 8'b11111111;
  #10	ways_in_use = 8'b00000000;
  #10	ways_in_use = 8'b01111111;
end

//Automatic checking code
initial begin
  #5;
  if(next_empty_way != 1 || valid != 1)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  if(next_empty_way != 2 || valid != 1)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  if(next_empty_way != 4 || valid != 1)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  if(next_empty_way != 8 || valid != 1)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  if(next_empty_way != 2 || valid != 1)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  if(next_empty_way != 1 || valid != 1)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  if(next_empty_way != 0 || valid != 0)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  if(next_empty_way != 1 || valid != 1)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  if(next_empty_way != 8'b10000000 || valid != 1)begin
    $display("\ntb_empty_way_select --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  #10;
  $display("\ntb_empty_way_select --> Test Passed!\n\n");
  $finish;
end

endmodule
