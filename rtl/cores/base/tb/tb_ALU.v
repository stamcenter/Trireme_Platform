/** @module : tb_ALU
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

module tb_ALU();

parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

reg clock;
reg [5:0] ALU_operation;
reg [31:0] operand_A;
reg [31:0] operand_B;
wire [31:0] ALU_result;

// Not in ALU module
reg scan;
reg [31:0] cycles;

ALU DUT (
  .ALU_operation(ALU_operation),
  .operand_A(operand_A),
  .operand_B(operand_B),
  .ALU_result(ALU_result)
);

// Clock generator
always #1 clock = ~clock;

initial begin
  clock  = 0;
  scan   = 0;
  cycles = 0;

  repeat (1) @ (posedge clock);

  operand_A     <= 32'h0000_0002;
  operand_B     <= 32'h0000_0004;
  ALU_operation <= 6'd14; // Subtraction
  repeat (1) @ (posedge clock);

  if( ALU_result !== 32'hfffffffe) begin
    $display("\nError: Subtraction operation failed!");
    $display("\ntb_ALU --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 32'h0000_0002;
  operand_B     <= 32'h0000_0004;
  ALU_operation <= 6'd9; // Bitwise OR
  repeat (1) @ (posedge clock);

  if( ALU_result !== 32'h00000006) begin
    $display("\nError: Bitwise OR operation failed!");
    $display("\ntb_ALU --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 32'h0000_000A;
  operand_B     <= 32'h0000_0003;
  ALU_operation <= 6'd13; // Arithemtic Right Shift
  repeat (1) @ (posedge clock);

  if( ALU_result !== 32'h00000001) begin
    $display("\nError: Arithmatic Shift Right  operation failed!");
    $display("\ntb_ALU --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 32'h0000_0002;
  operand_B     <= 32'hffff_ffff;
  ALU_operation <= 6'd4; // Signed Less Than
  repeat (1) @ (posedge clock);

  if( ALU_result !== 32'h00000000) begin
    $display("\nError: Signed Less Than operation failed!");
    $display("\ntb_ALU --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 32'hffff_ffff;
  operand_B     <= 32'h0000_0004;
  ALU_operation <= 6'd7; // Unsigned Greather Than or Equal
  repeat (1) @ (posedge clock);

  if( ALU_result !== 32'h00000001) begin
    $display("\nError: Unsigned Greater Than or Equal operation failed!");
    $display("\ntb_ALU --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_ALU --> Test Passed!\n\n");
  $stop();
end

// Scan reporting logic is in test bench because no clock is fed to ALU module.
always @ (posedge clock) begin
  cycles <= cycles+1;
  if(scan & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) ) begin
    $display ("ALU_operation [%b], operand_A [%d] operand_B [%d]", ALU_operation, operand_A, operand_B);
    $display ("ALU_result [%d] ",ALU_result);
  end
end


endmodule
