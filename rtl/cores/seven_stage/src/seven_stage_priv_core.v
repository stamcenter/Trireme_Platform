/** @module : seven_stage_priv_core
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

module seven_stage_priv_core #(
  parameter CORE            = 0,
  parameter RESET_PC        = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter SATP_MODE_BITS = DATA_WIDTH == 32 ? 1 : 4,
  parameter ASID_BITS      = DATA_WIDTH == 32 ? 4 : 16,
  parameter PPN_BITS       = DATA_WIDTH == 32 ? 22 : 44,
  parameter NUM_BYTES       = DATA_WIDTH/8,
  parameter M_EXTENSION     = "True",
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input  clock,
  input  reset,
  input  start,
  input  [ADDRESS_BITS-1:0] program_address,
  //memory interface
  input  fetch_valid,
  input  fetch_ready,
  input  [DATA_WIDTH-1  :0] fetch_data_in,
  input  [ADDRESS_BITS-1:0] fetch_address_in,
  input  memory_valid,
  input  memory_ready,
  input  [DATA_WIDTH-1  :0] memory_data_in,
  input  [ADDRESS_BITS-1:0] memory_address_in,
  output fetch_read,
  output [ADDRESS_BITS-1:0] fetch_address_out,
  output memory_read,
  output memory_write,
  output [NUM_BYTES-1:   0] memory_byte_en,
  output [ADDRESS_BITS-1:0] memory_address_out,
  output [DATA_WIDTH-1  :0] memory_data_out,
  // Exception/Interrupt Trap Signals
  input m_ext_interrupt,
  input s_ext_interrupt,
  input software_interrupt,
  input timer_interrupt,
  input i_mem_page_fault,
  input i_mem_access_fault,
  input d_mem_page_fault,
  input d_mem_access_fault,

  // Privilege CSRs for Virtual Memory
  output [PPN_BITS-1      :0] PT_base_PPN, // from satp register
  output [ASID_BITS-1     :0] ASID,        // from satp register
  output [1               :0] priv,        // current privilege level
  output [1               :0] MPP,         // from mstatus register
  output [SATP_MODE_BITS-1:0] MODE,        // paging mode
  output                      SUM,         // permit Supervisor User Memory access
  output                      MXR,         // Make eXecutable Readable
  output                      MPRV,        // Modify PRiVilege

  // TLB invalidate signals from sfence.vma
  output       tlb_invalidate,
  output [1:0] tlb_invalidate_mode,

  //scan signal
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

localparam LOG2_NUM_BYTES  = log2(NUM_BYTES);

// Pipe Parameters
localparam FETCH_RECEIVE_PIPE_WIDTH = ADDRESS_BITS // issue_PC
                                   + 1;           // issue_request

localparam DECODE_PIPE_WIDTH = 32             // instruction
                             + ADDRESS_BITS   // inst_pc
                             + 1              // exception
                             + 4;             // exception_code


localparam EXECUTE_PIPE_WIDTH = ADDRESS_BITS   // inst_PC
                              + DATA_WIDTH     // rs1_data
                              + DATA_WIDTH     // rs2_data
                              + 5              // rd
                              + DATA_WIDTH     // extend_imm
                              + ADDRESS_BITS   // branch_target
                              + 1              // branch_op
                              + 1              // memRead
                              + 6              // ALU_operation
                              + 1              // memWrite
                              + LOG2_NUM_BYTES // log2_bytes
                              + 1              // unsigned_load
                              + 2              // operand_A_sel
                              + 1              // operand_B_sel
                              + 1              // regWrite
                              + 1              // solo_instr
                              + 7              // opcode
                              + 3              // [m|s|u]_ret
                              + 4              // CSR_[read|write|set|clear]_en
                              + 12             // CSR_address
                              + 1              // tlb_invalidate
                              + 2              // tlb_invalidate_mode
                              + 1              // exception
                              + 4;             // exception_code

localparam MEMORY_ISSUE_PIPE_WIDTH = 1              // load // memRead,
                                   + 1              // store // memWrite,
                                   + LOG2_NUM_BYTES // log2_bytes
                                   + 1              // unsigned_load
                                   + ADDRESS_BITS   // generated_address,
                                   + DATA_WIDTH     // rs2_data
                                   + 1              // regWrite_memory_issue,
                                   + 1              // solo_instr
                                   + 5              // rd_memory_issue,
                                   + DATA_WIDTH     // ALU_result_memory,
                                   + 7              // opcode
                                   + 3              // [m|s|u]_ret
                                   + 4              // CSR_[read|write|set|clear]_en
                                   + 12             // CSR_address
                                   + 1              // tlb_invalidate
                                   + 2              // tlb_invalidate_mode
                                   + ADDRESS_BITS   // inst_PC
                                   + 1              // exception
                                   + 4;             // exception_code

localparam MEMORY_RECEIVE_PIPE_WIDTH = 1             // load //memRead_memory_receive
                                    + 1              // store //memWrite_memory_receive
                                    + ADDRESS_BITS   // load address
                                    + DATA_WIDTH     // ALU_result
                                    + 1              // regWrite
                                    + 1              // solo_instr
                                    + LOG2_NUM_BYTES // log2_bytes
                                    + 1              // unsigned_load
                                    + 5              // rd
                                    + 7              // opcode
                                    + 3              // [m|s|u]_ret
                                    + 4              // CSR_[read|write|set|clear]_en
                                    + 12             // CSR_address
                                    + ADDRESS_BITS   // inst_PC
                                    + 1              // exception
                                    + 4;             // exception_code

localparam WRITEBACK_PIPE_WIDTH = 1             // regWrite_writeback
                                + 1             // solo_instr
                                + 1             // memRead_writeback
                                + 5             // rd_writeback
                                + DATA_WIDTH    // ALU_result_writeback
                                + DATA_WIDTH    // load_data_writeback
                                + 1             // CSR_read_data_valid
                                + DATA_WIDTH;   // CSR_read_data



// Fetch Issue Stage Wires
wire [1:0] next_PC_select;
wire [ADDRESS_BITS-1:0] target_PC;
wire [ADDRESS_BITS-1:0] issue_PC;
wire [ADDRESS_BITS-1:0] trap_target; // The PC to go to on a trap
wire [ADDRESS_BITS-1:0] next_PC; // The PC that was interrupted

// Fetch Receive Stage Wires
wire [ADDRESS_BITS-1:0] inst_PC_fetch_receive;
wire [31:0] instruction_fetch_receive;
wire [ADDRESS_BITS-1:0] issue_PC_fetch_receive;
wire issue_request_fetch_receive;

wire exception_fetch_receive;
wire new_exception_fetch_receive;
wire [3:0] exception_code_fetch_receive;
wire [3:0] new_exception_code_fetch_receive;

// Decode Stage Wires
wire [31:0] instruction_decode;
wire [ADDRESS_BITS-1:0] inst_PC_decode;
wire [1:0] extend_sel_decode;
wire [DATA_WIDTH-1:0] rs1_data_decode;
wire [DATA_WIDTH-1:0] rs2_data_decode;
wire [4:0] rd_decode;
wire [6:0] opcode_decode;
wire [6:0] funct7_decode;
wire [2:0] funct3_decode;
wire [DATA_WIDTH-1:0] extend_imm_decode;
wire [ADDRESS_BITS-1:0] branch_target_decode;
wire [ADDRESS_BITS-1:0] JAL_target_decode;

wire branch_op_decode;
wire memRead_decode;
wire [5:0] ALU_operation_decode;
wire memWrite_decode;
wire [LOG2_NUM_BYTES-1:0] log2_bytes_decode;
wire unsigned_load_decode;
wire [1:0] operand_A_sel_decode;
wire operand_B_sel_decode;
wire regWrite_decode;

wire solo_instr_decode;
wire solo_instr_execute;
wire solo_instr_memory_issue;
wire solo_instr_memory_receive;
wire solo_instr_writeback;

wire stall_fetch_receive;
wire stall_decode;
wire stall_execute;
wire stall_memory_issue;
wire stall_memory_receive;
wire flush_fetch_receive;
wire flush_decode;
wire flush_execute;
wire flush_memory_issue;
wire flush_memory_receive;
wire flush_writeback;

wire [2:0] rs1_data_bypass;
wire [2:0] rs2_data_bypass;

//wire [1:0] priv;
wire [ADDRESS_BITS-1:0] trap_PC;

wire m_ret_decode;
wire s_ret_decode;
wire u_ret_decode;

wire exception_decode;
wire prev_exception_decode;
wire new_exception_decode;
wire [3:0] exception_code_decode;
wire [3:0] prev_exception_code_decode;
wire [3:0] new_exception_code_decode;

wire CSR_read_en_decode;
wire CSR_write_en_decode;
wire CSR_set_en_decode;
wire CSR_clear_en_decode;
wire [11:0] CSR_address_decode;
wire       tlb_invalidate_decode;
wire [1:0] tlb_invalidate_mode_decode;


// Execute Stage Wires
wire memRead_execute;
wire [5:0] ALU_operation_execute;
wire memWrite_execute;
wire [LOG2_NUM_BYTES-1:0] log2_bytes_execute;
wire unsigned_load_execute;
wire [ADDRESS_BITS-1:0] inst_PC_execute;
wire [1:0] operand_A_sel_execute;
wire operand_B_sel_execute;
wire regWrite_execute;

wire branch_op_execute;
wire [DATA_WIDTH-1:0] rs1_data_execute;
wire [DATA_WIDTH-1:0] rs2_data_execute;
wire [DATA_WIDTH-1:0] extend_imm_execute;

wire branch_execute;
wire [DATA_WIDTH-1:0] ALU_result_execute;
wire [ADDRESS_BITS-1:0] JALR_target_execute;

wire [ADDRESS_BITS-1:0] branch_target_execute;

wire [4:0] rd_execute;
wire [6:0] opcode_execute;
wire [31:0] instruction_execute;

wire [ADDRESS_BITS-1:0] generated_address_execute;


wire m_ret_execute;
wire s_ret_execute;
wire u_ret_execute;

wire exception_execute;
wire prev_exception_execute;
wire new_exception_execute;
wire [3:0] exception_code_execute;
wire [3:0] prev_exception_code_execute;
wire [3:0] new_exception_code_execute;

wire CSR_read_en_execute;
wire CSR_write_en_execute;
wire CSR_set_en_execute;
wire CSR_clear_en_execute;
wire [11:0] CSR_address_execute;

wire       tlb_invalidate_execute;
wire [1:0] tlb_invalidate_mode_execute;


wire execute_ready_i;
wire execute_valid_result_execute;

// Memory Issue Stage Wires
wire memRead_memory_issue;
wire regWrite_memory_issue;
wire memWrite_memory_issue;
wire memWrite_memory_issue_allowed;
wire [LOG2_NUM_BYTES-1:0] log2_bytes_memory_issue;
wire unsigned_load_memory_issue;
wire [ADDRESS_BITS-1:0] generated_address_memory_issue;
wire [DATA_WIDTH-1:0] rs2_data_memory_issue;
wire [DATA_WIDTH-1:0] ALU_result_memory_issue;

wire [4:0] rd_memory_issue;
wire [6:0] opcode_memory_issue;
wire [ADDRESS_BITS-1:0] inst_PC_memory_issue;
wire [31:0] instruction_memory_issue;

wire m_ret_memory_issue;
wire s_ret_memory_issue;
wire u_ret_memory_issue;

wire CSR_read_en_memory_issue;
wire CSR_write_en_memory_issue;
wire CSR_set_en_memory_issue;
wire CSR_clear_en_memory_issue;
wire [11:0] CSR_address_memory_issue;

wire       tlb_invalidate_memory_issue;
wire [1:0] tlb_invalidate_mode_memory_issue;

wire exception_memory_issue;
wire prev_exception_memory_issue;
wire new_exception_memory_issue;
wire [3:0] exception_code_memory_issue;
wire [3:0] prev_exception_code_memory_issue;
wire [3:0] new_exception_code_memory_issue;


// Memory Receive Stage Wires
wire memRead_memory_receive;
wire memWrite_memory_receive;
wire [ADDRESS_BITS-1:0] generated_address_memory_receive;
wire [DATA_WIDTH-1  :0] ALU_result_memory_receive;
wire regWrite_memory_receive;
wire [LOG2_NUM_BYTES-1:0] log2_bytes_memory_receive;
wire unsigned_load_memory_receive;
wire [4:0] rd_memory_receive;
wire [6:0] opcode_memory_receive;
wire [DATA_WIDTH-1:0] load_data_memory_receive;
wire [ADDRESS_BITS-1:0] inst_PC_memory_receive;
wire [31:0] instruction_memory_receive;

wire m_ret_memory_receive;
wire s_ret_memory_receive;
wire u_ret_memory_receive;

wire intr_branch;
wire trap_branch;
wire CSR_read_en_memory_receive;
wire CSR_write_en_memory_receive;
wire CSR_set_en_memory_receive;
wire CSR_clear_en_memory_receive;
wire [11:0] CSR_address_memory_receive;

wire CSR_read_data_valid_memory_receive;
wire [DATA_WIDTH-1:0] CSR_read_data_memory_receive;

wire exception_memory_receive;
wire prev_exception_memory_receive;
wire new_exception_memory_receive;
wire [3:0] exception_code_memory_receive;
wire [3:0] prev_exception_code_memory_receive;
wire [3:0] new_exception_code_memory_receive;


// Writeback Stage Wires
wire regWrite_writeback;
wire memRead_writeback;
wire [4:0] rd_writeback;
wire [DATA_WIDTH-1:0] ALU_result_writeback;
wire [DATA_WIDTH-1:0] load_data_writeback;

wire write_writeback;
wire [4:0] write_reg_writeback;
wire [DATA_WIDTH-1:0] write_data_writeback;
wire [31:0] instruction_writeback;

wire CSR_read_data_valid_writeback;
wire [DATA_WIDTH-1:0] CSR_read_data_writeback;


// Pipe Wires
wire [FETCH_RECEIVE_PIPE_WIDTH-1:0] fetch_receive_pipe_input;
wire [FETCH_RECEIVE_PIPE_WIDTH-1:0] fetch_receive_pipe_flush;
wire [FETCH_RECEIVE_PIPE_WIDTH-1:0] fetch_receive_pipe_output;

wire [DECODE_PIPE_WIDTH-1:0] decode_pipe_input;
wire [DECODE_PIPE_WIDTH-1:0] decode_pipe_flush;
wire [DECODE_PIPE_WIDTH-1:0] decode_pipe_output;

wire [EXECUTE_PIPE_WIDTH-1:0] execute_pipe_input;
wire [EXECUTE_PIPE_WIDTH-1:0] execute_pipe_flush;
wire [EXECUTE_PIPE_WIDTH-1:0] execute_pipe_output;

wire [MEMORY_ISSUE_PIPE_WIDTH-1:0] memory_issue_pipe_input;
wire [MEMORY_ISSUE_PIPE_WIDTH-1:0] memory_issue_pipe_flush;
wire [MEMORY_ISSUE_PIPE_WIDTH-1:0] memory_issue_pipe_output;

wire [MEMORY_RECEIVE_PIPE_WIDTH-1:0] memory_receive_pipe_input;
wire [MEMORY_RECEIVE_PIPE_WIDTH-1:0] memory_receive_pipe_flush;
wire [MEMORY_RECEIVE_PIPE_WIDTH-1:0] memory_receive_pipe_output;

wire [WRITEBACK_PIPE_WIDTH-1:0] writeback_pipe_input;
wire [WRITEBACK_PIPE_WIDTH-1:0] writeback_pipe_flush;
wire [WRITEBACK_PIPE_WIDTH-1:0] writeback_pipe_output;




assign generated_address_execute = ALU_result_execute; //in case ADDRESS_BITS and DATA_WIDTH are different.


/*fetch issue*/
fetch_issue_intr #(
  .CORE(CORE),
  .RESET_PC(RESET_PC),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) FI (
  .clock(clock),
  .reset(reset),
  .next_PC_select(next_PC_select),
  .target_PC(target_PC),
  .issue_PC(issue_PC),
  .i_mem_read_address(fetch_address_out),
  .trap_branch(trap_branch),
  .trap_target(trap_target),
  .next_PC(next_PC),
  .scan(scan)
);


