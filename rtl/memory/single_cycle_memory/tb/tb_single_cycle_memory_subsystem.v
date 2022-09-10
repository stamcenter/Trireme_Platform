/** @module : tb_single_cycle_memory_subsystem
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

module tb_single_cycle_memory_subsystem();

parameter DATA_WIDTH       = 32;
parameter ADDRESS_BITS     = 32;
parameter I_ADDRESS_BITS   =  8;
parameter D_ADDRESS_BITS   = 12;

reg clock;
reg reset;
//instruction memory
reg  i_mem_read;
reg  [ADDRESS_BITS-1:0] i_mem_address_in;
wire [DATA_WIDTH-1  :0] i_mem_data_out;
wire [ADDRESS_BITS-1:0] i_mem_address_out;
wire i_mem_valid;
wire i_mem_ready;
//data memory
reg  d_mem_read;
reg  d_mem_write;
reg  [DATA_WIDTH/8-1:0] d_mem_byte_en;
reg  [ADDRESS_BITS-1:0] d_mem_address_in;
reg  [DATA_WIDTH-1  :0] d_mem_data_in;
wire [DATA_WIDTH-1  :0] d_mem_data_out;
wire [ADDRESS_BITS-1:0] d_mem_address_out;
wire d_mem_valid;
wire d_mem_ready;

reg scan;


//instantiate memory_subsystem
single_cycle_memory_subsystem#(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .I_ADDRESS_BITS(I_ADDRESS_BITS),
  .D_ADDRESS_BITS(D_ADDRESS_BITS)
) DUT (
  .clock(clock),
  .reset(reset),
  .i_mem_read(i_mem_read),
  .i_mem_address_in(i_mem_address_in),
  .i_mem_data_out(i_mem_data_out),
  .i_mem_address_out(i_mem_address_out),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_ready),
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),
  .d_mem_byte_en(d_mem_byte_en),
  .d_mem_address_in(d_mem_address_in),
  .d_mem_data_in(d_mem_data_in),
  .d_mem_data_out(d_mem_data_out),
  .d_mem_address_out(d_mem_address_out),
  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),
  .scan(scan)
);


// generate clock signal
always #1 clock = ~clock;

initial begin
  clock            <= 0;
  reset            <= 1;
  i_mem_read       <= 0;
  i_mem_address_in <= 0;
  d_mem_read       <= 0;
  d_mem_write      <= 0;
  d_mem_byte_en    <= 4'b1111;
  d_mem_address_in <= 0;
  d_mem_data_in    <= 0;

  repeat(1) @(posedge clock);
  @(posedge clock)begin
    reset <= 0;
    // Only works with flat memory
    //DUT.instruction_memory.sram[3] <= 32'h33333333;
    //DUT.data_memory.sram[4]        <= 32'h44444444;
  end

  repeat(1) @(posedge clock);
  @(posedge clock)begin
    i_mem_read       <= 0;
    i_mem_address_in <= 0;
    d_mem_read       <= 0;
    d_mem_write      <= 1;
    d_mem_address_in <= 4;
    d_mem_data_in    <= 32'h44444444;
  end

  repeat(1) @(posedge clock);
  @(posedge clock)begin
    i_mem_read       <= 1;
    i_mem_address_in <= 3;
    d_mem_read       <= 1;
    d_mem_address_in <= 4;
  end
  // Flat memory test
  //wait(i_mem_data_out == 32'h33333333 & d_mem_data_out == 32'h44444444);
  // Byte loop memory test
  wait(d_mem_data_out == 32'h44444444);

  @(posedge clock)begin
    i_mem_read       <= 0;
    i_mem_address_in <= 0;
    d_mem_read       <= 0;
    d_mem_write      <= 1;
    d_mem_address_in <= 4;
    d_mem_data_in    <= 32'h12345678;
  end
  @(posedge clock)begin
    i_mem_read       <= 1;
    i_mem_address_in <= 3;
    d_mem_read       <= 1;
    d_mem_write      <= 0;
    d_mem_address_in <= 4;
    d_mem_data_in    <= 0;
  end
  // Flat memory test
  //wait(i_mem_data_out == 32'h33333333 & d_mem_data_out == 32'h12345678);
  // Byte loop memory test
  wait(d_mem_data_out == 32'h12345678);

  $display("\ntb_single_cycle_memory_subsystem --> Test Passed!\n\n");
  $stop;

end

initial begin
  #100;
  $display("\ntb_single_cycle_memory_subsystem --> Test Failed!\n\n");
  $stop;
end

endmodule
