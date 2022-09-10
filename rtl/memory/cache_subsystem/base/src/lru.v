/** @module : LRU
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

module LRU #( 
parameter WIDTH      = 4,
          INDEX_BITS = 8
) (
  input clock,
  input reset,
  input [INDEX_BITS-1 : 0] current_index,
  input [log2(WIDTH)-1:0] access,
  input access_valid,
  output [WIDTH-1:0] lru
);
    
//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction
	
localparam CACHE_DEPTH   =   1 << INDEX_BITS;
localparam LRU_MEM_WIDTH = log2(WIDTH)*WIDTH;

genvar  i;
integer j;

wire [LRU_MEM_WIDTH-1 : 0] data_in0, data_in1, data_out0, data_out1, init_data;
wire [INDEX_BITS-1 : 0] address0, address1;
wire [log2(WIDTH)-1:0] w_order [WIDTH-1 : 0];
wire [LRU_MEM_WIDTH-1 : 0] c_order;
wire we1;
wire we0;
reg  [INDEX_BITS-1 : 0] r_current_index;

dual_port_RAM #(LRU_MEM_WIDTH, INDEX_BITS, INDEX_BITS, "NEW_DATA") 
  lru_bram (clock, we0, we1, data_in0, data_in1, address0, address1,
  data_out0, data_out1);
// Port 0 is used for writing. Port 1 is for reading.

generate
  for(i=0; i<WIDTH; i=i+1)begin : ASSIGNS
    assign init_data[i*log2(WIDTH) +: log2(WIDTH)] = i;
    assign w_order[i] = data_out1[i*log2(WIDTH) +: log2(WIDTH)];
  end
  for(i=0; i<WIDTH; i=i+1)begin:C_ORDER
    assign c_order[i*log2(WIDTH) +: log2(WIDTH)] = we0 ? (access == i) ? 0
      : (w_order[access] > w_order[i]) ? w_order[i] + 1   : w_order[i] : 0;
  end
endgenerate

assign we1      = reset ? 1 : 0;
assign data_in1 = reset ? init_data : 0;
assign address1 = current_index;

assign data_in0 = c_order;
assign address0 = r_current_index;

assign we0 = access_valid & ~reset;

always @(posedge clock)begin
  r_current_index <= current_index;
end

generate
  for(i=0; i<WIDTH; i=i+1)begin:LRU
    assign lru[i] = w_order[i] == (WIDTH-1);
  end
endgenerate

endmodule
