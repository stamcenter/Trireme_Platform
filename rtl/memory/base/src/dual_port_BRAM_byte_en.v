/** @module : dual_port_BRAM_byte_en
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

module dual_port_BRAM_byte_en #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 8,
  parameter INIT_FILE_BASE = "",
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input  clock,
  input  reset,

  // Port 1
  input  readEnable_1,
  input  writeEnable_1,
  input  [DATA_WIDTH/8-1:0] writeByteEnable_1,
  input  [ADDR_WIDTH-1:0] address_1,
  input  [DATA_WIDTH-1:0] writeData_1,
  output [DATA_WIDTH-1:0] readData_1,

  // Port 2
  input  readEnable_2,
  input  writeEnable_2,
  input  [DATA_WIDTH/8-1:0] writeByteEnable_2,
  input  [ADDR_WIDTH-1:0] address_2,
  input  [DATA_WIDTH-1:0] writeData_2,
  output [DATA_WIDTH-1:0] readData_2,

  input  scan
);

localparam MEM_DEPTH = 1 << ADDR_WIDTH;
localparam NUM_BYTES = DATA_WIDTH/8;


genvar i;
generate
for(i=0; i<NUM_BYTES; i=i+1) begin : BYTE_LOOP

  if(INIT_FILE_BASE != "") begin : IF_INIT
    // Override the init file parameter by prepending the byte number to the
    // base file name
    dual_port_BRAM #(
      .CORE(CORE),
      .DATA_WIDTH(8),
      .ADDR_WIDTH(ADDR_WIDTH),
      .INIT_FILE({"0"+i,INIT_FILE_BASE}),
      .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
      .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
    ) BRAM_byte (
      .clock(clock),
      .reset(reset),

      // Port
      .readEnable_1(readEnable_1),
      .writeEnable_1(writeEnable_1 & writeByteEnable_1[i]),
      .address_1(address_1),
      .writeData_1(writeData_1[(8*i)+7:8*i]),
      .readData_1(readData_1[(8*i)+7:8*i]),

      // Port 2
      .readEnable_2(readEnable_2),
      .writeEnable_2(writeEnable_2 & writeByteEnable_2[i]),
      .address_2(address_2),
      .writeData_2(writeData_2[(8*i)+7:8*i]),
      .readData_2(readData_2[(8*i)+7:8*i]),

      .scan(scan)
    );
  end
  else begin : ELSE_INIT
    // Do not override the INIT_FILE parameter
    dual_port_BRAM #(
      .CORE(CORE),
      .DATA_WIDTH(8),
      .ADDR_WIDTH(ADDR_WIDTH),
      .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
      .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
    ) BRAM_byte (
      .clock(clock),
      .reset(reset),

      // Port
      .readEnable_1(readEnable_1),
      .writeEnable_1(writeEnable_1 & writeByteEnable_1[i]),
      .address_1(address_1),
      .writeData_1(writeData_1[(8*i)+7:8*i]),
      .readData_1(readData_1[(8*i)+7:8*i]),

      // Port 2
      .readEnable_2(readEnable_2),
      .writeEnable_2(writeEnable_2 & writeByteEnable_2[i]),
      .address_2(address_2),
      .writeData_2(writeData_2[(8*i)+7:8*i]),
      .readData_2(readData_2[(8*i)+7:8*i]),

      .scan(scan)
    );
  end
end


endgenerate

reg [31: 0] cycles;
always @ (negedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan & ((cycles >=  SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)))begin
    $display ("------ Core %d Dual Port BRAM Byte En Unit - Current Cycle %d --------", CORE, cycles);
    $display ("| Read 1       [%b]", readEnable_1);
    $display ("| Write 1      [%b]", writeEnable_1);
    $display ("| Write Byte 1 [%b]", writeByteEnable_1);
    $display ("| Address 1    [%h]", address_1);
    $display ("| Read Data 1  [%h]", readData_1);
    $display ("| Write Data 1 [%h]", writeData_1);
    $display ("| Read 2       [%b]", readEnable_2);
    $display ("| Write 2      [%b]", writeEnable_2);
    $display ("| Write Byte 2 [%b]", writeByteEnable_2);
    $display ("| Address 2    [%h]", address_2);
    $display ("| Read Data 2  [%h]", readData_2);
    $display ("| Write Data 2 [%h]", writeData_2);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
