/** @module : tb_m_control
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

module tb_m_control();

localparam [6:0]R_TYPE  = 7'b0110011,
                I_TYPE  = 7'b0010011,
                STORE   = 7'b0100011,
                LOAD    = 7'b0000011,
                BRANCH  = 7'b1100011,
                JALR    = 7'b1100111,
                JAL     = 7'b1101111,
                AUIPC   = 7'b0010111,
                LUI     = 7'b0110111,
                FENCE   = 7'b0001111,
                SYSTEM  = 7'b1110011;

// RV64 Opcodes
localparam [6:0]IMM_32 = 7'b0011011,
                OP_32  = 7'b0111011;


parameter CORE            = 0;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

reg clock;
reg reset;
reg [6:0] opcode_decode;
reg [2:0] funct3; // decode
reg [6:0] funct7; // decode

reg [5:0] ALU_operation_base;

wire [5:0] ALU_operation;

reg  scan;


m_control #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  .clock(clock),
  .reset(reset),
  .opcode_decode(opcode_decode),
  .funct3(funct3),
  .funct7(funct7),

  .ALU_operation_base(ALU_operation_base),

  .ALU_operation(ALU_operation),

  .scan(scan)
);

always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;
  opcode_decode = 7'd0;
  funct3 = 3'b000;
  funct7 = 7'b0000000;
  ALU_operation_base = 6'd0;
  scan = 1'b0;

  repeat (3) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  if( ALU_operation !== 6'd0) begin
    $display("\nError! Unexpected idle state.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  funct3 = 3'b000;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd20) begin
    $display("\nError! Unexpected output for MUL.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  funct3 = 3'b001;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd21) begin
    $display("\nError! Unexpected output for MULH.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  funct3 = 3'b010;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd23) begin
    $display("\nError! Unexpected output for MULHSU.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  funct3 = 3'b011;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd22) begin
    $display("\nError! Unexpected output for MULHU.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  funct3 = 3'b100;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd24) begin
    $display("\nError! Unexpected output for DIV.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  funct3 = 3'b101;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd25) begin
    $display("\nError! Unexpected output for DIVU.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  funct3 = 3'b110;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd26) begin
    $display("\nError! Unexpected output for REM.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  funct3 = 3'b111;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd27) begin
    $display("\nError! Unexpected output for REMU.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = OP_32;
  funct3 = 3'b000;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd28) begin
    $display("\nError! Unexpected output for MULW.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = OP_32;
  funct3 = 3'b100;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd29) begin
    $display("\nError! Unexpected output for DIVW.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = OP_32;
  funct3 = 3'b101;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd30) begin
    $display("\nError! Unexpected output for DIVUW.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = OP_32;
  funct3 = 3'b110;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd31) begin
    $display("\nError! Unexpected output for REMW.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = OP_32;
  funct3 = 3'b111;
  funct7 = 7'b0000001;

  repeat (1) @ (posedge clock);
  #1
  if( ALU_operation !== 6'd32) begin
    $display("\nError! Unexpected output for REMUW.");
    $display("\n%h",ALU_operation);
    $display("\ntb_m_control --> Test Failed!\n\n");
    $stop();
  end

  repeat (1) @ (posedge clock);
  $display("\ntb_m_control --> Test Passed!\n\n");
  $stop();

end





endmodule

