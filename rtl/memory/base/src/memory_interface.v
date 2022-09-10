/** @module : memory_interface
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

module memory_interface #(
  parameter DATA_WIDTH   = 32,
  parameter ADDRESS_BITS = 32
)(
  //fetch stage interface
  input  fetch_read,
  input  [ADDRESS_BITS-1:0] fetch_address_out,
  output [DATA_WIDTH-1  :0] fetch_data_in,
  output [ADDRESS_BITS-1:0] fetch_address_in,
  output fetch_valid,
  output fetch_ready,
  //memory stage interface
  input  memory_read,
  input  memory_write,
  input  [DATA_WIDTH/8-1:0] memory_byte_en,
  input  [ADDRESS_BITS-1:0] memory_address_out,
  input  [DATA_WIDTH-1  :0] memory_data_out,
  output [DATA_WIDTH-1  :0] memory_data_in,
  output [ADDRESS_BITS-1:0] memory_address_in,
  output memory_valid,
  output memory_ready,
  //instruction memory/cache interface
  input  [DATA_WIDTH-1  :0] i_mem_data_out,
  input  [ADDRESS_BITS-1:0] i_mem_address_out,
  input  i_mem_valid,
  input  i_mem_ready,
  output i_mem_read,
  output [ADDRESS_BITS-1:0] i_mem_address_in,
  //data memory/cache interface
  input  [DATA_WIDTH-1  :0] d_mem_data_out,
  input  [ADDRESS_BITS-1:0] d_mem_address_out,
  input  d_mem_valid,
  input  d_mem_ready,
  output d_mem_read,
  output d_mem_write,
  output [DATA_WIDTH/8-1:0] d_mem_byte_en,
  output [ADDRESS_BITS-1:0] d_mem_address_in,
  output [DATA_WIDTH-1  :0] d_mem_data_in,

  input scan
);

assign fetch_data_in     = i_mem_data_out;
assign fetch_address_in  = i_mem_address_out;
assign fetch_valid       = i_mem_valid;
assign fetch_ready       = i_mem_ready;

assign memory_data_in    = d_mem_data_out;
assign memory_address_in = d_mem_address_out;
assign memory_valid      = d_mem_valid;
assign memory_ready      = d_mem_ready;

assign i_mem_read        = fetch_read;
assign i_mem_address_in  = fetch_address_out;

assign d_mem_read        = memory_read;
assign d_mem_write       = memory_write;
assign d_mem_byte_en     = memory_byte_en;
assign d_mem_address_in  = memory_address_out;
assign d_mem_data_in     = memory_data_out;

endmodule
