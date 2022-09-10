/** @module : fetch_receive
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

module fetch_receive #(
  parameter DATA_WIDTH      =   32,
  parameter ADDRESS_BITS    =   32,
  parameter SCAN_CYCLES_MIN =    0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  // Control signals
  input  flush,

  // Instruction memory interface
  input  [DATA_WIDTH-1  :0] i_mem_data,
  input  [ADDRESS_BITS-1:0] issue_PC,

  // Outputs to with decode
  output [31            :0] instruction,

  //scan signal
  input scan
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

localparam NUM_BYTES       = DATA_WIDTH/8;
localparam LOG2_NUM_BYTES  = log2(NUM_BYTES);

localparam NOP = 32'h00000013;

wire [LOG2_NUM_BYTES-1:0] byte_shift;
wire [DATA_WIDTH-1:0] shifted_data;

generate
  if(DATA_WIDTH==32) begin
    // No need to shift in RV32, cut out shifter because synthesizer is
    // unlikely to automatically remove it.
    assign byte_shift = 1'b0;
    assign shifted_data = i_mem_data;
  end
  else begin
    // Shift Double wide i_mem_data if instruction is in upper 4 bytes
    assign byte_shift = issue_PC[LOG2_NUM_BYTES-1:0];
    assign shifted_data = i_mem_data >> {byte_shift, 3'b000};
  end
endgenerate

// Only support 32 bit instructions
assign instruction = flush ? NOP : shifted_data[31:0];

endmodule
