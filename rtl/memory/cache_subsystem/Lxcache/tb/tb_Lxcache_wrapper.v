/** @module : tb_Lxcache_wrapper
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

module tb_Lxcache_wrapper();

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value >> 1;
  end
endfunction

parameter STATUS_BITS         = 3;
parameter INCLUSION           = 1;
parameter COHERENCE_BITS      = 2;
parameter CACHE_OFFSET_BITS   = 2;
parameter BUS_OFFSET_BITS     = 2;
parameter MAX_OFFSET_BITS     = 3;
parameter DATA_WIDTH          = 32;
parameter NUMBER_OF_WAYS      = 4;
parameter ADDRESS_BITS        = 32;
parameter INDEX_BITS          = 8;
parameter REPLACEMENT_MODE    = 1'b0;
parameter MSG_BITS            = 4;
parameter LAST_LEVEL          = 1;
parameter MEM_SIDE            = "SNOOP";
parameter CACHE_WORDS         = 1 << CACHE_OFFSET_BITS;
parameter CACHE_WIDTH         = DATA_WIDTH * CACHE_WORDS;
parameter WAY_BITS            = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
parameter TAG_BITS            = ADDRESS_BITS - INDEX_BITS - CACHE_OFFSET_BITS;
parameter SBITS               = COHERENCE_BITS + STATUS_BITS;
parameter BUS_WORDS           = 1 << BUS_OFFSET_BITS;
parameter BUS_WIDTH           = DATA_WIDTH*BUS_WORDS;


`include `INCLUDE_FILE

reg  clock;
reg  reset;
//signals to/from the shared bus on processor side
reg  [MSG_BITS-1    :0]     bus_msg_in;
reg  [ADDRESS_BITS-1:0] bus_address_in;
reg  [BUS_WIDTH-1   :0]    bus_data_in;
reg  req_ready;
reg  [log2(MAX_OFFSET_BITS):0] req_offset;
wire [MSG_BITS-1           :0]     bus_msg_out;
wire [ADDRESS_BITS-1       :0] bus_address_out;
wire [BUS_WIDTH-1          :0]    bus_data_out;
wire [log2(MAX_OFFSET_BITS):0] active_offset;
//signals to/from memory side interface
reg  [MSG_BITS-1    :0] mem2cache_msg;
reg  [ADDRESS_BITS-1:0] mem2cache_address;
reg  [CACHE_WIDTH-1 :0] mem2cache_data;
reg  mem_intf_busy;
reg  [ADDRESS_BITS-1:0] mem_intf_address;
reg  mem_intf_address_valid;
wire [MSG_BITS-1    :0] cache2mem_msg;
wire [ADDRESS_BITS-1:0] cache2mem_address;
wire [CACHE_WIDTH-1 :0] cache2mem_data;
reg  port1_read, port1_write, port1_invalidate;
reg  [INDEX_BITS-1 :0] port1_index;
reg  [TAG_BITS-1   :0] port1_tag;
reg  [SBITS-1      :0] port1_metadata;
reg  [CACHE_WIDTH-1:0] port1_write_data;
reg  [WAY_BITS-1   :0] port1_way_select;
wire [CACHE_WIDTH-1   :0] port1_read_data;
wire [WAY_BITS-1      :0] port1_matched_way;
wire [COHERENCE_BITS-1:0] port1_coh_bits;
wire [STATUS_BITS-1   :0] port1_status_bits;
wire port1_hit;
reg  scan;


//instantiate DUT
Lxcache_wrapper #(
  .STATUS_BITS(STATUS_BITS),
  .INCLUSION(INCLUSION),
  .COHERENCE_BITS(COHERENCE_BITS),
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .REPLACEMENT_MODE(REPLACEMENT_MODE),
  .MSG_BITS(MSG_BITS),
  .LAST_LEVEL(LAST_LEVEL),
  .MEM_SIDE(MEM_SIDE)
) DUT (
  .clock(clock),
  .reset(reset),
  .bus_msg_in(bus_msg_in),
  .bus_address_in(bus_address_in),
  .bus_data_in(bus_data_in),
  .req_ready(req_ready),
  .req_offset(req_offset),
  .bus_msg_out(bus_msg_out),
  .bus_address_out(bus_address_out),
  .bus_data_out(bus_data_out),
  .active_offset(active_offset),
  .mem2cache_msg(mem2cache_msg),
  .mem2cache_address(mem2cache_address),
  .mem2cache_data(mem2cache_data),
  .mem_intf_busy(mem_intf_busy),
  .mem_intf_address(mem_intf_address),
  .mem_intf_address_valid(mem_intf_address_valid),
  .cache2mem_msg(cache2mem_msg),
  .cache2mem_address(cache2mem_address),
  .cache2mem_data(cache2mem_data),
  .port1_read(port1_read),
  .port1_write(port1_write),
  .port1_invalidate(port1_invalidate),
  .port1_index(port1_index),
  .port1_tag(port1_tag),
  .port1_metadata(port1_metadata),
  .port1_write_data(port1_write_data),
  .port1_way_select(port1_way_select),
  .port1_read_data(port1_read_data),
  .port1_matched_way(port1_matched_way),
  .port1_coh_bits(port1_coh_bits),
  .port1_status_bits(port1_status_bits),
  .port1_hit(port1_hit),
  .scan(scan)
);



//generate clock
always #1 clock = ~clock;

//cycle counter
reg [31:0] cycles;
always @(posedge clock)begin
  cycles <= cycles + 1;
end

// Test patterns
initial begin
  clock                  = 0;
  reset                  = 0;
  cycles                 = 0;
  scan                   = 0;

  bus_msg_in             = NO_REQ;
  bus_address_in         = 0;
  bus_data_in            = 128'd0;
  req_ready              = 0;
  req_offset             = 0;

  mem2cache_msg          = 0;
  mem2cache_address      = 0;
  mem2cache_data         = 128'd0;

  mem_intf_busy          = 0;
  mem_intf_address       = 0;
  mem_intf_address_valid = 0;

  port1_read             = 0;
  port1_write            = 0;
  port1_invalidate       = 0;
  port1_index            = {INDEX_BITS{1'b0}};
  port1_tag              = {TAG_BITS{1'b0}};
  port1_metadata         = {SBITS{1'b0}};
  port1_write_data       = 128'd0;
  port1_way_select       = {WAY_BITS{1'b0}};


  repeat(1) @(posedge clock);
  @(posedge clock) begin
    reset <= 1;
    $display("%0d> Assert reset.", cycles);
  end
  repeat(1) @(posedge clock);
  @(posedge clock) begin
    reset <= 0;
    $display("%0d> Deassert reset.", cycles);
  end
  wait(DUT.controller.state == 0);
  $display("%0d> DUT in IDLE state", cycles-1);

  @(posedge clock)begin
    bus_msg_in     <= R_REQ;
    bus_address_in <= 32'h11110004;
    req_offset     <= 2;
  end
  @(bus_msg_in) $display("%0d> Read request on the bus. Address:%h | width:%0d"
  , cycles-1, bus_address_in, 1<<req_offset);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    req_ready <= 1;
    $display("%0d> req_ready signal goes high.", cycles);
  end

  wait(cache2mem_msg == R_REQ);
  $display("%0d> Read request 1 sent to the memory side interface. Address:%h" ,cycles-1,
    cache2mem_address);

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg     <= MEM_RESP;
    mem2cache_address <= cache2mem_address;
    mem2cache_data    <= 128'h44444444_33333333_22222222_11111111;
  end
  @(mem2cache_msg) $display("%0d> Cache receives data from memory side interface. Data:%h", cycles-1,
    mem2cache_data);
  @(posedge clock)begin
    mem2cache_msg     <= NO_REQ;
    mem2cache_address <= 0;
    mem2cache_data    <= 0;
  end

  wait(bus_msg_out == MEM_RESP);
  $display("%0d> DUT puts MEM_RESP message on the bus" ,cycles-1);
  @(posedge clock)begin
	bus_msg_in     <= NO_REQ;
	bus_address_in <= 0;
	req_offset     <= 0;
	req_ready      <= 0;
  end


  #20;
  $display("\ntb_Lxcache_wrapper --> Test Passed!\n\n");
  $stop;
end

//timeout
initial begin
  #15000;
  $display("\ntb_Lxcache_wrapper --> Test Failed!\n\n");
  $stop;
end

endmodule
