/** @module : arbiter
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

module arbiter #(
  parameter WIDTH = 4,
  // Setting ARB_TYPE to PACKET will cause the granted request to remain valid
  // until the request is lowered, i.e. the whole packet has been processed.
  // Setting ARB_TYPE to CYCLE will cause the granted request to be updated each
  // cycle. So in a 4 port arbiter, if all for request lines are high, in 4
  // cycles, each request will have been granted for one cycle. Setting
  // ARB_TYPE to anything else selects the "TOP_ROT" arbitration type. The
  // "TOP_ROT" (as in Top Rotate) shifts the highest priority port each cycle.
  // The relative priority of ports not selected as the top/highest priority
  // remains constant (with port 0 having the highest non-top priority. The
  // "TOP_ROT" type shifts priority even if the granted request is still high
  // the next cycle (just like the CYCLE type).
  parameter ARB_TYPE = "PACKET"
) (
  input clock,
  input reset,
  input [WIDTH-1:0] requests,
  output [log2(WIDTH)-1:0] grant,
  output valid
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

integer j;

reg [WIDTH-1 : 0] mask;
wire [WIDTH-1 : 0] masked_requests;
wire [WIDTH-1 : 0] next_even_mask;
wire masked_valid;
wire unmasked_valid;
wire [log2(WIDTH)-1 : 0] masked_encoded;
wire [log2(WIDTH)-1 : 0] unmasked_encoded;

// Instantiate priority encoders
priority_encoder #(WIDTH, "LSB")
  masked_encoder(masked_requests, masked_encoded, masked_valid);
priority_encoder #(WIDTH, "LSB")
  unmasked_encoder(requests, unmasked_encoded, unmasked_valid);

always@(posedge clock)begin
  if(reset) begin
    mask <= (ARB_TYPE == "PACKET") ? {WIDTH{1'b0}} :
            (ARB_TYPE == "CYCLE" ) ? {WIDTH{1'b0}} :
            {{WIDTH-1{1'b0}}, 1'b1};
  end
  else begin
    for(j=0; j<WIDTH; j=j+1)begin
      mask[j] <= (ARB_TYPE == "PACKET") ? ~(j <  grant) :
                 (ARB_TYPE == "CYCLE" ) ? ~(j <= grant) :
                 // ARB_TYPE == "TOP_ROT"
                 (j == 0) ? mask[WIDTH-1] : mask[j-1];
    end
  end
end

assign masked_requests = requests & mask;
assign grant = (masked_requests == 0) ? unmasked_encoded : masked_encoded;
assign valid = |requests;

endmodule
