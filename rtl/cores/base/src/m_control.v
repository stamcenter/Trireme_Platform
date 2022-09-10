/** @module : m_control
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

module m_control #(
  parameter CORE            = 0,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input [6:0] opcode_decode,
  input [2:0] funct3, // decode
  input [6:0] funct7, // decode

  input [5:0] ALU_operation_base,

  output [5:0] ALU_operation,

  input  scan
);

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction


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

// Check for operations other than addition. Use addition as default case
assign ALU_operation =
  (opcode_decode == R_TYPE & funct3 == 3'b000 & funct7 == 7'b0000001) ? 6'd20 : // MUL
  (opcode_decode == R_TYPE & funct3 == 3'b001 & funct7 == 7'b0000001) ? 6'd21 : // MULH
  (opcode_decode == R_TYPE & funct3 == 3'b011 & funct7 == 7'b0000001) ? 6'd22 : // MULHU
  (opcode_decode == R_TYPE & funct3 == 3'b010 & funct7 == 7'b0000001) ? 6'd23 : // MULHSU
  (opcode_decode == R_TYPE & funct3 == 3'b100 & funct7 == 7'b0000001) ? 6'd24 : // DIV
  (opcode_decode == R_TYPE & funct3 == 3'b101 & funct7 == 7'b0000001) ? 6'd25 : // DIVU
  (opcode_decode == R_TYPE & funct3 == 3'b110 & funct7 == 7'b0000001) ? 6'd26 : // REM
  (opcode_decode == R_TYPE & funct3 == 3'b111 & funct7 == 7'b0000001) ? 6'd27 : // REMU
  (opcode_decode == OP_32  & funct3 == 3'b000 & funct7 == 7'b0000001) ? 6'd28 : // MULW
  (opcode_decode == OP_32  & funct3 == 3'b100 & funct7 == 7'b0000001) ? 6'd29 : // DIVW
  (opcode_decode == OP_32  & funct3 == 3'b101 & funct7 == 7'b0000001) ? 6'd30 : // DIVUW
  (opcode_decode == OP_32  & funct3 == 3'b110 & funct7 == 7'b0000001) ? 6'd31 : // REMW
  (opcode_decode == OP_32  & funct3 == 3'b111 & funct7 == 7'b0000001) ? 6'd32 : // REMUW
  ALU_operation_base;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d M Control Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| ALU_operation  [%b]", ALU_operation);
    $display ("----------------------------------------------------------------------");
  end
end
endmodule