/*fetch receive*/
assign fetch_receive_pipe_input = { issue_PC,
                                    fetch_read
                                  };

assign fetch_receive_pipe_flush = { {{ADDRESS_BITS-1{1'b0}}, 1'b1},
                                    1'b0
                                  };

assign { issue_PC_fetch_receive      ,
         issue_request_fetch_receive } = fetch_receive_pipe_output;

pipeline_register #(
  .PIPELINE_STAGE("Fetch receive Pipe"),
  .PIPE_WIDTH(FETCH_RECEIVE_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) fetch_receive_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_fetch_receive),
  .flush(flush_fetch_receive),
  .pipe_input(fetch_receive_pipe_input),
  .flush_input(fetch_receive_pipe_flush),
  .pipe_output(fetch_receive_pipe_output),
  //scan signal
  .scan(scan)
);

/*fetch receive*/
fetch_receive #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) FR (
  .flush(~issue_request_fetch_receive),
  .i_mem_data(fetch_data_in),
  .issue_PC(issue_PC_fetch_receive),
  .instruction(instruction_fetch_receive),
  //scan signal
  .scan(scan)
);

assign exception_fetch_receive      = new_exception_fetch_receive;
assign exception_code_fetch_receive = new_exception_code_fetch_receive;

assign inst_PC_fetch_receive = fetch_address_in;


