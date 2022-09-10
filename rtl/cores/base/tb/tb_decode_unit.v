/** @module : tb_decode_unit
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

module tb_decode_unit ();

reg clock;
reg reset;

reg [31:0] PC;
reg [31:0] instruction;
reg [1:0] extend_sel;
reg write;
reg [4:0]  write_reg;
reg [31:0] write_data;
reg scan;

wire [31:0]  rs1_data;
wire [31:0]  rs2_data;
wire [4:0]   rd;
wire [31:0] branch_target;
wire [31:0] JAL_target;

wire [6:0]  opcode;
wire [6:0]  funct7;
wire [2:0]  funct3;
wire [31:0] extend_imm;

decode_unit #(
  .CORE(0),
  .DATA_WIDTH(32),
  .ADDRESS_BITS(32)
) decode (
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

  .scan(scan)
);

// Clock generator
always #1 clock = ~clock;

initial begin
  clock   = 0;
  reset = 1;
  PC            = 0;
  instruction   = 0;
  extend_sel    = 0;
  write         = 0;
  write_data    = 0;
  write_reg     = 0;
  scan        = 0;

  #10 reset = 0;
  repeat (1) @ (posedge clock);

  PC            <= 32'h00000004;
  instruction   <= 32'hfe010113; // addi sp, sp, -32
  extend_sel    <= 2'b00;
  write         <= 0;
  write_data    <= 0;
  write_reg     <= 0;

  repeat (1) @ (posedge clock);

  if( rd         !== 5'd2         |
      opcode     !== 7'h13        |
      funct3     !== 3'b000       |
      extend_imm !== 32'hffffffe0 ) begin
    scan = 1;
    repeat (1) @ (posedge clock);
    $display("\nError: instruction 'addi sp, sp, -32' failed");
    $display("\ntb_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  PC            <= 32'h00000008;
  instruction   <= 32'h00112e23; // sw ra, 28(sp)
  extend_sel    <= 2'b01;
  write         <= 0;
  write_data    <= 0;
  write_reg     <= 0;

  repeat (1) @ (posedge clock);

  if( opcode     !== 7'h23        |
      funct3     !== 3'b010       |
      extend_imm !== 32'h0000001c ) begin
    scan = 1;
    repeat (1) @ (posedge clock);
    $display("\nError: instruction 'sw ra, 28(sp)' failed");
    $display("\ntb_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  PC            <= 32'h0000000c;
  instruction   <= 32'h00812c23; // sw s0, 24(sp)
  extend_sel    <= 2'b01;
  write         <= 0;
  write_data    <= 0;
  write_reg     <= 0;

  repeat (1) @ (posedge clock);

  if( opcode     !== 7'h23        |
      funct3     !== 3'b010       |
      extend_imm !== 32'h00000018 ) begin
    scan = 1;
    repeat (1) @ (posedge clock);
    $display("\nError: instruction 'sw s0, 24(sp)' failed");
    $display("\ntb_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  PC            <= 32'h00000010;
  instruction   <= 32'h02010413; // addi s0, sp, 32
  extend_sel    <= 2'b00;
  write         <= 0;
  write_data    <= 0;
  write_reg     <= 0;

  repeat (1) @ (posedge clock);

  if( rd         !== 5'd8         |
      opcode     !== 7'h13        |
      funct3     !== 3'b000       |
      extend_imm !== 32'h00000020 ) begin
    scan = 1;
    repeat (1) @ (posedge clock);
    $display("\nError: instruction 'addi s0, sp, 32' failed");
    $display("\ntb_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  PC            <= 32'h00000014;
  instruction   <= 32'h00400793; // addi a5, zero, 4
  extend_sel    <= 2'b00;
  write         <= 0;
  write_data    <= 0;
  write_reg     <= 0;

  repeat (1) @ (posedge clock);

  if( rd         !== 5'd15        |
      opcode     !== 7'h13        |
      funct3     !== 3'b000       |
      extend_imm !== 32'h00000004 ) begin
    scan = 1;
    repeat (1) @ (posedge clock);
    $display("\nError: instruction 'addi a5, zero, 4' failed");
    $display("\ntb_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  PC            <= 32'h00000018;
  instruction   <= 32'hfef42623; // sw a5, -20(s0)
  extend_sel    <= 2'b01;
  write         <= 0;
  write_data    <= 0;
  write_reg     <= 0;
  repeat (1) @ (posedge clock);

  if( opcode     !== 7'h23        |
      funct3     !== 3'b010       |
      extend_imm !== 32'hffffffec ) begin
    scan = 1;
    repeat (1) @ (posedge clock);
    $display("\nError: instruction 'sw a5, -20(sp)' failed");
    $display("\ntb_decode_unit --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_decode_unit --> Test Passed!\n\n");
  $stop();

end

endmodule
