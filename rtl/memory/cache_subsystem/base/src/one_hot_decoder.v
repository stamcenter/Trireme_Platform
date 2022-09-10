/** @module : one_hot_decoder
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

module one_hot_decoder #(
parameter WIDTH = 16
) (
encoded,
decoded,
valid
);

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction


input [WIDTH-1 : 0] encoded;
output [log2(WIDTH)-1 : 0] decoded;
output valid;

generate
  wire decoded_half_valid;
  wire top_half_has_one;

  if (WIDTH==2)begin
    assign valid = encoded[1] | encoded [0];
    assign decoded = encoded[1];
  end
  else begin
    assign top_half_has_one = |encoded[WIDTH-1 : WIDTH/2];
    assign decoded[log2(WIDTH)-1] = top_half_has_one;
    assign valid = top_half_has_one | decoded_half_valid;

    one_hot_decoder #(WIDTH/2) decode_half (
      .encoded(top_half_has_one ? encoded[WIDTH-1 : WIDTH/2] 
      : encoded[(WIDTH/2)-1 : 0]),
      .decoded(decoded[log2(WIDTH)-2 : 0]),
      .valid(decoded_half_valid)	);
  end
endgenerate


endmodule
