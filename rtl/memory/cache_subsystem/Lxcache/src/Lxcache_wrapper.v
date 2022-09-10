/** @module : Lxcache_wrapper
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

/** Module description
* --------------------
  *  - Wrapper module for Lx cache.
  *  - This wrapper is to be used when the Lx cache is connected directly to
  *    the main memory without a bus or NoC interface.
  *
  *  sub modules
  *  -----------
    *  Lxcache_controller
    *  lx_bus_interface (processor side)
    *  cache_memory
*/


module Lxcache_wrapper #(
parameter STATUS_BITS         = 3, // Valid bit + Dirty bit + include
          /*include bit is always zero if not tracking inclusion*/
          INCLUSION           = 1, //track inclusion
          COHERENCE_BITS      = 2,
          CACHE_OFFSET_BITS   = 2, //determines width of cache lines
          BUS_OFFSET_BITS     = 1, //determines width of the bus
          MAX_OFFSET_BITS     = 3, //correspond to widest cache lines in the 
                                   //coherence domain over the shared bus
          DATA_WIDTH          = 32,
          NUMBER_OF_WAYS      = 4,
          ADDRESS_BITS        = 32,
          INDEX_BITS          = 10,
          REPLACEMENT_MODE    = 1'b0,
          MSG_BITS            = 4,
          LAST_LEVEL          = 1,
          MEM_SIDE            = "SNOOP",
          //Use default value in module instantiation for following parameters
          CACHE_WORDS         = 1 << CACHE_OFFSET_BITS,
          CACHE_WIDTH         = DATA_WIDTH * CACHE_WORDS,
          WAY_BITS            = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1,
          TAG_BITS            = ADDRESS_BITS - INDEX_BITS - CACHE_OFFSET_BITS,
          SBITS               = COHERENCE_BITS + STATUS_BITS,
          BUS_WORDS           = 1 << BUS_OFFSET_BITS,
          BUS_WIDTH           = DATA_WIDTH*BUS_WORDS
)(
input clock,
input reset,
//signals to/from the shared bus on processor side
input  [MSG_BITS-1    :0]     bus_msg_in,
input  [ADDRESS_BITS-1:0] bus_address_in,
input  [BUS_WIDTH-1   :0]    bus_data_in,
input  req_ready,
input  [log2(MAX_OFFSET_BITS):0] req_offset,
output [MSG_BITS-1           :0]     bus_msg_out,
output [ADDRESS_BITS-1       :0] bus_address_out,
output [BUS_WIDTH-1          :0]    bus_data_out,
output [log2(MAX_OFFSET_BITS):0] active_offset,
//signals to/from memory side interface
input  [MSG_BITS-1    :0] mem2cache_msg,
input  [ADDRESS_BITS-1:0] mem2cache_address,
input  [CACHE_WIDTH-1 :0] mem2cache_data,
input  mem_intf_busy,
input  [ADDRESS_BITS-1:0] mem_intf_address,
input  mem_intf_address_valid,
output [MSG_BITS-1    :0] cache2mem_msg,
output [ADDRESS_BITS-1:0] cache2mem_address,
output [CACHE_WIDTH-1 :0] cache2mem_data,
input  port1_read, port1_write, port1_invalidate,
input  [INDEX_BITS-1 :0] port1_index,
input  [TAG_BITS-1   :0] port1_tag,
input  [SBITS-1      :0] port1_metadata,
input  [CACHE_WIDTH-1:0] port1_write_data,
input  [WAY_BITS-1   :0] port1_way_select,
output [CACHE_WIDTH-1   :0] port1_read_data,
output [WAY_BITS-1      :0] port1_matched_way,
output [COHERENCE_BITS-1:0] port1_coh_bits,
output [STATUS_BITS-1   :0] port1_status_bits,
output port1_hit,

input scan
);

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value >> 1;
  end
endfunction


