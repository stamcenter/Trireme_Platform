/** @module : execution_unit
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

// 32-bit Exection
module execution_unit #(
  parameter CORE            = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input [5:0] ALU_operation,
  input [ADDRESS_BITS-1:0] PC,
  input [1:0] operand_A_sel,
  input operand_B_sel,
  input branch_op,
  input [DATA_WIDTH-1:0] rs1_data,
  input [DATA_WIDTH-1:0] rs2_data,
  input [DATA_WIDTH-1:0] extend,

  output branch,
  output [DATA_WIDTH-1:0] ALU_result,
  output [ADDRESS_BITS-1:0] JALR_target,

  input scan

);

wire [DATA_WIDTH-1:0]  operand_A;
wire [DATA_WIDTH-1:0]  operand_B;

assign operand_A  =  (operand_A_sel == 2'b01) ? PC       :
                     (operand_A_sel == 2'b10) ? (PC + 4) :
                     (operand_A_sel == 2'b11) ? 0        :
                     rs1_data;

assign operand_B  =  operand_B_sel ? extend : rs2_data;

assign branch     = (ALU_result == {{DATA_WIDTH-1{1'b0}}, 1'b1} & branch_op);

/* Only JALR Target. JAL happens in the decode unit*/
assign JALR_target = {rs1_data + extend} & {{DATA_WIDTH-1{1'b1}}, 1'b0};

ALU #(
  .DATA_WIDTH(DATA_WIDTH)
) EU (
  .ALU_operation(ALU_operation),
  .operand_A(operand_A),
  .operand_B(operand_B),
  .ALU_result(ALU_result)
);

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Execute Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| ALU_Operation [%b]", ALU_operation);
    $display ("| operand_A     [%h]", operand_A);
    $display ("| operand_B     [%h]", operand_B);
    $display ("| Branch        [%b]", branch);
    $display ("| ALU_result    [%h]", ALU_result);
    $display ("| JALR_taget    [%h]", JALR_target);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
