/** @module : tb_five_stage_decode_unit
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

module tb_five_stage_decode_unit();

parameter CORE            = 0;
parameter DATA_WIDTH      = 32;
parameter ADDRESS_BITS    = 20;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

// Base Decode Signals
reg  clock;
reg  reset;

reg  [ADDRESS_BITS-1:0] PC;
reg  [31:0] instruction;
reg  [1:0] extend_sel;
reg  write;
reg  [4:0]  write_reg;
reg  [31:0] write_data;

wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [4:0]  rd;
wire [6:0]  opcode;
wire [6:0]  funct7;
wire [2:0]  funct3;
wire [31:0] extend_imm;
wire [ADDRESS_BITS-1:0] branch_target;
wire [ADDRESS_BITS-1:0] JAL_target;

// Data Bypassing Signals
reg [1:0] rs1_data_bypass;
reg [1:0] rs2_data_bypass;
reg [DATA_WIDTH-1:0] ALU_result_execute;
reg [DATA_WIDTH-1:0] ALU_result_memory;
reg [DATA_WIDTH-1:0] ALU_result_writeback;

reg scan;

five_stage_decode_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  // Base Decode Signals
  .clock(clock),
  .reset(reset),

  .PC(PC),
  .instruction(instruction),
  .extend_sel(extend_sel),
  .write(write),
  .write_reg(write_reg),
  .write_data(write_data),

  .rs1_data(rs1_data),
  .rs2_data(rs2_data),
  .rd(rd),
  .opcode(opcode),
  .funct7(funct7),
  .funct3(funct3),
  .extend_imm(extend_imm),
  .branch_target(branch_target),
  .JAL_target(JAL_target),

  // Data Bypassing Signals
  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),
  .ALU_result_execute(ALU_result_execute),
  .ALU_result_memory(ALU_result_memory),
  .ALU_result_writeback(ALU_result_writeback),

  .scan(scan)

);

always #5 clock = ~clock;


initial begin
  clock = 1'b1;
  reset = 1'b1;

  PC = 32'd4;
  instruction = 32'h00000013;
  extend_sel = 0;
  write = 1'b0;
  write_reg = 5'd0;
  write_data = 32'd0;

  // Data Bypassing Signals
  rs1_data_bypass = 2'b00;
  rs2_data_bypass = 2'b00;
  ALU_result_execute = 32'd1;
  ALU_result_memory = 32'd2;
  ALU_result_writeback = 32'd3;

  scan = 1'b0;

  repeat (1) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  if( rs1_data != 32'd0 |
      rs2_data != 32'd0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: RS1 and RS2 should be 0!");
    $display("\ntb_five_stage_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  rs1_data_bypass = 2'b01;
  rs2_data_bypass = 2'b10;

  repeat (1) @ (posedge clock);

  if( rs1_data != 32'd1 |
      rs2_data != 32'd2 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: RS1 should be 1 and RS2 should be 2!");
    $display("\ntb_five_stage_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  rs1_data_bypass = 2'b10;
  rs2_data_bypass = 2'b11;

  repeat (1) @ (posedge clock);

  if( rs1_data != 32'd2 |
      rs2_data != 32'd3 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: RS1 should be 2 and RS2 should be 3!");
    $display("\ntb_five_stage_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  rs1_data_bypass = 2'b11;
  rs2_data_bypass = 2'b01;

  repeat (1) @ (posedge clock);

  if( rs1_data != 32'd3 |
      rs2_data != 32'd1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: RS1 should be 3 and RS2 should be 1!");
    $display("\ntb_five_stage_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_five_stage_decode_unit --> Test Passed!\n\n");
  $stop();

end

endmodule
