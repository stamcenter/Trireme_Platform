/** @module : single_cycle_cache_top
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

module single_cycle_cache_top #(
  parameter CORE             = 0,
  parameter DATA_WIDTH       = 32,
  parameter ADDRESS_BITS     = 32,
  parameter MEM_ADDRESS_BITS = 14,
  parameter SCAN_CYCLES_MIN  = 0,
  parameter SCAN_CYCLES_MAX  = 1000
) (
  input clock,
  input reset,

  input start,
  input [ADDRESS_BITS-1:0] program_address,

  output [ADDRESS_BITS-1:0] PC,

  input scan
);

localparam MSG_BITS  = 4;
localparam L2_OFFSET = 2;
localparam L2_WIDTH  = DATA_WIDTH*(1 << L2_OFFSET);
localparam NUM_L1_CACHES = 2;

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
//cache hierarchy to main memory interface signals
wire [MSG_BITS-1    :0]     intf2cachehier_msg;
wire [ADDRESS_BITS-1:0] intf2cachehier_address;
wire [L2_WIDTH-1    :0]    intf2cachehier_data;
wire [MSG_BITS-1    :0]     cachehier2intf_msg;
wire [ADDRESS_BITS-1:0] cachehier2intf_address;
wire [L2_WIDTH-1    :0]    cachehier2intf_data;
//main memory interface to main memory signals
wire [MSG_BITS-1    :0]     mem2intf_msg;
wire [ADDRESS_BITS-1:0] mem2intf_address;
wire [DATA_WIDTH-1  :0]    mem2intf_data;
wire [MSG_BITS-1    :0]     intf2mem_msg;
wire [ADDRESS_BITS-1:0] intf2mem_address;
wire [DATA_WIDTH-1  :0]    intf2mem_data;

assign PC = fetch_address_in;

single_cycle_core #(
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

/*cache hierarchy*/
two_level_cache_hierarchy #(
  .STATUS_BITS_L1(2),
  .OFFSET_BITS_L1({32'd2, 32'd2}),
  .NUMBER_OF_WAYS_L1({32'd4, 32'd4}),
  .INDEX_BITS_L1({32'd6, 32'd6}),
  .REPLACEMENT_MODE_L1(1'b0),
  .STATUS_BITS_L2(3),
  .OFFSET_BITS_L2(2),
  .NUMBER_OF_WAYS_L2(4),
  .INDEX_BITS_L2(8),
  .REPLACEMENT_MODE_L2(1'b0),
  .L2_INCLUSION(1'b1),
  .COHERENCE_BITS(2),
  .DATA_WIDTH(32),
  .ADDRESS_BITS(32),
  .MSG_BITS(4),
  .NUM_L1_CACHES(2),
  .BUS_OFFSET_BITS(2),
  .MAX_OFFSET_BITS(2)
) cache_hier (
  .clock(clock),
  .reset(reset),
  //interface with processor pipelines
  .read({d_mem_read, i_mem_read}),
  .write({d_mem_write, 1'b0}),
  .invalidate(2'b00),
  .w_byte_en({d_mem_byte_en, {DATA_WIDTH/8{1'b0}}}),
  .flush(2'b00),
  .address({d_mem_address_in, i_mem_address_in}),
  .data_in({d_mem_data_in, {DATA_WIDTH{1'b0}}}),
  .data_out({d_mem_data_out, i_mem_data_out}),
  .out_address({d_mem_address_out, i_mem_address_out}),
  .ready({d_mem_ready, i_mem_ready}),
  .valid({d_mem_valid, i_mem_valid}),
  //interface with memory side interface
  .mem2cachehier_msg(intf2cachehier_msg),
  .mem2cachehier_address(intf2cachehier_address),
  .mem2cachehier_data(intf2cachehier_data),
  .cachehier2mem_msg(cachehier2intf_msg),
  .cachehier2mem_address(cachehier2intf_address),
  .cachehier2mem_data(cachehier2intf_data),
  .mem_intf_busy(1'b0),
  .mem_intf_address(32'd0),
  .mem_intf_address_valid(1'b0),
  //interface for memory side interface to access cache memory
  .port1_read(1'b0),
  .port1_write(1'b0),
  .port1_invalidate(1'b0),
  .port1_index(8'd0),
  .port1_tag(22'b0),
  .port1_metadata(5'b0),
  .port1_write_data(128'd0),
  .port1_way_select(2'd0),
  .port1_read_data(),
  .port1_matched_way(),
  .port1_coh_bits(),
  .port1_status_bits(),
  .port1_hit(),
  
  .scan(scan)
);


/*Main memory interface*/
main_memory_interface #(
  .OFFSET_BITS(L2_OFFSET),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS)
) mem_intf (
  .clock(clock),
  .reset(reset),
  .cache2interface_msg(cachehier2intf_msg),
  .cache2interface_address(cachehier2intf_address),
  .cache2interface_data(cachehier2intf_data),
  .interface2cache_msg(intf2cachehier_msg),
  .interface2cache_address(intf2cachehier_address),
  .interface2cache_data(intf2cachehier_data),
  .mem2interface_msg(mem2intf_msg),
  .mem2interface_address(mem2intf_address),
  .mem2interface_data(mem2intf_data),
  .interface2mem_msg(intf2mem_msg),
  .interface2mem_address(intf2mem_address),
  .interface2mem_data(intf2mem_data)
);


/*Main memory*/
main_memory #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .INDEX_BITS(16),
  .NUM_PORTS(1),
  .PROGRAM("")
) memory (
  .clock(clock),
  .reset(reset),
  .msg_in(intf2mem_msg),
  .address(intf2mem_address),
  .data_in(intf2mem_data),
  .msg_out(mem2intf_msg),
  .address_out(mem2intf_address),
  .data_out(mem2intf_data)
);



endmodule
