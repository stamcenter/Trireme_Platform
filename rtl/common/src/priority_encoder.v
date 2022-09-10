/** @module : priority_encoder
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

module priority_encoder #(
  parameter WIDTH    = 8,
  parameter PRIORITY = "MSB"
) (
  input [WIDTH-1 : 0] decode,
  output [log2(WIDTH)-1 : 0] encode,
  output valid
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

function integer is_power_of_2;
  input integer value;
  integer power;
  integer result;
begin
  power = 1;
  result = 0;

  if(value == 0) begin
    result = 1;
  end
  else begin
    for( power=1; power<=value; power = power << 1) begin
      if(power == value) begin
        result = 1;
      end
    end
  end
  is_power_of_2 = result;
end
endfunction


genvar i;
generate
  if(is_power_of_2(WIDTH)) begin
    //-------------------------------------------------------------------------
    // Priority encoder for WIDTHs equal to a power of 2
    //-------------------------------------------------------------------------
    wire encoded_half_valid;
    wire half_has_one;

    if (WIDTH==2)begin
      assign valid = decode[1] | decode [0];
      assign encode = ((PRIORITY == "LSB") & decode[0]) ? 0 : decode[1];
    end
    else begin
      assign half_has_one = (PRIORITY == "LSB") ? |decode[(WIDTH/2)-1 : 0]
                          : |decode[WIDTH-1 : WIDTH/2];
      assign encode[log2(WIDTH)-1] = ((PRIORITY == "MSB") & half_has_one) ? 1
                                   : ((PRIORITY == "LSB") & ~half_has_one &
                                     valid) ? 1
                                   : 0;
      assign valid = half_has_one | encoded_half_valid;

      if(PRIORITY == "MSB")
        priority_encoder #((WIDTH/2), PRIORITY)
        decode_half (
          .decode(half_has_one ? decode[WIDTH-1 : WIDTH/2] :
            decode[(WIDTH/2)-1 : 0]),
          .encode(encode[log2(WIDTH)-2 : 0]),
          .valid(encoded_half_valid)
        );

      else
        priority_encoder #((WIDTH/2), PRIORITY)
        decode_half (
          .decode(half_has_one ? decode[(WIDTH/2)-1 : 0] : decode[WIDTH-1 :
           WIDTH/2]),
          .encode(encode[log2(WIDTH)-2 : 0]),
          .valid(encoded_half_valid)
        );
    end
  end
  else begin
    //-------------------------------------------------------------------------
    // Priority encoder for all other WIDTHs
    //-------------------------------------------------------------------------
    wire [log2(WIDTH)-1:0] mux_chain [WIDTH-1:0];

    assign encode = mux_chain[0];
    assign valid  = |decode;

    if(PRIORITY == "MSB") begin

      for(i=0; i<WIDTH-1; i=i+1) begin : MSB_LOOP
        assign mux_chain[i] = decode[WIDTH-1-i] ? WIDTH-1-i : mux_chain[i+1];
      end

      assign mux_chain[WIDTH-1] = 0;

    end
    else begin // PRIORITY == "LSB"

      for(i=0; i<WIDTH-1; i=i+1) begin : LSB_LOOP
        assign mux_chain[i] = decode[i] ? i : mux_chain[i+1];
      end // For

      assign mux_chain[WIDTH-1] = WIDTH-1;

    end // if LSB

  end
endgenerate


endmodule
