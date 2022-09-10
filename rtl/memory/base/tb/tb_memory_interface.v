/** @module : tb_memory_interface
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

module tb_memory_interface();

parameter DATA_WIDTH   = 32;
parameter ADDRESS_BITS = 32;

task print_signal_values;
  begin
    $display("Simulation time: %0t", $time);
    $display("fetch_read: %b", fetch_read);
    $display("fetch_address_out: %h", fetch_address_out);
    $display("fetch_data_in: %h", fetch_data_in);
    $display("fetch_address_in: %h", fetch_address_in);
    $display("fetch_valid: %b", fetch_valid);
    $display("fetch_ready: %b", fetch_ready);
    $display("i_mem_read: %b", i_mem_read);
    $display("i_mem_address_in: %b", i_mem_address_in);
    $display("i_mem_data_out: %b", i_mem_data_out);
    $display("i_mem_address_out: %b", i_mem_address_out);
    $display("i_mem_valid: %b", i_mem_valid);
    $display("i_mem_ready: %b", i_mem_ready);
    $display("memory_read: %b", memory_read);
    $display("memory_write: %b", memory_write);
    $display("memory_byte_en: %b", memory_byte_en);
    $display("memory_address_out: %b", memory_address_out);
    $display("memory_data_out: %b", memory_data_out);
    $display("memory_data_in: %b", memory_data_in);
    $display("memory_address_in: %b", memory_address_in);
    $display("memory_valid: %b", memory_valid);
    $display("memory_ready: %b", memory_ready);
    $display("d_mem_read: %b", d_mem_read);
    $display("d_mem_write: %b", d_mem_write);
    $display("d_mem_byte_en: %b", d_mem_byte_en);
    $display("d_mem_address_in: %b", d_mem_address_in);
    $display("d_mem_data_in: %b", d_mem_data_in);
    $display("d_mem_data_out: %b", d_mem_data_out);
    $display("d_mem_address_out: %b", d_mem_address_out);
    $display("d_mem_valid: %b", d_mem_valid);
    $display("d_mem_ready: %b", d_mem_ready);
  end
endtask

//fetch stage interface
reg  fetch_read;
reg  [ADDRESS_BITS-1:0] fetch_address_out;
wire [DATA_WIDTH-1  :0] fetch_data_in;
wire [ADDRESS_BITS-1:0] fetch_address_in;
wire fetch_valid;
wire fetch_ready;
//memory stage interface
reg  memory_read;
reg  memory_write;
reg  [DATA_WIDTH/8-1:0] memory_byte_en;
reg  [ADDRESS_BITS-1:0] memory_address_out;
reg  [DATA_WIDTH-1  :0] memory_data_out;
wire [DATA_WIDTH-1  :0] memory_data_in;
wire [ADDRESS_BITS-1:0] memory_address_in;
wire memory_valid;
wire memory_ready;
//instruction memory/cache interface
reg  [DATA_WIDTH-1  :0] i_mem_data_out;
reg  [ADDRESS_BITS-1:0] i_mem_address_out;
reg  i_mem_valid;
reg  i_mem_ready;
wire i_mem_read;
wire [ADDRESS_BITS-1:0] i_mem_address_in;
//data memory/cache interface
reg  [DATA_WIDTH-1  :0] d_mem_data_out;
reg  [ADDRESS_BITS-1:0] d_mem_address_out;
reg  d_mem_valid;
reg  d_mem_ready;
wire d_mem_read;
wire d_mem_write;
wire [DATA_WIDTH/8-1:0] d_mem_byte_en;
wire [ADDRESS_BITS-1:0] d_mem_address_in;
wire [DATA_WIDTH-1  :0] d_mem_data_in;

reg scan;

//instantiate memory_interface
memory_interface #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) DUT (
  .fetch_read(fetch_read),
  .fetch_address_out(fetch_address_out),
  .fetch_data_in(fetch_data_in),
  .fetch_address_in(fetch_address_in),
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address_out(memory_address_out),
  .memory_data_out(memory_data_out),
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  .i_mem_data_out(i_mem_data_out),
  .i_mem_address_out(i_mem_address_out),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_ready),
  .i_mem_read(i_mem_read),
  .i_mem_address_in(i_mem_address_in),
  .d_mem_data_out(d_mem_data_out),
  .d_mem_address_out(d_mem_address_out),
  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),
  .d_mem_byte_en(d_mem_byte_en),
  .d_mem_address_in(d_mem_address_in),
  .d_mem_data_in(d_mem_data_in),
  .scan(scan)
);

//test vectos
initial begin
  fetch_read        <= 0;
  fetch_address_out <= 0;
  memory_read       <= 0;
  memory_write      <= 0;
  memory_address_out<= 0;
  memory_data_out   <= 0;
  i_mem_data_out    <= 0;
  i_mem_address_out <= 0;
  i_mem_valid       <= 0;
  i_mem_ready       <= 0;
  d_mem_data_out    <= 0;
  d_mem_address_out <= 0;
  d_mem_valid       <= 0;
  d_mem_ready       <= 0;
  scan              <= 0;

  #10;
  fetch_read        <= 1;
  fetch_address_out <= 32'h11111111;

  #1;
  if(DUT.i_mem_read       != fetch_read   |
     DUT.i_mem_address_in != fetch_address_out)
  begin
    $display("\nTest 1 Error!");
    $display("\ntb_memory_interface --> Test Failed!\n\n");
    print_signal_values();
    $stop;
  end

  #9;
  i_mem_data_out    <= 32'h22222222;
  i_mem_address_out <= 32'h11111111;
  i_mem_valid       <= 1;
  i_mem_ready       <= 1;

  #1;
  if(DUT.fetch_data_in     != i_mem_data_out    |
     DUT.fetch_address_in  != i_mem_address_out |
     DUT.fetch_valid       != i_mem_valid       |
     DUT.fetch_ready       != i_mem_ready       )
  begin
    $display("\nTest 2 Error!");
    $display("\ntb_memory_interface --> Test Failed!\n\n");
    print_signal_values();
    $stop;
  end

  #9;
  memory_write = 1;
  memory_address_out <= 32'h12341234;
  memory_data_out    <= 32'h99999999;

  #1;
  if(DUT.d_mem_write      != memory_write   |
     DUT.d_mem_read       != memory_read    |
     DUT.d_mem_address_in != memory_address_out |
     DUT.d_mem_data_in    != memory_data_out    )
  begin
    $display("\nTest 3 Error!");
    $display("\ntb_memory_interface --> Test Failed!\n\n");
    print_signal_values();
    $stop;
  end

  #9;
  d_mem_address_out <= 32'haabbccdd;
  d_mem_data_out    <= 32'h10002000;
  d_mem_valid       <= 1'b1;
  d_mem_ready       <= 1'b1;

  #1;
  if(DUT.memory_data_in     != d_mem_data_out    |
     DUT.memory_address_in  != d_mem_address_out |
     DUT.memory_valid       != d_mem_valid       |
     DUT.memory_ready       != d_mem_ready       )
  begin
    $display("\nTest 4 Error!");
    $display("\ntb_memory_interface --> Test Failed!\n\n");
    print_signal_values();
    $stop;
  end

  $display("\ntb_memory_interface --> Test Passed!\n\n");
  $stop;
end

endmodule
