/** @module : tb_two_level_cache_hierarchy
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
module tb_two_level_cache_hierarchy();

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value>>1;
  end
endfunction

parameter STATUS_BITS_L1      = 2,
          OFFSET_BITS_L1      = {32'd2, 32'd2, 32'd2, 32'd2},
          NUMBER_OF_WAYS_L1   = {32'd2, 32'd2, 32'd2, 32'd2},
          INDEX_BITS_L1       = {32'd6, 32'd6, 32'd6, 32'd6},
          REPLACEMENT_MODE_L1 = 1'b0,
          STATUS_BITS_L2      = 3,
          OFFSET_BITS_L2      = 2,
          NUMBER_OF_WAYS_L2   = 4,
          INDEX_BITS_L2       = 6,
          REPLACEMENT_MODE_L2 = 1'b0,
          L2_INCLUSION        = 1'b1,
          COHERENCE_BITS      = 2,
          DATA_WIDTH          = 32,
          ADDRESS_BITS        = 32,
          MSG_BITS            = 4,
          NUM_L1_CACHES       = 4,
          BUS_OFFSET_BITS     = 2,
          MAX_OFFSET_BITS     = 2,
          //Use default value in module instantiation for following parameters
          L2_WORDS            = 1 << OFFSET_BITS_L2,
          L2_WIDTH            = L2_WORDS*DATA_WIDTH,
          L2_TAG_BITS         = ADDRESS_BITS - OFFSET_BITS_L2 - INDEX_BITS_L2,
          L2_WAY_BITS         = (NUMBER_OF_WAYS_L2 > 1) ? log2(NUMBER_OF_WAYS_L2) : 1,
          L2_MBITS            = COHERENCE_BITS + STATUS_BITS_L2;

localparam BUS_WORDS     = 1 << BUS_OFFSET_BITS;
localparam BUS_WIDTH     = BUS_WORDS*DATA_WIDTH;
localparam BUS_PORTS     = NUM_L1_CACHES + 1;
localparam MEM_PORT      = BUS_PORTS - 1;
localparam BUS_SIG_WIDTH = log2(BUS_PORTS);
localparam WIDTH_BITS    = log2(MAX_OFFSET_BITS) + 1;

// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
`include `INCLUDE_FILE


reg  clock;
reg  reset;
//interface with processor pipelines
reg  [NUM_L1_CACHES-1:0] read, write, flush, invalidate;
reg  [NUM_L1_CACHES*DATA_WIDTH/8-1:0] w_byte_en;
reg  [ADDRESS_BITS-1:0] address_s [NUM_L1_CACHES-1:0];
wire [NUM_L1_CACHES*ADDRESS_BITS-1:0] address;
reg  [DATA_WIDTH-1  :0] data_in_s [NUM_L1_CACHES-1:0];
wire [NUM_L1_CACHES*DATA_WIDTH-1  :0] data_in;
wire [ADDRESS_BITS-1:0] out_address_s [NUM_L1_CACHES-1:0];
wire [NUM_L1_CACHES*ADDRESS_BITS-1:0] out_address;
wire [DATA_WIDTH-1  :0] data_out_s [NUM_L1_CACHES-1:0];
wire [NUM_L1_CACHES*DATA_WIDTH-1  :0] data_out;
wire [NUM_L1_CACHES-1:0] valid, ready;
//interface with memory side interface
reg  [MSG_BITS-1    :0]     mem2cachehier_msg;
reg  [ADDRESS_BITS-1:0] mem2cachehier_address;
reg  [L2_WIDTH-1    :0]    mem2cachehier_data;
reg  mem_intf_busy;
reg  [ADDRESS_BITS-1:0] mem_intf_address;
reg  mem_intf_address_valid;
wire [MSG_BITS-1    :0]     cachehier2mem_msg;
wire [ADDRESS_BITS-1:0] cachehier2mem_address;
wire [L2_WIDTH-1    :0]    cachehier2mem_data;
//interface for memory side interface to access cache memory
reg  port1_read, port1_write, port1_invalidate;
reg  [INDEX_BITS_L2-1 :0] port1_index;
reg  [L2_TAG_BITS-1   :0] port1_tag;
reg  [L2_MBITS-1      :0] port1_metadata;
reg  [L2_WIDTH-1      :0] port1_write_data;
reg  [L2_WAY_BITS-1   :0] port1_way_select;
wire [L2_WIDTH-1      :0] port1_read_data;
wire [L2_WAY_BITS-1   :0] port1_matched_way;
wire [COHERENCE_BITS-1:0] port1_coh_bits;
wire [STATUS_BITS_L2-1:0] port1_status_bits;
wire port1_hit;

reg  scan;

//combine and split signals
genvar j;
generate
  for(j=0; j<NUM_L1_CACHES; j=j+1)begin
    assign address[j*ADDRESS_BITS +: ADDRESS_BITS] = address_s[j];
    assign data_in[j*DATA_WIDTH   +: DATA_WIDTH  ] = data_in_s[j];
  end
  for(j=0; j<NUM_L1_CACHES; j=j+1)begin
    assign data_out_s[j]    = data_out   [j*DATA_WIDTH   +: DATA_WIDTH  ];
    assign out_address_s[j] = out_address[j*ADDRESS_BITS +: ADDRESS_BITS];
  end
endgenerate

//Instantiate DUT
two_level_cache_hierarchy #(
  .STATUS_BITS_L1(STATUS_BITS_L1),
  .OFFSET_BITS_L1(OFFSET_BITS_L1),
  .NUMBER_OF_WAYS_L1(NUMBER_OF_WAYS_L1),
  .INDEX_BITS_L1(INDEX_BITS_L1),
  .REPLACEMENT_MODE_L1(REPLACEMENT_MODE_L1),
  .STATUS_BITS_L2(STATUS_BITS_L2),
  .OFFSET_BITS_L2(OFFSET_BITS_L2),
  .NUMBER_OF_WAYS_L2(NUMBER_OF_WAYS_L2),
  .INDEX_BITS_L2(INDEX_BITS_L2),
  .REPLACEMENT_MODE_L2(REPLACEMENT_MODE_L2),
  .L2_INCLUSION(L2_INCLUSION),
  .COHERENCE_BITS(COHERENCE_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .NUM_L1_CACHES(NUM_L1_CACHES),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) DUT (
  .clock(clock),
  .reset(reset),
  //interface with processor pipelines
  .read(read),
  .write(write),
  .invalidate({4'b0000}),
  .flush(flush),
  .w_byte_en(w_byte_en),
  .address(address),
  .data_in(data_in),
  .out_address(out_address),
  .data_out(data_out),
  .valid(valid),
  .ready(ready),
  //interface with memory side interface
  .mem2cachehier_msg(mem2cachehier_msg),
  .mem2cachehier_address(mem2cachehier_address),
  .mem2cachehier_data(mem2cachehier_data),
  .mem_intf_busy(mem_intf_busy),
  .mem_intf_address(mem_intf_address),
  .mem_intf_address_valid(mem_intf_address_valid),
  .cachehier2mem_msg(cachehier2mem_msg),
  .cachehier2mem_address(cachehier2mem_address),
  .cachehier2mem_data(cachehier2mem_data),
  //interface for memory side interface to access cache memory
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

integer i;

//clock signal
always #1 clock = ~clock;

//cycle counter
reg [31:0] cycles;
always @(posedge clock)begin
  cycles <= cycles + 1;
end


initial begin
  clock     = 1'b0;
  reset     = 1'b0;
  cycles    = 0;
  w_byte_en = {NUM_L1_CACHES*(DATA_WIDTH/8){1'b1}};
  for(i=0; i<NUM_L1_CACHES; i=i+1)begin
    address_s[i]  = 32'd0;
    data_in_s[i]  = 32'd0;
    read[i]       = 1'b0;
    write[i]      = 1'b0;
    flush[i]      = 1'b0;
  end
  mem2cachehier_msg      = NO_REQ;
  mem2cachehier_data     = 128'h0;
  mem2cachehier_address  = 32'd0;
  mem_intf_busy          = 0;
  mem_intf_address       = 32'd0;
  mem_intf_address_valid = 0;

  port1_read       = 1'b0;
  port1_write      = 1'b0;
  port1_invalidate = 1'b0;
  port1_index      = {INDEX_BITS_L2{1'b0}};
  port1_tag        = {L2_TAG_BITS{1'b0}};
  port1_metadata   = {L2_MBITS{1'b0}};
  port1_write_data = 128'h0;
  port1_way_select = {L2_WAY_BITS{1'b0}};

  scan = 1'b0;

  //reset
  repeat(1) @(posedge clock);
  @(posedge clock) reset <= 1;
  repeat(3) @(posedge clock);
  @(posedge clock) reset <= 0;

  //wait for L1 caches to finish reset sequence
  wait(DUT.L1INST[0].L1CACHE.cache.controller.state == 4'd0);
  $display("%0d> L1 caches finished reset sequence", cycles-1);

  //write request to L1cache 0
  @(posedge clock)begin
    write[0]     <= 1'b1;
    address_s[0] <= 32'hffffff0c;
    data_in_s[0] <= 32'h11112222;
  end
  @(posedge clock)begin
    write[0]     <= 1'b0;
    address_s[0] <= 32'h0;
    data_in_s[0] <= 32'h0;
  end

  wait(cachehier2mem_msg == RFO_BCAST & cachehier2mem_address == 32'h3fffffc0);

  //L1cache 3 issuing a read request to the same address
  @(posedge clock)begin
    read[3]      <= 1'b1;
    address_s[3] <= 32'hffffff0c;
  end
  @(posedge clock)begin
    read[3]      <= 1'b0;
    address_s[3] <= 32'h0;
  end

  //memory respondong to the cache hierarchy
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    mem2cachehier_msg     <= MEM_RESP;
    mem2cachehier_address <= 32'h3fffffc0;
    mem2cachehier_data    <= 128'h00040004_00030003_00020002_00010001;
  end
  @(posedge clock)begin
    mem2cachehier_msg     <= NO_REQ;
    mem2cachehier_address <= 32'h0;
    mem2cachehier_data    <= 128'h0;
  end

  //cache 0 completes the write request
  wait(ready[0]);

  //cache 3 returns requested data.
  wait(valid[3] & data_out_s[3] == 32'h11112222);

  //Flush request from memory side
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2cachehier_msg     <= REQ_FLUSH;
    mem2cachehier_address <= 32'h3fffffc0;
  end
  @(posedge clock)begin
    mem2cachehier_msg     <= NO_REQ;
    mem2cachehier_address <=32'h0;
  end

  //requested line is written back by the cache hierarchy
  wait(cachehier2mem_msg == C_FLUSH & cachehier2mem_address == 32'h3fffffc0 &
  cachehier2mem_data == 128'h11112222_00030003_00020002_00010001);

  //Test passed
  #20;
  $display("\ntb_two_level_cache_hierarchy --> Test Passed!\n\n");
  $stop;
end

//timeout
initial begin
  #500;
  $display("Error! Timeout.");
  $display("\ntb_two_level_cache_hierarchy --> Test Failed!\n\n");
  $stop;
end

endmodule
