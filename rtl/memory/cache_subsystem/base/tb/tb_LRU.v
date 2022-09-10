/** @module : tb_LRU
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

module tb_LRU();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

    parameter WIDTH=4;
    parameter INDEX_BITS = 8;

    reg clock, reset;
    reg [INDEX_BITS-1:0] current_index;
    reg [log2(WIDTH)-1:0] access;
    reg access_valid;
    wire [WIDTH-1:0] lru;

    LRU #(
        .WIDTH(WIDTH),
        .INDEX_BITS(INDEX_BITS)
    ) DUT (
        .clock        (clock        ),
        .reset        (reset        ),
        .current_index(current_index),
        .access       (access       ),
        .access_valid (access_valid ),
        .lru          (lru          )
    );


    always #1 clock = ~clock;
integer n;

initial begin
clock = 0;
reset = 0;
current_index = 1;
access_valid  = 0;
access = 0;
n = 0;

@(posedge clock) reset <= 1;
repeat(5) @(posedge clock);
@(posedge clock) reset <= 0;
if (lru == 8)
    n = n + 1; // 1 if all passed

repeat(2) @(posedge clock);
@(posedge clock)begin
  access <= 2;
  access_valid <= 1;
  if (lru == 8)
    n = n + 1; //2 if all passed
end
@(posedge clock) access_valid <= 0;

repeat(4) @(posedge clock);
@(posedge clock)begin
    access <= 1;
    access_valid <= 1;
    if (lru == 8)
        n = n + 1; //3 if all passed
end
@(posedge clock)begin
    access <= 3;
    access_valid <= 1;
    if (lru == 8)
        n = n + 1; //4 if all passed
end
@(posedge clock) access_valid <= 0;

repeat(4) @(posedge clock);
@(posedge clock)begin
  access <= 2;
  access_valid <= 1;
  if (lru == 1)
    n = n + 1; // 5 if all passed
end
@(posedge clock)begin
    access <= 0;
    access_valid <= 1;
    if (lru == 1)
        n = n + 1; // 6 if all passed
end
@(posedge clock) access_valid <= 0;

if(n == 6)begin
  $display("All tests passed.");
  $display("\ntb_LRU --> Test Passed!\n\n");
  $stop;
end
else begin
  $display("Failed one or more tests; simulation ends.");
  $display("\ntb_lRU --> Test Failed!\n\n");
  $stop;
end
end

endmodule
