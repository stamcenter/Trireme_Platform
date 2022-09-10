/** @module : tb_control_unit
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
*/


module tb_control_unit();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter CORE            = 0;
parameter ADDRESS_BITS    = 20;
parameter NUM_BYTES       = 32/8;
parameter LOG2_NUM_BYTES  = log2(NUM_BYTES);
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

reg clock;
reg reset;

reg [6:0] opcode_decode;
reg [6:0] opcode_execute;
reg [2:0] funct3;
reg [6:0] funct7;

reg [ADDRESS_BITS-1:0] JALR_target_execute;
reg [ADDRESS_BITS-1:0] branch_target_execute;
reg [ADDRESS_BITS-1:0] JAL_target_decode;
reg branch_execute;

reg true_data_hazard;
//reg d_mem_hazard;
reg d_mem_issue_hazard;
reg d_mem_recv_hazard;
reg i_mem_hazard;
reg JALR_branch_hazard;
reg JAL_hazard;

wire branch_op;
wire memRead;
wire [5:0] ALU_operation;
wire memWrite;
wire [LOG2_NUM_BYTES-1:0] log2_bytes;
wire unsigned_load;
wire [1:0] next_PC_sel;
wire [1:0] operand_A_sel;
wire operand_B_sel;
wire [1:0] extend_sel;
wire regWrite;

wire solo_instr_decode;

wire [ADDRESS_BITS-1:0] target_PC;
wire i_mem_read;

reg scan;

control_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) control (
  .clock(clock),
  .reset(reset),
  .opcode_decode(opcode_decode),
  .opcode_execute(opcode_execute),
  .funct3(funct3),
  .funct7(funct7),

  .JALR_target_execute(JALR_target_execute),
  .branch_target_execute(branch_target_execute),
  .JAL_target_decode(JAL_target_decode),
  .branch_execute(branch_execute),

  .true_data_hazard(true_data_hazard),
  //.d_mem_hazard(d_mem_hazard),
  .d_mem_issue_hazard(d_mem_issue_hazard),
  .d_mem_recv_hazard(d_mem_recv_hazard),
  .i_mem_hazard(i_mem_hazard),
  .JALR_branch_hazard(JALR_branch_hazard),
  .JAL_hazard(JAL_hazard),

  .branch_op(branch_op),
  .memRead(memRead),
  .ALU_operation(ALU_operation),
  .memWrite(memWrite),
  .log2_bytes(log2_bytes),
  .unsigned_load(unsigned_load),
  .next_PC_sel(next_PC_sel),
  .operand_A_sel(operand_A_sel),
  .operand_B_sel(operand_B_Sel),
  .extend_sel(extend_sel),
  .regWrite(regWrite),

  .solo_instr_decode(solo_instr_decode),

  .target_PC(target_PC),
  .i_mem_read(i_mem_read),

  .scan(scan)
);

// Clock generator
always #1 clock = ~clock;

