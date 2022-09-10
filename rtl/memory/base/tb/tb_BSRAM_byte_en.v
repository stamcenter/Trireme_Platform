/** @module : tb_BSRAM_byte_en
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

module tb_BSRAM_byte_en();

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 8;

task print_signal_values;
  begin
    $display("Simulation time: %0t", $time);
    $display("Read: %b", readEnable);
    $display("Read address: %h", readAddress);
    $display("Read data: %h", readData);
    $display("Write: %h", writeEnable);
    $display("Write Byte: %h", writeByteEnable);
    $display("Write address: %b", writeAddress);
    $display("Write data: %b", writeData);
  end
endtask


reg  clock;
reg  reset;
reg  readEnable;
reg  [ADDR_WIDTH-1:0] readAddress;
wire [DATA_WIDTH-1:0] readData;

reg [ADDR_WIDTH-1:0] writeAddress;
reg [DATA_WIDTH-1:0] writeData;
reg writeEnable;
reg [DATA_WIDTH/8-1:0] writeByteEnable;

reg scan;

integer i;

BSRAM_byte_en #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH)
) DUT (
  .clock(clock),
  .reset(reset),
  .readEnable(readEnable),
  .readAddress(readAddress),
  .readData(readData),
  .writeEnable(writeEnable),
  .writeByteEnable(writeByteEnable),
  .writeAddress(writeAddress),
  .writeData(writeData),
  .scan(scan)
);

always #5 clock = ~clock;

initial begin
	clock            <= 0;
	reset            <= 1;
	scan             <= 0;
  @(posedge clock)begin
	  readAddress      <= 0;
	  readEnable       <= 0;
  end
  @(posedge clock)begin
	  writeAddress     = 2;
	  writeData        = 32'hAAAA8888;
	  writeEnable      = 1;
    writeByteEnable  = 4'b1111;
  end
  @(posedge clock)begin
	  writeAddress     = 4;
	  writeData        = 32'h11110000;
	  writeEnable      = 1;
    writeByteEnable  = 4'b1111;
  end
  @(posedge clock)begin
	  writeAddress     = 0;
	  writeData        = 0;
	  writeEnable      = 0;
    writeByteEnable  = 4'b0000;
  end

	repeat (1) @ (posedge clock);

  @(posedge clock)begin
    readAddress      = 2;
    readEnable       = 1;
  end
  wait(readData == 32'hAAAA8888);

  @(posedge clock)begin
    writeAddress     = 2;
	  writeData        = 100;
    writeEnable      = 1;
    writeByteEnable  = 4'b0011;
  end
  @(posedge clock)begin
    writeEnable      = 0;
    readAddress      = 2;
    readEnable       = 1;
  end

  wait(readData == 32'hAAAA0064);

  @(posedge clock)begin
	  readAddress      = 4;
    readEnable       = 1;
  end

  wait(readData == 32'h11110000);

  $display("\ntb_BSRAM_byte_en --> Test Passed!\n\n");
  $stop;

end

initial begin
  #100;
  $display("\ntb_BSRAM_byte_en --> Test Failed!\n\n");
  $stop;
end

endmodule

