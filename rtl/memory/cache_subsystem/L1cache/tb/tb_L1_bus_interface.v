/** @module : tb_L1_bus_interface
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

module tb_L1_bus_interface();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter CACHE_OFFSET_BITS =  3,
          BUS_OFFSET_BITS   =  1,
          DATA_WIDTH        = 32,
          ADDRESS_WIDTH     = 32,
          MSG_BITS          = 4;

localparam CACHE_WORDS = 1 << CACHE_OFFSET_BITS; //number of words in one line.
localparam BUS_WORDS   = 1 << BUS_OFFSET_BITS; //width of data bus.
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam BUS_WIDTH   = DATA_WIDTH*BUS_WORDS;

localparam IDLE              =  0,
           SNOOPER_REQ       =  1,
           CACHE_REQ         =  2, 
           SN_WAIT_FOR_BUS   =  3,
           SN_WAIT_FOR_READY =  4,
           SN_TRANSFER       =  5,
           SN_WAIT_RESP      =  6,
           WAIT_FOR_BUS      =  7,
           WAIT_RESP         =  8,
           TRANSFER          =  9,
           RECEIVE           = 10,
           WAIT_FOR_SNOOP    = 11,
           WAIT_FOR_CACHE    = 12;

// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
`include `INCLUDE_FILE


reg clock, reset;
reg  [log2(CACHE_OFFSET_BITS):0] cache_offset;

reg  [MSG_BITS-1:      0] cache_msg_in     ;
reg  [ADDRESS_WIDTH-1: 0] cache_address_in ;
reg  [CACHE_WIDTH-1:   0] cache_data_in    ;
wire [MSG_BITS-1:      0] cache_msg_out    ;
wire [ADDRESS_WIDTH-1: 0] cache_address_out;
wire [CACHE_WIDTH-1:   0] cache_data_out   ;

reg  [MSG_BITS-1:      0] snoop_msg_in     ;
reg  [ADDRESS_WIDTH-1: 0] snoop_address_in ;
reg  [CACHE_WIDTH-1:   0] snoop_data_in    ;
wire [MSG_BITS-1:      0] snoop_msg_out    ;
wire [ADDRESS_WIDTH-1: 0] snoop_address_out;
wire [CACHE_WIDTH-1:   0] snoop_data_out   ;

reg  [MSG_BITS-1:      0]     bus_msg_in  ;
reg  [ADDRESS_WIDTH-1: 0] bus_address_in  ;
reg  [BUS_WIDTH-1:     0]    bus_data_in  ;
wire [MSG_BITS-1:      0]     bus_msg_out ;
wire [ADDRESS_WIDTH-1: 0] bus_address_out ;
wire [BUS_WIDTH-1:     0]    bus_data_out ;
wire [log2(CACHE_OFFSET_BITS):0] active_offset;

reg req_ready;
reg bus_master;


// instantiate DUT
L1_bus_interface #(
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS), 
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_WIDTH),
  .MSG_BITS(MSG_BITS)
) DUT (
clock, 
reset,
cache_offset,

cache_msg_in,
cache_address_in,
cache_data_in,
cache_msg_out,
cache_address_out,
cache_data_out,

snoop_msg_in,
snoop_address_in,
snoop_data_in,
snoop_msg_out,
snoop_address_out,
snoop_data_out,

bus_msg_in,
bus_address_in,
bus_data_in,
bus_msg_out,
bus_address_out,
bus_data_out,
active_offset,

bus_master,
req_ready
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
  clock = 0;
  reset = 0;
  cache_offset = 2;
  cache_msg_in = NO_REQ;
  cache_address_in = 0;
  cache_data_in = 0;
  snoop_msg_in = NO_REQ;
  snoop_address_in = 0;
  snoop_data_in = 0;
  bus_msg_in = NO_REQ;
  bus_address_in = 0;
  bus_data_in = 0;
  req_ready = 0;
  bus_master = 0;

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
  //Request from snooper. Snooper should win the arbitration
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    snoop_msg_in <= EN_ACCESS;
    snoop_address_in <= 32'h12345678;
    $display("%0d> Snooper issues a request.", cycles);
  end
  wait(bus_msg_out == EN_ACCESS);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    req_ready <= 1;
  end
  wait(snoop_msg_out == EN_ACCESS);
  $display("%0d> Interface responds to the snooper.", cycles-1);
  @(posedge clock)begin
    snoop_msg_in <= NO_REQ;
    snoop_address_in <= 0;
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
  $display("\ntb_L1_bus_interface --> Test Passed!\n\n");
  $stop;  
end

//timeout
initial begin
  #400;
  $display("\ntb_L1_bus_interface --> Test Failed!\n\n");
  $stop;
end

endmodule
