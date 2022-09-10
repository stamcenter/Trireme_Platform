/** @module : pipeline_register
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

module pipeline_register #(
  parameter PIPELINE_STAGE  =  0,
  parameter PIPE_WIDTH      = 32,
  parameter SCAN_CYCLES_MIN =  1,
  parameter SCAN_CYCLES_MAX = 1000 
)(
  input  clock,
  input  reset,
  input  stall,
  input  flush,
  input  [PIPE_WIDTH-1:0] pipe_input,
  input  [PIPE_WIDTH-1:0] flush_input,
  output [PIPE_WIDTH-1:0] pipe_output,
  //scan signal
  input scan
);

reg [PIPE_WIDTH-1:0] pipe_reg;

always @(posedge clock)begin
  if(reset)
    pipe_reg <= {PIPE_WIDTH{1'b0}};
  else if(flush)
    pipe_reg <= flush_input;
  else if(stall)
    pipe_reg <= pipe_reg;
  else
    pipe_reg <= pipe_input;
end

assign pipe_output = pipe_reg;

endmodule
