/** @module : five_stage_top
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

module five_stage_top #(
  parameter CORE            = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter MEM_ADDRESS_BITS = 14,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  input start,
  input [ADDRESS_BITS-1:0] program_address,

  output [ADDRESS_BITS-1:0] PC,

  input scan
);

localparam I_ADDRESS_BITS  = MEM_ADDRESS_BITS;
localparam D_ADDRESS_BITS  = MEM_ADDRESS_BITS;

//fetch stage interface
wire fetch_read;
wire [ADDRESS_BITS-1:0] fetch_address_out;
wire [DATA_WIDTH-1  :0] fetch_data_in;
wire [ADDRESS_BITS-1:0] fetch_address_in;
wire fetch_valid;
wire fetch_ready;
//memory stage interface
wire memory_read;
wire memory_write;
wire [DATA_WIDTH/8-1:0] memory_byte_en;
wire [ADDRESS_BITS-1:0] memory_address_out;
wire [DATA_WIDTH-1  :0] memory_data_out;
wire [DATA_WIDTH-1  :0] memory_data_in;
wire [ADDRESS_BITS-1:0] memory_address_in;
wire memory_valid;
wire memory_ready;
//instruction memory/cache interface
wire [DATA_WIDTH-1  :0] i_mem_data_out;
wire [ADDRESS_BITS-1:0] i_mem_address_out;
wire i_mem_valid;
wire i_mem_ready;
wire i_mem_read;
wire [ADDRESS_BITS-1:0] i_mem_address_in;
//data memory/cache interface
wire [DATA_WIDTH-1  :0] d_mem_data_out;
wire [ADDRESS_BITS-1:0] d_mem_address_out;
wire d_mem_valid;
wire d_mem_ready;
wire d_mem_read;
wire d_mem_write;
wire [DATA_WIDTH/8-1:0] d_mem_byte_en;
wire [ADDRESS_BITS-1:0] d_mem_address_in;
wire [DATA_WIDTH-1  :0] d_mem_data_in;

assign PC = fetch_address_in << 1;

five_stage_core #(
  .CORE(CORE),
  .RESET_PC(32'd0),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) core (
  .clock(clock),
  .reset(reset),
  .start(start),
  .program_address(program_address),
  //memory interface
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .fetch_data_in(fetch_data_in),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  .fetch_read(fetch_read),
  .fetch_address_out(fetch_address_out),
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address_out(memory_address_out),
  .memory_data_out(memory_data_out),
  //scan signal
  .scan(scan)
);

memory_interface #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) mem_interface (
  //fetch stage interface
  .fetch_read(fetch_read),
  .fetch_address_out(fetch_address_out),
  .fetch_data_in(fetch_data_in),
  .fetch_address_in(fetch_address_in),
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  //memory stage interface
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address_out(memory_address_out),
  .memory_data_out(memory_data_out),
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  //instruction memory/cache interface
  .i_mem_data_out(i_mem_data_out),
  .i_mem_address_out(i_mem_address_out),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_ready),
  .i_mem_read(i_mem_read),
  .i_mem_address_in(i_mem_address_in),
  //data memory/cache interface
  .d_mem_data_out(d_mem_data_out),
  .d_mem_address_out(d_mem_address_out),
  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),
  .d_mem_byte_en(d_mem_byte_en),
  .d_mem_address_in(d_mem_address_in),
  .d_mem_data_in(d_mem_data_in),

  .scan(scan)
);

single_cycle_memory_subsystem #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .I_ADDRESS_BITS(I_ADDRESS_BITS),
  .D_ADDRESS_BITS(D_ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) memory (
  .clock(clock),
  .reset(reset),
  //instruction memory
  .i_mem_read(i_mem_read),
  .i_mem_address_in(i_mem_address_in),
  .i_mem_data_out(i_mem_data_out),
  .i_mem_address_out(i_mem_address_out),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_ready),
  //data memory
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),
  .d_mem_byte_en(d_mem_byte_en),
  .d_mem_address_in(d_mem_address_in),
  .d_mem_data_in(d_mem_data_in),
  .d_mem_data_out(d_mem_data_out),
  .d_mem_address_out(d_mem_address_out),
  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),

  .scan(scan)
);

endmodule
