/** @module : control_unit64
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

module control_unit64 #(
  parameter CORE            = 0,
  parameter ADDRESS_BITS    = 32,
  parameter NUM_BYTES       = 32/8,
  parameter LOG2_NUM_BYTES  = log2(NUM_BYTES),
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input [6:0] opcode_decode,
  input [6:0] opcode_execute,
  input [2:0] funct3, // decode
  input [6:0] funct7, // decode

  input [ADDRESS_BITS-1:0] JALR_target_execute,
  input [ADDRESS_BITS-1:0] branch_target_execute,
  input [ADDRESS_BITS-1:0] JAL_target_decode,
  input branch_execute,

  input true_data_hazard,
  //input d_mem_hazard,
  input d_mem_issue_hazard,
  input d_mem_recv_hazard,
  input i_mem_hazard,
  input JALR_branch_hazard,
  input JAL_hazard,

  output branch_op,
  output memRead,
  output [5:0] ALU_operation, // use 6-bits to leave room for extensions
  output memWrite,
  output [LOG2_NUM_BYTES-1:0] log2_bytes,
  output unsigned_load,
  output [1:0] next_PC_sel,
  output [1:0] operand_A_sel,
  output operand_B_sel,
  output [1:0] extend_sel,
  output regWrite,

  output solo_instr_decode,

  output [ADDRESS_BITS-1:0] target_PC,
  output i_mem_read,

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

assign regWrite      = (opcode_decode == R_TYPE) | (opcode_decode == I_TYPE) |
                       (opcode_decode == LOAD)   | (opcode_decode == JALR)   |
                       (opcode_decode == JAL)    | (opcode_decode == AUIPC)  |
                       (opcode_decode == LUI)    |
                       // RV64
                       (opcode_decode == OP_32)  | (opcode_decode == IMM_32);


assign memWrite      = (opcode_decode == STORE);
assign branch_op     = (opcode_decode == BRANCH);
assign memRead       = (opcode_decode == LOAD);


/*
// This logic is less effeicient but may be usefull when non-standard
// instructions are added.
assign log2_bytes = (opcode_decode == LOAD  & funct3 == 3'b000) ? 0 : // LB
                    (opcode_decode == LOAD  & funct3 == 3'b001) ? 1 : // LH
                    (opcode_decode == LOAD  & funct3 == 3'b010) ? 2 : // LW
                    (opcode_decode == LOAD  & funct3 == 3'b011) ? 3 : // LD
                    (opcode_decode == LOAD  & funct3 == 3'b100) ? 0 : // LBU
                    (opcode_decode == LOAD  & funct3 == 3'b101) ? 1 : // LHU
                    (opcode_decode == LOAD  & funct3 == 3'b110) ? 2 : // LWU
                    (opcode_decode == STORE & funct3 == 3'b000) ? 0 : // SB
                    (opcode_decode == STORE & funct3 == 3'b001) ? 1 : // SH
                    (opcode_decode == STORE & funct3 == 3'b010) ? 2 : // SW
                    (opcode_decode == STORE & funct3 == 3'b011) ? 3 : // SD
                    {LOG2_NUM_BYTES{1'b0}};
*/
// Most efficient logic for standard ISA extensions
assign log2_bytes = funct3[1:0];

/*
// This logic is less effeicient but may be usefull when non-standard
// instructions are added.
assign unsigned_load = (opcode_decode == LOAD & funct3 == 3'b100) | // LBU
                       (opcode_decode == LOAD & funct3 == 3'b101) | // LHU
                       (opcode_decode == LOAD & funct3 == 3'b110) | // LWU
*/
// Most efficient logic for standard ISA extensions
assign unsigned_load = funct3[2];


