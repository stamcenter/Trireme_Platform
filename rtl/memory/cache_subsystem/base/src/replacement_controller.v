/** @module : replacement_controller
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

module replacement_controller #(
parameter NUMBER_OF_WAYS = 8,
          INDEX_BITS     = 8
) (
clock, reset,
ways_in_use,
current_index,
replacement_policy_select,
current_access, access_valid,
report,
selected_way
);

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

input clock, reset;
input [NUMBER_OF_WAYS-1:0] ways_in_use;
input [INDEX_BITS-1 : 0] current_index;
input replacement_policy_select;	/* 0-LRU  1-Random */
input [log2(NUMBER_OF_WAYS)-1:0] current_access;
input access_valid;
input report;
output [NUMBER_OF_WAYS-1:0] selected_way;

wire [NUMBER_OF_WAYS-1:0] lru_way, random_way, next_empty_way;
wire [log2(NUMBER_OF_WAYS)-1 : 0] current_access_binary;
wire valid_decode, valid_empty_way;

// Instantiate LRU
LRU #(NUMBER_OF_WAYS, INDEX_BITS) 
  lru_inst (clock, reset, current_index, current_access, 
  access_valid, lru_way);

// Instantiate empty way select module
empty_way_select #(NUMBER_OF_WAYS) 
  empty_way_sel_inst (ways_in_use, next_empty_way, valid_empty_way);

assign random_way   = 0; //temporary assignment

assign selected_way = valid_empty_way ? next_empty_way 
                    : (replacement_policy_select)? random_way
                    : lru_way;

endmodule
