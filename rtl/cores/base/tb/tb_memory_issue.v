/** @module : tb_memory_issue
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

module tb_memory_issue();

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
parameter ADDRESS_BITS    = 20;
parameter NUM_BYTES       = DATA_WIDTH/8;
parameter LOG2_NUM_BYTES  = log2(NUM_BYTES);
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;


reg clock;
reg reset;

// Execute stage interface
reg load;
reg store;
reg [ADDRESS_BITS-1:0] address;
reg [DATA_WIDTH-1:0] store_data;
reg [LOG2_NUM_BYTES-1:0] log2_bytes;

// Memory interface
wire memory_read;
wire memory_write;
wire [NUM_BYTES-1:0] memory_byte_en;
wire [ADDRESS_BITS-1:0] memory_address;
wire [DATA_WIDTH-1:0] memory_data;

reg scan;

memory_issue #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) UUT (
  .clock(clock),
  .reset(reset),
  // Execute stage interface
  .load(load),
  .store(store),
  .address(address),
  .store_data(store_data),
  .log2_bytes(log2_bytes),

  // Memory interface
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address(memory_address),
  .memory_data(memory_data),

  .scan(scan)

);

always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;
  load = 1'b0;
  store = 1'b0;
  address = 0;
  store_data = 0;
  log2_bytes = 2'b10; // SW
  scan = 1'b0;

  repeat (1) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b0    |
      memory_write   !== 1'b0    |
      memory_address !== 0       |
      memory_data    !== 0       |
      memory_byte_en !== 4'b1111 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected memory interface signals!");
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  load = 1'b1;
  store = 1'b0;
  address = 4;
  store_data = 32'hffffffff;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b1         |
      memory_write   !== 1'b0         |
      memory_address !== 4            |
      memory_data    !== 32'hffffffff |
      memory_byte_en !== 4'b1111      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected memory interface signals!");
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  load = 1'b0;
  store = 1'b1;
  address = 8;
  store_data = 32'hffffffff;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b0         |
      memory_write   !== 1'b1         |
      memory_address !== 8            |
      memory_data    !== 32'hffffffff |
      memory_byte_en !== 4'b1111      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected memory interface signals!");
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  load = 1'b0;
  store = 1'b1;
  address = 0;
  log2_bytes = 2'b00; // SB
  store_data = 32'hffffffff;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b0         |
      memory_write   !== 1'b1         |
      memory_address !== 0            |
      memory_data    !== 32'hffffffff |
      memory_byte_en !== 4'b0001      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected signal during SB[0]!");
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  load = 1'b0;
  store = 1'b1;
  address = 1;
  log2_bytes = 2'b00; // SB
  store_data = 32'hffffffff;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b0         |
      memory_write   !== 1'b1         |
      memory_address !== 1            |
      memory_data    !== 32'hffffffff |
      memory_byte_en !== 4'b0010      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected signal during SB[1]!");
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  load = 1'b0;
  store = 1'b1;
  address = 2;
  log2_bytes = 2'b00; // SB
  store_data = 32'hffffffff;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b0         |
      memory_write   !== 1'b1         |
      memory_address !== 2            |
      memory_data    !== 32'hffffffff |
      memory_byte_en !== 4'b0100      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected signal during SB[2]!");
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  load = 1'b0;
  store = 1'b1;
  address = 3;
  log2_bytes = 2'b00; // SB
  store_data = 32'hffffffff;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b0         |
      memory_write   !== 1'b1         |
      memory_address !== 3            |
      memory_data    !== 32'hffffffff |
      memory_byte_en !== 4'b1000      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected signal during SB[3]!");
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  load = 1'b0;
  store = 1'b1;
  address = 0;
  log2_bytes = 2'b01; // SH
  store_data = 32'hffffffff;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b0         |
      memory_write   !== 1'b1         |
      memory_address !== 0            |
      memory_data    !== 32'hffffffff |
      memory_byte_en !== 4'b0011      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected signal during SH[0]!");
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  load = 1'b0;
  store = 1'b1;
  address = 2;
  log2_bytes = 2'b01; // SH
  store_data = 32'hffffffff;

  repeat (1) @ (posedge clock);

  if( memory_read    !== 1'b0         |
      memory_write   !== 1'b1         |
      memory_address !== 2            |
      memory_data    !== 32'hffffffff |
      memory_byte_en !== 4'b1100      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Unexpected signal during SH[1]!");
    $display("Base Byte: %h", UUT.base_byte);
    $display("Byte Mask[0]: %b", UUT.byte_en_mask[0]);
    $display("Byte Mask[1]: %b", UUT.byte_en_mask[1]);
    $display("Byte Mask[2]: %b", UUT.byte_en_mask[2]);
    $display("\ntb_memory_issue --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_memory_issue --> Test Passed!\n\n");
  $stop();

end


endmodule
