/** @module : single_cycle_control_unit
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

module single_cycle_control_unit #(
  parameter CORE            = 0,
  parameter ADDRESS_BITS    = 20,
  parameter NUM_BYTES       = 32/8,
  parameter LOG2_NUM_BYTES  = log2(NUM_BYTES),
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  // Control Unit Ports
  input clock,
  input reset,

  input [6:0] opcode_decode,
  input [6:0] opcode_execute,
  input [2:0] funct3,
  input [6:0] funct7,

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

  // Hazard Detection Unit Ports
  input fetch_valid,
  input fetch_ready,
  input [ADDRESS_BITS-1:0] issue_PC,
  input [ADDRESS_BITS-1:0] fetch_address_in,
  input memory_valid,
  input memory_ready,

  input load_memory,
  input store_memory,
  input [ADDRESS_BITS-1:0] load_address,
  input [ADDRESS_BITS-1:0] memory_address_in,

  // New Ports
  output flush_fetch_receive,

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


wire d_mem_hazard;
wire d_mem_issue_hazard;
wire d_mem_recv_hazard;
wire i_mem_hazard;
wire i_mem_issue_hazard;
wire i_mem_recv_hazard;
wire JALR_branch_hazard;
wire JAL_hazard;
wire regWrite_i;

assign d_mem_hazard = d_mem_issue_hazard | d_mem_recv_hazard;
assign i_mem_hazard = i_mem_issue_hazard | i_mem_recv_hazard;

assign flush_fetch_receive = i_mem_hazard;
assign regWrite            = regWrite_i & ~d_mem_hazard;

hazard_detection_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) hazard_unit (
  .clock(clock),
  .reset(reset),
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .issue_PC(issue_PC),
  .issue_request(1'b1),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),

  .load_memory(load_memory),
  .store_memory(store_memory),
  .load_address(load_address),
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

  .true_data_hazard(1'b0), // No data hazards in single cycle core
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
  .operand_B_sel(operand_B_sel),
  .extend_sel(extend_sel),
  .regWrite(regWrite_i),

  .solo_instr_decode(),

  .target_PC(target_PC),
  .i_mem_read(i_mem_read),

  .scan(scan)
);

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Singl Cycle Control Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| Memory Valid [%b]", memory_valid);
    $display ("| Memory Ready [%b]", memory_ready);
    $display ("| Fetch Valid  [%b]", fetch_valid);
    $display ("| Target PC    [%h]", target_PC);
    $display ("| Next PC sel  [%b]", next_PC_sel);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
