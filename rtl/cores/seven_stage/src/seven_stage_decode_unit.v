/** @module : seven_stage_decode_unit
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

module seven_stage_decode_unit #(
  parameter CORE            = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 20,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  // Base Decode Signals
  input  clock,
  input  reset,

  input  [ADDRESS_BITS-1:0] PC,
  input  [31:0] instruction,
  input  [1:0] extend_sel,
  input  write,
  input  [4:0]  write_reg,
  input  [DATA_WIDTH-1:0] write_data,

  output [DATA_WIDTH-1:0] rs1_data,
  output [DATA_WIDTH-1:0] rs2_data,
  output [4:0]  rd,
  output [6:0]  opcode,
  output [6:0]  funct7,
  output [2:0]  funct3,
  output [DATA_WIDTH-1:0] extend_imm,
  output [ADDRESS_BITS-1:0] branch_target,
  output [ADDRESS_BITS-1:0] JAL_target,

  // Data Bypassing Signals
  input [2:0] rs1_data_bypass,
  input [2:0] rs2_data_bypass,
  input [DATA_WIDTH-1:0] ALU_result_execute,
  input [DATA_WIDTH-1:0] ALU_result_memory_issue,
  input [DATA_WIDTH-1:0] ALU_result_memory_receive,
  input [DATA_WIDTH-1:0] ALU_result_writeback,

  input scan

);

wire [DATA_WIDTH-1:0] rs1_data_decode;
wire [DATA_WIDTH-1:0] rs2_data_decode;

// Select signal for data bypassing
assign rs1_data = (rs1_data_bypass == 3'b000)? rs1_data_decode           :
                  (rs1_data_bypass == 3'b001)? ALU_result_execute        :
                  (rs1_data_bypass == 3'b010)? ALU_result_memory_issue   :
                  (rs1_data_bypass == 3'b011)? ALU_result_memory_receive :
                  (rs1_data_bypass == 3'b100)? ALU_result_writeback      :
                  {DATA_WIDTH{1'b0}};

assign rs2_data = (rs2_data_bypass == 3'b000)? rs2_data_decode           :
                  (rs2_data_bypass == 3'b001)? ALU_result_execute        :
                  (rs2_data_bypass == 3'b010)? ALU_result_memory_issue   :
                  (rs2_data_bypass == 3'b011)? ALU_result_memory_receive :
                  (rs2_data_bypass == 3'b100)? ALU_result_writeback      :
                  {DATA_WIDTH{1'b0}};

decode_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) base_decode (
  .clock(clock),
  .reset(reset),

  .PC(PC),
  .instruction(instruction),
  .extend_sel(extend_sel),
  .write(write),
  .write_reg(write_reg),
  .write_data(write_data),

  .rs1_data(rs1_data_decode),
  .rs2_data(rs2_data_decode),
  .rd(rd),
  .opcode(opcode),
  .funct7(funct7),
  .funct3(funct3),
  .extend_imm(extend_imm),
  .branch_target(branch_target),
  .JAL_target(JAL_target),

  .scan(scan)
);

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Seven Stage Decode Unit - Current Cycle %d -------", CORE, cycles);
    $display ("| rs1_data    [%d]", rs1_data);
    $display ("| rs2_data    [%d]", rs2_data);
    $display ("----------------------------------------------------------------------");
  end
end



endmodule
