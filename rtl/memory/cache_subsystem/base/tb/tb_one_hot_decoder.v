/** @module : tb_one_hot_decoder
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
module tb_one_hot_decoder();

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


reg [WIDTH-1:0] one_hot_encoded;
wire [log2(WIDTH)-1 : 0]  decoded;
wire valid;

one_hot_decoder #(WIDTH) DUT (one_hot_encoded, decoded, valid);

initial begin
	one_hot_encoded = 8'b00000001;
#10	one_hot_encoded = 8'b00000010;
#10	one_hot_encoded = 8'b00000100;
#10	one_hot_encoded = 8'b00001000;
#10	one_hot_encoded = 8'b00010000;
#10	one_hot_encoded = 8'b00100000;
#10	one_hot_encoded = 8'b01000000;
#10	one_hot_encoded = 8'b10000000;
#10	one_hot_encoded = 8'b00000000;
#10	one_hot_encoded = 8'b00010000;
end

//automatic test logic
initial begin
  #1;
  if(decoded != 3'd0 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd1 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd2 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd3 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd4 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd5 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd6 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd7 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd0 | valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  if(decoded != 3'd4 | ~valid)begin
    $display("\ntb_one_hot_decoder --> Test Failed!\n\n");
    $stop;
  end

  #10;
  $display("\ntb_one_hot_decoder --> Test Passed!\n\n");
  $finish;

end

endmodule
