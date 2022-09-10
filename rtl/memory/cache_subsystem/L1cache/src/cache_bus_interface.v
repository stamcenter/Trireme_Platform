/** @module : cache_bus_interface
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
 *  - Bus interface which connects caches to a shared bus.
 *  - Have two interfaces to;
 *    1) Interface with the cache
 *    2) Interface with the shared bus
 *
 *  Sub modules
 *  -----------
   *  snooper - handles cache coherence
   *  bus_interface - handles communication with the bus
 *
 *  Parameters
 *  ----------
   *  COHERENCE_PROTOCOL: Select the coherence protocol
   *    - MESI, MSI, CUSTOM (default is MESI)
   *    - CUSTOM: User specified protocol implemented by the user.
*/


module cache_bus_interface #(
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
          COHERENCE_PROTOCOL = "MESI",
          CORE               =  0,
          CACHE_NO           =  0,
          //Use default value in module instantiation for following parameters
          CACHE_WORDS        = 1 << CACHE_OFFSET_BITS,
          CACHE_WIDTH        = DATA_WIDTH * CACHE_WORDS,
          BUS_WORDS          = 1 << BUS_OFFSET_BITS,
          BUS_WIDTH          = BUS_WORDS * DATA_WIDTH,
          WAY_BITS           = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1,
          TAG_BITS           = ADDRESS_BITS - INDEX_BITS - CACHE_OFFSET_BITS,
          SBITS              = COHERENCE_BITS + STATUS_BITS
)(
input  clock, reset,
//interface with the shared bus
input  [MSG_BITS-1           :0] bus_msg_in,
input  [ADDRESS_BITS-1       :0] bus_address_in,
input  [BUS_WIDTH-1          :0] bus_data_in,
input  [log2(MAX_OFFSET_BITS):0] curr_offset,
input  bus_master,
input  req_ready,
output [MSG_BITS-1           :0] bus_msg_out,
output [ADDRESS_BITS-1       :0] bus_address_out,
output [BUS_WIDTH-1          :0] bus_data_out,
output [log2(MAX_OFFSET_BITS):0] active_offset,

//interface with cache controller
input  [MSG_BITS-1           :0] cache_msg_in,
input  [ADDRESS_BITS-1       :0] cache_address_in,
input  [CACHE_WIDTH-1        :0] cache_data_in,
input  i_reset,
output [MSG_BITS-1           :0] cache_msg_out,
output [ADDRESS_BITS-1       :0] cache_address_out,
output [CACHE_WIDTH-1        :0] cache_data_out,

//interface with cache memory
input  [CACHE_WIDTH-1   :0] port1_read_data,
input  [WAY_BITS-1      :0] port1_matched_way,
input  [COHERENCE_BITS-1:0] port1_coh_bits,
input  [STATUS_BITS-1   :0] port1_status_bits,
input  port1_hit,
output port1_read, port1_write, port1_invalidate,
output [INDEX_BITS-1    :0] port1_index,
output [TAG_BITS-1      :0] port1_tag,
output [SBITS-1         :0] port1_metadata,
output [CACHE_WIDTH-1   :0] port1_write_data,
output [WAY_BITS-1      :0] port1_way_select
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

//Internal signals
wire [MSG_BITS-1    :0] snooper2intf_msg, intf2snooper_msg;
wire [ADDRESS_BITS-1:0] snooper2intf_addr, intf2snooper_addr;
wire [CACHE_WIDTH-1 :0] snooper2intf_data, intf2snooper_data;
wire [log2(CACHE_OFFSET_BITS):0] cache_offset_bits_wire;

// Assign parameter to wire of appropriate width
assign cache_offset_bits_wire = CACHE_OFFSET_BITS[log2(CACHE_OFFSET_BITS):0];


//Instantiate snooper
snooper #(
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .INDEX_BITS(INDEX_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .STATUS_BITS(STATUS_BITS),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) snooper (
  .clock(clock),
  .reset(i_reset),
  .data_in(port1_read_data),
  .matched_way(port1_matched_way),
  .coh_bits(port1_coh_bits),
  .status_bits(port1_status_bits),
  .hit(port1_hit),
  .read(port1_read), 
  .write(port1_write),
  .invalidate(port1_invalidate),
  .index(port1_index),
  .tag(port1_tag),
  .meta_data(port1_metadata),
  .data_out(port1_write_data),
  .way_select(port1_way_select),
  
  .intf_msg(intf2snooper_msg),
  .intf_address(intf2snooper_addr),
  .intf_data(intf2snooper_data),
  .snoop_msg(snooper2intf_msg),
  .snoop_address(snooper2intf_addr),
  .snoop_data(snooper2intf_data),
  
  .bus_msg(bus_msg_in),
  .bus_address(bus_address_in),
  .req_ready(req_ready),
  .bus_master(bus_master),
  .curr_offset(curr_offset)
);


//Instantiate bus_interface
L1_bus_interface #(
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) bus_interface (
  .clock(clock), 
  .reset(i_reset),
  .cache_offset(cache_offset_bits_wire),
  
  .cache_msg_in(cache_msg_in),
  .cache_address_in(cache_address_in),
  .cache_data_in(cache_data_in),
  .cache_msg_out(cache_msg_out),
  .cache_address_out(cache_address_out),
  .cache_data_out(cache_data_out),
  
  .snoop_msg_in(snooper2intf_msg),
  .snoop_address_in(snooper2intf_addr),
  .snoop_data_in(snooper2intf_data),
  .snoop_msg_out(intf2snooper_msg),
  .snoop_address_out(intf2snooper_addr),
  .snoop_data_out(intf2snooper_data),
  
  .bus_msg_in(bus_msg_in),
  .bus_address_in(bus_address_in),
  .bus_data_in(bus_data_in),
  .bus_msg_out(bus_msg_out),
  .bus_address_out(bus_address_out),
  .bus_data_out(bus_data_out),
  .active_offset(active_offset),
 
  .bus_master(bus_master),
  .req_ready(req_ready)
);


endmodule
