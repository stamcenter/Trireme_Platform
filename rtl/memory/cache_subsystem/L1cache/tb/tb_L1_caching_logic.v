/** @module : tb_L1_caching_logic
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

module tb_L1_caching_logic();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter STATUS_BITS        =  2,
          COHERENCE_BITS     =  2,
          CACHE_OFFSET_BITS  =  2,
          DATA_WIDTH         = 32,
          NUMBER_OF_WAYS     =  4,
          ADDRESS_BITS       = 32,
          INDEX_BITS         =  6,
          MSG_BITS           =  4,
          REPLACEMENT_MODE   =  1'b0,
          COHERENCE_PROTOCOL = "MESI",
          CORE               =  0,
          CACHE_NO           =  0;


localparam CACHE_WORDS = 1 << CACHE_OFFSET_BITS; //number of words in one line.
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam SBITS       = COHERENCE_BITS + STATUS_BITS;
localparam TAG_BITS    = ADDRESS_BITS - CACHE_OFFSET_BITS - INDEX_BITS;
localparam WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;

`include `INCLUDE_FILE


reg  clock, reset;
reg  read, write, atomic, flush;
reg  cflush;
reg  c_wb;
reg  [DATA_WIDTH/8-1:0] w_byte_en;
reg  [ADDRESS_BITS-1:0] address;
reg  [DATA_WIDTH-1:  0] data_in;
reg  report;
wire [DATA_WIDTH-1:  0] data_out;
wire [ADDRESS_BITS-1:0] out_address;
wire ready;
wire valid;

//Port1 interface for memory side
reg  port1_read, port1_write, port1_invalidate;
reg  [INDEX_BITS-1    :0] port1_index;
reg  [TAG_BITS-1      :0] port1_tag;
reg  [SBITS-1         :0] port1_metadata;
reg  [CACHE_WIDTH-1   :0] port1_data_in;
reg  [WAY_BITS-1      :0] port1_way_select;
wire [CACHE_WIDTH-1   :0] port1_data_out;
wire [WAY_BITS-1      :0] port1_matched_way;
wire [COHERENCE_BITS-1:0] port1_coh_bits;
wire [STATUS_BITS-1   :0] port1_status_bits;
wire port1_hit;

//interface with bus interface
reg  [MSG_BITS-1:    0] mem2cache_msg;
reg  [CACHE_WIDTH-1: 0] mem2cache_data;
reg  [ADDRESS_BITS-1:0] mem2cache_address;
wire [MSG_BITS-1:    0] cache2mem_msg;
wire [CACHE_WIDTH-1: 0] cache2mem_data;
wire [ADDRESS_BITS-1:0] cache2mem_address;


//instantiate DUT
L1_caching_logic#(
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
) DUT (
  // interface with the core
  .clock(clock),
  .reset(reset),
  .read(read),
  .write(write),
  .invalidate(1'b0),
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
  .port1_data_in(port1_data_in),
  .port1_way_select(port1_way_select),
  .port1_data_out(port1_data_out),
  .port1_matched_way(port1_matched_way),
  .port1_coh_bits(port1_coh_bits),
  .port1_status_bits(port1_status_bits),
  .port1_hit(port1_hit),
// interface for cache_controller <-> bus_interface
  .mem2cache_msg(mem2cache_msg),
  .mem2cache_data(mem2cache_data),
  .mem2cache_address(mem2cache_address),
  .cache2mem_msg(cache2mem_msg),
  .cache2mem_data(cache2mem_data),
  .cache2mem_address(cache2mem_address),
  .i_reset(i_reset)
);


// cycle counter
reg [31:0] cycles;
always @(posedge clock)begin
  cycles <= cycles + 32'd1;
end

//clock generator
always
  #1 clock = ~clock;


// test vectors
initial begin
  cycles            = 0;
  clock             = 0;
  reset             = 0;
  read              = 0;
  write             = 0;
  atomic            = 0;
  flush             = 0;
  cflush            = 0;
  c_wb              = 0;
  w_byte_en         = 4'b1111;
  address           = 0;
  data_in           = 0;
  report            = 0;
  mem2cache_msg     = 0;
  mem2cache_data    = 0;
  mem2cache_address = 0;

  port1_read       = 0;
  port1_write      = 0;
  port1_invalidate = 0;
  port1_index      = 0;
  port1_tag        = 0;
  port1_metadata   = 0;
  port1_data_in    = 0;
  port1_way_select = 0;


  repeat(1) @(posedge clock);
  @(posedge clock) reset <= 1;
  $display("%d> Assert reset signal.", cycles);
  repeat(10) @(posedge clock);
  @(posedge clock) reset <= 0;
  $display("%d> Deassert reset signal.", cycles);

  wait(DUT.controller.state == 0);
  $display("%d> Reset sequence completed." ,cycles);

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    read <= 1;
    address <= 32'hEEEEEE04;
  end
  @(address) $display("%d> Read request. Address:%h", cycles-1, address);
  @(posedge clock)begin
    read    <= 0;
    address <= 0;
  end

  wait(cache2mem_msg == R_REQ);
  repeat(4) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg     <= MEM_RESP;
    mem2cache_address <= cache2mem_address;
    mem2cache_data    <= 128'h99991111_88882222_77773333_66664444;
  end
  @(mem2cache_data) $display("%d> L2 cache responds. Data:%h", cycles, mem2cache_data);

  wait(ready);
  @(posedge clock)begin
    write   <= 1;
    address <= 32'heeeeee00;
    data_in <= 32'h01020304;
  end
  @(write) $display("%d> Write request. Address:%h | Data:%h", cycles-1, address,
  data_in);
  @(posedge clock)begin
    write   <= 0;
    address <= 0;
    data_in <= 0;
  end

  wait(ready);
  @(posedge clock)begin
    read <= 1;
    address <= 32'hEEEEEE00;
  end
  @(address) $display("%d> Read address:%h", cycles-1, address);
  @(posedge clock)begin
    read    <= 0;
    address <= 0;
  end

  wait(valid & data_out == 32'h01020304);

  #10;
  $display("\ntb_L1_caching_logic --> Test Passed!\n\n");
  $finish;
end


//timeout
initial begin
  #400;
  $display("\ntb_L1_caching_logic --> Test Failed!\n\n");
  $stop;
end


//print values returned by the cache
always @(posedge clock)begin
  if(valid)
    $display("%d> Data word returned:%h | Address:%h", cycles-1, data_out,
      out_address);
end


endmodule
