/** @module : tb_CSR_control
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

module tb_CSR_control();

parameter CORE            = 0;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

parameter [6:0]R_TYPE  = 7'b0110011,
                I_TYPE  = 7'b0010011,
                STORE   = 7'b0100011,
                LOAD    = 7'b0000011,
                BRANCH  = 7'b1100011,
                JALR    = 7'b1100111,
                JAL     = 7'b1101111,
                AUIPC   = 7'b0010111,
                LUI     = 7'b0110111,
                FENCES  = 7'b0001111,
                SYSTEM  = 7'b1110011;

parameter MACHINE    = 2'b11;
parameter SUPERVISOR = 2'b01;
parameter USER       = 2'b00;


reg clock;
reg reset;

reg [6:0] opcode_decode;
reg [2:0] funct3; // decode
reg [4:0] rs1;
reg [4:0] rd;
reg [1:0] extend_sel_base;
reg [1:0] operand_A_sel_base;
reg       operand_B_sel_base;
reg [5:0] ALU_operation_base;
reg       regWrite_base;

wire CSR_read_en;
wire CSR_write_en;
wire CSR_set_en;
wire CSR_clear_en;


wire [1:0] extend_sel;
wire [1:0] operand_A_sel;
wire       operand_B_sel;
wire [5:0] ALU_operation;
wire       regWrite;

reg scan;


CSR_control #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  .clock(clock),
  .reset(reset),

  .opcode_decode(opcode_decode),
  .funct3(funct3), // decode
  .rs1(rs1),
  .rd(rd),
  .extend_sel_base(extend_sel_base),
  .operand_A_sel_base(operand_A_sel_base),
  .operand_B_sel_base(operand_B_sel_base),
  .ALU_operation_base(ALU_operation_base),
  .regWrite_base(regWrite_base),

  .CSR_read_en(CSR_read_en),
  .CSR_write_en(CSR_write_en),
  .CSR_set_en(CSR_set_en),
  .CSR_clear_en(CSR_clear_en),

  .extend_sel(extend_sel),

  .operand_A_sel(operand_A_sel),
  .operand_B_sel(operand_B_sel),
  .ALU_operation(ALU_operation),
  .regWrite(regWrite),

  .scan(scan)
);

always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;

  opcode_decode = R_TYPE;
  funct3        = 3'b000; // decode
  rs1           = 5'b00000;
  rd            = 5'b00000;
  extend_sel_base = 2'b00;
  operand_B_sel_base = 1'b0;
  ALU_operation_base = 6'd0;
  regWrite_base      = 1'b0;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  // CSRRW
  opcode_decode = SYSTEM;
  funct3        = 3'b001;
  rs1           = 5'b00001;
  rd            = 5'b00001;

  repeat (1) @ (posedge clock);
  #1
  if( CSR_read_en   !== 1'b1 |
      CSR_write_en  !== 1'b1 |
      CSR_set_en    !== 1'b0 |
      CSR_clear_en  !== 1'b0 |
      extend_sel    !== 2'd0 |
      operand_A_sel !== 2'd0 |
      operand_B_sel !== 1'b0 |
      ALU_operation !== 6'd1 |
      regWrite      !== 1'b1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Unexpected CSRRW control signals!");
    $display("\ntb_CSR_control --> Test Failed!\n\n");
    $stop();
  end

  // CSRRS
  opcode_decode = SYSTEM;
  funct3        = 3'b010;
  rs1           = 5'b00001;
  rd            = 5'b00001;

  repeat (1) @ (posedge clock);
  #1
  if( CSR_read_en   !== 1'b1 |
      CSR_write_en  !== 1'b0 |
      CSR_set_en    !== 1'b1 |
      CSR_clear_en  !== 1'b0 |
      extend_sel    !== 2'd0 |
      operand_A_sel !== 2'd0 |
      operand_B_sel !== 1'b0 |
      ALU_operation !== 6'd1 |
      regWrite      !== 1'b1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Unexpected CSRRS control signals!");
    $display("\ntb_CSR_control --> Test Failed!\n\n");
    $stop();
  end

  // CSRRC
  opcode_decode = SYSTEM;
  funct3        = 3'b011;
  rs1           = 5'b00001;
  rd            = 5'b00001;

  repeat (1) @ (posedge clock);
  #1
  if( CSR_read_en   !== 1'b1 |
      CSR_write_en  !== 1'b0 |
      CSR_set_en    !== 1'b0 |
      CSR_clear_en  !== 1'b1 |
      extend_sel    !== 2'd0 |
      operand_A_sel !== 2'd0 |
      operand_B_sel !== 1'b0 |
      ALU_operation !== 6'd1 |
      regWrite      !== 1'b1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Unexpected CSRRC control signals!");
    $display("\ntb_CSR_control --> Test Failed!\n\n");
    $stop();
  end

  // CSRRC
  opcode_decode = SYSTEM;
  funct3        = 3'b011;
  rs1           = 5'b00000;
  rd            = 5'b00001;

  repeat (1) @ (posedge clock);
  #1
  if( CSR_read_en   !== 1'b1 |
      CSR_write_en  !== 1'b0 |
      CSR_set_en    !== 1'b0 |
      CSR_clear_en  !== 1'b0 |
      extend_sel    !== 2'd0 |
      operand_A_sel !== 2'd0 |
      operand_B_sel !== 1'b0 |
      ALU_operation !== 6'd1 |
      regWrite      !== 1'b1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Unexpected CSRRC (rs1 = x0) control signals!");
    $display("\ntb_CSR_control --> Test Failed!\n\n");
    $stop();
  end
  // CSRRWI
  opcode_decode = SYSTEM;
  funct3        = 3'b101;
  rs1           = 5'b00001;
  rd            = 5'b00001;

  repeat (1) @ (posedge clock);
  #1
  if( CSR_read_en   !== 1'b1 |
      CSR_write_en  !== 1'b1 |
      CSR_set_en    !== 1'b0 |
      CSR_clear_en  !== 1'b0 |
      extend_sel    !== 2'd2 |
      operand_A_sel !== 2'd3 |
      operand_B_sel !== 1'b1 |
      ALU_operation !== 6'd0 |
      regWrite      !== 1'b1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Unexpected CSRRWI control signals!");
    $display("\ntb_CSR_control --> Test Failed!\n\n");
    $stop();
  end

  // CSRRWI
  opcode_decode = SYSTEM;
  funct3        = 3'b101;
  rs1           = 5'b00001;
  rd            = 5'b00000;

  repeat (1) @ (posedge clock);
  #1
  if( CSR_read_en   !== 1'b0 |
      CSR_write_en  !== 1'b1 |
      CSR_set_en    !== 1'b0 |
      CSR_clear_en  !== 1'b0 |
      extend_sel    !== 2'd2 |
      operand_A_sel !== 2'd3 |
      operand_B_sel !== 1'b1 |
      ALU_operation !== 6'd0 |
      regWrite      !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);

    $display("Error: Unexpected CSRRWI (rd = x0) control signals!");
    $display("\ntb_CSR_control --> Test Failed!\n\n");
    $stop();
  end

  repeat (5) @ (posedge clock);

  $display("\ntb_CSR_control --> Test Passed!\n\n");
  $stop();

end

endmodule
