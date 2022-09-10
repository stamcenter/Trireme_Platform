/** @module : tb_priority_encoder
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

module tb_priority_encoder();

task print_state_a;
  begin
    $display("Priority Encoder A, WIDTH=%d", WIDTH_A);
    $display("Signal to encode            :%b", decode_a);
    $display("Encoded value (LSB priority):%0d", encode_lsb_a);
    $display("Valid (LSB priority)        :%b", valid_lsb_a);
    $display("Encoded value (MSB priority):%0d", encode_msb_a);
    $display("Valid (MSB priority)        :%b", valid_msb_a);
  end
endtask

task print_state_b;
  begin
    $display("Priority Encoder B, WIDTH=%d", WIDTH_B);
    $display("Signal to encode            :%b", decode_b);
    $display("Encoded value (LSB priority):%0d", encode_lsb_b);
    $display("Valid (LSB priority)        :%b", valid_lsb_b);
    $display("Encoded value (MSB priority):%0d", encode_msb_b);
    $display("Valid (MSB priority)        :%b", valid_msb_b);
  end
endtask


parameter WIDTH_A = 8;
parameter WIDTH_B = 5;

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value>>1;
  end
endfunction

reg [WIDTH_A-1 : 0] decode_a;
wire [log2(WIDTH_A)-1 : 0] encode_lsb_a, encode_msb_a;
wire valid_lsb_a, valid_msb_a;

reg [WIDTH_B-1 : 0] decode_b;
wire [log2(WIDTH_B)-1 : 0] encode_lsb_b, encode_msb_b;
wire valid_lsb_b, valid_msb_b;

// instantiate priority encoders
priority_encoder #(WIDTH_A, "LSB") lsb_encoder_a (decode_a, encode_lsb_a, valid_lsb_a);
priority_encoder #(WIDTH_A, "MSB") msb_encoder_a (decode_a, encode_msb_a, valid_msb_a);
priority_encoder #(WIDTH_B, "LSB") lsb_encoder_b (decode_b, encode_lsb_b, valid_lsb_b);
priority_encoder #(WIDTH_B, "MSB") msb_encoder_b (decode_b, encode_msb_b, valid_msb_b);

initial
begin
decode_a = 8'b01101010;
#1;
if(encode_lsb_a !== 3'd1 | encode_msb_a !== 3'd6)begin
  $display("\nTest 1 Error!");
  print_state_a();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end
#10;
decode_a = 8'b00011100;
#1;
if(encode_lsb_a !== 3'd2 | encode_msb_a !== 3'd4)begin
  $display("\nTest 2 Error!");
  print_state_a();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end
#10;
decode_a = 8'b00001000;
#1;
if(encode_lsb_a !== 3'd3 | encode_msb_a !== 3'd3)begin
  $display("\nTest 3 Error!");
  print_state_a();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end
#10;
decode_a = 8'b10000001;
#1;
if(encode_lsb_a !== 3'd0 | encode_msb_a !== 3'd7 | ~valid_lsb_a)begin
  $display("\nTest 4 Error!");
  print_state_a();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end
#10;
decode_a = 8'b00000000;
#1;
if(encode_lsb_a !== 3'd0 | encode_msb_a !== 3'd0 | valid_msb_a | valid_lsb_a)begin
  $display("\nTest 5 Error!");
  print_state_a();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end
#10;
decode_a = 8'b10000000;
#1;
if(encode_lsb_a !== 3'd7 | encode_msb_a !== 3'd7)begin
  $display("\nTest 6 Error!");
  print_state_a();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end
#10;
decode_a = 8'b01010000;
#1;
if(encode_lsb_a !== 3'd4 | encode_msb_a !== 3'd6)begin
  $display("\nTest 7 Error!");
  print_state_a();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end

// Test Encoder B
#10;
decode_b = 5'b01010;
#1;
if(encode_lsb_b !== 3'd1 | encode_msb_b !== 3'd3)begin
  $display("\nTest 8 Error!");
  print_state_b();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end

#10;
decode_b = 5'b11111;
#1;
if(encode_lsb_b !== 3'd0 | encode_msb_b !== 3'd4)begin
  $display("\nTest 9 Error!");
  print_state_b();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end

#10;
decode_b = 5'b11000;
#1;
if(encode_lsb_b !== 3'd3 | encode_msb_b !== 3'd4)begin
  $display("\nTest 10 Error!");
  print_state_b();
  $display("\ntb_priority_encoder --> Test Failed!\n\n");
  $stop;
end


$display("\ntb_priority_encoder --> Test Passed!\n\n");
$stop;

end

endmodule
