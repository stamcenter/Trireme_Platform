/** @module : tb_regFile
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

module tb_regFile();

reg clock;
reg reset;
reg wEn;
reg [31:0] write_data;
reg [4:0] read_sel1;
reg [4:0] read_sel2;
reg [4:0] write_sel;

wire [31:0] read_data1;
wire [31:0] read_data2;

regFile uut (
  .clock(clock),
  .reset(reset),
  .wEn(wEn), // Write Enable
  .write_data(write_data),
  .read_sel1(read_sel1),
  .read_sel2(read_sel2),
  .write_sel(write_sel),
  .read_data1(read_data1),
  .read_data2(read_data2)
);


always #5 clock = ~clock;

integer data;
integer addr;

initial begin
  clock = 1'b1;
  reset = 1'b1;
  wEn = 1'b0;
  write_data = 32'h00000000;
  read_sel1 = 5'd0;
  read_sel2 = 5'd1;
  write_sel = 5'd0;

  #1
  #20
  reset = 1'b0;
  #10
  // Write data to each register
  data = 31;
  for(addr=0; addr<32; addr= addr+1) begin
    wEn = 1'b1;
    write_sel = addr;
    write_data = data;
    #10
    data = data - 1;
  end
  wEn = 1'b0;
  #10
  // Check write data
  data = 30;
  for(addr=1; addr<32; addr= addr+1) begin
    if(uut.register_file[addr] != data) begin
      $display("\nError: unexpected data in register file!");
      $display("\ntb_regFile --> Test Failed!\n\n");
      $stop();
    end
    data = data - 1;
  end

  #10
  // Read data from each register
  data = 30;
  for(addr=1; addr<32; addr= addr+1) begin
    read_sel1 = addr;
    read_sel2 = addr;
    #10
    if(read_data1 != data) begin
      $display("\nError: unexpected data from read_data1!");
      $display("\ntb_regFile --> Test Failed!\n\n");
      $stop();
    end
    if(read_data2 != data) begin
      $display("\nError: unexpected data from read_data2!");
      $display("\ntb_regFile --> Test Failed!\n\n");
      $stop();
    end
    data = data - 1;
  end

  read_sel1 =0;
  #10

  // Check that register 0 is always 0x00000000
  if(read_data1 != 0) begin
      $display("\nError: Register 0 is not 0x00000000!");
      $display("\ntb_regFile --> Test Failed!\n\n");
      $stop();
  end

  #10

  read_sel1 = 1;
  write_sel = 1;
  write_data = 32'hffffffff;
  wEn = 1'b1;

  #1 // small delay before clock edge

  // read during write check - make sure old data is read
  if(read_data1 != 30) begin
    $display("\nError: Did not read old data with read during write!");
    $display("\ntb_regFile --> Test Failed!\n\n");
    $stop();

  end
  #9
  wEn = 1'b0;
  #10

  $display("\ntb_regFile --> Test Passed!\n\n");
  $stop();
end

endmodule
