/** @module : execution_unit_multi_cycle
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

module execution_unit_multi_cycle #(
  parameter CORE            = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter M_EXTENSION     = "False",
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

  // Signals for multi-cycle OPs
  input ready_i,
  output ready_o,
  output valid_result,

  output branch,
  output [DATA_WIDTH-1:0] ALU_result,
  output [ADDRESS_BITS-1:0] JALR_target,

  input scan

);

wire [DATA_WIDTH-1:0]  operand_A;
wire [DATA_WIDTH-1:0]  operand_B;

wire [DATA_WIDTH-1:0] ALU_output;
wire [DATA_WIDTH-1:0] MLU_output;

assign operand_A  =  (operand_A_sel == 2'b01) ? PC       :
                     (operand_A_sel == 2'b10) ? (PC + 4) :
                     (operand_A_sel == 2'b11) ? 0        :
                     rs1_data;

assign operand_B  =  operand_B_sel ? extend : rs2_data;

execution_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) EXECUTE_BASE (
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
  .ALU_result(ALU_output),
  .JALR_target(JALR_target),

  .scan(scan)

);

generate
  if(M_EXTENSION == "True") begin
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
      .MLU_result(MLU_output),
      .valid_result(valid_result)
    );
    assign ALU_result = (ALU_operation >= 6'd20) & (ALU_operation <= 6'd32) ? MLU_output : ALU_output;
  end
  else begin
    assign ALU_result = ALU_output;
    assign ready_o      = 1'b1;
    assign valid_result = 1'b1;
  end
endgenerate


reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Multi-Cycle Execute Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| ALU_Operation [%b]", ALU_operation);
    $display ("| operand_A     [%h]", operand_A);
    $display ("| operand_B     [%h]", operand_B);
    $display ("| Branch        [%b]", branch);
    $display ("| ALU_result    [%h]", ALU_result);
    $display ("| ALU_output    [%h]", ALU_output);
    $display ("| MLU_output    [%h]", MLU_output);
    $display ("| JALR_taget    [%h]", JALR_target);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
