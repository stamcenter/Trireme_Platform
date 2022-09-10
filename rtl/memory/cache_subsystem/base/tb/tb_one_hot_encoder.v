/** @moudle : tb_one_hot_encoder
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

module tb_one_hot_encoder();

parameter WIDTH = 8;

//define the log2 function
function integer log2;
  input integer num;
  integer i, result;
  begin
      for (i = 0; 2 ** i < num; i = i + 1)
          result = i + 1;
      log2 = result;
  end
endfunction


reg [log2(WIDTH)-1 : 0] toencode;
reg valid_input;
wire [WIDTH-1 : 0] encoded;
integer error;

// Instantiate the encoder
one_hot_encoder #(WIDTH) DUT (toencode, valid_input, encoded);

initial begin
valid_input = 1;
toencode = 1;
#10 toencode = 2;
#10 toencode = 0;
#10 toencode = 3;
#10 toencode = 4;
#10 toencode = 7;
#10 toencode = 6;
#10 toencode = 5;
end

//Automated testing code
initial begin
  error = 0;
  #5;
  if(encoded != 8'b00000010)
    error = 1;
  #6;
  if(encoded != 8'b00000100)
    error = 1;
  #10;
  if(encoded != 8'b00000001)
    error = 1;
  
  #10;
  if(encoded != 8'b00001000)
    error = 1;
  #10;
  if(encoded != 8'b00010000)
    error = 1;
  #10;
  if(encoded != 8'b10000000)
    error = 1;
  #10;
  if(encoded != 8'b01000000)
    error = 1;
  #10;
  if(encoded != 8'b00100000)
    error = 1;
 
  #10;
  if(error == 0)begin
    $display("\ntb_one_hot_encoder --> Test Passed!\n\n");
    $finish;
  end
  else begin
    $display("\ntb_one_hot_encoder --> Test Failed!\n\n");
    $stop;
  end
end

endmodule
