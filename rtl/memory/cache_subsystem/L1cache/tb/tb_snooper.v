/** @module : tb_snooper
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

module tb_snooper();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter CACHE_OFFSET_BITS =  1, //max offset bits from cache side
          BUS_OFFSET_BITS   =  1, //determines width of the bus
          DATA_WIDTH        = 32,
          ADDRESS_WIDTH     = 32,
          MSG_BITS          =  4,
          INDEX_BITS        =  8,  //max index bits for the cache
          COHERENCE_BITS    =  2,
          STATUS_BITS       =  2,
          NUMBER_OF_WAYS    =  4,
	        MAX_OFFSET_BITS   =  2;

parameter CACHE_WORDS = 1 << CACHE_OFFSET_BITS; //number of words in one line.
parameter BUS_WORDS   = 1 << BUS_OFFSET_BITS; //width of data bus.
parameter CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
parameter BUS_WIDTH   = DATA_WIDTH*BUS_WORDS;
parameter SBITS       = COHERENCE_BITS + STATUS_BITS;
parameter TAG_BITS    = ADDRESS_WIDTH - CACHE_OFFSET_BITS - INDEX_BITS;
parameter WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;

parameter IDLE            = 3'd0,
          START           = 3'd1,
          READ_LINE       = 3'd2,
          WRITE_LINE      = 3'd3,
          INVALIDATE_LINE = 3'd4,
          ACTION          = 3'd5,
          WAIT_FOR_RESP   = 3'd6;

// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
`include `INCLUDE_FILE


reg clock, reset;
//interface to cache memory
reg  [CACHE_WIDTH-1   :0] data_in;
reg  [WAY_BITS-1      :0] matched_way;
reg  [COHERENCE_BITS-1:0] coh_bits;
reg  [STATUS_BITS-1   :0] status_bits;
reg  hit;
wire read, write, invalidate;
wire [INDEX_BITS-1    :0] index;
wire [TAG_BITS-1      :0] tag;
wire [SBITS-1         :0] meta_data;
wire [CACHE_WIDTH-1   :0] data_out;
wire [WAY_BITS-1      :0] way_select;

//interface to L1 bus interface
reg  [MSG_BITS-1:      0] intf_msg;
reg  [ADDRESS_WIDTH-1: 0] intf_address;
reg  [CACHE_WIDTH-1:   0] intf_data;
wire [MSG_BITS-1:      0] snoop_msg;
wire [ADDRESS_WIDTH-1: 0] snoop_address;
wire [CACHE_WIDTH-1:   0] snoop_data;

//interface to the shared bus
reg  [MSG_BITS-1:      0] bus_msg;
reg  [ADDRESS_WIDTH-1: 0] bus_address;
reg  req_ready;
reg  bus_master;
reg [log2(MAX_OFFSET_BITS):0] curr_offset;


//instantiate DUT
snooper #(
  CACHE_OFFSET_BITS,
  BUS_OFFSET_BITS,
  DATA_WIDTH,
  ADDRESS_WIDTH,
  MSG_BITS,
  INDEX_BITS,
  COHERENCE_BITS,
  STATUS_BITS,
  NUMBER_OF_WAYS
) DUT (
  clock,
  reset,
  data_in,
  matched_way,
  coh_bits,
  status_bits,
  hit,
  read, 
  write, 
  invalidate,
  index,
  tag,
  meta_data,
  data_out,
  way_select,
  
  intf_msg,
  intf_address,
  intf_data,
  snoop_msg,
  snoop_address,
  snoop_data,
  
  bus_msg,
  bus_address,
  req_ready,
  bus_master,
  curr_offset
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
  clock        = 0;
  reset        = 0;
  cycles       = 0;
  data_in      = 0;
  matched_way  = 0;
  coh_bits     = 0;
  status_bits  = 0;
  hit          = 0;
  intf_msg     = NO_REQ;
  intf_address = 0;
  intf_data    = 0;
  bus_msg      = NO_REQ;
  bus_address  = 0;
  req_ready    = 0;
  bus_master   = 0;
  curr_offset  = 0;

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

  //R_REQ
  repeat(1) @(posedge clock);
  @(posedge clock) begin
    bus_msg <= R_REQ;
    bus_address <= 32'h11223344;
    curr_offset <= 2;
    $display("%0d> Read request on shared bus.", cycles);
  end
  wait(read);
  $display("%0d> Read request to cache memory. Index:%h", cycles-1, index);
  @(posedge clock)begin
    hit <= 1'b1;
    data_in <= 128'h00000000_00000000_12341234_AAAABBBB;
    status_bits <= 2'b10;
    coh_bits <= 2'b01;
    matched_way <= 2;
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    hit <= 1'b0;
    data_in <= 0;
    status_bits <= 0;
    coh_bits <= 2'b00;
    matched_way <= 0;
  end
  wait(read & index == 8'ha3);
  $display("%0d> Read request to cache memory. Index:%h", cycles-1, index);
  @(posedge clock)begin
    hit <= 1'b1;
    data_in <= 128'h00000000_00000000_99999999_FFFFEEEE;
    status_bits <= 2'b11;
    coh_bits <= 2'b10;
    matched_way <= 3;
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    hit <= 1'b0;
    data_in <= 0;
    status_bits <= 0;
    coh_bits <= 2'b00;
    matched_way <= 0;
  end
  wait(snoop_msg == C_WB);
  $display("%0d> Write back request to Bus interface. Address:%h | Data:%h", 
    cycles-1, snoop_address, snoop_data);
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    intf_msg <= MEM_RESP;
  end
  @(posedge clock)begin
    intf_msg <= NO_REQ;
    bus_msg <= NO_REQ;
    bus_address <= 0;
    curr_offset <= 0;
  end
  wait(snoop_msg == EN_ACCESS);
  $display("%0d> Enable the original request. Address:%h | Data:%h", 
    cycles-1, snoop_address, snoop_data);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    intf_msg <= EN_ACCESS;
  end
  @(posedge clock)begin
    intf_msg <= R_REQ;
    req_ready <= 1;
  end
  repeat(4) @(posedge clock);
  @(posedge clock)begin
    intf_msg <= NO_REQ;
    req_ready <= 0;
  end

  //WS_BCAST
  wait(DUT.state == IDLE);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    bus_msg <= WS_BCAST;
    bus_address <= 32'h11220000;
    curr_offset <= 1;
    $display("%0d> Share write request on shared bus.", cycles);
  end 
  wait(read);
  $display("%0d> Read request to cache memory. Index:%h", cycles-1, index);
  @(posedge clock)begin
    hit <= 1'b1;
    data_in <= 128'h00000000_00000000_55555555_66666666;
    status_bits <= 2'b10;
    coh_bits <= 2'b11;
    matched_way <= 0;
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    hit <= 1'b0;
    data_in <= 0;
    status_bits <= 0;
    coh_bits <= 2'b00;
    matched_way <= 0;
  end
  wait(snoop_msg == EN_ACCESS);
  $display("%0d> Enable the request. Address:%h | Data:%h", 
    cycles-1, snoop_address, snoop_data);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    intf_msg <= EN_ACCESS;
    req_ready <= 1;
  end
  @(posedge clock)begin
    intf_msg <= NO_REQ;
    req_ready <= 0;
    bus_msg <= NO_REQ;
  end

  //REQ_FLUSH
  wait(DUT.state == IDLE);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    bus_msg <= REQ_FLUSH;
    bus_address <= 32'h5555002C;
    curr_offset <= 2;
    $display("%0d> Flush request from L2 cache.", cycles);
  end 
  wait(read);
  $display("%0d> Read request to cache memory. Index:%h", cycles-1, index);
  @(posedge clock)begin
    hit <= 1'b1;
    data_in <= 128'h00000000_00000000_33333333_CCCCCCCC;
    status_bits <= 2'b11;
    coh_bits <= 2'b10;
    matched_way <= 1;
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    hit <= 1'b0;
    data_in <= 0;
    status_bits <= 0;
    coh_bits <= 2'b00;
    matched_way <= 0;
  end
  wait(snoop_msg == C_FLUSH);
  $display("%0d> Flushing dirty line. Index:%h | Data:%h", cycles-1, 
    snoop_address, snoop_data);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    intf_msg <= MEM_RESP;
  end
  @(posedge clock)begin
    intf_msg <= NO_REQ;
  end
  wait(read);
  $display("%0d> Read request to cache memory. Index:%h", cycles-1, index);
  @(posedge clock)begin
    hit <= 1'b1;
    data_in <= 128'h00000000_00000000_88888888_AAAAAAAA;
    status_bits <= 2'b11;
    coh_bits <= 2'b10;
    matched_way <= 1;
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    hit <= 1'b0;
    data_in <= 0;
    status_bits <= 0;
    coh_bits <= 2'b00;
    matched_way <= 0;
  end
  wait(snoop_msg == C_FLUSH);
  $display("%0d> Flushing dirty line. Index:%h | Data:%h", cycles-1, 
    snoop_address, snoop_data);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    intf_msg <= MEM_RESP;
  end
  @(posedge clock)begin
    intf_msg <= NO_REQ;
  end
  wait(snoop_msg == EN_ACCESS);
  $display("%0d> Snooper sends EN_ACCESS signal. Address:%h | Data:%h", 
    cycles-1, snoop_address, snoop_data);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    intf_msg <= EN_ACCESS;
    req_ready <= 1;
  end
  @(posedge clock)begin
    intf_msg <= NO_REQ;
    req_ready <= 0;
    bus_msg <= NO_REQ;
  end

  //RFO_BCAST for addresses not present in the cache
  wait(DUT.state == IDLE);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    bus_msg <= RFO_BCAST;
    bus_address <= 32'hABCD0036;
    curr_offset <= 2;
    $display("%0d> Request for ownership broadcast on shared bus.", cycles);
  end
  wait(read);
  $display("%0d> Read request to cache memory. Index:%h", cycles-1, index);
  wait(read & index==28);
  $display("%0d> Read request to cache memory. Index:%h", cycles-1, index);
  wait(snoop_msg == EN_ACCESS);
  $display("%0d> Snooper sends EN_ACCESS signal. Address:%h | Data:%h", 
    cycles-1, snoop_address, snoop_data);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    intf_msg <= EN_ACCESS;
    req_ready <= 1;
  end
  @(posedge clock)begin
    intf_msg <= NO_REQ;
    req_ready <= 0;
    bus_msg <= NO_REQ;
  end

  #10;
  $display("\ntb_snooper --> Test Passed!\n\n");
  $stop;
end

//timeout
initial begin
  #400;
  $display("\ntb_snooper --> Test Failed!\n\n");
  $stop;
end

endmodule
