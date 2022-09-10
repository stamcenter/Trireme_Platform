/** @module : tb_single_cycle_control_unit
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

module tb_single_cycle_control_unit();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter [6:0]R_TYPE  = 7'b0110011,
               BRANCH  = 7'b1100011,
               JALR    = 7'b1100111,
               JAL     = 7'b1101111;

parameter CORE            = 0;
parameter ADDRESS_BITS    = 20;
parameter NUM_BYTES       = 32/8;
parameter LOG2_NUM_BYTES  = log2(NUM_BYTES);
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

// Control Unit Ports
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

wire [ADDRESS_BITS-1:0] target_PC;
wire i_mem_read;

// Hazard Detection Unit Ports
reg fetch_valid;
reg fetch_ready;
reg [ADDRESS_BITS-1:0] issue_PC;
reg [ADDRESS_BITS-1:0] fetch_address_in;
reg memory_valid;
reg memory_ready;

reg load_memory;
reg store_memory;
reg [ADDRESS_BITS-1:0] load_address;
reg [ADDRESS_BITS-1:0] memory_address_in;

// New Ports
wire flush_fetch_receive;

reg  scan;


single_cycle_control_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) uut (
  // Control Unit Ports
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
  .regWrite(regWrite),

  .target_PC(target_PC),
  .i_mem_read(i_mem_read),

  // Hazard Detection Unit Ports
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .issue_PC(issue_PC),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),

  .load_memory(load_memory),
  .store_memory(store_memory),
  .load_address(load_address),
  .memory_address_in(memory_address_in),

  // New Ports
  .flush_fetch_receive(flush_fetch_receive),

  .scan(scan)
);


always #5 clock = ~clock;


initial begin
  clock = 1'b1;
  reset = 1'b1;

  opcode_decode  = R_TYPE;
  opcode_execute = R_TYPE;
  funct3         = 3'b000;
  funct7         = 7'b0000000;

  JALR_target_execute   = 4;
  branch_target_execute = 8;
  JAL_target_decode     = 12;
  branch_execute        = 1'b0;

  fetch_valid      = 1'b1;
  fetch_ready      = 1'b0;
  issue_PC         = 0;
  fetch_address_in = 0;
  memory_valid     = 1'b1;
  memory_ready     = 1'b1;

  load_memory  = 1'b0;
  store_memory = 1'b0;
  load_address = 0;
  memory_address_in = 0;

  branch_execute = 1'b0;

  scan = 1'b0;

  repeat (1) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  if( target_PC           != 0     |
      next_PC_sel         != 2'b00 |
      flush_fetch_receive != 1'b0  ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 0 and next PC select should be 0 (PC+4)!");
    $display("\ntb_single_cycle_control_unit --> Test Failed!\n\n");
    $stop();
  end

  // Instruction memory hazard
  fetch_valid = 1'b0;

  repeat (1) @ (posedge clock);

  if( target_PC           != 0     |
      next_PC_sel         != 2'b01 |
      flush_fetch_receive != 1'b1  ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 0 and next PC select should be 1 (stall)!");
    $display("\ntb_single_cycle_control_unit --> Test Failed!\n\n");
    $stop();
  end

  // Instruction memory hazard
  fetch_valid      = 1'b1;
  fetch_address_in = 4;

  repeat (1) @ (posedge clock);

  if( target_PC           != 0     |
      next_PC_sel         != 2'b01 |
      flush_fetch_receive != 1'b1  ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 0 and next PC select should be 1 (stall)!");
    $display("\ntb_single_cycle_control_unit --> Test Failed!\n\n");
    $stop();
  end


  fetch_valid      = 1'b1;
  fetch_address_in = 0;
  // Data memory hazard
  memory_ready = 1'b0;
  store_memory = 1'b1;

  repeat (1) @ (posedge clock);

  if( target_PC           != 0     |
      next_PC_sel         != 2'b01 |
      flush_fetch_receive != 1'b0  ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 0 and next PC select should be 1 (stall)!");
    $display("\ntb_single_cycle_control_unit --> Test Failed!\n\n");
    $stop();
  end

  memory_ready = 1'b1;
  store_memory = 1'b0;

  // Data memory hazard
  memory_valid = 1'b0;
  load_memory  = 1'b1;

  repeat (1) @ (posedge clock);

  if( target_PC   != 0     |
      next_PC_sel != 2'b01 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 0 and next PC select should be 1 (stall)!");
    $display("\ntb_single_cycle_control_unit --> Test Failed!\n\n");
    $stop();
  end


  load_memory  = 1'b0;

  // JAL hazard
  opcode_decode = JAL;

  repeat (1) @ (posedge clock);

  if( target_PC   != 12    |
      next_PC_sel != 2'b10 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 12 and next PC select should be 2 (target_PC)!");
    $display("\ntb_single_cycle_control_unit --> Test Failed!\n\n");
    $stop();
  end


  opcode_decode = R_TYPE;
  // JAL hazard
  opcode_execute = JALR;

  repeat (1) @ (posedge clock);

  if( target_PC   != 4     |
      next_PC_sel != 2'b10 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 4 and next PC select should be 2 (target_PC)!");
    $display("\ntb_single_cycle_control_unit --> Test Failed!\n\n");
    $stop();
  end

  // Branch hazard
  opcode_execute = BRANCH;

  repeat (1) @ (posedge clock);

  if( target_PC   != 0     |
      next_PC_sel != 2'b00 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 0 and next PC select should be 0 (PC+4)!");
    $display("\ntb_single_cycle_control_unit --> Test Failed!\n\n");
    $stop();
  end


  // Branch hazard
  opcode_execute = BRANCH;
  branch_execute = 1'b1;

  repeat (1) @ (posedge clock);

  if( target_PC   != 8     |
      next_PC_sel != 2'b10 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Target should be 8 and next PC select should be 2 (target_PC)!");
    $stop();
  end


  $display("\ntb_single_cycle_control_unit --> Test Passed!\n\n");
  $stop();
end

endmodule
