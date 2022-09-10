/** @module : tb_simple_dual_port_ram
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
module tb_simple_dual_port_ram();

parameter DATA_WIDTH    = 8,
          ADDRESS_WIDTH = 4,
          INDEX_BITS    = 4;

reg clock;
reg writeEnable_0, writeEnable_1;
reg  [DATA_WIDTH-1:0]    writeData_0;
reg  [DATA_WIDTH-1:0]    writeData_1;
reg  [ADDRESS_WIDTH-1:0] address_0;
reg  [ADDRESS_WIDTH-1:0] address_1;
wire [DATA_WIDTH-1:0] readData_0;
wire [DATA_WIDTH-1:0] readData_1;

//instantiate DUT
simple_dual_port_ram #(
  DATA_WIDTH,
  ADDRESS_WIDTH,
  INDEX_BITS
) DUT (
clock,
writeEnable_0, writeEnable_1,
writeData_0,
writeData_1,
address_0,
address_1,
readData_0,
readData_1
);

//generate clock
always #1 clock = ~clock;

//cycle counter
reg [31:0] cycles;
always @(posedge clock)begin
  cycles <= cycles + 1;
end

//Test patterns
initial begin
  clock  = 0;
  cycles = 0;
  writeEnable_0 = 0;
  writeEnable_1 = 0;
  writeData_0 = 0;
  writeData_1 = 0;
  address_0 = 0;
  address_1 = 0;

//write value
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    writeEnable_0     <= 1;
    writeData_0 <= 8'h49;
    address_0 <= 14;
  end
  @(posedge clock)begin
    writeData_0 <= 8'h53;
	  address_0 <= 7;
  end
  //read from both ports
  @(posedge clock)begin
    writeEnable_0      <= 0;
	  writeData_0 <= 0;
	  writeData_1 <= 0;
	  address_0 <= 14;
	  address_1 <= 7;
  end
  //write to same address on both ports
  @(posedge clock)begin
	  writeEnable_0      <= 1;
	  writeEnable_1      <= 1;
	  writeData_0 <= 8'h11;
	  writeData_1 <= 8'h22;
	  address_0 <= 7;
	  address_1 <= 7;
  end
  //read the same address
  @(posedge clock)begin
	  writeEnable_0      <= 0;
	  writeEnable_1      <= 0;
	  writeData_0 <= 0;
	  writeData_1 <= 0;
  end
end

// Automatic checking code
initial begin
  repeat(4) @(posedge clock);
  if(readData_0 != 8'h49 || DUT.ram[14] != 8'h49)begin
    $display("Cycle count = %d", cycles);
    $display("tb_simple_dual_port_ram -> Test Failed!");
    $stop;
  end
  repeat(1) @(posedge clock);
  if(readData_0 != 8'h53 || DUT.ram[7] != 8'h53)begin
    $display("Cycle count = %d", cycles);
    $display("tb_simple_dual_port_ram -> Test Failed!");
    $stop;
  end
  repeat(1) @(posedge clock);
  if(readData_0 != 8'h49 || readData_1 != 8'h53)begin
    $display("Cycle count = %d", cycles);
    $display("tb_simple_dual_port_ram -> Test Failed!");
    $stop;
  end
  repeat(1) @(posedge clock);
  if(readData_0 != 8'h53 || readData_1 != 8'h22 || DUT.ram[7] != 8'h22)begin
    $display("Cycle count = %d", cycles);
    $display("tb_simple_dual_port_ram -> Test Failed!");
    $stop;
  end
  repeat(1) @(posedge clock);
  if(readData_0 != 8'h22)begin
    $display("tb_simple_dual_port_ram -> Test Failed!");
    $display("Cycle count = %d", cycles);
    $stop;
  end
  repeat(1) @(posedge clock);
  $display("\ntb_simple_dual_port_ram --> Test Passed!\n\n");
  $stop;

end

endmodule
