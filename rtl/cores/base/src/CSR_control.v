/** @module : CSR_control
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


module CSR_control #(
  parameter CORE            = 0,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  input [6:0] opcode_decode,
  input [2:0] funct3, // decode
  input [4:0] rs1,
  input [4:0] rd,
  input [1:0] extend_sel_base,
  input [1:0] operand_A_sel_base,
  input       operand_B_sel_base,
  input [5:0] ALU_operation_base,
  input       regWrite_base,

  output CSR_read_en,
  output CSR_write_en,
  output CSR_set_en,
  output CSR_clear_en,


  output [1:0] extend_sel,
  output [1:0] operand_A_sel,
  output       operand_B_sel,
  output [5:0] ALU_operation,
  output       regWrite,

  input scan
);

localparam SYSTEM = 7'b1110011;

// Do not read on CSRRW instructions w/ rd=0.
//assign CSR_read_en = (opcode_decode == SYSTEM) & ~((funct3[2:0] == 2'd1) & (rd == 5'd0));
assign CSR_read_en = (opcode_decode == SYSTEM) & (
 ((funct3 == 3'b001) & (rd != 5'd0)) | // CSRRW
  (funct3 == 3'b010)                 | // CSRRS
  (funct3 == 3'b011)                 | // CSRRC
 ((funct3 == 3'b101) & (rd != 5'd0)) | // CSRRWI
  (funct3 == 3'b110)                 | // CSRRSI
  (funct3 == 3'b111)                   // CSRRCI
);


assign CSR_write_en = (opcode_decode == SYSTEM & funct3 == 3'b001) |
                      (opcode_decode == SYSTEM & funct3 == 3'b101);

assign CSR_set_en =  (rs1 != 5'd0) & (opcode_decode == SYSTEM) & (
  (funct3 == 3'b010) |
  (funct3 == 3'b110)
);

assign CSR_clear_en = (rs1 != 5'd0) & (opcode_decode == SYSTEM) & (
  (funct3 == 3'b011) |
  (funct3 == 3'b111)
);

assign operand_A_sel = (opcode_decode == SYSTEM) & funct3[2] ?  2'b11 : // Select 0 for immediate CSR instructions
                       (opcode_decode == SYSTEM)             ?  2'b00 : // Select RS1 for other CSR instructions
                       operand_A_sel_base;

// Add extra ALU op conditions
assign ALU_operation =
  (opcode_decode == SYSTEM & funct3 == 3'b001) ? 6'd1 : // CSRRW (Passthrough A)
  (opcode_decode == SYSTEM & funct3 == 3'b010) ? 6'd1 : // CSRRS (Passthrough A)
  (opcode_decode == SYSTEM & funct3 == 3'b011) ? 6'd1 : // CSRRC (Passthrough A)
  (opcode_decode == SYSTEM & funct3 == 3'b101) ? 6'd0 : // CSRRWI (B+0 Passthrough)
  (opcode_decode == SYSTEM & funct3 == 3'b110) ? 6'd0 : // CSRRSI (B+0 Passthrough)
  (opcode_decode == SYSTEM & funct3 == 3'b111) ? 6'd0 : // CSRRCI (B+0 Passthrough)
  ALU_operation_base;

// Add extra condition to extend_sel
assign extend_sel = (opcode_decode == SYSTEM) & funct3[2] ? 2'b10 : extend_sel_base;
assign operand_B_sel = ((opcode_decode == SYSTEM) & funct3[2]) | operand_B_sel_base;

assign regWrite = CSR_read_en | regWrite_base;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d CSR Control Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| Opcode decode  [%b]", opcode_decode);
    $display ("| Funct3         [%b]", funct3);
    $display ("| RS1            [%b]", rs1);
    $display ("| RD             [%b]", rd);
    $display ("| CSRRead        [%b]", CSR_read_en);
    $display ("| RegWrite       [%b]", regWrite);
    $display ("| ALU_operation  [%b]", ALU_operation);
    $display ("| Extend_sel     [%b]", extend_sel);
    $display ("| ALUSrc_B       [%b]", operand_B_sel);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
