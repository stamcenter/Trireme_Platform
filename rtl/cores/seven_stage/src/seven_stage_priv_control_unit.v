/** @module : seven_stage_priv_control_unit
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

module seven_stage_priv_control_unit #(
  parameter CORE            = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter NUM_BYTES       = DATA_WIDTH/8,
  parameter M_EXTENSION     = "False",
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
  input store_memory_receive, // memWrite_memory_receive
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
  output flush_memory_issue,
  output flush_memory_receive,
  output flush_writeback,

  // Seven Stage Bypass Unit Ports
  output [2:0] rs1_data_bypass,
  output [2:0] rs2_data_bypass,

  // CSR & Privilege Control Ports
  input [1:0] priv,
  input       intr_branch,
  input       trap_branch,

  input [ADDRESS_BITS-1:0] inst_PC_fetch_receive,
  input [ADDRESS_BITS-1:0] inst_PC_decode,
  input [ADDRESS_BITS-1:0] inst_PC_execute,
  input [ADDRESS_BITS-1:0] inst_PC_memory_issue,
  input [ADDRESS_BITS-1:0] inst_PC_memory_receive,

  input m_ret_memory_receive,
  input s_ret_memory_receive,
  input u_ret_memory_receive,

  input i_mem_page_fault,
  input i_mem_access_fault,
  input d_mem_page_fault,
  input d_mem_access_fault,

  input exception,

  output exception_fetch_receive,
  output exception_decode,
  output exception_execute,
  output exception_memory_issue,
  output exception_memory_receive,

  output [3:0] exception_code_fetch_receive,
  output [3:0] exception_code_decode,
  output [3:0] exception_code_execute,
  output [3:0] exception_code_memory_issue,
  output [3:0] exception_code_memory_receive,

  output m_ret_decode,
  output s_ret_decode,
  output u_ret_decode,

  output [ADDRESS_BITS-1:0] trap_PC,

  output CSR_read_en,
  output CSR_write_en,
  output CSR_set_en,
  output CSR_clear_en,

  output solo_instr_decode, // generated here
  input  solo_instr_execute,
  input  solo_instr_memory_issue,
  input  solo_instr_memory_receive,
  input  solo_instr_writeback,

  // TLB invalidate signals from sfence.vma
  output       tlb_invalidate,
  output [1:0] tlb_invalidate_mode,

  // Multi-Cycle Execute Unit Control Signals
  input execute_valid_result,

  // New Ports
  input [4:0] rs1,
  input [4:0] rs2,
  input [4:0] rd, // for csrs
  input [4:0] rd_execute,
  input [4:0] rd_memory_issue,
  input [4:0] rd_memory_receive,
  input [4:0] rd_writeback,
  input regWrite_execute,
  input regWrite_memory_issue,
  input regWrite_memory_receive,
  input regWrite_writeback,
  input issue_request,
  output store_memory_issue_allowed,

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
                JAL     = 7'b1101111,
                SYSTEM  = 7'b1110011,
                AMO     = 7'b0101111;

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
wire rs1_system_hazard_execute;
wire rs1_system_hazard_memory_issue;
wire rs1_system_hazard_memory_receive;
wire rs1_true_hazard;

wire rs2_hazard_execute;
wire rs2_hazard_memory_issue;
wire rs2_hazard_memory_receive;
wire rs2_hazard_writeback;

wire rs2_load_hazard_execute;
wire rs2_load_hazard_memory_issue;
wire rs2_load_hazard_memory_receive;
wire rs2_system_hazard_execute;
wire rs2_system_hazard_memory_issue;
wire rs2_system_hazard_memory_receive;
wire rs2_true_hazard;

wire load_opcode_in_execute;
wire load_opcode_in_memory_issue;
wire load_opcode_in_memory_receive;
wire system_opcode_in_execute;
wire system_opcode_in_memory_issue;
wire system_opcode_in_memory_receive;

wire d_mem_issue_hazard_base;
wire d_mem_recv_hazard_base;
wire i_mem_issue_hazard_base;
wire i_mem_recv_hazard_base;
wire JALR_branch_hazard_base;
wire JAL_hazard_base;
wire solo_instr_hazard_base;

wire true_data_hazard;
wire execute_invalid_hazard;
wire d_mem_hazard;
wire d_mem_issue_hazard;
wire d_mem_recv_hazard;
wire i_mem_hazard;
wire i_mem_issue_hazard;
wire i_mem_recv_hazard;
wire JALR_branch_hazard;
wire JAL_hazard;
wire solo_instr_hazard;
wire clog;
wire redo_fetch;

// Outputs from the base control module that get passed into another module
wire [5:0] ALU_operation_base;
//wire [1:0] next_PC_sel_base;
wire [1:0] operand_A_sel_base;
wire       operand_B_sel_base;
wire [1:0] extend_sel_base;
wire       regWrite_base;

// Outputs from the m_control module that get passed into another module
wire [5:0] ALU_operation_mul;

// Outputs from the CSR control module that get passed into another module
wire CSR_read_en_base;
wire CSR_write_en_base;
wire CSR_set_en_base;
wire CSR_clear_en_base;

wire i_mem_read_base;

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
                      (opcode_decode == OP_32 ) |
                      (opcode_decode == SYSTEM) |
                      (opcode_decode == AMO   );

    assign rs2_read = (opcode_decode == R_TYPE) |
                      (opcode_decode == STORE ) |
                      (opcode_decode == BRANCH) |
                      (opcode_decode == OP_32 ) |
                      (opcode_decode == AMO   );
  end
  else begin
    assign rs1_read = (opcode_decode == R_TYPE) |
                      (opcode_decode == I_TYPE) |
                      (opcode_decode == STORE ) |
                      (opcode_decode == LOAD  ) |
                      (opcode_decode == BRANCH) |
                      (opcode_decode == JALR  ) |
                      (opcode_decode == SYSTEM) |
                      (opcode_decode == AMO   );

    assign rs2_read = (opcode_decode == R_TYPE) |
                      (opcode_decode == STORE ) |
                      (opcode_decode == BRANCH) |
                      (opcode_decode == AMO   );

  end
endgenerate

// Detect data hazards between decode and other stages
assign load_opcode_in_execute        = (opcode_execute        == LOAD) | (opcode_execute        == AMO);
assign load_opcode_in_memory_issue   = (opcode_memory_issue   == LOAD) | (opcode_memory_issue   == AMO);
assign load_opcode_in_memory_receive = (opcode_memory_receive == LOAD) | (opcode_memory_receive == AMO);

assign system_opcode_in_execute        = opcode_execute        == SYSTEM;
assign system_opcode_in_memory_issue   = opcode_memory_issue   == SYSTEM;
assign system_opcode_in_memory_receive = opcode_memory_receive == SYSTEM;

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

assign rs1_system_hazard_execute        = rs1_hazard_execute        & system_opcode_in_execute;
assign rs1_system_hazard_memory_issue   = rs1_hazard_memory_issue   & system_opcode_in_memory_issue;
assign rs1_system_hazard_memory_receive = rs1_hazard_memory_receive & system_opcode_in_memory_receive;

assign rs1_true_hazard = rs1_load_hazard_execute        |
                         rs1_load_hazard_memory_issue   |
                         rs1_load_hazard_memory_receive |
                         rs1_system_hazard_execute        |
                         rs1_system_hazard_memory_issue   |
                         rs1_system_hazard_memory_receive ;


assign rs2_load_hazard_execute        = rs2_hazard_execute        & load_opcode_in_execute;
assign rs2_load_hazard_memory_issue   = rs2_hazard_memory_issue   & load_opcode_in_memory_issue;
assign rs2_load_hazard_memory_receive = rs2_hazard_memory_receive & load_opcode_in_memory_receive;

assign rs2_system_hazard_execute        = rs2_hazard_execute        & system_opcode_in_execute;
assign rs2_system_hazard_memory_issue   = rs2_hazard_memory_issue   & system_opcode_in_memory_issue;
assign rs2_system_hazard_memory_receive = rs2_hazard_memory_receive & system_opcode_in_memory_receive;


assign rs2_true_hazard = rs2_load_hazard_execute       |
                         rs2_load_hazard_memory_issue  |
                         rs2_load_hazard_memory_receive|
                         rs2_system_hazard_execute        |
                         rs2_system_hazard_memory_issue   |
                         rs2_system_hazard_memory_receive ;

assign true_data_hazard = rs1_true_hazard | rs2_true_hazard;
assign execute_invalid_hazard = ~execute_valid_result;

assign i_mem_hazard = i_mem_issue_hazard | i_mem_recv_hazard;
assign d_mem_hazard = d_mem_issue_hazard | d_mem_recv_hazard;

assign target_PC = (opcode_execute == JALR)                    ? JALR_target_execute   :
                   (opcode_execute == BRANCH) & branch_execute ? branch_target_execute :
                   (opcode_decode  == JAL)                     ? JAL_target_decode     :
                   redo_fetch                                  ? issue_PC              :
                   {ADDRESS_BITS{1'b0}};

assign next_PC_sel = JALR_branch_hazard      ? 2'b10 : // target_PC
                     true_data_hazard & clog ? 2'b10 : // target_PC
                     execute_invalid_hazard & clog ? 2'b10 : // target_PC
                     true_data_hazard        ? 2'b01 : // stall
                     execute_invalid_hazard  ? 2'b01 : // stall
                     JAL_hazard              ? 2'b10 : // target_PC
                     solo_instr_hazard & redo_fetch ? 2'b10 : //target_PC
                     solo_instr_hazard       ? 2'b01 : // stall
                     i_mem_hazard            ? 2'b01 : // stall
                     d_mem_hazard & clog     ? 2'b10 : // target_PC
                     d_mem_hazard            ? 2'b01 : // stall
                     2'b00;                            // PC + 4

assign clog = stall_decode & issue_request & fetch_valid & (issue_PC == fetch_address_in);

// Re-fetch the PC in the Fetch Receive stage if the clog signal is high, or
// there is a solo instruction in decode AND the PC in fetch receive is not
// the 0x1 bubble PC value
assign redo_fetch = clog | (solo_instr_decode & ~issue_PC[0]);

// Disable writes if an exception is in this stage or the next one.
assign store_memory_issue_allowed = store_memory_issue & ~trap_branch;

// Dont read PC values while a solo instruction is in the pipeline. If the
// privilege mode is changed, an early read could cause a page fault.
assign i_mem_read = i_mem_read_base & ~solo_instr_hazard;

hazard_detection_unit_priv #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) PRIV_HAZARD_UNIT (
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

  .solo_instr_decode(solo_instr_decode),
  .solo_instr_execute(solo_instr_execute),
  .solo_instr_memory_issue(solo_instr_memory_issue),
  .solo_instr_memory_receive(solo_instr_memory_receive),
  .solo_instr_writeback(solo_instr_writeback),

  .i_mem_page_fault(i_mem_page_fault),
  .i_mem_access_fault(i_mem_access_fault),
  .d_mem_page_fault(d_mem_page_fault),
  .d_mem_access_fault(d_mem_access_fault),

  .i_mem_issue_hazard(i_mem_issue_hazard),
  .i_mem_recv_hazard(i_mem_recv_hazard),
  .d_mem_issue_hazard(d_mem_issue_hazard),
  .d_mem_recv_hazard(d_mem_recv_hazard),
  .JALR_branch_hazard(JALR_branch_hazard),
  .JAL_hazard(JAL_hazard),
  .solo_instr_hazard(solo_instr_hazard),

  .scan(scan)
);

seven_stage_priv_stall_unit #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) STALL_UNIT (
  .clock(clock),
  .reset(reset),
  .true_data_hazard(true_data_hazard),
  .execute_invalid_hazard(execute_invalid_hazard),
  .d_mem_issue_hazard(d_mem_issue_hazard),
  .d_mem_recv_hazard(d_mem_recv_hazard),
  .i_mem_issue_hazard(i_mem_issue_hazard),
  .i_mem_recv_hazard(i_mem_recv_hazard),
  .JALR_branch_hazard(JALR_branch_hazard),
  .JAL_hazard(JAL_hazard),
  .trap_hazard(trap_branch),
  .solo_instr_hazard(solo_instr_hazard),

  .clog(clog),

  .stall_fetch_receive(stall_fetch_receive),
  .stall_decode(stall_decode),
  .stall_execute(stall_execute),
  .stall_memory_issue(stall_memory_issue),
  .stall_memory_receive(stall_memory_receive),

  .flush_fetch_receive(flush_fetch_receive),
  .flush_decode(flush_decode),
  .flush_execute(flush_execute),
  .flush_memory_issue(flush_memory_issue),
  .flush_memory_receive(flush_memory_receive),
  .flush_writeback(flush_writeback),

  .scan(scan)
);

seven_stage_bypass_unit #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) BYPASS_UNIT (
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



CSR_control #(
  .CORE(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) CSR_CTRL (
  .clock(clock),
  .reset(reset),

  .opcode_decode(opcode_decode),
  .funct3(funct3), // decode
  .rs1(rs1),
  .rd(rd),
  .extend_sel_base(extend_sel_base),
  .operand_A_sel_base(operand_A_sel_base),
  .operand_B_sel_base(operand_B_sel_base),
  .ALU_operation_base(ALU_operation_mul),
  .regWrite_base(regWrite_base),

  .CSR_read_en(CSR_read_en_base),
  .CSR_write_en(CSR_write_en_base),
  .CSR_set_en(CSR_set_en_base),
  .CSR_clear_en(CSR_clear_en_base),

  .extend_sel(extend_sel),
  .operand_A_sel(operand_A_sel),
  .operand_B_sel(operand_B_sel),
  .ALU_operation(ALU_operation),
  .regWrite(), // Use the priv_control signal instead

  .scan(scan)
);


priv_control #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) PRIV_CTRL (
  .clock(clock),
  .reset(reset),
  .opcode_decode(opcode_decode),
  .funct3(funct3), // decode
  .funct7(funct7), // decode

  .rs1(rs1), // decode
  .rs2(rs2), // decode

  .priv(priv),
  .intr_branch(intr_branch),
  .trap_branch(trap_branch),

  .load_memory_receive(load_memory_receive),
  .store_memory_receive(store_memory_receive),

  .issue_PC(issue_PC),
  .inst_PC_fetch_receive(inst_PC_fetch_receive),
  .inst_PC_decode(inst_PC_decode),
  .inst_PC_execute(inst_PC_execute),
  .inst_PC_memory_issue(inst_PC_memory_issue),
  .inst_PC_memory_receive(inst_PC_memory_receive),

  .CSR_read_en_base(CSR_read_en_base),
  .CSR_write_en_base(CSR_write_en_base),
  .CSR_set_en_base(CSR_set_en_base),
  .CSR_clear_en_base(CSR_clear_en_base),
  .regWrite_base(regWrite_base),
  // The priviledge level required to access a CSR (CSR_addr[9:8])
  .CSR_priv_level(funct7[4:3]),

  .m_ret_memory_receive(m_ret_memory_receive),
  .s_ret_memory_receive(s_ret_memory_receive),
  .u_ret_memory_receive(u_ret_memory_receive),

  .i_mem_page_fault(i_mem_page_fault),
  .i_mem_access_fault(i_mem_access_fault),
  .d_mem_page_fault(d_mem_page_fault),
  .d_mem_access_fault(d_mem_access_fault),

  .is_emulated_instruction(1'b0),
  .exception(exception),

  .exception_fetch_receive(exception_fetch_receive),
  .exception_decode(exception_decode),
  .exception_execute(exception_execute),
  .exception_memory_issue(exception_memory_issue),
  .exception_memory_receive(exception_memory_receive),

  .exception_code_fetch_receive(exception_code_fetch_receive),
  .exception_code_decode(exception_code_decode),
  .exception_code_execute(exception_code_execute),
  .exception_code_memory_issue(exception_code_memory_issue),
  .exception_code_memory_receive(exception_code_memory_receive),

  .m_ret_decode(m_ret_decode),
  .s_ret_decode(s_ret_decode),
  .u_ret_decode(u_ret_decode),

  .trap_PC(trap_PC),

  .CSR_read_en(CSR_read_en),
  .CSR_write_en(CSR_write_en),
  .CSR_set_en(CSR_set_en),
  .CSR_clear_en(CSR_clear_en),
  .regWrite(regWrite),

  // TLB invalidate signals from sfence.vma
  .tlb_invalidate(tlb_invalidate),
  .tlb_invalidate_mode(tlb_invalidate_mode),

  .scan(scan)
);

generate
  if(M_EXTENSION == "True") begin
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
      .ALU_operation(ALU_operation_mul),
      .scan(scan)
    );
  end
  else begin
    assign ALU_operation_mul = ALU_operation_base;
  end
endgenerate

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
    ) CONTROL (
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
      .ALU_operation(ALU_operation_base),
      .memWrite(memWrite),
      .log2_bytes(log2_bytes),
      .unsigned_load(unsigned_load),
      //.next_PC_sel(next_PC_sel),
      .next_PC_sel(), // Logic differs from base module
      .operand_A_sel(operand_A_sel_base),
      .operand_B_sel(operand_B_sel_base),
      .extend_sel(extend_sel_base),
      .regWrite(regWrite_base),

      .solo_instr_decode(solo_instr_decode),

      //.target_PC(target_PC),
      .target_PC(), // Logic differs from base module
      .i_mem_read(i_mem_read_base),

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
    ) CONTROL (
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
      .ALU_operation(ALU_operation_base),
      .memWrite(memWrite),
      .log2_bytes(log2_bytes),
      .unsigned_load(unsigned_load),
      //.next_PC_sel(next_PC_sel),
      .next_PC_sel(), // Logic differs from base module
      .operand_A_sel(operand_A_sel_base),
      .operand_B_sel(operand_B_sel_base),
      .extend_sel(extend_sel_base),
      .regWrite(regWrite_base),

      .solo_instr_decode(solo_instr_decode),

      //.target_PC(target_PC),
      .target_PC(), // Logic differs from base module
      .i_mem_read(i_mem_read_base),

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
