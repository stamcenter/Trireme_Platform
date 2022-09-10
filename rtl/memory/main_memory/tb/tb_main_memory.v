/** @module : tb_main_memory
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
module tb_main_memory();

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value>>1;
  end
endfunction

parameter DATA_WIDTH    = 32,
          ADDRESS_WIDTH = 32,
          MSG_BITS      = 4,
          INDEX_BITS    = 15,
          NUM_PORTS     = 1;

localparam MEM_DEPTH = 1 << INDEX_BITS;
localparam IDLE      = 0,
           SERVING   = 1,
           READ_OUT  = 2;

// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
`include `INCLUDE_FILE

reg  clock, reset;
reg  [NUM_PORTS*MSG_BITS-1 : 0]           msg_in;
reg  [NUM_PORTS*ADDRESS_WIDTH-1 : 0]     address;
reg  [NUM_PORTS*DATA_WIDTH-1 : 0]        data_in;
wire [NUM_PORTS*MSG_BITS-1 : 0]          msg_out;
wire [NUM_PORTS*ADDRESS_WIDTH-1 : 0] address_out;
wire [NUM_PORTS*DATA_WIDTH-1 : 0]       data_out;

//instantiate DUT
main_memory #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_WIDTH),
  .MSG_BITS(MSG_BITS),
  .INDEX_BITS(INDEX_BITS),
  .NUM_PORTS(NUM_PORTS)
) DUT (
  clock,
  reset,
  msg_in,
  address,
  data_in,
  msg_out,
  address_out,
  data_out
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
  clock   = 0;
  reset   = 0;
  cycles  = 0;
  msg_in  = NO_REQ;
  address = 0;
  data_in = 0;
//Initialize memory contents
  DUT.BRAM_inst.ram[0] = 32'd555;
  DUT.BRAM_inst.ram[1] = 32'd600;
  DUT.BRAM_inst.ram[2] = 32'd777;
  DUT.BRAM_inst.ram[3] = 32'd800;
  DUT.BRAM_inst.ram[4] = 32'd999;

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
  wait(DUT.state == 0);
  $display("%0d> DUT in IDLE state.", cycles-1);

  //read request
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    msg_in <= R_REQ;
    address <= 1;
    $display("%0d> Read request. address = 1", cycles);
  end
  wait(msg_out == MEM_RESP);
  $display("%0d> Memory responds. Data:%0d", cycles-1, data_out);
  @(posedge clock)begin
    msg_in <= NO_REQ;
    address <= 0;
  end

  //read request
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    msg_in <= R_REQ;
    address <= 2;
    $display("%0d> Read request. address = 2", cycles);
  end
  wait(msg_out == MEM_RESP);
  $display("%0d> Memory responds. Data:%0d", cycles-1, data_out);
  @(posedge clock)begin
    msg_in <= NO_REQ;
    address <= 0;
  end

  //write request
  @(posedge clock)begin
    msg_in <= WB_REQ;
    address <= 1;
    data_in <= 32'd1057;
    $display("%0d> Write request. address = 1 | Data: 1057", cycles);
  end
  wait(msg_out == MEM_RESP);
  $display("%0d> Memory responds. Data:%0d", cycles-1, data_out);
  @(posedge clock)begin
    msg_in <= NO_REQ;
    address <= 0;
  end

  //read request
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    msg_in <= R_REQ;
    address <= 1;
    $display("%0d> Read request. address = 1", cycles);
  end
  wait(msg_out == MEM_RESP);
  $display("%0d> Memory responds. Data:%0d", cycles-1, data_out);
  @(posedge clock)begin
    msg_in <= NO_REQ;
    address <= 0;
  end

  #20;
  $display("\ntb_main_memory --> Test Passed!\n\n");
  $stop;
end

//timeout
initial begin
  #500;
  $display("\ntb_main_memory --> Test Failed!\n\n");
  $stop;
end

endmodule
