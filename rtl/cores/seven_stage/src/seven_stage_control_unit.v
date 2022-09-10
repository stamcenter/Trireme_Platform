/** @module : seven_stage_control_unit
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

module seven_stage_control_unit #(
  parameter CORE            = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter NUM_BYTES       = DATA_WIDTH/8,
  parameter LOG2_NUM_BYTES  = log2(NUM_BYTES),
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  // Base Control Unit Ports
  input clock,
  input reset,
  input [6:0] opcode_decode,
  input [6:0] opcode_execute,
  input [6:0] opcode_memory_issue,
  input [6:0] opcode_memory_receive,
  input [2:0] funct3, // decode
  input [6:0] funct7, // decode

  input [ADDRESS_BITS-1:0] JALR_target_execute,
  input [ADDRESS_BITS-1:0] branch_target_execute,
  input [ADDRESS_BITS-1:0] JAL_target_decode,
  input branch_execute,

  output branch_op,
  output memRead,
  output [5:0] ALU_operation,
  output memWrite,
  output [LOG2_NUM_BYTES-1:0] log2_bytes,
  output unsigned_load,
  output [1:0] next_PC_sel,
  output [1:0] operand_A_sel,
  output operand_B_sel,
  output [1:0] extend_sel,
  output regWrite,

  output [ADDRESS_BITS-1:0] target_PC,
  output i_mem_read,

  // Base Hazard Detection Unit Ports
  input fetch_valid,
  input fetch_ready,
  input [ADDRESS_BITS-1:0] issue_PC,
  input [ADDRESS_BITS-1:0] fetch_address_in,
  input memory_valid,
  input memory_ready,

  input load_memory_receive, // memRead_memory_receive
  input store_memory_issue, // memWrite_memory_issue
  input [ADDRESS_BITS-1:0] load_address_receive,
  input [ADDRESS_BITS-1:0] memory_address_in,

  // Seven Stage Stall Unit Ports
  output stall_fetch_receive,
  output stall_decode,
  output stall_execute,
  output stall_memory_issue,
  output stall_memory_receive,

  output flush_fetch_receive,
  output flush_decode,
  output flush_execute,
  output flush_memory_receive,
  output flush_writeback,

  // Seven Stage Bypass Unit Ports
  output [2:0] rs1_data_bypass,
  output [2:0] rs2_data_bypass,

  // New Ports
  input [4:0] rs1,
  input [4:0] rs2,
  input [4:0] rd_execute,
  input [4:0] rd_memory_issue,
  input [4:0] rd_memory_receive,
  input [4:0] rd_writeback,
  input regWrite_execute,
  input regWrite_memory_issue,
  input regWrite_memory_receive,
  input regWrite_writeback,
  input issue_request,

  input scan
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


localparam[6:0] R_TYPE  = 7'b0110011,
                I_TYPE  = 7'b0010011,
                STORE   = 7'b0100011,
                LOAD    = 7'b0000011,
                BRANCH  = 7'b1100011,
                JALR    = 7'b1100111,
                JAL     = 7'b1101111;

// RV64 Opcodes
localparam [6:0]IMM_32 = 7'b0011011,
                OP_32  = 7'b0111011;


wire rs1_read;
wire rs2_read;

wire rs1_hazard_execute;
wire rs1_hazard_memory_issue;
wire rs1_hazard_memory_receive;
wire rs1_hazard_writeback;

wire rs1_load_hazard_execute;
wire rs1_load_hazard_memory_issue;
wire rs1_load_hazard_memory_receive;
wire rs1_true_hazard;

wire rs2_hazard_execute;
wire rs2_hazard_memory_issue;
wire rs2_hazard_memory_receive;
wire rs2_hazard_writeback;

wire rs2_load_hazard_execute;
wire rs2_load_hazard_memory_issue;
wire rs2_load_hazard_memory_receive;
wire rs2_true_hazard;

wire load_opcode_in_execute;
wire load_opcode_in_memory_issue;
wire load_opcode_in_memory_receive;

wire true_data_hazard;
wire d_mem_hazard;
wire d_mem_issue_hazard;
wire d_mem_recv_hazard;
wire i_mem_hazard;
wire i_mem_issue_hazard;
wire i_mem_recv_hazard;
wire JALR_branch_hazard;
wire JAL_hazard;
wire clog;

// New Control logic
generate
  if(DATA_WIDTH == 64) begin
    assign rs1_read = (opcode_decode == R_TYPE) |
                      (opcode_decode == I_TYPE) |
                      (opcode_decode == STORE ) |
                      (opcode_decode == LOAD  ) |
                      (opcode_decode == BRANCH) |
                      (opcode_decode == JALR  ) |
                      (opcode_decode == IMM_32) |
                      (opcode_decode == OP_32 );

    assign rs2_read = (opcode_decode == R_TYPE) |
                      (opcode_decode == STORE ) |
                      (opcode_decode == BRANCH) |
                      (opcode_decode == OP_32 );
  end
  else begin
    assign rs1_read = (opcode_decode == R_TYPE) |
                      (opcode_decode == I_TYPE) |
                      (opcode_decode == STORE ) |
                      (opcode_decode == LOAD  ) |
                      (opcode_decode == BRANCH) |
                      (opcode_decode == JALR  );

    assign rs2_read = (opcode_decode == R_TYPE) |
                      (opcode_decode == STORE ) |
                      (opcode_decode == BRANCH);

  end
endgenerate

// Detect data hazards between decode and other stages
assign load_opcode_in_execute        = opcode_execute        == LOAD;
assign load_opcode_in_memory_issue   = opcode_memory_issue   == LOAD;
assign load_opcode_in_memory_receive = opcode_memory_receive == LOAD;

assign rs1_hazard_execute        = (rs1 == rd_execute       ) & rs1_read & (rs1 != 5'd0) & regWrite_execute;
assign rs1_hazard_memory_issue   = (rs1 == rd_memory_issue  ) & rs1_read & (rs1 != 5'd0) & regWrite_memory_issue;
assign rs1_hazard_memory_receive = (rs1 == rd_memory_receive) & rs1_read & (rs1 != 5'd0) & regWrite_memory_receive;
assign rs1_hazard_writeback      = (rs1 == rd_writeback     ) & rs1_read & (rs1 != 5'd0) & regWrite_writeback;

assign rs2_hazard_execute        = (rs2 == rd_execute   )     & rs2_read & (rs2 != 5'd0) & regWrite_execute;
assign rs2_hazard_memory_issue   = (rs2 == rd_memory_issue  ) & rs2_read & (rs2 != 5'd0) & regWrite_memory_issue;
assign rs2_hazard_memory_receive = (rs2 == rd_memory_receive) & rs2_read & (rs2 != 5'd0) & regWrite_memory_receive;
assign rs2_hazard_writeback      = (rs2 == rd_writeback )     & rs2_read & (rs2 != 5'd0) & regWrite_writeback;

assign rs1_load_hazard_execute        = rs1_hazard_execute        & load_opcode_in_execute;
assign rs1_load_hazard_memory_issue   = rs1_hazard_memory_issue   & load_opcode_in_memory_issue;
assign rs1_load_hazard_memory_receive = rs1_hazard_memory_receive & load_opcode_in_memory_receive;

assign rs1_true_hazard = rs1_load_hazard_execute        |
                         rs1_load_hazard_memory_issue   |
                         rs1_load_hazard_memory_receive ;

assign rs2_load_hazard_execute        = rs2_hazard_execute        & load_opcode_in_execute;
assign rs2_load_hazard_memory_issue   = rs2_hazard_memory_issue   & load_opcode_in_memory_issue;
assign rs2_load_hazard_memory_receive = rs2_hazard_memory_receive & load_opcode_in_memory_receive;

assign rs2_true_hazard = rs2_load_hazard_execute       |
                         rs2_load_hazard_memory_issue  |
                         rs2_load_hazard_memory_receive;

assign true_data_hazard = rs1_true_hazard | rs2_true_hazard;

assign d_mem_hazard = d_mem_issue_hazard | d_mem_recv_hazard;
assign i_mem_hazard = i_mem_issue_hazard | i_mem_recv_hazard;

assign target_PC = (opcode_execute == JALR)                    ? JALR_target_execute   :
                   (opcode_execute == BRANCH) & branch_execute ? branch_target_execute :
                   (opcode_decode  == JAL)                     ? JAL_target_decode     :
                   clog                                        ? issue_PC              :
                   {ADDRESS_BITS{1'b0}};

assign next_PC_sel = JALR_branch_hazard      ? 2'b10 : // target_PC
                     true_data_hazard & clog ? 2'b10 : // target_PC
                     true_data_hazard        ? 2'b01 : // stall
                     JAL_hazard              ? 2'b10 : // targeet_PC
                     i_mem_hazard            ? 2'b01 : // stall
                     d_mem_hazard & clog     ? 2'b10 : // target_PC
                     d_mem_hazard            ? 2'b01 : // stall
                     2'b00;                            // PC + 4

assign clog = stall_decode & issue_request & fetch_valid & (issue_PC == fetch_address_in);

hazard_detection_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) base_hazard_unit (
  .clock(clock),
  .reset(reset),
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .issue_request(issue_request),
  .issue_PC(issue_PC),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),

  .load_memory(load_memory_receive),
  .store_memory(store_memory_issue),
  .load_address(load_address_receive),
  .memory_address_in(memory_address_in),

  .opcode_decode(opcode_decode),
  .opcode_execute(opcode_execute),
  .branch_execute(branch_execute),

  // No solo instructions for non-priviledged cores
  .solo_instr_decode(1'b0),
  .solo_instr_execute(1'b0),
  .solo_instr_memory_issue(1'b0),
  .solo_instr_memory_receive(1'b0),
  .solo_instr_writeback(1'b0),

  .i_mem_issue_hazard(i_mem_issue_hazard),
  .i_mem_recv_hazard(i_mem_recv_hazard),
  .d_mem_issue_hazard(d_mem_issue_hazard),
  .d_mem_recv_hazard(d_mem_recv_hazard),
  .JALR_branch_hazard(JALR_branch_hazard),
  .JAL_hazard(JAL_hazard),
  .solo_instr_hazard(),

  .scan(scan)
);


seven_stage_stall_unit #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) stall_unit (
  .clock(clock),
  .reset(reset),
  .execute_invalid_hazard(1'b0),
  .true_data_hazard(true_data_hazard),
  .d_mem_issue_hazard(d_mem_issue_hazard),
  .d_mem_recv_hazard(d_mem_recv_hazard),
  .i_mem_issue_hazard(i_mem_issue_hazard),
  .i_mem_recv_hazard(i_mem_recv_hazard),
  .JALR_branch_hazard(JALR_branch_hazard),
  .JAL_hazard(JAL_hazard),

  .clog(clog),

  .stall_fetch_receive(stall_fetch_receive),
  .stall_decode(stall_decode),
  .stall_execute(stall_execute),
  .stall_memory_issue(stall_memory_issue),
  .stall_memory_receive(stall_memory_receive),

  .flush_fetch_receive(flush_fetch_receive),
  .flush_decode(flush_decode),
  .flush_execute(flush_execute),
  .flush_memory_issue(),
  .flush_memory_receive(flush_memory_receive),
  .flush_writeback(flush_writeback),

  .scan(scan)
);

seven_stage_bypass_unit #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) bypass_unit (
  .clock(clock),
  .reset(reset),

  .true_data_hazard(true_data_hazard),

  .rs1_hazard_execute(rs1_hazard_execute),
  .rs1_hazard_memory_issue(rs1_hazard_memory_issue),
  .rs1_hazard_memory_receive(rs1_hazard_memory_receive),
  .rs1_hazard_writeback(rs1_hazard_writeback),

  .rs2_hazard_execute(rs2_hazard_execute),
  .rs2_hazard_memory_issue(rs2_hazard_memory_issue),
  .rs2_hazard_memory_receive(rs2_hazard_memory_receive),
  .rs2_hazard_writeback(rs2_hazard_writeback),

  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),

  .scan(scan)
);


// This could have been done with a macro but as a convention, we use generate
// statements for different 32-bit/64-bit logic
generate
  if(DATA_WIDTH == 64) begin
    control_unit64 #(
      .CORE(CORE),
      .ADDRESS_BITS(ADDRESS_BITS),
      .NUM_BYTES(NUM_BYTES),
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
      .next_PC_sel(), // Logic differs from base module
      .operand_A_sel(operand_A_sel),
      .operand_B_sel(operand_B_sel),
      .extend_sel(extend_sel),
      .regWrite(regWrite),

      .solo_instr_decode(),

      .target_PC(), // Logic differs from base module
      .i_mem_read(i_mem_read),

      .scan(scan)
    );
  end
  else begin
    control_unit #(
      .CORE(CORE),
      .ADDRESS_BITS(ADDRESS_BITS),
      .NUM_BYTES(NUM_BYTES),
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
      .next_PC_sel(), // Logic differs from base module
      .operand_A_sel(operand_A_sel),
      .operand_B_sel(operand_B_sel),
      .extend_sel(extend_sel),
      .regWrite(regWrite),

      .solo_instr_decode(),

      .target_PC(), // Logic differs from base module
      .i_mem_read(i_mem_read),

      .scan(scan)
    );
  end
endgenerate

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Seven Stage Control Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| RS1 Read [%b]", rs1_read);
    $display ("| RS2 Read [%b]", rs1_read);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
