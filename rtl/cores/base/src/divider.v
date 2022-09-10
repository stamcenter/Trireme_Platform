/** @module : divider
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

module divider #(
  parameter DIV_SIZE=32,
  parameter SIGNED = "False",
  //Adds FRACTION_BITS bits to the quotient as fixed point fraction bits
  parameter FRACTION_BITS=0
) (
  input clock,
  input reset,
  input ready_i,
  input start,
  input [DIV_SIZE-1:0] numerator,
  input [DIV_SIZE-1:0] denominator,
  output reg [DIV_SIZE+FRACTION_BITS-1:0] quotient,
  output reg [DIV_SIZE-1:0] remainder,
  output reg valid,
  output ready_o
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

localparam DIV_CYCLES = DIV_SIZE + FRACTION_BITS;

// States
localparam IDLE   = 3'd0;
localparam ABS    = 3'd1;
localparam DIV    = 3'd2;
localparam INVERT = 3'd3;
localparam OUTPUT = 3'd4;

reg invert_q;
reg invert_r;
reg [DIV_SIZE:0] B;
reg [log2(DIV_CYCLES):0] count; // counts division iterations
reg [2:0] state;
wire [DIV_CYCLES:0] difference, shifted_r;

assign shifted_r = {remainder, quotient[DIV_CYCLES-1]};
assign difference = shifted_r - B;

assign ready_o  = state == IDLE;

always@(posedge clock) begin
  if(reset) begin
    invert_q  <= 1'b0;
    invert_r  <= 1'b0;
    quotient  <= {DIV_CYCLES{1'b0}};
    B         <= {DIV_SIZE+1{1'b0}};
    remainder <= {DIV_SIZE{1'b0}};
    count     <= {log2(DIV_CYCLES){1'b0}};
    valid     <= 1'b0;
    state     <= IDLE;
  end
  else begin
    case (state)
      IDLE: begin
        count <= {log2(DIV_CYCLES){1'b0}};
        valid <= 1'b0;
        if(start) begin
          invert_q  <= (SIGNED == "True") ? numerator[DIV_SIZE-1] ^ denominator[DIV_SIZE-1] : 1'b0;
          invert_r  <= (SIGNED == "True") ? numerator[DIV_SIZE-1]  : 1'b0;
          quotient  <= {numerator, {FRACTION_BITS{1'b0}} };
          B         <= (SIGNED == "True") ? {denominator[DIV_SIZE-1], denominator} :
                       {1'b0, denominator};
          remainder <= {DIV_SIZE{1'b0}};
          // If division is signed and inputs are negative, take their
          // absolute value before dividing them.
          state     <= (SIGNED == "True") & numerator[DIV_CYCLES-1] ? ABS :
                       (SIGNED == "True") & denominator[DIV_SIZE-1] ? ABS :
                       DIV;
        end
      end
      ABS: begin
        quotient  <= quotient[DIV_CYCLES-1] ? (~quotient ) + 1'b1 : quotient;
        B         <= B       [DIV_SIZE-1]   ? (~B        ) + 1'b1 : B        ;
        state     <= DIV;
      end
      DIV: begin
        if (B > shifted_r) begin
          {remainder, quotient} <= {remainder[DIV_SIZE-2:0], quotient, 1'b0};
        end
        else begin // B <= shifted_r
          {remainder, quotient} <= {difference, quotient[DIV_CYCLES-2:0], 1'b1};
        end

        count <= count + 1'b1;
        state <= (count >= DIV_CYCLES-1) & invert_r ? INVERT :
                 (count >= DIV_CYCLES-1) & invert_q ? INVERT :
                 (count >= DIV_CYCLES-1)            ? OUTPUT :
                 DIV;
      end
      INVERT: begin
        quotient  <= invert_q ? (~quotient ) + 1'b1 : quotient;
        remainder <= invert_r ? (~remainder) + 1'b1 : remainder;
        state     <= OUTPUT;
      end
      OUTPUT: begin
        valid <= ready_i;
        state <= ready_i ? IDLE : OUTPUT;
      end
    endcase
  end
end


endmodule
