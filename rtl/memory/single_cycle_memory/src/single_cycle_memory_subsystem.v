/** @module : single_cycle_memory_subsystem
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

module single_cycle_memory_subsystem #(
  parameter CORE             = 0,
  parameter DATA_WIDTH       = 32,
  parameter ADDRESS_BITS     = 32,
  parameter I_ADDRESS_BITS   = 8,
  parameter D_ADDRESS_BITS   = 12,
  parameter SCAN_CYCLES_MIN  = 0,
  parameter SCAN_CYCLES_MAX  = 1000
) (
  input  clock,
  input  reset,
  //instruction memory
  input  i_mem_read,
  input  [ADDRESS_BITS-1:0] i_mem_address_in,
  output [DATA_WIDTH-1  :0] i_mem_data_out,
  output [ADDRESS_BITS-1:0] i_mem_address_out,
  output i_mem_valid,
  output i_mem_ready,
  //data memory
  input  d_mem_read,
  input  d_mem_write,
  input  [DATA_WIDTH/8-1:0] d_mem_byte_en,
  input  [ADDRESS_BITS-1:0] d_mem_address_in,
  input  [DATA_WIDTH-1  :0] d_mem_data_in,
  output [DATA_WIDTH-1  :0] d_mem_data_out,
  output [ADDRESS_BITS-1:0] d_mem_address_out,
  output d_mem_valid,
  output d_mem_ready,

  input  scan
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

localparam NUM_BYTES = DATA_WIDTH/8;

//instantiate two BSRAMs as instruction and data memory
//BSRAM_byte_en_flat #(
BSRAM_byte_en #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(I_ADDRESS_BITS-log2(NUM_BYTES)) // convert byte address to word address
) instruction_memory (
  .clock(clock),
  .reset(reset),
  .readEnable(i_mem_read),
//  .readAddress(i_mem_address_in[0 +: I_ADDRESS_BITS]),
  .readAddress(i_mem_address_in[2 +: I_ADDRESS_BITS-2]),
  .readData(i_mem_data_out),
  .writeEnable(1'b0),
  .writeByteEnable(4'b0000),
  .writeAddress({I_ADDRESS_BITS-2{1'b0}}),
  .writeData({DATA_WIDTH{1'b0}}),
  .scan(scan)
);

//BSRAM_byte_en_flat #(
BSRAM_byte_en #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(D_ADDRESS_BITS-log2(NUM_BYTES)) // convert byte address to word address
) data_memory (
  .clock(clock),
  .reset(reset),
  .readEnable(d_mem_read),
  .readAddress(d_mem_address_in[D_ADDRESS_BITS-1:log2(NUM_BYTES)]),
  .readData(d_mem_data_out),
  .writeEnable(d_mem_write),
  .writeByteEnable(d_mem_byte_en),
  .writeAddress(d_mem_address_in[D_ADDRESS_BITS-1:log2(NUM_BYTES)]),
  .writeData(d_mem_data_in),
  .scan(scan)
);


//assign outputs
assign i_mem_valid = i_mem_read;
assign i_mem_ready = 1'b1;
assign d_mem_valid = d_mem_read;
assign d_mem_ready = 1'b1;

assign i_mem_address_out = i_mem_address_in;
assign d_mem_address_out = d_mem_address_in;

endmodule
