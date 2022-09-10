/** @module : MLU
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

module MLU #(
  parameter DATA_WIDTH = 32
) (
  input clock,
  input reset,
  input  [5:0] ALU_operation,
  input  [DATA_WIDTH-1:0] operand_A,
  input  [DATA_WIDTH-1:0] operand_B,
  // Ready input from next stage of processor
  input                   ready_i,
  // Ready to previous stage of processor
  output                  ready_o,
  output [DATA_WIDTH-1:0] MLU_result,
  output                  valid_result
);

wire signed [DATA_WIDTH-1:0] signed_operand_A;
wire signed [DATA_WIDTH-1:0] signed_operand_B;

wire signed [DATA_WIDTH*2-1:0] ss_product;  // Signed   * Signed
wire        [DATA_WIDTH*2-1:0] uu_product;  // Unsigned * Unsigned
wire        [DATA_WIDTH*2-1:0] su_product;  // Signed   * Unsigend
                                            // RS1      * RS2
wire signed [31          :0]   ssw_product; // Signed   * Signed
wire        [DATA_WIDTH-1:0]   quotient_s;
wire        [DATA_WIDTH-1:0]   remainder_s;
wire        [DATA_WIDTH-1:0]   quotient_u;
wire        [DATA_WIDTH-1:0]   remainder_u;
wire        [DATA_WIDTH-1:0]   mulw;
wire        [DATA_WIDTH-1:0]   divw;
wire        [DATA_WIDTH-1:0]   divuw;
wire        [DATA_WIDTH-1:0]   remw;
wire        [DATA_WIDTH-1:0]   remuw;
wire        [31:0]   quotient_w_s;
wire        [31:0]   remainder_w_s;
wire        [31:0]   quotient_w_u;
wire        [31:0]   remainder_w_u;

// DIV
wire start_div_s;
wire ready_div_s_o;
wire valid_div_s;
// DIVU
wire start_div_u;
wire ready_div_u_o;
wire valid_div_u;
// DIVW
wire start_divw_s;
wire ready_divw_s_o;
wire valid_divw_s;
// DIVUW
wire start_divw_u;
wire ready_divw_u_o;
wire valid_divw_u;

assign signed_operand_A = operand_A;
assign signed_operand_B = operand_B;

assign ss_product  = signed_operand_A * signed_operand_B;
assign uu_product  = operand_A        * operand_B;
assign su_product  = signed_operand_A[DATA_WIDTH-1] ? (~ss_product) +1'b1 : ss_product;

// Do not start in same cycle as valid output to prevent re-doing the same
// division. This is simpler than adding complete handshaking logic to the
// execute stage.
assign start_div_s  = ((ALU_operation == 6'd24) | (ALU_operation == 6'd26)) & ~valid_div_s;
assign start_div_u  = ((ALU_operation == 6'd25) | (ALU_operation == 6'd27)) & ~valid_div_u;
assign start_divw_s = ((ALU_operation == 6'd29) | (ALU_operation == 6'd31)) & ~valid_divw_s;
assign start_divw_u = ((ALU_operation == 6'd30) | (ALU_operation == 6'd32)) & ~valid_divw_u;

assign MLU_result =
  (ALU_operation == 6'd20)? ss_product[0          +: DATA_WIDTH] : /* MUL    */
  (ALU_operation == 6'd21)? ss_product[DATA_WIDTH +: DATA_WIDTH] : /* MULH   */
  (ALU_operation == 6'd22)? uu_product[DATA_WIDTH +: DATA_WIDTH] : /* MULHU  */
  (ALU_operation == 6'd23)? su_product[DATA_WIDTH +: DATA_WIDTH] : /* MULHSU */
  (ALU_operation == 6'd24)? quotient_s                           : /* DIV    */
  (ALU_operation == 6'd25)? quotient_u                           : /* DIVU   */
  (ALU_operation == 6'd26)? remainder_s                          : /* REM    */
  (ALU_operation == 6'd27)? remainder_u                          : /* REMU   */
  (ALU_operation == 6'd28)? mulw                                 : /* MULW   */
  (ALU_operation == 6'd29)? divw                                 : /* DIVW   */
  (ALU_operation == 6'd30)? divuw                                : /* DIVUW  */
  (ALU_operation == 6'd31)? remw                                 : /* REMW   */
  (ALU_operation == 6'd32)? remuw                                : /* REMUW  */
  {DATA_WIDTH{1'b0}};

// Output always valid during non-division operations or when division valid
// signal is high.
assign valid_result = valid_div_s | valid_div_u | valid_divw_s | valid_divw_u |
                      (~start_div_u & ~start_div_s & ~start_divw_u & ~start_divw_s);

assign ready_o = ready_div_s_o & ready_div_u_o & ready_divw_s_o & ready_divw_u_o;

divider #(
  .DIV_SIZE(DATA_WIDTH),
  .SIGNED("True"),
  .FRACTION_BITS(0)
) SIGNED_DIV (
  .clock(clock),
  .reset(reset),
  .ready_i(ready_i),
  .start(start_div_s),
  .numerator(operand_A),
  .denominator(operand_B),
  .quotient(quotient_s),
  .remainder(remainder_s),
  .valid(valid_div_s),
  .ready_o(ready_div_s_o)
);

divider #(
  .DIV_SIZE(DATA_WIDTH),
  .SIGNED("False"),
  .FRACTION_BITS(0)
) UNSIGNED_DIV (
  .clock(clock),
  .reset(reset),
  .ready_i(ready_i),
  .start(start_div_u),
  .numerator(operand_A),
  .denominator(operand_B),
  .quotient(quotient_u),
  .remainder(remainder_u),
  .valid(valid_div_u),
  .ready_o(ready_div_u_o)
);

generate
  if(DATA_WIDTH == 64) begin : XLEN_64

    assign ssw_product = signed_operand_A[31:0] * signed_operand_B[31:0];
    // Sign extend the 32-bit product
    assign mulw        = { {DATA_WIDTH-32{ssw_product[31]}}, ssw_product};

    divider #(
      .DIV_SIZE(32),
      .SIGNED("True"),
      .FRACTION_BITS(0)
    ) SIGNED_DIVW (
      .clock(clock),
      .reset(reset),
      .ready_i(ready_i),
      .start(start_divw_s),
      .numerator(operand_A[31:0]),
      .denominator(operand_B[31:0]),
      .quotient(quotient_w_s),
      .remainder(remainder_w_s),
      .valid(valid_divw_s),
      .ready_o(ready_divw_s_o)
    );

    divider #(
      .DIV_SIZE(32),
      .SIGNED("False"),
      .FRACTION_BITS(0)
    ) UNSIGNED_DIVW (
      .clock(clock),
      .reset(reset),
      .ready_i(ready_i),
      .start(start_divw_u),
      .numerator(operand_A[31:0]),
      .denominator(operand_B[31:0]),
      .quotient(quotient_w_u),
      .remainder(remainder_w_u),
      .valid(valid_divw_u),
      .ready_o(ready_divw_u_o)
    );

    // Always sign extend to 64-bits
    assign divw  = { {DATA_WIDTH-32{quotient_w_s[31] }}, quotient_w_s };
    assign divuw = { {DATA_WIDTH-32{quotient_w_u[31] }}, quotient_w_u };
    assign remw  = { {DATA_WIDTH-32{remainder_w_s[31]}}, remainder_w_s};
    assign remuw = { {DATA_WIDTH-32{remainder_w_u[31]}}, remainder_w_u};

  end
  else begin
    assign ssw_product = 32'd0;
    assign mulw        = {DATA_WIDTH{1'b0}};

    assign quotient_w_s  = 32'd0;
    assign quotient_w_u  = 32'd0;
    assign remainder_w_s = 32'd0;
    assign remainder_w_u = 32'd0;

    assign divw  = {DATA_WIDTH{1'b0}};
    assign divuw = {DATA_WIDTH{1'b0}};
    assign remw  = {DATA_WIDTH{1'b0}};
    assign remuw = {DATA_WIDTH{1'b0}};

  end
endgenerate


endmodule
