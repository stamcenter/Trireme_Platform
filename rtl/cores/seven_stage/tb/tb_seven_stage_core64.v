/** @module : tb_seven_stage_core64
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

`define CORE_REGISTER_FILE DUT.ID.base_decode.registers.register_file

module tb_seven_stage_core64();

parameter RESET_PC        = 0;
parameter DATA_WIDTH      = 64;
parameter NUM_BYTES       = DATA_WIDTH/8;
parameter ADDRESS_BITS    = 64;

task print_state;
  integer x;
  begin
    $display("Time:\t%0d", $time);
    for( x=0; x<32; x=x+1) begin
      $display("Register %d: %h", x, `CORE_REGISTER_FILE[x]);
    end
    $display("--------------------------------------------------------------------------------");
    $display("\n\n");
  end
endtask

integer x;

reg  clock;
reg  reset;
reg  start;
reg  [ADDRESS_BITS-1:0] program_address;
//memory interface
reg  fetch_valid;
reg  fetch_ready;
reg  [DATA_WIDTH-1  :0] fetch_data_in;
reg  [ADDRESS_BITS-1:0] fetch_address_in;
reg  memory_valid;
reg  memory_ready;
reg  [DATA_WIDTH-1  :0] memory_data_in;
reg  [ADDRESS_BITS-1:0] memory_address_in;
wire fetch_read;
wire [ADDRESS_BITS-1:0] fetch_address_out;
wire memory_read;
wire memory_write;
wire [NUM_BYTES-1:   0] memory_byte_en;
wire [ADDRESS_BITS-1:0] memory_address_out;
wire [DATA_WIDTH-1  :0] memory_data_out;
//scan signal
reg  scan;


//instantiate single_cycle_top
seven_stage_core #(
  .RESET_PC(RESET_PC),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) DUT (
  .clock(clock),
  .reset(reset),
  .start(start),
  .program_address(program_address),
  //memory interface
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .fetch_data_in(fetch_data_in),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  .fetch_read(fetch_read),
  .fetch_address_out(fetch_address_out),
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address_out(memory_address_out),
  .memory_data_out(memory_data_out),
  //scan signal
  .scan(scan)
);

initial begin
  for(x=0; x<32; x=x+1) begin
    `CORE_REGISTER_FILE[x] = 32'd0;
  end
end

// generate clock signal
always #1 clock = ~clock;

initial begin
  clock <= 1;
  reset <= 1;
  start <= 0;
  program_address   <= 0;
  fetch_valid       <= 0;
  fetch_ready       <= 0;
  fetch_data_in     <= 0;
  fetch_address_in  <= 0;
  memory_valid      <= 0;
  memory_ready      <= 0;
  memory_address_in <= 0;
  memory_data_in    <= 0;
  scan              <= 0;

  repeat(2) @(posedge clock);
  @(posedge clock) reset <= 0;
  //@(posedge clock) start <= 1;
  //@(posedge clock) start <= 0;
  //repeat(1) @(posedge clock);
  @(posedge clock)begin
    start <= 0;
    fetch_ready  <= 1;
    fetch_valid  <= 1;
    memory_ready <= 1;
    memory_valid <= 1;
    fetch_data_in <= 32'h00000013;
  end

  wait(fetch_read & fetch_address_out == 4);
  fetch_data_in <= {32'h00000013, 32'h00000013};
  wait(fetch_read & fetch_address_out == 20);
  fetch_data_in <={32'b000000000010_00000_000_01100_0010011, 32'b000000000001_00000_000_01011_0010011}; // addi a1, zero, 1;
  wait(fetch_read & fetch_address_out == 24);
  fetch_data_in <={32'b000000000010_00000_000_01100_0010011, 32'b000000000001_00000_000_01011_0010011}; // addi a2, zero, 2
  wait(fetch_read & fetch_address_out == 28);
  fetch_data_in <= {32'b000000000110_00000_000_01110_0010011, 32'b000000000101_00000_000_01101_0010011}; // addi a3, zero, 5
  wait(fetch_read & fetch_address_out == 32);
  fetch_data_in <= {32'b000000000110_00000_000_01110_0010011, 32'b000000000101_00000_000_01101_0010011}; // addi a4, zero, 6
  wait(fetch_read & fetch_address_out == 36);
  fetch_data_in <= {32'h00000013, 32'b111111111111_00000_000_01111_0010011}; // addi a5, zero, -1
  wait(fetch_read & fetch_address_out == 40);
  fetch_data_in <= {32'h00000013, 32'h00000013};
  repeat(1) @(posedge clock);
  print_state();


  wait(fetch_read & fetch_address_out == 60);
  fetch_data_in <= 32'b0000000_01100_01011_000_10000_0110011; // add a6, a1, a2
  $display("add a6, a1, a2");


  wait(fetch_read & fetch_address_out == 80);
  if(`CORE_REGISTER_FILE[16] != 0)begin
    $display("\ntb_seven_stage_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  wait(fetch_read & fetch_address_out == 84);
  if(`CORE_REGISTER_FILE[16] != 3)begin
    $display("\ntb_seven_stage_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end

  #100;
  print_state();
  $display("\ntb_seven_stage_core --> Test Passed!\n\n");
  $stop;

end

always @(posedge clock) fetch_address_in = fetch_address_out;

initial begin
  #500;
  $display("\nError: Timeout");
  $display("\ntb_seven_stage_core --> Test Failed!\n\n");
  $stop;
end


endmodule
