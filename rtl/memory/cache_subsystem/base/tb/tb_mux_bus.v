/** @module : tb_mux_bus
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

module tb_mux_bus();

parameter WIDTH     = 8,
          NUM_PORTS = 4;

//Define the log2 function
function integer log2;
   input integer num;
   integer i, result;
   begin
       for (i = 0; 2 ** i < num; i = i + 1)
           result = i + 1;
       log2 = result;
   end
endfunction

reg [WIDTH*NUM_PORTS-1 : 0] data_in;
reg [log2(NUM_PORTS)-1 : 0] enable_port;
reg valid_enable;
wire [WIDTH-1 : 0] data_out;

// Instantiate tristate_bus
mux_bus #(WIDTH, NUM_PORTS)
    DUT(data_in, enable_port, valid_enable, data_out);

initial begin
  data_in      = 32'h89ABCDEF;
  enable_port  = 0;
  valid_enable = 0;
  #100;
  enable_port  = 1;
  valid_enable = 1;
  #50;
  enable_port  = 2;
  #50;
  enable_port  = 3;
  #50;
  enable_port  = 0;
  #50;
  valid_enable = 0;
  #50;
  enable_port  = 3;
  valid_enable = 1;
  
end

//Automatic verification code
initial begin
  #1;
  if(data_out != 8'h00)begin
  $display("\ntb_mux_bus --> Test Failed!\n\n");
  $stop;
  end

  #100;
  if(data_out != 8'hCD)begin
  $display("\ntb_mux_bus --> Test Failed!\n\n");
  $stop;
  end

  #50;
  if(data_out != 8'hAB)begin
  $display("\ntb_mux_bus --> Test Failed!\n\n");
  $stop;
  end

  #50;
  if(data_out != 8'h89)begin
  $display("\ntb_mux_bus --> Test Failed!\n\n");
  $stop;
  end

  #50;
  if(data_out != 8'hEF)begin
  $display("\ntb_mux_bus --> Test Failed!\n\n");
  $stop;
  end

  #50;
  if(data_out != 8'h00)begin
  $display("\ntb_mux_bus --> Test Failed!\n\n");
  $stop;
  end

  #50;
  if(data_out != 8'h89)begin
  $display("\ntb_mux_bus --> Test Failed!\n\n");
  $stop;
  end

  #50;
  $display("\ntb_mux_bus --> Test Passed!\n\n");
  $finish;
end

//Timeout
initial begin
  #500;
  $display("\ntb_mux_bus --> Test Failed!\n\n");
  $finish;
end

endmodule