assign decode_pipe_input = { instruction_fetch_receive,
                             inst_PC_fetch_receive,
                             exception_fetch_receive,
                             exception_code_fetch_receive
                           };

assign decode_pipe_flush = { 32'h00000013,
                             {{ADDRESS_BITS-1{1'b0}}, 1'b1},
                             1'b0, // Exception
                             4'h0  // Exception Code
                           };

assign { instruction_decode,
         inst_PC_decode,
         prev_exception_decode,
         prev_exception_code_decode } = decode_pipe_output;

pipeline_register #(
  .PIPELINE_STAGE("Decode Pipe"),
  .PIPE_WIDTH(DECODE_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) decode_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_decode),
  .flush(flush_decode),
  .pipe_input(decode_pipe_input),
  .flush_input(decode_pipe_flush),
  .pipe_output(decode_pipe_output),
  //scan signal
  .scan(scan)
);


/*decode unit*/
seven_stage_decode_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) ID (
  .clock(clock),
  .reset(reset),

  .PC(inst_PC_decode),
  .instruction(instruction_decode),
  .extend_sel(extend_sel_decode),
  .write(write_writeback),
  .write_reg(write_reg_writeback),
  .write_data(write_data_writeback),

  .rs1_data(rs1_data_decode),
  .rs2_data(rs2_data_decode),
  .rd(rd_decode),
  .opcode(opcode_decode),
  .funct7(funct7_decode),
  .funct3(funct3_decode),
  .extend_imm(extend_imm_decode),
  .branch_target(branch_target_decode),
  .JAL_target(JAL_target_decode),

  // Data Bypassing Signals
  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),
  .ALU_result_execute(ALU_result_execute),
  .ALU_result_memory_issue(ALU_result_memory_issue),
  .ALU_result_memory_receive(ALU_result_memory_receive),
  .ALU_result_writeback(write_data_writeback), // TODO: rename bypass signals

  //scan signal
  .scan(scan)
);

