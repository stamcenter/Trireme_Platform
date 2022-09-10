/** @module : tb_MLU64
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

module tb_MLU64();

parameter DATA_WIDTH      = 64;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

reg clock;
reg reset;
reg [5:0] ALU_operation;
reg [DATA_WIDTH-1:0] operand_A;
reg [DATA_WIDTH-1:0] operand_B;
reg                  ready_i;

wire                  ready_o;
wire [DATA_WIDTH-1:0] MLU_result;
wire                  valid_result;

// Not in ALU module
reg scan;
reg [31:0] cycles;

MLU #(
  .DATA_WIDTH(DATA_WIDTH)
) DUT (
  .clock(clock),
  .reset(reset),
  .ALU_operation(ALU_operation),
  .operand_A(operand_A),
  .operand_B(operand_B),
  .ready_i(ready_i),
  .ready_o(ready_o),
  .MLU_result(MLU_result),
  .valid_result(valid_result)
);

// Clock generator
always #1 clock = ~clock;

initial begin
  clock  = 1'b1;
  reset  = 1'b1;
  scan   = 1'b0;
  cycles = 0;

  ready_i = 1'b1;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  operand_A     <= 64'h0000_0000_0000_0002;
  operand_B     <= 64'h0000_0000_0000_0004;
  ALU_operation <= 6'd20; // Multiplication (lower)
  repeat (1) @ (posedge clock);
  #1
  if( MLU_result !== 64'h00000000_00000008) begin
    $display("\nError: Multiplication (lower) operation failed!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 64'h0000_0000_0000_0001;
  operand_B     <= 64'hffff_ffff_ffff_ffff;
  ALU_operation <= 6'd21; // Signed Multiplication (Upper)
  repeat (1) @ (posedge clock);
  #1
  if( MLU_result !== 64'hffffffff_ffffffff) begin
    $display("\nError: Multiplication (lower) operation failed!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 64'h0000_0000_0000_0001;
  operand_B     <= 64'hffff_ffff_ffff_ffff;
  ALU_operation <= 6'd22; // Unsigned Multiplication (Upper)
  repeat (1) @ (posedge clock);
  #1
  if( MLU_result !== 64'h00000000_00000000) begin
    $display("\nError: Unsigned Multiplication (Upper) operation failed!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 64'hffff_ffff_ffff_fffe; // -2
  operand_B     <= 64'h8000_0000_0000_0000; // 2^63
  ALU_operation <= 6'd23; // S*U Multiplication (Upper)
  repeat (1) @ (posedge clock);
  #1
  if( MLU_result !== 64'hffffffff_ffffffff) begin
    $display("\nError: S*U Multiplication (Upper) operation failed!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 64'h0000_0000_ffff_ffff;
  operand_B     <= 64'h8000_0000_0000_0002;
  ALU_operation <= 6'd28; // Word Multiplication
  repeat (1) @ (posedge clock);
  #1
  if( MLU_result !== 64'hffffffff_fffffffe) begin
    $display("\nError: Word Multiplication operation failed!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  operand_A     <= 64'd29;
  operand_B     <= 64'd10;
  ALU_operation <= 6'd24; // Signed Division

  repeat (1) @ (posedge clock);
  #1
  if( ready_o !== 1'b0) begin
    $display("\nError: MLU should not be ready during Division!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  repeat (65) @ (posedge clock);
  #1
  if( MLU_result   !== 64'd2 |
      valid_result !== 1'b1  ) begin
    $display("\nError: Signed division operation failed!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  repeat (1) @ (posedge clock);

  operand_A     <= 64'd2;
  operand_B     <= 64'h00000000_ffffffff;
  ALU_operation <= 6'd29; // Signed Word Division

  repeat (1) @ (posedge clock);
  #1
  if( ready_o !== 1'b0) begin
    $display("\nError: MLU should not be ready during Division!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  repeat (35) @ (posedge clock);
  #1
  if( MLU_result   !== 64'hffffffff_fffffffe |
      valid_result !== 1'b1  ) begin
    $display("\nError: Signed Word Division operation failed!");
    $display("\ntb_MLU64 --> Test Failed!\n\n");
    $stop();
  end

  repeat (1) @ (posedge clock);

  $display("\ntb_MLU64 --> Test Passed!\n\n");
  $stop();
end


// Scan reporting logic is in test bench because no clock is fed to MLU module.
always @ (posedge clock) begin
  cycles <= cycles+1;
  if(scan & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) ) begin
    $display ("ALU_operation [%d], operand_A [%h] operand_B [%h]", ALU_operation, operand_A, operand_B);
    $display ("MLU_result [%h] ", MLU_result);
    $display ("ss_product [%h] ", DUT.ss_product);
    $display ("uu_product [%h] ", DUT.uu_product);
    $display ("su_product [%h] ", DUT.su_product);
    $display ("ssw_product[%h] ", DUT.ssw_product);
    $display ("ready_i    [%b] ", ready_i);
    $display ("ready_o    [%b] ", ready_o);
    $display ("valid_result[%b] ", valid_result);
    $display ("start_div_s [%b] ", DUT.start_div_s);
    $display ("start_div_u [%b] ", DUT.start_div_u);
    $display ("div state   [%h] ", DUT.SIGNED_DIV.state);
    $display ("divu state  [%h] ", DUT.UNSIGNED_DIV.state);
    $display ("start_divw_s [%b] ", DUT.start_divw_s);
    $display ("start_divw_u [%b] ", DUT.start_divw_u);
    $display ("div state   [%h] ", DUT.XLEN_64.SIGNED_DIVW.state);
    $display ("divu state  [%h] ", DUT.XLEN_64.UNSIGNED_DIVW.state);
    $display ("            [%h] ", DUT.XLEN_64.SIGNED_DIVW.count);
  end
end


endmodule
