/** @module : dual_port_BRAM_memory_subsystem
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

module dual_port_BRAM_memory_subsystem #(
  parameter DATA_WIDTH       = 32,
  parameter ADDRESS_BITS     = 32,
  parameter MEM_ADDRESS_BITS = 12,
  parameter INIT_FILE_BASE   = "",
  parameter SCAN_CYCLES_MIN  = 0,
  parameter SCAN_CYCLES_MAX  = 1000
) (
  input      clock,
  input      reset,
  //instruction memory
  input      i_mem_read,
  input      [ADDRESS_BITS-1:0] i_mem_address_in,
  output     [DATA_WIDTH-1  :0] i_mem_data_out,
  output reg [ADDRESS_BITS-1:0] i_mem_address_out,
  output reg i_mem_valid,
  output     i_mem_ready,
  //data memory
  input      d_mem_read,
  input      d_mem_write,
  input      [DATA_WIDTH/8-1:0] d_mem_byte_en,
  input      [ADDRESS_BITS-1:0] d_mem_address_in,
  input      [DATA_WIDTH-1  :0] d_mem_data_in,
  output     [DATA_WIDTH-1  :0] d_mem_data_out,
  output reg [ADDRESS_BITS-1:0] d_mem_address_out,
  output reg d_mem_valid,
  output     d_mem_ready,
  //scan signal
  input      scan
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

dual_port_BRAM_byte_en #(
  .CORE(0),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(MEM_ADDRESS_BITS-log2(NUM_BYTES)),
  .INIT_FILE_BASE(INIT_FILE_BASE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) memory (
  .clock(clock),
  .reset(reset),
  // Port // instruction fetch
  .readEnable_1(i_mem_read),
  .writeEnable_1(1'b0),
  .writeByteEnable_1({NUM_BYTES{1'b0}}),
  .address_1(i_mem_address_in[MEM_ADDRESS_BITS-1:log2(NUM_BYTES)]),
  .writeData_1({DATA_WIDTH{1'b0}}),
  .readData_1(i_mem_data_out),
  // Port 2 // data memory operations
  .readEnable_2(d_mem_read),
  .writeEnable_2(d_mem_write),
  .writeByteEnable_2(d_mem_byte_en),
  .address_2(d_mem_address_in[MEM_ADDRESS_BITS-1:log2(NUM_BYTES)]),
  .writeData_2(d_mem_data_in),
  .readData_2(d_mem_data_out),
  // scan signal
  .scan(scan)
);

//assign outputs
always @(posedge clock)begin
  i_mem_valid       <= i_mem_read;
  i_mem_address_out <= i_mem_address_in;
  d_mem_valid       <= d_mem_read;
  d_mem_address_out <= d_mem_address_in;
end

assign i_mem_ready = 1'b1;
assign d_mem_ready = 1'b1;

endmodule