// Not worth a whole module for this
assign CSR_address_decode = instruction_decode[31:20];

/*control unit*/
seven_stage_priv_control_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .M_EXTENSION(M_EXTENSION),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) CTRL (
  // Base Control Unit Ports
  .clock(clock),
  .reset(reset),
  .opcode_decode(opcode_decode),
  .opcode_execute(opcode_execute),
  .opcode_memory_issue(opcode_memory_issue),
  .opcode_memory_receive(opcode_memory_receive),
  .funct3(funct3_decode),
  .funct7(funct7_decode),

  .JALR_target_execute(JALR_target_execute),
  .branch_target_execute(branch_target_execute),
  .JAL_target_decode(JAL_target_decode),
  .branch_execute(branch_execute),

  .branch_op(branch_op_decode),
  .memRead(memRead_decode),
  .ALU_operation(ALU_operation_decode),
  .memWrite(memWrite_decode),
  .log2_bytes(log2_bytes_decode),
  .unsigned_load(unsigned_load_decode),
  .next_PC_sel(next_PC_select),
  .operand_A_sel(operand_A_sel_decode),
  .operand_B_sel(operand_B_sel_decode),
  .extend_sel(extend_sel_decode),
  .regWrite(regWrite_decode),

  .target_PC(target_PC),
  .i_mem_read(fetch_read),

  // Base Hazard Detection Unit Ports
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .issue_PC(issue_PC_fetch_receive),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  .load_memory_receive(memRead_memory_receive), // memRead_memory_receive
  .store_memory_issue(memWrite_memory_issue), // memWrite_memory_issue
  .store_memory_receive(memWrite_memory_receive),
  .load_address_receive(generated_address_memory_receive),
  .memory_address_in(memory_address_in),

  // Seven Stage Stall Unit Ports
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

  // Seven Stage Bypass Unit Ports
  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),

  // CSR & Privilege Control Ports
  .priv(priv),
  .intr_branch(intr_branch),

  .inst_PC_fetch_receive(inst_PC_fetch_receive),
  .inst_PC_decode(inst_PC_decode),
  .inst_PC_execute(inst_PC_execute),
  .inst_PC_memory_issue(inst_PC_memory_issue),
  .inst_PC_memory_receive(inst_PC_memory_receive),

  .m_ret_memory_receive(m_ret_memory_receive),
  .s_ret_memory_receive(s_ret_memory_receive),
  .u_ret_memory_receive(u_ret_memory_receive),

  .i_mem_page_fault(i_mem_page_fault),
  .i_mem_access_fault(i_mem_access_fault),
  .d_mem_page_fault(d_mem_page_fault),
  .d_mem_access_fault(d_mem_access_fault),

  .exception(exception_memory_receive),

  .exception_fetch_receive(new_exception_fetch_receive),
  .exception_decode(new_exception_decode),
  .exception_execute(new_exception_execute),
  .exception_memory_issue(new_exception_memory_issue),
  .exception_memory_receive(new_exception_memory_receive),

  .exception_code_fetch_receive(new_exception_code_fetch_receive),
  .exception_code_decode(new_exception_code_decode),
  .exception_code_execute(new_exception_code_execute),
  .exception_code_memory_issue(new_exception_code_memory_issue),
  .exception_code_memory_receive(new_exception_code_memory_receive),

  .m_ret_decode(m_ret_decode),
  .s_ret_decode(s_ret_decode),
  .u_ret_decode(u_ret_decode),

  .trap_PC(trap_PC),
  .trap_branch(trap_branch),

  .CSR_read_en(CSR_read_en_decode),
  .CSR_write_en(CSR_write_en_decode),
  .CSR_set_en(CSR_set_en_decode),
  .CSR_clear_en(CSR_clear_en_decode),

  .solo_instr_decode(solo_instr_decode), // generated here
  .solo_instr_execute(solo_instr_execute),
  .solo_instr_memory_issue(solo_instr_memory_issue),
  .solo_instr_memory_receive(solo_instr_memory_receive),
  .solo_instr_writeback(solo_instr_writeback),

  // TLB invalidate signals from sfence.vma
  .tlb_invalidate(tlb_invalidate_decode),
  .tlb_invalidate_mode(tlb_invalidate_mode_decode),

  // Multi-Cycle Execute Unit Control Signals
  .execute_valid_result(execute_valid_result_execute),

  // New Ports
  .rs1(instruction_decode[19:15]),
  .rs2(instruction_decode[24:20]),
  .rd(instruction_decode[11:7]),
  .rd_execute(rd_execute),
  .rd_memory_issue(rd_memory_issue),
  .rd_memory_receive(rd_memory_receive),
  .rd_writeback(rd_writeback),
  .regWrite_execute(regWrite_execute),
  .regWrite_memory_issue(regWrite_memory_issue),
  .regWrite_memory_receive(regWrite_memory_receive),
  .regWrite_writeback(regWrite_writeback),
  .issue_request(issue_request_fetch_receive),
  .store_memory_issue_allowed(memWrite_memory_issue_allowed),

  .scan(scan)
);


