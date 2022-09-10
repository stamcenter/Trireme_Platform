/** @module : tb_cache_bus_interface
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

module tb_cache_bus_interface();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter STATUS_BITS        =  2;
parameter COHERENCE_BITS     =  2;
parameter CACHE_OFFSET_BITS  =  2;
parameter DATA_WIDTH         = 32;
parameter NUMBER_OF_WAYS     =  4;
parameter ADDRESS_BITS       = 32;
parameter INDEX_BITS         =  8;
parameter MSG_BITS           =  4;
parameter	BUS_OFFSET_BITS    =  1;
parameter	MAX_OFFSET_BITS    =  3;
parameter COHERENCE_PROTOCOL = "MESI";
parameter CORE               =  0;
parameter CACHE_NO           =  0;
parameter CACHE_WORDS        = 1 << CACHE_OFFSET_BITS;
parameter CACHE_WIDTH        = DATA_WIDTH * CACHE_WORDS;
parameter BUS_WORDS          = 1 << BUS_OFFSET_BITS;
parameter BUS_WIDTH          = BUS_WORDS * DATA_WIDTH;
parameter WAY_BITS           = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
parameter TAG_BITS           = ADDRESS_BITS - INDEX_BITS - CACHE_OFFSET_BITS;
parameter SBITS              = COHERENCE_BITS + STATUS_BITS;


// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
`include `INCLUDE_FILE

reg  clock, reset;
//interface with the shared bus
reg  [MSG_BITS-1           :0] bus_msg_in;
reg  [ADDRESS_BITS-1       :0] bus_address_in;
reg  [BUS_WIDTH-1          :0] bus_data_in;
reg  [log2(MAX_OFFSET_BITS):0] curr_offset;
reg  bus_master;
reg  req_ready;
wire [MSG_BITS-1           :0] bus_msg_out;
wire [ADDRESS_BITS-1       :0] bus_address_out;
wire [BUS_WIDTH-1          :0] bus_data_out;
wire [log2(MAX_OFFSET_BITS):0] active_offset;
//interface with cache controller
reg  [MSG_BITS-1           :0] cache_msg_in;
reg  [ADDRESS_BITS-1       :0] cache_address_in;
reg  [CACHE_WIDTH-1        :0] cache_data_in;
reg  i_reset;
wire [MSG_BITS-1           :0] cache_msg_out;
wire [ADDRESS_BITS-1       :0] cache_address_out;
wire [CACHE_WIDTH-1        :0] cache_data_out;
//interface with cache memory
reg  [CACHE_WIDTH-1   :0] port1_read_data;
reg  [WAY_BITS-1      :0] port1_matched_way;
reg  [COHERENCE_BITS-1:0] port1_coh_bits;
reg  [STATUS_BITS-1   :0] port1_status_bits;
reg  port1_hit;
wire port1_read, port1_write, port1_invalidate;
wire [INDEX_BITS-1    :0] port1_index;
wire [TAG_BITS-1      :0] port1_tag;
wire [SBITS-1         :0] port1_metadata;
wire [CACHE_WIDTH-1   :0] port1_write_data;
wire [WAY_BITS-1      :0] port1_way_select;



// instantiate DUT
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
) DUT (
  .clock(clock), 
  .reset(reset),
  //interface with cache controller,
  .cache_msg_in(cache_msg_in),
  .cache_address_in(cache_address_in),
  .cache_data_in(cache_data_in),
  .i_reset(i_reset),
  .cache_msg_out(cache_msg_out),
  .cache_address_out(cache_address_out),
  .cache_data_out(cache_data_out),
  //interface with shared bus
  .bus_msg_in(bus_msg_in),
  .bus_address_in(bus_address_in),
  .bus_data_in(bus_data_in),
  .curr_offset(curr_offset),
  .bus_master(bus_master),
  .req_ready(req_ready),
  .bus_msg_out(bus_msg_out),
  .bus_address_out(bus_address_out),
  .bus_data_out(bus_data_out),
  .active_offset(active_offset),
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


//generate clock
always #1 clock = ~clock;

//cycle counter
reg [31:0] cycles;
always @(posedge clock)begin
  cycles <= cycles + 1;
end

// Test patterns
initial begin
  cycles = 0;
  clock  = 0;
  reset  = 0;

  bus_msg_in     = NO_REQ;
  bus_address_in = 0;
  bus_data_in    = 0;
  req_ready      = 0;
  bus_master     = 0;
  curr_offset    = 0;

  cache_msg_in     = NO_REQ;
  cache_address_in = 0;
  cache_data_in    = 0;
  i_reset          = 0;

  port1_read_data   = {CACHE_WIDTH{1'b0}};
  port1_matched_way = {WAY_BITS{1'b0}};
  port1_coh_bits    = {COHERENCE_BITS{1'b0}};
  port1_status_bits = {SBITS{1'b0}};
  port1_hit         = 1'b0;


  repeat(1) @(posedge clock);
  @(posedge clock) begin
    reset   <= 1;
    i_reset <= 1;
    $display("%0d> Assert reset.", cycles);
  end
  repeat(1) @(posedge clock);
  @(posedge clock) begin
    reset   <= 0;
    i_reset <= 0;
    $display("%0d> Deassert reset.", cycles);
  end

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= WB_REQ;
    cache_address_in <= 32'h00001144;
    cache_data_in <= 128'h11111111_22222222_33333333_44444444;
  end
  @(cache_address_in)begin
    $display("%0d> Write-back request. Address:%0h | data:%0h", cycles-1,
      cache_address_in, cache_data_in);
  end
  wait(bus_msg_out == WB_REQ);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    req_ready <= 1;
    bus_master <= 1;
    $display("%0d> Bus control granted.", cycles);
  end
  @(bus_data_out) $display("%0d> Bus data:%0h", cycles-1, bus_data_out);
  @(bus_data_out) $display("%0d> Bus data:%0h", cycles-1, bus_data_out);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    bus_msg_in <= MEM_RESP;
    $display("%0d> Response from L2/memory.", cycles);
  end
  @(posedge clock)begin
    bus_msg_in <= NO_REQ;
    bus_master <= 0;
    req_ready  <= 0;
  end
  wait(cache_msg_out == MEM_RESP);
  $display("%0d> Interface responds to the L1 cache.", cycles-1);
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
    cache_data_in <= 0;
  end

  //Read request
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= R_REQ;
    cache_address_in <= 32'h80005508;
    cache_data_in <= 0;
    $display("%0d> Read request.", cycles);
  end
  wait(bus_msg_out == R_REQ);
  $display("%0d> Interface issues read request on the bus.", cycles-1);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    req_ready <= 1;
    bus_master <= 1;
    $display("%0d> Bus control granted.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    bus_msg_in <= MEM_RESP_S;
    bus_address_in <= 32'h80005508;
    bus_data_in <= 64'h88888888_99999999;
  end
  @(bus_data_in) $display("%0d> Data from bus:%h", cycles-1, bus_data_in);
  @(posedge clock)begin
    bus_data_in <= 64'h66666666_77777777;
  end
  @(bus_data_in) $display("%0d> Data from bus:%h", cycles-1, bus_data_in);
  @(posedge clock)begin
    bus_msg_in <= NO_REQ;
    bus_address_in <= 0;
    bus_data_in <= 0;
  end
  wait(cache_msg_out == MEM_RESP_S);
  $display("%0d> Interface responds to L1 cache. Data returned:%h", cycles-1,
    cache_data_out);
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
    cache_data_in <= 0;
  end

  #10;
  $display("\ntb_cache_bus_interface --> Test Passed!\n\n");
  $stop;  
end

//timeout
initial begin
  #400;
  $display("\ntb_cache_bus_interface--> Test Failed!\n\n");
  $stop;
end

endmodule