initial begin
  clock          = 0;
  reset          = 1;
  opcode_decode  = 0;
  opcode_execute = 0;
  funct3         = 3'b000;
  funct7         = 7'b0000000;

  JALR_target_execute   = 4;
  branch_target_execute = 8;
  JAL_target_decode     = 12;
  branch_execute        = 0;

  true_data_hazard   = 1'b0;
  //d_mem_hazard       = 1'b0;
  d_mem_issue_hazard = 1'b0;
  d_mem_recv_hazard  = 1'b0;
  i_mem_hazard       = 1'b0;
  JALR_branch_hazard = 1'b0;
  JAL_hazard         = 1'b0;

  scan           = 0;

  #10 reset = 0;
  repeat (1) @ (posedge clock);

  // Subtract
  opcode_decode <= 7'b0110011;
  funct3 <= 3'b000;
  funct7 <= 7'b0100000;
  repeat (1) @ (posedge clock);

  if( branch_op     !== 1'b0   |
      memRead       !== 1'b0   |
      ALU_operation !== 6'd14  |
      memWrite      !== 1'b0   |
      log2_bytes    !== 2'b00  |
      unsigned_load !== 1'b0   |
      next_PC_sel   !== 2'b00  |
      operand_A_sel !== 2'b00  |
      operand_B_Sel !== 1'b0   |
      extend_sel    !== 2'b00  |
      regWrite      !== 1'b1   ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Subtract operation failed!");
    $display("\ntb_control_unit--> Test Failed!\n\n");
    $stop();
  end

  opcode_decode      <= 7'b0110011; // Add in decode
  opcode_execute     <= 7'b1100011; // Branch Equal
  funct3 <= 3'b000; // Add in decode
  funct7 <= 7'b0000000; // Add in decode
  branch_execute     <= 1'b1;
  JALR_branch_hazard <= 1'b1;
  repeat (1) @ (posedge clock);

  if( branch_op     !== 1'b0   |
      memRead       !== 1'b0   |
      ALU_operation !== 6'd0   | // Add in decode
      memWrite      !== 1'b0   |
      log2_bytes    !== 2'b00  |
      unsigned_load !== 1'b0   |
      next_PC_sel   !== 2'b10  |
      operand_A_sel !== 2'b00  |
      operand_B_Sel !== 1'b0   |
      extend_sel    !== 2'b00  |
      regWrite      !== 1'b1   |
      target_PC     !== 8      ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Branch operation failed!");
    $display("\ntb_control_unit--> Test Failed!\n\n");
    $stop();
  end

  opcode_execute     <= 7'b0110011; // R-Type
  branch_execute     <= 1'b0;
  JALR_branch_hazard <= 1'b0;

  // Load Word
  opcode_decode <= 7'b0000011;
  funct3 <= 3'b010;
  funct7 <= 7'b0000000; // imm
  repeat (1) @ (posedge clock);

  if( branch_op     !== 1'b0   |
      memRead       !== 1'b1   |
      ALU_operation !== 6'd0   |
      memWrite      !== 1'b0   |
      log2_bytes    !== 2'b10  |
      unsigned_load !== 1'b0   |
      next_PC_sel   !== 2'b00  |
      operand_A_sel !== 2'b00  |
      operand_B_Sel !== 1'b1   |
      extend_sel    !== 2'b00  |
      regWrite      !== 1'b1   ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Load operation failed!");
    $display("\ntb_control_unit--> Test Failed!\n\n");
    $stop();
  end

  // Store Word
  opcode_decode <= 7'b0100011;
  funct3 <= 3'b010;
  funct7 <= 7'b0000000;
  repeat (1) @ (posedge clock);

  if( branch_op     !== 1'b0   |
      memRead       !== 1'b0   |
      ALU_operation !== 6'd0   |
      memWrite      !== 1'b1   |
      log2_bytes    !== 2'b10  |
      unsigned_load !== 1'b0   |
      next_PC_sel   !== 2'b00  |
      operand_A_sel !== 2'b00  |
      operand_B_Sel !== 1'b1   |
      extend_sel    !== 2'b01  |
      regWrite      !== 1'b0   ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Store operation failed!");
    $display("\ntb_control_unit--> Test Failed!\n\n");
    $stop();
  end

  opcode_decode <= 7'b1101111; // JAL
  JAL_hazard    <= 1'b1;
  funct3 <= 3'b000; // imm
  funct7 <= 7'b0000000; // imm
  repeat (1) @ (posedge clock);

  if( branch_op     !== 1'b0   |
      memRead       !== 1'b0   |
      ALU_operation !== 6'd1   |
      memWrite      !== 1'b0   |
      log2_bytes    !== 2'b00  |
      unsigned_load !== 1'b0   |
      next_PC_sel   !== 2'b10  |
      operand_A_sel !== 2'b10  |
      operand_B_Sel !== 1'b0   |
      extend_sel    !== 2'b00  |
      regWrite      !== 1'b1   |
      target_PC     !== 12     ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: JAL operation failed!");
    $display("\ntb_control_unit--> Test Failed!\n\n");
    $stop();
  end

  JAL_hazard    <= 1'b0;
  opcode_decode <= 7'b0110011;
  repeat (1) @ (posedge clock);

  if( branch_op     !== 1'b0   |
      memRead       !== 1'b0   |
      ALU_operation !== 6'd0   |
      memWrite      !== 1'b0   |
      log2_bytes    !== 2'b00  |
      unsigned_load !== 1'b0   |
      next_PC_sel   !== 2'b00  |
      operand_A_sel !== 2'b00  |
      operand_B_Sel !== 1'b0   |
      extend_sel    !== 2'b00  |
      regWrite      !== 1'b1   ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: R-Type operation failed!");
    $display("\ntb_control_unit--> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_control_unit--> Test Passed!\n\n");
  $stop();

end

endmodule
