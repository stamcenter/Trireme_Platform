/** @module : mm_register
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


module mm_register #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 8,
  parameter NUM_REGS  = 1
) (
  input clock,
  input reset,

  // Output register value
  output [DATA_WIDTH*NUM_REGS-1:0] register,

  // Memory Mapped Port
  input  readEnable,
  input  writeEnable,
  input  [DATA_WIDTH/8-1:0] writeByteEnable,
  input  [ADDR_WIDTH-1:0] address,
  input  [DATA_WIDTH-1:0] writeData,
  output reg [DATA_WIDTH-1:0] readData

);

//define the log2 function
function integer log2;
  input integer num;
  integer i, result;
  begin
    for (i = 0; 2 ** i < num; i = i + 1)
      result = i + 1;
    log2 = result;
  end
endfunction

localparam REG_ADDRESS_BITS = NUM_REGS>1 ? log2(NUM_REGS) : 1;

genvar i;
integer j;

wire [REG_ADDRESS_BITS-1:0] reg_address;
reg [DATA_WIDTH-1:0] register_s [NUM_REGS-1:0];


// Flatten register_s to single output vector
generate
  for(i=0; i<NUM_REGS; i=i+1) begin : REG_LOOP
    assign register[i*DATA_WIDTH +: DATA_WIDTH] = register_s[i];
  end
endgenerate

generate
  if(NUM_REGS == 1) begin
    assign reg_address = 1'b0;
  end
  else begin
    assign reg_address = address[REG_ADDRESS_BITS-1:0];
  end
endgenerate

// Read Logic
always@(posedge clock) begin
  if(reset) begin
    readData <= {DATA_WIDTH{1'b0}};
  end
  else if(readEnable) begin
    readData <= register_s[reg_address];
  end
  else begin
    readData <= {DATA_WIDTH{1'b0}};
  end
end

// Write Logic
always@(posedge clock) begin
  if(reset) begin
    for(j=0; j<NUM_REGS; j=j+1) begin
      register_s[j] <= {DATA_WIDTH{1'b0}};
    end
  end
  else if(writeEnable) begin
    for(j=0; j<DATA_WIDTH/8; j=j+1) begin
      if(writeByteEnable[j]) begin
        register_s[reg_address][j*8 +: 8] <= writeData[j*8 +: 8];
      end
    end
  end
end


endmodule
