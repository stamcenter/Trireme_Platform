/** @module : tb_L1cache_bus_wrapper
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

module tb_L1cache_bus_wrapper();

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
parameter BUS_OFFSET_BITS    =  2;
parameter MAX_OFFSET_BITS    =  3;
parameter REPLACEMENT_MODE   =  1'b0;
parameter COHERENCE_PROTOCOL = "MESI";
parameter MODE               = "VIVT";
parameter PPN_BITS           = 22;
parameter VPN_BITS           = 20;
parameter PAGE_OFFSET_BITS   = 12;
parameter CORE               =  0;
parameter CACHE_NO           =  0;
parameter CACHE_WORDS        = 1 << CACHE_OFFSET_BITS;
parameter BUS_WORDS          = 1 << BUS_OFFSET_BITS;
parameter CACHE_WIDTH        = CACHE_WORDS * DATA_WIDTH;
parameter BUS_WIDTH          = BUS_WORDS   * DATA_WIDTH;
parameter TAG_BITS           = ADDRESS_BITS - INDEX_BITS - CACHE_OFFSET_BITS;
parameter WAY_BITS           = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
parameter SBITS              = COHERENCE_BITS + STATUS_BITS;

// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
`include `INCLUDE_FILE


reg  clock;
reg  reset;
//processor interface
reg  read, write, flush;
reg  [DATA_WIDTH/8-1:0] w_byte_en;
reg  [ADDRESS_BITS-1:0] address;
reg  [DATA_WIDTH-1  :0] data_in;
reg  report;
wire [DATA_WIDTH-1  :0] data_out;
wire [ADDRESS_BITS-1:0] out_address;
wire ready, valid;
//bus interface
reg  [MSG_BITS-1    :0] bus_msg_in;
reg  [ADDRESS_BITS-1:0] bus_address_in;
reg  [BUS_WIDTH-1   :0] bus_data_in;
reg  bus_master;
reg  req_ready;
reg  [log2(MAX_OFFSET_BITS):0] curr_offset;
wire [MSG_BITS-1    :0] bus_msg_out;
wire [ADDRESS_BITS-1:0] bus_address_out;
wire [BUS_WIDTH-1   :0] bus_data_out;
wire [log2(MAX_OFFSET_BITS):0] active_offset;


// Instantiate L1cache_bus_wrapper
L1cache_bus_wrapper #(
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
  .REPLACEMENT_MODE(REPLACEMENT_MODE),
  .COHERENCE_PROTOCOL(COHERENCE_PROTOCOL),
  .CORE(CORE),
  .CACHE_NO(CACHE_NO)
) DUT (
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
  .bus_msg_in(bus_msg_in),
  .bus_address_in(bus_address_in),
  .bus_data_in(bus_data_in),
  .bus_master(bus_master),
  .req_ready(req_ready),
  .curr_offset(curr_offset),
  .bus_msg_out(bus_msg_out),
  .bus_address_out(bus_address_out),
  .bus_data_out(bus_data_out),
  .active_offset(active_offset)
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
  report = 0;

  bus_msg_in     = NO_REQ;
  bus_address_in = 0;
  bus_data_in    = 0;
  req_ready      = 0;
  bus_master     = 0;
  curr_offset    = 0;

  read       = 0;
  write      = 0;
  flush      = 0;
  w_byte_en  = 4'hf;
  address    = 32'd0;
  data_in    = 32'd0;

  repeat(1) @(posedge clock);
  @(posedge clock) reset <= 1;
  $display("%0d> Assert reset signal.", cycles);
  repeat(10) @(posedge clock);
  @(posedge clock) reset <= 0;
  $display("%0d> Deassert reset signal.", cycles);

  wait(DUT.cache.controller.state == 0);
  $display("%0d> Reset sequence completed." ,cycles);

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    read <= 1;
    address <= 32'hEEEEEE04;
  end
  @(address) $display("%0d> Read request. Address:%h", cycles-1, address);
  @(posedge clock)begin
    read    <= 0;
    address <= 0;
  end

  wait(bus_msg_out == R_REQ & bus_address_out == 32'h3bbbbb80);
  $display("%0d> Interface issues read request on the bus.", cycles-1);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    req_ready <= 1;
    bus_master <= 1;
    $display("%0d> Bus control granted.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    bus_msg_in     <= MEM_RESP_S;
    bus_address_in <= 32'h3bbbbb80;
    bus_data_in    <= 128'h88888888_99999999_aaaaaaaa_bbbbbbbb;
  end
  @(bus_data_in) $display("%0d> Data from bus:%h", cycles-1, bus_data_in);
  @(posedge clock)begin
    bus_msg_in     <= NO_REQ;
    bus_address_in <= 0;
    bus_data_in    <= 0;
  end

  wait(valid & data_out == 32'haaaaaaaa);


  #20;
  $display("\ntb_L1cache_bus_wrapper --> Test Passed!\n\n");
  $stop();
end


// Simulation timeout
initial begin
  #1000;
  $display("\ntb_L1cache_bus_wrapper --> Test Failed!\n\n");
  $stop();
end


endmodule
