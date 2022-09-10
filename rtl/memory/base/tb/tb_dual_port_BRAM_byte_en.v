/** @module : tb_dual_port_BRAM_byte_en
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

module tb_dual_port_BRAM_byte_en();

parameter CORE = 0;
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 8;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;
parameter NUM_BYTES = DATA_WIDTH/8;

reg  clock;
reg  reset;

// Port 1
reg  readEnable_1;
reg  writeEnable_1;
reg  [DATA_WIDTH/8-1:0] writeByteEnable_1;
reg  [ADDR_WIDTH-1:0] address_1;
reg  [DATA_WIDTH-1:0] writeData_1;
wire [DATA_WIDTH-1:0] readData_1;

// Port 2
reg  readEnable_2;
reg  writeEnable_2;
reg  [DATA_WIDTH/8-1:0] writeByteEnable_2;
reg  [ADDR_WIDTH-1:0] address_2;
reg  [DATA_WIDTH-1:0] writeData_2;
wire [DATA_WIDTH-1:0] readData_2;

reg scan;

dual_port_BRAM_byte_en #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) uut (
  .clock(clock),
  .reset(reset),

  // Port
  .readEnable_1(readEnable_1),
  .writeEnable_1(writeEnable_1),
  .writeByteEnable_1(writeByteEnable_1),
  .address_1(address_1),
  .writeData_1(writeData_1),
  .readData_1(readData_1),

  // Port 2
  .readEnable_2(readEnable_2),
  .writeEnable_2(writeEnable_2),
  .writeByteEnable_2(writeByteEnable_2),
  .address_2(address_2),
  .writeData_2(writeData_2),
  .readData_2(readData_2),

  .scan(scan)

);

always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;
  readEnable_1 = 1'b0;
  writeEnable_1 = 1'b0;
  writeByteEnable_1 = 4'b1111;
  address_1 = 0;
  writeData_1 = 0;
  readEnable_2 = 1'b0;
  writeEnable_2 = 1'b0;
  writeByteEnable_2 = 4'b1111;
  address_2 = 0;
  writeData_2 = 0;
  scan = 0;

  repeat (1) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);
  writeEnable_1 = 1'b1;
  address_1     = 0;
  writeData_1   = 10;
  writeEnable_2 = 1'b1;
  address_2     = 1;
  writeData_2   = 11;

  repeat (1) @ (posedge clock);
  #1 // Delay to ensure readData is checked after it is latched on the posedge clock
  if( readData_1 != 0 |
      readData_2 != 0 ) begin
    $display("\nError: Unexpected read data during write!");
    $display("\ntb_dual_port_BRAM_byte_en --> Test Failed!\n\n");
    $stop();
  end

  writeEnable_1 = 1'b0;
  readEnable_1  = 1'b1;
  writeEnable_2 = 1'b0;
  readEnable_2  = 1'b1;

  repeat (1) @ (posedge clock);
  #1 // Delay to ensure readData is checked after it is latched on the posedge clock
  if( readData_1 != 10 |
      readData_2 != 11 ) begin
    $display("\nError: Unexpected read data during read!");
    $display("\ntb_dual_port_BRAM_byte_en --> Test Failed!\n\n");
    $stop();
  end
  readEnable_1 = 1'b1;
  writeEnable_1 = 1'b1;
  address_1 = 0;
  writeData_1 = 0;
  readEnable_2 = 1'b1;
  writeEnable_2 = 1'b1;
  address_2 = 1;
  writeData_2 = 0;

  repeat (1) @ (posedge clock);

  readEnable_1 = 1'b1;
  writeEnable_1 = 1'b1;
  writeByteEnable_1 = 4'b1100;
  address_1 = 0;
  writeData_1 = 32'hCCCCBBBB;
  readEnable_2 = 1'b1;
  writeEnable_2 = 1'b1;
  writeByteEnable_2 = 4'b0011;
  address_2 = 1;
  writeData_2 = 32'hDDDDEEEE;

  repeat (1) @ (posedge clock);
  #1 // Delay to ensure readData is checked after it is latched on the posedge clock
  if( readData_1 != 32'hCCCC0000 |
      readData_2 != 32'h0000EEEE ) begin
    $display("\nError: Unexpected read data during byte write 1!");
    $display("rd1: %h\nrd2: %h", readData_1, readData_2);
    $display("\ntb_dual_port_BRAM_byte_en --> Test Failed!\n\n");
    $stop();
  end

  readEnable_1 = 1'b1;
  writeEnable_1 = 1'b1;
  writeByteEnable_1 = 4'b0011;
  address_1 = 0;
  writeData_1 = 32'hBBBBCCCC;
  readEnable_2 = 1'b1;
  writeEnable_2 = 1'b1;
  writeByteEnable_2 = 4'b1100;
  address_2 = 1;
  writeData_2 = 32'hEEEEDDDD;

  repeat (1) @ (posedge clock);
  #1 // Delay to ensure readData is checked after it is latched on the posedge clock
  if( readData_1 != 32'hCCCCCCCC |
      readData_2 != 32'hEEEEEEEE ) begin
    $display("\nError: Unexpected read data during byte write 2!");
    $display("rd1: %h\nrd2: %h", readData_1, readData_2);
    $display("\ntb_dual_port_BRAM_byte_en --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_dual_port_BRAM_byte_en --> Test Passed!\n\n");
  $stop();

end

endmodule
