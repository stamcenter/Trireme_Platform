/** @module : L1cache_bus_wrapper
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
 *  - Wrapper module for L1 cache.
 *  - Uses the bus interface on the memory side.
 *
 *  Sub modules
 *  -----------
   *  L1_caching_logic
   *  cache_bus_interface
*/

module L1cache_bus_wrapper #(
parameter STATUS_BITS        =  2,
          COHERENCE_BITS     =  2,
          CACHE_OFFSET_BITS  =  2,
          DATA_WIDTH         = 32,
          NUMBER_OF_WAYS     =  4,
          ADDRESS_BITS       = 32,
          INDEX_BITS         =  8,
          MSG_BITS           =  4,
		      BUS_OFFSET_BITS    =  0,
		      MAX_OFFSET_BITS    =  3,
          REPLACEMENT_MODE   =  1'b0,
          COHERENCE_PROTOCOL = "MESI",
          CORE               =  0,
          CACHE_NO           =  0,
          //Use default value in module instantiation for following parameters
          CACHE_WORDS        = 1 << CACHE_OFFSET_BITS,
          BUS_WORDS          = 1 << BUS_OFFSET_BITS,
          CACHE_WIDTH        = CACHE_WORDS * DATA_WIDTH,
          BUS_WIDTH          = BUS_WORDS   * DATA_WIDTH,
          TAG_BITS           = ADDRESS_BITS - INDEX_BITS - CACHE_OFFSET_BITS,
          WAY_BITS           = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1,
          SBITS              = COHERENCE_BITS + STATUS_BITS
)(
input  clock,
input  reset,
//processor interface
input  read, write, invalidate, flush,
input  [DATA_WIDTH/8-1:0] w_byte_en,
input  [ADDRESS_BITS-1:0] address,
input  [DATA_WIDTH-1  :0] data_in,
input  report,
output [DATA_WIDTH-1  :0] data_out,
output [ADDRESS_BITS-1:0] out_address,
output ready, valid,
//bus interface
input  [MSG_BITS-1    :0] bus_msg_in,
input  [ADDRESS_BITS-1:0] bus_address_in,
input  [BUS_WIDTH-1   :0] bus_data_in,
input  bus_master,
input  req_ready,
input  [log2(MAX_OFFSET_BITS):0] curr_offset,
output [MSG_BITS-1    :0] bus_msg_out,
output [ADDRESS_BITS-1:0] bus_address_out,
output [BUS_WIDTH-1   :0] bus_data_out,
output [log2(MAX_OFFSET_BITS):0] active_offset
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

`include `INCLUDE_FILE


//internal wires
wire i_reset;
wire snoop_action;

wire [MSG_BITS-1    :0] cache2intf_msg, intf2cache_msg;
wire [ADDRESS_BITS-1:0] cache2intf_addr, intf2cache_addr;
wire [CACHE_WIDTH-1 :0] cache2intf_data, intf2cache_data;
wire [MSG_BITS-1    :0] snooper2intf_msg, intf2snooper_msg;
wire [ADDRESS_BITS-1:0] snooper2intf_addr, intf2snooper_addr;
wire [CACHE_WIDTH-1 :0] snooper2intf_data, intf2snooper_data;

wire [CACHE_WIDTH-1   :0] port1_read_data;
wire [WAY_BITS-1      :0] port1_matched_way;
wire [COHERENCE_BITS-1:0] port1_coh_bits;
wire [STATUS_BITS-1   :0] port1_status_bits;
wire port1_hit;
wire port1_read, port1_write, port1_invalidate;
wire [INDEX_BITS-1    :0] port1_index;
wire [TAG_BITS-1      :0] port1_tag;
wire [SBITS-1         :0] port1_metadata;
wire [CACHE_WIDTH-1   :0] port1_write_data;
wire [WAY_BITS-1      :0] port1_way_select;


//assignments



//Instantiate L1_caching_logic
L1_caching_logic #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .MSG_BITS(MSG_BITS),
  .REPLACEMENT_MODE(REPLACEMENT_MODE),
  .COHERENCE_PROTOCOL(COHERENCE_PROTOCOL),
  .CORE(CORE),
  .CACHE_NO(CACHE_NO)
) cache (
// interface with the core
  .clock(clock), 
  .reset(reset),
  .read(read), 
  .write(write), 
  .invalidate(invalidate), 
  .flush(flush),
  .w_byte_en(w_byte_en),
  .address(address),
  .data_in(data_in),
  .report(report),
  .data_out(data_out),
  .out_address(out_address),
  .ready(ready), 
  .valid(valid),
// port1 interface for coherence
  .port1_read(port1_read), 
  .port1_write(port1_write), 
  .port1_invalidate(port1_invalidate),
  .port1_index(port1_index),
  .port1_tag(port1_tag),
  .port1_metadata(port1_metadata),
  .port1_data_in(port1_write_data),
  .port1_way_select(port1_way_select),
  .port1_data_out(port1_read_data),
  .port1_matched_way(port1_matched_way),
  .port1_coh_bits(port1_coh_bits),
  .port1_status_bits(port1_status_bits),
  .port1_hit(port1_hit),
// interface for cache_controller <-> bus_interface
  .mem2cache_msg(intf2cache_msg),
  .mem2cache_data(intf2cache_data),
  .mem2cache_address(intf2cache_addr),
  .cache2mem_msg(cache2intf_msg),
  .cache2mem_data(cache2intf_data),
  .cache2mem_address(cache2intf_addr),
  .i_reset(i_reset)
);


//Instantiate cache_bus_interface
cache_bus_interface #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .MSG_BITS(MSG_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS),
  .COHERENCE_PROTOCOL(COHERENCE_PROTOCOL),
  .CORE(CORE),
  .CACHE_NO(CACHE_NO)
) bus_interface (
  .clock(clock),
  .reset(reset),
//interface with the shared bus
  .bus_msg_in(bus_msg_in),
  .bus_address_in(bus_address_in),
  .bus_data_in(bus_data_in),
  .bus_master(bus_master),
  .curr_offset(curr_offset),
  .req_ready(req_ready),
  .bus_msg_out(bus_msg_out),
  .bus_address_out(bus_address_out),
  .bus_data_out(bus_data_out),
  .active_offset(active_offset),
//interface with cache controller
  .cache_msg_in(cache2intf_msg),
  .cache_address_in(cache2intf_addr),
  .cache_data_in(cache2intf_data),
  .i_reset(i_reset),
  .cache_msg_out(intf2cache_msg),
  .cache_address_out(intf2cache_addr),
  .cache_data_out(intf2cache_data),
//interface with cache memory
  .port1_read_data(port1_read_data),
  .port1_matched_way(port1_matched_way),
  .port1_coh_bits(port1_coh_bits),
  .port1_status_bits(port1_status_bits),
  .port1_hit(port1_hit),
  .port1_read(port1_read), 
  .port1_write(port1_write),
  .port1_invalidate(port1_invalidate),
  .port1_index(port1_index),
  .port1_tag(port1_tag),
  .port1_metadata(port1_metadata),
  .port1_write_data(port1_write_data),
  .port1_way_select(port1_way_select)
);

endmodule

