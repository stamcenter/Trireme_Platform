/** @module : tb_dual_port_RAM
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

module tb_dual_port_RAM();

parameter DATA_WIDTH    = 8,
          ADDRESS_WIDTH = 4,
          INDEX_BITS    = 4;

reg clock;
reg writeEnable_0, writeEnable_1;
reg  [DATA_WIDTH-1:0]    writeData_0;
reg  [DATA_WIDTH-1:0]    writeData_1;
reg  [ADDRESS_WIDTH-1:0] address_0;
reg  [ADDRESS_WIDTH-1:0] address_1;
wire [DATA_WIDTH-1:0] data_out0_old, data_out0_new;
wire [DATA_WIDTH-1:0] data_out1_old, data_out1_new;

//instantiate DUT
dual_port_RAM #(
  DATA_WIDTH,
  ADDRESS_WIDTH,
  INDEX_BITS,
  "OLD_DATA"
) DUT_OLD (
.clock(clock),
.writeEnable_0(writeEnable_0), .writeEnable_1(writeEnable_1),
.writeData_0(writeData_0),
.writeData_1(writeData_1),
.address_0(address_0),
.address_1(address_1),
.readData_0(data_out0_old),
.readData_1(data_out1_old)
);

dual_port_RAM #(
  DATA_WIDTH,
  ADDRESS_WIDTH,
  INDEX_BITS,
  "NEW_DATA"
) DUT_NEW (
.clock(clock),
.writeEnable_0(writeEnable_0), .writeEnable_1(writeEnable_1),
.writeData_0(writeData_0),
.writeData_1(writeData_1),
.address_0(address_0),
.address_1(address_1),
.readData_0(data_out0_new),
.readData_1(data_out1_new)
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
    writeEnable_0      <= 1;
    writeData_0 <= 8'h49;
    address_0 <= 14;
  end
  //pass through behavior
  @(posedge clock)begin
    writeEnable_0      <= 0;
	  writeData_0 <= 0;
	  address_0 <= 14;
	  writeEnable_1      <= 1;
    writeData_1 <= 8'h53;
	  address_1 <= 14;
  end
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
  if(data_out0_old != 8'h49 || data_out0_new != 8'h49)begin
    $display("Cycle count = %d", cycles);
    $display("\ntb_dual_port_RAM --> Test Failed!\n\n");
    $stop;
  end
  repeat(1) @(posedge clock);
  if(data_out0_old != 8'h49 || data_out0_new != 8'h53 || data_out1_old != 8'h53 ||
  data_out1_new != 8'h53)begin
    $display("Cycle count = %d", cycles);
    $display("\ntb_dual_port_RAM --> Test Failed!\n\n");
    $stop;
  end
  repeat(1) @(posedge clock);
  if(data_out0_old != 8'h53 || data_out0_new != 8'h53 || data_out1_old != 8'h53 ||
  data_out1_new != 8'h53)begin
    $display("Cycle count = %d", cycles);
    $display("\ntb_dual_port_RAM --> Test Failed!\n\n");
    $stop;
  end

  repeat(1) @(posedge clock);
  $display("\ntb_dual_port_RAM --> Test Passed!\n\n");
  $stop;

end

endmodule
