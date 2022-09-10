/** @module : mux_bus
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

module mux_bus #(
parameter WIDTH      = 8,
          NUM_PORTS  = 4
)(
input [WIDTH*NUM_PORTS-1 : 0] data_in,
input [log2(NUM_PORTS)-1 : 0] enable_port,
input valid_enable,
output [WIDTH-1 : 0] data_out
);

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value>>1;
  end
endfunction

genvar i;
wire [WIDTH-1 : 0] inputs [NUM_PORTS-1 : 0];

generate
  for(i=0; i<NUM_PORTS; i=i+1)begin: INPUT
    assign inputs[i] = data_in[i*WIDTH +: WIDTH];
  end
endgenerate

assign data_out = valid_enable ? inputs[enable_port] : 0;

endmodule
