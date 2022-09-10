/** @module : L1_caching_logic
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
 *  - Level 1 cache module.
 *  - Have two interfaces to;
 *    1) Interface with the processor pipeline
 *    2) Interface with the cache_bus_interface/cache_noc_interface.
 *  - Cache memory module stores tags and data while also implementing LRU 
 *    replacement.
 *  - Signals for port 1 of the cache_memory module are exposed so that the
 *    coherence related updates can be performed by the bus/noc interface.
 *
 *  Sub modules
 *  -----------
   *  cache_memory
   *  cache_controller
 *
 *  Parameters
 *  ----------
   *  COHERENCE_PROTOCOL: Select the coherence protocol
   *    - MESI, MSI, CUSTOM (default is MESI)
   *    - CUSTOM: User specified protocol implemented by the user.
   *  REPLACEMENT_MODE: Select replacement policy
   *    - 0: LRU (default)
*/


module L1_caching_logic#(
parameter STATUS_BITS        =  2,
          COHERENCE_BITS     =  2,
          CACHE_OFFSET_BITS  =  2,
          DATA_WIDTH         = 32,
          NUMBER_OF_WAYS     =  4,
          ADDRESS_BITS       = 32,
          INDEX_BITS         =  8,
          MSG_BITS           =  4,
          REPLACEMENT_MODE   =  1'b0,
          COHERENCE_PROTOCOL = "MESI",
          CORE               =  0,
          CACHE_NO           =  0,
          //Use default value in module instantiation for following parameters
          CACHE_WORDS        = 1 << CACHE_OFFSET_BITS,
          CACHE_WIDTH        = DATA_WIDTH * CACHE_WORDS,
          TAG_BITS           = ADDRESS_BITS - INDEX_BITS - CACHE_OFFSET_BITS,
          WAY_BITS           = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1,
          SBITS              = COHERENCE_BITS + STATUS_BITS

)(
// interface with the core
input  clock, reset,
input  read, write, invalidate, flush,
input  [DATA_WIDTH/8-1:0] w_byte_en,
input  [ADDRESS_BITS-1:0] address,
input  [DATA_WIDTH-1  :0] data_in,
input  report,
output [DATA_WIDTH-1  :0] data_out,
output [ADDRESS_BITS-1:0] out_address,
output ready, valid,
/*Add byte enable signal for writes later.*/

// port1 interface for coherence
input  port1_read, port1_write, port1_invalidate,
input  [INDEX_BITS-1    :0] port1_index,
input  [TAG_BITS-1      :0] port1_tag,
input  [SBITS-1         :0] port1_metadata,
input  [CACHE_WIDTH-1   :0] port1_data_in,
input  [WAY_BITS-1      :0] port1_way_select,
output [CACHE_WIDTH-1   :0] port1_data_out,
output [WAY_BITS-1      :0] port1_matched_way,
output [COHERENCE_BITS-1:0] port1_coh_bits,
output [STATUS_BITS-1   :0] port1_status_bits,
output port1_hit,

// interface for cache_controller <-> bus_interface
input  [MSG_BITS-1:    0] mem2cache_msg,
input  [CACHE_WIDTH-1: 0] mem2cache_data,
input  [ADDRESS_BITS-1:0] mem2cache_address,
output [MSG_BITS-1:    0] cache2mem_msg,
output [CACHE_WIDTH-1: 0] cache2mem_data,
output [ADDRESS_BITS-1:0] cache2mem_address,
output i_reset
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


// Internal signals
wire [CACHE_WIDTH-1   :0] ctrl_data_out0, ctrl_data_out1;
wire [CACHE_WIDTH-1   :0] ctrl_data_in0;
wire [INDEX_BITS-1    :0] ctrl_index0, ctrl_index1;
wire [TAG_BITS-1      :0] ctrl_tag_in0, ctrl_tag_out0, ctrl_tag_out1;
wire [COHERENCE_BITS-1:0] ctrl_coh_bits0, ctrl_coh_bits1;
wire [SBITS-1         :0] ctrl_metadata0, ctrl_metadata1;
wire [WAY_BITS-1      :0] ctrl_matched_way0;
wire [WAY_BITS-1      :0] ctrl_way_select0, ctrl_way_select1;
wire [STATUS_BITS-1   :0] ctrl_status_bits0;
wire ctrl_hit0;
wire ctrl_read0, ctrl_write0, ctrl_invalidate0;
wire ctrl_read1, ctrl_write1, ctrl_invalidate1;
wire snoop_action;
wire [CACHE_WIDTH-1   :0] mem_data_in0, mem_data_in1;
wire [CACHE_WIDTH-1   :0] mem_data_out0, mem_data_out1;
wire [INDEX_BITS-1    :0] mem_index0, mem_index1;
wire [TAG_BITS-1      :0] mem_tag_in0, mem_tag_in1, mem_tag_out0, mem_tag_out1;
wire [WAY_BITS-1      :0] mem_matched_way0, mem_matched_way1;
wire [WAY_BITS-1      :0] mem_way_select0, mem_way_select1;
wire [COHERENCE_BITS-1:0] mem_coh_bits0, mem_coh_bits1;
wire [SBITS-1         :0] mem_metadata0, mem_metadata1;
wire [STATUS_BITS-1   :0] mem_status_bits0, mem_status_bits1;
wire mem_hit0, mem_hit1;
wire mem_read0, mem_read1, mem_write0, mem_write1;
wire mem_invalidate0, mem_invalidate1;


// Assignments
assign snoop_action = port1_read | port1_write | port1_invalidate;

assign mem_read0       = ctrl_read0;
assign mem_write0      = ctrl_write0;
assign mem_invalidate0 = ctrl_invalidate0;
assign mem_index0      = ctrl_index0;
assign mem_tag_in0     = ctrl_tag_out0;
assign mem_metadata0   = ctrl_metadata0;
assign mem_data_in0    = ctrl_data_out0;
assign mem_way_select0 = ctrl_way_select0;
assign mem_read1       = snoop_action ? port1_read       : ctrl_read1;
assign mem_write1      = snoop_action ? port1_write      : ctrl_write1;
assign mem_invalidate1 = snoop_action ? port1_invalidate : ctrl_invalidate1;
assign mem_index1      = snoop_action ? port1_index      : ctrl_index1;
assign mem_tag_in1     = snoop_action ? port1_tag        : ctrl_tag_out1;
assign mem_metadata1   = snoop_action ? port1_metadata   : ctrl_metadata1;
assign mem_data_in1    = snoop_action ? port1_data_in    : ctrl_data_out1;
assign mem_way_select1 = snoop_action ? port1_way_select : ctrl_way_select1;

assign port1_data_out    = mem_data_out1;
assign port1_matched_way = mem_matched_way1;
assign port1_coh_bits    = mem_coh_bits1;
assign port1_status_bits = mem_status_bits1;
assign port1_hit         = mem_hit1;

assign ctrl_data_in0     = mem_data_out0;
assign ctrl_tag_in0      = mem_tag_out0;
assign ctrl_matched_way0 = mem_matched_way0;
assign ctrl_coh_bits0    = mem_coh_bits0;
assign ctrl_status_bits0 = mem_status_bits0;
assign ctrl_hit0         = mem_hit0;


// Instantiate cache controller
cache_controller #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .MSG_BITS(MSG_BITS),
  .CORE(0),
  .CACHE_NO(0)
) controller (
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

  .data_in0(ctrl_data_in0),
  .tag_in0(ctrl_tag_in0),
  .matched_way0(ctrl_matched_way0),
  .coh_bits0(ctrl_coh_bits0),
  .status_bits0(ctrl_status_bits0),
  .hit0(ctrl_hit0),
  .read0(ctrl_read0), 
  .write0(ctrl_write0), 
  .invalidate0(ctrl_invalidate0),
  .index0(ctrl_index0),
  .tag0(ctrl_tag_out0),
  .meta_data0(ctrl_metadata0),
  .data_out0(ctrl_data_out0),
  .way_select0(ctrl_way_select0),
  .read1(ctrl_read1), 
  .write1(ctrl_write1), 
  .invalidate1(ctrl_invalidate1),
  .index1(ctrl_index1),
  .tag1(ctrl_tag_out1),
  .meta_data1(ctrl_metadata1),
  .data_out1(ctrl_data_out1),
  .way_select1(ctrl_way_select1),
  .i_reset(i_reset),

  .mem2cache_msg(mem2cache_msg),
  .mem2cache_data(mem2cache_data),
  .mem2cache_address(mem2cache_address),
  .cache2mem_msg(cache2mem_msg),
  .cache2mem_data(cache2mem_data),
  .cache2mem_address(cache2mem_address),

  .snoop_address({port1_tag, port1_index, {CACHE_OFFSET_BITS{1'b0}}}),
  .snoop_read(port1_read),
  .snoop_modify(port1_write | port1_invalidate)
);


// Instantiate cache memory
cache_memory #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .REPLACEMENT_MODE(REPLACEMENT_MODE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .READ_DURING_WRITE("OLD_DATA")
) memory (
  .clock(clock), 
  .reset(i_reset),
  //port 0
  .read0(mem_read0), 
  .write0(mem_write0),
  .invalidate0(mem_invalidate0),
  .index0(mem_index0),
  .tag0(mem_tag_in0),
  .meta_data0(mem_metadata0),
  .data_in0(mem_data_in0),
  .way_select0(mem_way_select0),
  .data_out0(mem_data_out0),
  .tag_out0(mem_tag_out0),
  .matched_way0(mem_matched_way0),
  .coh_bits0(mem_coh_bits0),
  .status_bits0(mem_status_bits0),
  .hit0(mem_hit0),
  //port 1
  .read1(mem_read1),
  .write1(mem_write1),
  .invalidate1(mem_invalidate1),
  .index1(mem_index1),
  .tag1(mem_tag_in1),
  .meta_data1(mem_metadata1),
  .data_in1(mem_data_in1),
  .way_select1(mem_way_select1),
  .data_out1(mem_data_out1),
  .tag_out1(mem_tag_out1),
  .matched_way1(mem_matched_way1),
  .coh_bits1(mem_coh_bits1),
  .status_bits1(mem_status_bits1),
  .hit1(mem_hit1),
  
  .report(report)
);

endmodule
