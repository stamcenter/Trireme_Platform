/** @module : tb_memory_receive
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

module tb_memory_receive();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter CORE            = 0;
parameter DATA_WIDTH      = 32;
parameter ADDRESS_BITS    = 32;
parameter NUM_BYTES       = DATA_WIDTH/8;
parameter LOG2_NUM_BYTES  = log2(NUM_BYTES);
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;


reg clock;
reg reset;

reg [LOG2_NUM_BYTES-1:0] log2_bytes;
reg unsigned_load;

// Memory interface
reg [DATA_WIDTH-1:0] memory_data_in;
reg [ADDRESS_BITS-1:0] memory_address_in;

// Writeback interface
wire [DATA_WIDTH-1:0] load_data;

reg scan;

memory_receive #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) DUT (
  .clock(clock),
  .reset(reset),

  .log2_bytes(log2_bytes),
  .unsigned_load(unsigned_load),
  // Memory interface
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),

  // Writeback interface
  .load_data(load_data),

  .scan(scan)
);

always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;
  {log2_bytes, unsigned_load} = 3'd4;
  memory_data_in = 32'hAAAAAAAA;
  memory_address_in = 32'd0;
  scan = 1'b0;

  repeat (1) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  {log2_bytes, unsigned_load} = 3'd0;
  memory_data_in = 32'h000000FF;
  memory_address_in = 32'd0;

  repeat (1) @ (posedge clock);

  if( load_data !== 32'hFFFFFFFF ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected load data value for LB!");
    $display("\ntb_memory_receive --> Test Failed!\n\n");
    $stop();
  end

  {log2_bytes, unsigned_load} = 3'd1;
  memory_data_in = 32'h000000FF;
  memory_address_in = 32'd0;

  repeat (1) @ (posedge clock);

  if( load_data !== 32'h000000FF ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected load data value for LBU!");
    $display("\ntb_memory_receive --> Test Failed!\n\n");
    $stop();
  end

  {log2_bytes, unsigned_load} = 3'd2;
  memory_data_in = 32'hFFFF0000;
  memory_address_in = 32'd2;

  repeat (1) @ (posedge clock);

  if( load_data !== 32'hFFFFFFFF ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected load data value for LH!");
    $display("\ntb_memory_receive --> Test Failed!\n\n");
    $stop();
  end

  {log2_bytes, unsigned_load} = 3'd3;
  memory_data_in = 32'hFFFF0000;
  memory_address_in = 32'd2;

  repeat (1) @ (posedge clock);

  if( load_data !== 32'h0000FFFF ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected load data value for LHU!");
    $display("\ntb_memory_receive --> Test Failed!\n\n");
    $stop();
  end

  {log2_bytes, unsigned_load} = 3'd4;
  memory_data_in = 32'hFFFF0000;
  memory_address_in = 32'd4;

  repeat (1) @ (posedge clock);

  if( load_data !== 32'hFFFF0000 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected load data value for LW!");
    $display("\ntb_memory_receive --> Test Failed!\n\n");
    $stop();
  end

  {log2_bytes, unsigned_load} = 3'd5; // Should be same as 4 in RV32
  memory_data_in = 32'hAAAAAAAA;
  memory_address_in = 32'd4;

  repeat (1) @ (posedge clock);

  if( load_data !== 32'hAAAAAAAA ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected load data value for LWU!");
    $display("\ntb_memory_receive --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_memory_receive --> Test Passed!\n\n");
  $stop();
end


endmodule