//internal signals
//signals between bus interface and cache controller
wire [ADDRESS_BITS-1:0] bus2ctrl_address;
wire [CACHE_WIDTH-1 :0] bus2ctrl_data;
wire [MSG_BITS-1    :0] bus2ctrl_msg;
wire bus2ctrl_pending_req;
wire [CACHE_WIDTH-1 :0] ctrl2bus_data;
wire [ADDRESS_BITS-1:0] ctrl2bus_address;
wire [MSG_BITS-1    :0] ctrl2bus_msg;
//signals to/from cache memory
wire read0;
wire write0;
wire invalidate0;
wire [INDEX_BITS-1    :0] index0;
wire [TAG_BITS-1      :0] tag0;
wire [SBITS-1         :0] meta_data0;
wire [CACHE_WIDTH-1   :0] data_in0;
wire [WAY_BITS-1      :0] way_select0;
wire i_reset;
wire [CACHE_WIDTH-1   :0] data_out0;
wire [TAG_BITS-1      :0] tag_out0;
wire [WAY_BITS-1      :0] matched_way0;
wire [COHERENCE_BITS-1:0] coh_bits0;
wire [STATUS_BITS-1   :0] status_bits0;
wire hit0;


//Instantiate submodules
//Cache controller
Lxcache_controller #(
  .STATUS_BITS(STATUS_BITS),
  .INCLUSION(INCLUSION),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .MSG_BITS(MSG_BITS),
  .LAST_LEVEL(LAST_LEVEL),
  .MEM_SIDE(MEM_SIDE)
) controller (
  .clock(clock),
  .reset(reset),
//signals to/from bus interface
  .address(bus2ctrl_address),
  .data_in(bus2ctrl_data),
  .msg_in(bus2ctrl_msg),
  .pending_requests(bus2ctrl_pending_req),
  .data_out(ctrl2bus_data),
  .out_address(ctrl2bus_address),
  .msg_out(ctrl2bus_msg),
//signals to/from memory side interface
  .mem2cache_msg(mem2cache_msg),
  .mem2cache_address(mem2cache_address),
  .mem2cache_data(mem2cache_data),
  .mem_intf_busy(mem_intf_busy),
  .mem_intf_address(mem_intf_address),
  .mem_intf_address_valid(mem_intf_address_valid),
  .cache2mem_msg(cache2mem_msg),
  .cache2mem_address(cache2mem_address),
  .cache2mem_data(cache2mem_data),
//signals to/from cache_memory
  .read0(read0),
  .write0(write0),
  .invalidate0(invalidate0),
  .index0(index0),
  .tag0(tag0),
  .meta_data0(meta_data0),
  .data0(data_in0),
  .way_select0(way_select0),
  .i_reset(i_reset),
  .data_in0(data_out0),
  .tag_in0(tag_out0),
  .matched_way0(matched_way0),
  .coh_bits0(coh_bits0),
  .status_bits0(status_bits0),
  .hit0(hit0),
//scan
  .scan(scan)
);

//Bus interface
lx_bus_interface #(
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) bus_intf (
  .clock(clock),
  .reset(reset),
  
  .bus_msg_in(bus_msg_in),
  .bus_address_in(bus_address_in),
  .bus_data_in(bus_data_in),
  .bus_msg_out(bus_msg_out),
  .bus_address_out(bus_address_out),
  .bus_data_out(bus_data_out),
  .req_offset(req_offset),
  .req_ready(req_ready),
  .active_offset(active_offset),
  
  .cache_msg_in(ctrl2bus_msg),
  .cache_address_in(ctrl2bus_address),
  .cache_data_in(ctrl2bus_data),
  .cache_msg_out(bus2ctrl_msg),
  .cache_address_out(bus2ctrl_address),
  .cache_data_out(bus2ctrl_data),
  .pending_requests(bus2ctrl_pending_req)
);

//Cache memory
cache_memory #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .REPLACEMENT_MODE(REPLACEMENT_MODE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS)
) memory (
  .clock(clock),
  .reset(i_reset),
//port 0
  .read0(read0),
  .write0(write0),
  .invalidate0(invalidate0),
  .index0(index0),
  .tag0(tag0),
  .meta_data0(meta_data0),
  .data_in0(data_in0),
  .way_select0(way_select0),
  .data_out0(data_out0),
  .tag_out0(tag_out0),
  .matched_way0(matched_way0),
  .coh_bits0(coh_bits0),
  .status_bits0(status_bits0),
  .hit0(hit0),
//port 1
  .read1(port1_read),
  .write1(port1_write),
  .invalidate1(port1_invalidate),
  .index1(port1_index),
  .tag1(port1_tag),
  .meta_data1(port1_metadata),
  .data_in1(port1_write_data),
  .way_select1(port1_way_select),
  .data_out1(port1_read_data),
  .tag_out1(),
  .matched_way1(port1_matched_way),
  .coh_bits1(port1_coh_bits),
  .status_bits1(port1_status_bits),
  .hit1(port1_hit),

  .report(scan)
);


endmodule
