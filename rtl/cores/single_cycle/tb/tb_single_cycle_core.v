/** @module : tb_single_cycle_core
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

module tb_single_cycle_core();

parameter RESET_PC        = 0;
parameter DATA_WIDTH      = 32;
parameter ADDRESS_BITS    = 32;
parameter NUM_BYTES       = DATA_WIDTH/8;

task print_state;
  integer x;
  begin
    $display("Time:\t%0d", $time);
    for( x=0; x<32; x=x+1) begin
      $display("Register %d: %h", x, DUT.ID.registers.register_file[x]);
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
wire [NUM_BYTES-1   :0] memory_byte_en;
wire [ADDRESS_BITS-1:0] memory_address_out;
wire [DATA_WIDTH-1  :0] memory_data_out;
//scan signal
reg  scan;


//instantiate single_cycle_top
single_cycle_core #(
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

// generate clock signal
always #1 clock = ~clock;

initial begin
  for(x=0; x<32; x=x+1)
    DUT.ID.registers.register_file[x] = 0;
end

initial begin
  clock <= 0;
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
  @(posedge clock) start <= 1;
  @(posedge clock) start <= 0;
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    fetch_ready  <= 1;
    fetch_valid  <= 1;
    memory_ready <= 1;
    memory_valid <= 1;
  end

  wait(fetch_read & fetch_address_out == 0);
  fetch_data_in    <= 32'h00000013;
  fetch_address_in <= 0;
  wait(fetch_read & fetch_address_out == 4);
  fetch_data_in    <= 32'h00000013;
  fetch_address_in <= 4;
  wait(fetch_read & fetch_address_out == 8);
  fetch_data_in    <= 32'h00000013;
  fetch_address_in <= 8;
  wait(fetch_read & fetch_address_out == 12);
  fetch_data_in    <= 32'h00000013;
  fetch_address_in <= 12;
  wait(fetch_read & fetch_address_out == 16);
  fetch_data_in    <= 32'h00000013;
  fetch_address_in <= 16;

  wait(fetch_read & fetch_address_out == 20);
  fetch_data_in <= 32'b000000000001_00000_000_01011_0010011; // addi a1, zero, 1;
  fetch_address_in <= 20;
  wait(fetch_read & fetch_address_out == 24);
  fetch_data_in <= 32'b000000000010_00000_000_01100_0010011; // addi a2, zero, 2
  fetch_address_in <= 24;
  wait(fetch_read & fetch_address_out == 28);
  fetch_data_in <= 32'b000000000101_00000_000_01101_0010011; // addi a3, zero, 5
  fetch_address_in <= 28;
  wait(fetch_read & fetch_address_out == 32);
  fetch_data_in <= 32'b000000000110_00000_000_01110_0010011; // addi a4, zero, 6
  fetch_address_in <= 32;
  wait(fetch_read & fetch_address_out == 36);
  fetch_data_in <= 32'b111111111111_00000_000_01111_0010011; // addi a5, zero, -1
  fetch_address_in <= 36;
  wait(fetch_read & fetch_address_out == 40);
  fetch_data_in <= 32'h00000013;
  fetch_address_in <= 40;
  print_state();

  wait(fetch_read & fetch_address_out == 44);
  fetch_data_in <= 32'h00000013;
  fetch_address_in <= 44;
  wait(fetch_read & fetch_address_out == 48);
  fetch_data_in <= 32'h00000013;
  fetch_address_in <= 48;
  wait(fetch_read & fetch_address_out == 52);
  fetch_data_in <= 32'h00000013;
  fetch_address_in <= 52;
  wait(fetch_read & fetch_address_out == 56);
  fetch_data_in <= 32'h00000013;
  fetch_address_in <= 56;

  wait(fetch_read & fetch_address_out == 60);
  fetch_data_in <= 32'b0000000_01100_01011_000_10000_0110011; // add a6, a1, a2
  fetch_address_in <= 60;
  $display("add a6, a1, a2");

  wait(fetch_read & fetch_address_out == 64);
  if(DUT.ID.registers.register_file[16] != 3)begin
    $display("\ntb_single_cycle_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  fetch_data_in <= 32'b0100000_01110_01100_000_10001_0110011; // sub a7, a2, a4
  fetch_address_in <= 64;
  $display("sub a7, a2, a4");

  wait(fetch_read & fetch_address_out == 68);
  if(DUT.ID.registers.register_file[17] != -4)begin
    $display("\ntb_single_cycle_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  fetch_data_in <= 32'b0000000_01111_01011_100_01110_0110011; // xor a4, a1, a5
  fetch_address_in <= 68;
  $display("xor a4, a1, a5");

  wait(fetch_read & fetch_address_out == 72);
  if(DUT.ID.registers.register_file[14] != 32'hfffffffe)begin
    $display("\ntb_single_cycle_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  fetch_data_in <= 32'b011000000000_00000_000_01011_0010011; // addi a1, zero, 1536
  fetch_address_in <= 72;
  $display("addi a1, zero, 1536");

  wait(fetch_read & fetch_address_out == 76);
  if(DUT.ID.registers.register_file[11] != 1536)begin
    $display("\ntb_single_cycle_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  fetch_data_in <= 32'b0000000_01100_01011_010_00000_0100011; // sw a2, 0(a1);
  fetch_address_in <= 76;
  $display("sw a2, 0(a1)");

  wait(memory_write & memory_address_out == 1536);

  wait(fetch_read & fetch_address_out == 80);
  fetch_data_in <= 32'b000000000000_01011_010_10010_0000011; // lw s2, 0(a1);
  fetch_address_in <= 80;
  $display("lw s2, 0(a1)");

  wait(memory_read & memory_address_out == 1536);
  memory_address_in <= 1536;
  memory_data_in    <= 32'h12345678;

  wait(fetch_read & fetch_address_out == 84);
  if(DUT.ID.registers.register_file[18] != 32'h12345678)begin
    $display("\ntb_single_cycle_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  fetch_data_in <= 32'h00000013;
  fetch_address_in <= 84;

  //test stalls
  wait(fetch_read & fetch_address_out == 88);
  fetch_valid <= 0;
  repeat(5) @(posedge clock);
  if(DUT.FI.PC_reg != 88 )begin
    $display("\ntb_single_cycle_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  @(posedge clock)begin
    fetch_valid   <= 1;
    fetch_data_in <= 32'b0000000_01011_01101_111_01101_0110011; // and a3, a3, a1
    fetch_address_in <= 88;
    $display("and a3, a3, a1");
  end
  repeat(1) @(posedge clock);
  wait(fetch_read & fetch_address_out == 92);
  if(DUT.ID.registers.register_file[13] != 0)begin
    $display("\ntb_single_cycle_core --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  fetch_data_in <= 32'h00000013;
  fetch_address_in <= 92;


  #10;
  print_state();
  $display("\ntb_single_cycle_core --> Test Passed!\n\n");
  $stop;

end

//always #1 fetch_address_in = fetch_address_out;


initial begin
  #500;
  $display("\nError: Timeout");
  $display("\ntb_single_cycle_core --> Test Failed!\n\n");
  $stop;
end


endmodule
