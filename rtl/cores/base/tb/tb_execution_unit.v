/** @module : tb_execution_unit
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

module tb_execution_unit();

reg clock;
reg reset;
reg [5:0] ALU_operation;
reg [19:0] PC;
reg [1:0] operand_A_sel;
reg operand_B_sel;
reg branch_op;
reg [31:0] rs1_data;
reg [31:0] rs2_data;
reg [31:0] extend;

wire branch;
wire [31:0] ALU_result;
wire [19:0] JALR_target;

reg scan;

execution_unit #(
  .CORE(0),
  .DATA_WIDTH(32),
  .ADDRESS_BITS(20)
) execute (
  .clock(clock),
  .reset(reset),
  .ALU_operation(ALU_operation),
  .PC(PC),
  .operand_A_sel(operand_A_sel),
  .operand_B_sel(operand_B_sel),
  .branch_op(branch_op),
  .rs1_data(rs1_data),
  .rs2_data(rs2_data),
  .extend(extend),

  .branch(branch),
  .ALU_result(ALU_result),
  .JALR_target(JALR_target),

  .scan(scan)

);

// Clock generator
always #1 clock = ~clock;

initial begin
  clock         = 0;
  reset         = 1;
  ALU_operation = 0;
  PC            = 0;
  operand_A_sel = 0;
  operand_B_sel = 0;
  branch_op     = 0;
  rs1_data      = 0;
  rs2_data      = 0;
  extend        = 0;
  scan          = 0;

  #10 reset = 0;
  repeat (1) @ (posedge clock);

  // Logical Shift Right
  ALU_operation <= 6'd12;
  rs1_data      <= 15;
  rs2_data      <= 2;

  repeat (1) @ (posedge clock);

  if( ALU_result !== 32'h00000003) begin
    $display("\nError: Logical Shift Right operation failed!");
    $display("\ntb_execution_unit--> Test Failed!\n\n");
    $stop();
  end

  // Subtraction
  ALU_operation <= 6'd14;
  rs1_data      <= 5;
  rs2_data      <= 7;

  repeat (1) @ (posedge clock);

  if( ALU_result !== 32'hfffffffe) begin
    $display("\nError: Subtraction operation failed!");
    $display("\ntb_execution_unit--> Test Failed!\n\n");
    $stop();
  end

  // Immediate And
  ALU_operation <= 6'd10;
  rs1_data      <= 4;
  rs2_data      <= 7;
  extend        <= 4;
  operand_B_sel <= 1'b1;
  repeat (1) @ (posedge clock);

  if( ALU_result !== 32'h00000004) begin
    $display("\nError: Immediate AND operation failed!");
    $display("\ntb_execution_unit--> Test Failed!\n\n");
    $stop();
  end


  $display("\ntb_execution_unit--> Test Passed!\n\n");
  $stop();

end

endmodule
