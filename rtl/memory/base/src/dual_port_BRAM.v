/** @module : dual_port_BRAM
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

module dual_port_BRAM #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 8,
  parameter INIT_FILE  = "",
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input  clock,
  input  reset,

  // Port 1
  input  readEnable_1,
  input  writeEnable_1,
  input  [ADDR_WIDTH-1:0] address_1,
  input  [DATA_WIDTH-1:0] writeData_1,
  output reg [DATA_WIDTH-1:0] readData_1,

  // Port 2
  input  readEnable_2,
  input  writeEnable_2,
  input  [ADDR_WIDTH-1:0] address_2,
  input  [DATA_WIDTH-1:0] writeData_2,
  output reg [DATA_WIDTH-1:0] readData_2,

  input  scan

);

localparam RAM_DEPTH = 1 << ADDR_WIDTH;

reg [DATA_WIDTH-1:0] readData_r_1;
reg [DATA_WIDTH-1:0] readData_r_2;
reg [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];

wire valid_writeEnable_2;

assign valid_writeEnable_2 =  writeEnable_2 & ~(writeEnable_1 & (address_1 == address_2));

initial begin
  if(INIT_FILE != "")
    $readmemh(INIT_FILE, ram);
end

// Port 1
always@(posedge clock) begin
  if(writeEnable_1)
    // Blocking Write to read new data on read during write
    ram[address_1] = writeData_1;
  if(readEnable_1)
    readData_1 <= ram[address_1];

end

// port 2
always@(posedge clock)begin
  if(valid_writeEnable_2)
    // Blocking Write to read new data on read during write
    ram[address_2] = writeData_2;
  if(readEnable_2)
    readData_2 <= ram[address_2];
end

reg [31: 0] cycles;
always @ (negedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan & ((cycles >=  SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)))begin
    $display ("------ Core %d BRAM Unit - Current Cycle %d --------", CORE, cycles);
    $display ("| Read 1       [%b]", readEnable_1);
    $display ("| Write 1      [%b]", writeEnable_1);
    $display ("| Address 1    [%h]", address_1);
    $display ("| Read Data 1  [%h]", readData_1);
    $display ("| Write Data 1 [%h]", writeData_1);
    $display ("| Read 2       [%b]", readEnable_2);
    $display ("| Write 2      [%b]", writeEnable_2);
    $display ("| Valid Write 2[%b]", valid_writeEnable_2);
    $display ("| Address 2    [%h]", address_2);
    $display ("| Read Data 2  [%h]", readData_2);
    $display ("| Write Data 2 [%h]", writeData_2);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