assign exception_decode      = prev_exception_decode | new_exception_decode;
assign exception_code_decode = prev_exception_decode ? prev_exception_code_decode : new_exception_code_decode;


assign execute_pipe_input = { inst_PC_decode,
                              rs1_data_decode,
                              rs2_data_decode,
                              rd_decode,
                              extend_imm_decode,
                              branch_target_decode,
                              branch_op_decode,
                              memRead_decode,
                              ALU_operation_decode,
                              memWrite_decode,
                              log2_bytes_decode,
                              unsigned_load_decode,
                              operand_A_sel_decode,
                              operand_B_sel_decode,
                              regWrite_decode,
                              solo_instr_decode,
                              opcode_decode,
                              m_ret_decode,
                              s_ret_decode,
                              u_ret_decode,
                              CSR_read_en_decode,
                              CSR_write_en_decode,
                              CSR_set_en_decode,
                              CSR_clear_en_decode,
                              CSR_address_decode,
                              tlb_invalidate_decode,
                              tlb_invalidate_mode_decode,
                              exception_decode,
                              exception_code_decode
                            };

assign execute_pipe_flush = { {{ADDRESS_BITS-1{1'b0}}, 1'b1}, // inst_PC
                              {DATA_WIDTH{1'b0}},             // rs1_data,
                              {DATA_WIDTH{1'b0}},             // rs2_data,
                              5'b00000,                       // rd,
                              {DATA_WIDTH{1'b0}},             // extend_imm,
                              {ADDRESS_BITS{1'b0}},           // branch_target,
                              1'b0,                           // branch_op,
                              1'b0,                           // memRead,
                              6'b000000,                      // ALU_operation,
                              1'b0,                           // memWrite,
                              {LOG2_NUM_BYTES{1'b0}},         // log2_bytes,
                              1'b0,                           // unsigned_load,
                              2'b00,                          // operand_A_sel,
                              1'b0,                           // operand_B_sel,
                              1'b0,                           // regWrite,
                              1'b0,                           // solo_instr,
                              7'b0110011,                     // opcode
                              3'b000,                         // [m|s|u]_ret
                              4'b0000,                        // CSR rd/wr/set/clear en
                              12'd0,                          // CSR_address
                              1'b0,                           // tlb_invalidate
                              2'b00,                          // tlb_invalidate_mode
                              1'b0,                           // exception
                              4'h0                            // exception_code
                            };

assign { inst_PC_execute,
         rs1_data_execute,
         rs2_data_execute,
         rd_execute,
         extend_imm_execute,
         branch_target_execute,
         branch_op_execute,
         memRead_execute,
         ALU_operation_execute,
         memWrite_execute,
         log2_bytes_execute,
         unsigned_load_execute,
         operand_A_sel_execute,
         operand_B_sel_execute,
         regWrite_execute,
         solo_instr_execute,
         opcode_execute,
         m_ret_execute,
         s_ret_execute,
         u_ret_execute,
         CSR_read_en_execute,
         CSR_write_en_execute,
         CSR_set_en_execute,
         CSR_clear_en_execute,
         CSR_address_execute,
         tlb_invalidate_execute,
         tlb_invalidate_mode_execute,
         prev_exception_execute,
         prev_exception_code_execute
       } = execute_pipe_output;




pipeline_register #(
  .PIPELINE_STAGE("Execute Pipe"),
  .PIPE_WIDTH(EXECUTE_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) execute_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_execute),
  .flush(flush_execute),
  .pipe_input(execute_pipe_input),
  .flush_input(execute_pipe_flush),
  .pipe_output(execute_pipe_output),
  //scan signal
  .scan(scan)
);


pipeline_register #(
  .PIPELINE_STAGE("Instruction Execute Pipe"),
  .PIPE_WIDTH(32),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) instruction_execute_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_execute),
  .flush(flush_execute),
  .pipe_input(instruction_decode),
  .flush_input(32'h00000013),
  .pipe_output(instruction_execute),
  //scan signal
  .scan(scan)
);


/*execute unit*/
execution_unit_multi_cycle #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .M_EXTENSION(M_EXTENSION),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) EX (
  .clock(clock),
  .reset(reset),
  .ALU_operation(ALU_operation_execute),
  .PC(inst_PC_execute),
  .operand_A_sel(operand_A_sel_execute),
  .operand_B_sel(operand_B_sel_execute),
  .branch_op(branch_op_execute),
  .rs1_data(rs1_data_execute),
  .rs2_data(rs2_data_execute),
  .extend(extend_imm_execute),

  // Signals for multi-cycle OPs
  .ready_i(execute_ready_i),
  .ready_o(),
  .valid_result(execute_valid_result_execute),

  .branch(branch_execute),
  .ALU_result(ALU_result_execute),
  .JALR_target(JALR_target_execute),
  //scan signal
  .scan(scan)
);

assign execute_ready_i = 1'b1;
assign exception_execute      = prev_exception_execute | new_exception_execute;
assign exception_code_execute = prev_exception_execute ? prev_exception_code_execute : new_exception_code_execute;

assign memory_issue_pipe_input = { memRead_execute,
                             memWrite_execute,
                             log2_bytes_execute,
                             unsigned_load_execute,
                             generated_address_execute,
                             rs2_data_execute,
                             regWrite_execute,
                             solo_instr_execute,
                             rd_execute,
                             ALU_result_execute,
                             opcode_execute,
                             m_ret_execute,
                             s_ret_execute,
                             u_ret_execute,
                             CSR_read_en_execute,
                             CSR_write_en_execute,
                             CSR_set_en_execute,
                             CSR_clear_en_execute,
                             CSR_address_execute,
                             tlb_invalidate_execute,
                             tlb_invalidate_mode_execute,
                             inst_PC_execute,
                             exception_execute,
                             exception_code_execute
                           };

assign memory_issue_pipe_flush = { 1'b0,                    // memRead_execute,
                             1'b0,                          // memWrite_execute,
                             {LOG2_NUM_BYTES{1'b0}},        // log2_bytes,
                             1'b0,                          // unsigned_load,
                             {ADDRESS_BITS{1'b0}},          // generated_address_execute,
                             {DATA_WIDTH{1'b0}},            // rs2_data_execute,
                             1'b0,                          // regWrite_execute,
                             1'b0,                          // solo_instr_execute,
                             5'b00000,                      // rd_execute,
                             {DATA_WIDTH{1'b0}},            // ALU_result_execute,
                             7'b0110011,                    // opcode
                             3'b000,                        // [m|s|u]_ret
                             4'b0000,                       // CSR rd/wr/set/clear en
                             12'd0,                         // CSR_address
                             1'b0,                           // tlb_invalidate
                             2'b00,                          // tlb_invalidate_mode
                             {{ADDRESS_BITS-1{1'b0}},1'b1}, // inst_PC
                             1'b0,                          // exception
                             4'h0                           // exception_code
                           };

assign { memRead_memory_issue,
         memWrite_memory_issue,
         log2_bytes_memory_issue,
         unsigned_load_memory_issue,
         generated_address_memory_issue,
         rs2_data_memory_issue,
         regWrite_memory_issue,
         solo_instr_memory_issue,
         rd_memory_issue,
         ALU_result_memory_issue,
         opcode_memory_issue,
         m_ret_memory_issue,
         s_ret_memory_issue,
         u_ret_memory_issue,
         CSR_read_en_memory_issue,
         CSR_write_en_memory_issue,
         CSR_set_en_memory_issue,
         CSR_clear_en_memory_issue,
         CSR_address_memory_issue,
         tlb_invalidate_memory_issue,
         tlb_invalidate_mode_memory_issue,
         inst_PC_memory_issue,
         prev_exception_memory_issue,
         prev_exception_code_memory_issue
       } = memory_issue_pipe_output;

pipeline_register #(
  .PIPELINE_STAGE("Memory Pipe"),
  .PIPE_WIDTH(MEMORY_ISSUE_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) memory_issue_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_memory_issue),
  .flush(flush_memory_issue),
  .pipe_input(memory_issue_pipe_input),
  .flush_input(memory_issue_pipe_flush),
  .pipe_output(memory_issue_pipe_output),
  //scan signal
  .scan(scan)
);

pipeline_register #(
  .PIPELINE_STAGE("Instruction Memory Pipe"),
  .PIPE_WIDTH(32),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) instruction_memory_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_memory_issue),
  .flush(flush_memory_issue),
  .pipe_input(instruction_execute),
  .flush_input(32'h00000013),
  .pipe_output(instruction_memory_issue),
  //scan signal
  .scan(scan)
);


/*memory issue*/
memory_issue #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) MI (
  .clock(clock),
  .reset(reset),
  // Execute stage interface
  .load(memRead_memory_issue),
  .store(memWrite_memory_issue_allowed),
  .address(generated_address_memory_issue),
  .store_data(rs2_data_memory_issue),
  .log2_bytes(log2_bytes_memory_issue),
  // Memory interface
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address(memory_address_out),
  .memory_data(memory_data_out),
  // scan signal
  .scan(scan)
);

assign tlb_invalidate      = tlb_invalidate_memory_issue;
assign tlb_invalidate_mode = tlb_invalidate_mode_memory_issue;

assign exception_memory_issue      = prev_exception_memory_issue | new_exception_memory_issue;
assign exception_code_memory_issue = prev_exception_memory_issue ? prev_exception_code_memory_issue : new_exception_code_memory_issue;


/*memory receive*/
assign memory_receive_pipe_input = { memRead_memory_issue,
                                     memWrite_memory_issue,
                                     generated_address_memory_issue,
                                     ALU_result_memory_issue,
                                     regWrite_memory_issue,
                                     solo_instr_memory_issue,
                                     log2_bytes_memory_issue,
                                     unsigned_load_memory_issue,
                                     rd_memory_issue,
                                     opcode_memory_issue,
                                     m_ret_memory_issue,
                                     s_ret_memory_issue,
                                     u_ret_memory_issue,
                                     CSR_read_en_memory_issue,
                                     CSR_write_en_memory_issue,
                                     CSR_set_en_memory_issue,
                                     CSR_clear_en_memory_issue,
                                     CSR_address_memory_issue,
                                     inst_PC_memory_issue,
                                     exception_memory_issue,
                                     exception_code_memory_issue
                                   };

assign memory_receive_pipe_flush = { 1'b0,                          // memory read
                                     1'b0,                          // memory write
                                     {ADDRESS_BITS{1'b0}},          // memory read address
                                     {DATA_WIDTH{1'b0}},            // ALU result
                                     1'b0,                          // regWrite
                                     1'b0,                          // solo_instr
                                     {LOG2_NUM_BYTES{1'b0}},        // log2_bytes
                                     1'b0,                          // unsigned_load
                                     5'd0,                          // rd
                                     7'b0110011,                    // opcode
                                     3'b000,                        // [m|s|u]_ret
                                     4'b0000,                       // CSR rd/wr/set/clear en
                                     12'd0,                         // CSR_address
                                     {{ADDRESS_BITS-1{1'b0}}, 1'b1},// inst_PC
                                     1'b0,                          // exception
                                     4'h0                           // exception_code
                                   };

assign { memRead_memory_receive,
         memWrite_memory_receive,
         generated_address_memory_receive,
         ALU_result_memory_receive,
         regWrite_memory_receive,
         solo_instr_memory_receive,
         log2_bytes_memory_receive,
         unsigned_load_memory_receive,
         rd_memory_receive,
         opcode_memory_receive,
         m_ret_memory_receive,
         s_ret_memory_receive,
         u_ret_memory_receive,
         CSR_read_en_memory_receive,
         CSR_write_en_memory_receive,
         CSR_set_en_memory_receive,
         CSR_clear_en_memory_receive,
         CSR_address_memory_receive,
         inst_PC_memory_receive,
         prev_exception_memory_receive,
         prev_exception_code_memory_receive
       } = memory_receive_pipe_output;

pipeline_register #(
  .PIPELINE_STAGE("Memory Receive Pipe"),
  .PIPE_WIDTH(MEMORY_RECEIVE_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) memory_receive_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_memory_receive),
  .flush(flush_memory_receive),
  .pipe_input(memory_receive_pipe_input),
  .flush_input(memory_receive_pipe_flush),
  .pipe_output(memory_receive_pipe_output),
  //scan signal
  .scan(scan)
);


pipeline_register #(
  .PIPELINE_STAGE("Instruction Memory Receive Pipe"),
  .PIPE_WIDTH(32),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) instruction_memory_receive_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_memory_receive),
  .flush(flush_memory_receive),
  .pipe_input(instruction_memory_issue),
  .flush_input(32'h00000013),
  .pipe_output(instruction_memory_receive),
  //scan signal
  .scan(scan)
);

memory_receive #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) MR (
  .clock(clock),
  .reset(reset),
  .log2_bytes(log2_bytes_memory_receive),
  .unsigned_load(unsigned_load_memory_receive),
  // Memory interface
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  // Writeback interface
  .load_data(load_data_memory_receive),
  // scan signal
  .scan(scan)
);


CSR_unit_priv #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .HART_ID(CORE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) CSR_UNIT_PRIV (
  .clock(clock),
  .reset(reset),

  .CSR_read_en(CSR_read_en_memory_receive),
  .CSR_write_en(CSR_write_en_memory_receive),
  .CSR_set_en(CSR_set_en_memory_receive),
  .CSR_clear_en(CSR_clear_en_memory_receive),

  .CSR_address(CSR_address_memory_receive),
  .CSR_write_data(ALU_result_memory_receive),

  .m_ext_interrupt(m_ext_interrupt),
  .s_ext_interrupt(s_ext_interrupt),
  .software_interrupt(software_interrupt),
  .timer_interrupt(timer_interrupt),

  .m_ret(m_ret_memory_receive),
  .s_ret(s_ret_memory_receive),
  .u_ret(u_ret_memory_receive),

  .exception(exception_memory_receive),
  .exception_code(exception_code_memory_receive),
  .trap_PC(trap_PC),
  .exception_addr(generated_address_memory_receive),
  .exception_instr(instruction_memory_receive),

  .CSR_read_data_valid(CSR_read_data_valid_memory_receive),
  .CSR_read_data(CSR_read_data_memory_receive),

  .intr_branch(intr_branch),
  .trap_branch(trap_branch),
  .trap_target(trap_target),

  .priv(priv),

  // MSTATUS CSR outputs
  .mstatus_MPP(MPP),
  .mstatus_SUM(SUM),
  .mstatus_MXR(MXR),
  .mstatus_MPRV(MPRV),

  // SATP CSR outputs
  .satp_MODE(MODE),
  .satp_ASID(ASID),
  .satp_PT_base_PPN(PT_base_PPN),

  .scan(scan) //
);

assign exception_memory_receive      = prev_exception_memory_receive | new_exception_memory_receive;
assign exception_code_memory_receive = prev_exception_memory_receive ? prev_exception_code_memory_receive : new_exception_code_memory_receive;


assign writeback_pipe_input = { regWrite_memory_receive   ,
                                solo_instr_memory_receive ,
                                memRead_memory_receive    ,
                                rd_memory_receive         ,
                                ALU_result_memory_receive ,
                                load_data_memory_receive  ,
                                CSR_read_data_valid_memory_receive,
                                CSR_read_data_memory_receive
                              };

assign writeback_pipe_flush = { 1'b0,                          // opWrite_writeback
                                1'b0,                          // solo_instr
                                1'b0,                          // opSel_writeback
                                5'd0,                          // opReg_writeback
                                {DATA_WIDTH{1'b0}},            // ALU_result_writeback
                                {DATA_WIDTH{1'b0}},            // load_data_writeback
                                1'b0,                          // CSR_read_data_valid
                                {DATA_WIDTH{1'b0}}             // CSR_read_data
                              };

assign { regWrite_writeback,
         solo_instr_writeback,
         memRead_writeback,
         rd_writeback,
         ALU_result_writeback,
         load_data_writeback,
         CSR_read_data_valid_writeback,
         CSR_read_data_writeback
         } = writeback_pipe_output;

pipeline_register #(
  .PIPELINE_STAGE("Writeback Pipe"),
  .PIPE_WIDTH(WRITEBACK_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) writeback_pipe (
  .clock(clock),
  .reset(reset),
  .stall(1'b0),
  .flush(flush_writeback),
  .pipe_input(writeback_pipe_input),
  .flush_input(writeback_pipe_flush),
  .pipe_output(writeback_pipe_output),
  //scan signal
  .scan(scan)
);


pipeline_register #(
  .PIPELINE_STAGE("Instruction Writeback Pipe"),
  .PIPE_WIDTH(32),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) instruction_writeback_pipe (
  .clock(clock),
  .reset(reset),
  .stall(1'b0),
  .flush(flush_writeback),
  .pipe_input(instruction_memory_receive),
  .flush_input(32'h00000013),
  .pipe_output(instruction_writeback),
  //scan signal
  .scan(scan)
);

/*writeback unit*/
writeback_unit_CSR #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) WB (
  .clock(clock),
  .reset(reset),

  .opWrite(regWrite_writeback),
  .opSel(memRead_writeback),
  .CSR_read_data_valid(CSR_read_data_valid_writeback),
  .opReg(rd_writeback),
  .ALU_result(ALU_result_writeback),
  .CSR_read_data(CSR_read_data_writeback),
  .memory_data(load_data_writeback),
  //decode unit interface
  .write(write_writeback),
  .write_reg(write_reg_writeback),
  .write_data(write_data_writeback),
  //scan signal
  .scan(scan)
);

endmodule
