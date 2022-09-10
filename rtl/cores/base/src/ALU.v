/** @module : ALU
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

module ALU #(
  parameter DATA_WIDTH = 32
) (
  input [5:0] ALU_operation,
  input [DATA_WIDTH-1:0] operand_A,
  input [DATA_WIDTH-1:0] operand_B,
  output [DATA_WIDTH-1:0] ALU_result
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

localparam LOG2_DATA_WIDTH = log2(DATA_WIDTH);

wire [LOG2_DATA_WIDTH:0] shamt;

wire signed [DATA_WIDTH-1:0] signed_operand_A;
wire signed [DATA_WIDTH-1:0] signed_operand_B;

// wires for signed operations
wire [(DATA_WIDTH*2)-1:0] arithmetic_right_shift_double;
wire [DATA_WIDTH-1:0] arithmetic_right_shift;
wire signed [DATA_WIDTH-1:0] signed_less_than;
wire signed [DATA_WIDTH-1:0] signed_greater_than_equal;

// wires for word operations in RV64
wire [31:0] word_operand_A;
wire [31:0] word_operand_B;
wire [31:0] word_sum;
wire [DATA_WIDTH-1:0] word_add;
wire [31:0] word_left_shift;
wire [31:0] word_right_shift;
wire [63:0] word_arithmetic_shift_double;
wire [31:0] word_arithmetic_shift;
wire [DATA_WIDTH-1:0] word_left_shift_SE;
wire [DATA_WIDTH-1:0] word_right_shift_SE;
wire [DATA_WIDTH-1:0] word_arithmetic_shift_SE;
wire [31:0] word_diff;
wire [DATA_WIDTH-1:0] word_sub;

assign shamt = operand_B [LOG2_DATA_WIDTH:0]; // I_immediate[5:0];

assign signed_operand_A = operand_A;
assign signed_operand_B = operand_B;

// Signed Operations
assign arithmetic_right_shift_double = ({ {DATA_WIDTH{operand_A[DATA_WIDTH-1]}}, operand_A }) >> shamt;
assign arithmetic_right_shift = arithmetic_right_shift_double[DATA_WIDTH-1:0];
assign signed_less_than = signed_operand_A < signed_operand_B;
assign signed_greater_than_equal = signed_operand_A >= signed_operand_B;

// Word Operations (for RV64)
assign word_operand_A = operand_A[31:0];
assign word_operand_B = operand_B[31:0];

// ADDW,ADDIW
assign word_sum = word_operand_A + word_operand_B;
assign word_add = {{DATA_WIDTH-32{word_sum[31]}}, word_sum};

// Word Shifts
assign word_left_shift = word_operand_A << shamt[4:0];
assign word_right_shift = word_operand_A >> shamt[4:0];
assign word_arithmetic_shift_double = ({ {32{word_operand_A[31]}}, word_operand_A}) >> shamt[4:0];
assign word_arithmetic_shift = word_arithmetic_shift_double[31:0];
// Sign Extend Word Shifts
assign word_left_shift_SE       = { {DATA_WIDTH-32{word_left_shift[31]}}, word_left_shift};
assign word_right_shift_SE      = { {DATA_WIDTH-32{word_right_shift[31]}}, word_right_shift};
assign word_arithmetic_shift_SE = { {DATA_WIDTH-32{word_arithmetic_shift[31]}}, word_arithmetic_shift};

// SUBW,SUBIW
assign word_diff = word_operand_A - word_operand_B;
assign word_sub = {{DATA_WIDTH-32{word_diff[31]}}, word_diff};


assign ALU_result =
  (ALU_operation == 6'd0 )? operand_A + operand_B:     /* ADD, ADDI, LB, LH, LW,
                                                          LBU, LHU, SB, SH, SW,
                                                          AUIPC, LUI */
  (ALU_operation == 6'd1 )? operand_A:                 /* JAL, JALR */
  (ALU_operation == 6'd2 )? operand_A == operand_B:    /* BEQ */
  (ALU_operation == 6'd3 )? operand_A != operand_B:    /* BNE */
  (ALU_operation == 6'd4 )? signed_less_than:          /* BLT, SLTI, SLT */
  (ALU_operation == 6'd5 )? signed_greater_than_equal: /* BGE */
  (ALU_operation == 6'd6 )? operand_A < operand_B:     /* BLTU, SLTIU, SLTU*/
  (ALU_operation == 6'd7 )? operand_A >= operand_B:    /* BGEU */
  (ALU_operation == 6'd8 )? operand_A ^ operand_B:     /* XOR, XORI*/
  (ALU_operation == 6'd9 )? operand_A | operand_B:     /* OR, ORI */
  (ALU_operation == 6'd10)? operand_A & operand_B:     /* AND, ANDI */
  (ALU_operation == 6'd11)? operand_A << shamt:        /* SLL, SLLI */
  (ALU_operation == 6'd12)? operand_A >> shamt:        /* SRL, SRLI */
  (ALU_operation == 6'd13)? arithmetic_right_shift:    /* SRA, SRAI */
  (ALU_operation == 6'd14)? operand_A - operand_B:     /* SUB */
  (ALU_operation == 6'd15)? word_add:                  /* ADDW, ADDIW*/
  (ALU_operation == 6'd16)? word_left_shift_SE:        /* SLLW, SLLIW */
  (ALU_operation == 6'd17)? word_right_shift_SE:       /* SRLW, SRLIW */
  (ALU_operation == 6'd18)? word_arithmetic_shift_SE:  /* SRAW, SRAIW */
  (ALU_operation == 6'd19)? word_sub:                  /* SUBW, SUBIW*/
  {DATA_WIDTH{1'b0}};

endmodule