// Check for operations other than addition. Use addition as default case
assign ALU_operation =
  (opcode_decode == JAL) ? 6'd1  : // JAL: Pass through
  (opcode_decode == JALR & funct3 == 3'b000) ? 6'd1 : // JALR: Pass through
  (opcode_decode == BRANCH & funct3 == 3'b000) ? 6'd2 : // BEQ: equal
  (opcode_decode == BRANCH & funct3 == 3'b001) ? 6'd3 : // BNE: not equal
  (opcode_decode == BRANCH & funct3 == 3'b100) ? 6'd4 : // BLT: signed less than
  (opcode_decode == BRANCH & funct3 == 3'b101) ? 6'd5 : // BGE: signed greater than, equal
  (opcode_decode == BRANCH & funct3 == 3'b110) ? 6'd6 : // BLTU: unsigned less than
  (opcode_decode == BRANCH & funct3 == 3'b111) ? 6'd7 : // BGEU: unsigned greater than, equal
  (opcode_decode == I_TYPE & funct3 == 3'b010) ? 6'd4 : // SLTI: signed less than
  (opcode_decode == I_TYPE & funct3 == 3'b011) ? 6'd6 : // SLTIU: unsigned less than
  (opcode_decode == I_TYPE & funct3 == 3'b100) ? 6'd8 : // XORI: xor
  (opcode_decode == I_TYPE & funct3 == 3'b110) ? 6'd9 : // ORI: or
  (opcode_decode == I_TYPE & funct3 == 3'b111) ? 6'd10 : // ANDI: and
  (opcode_decode == I_TYPE & funct3 == 3'b001 & funct7[6:1] == 6'b000000) ? 6'd11 : // SLLI: logical left shift
  (opcode_decode == I_TYPE & funct3 == 3'b101 & funct7[6:1] == 7'b000000) ? 6'd12 : // SRLI: logical right shift
  (opcode_decode == I_TYPE & funct3 == 3'b101 & funct7[6:1] == 7'b010000) ? 6'd13 : // SRAI: arithemtic right shift
  (opcode_decode == R_TYPE & funct3 == 3'b000 & funct7 == 7'b0100000) ? 6'd14 : // SUB: subtract
  (opcode_decode == R_TYPE & funct3 == 3'b001 & funct7 == 7'b0000000) ? 6'd11 : // SLL: logical left shift
  (opcode_decode == R_TYPE & funct3 == 3'b010 & funct7 == 7'b0000000) ? 6'd4  : // SLT: signed less than
  (opcode_decode == R_TYPE & funct3 == 3'b011 & funct7 == 7'b0000000) ? 6'd6  : // SLTU: signed less than
  (opcode_decode == R_TYPE & funct3 == 3'b100 & funct7 == 7'b0000000) ? 6'd8  : // XOR: xor
  (opcode_decode == R_TYPE & funct3 == 3'b101 & funct7 == 7'b0000000) ? 6'd12 : // SRL: logical right shift
  (opcode_decode == R_TYPE & funct3 == 3'b101 & funct7 == 7'b0100000) ? 6'd13 : // SRA: arithmetic right shift
  (opcode_decode == R_TYPE & funct3 == 3'b110 & funct7 == 7'b0000000) ? 6'd9  : // OR: or
  (opcode_decode == R_TYPE & funct3 == 3'b111 & funct7 == 7'b0000000) ? 6'd10 : // AND: and
  (opcode_decode == IMM_32 & funct3 == 3'b000)                        ? 6'd15 : // ADDIW
  (opcode_decode == IMM_32 & funct3 == 3'b001 & funct7 == 7'b0000000) ? 6'd16 : // SLLIW
  (opcode_decode == IMM_32 & funct3 == 3'b101 & funct7 == 7'b0000000) ? 6'd17 : // SRLIW
  (opcode_decode == IMM_32 & funct3 == 3'b101 & funct7 == 7'b0100000) ? 6'd18 : // SRAIW
  (opcode_decode == OP_32  & funct3 == 3'b000 & funct7 == 7'b0000000) ? 6'd15 : // ADDW
  (opcode_decode == OP_32  & funct3 == 3'b000 & funct7 == 7'b0100000) ? 6'd19 : // SUBW
  (opcode_decode == OP_32  & funct3 == 3'b001 & funct7 == 7'b0000000) ? 6'd16 : // SLLW
  (opcode_decode == OP_32  & funct3 == 3'b101 & funct7 == 7'b0000000) ? 6'd17 : // SRLW
  (opcode_decode == OP_32  & funct3 == 3'b101 & funct7 == 7'b0100000) ? 6'd18 : // SRAW
  6'd0; // Use addition by default

assign operand_A_sel = (opcode_decode == AUIPC) ?  2'b01 :
                       (opcode_decode == LUI)   ?  2'b11 :
                       ((opcode_decode == JALR)  | (opcode_decode == JAL)) ? 2'b10 : 2'b00;

assign operand_B_sel = (opcode_decode == I_TYPE) | (opcode_decode == STORE) |
                       (opcode_decode == LOAD)   | (opcode_decode == AUIPC) |
                       (opcode_decode == LUI)    | (opcode_decode == IMM_32);

/*
assign extend_sel    = ((opcode_decode == I_TYPE) | (opcode_decode == LOAD) | (opcode_decode == IMM_32) ) ? 2'b00 :
                       (opcode_decode == STORE)                       ? 2'b01 :
                       ((opcode_decode == AUIPC)  | (opcode_decode == LUI))  ? 2'b10 : 2'b00;
*/
assign extend_sel    = (opcode_decode == STORE) ? 2'b01 :
                       (opcode_decode == AUIPC) ? 2'b10 :
                       (opcode_decode == LUI)   ? 2'b10 :
                       2'b00;


assign target_PC = (opcode_execute == JALR)                    ? JALR_target_execute   :
                   (opcode_execute == BRANCH) & branch_execute ? branch_target_execute :
                   (opcode_decode  == JAL)                     ? JAL_target_decode     :
                   {ADDRESS_BITS{1'b0}};

assign next_PC_sel = JALR_branch_hazard ? 2'b10 : // target_PC
                     true_data_hazard   ? 2'b01 : // stall
                     JAL_hazard         ? 2'b10 : // targeet_PC
                     i_mem_hazard       ? 2'b01 : // stall
                     d_mem_issue_hazard ? 2'b01 : // stall
                     d_mem_recv_hazard  ? 2'b01 : // stall
                     2'b00;                       // PC + 4

assign i_mem_read = 1'b1;

// Most system instructions will have side effects. Dont let other
// instructions into the pipeline while SYSTEM instructions are being
// executed.
assign solo_instr_decode = (opcode_decode == SYSTEM);

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Control Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| Opcode decode  [%b]", opcode_decode);
    $display ("| Opcode execute [%b]", opcode_execute);
    $display ("| Branch_op      [%b]", branch_op);
    $display ("| memRead        [%b]", memRead);
    $display ("| memWrite       [%b]", memWrite);
    $display ("| RegWrite       [%b]", regWrite);
    $display ("| log2_bytes     [%b]", log2_bytes);
    $display ("| unsigned_load  [%b]", unsigned_load);
    $display ("| ALU_operation  [%b]", ALU_operation);
    $display ("| Extend_sel     [%b]", extend_sel);
    $display ("| ALUSrc_A       [%b]", operand_A_sel);
    $display ("| ALUSrc_B       [%b]", operand_B_sel);
    $display ("| Next PC sel    [%b]", next_PC_sel);
    $display ("| Target PC      [%h]", target_PC);
    $display ("----------------------------------------------------------------------");
  end
end
endmodule
