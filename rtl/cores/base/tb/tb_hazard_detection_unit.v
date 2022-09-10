/** @module : tb_hazard_detection_unit
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

module tb_hazard_detection_unit();

parameter [6:0]R_TYPE  = 7'b0110011,
               BRANCH  = 7'b1100011,
               JALR    = 7'b1100111,
               JAL     = 7'b1101111;


parameter CORE            = 0;
parameter ADDRESS_BITS    = 20;
parameter SCAN_CYCLES_MIN = 0;
parameter SCAN_CYCLES_MAX = 1000;

reg clock;
reg reset;

reg fetch_ready;
reg fetch_valid;
reg issue_request;
reg [ADDRESS_BITS-1:0] issue_PC;
reg [ADDRESS_BITS-1:0] fetch_address_in;
reg memory_valid;
reg memory_ready;
reg [ADDRESS_BITS-1:0] load_address;
reg [ADDRESS_BITS-1:0] memory_address_in;

reg load_memory;
reg store_memory;

reg [6:0] opcode_decode;
reg [6:0] opcode_execute;
reg branch_execute;

reg solo_instr_decode;
reg solo_instr_execute;
reg solo_instr_memory_issue;
reg solo_instr_memory_receive;
reg solo_instr_writeback;

wire i_mem_issue_hazard;
wire i_mem_recv_hazard;
wire d_mem_issue_hazard;
wire d_mem_recv_hazard;
wire JALR_branch_hazard;
wire JAL_hazard;
wire solo_instr_hazard;

reg scan;

hazard_detection_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  .clock(clock),
  .reset(reset),
  .fetch_ready(fetch_ready),
  .fetch_valid(fetch_valid),
  .issue_request(issue_request),
  .issue_PC(issue_PC),
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

  .solo_instr_decode(solo_instr_decode),
  .solo_instr_execute(solo_instr_execute),
  .solo_instr_memory_issue(solo_instr_memory_issue),
  .solo_instr_memory_receive(solo_instr_memory_receive),
  .solo_instr_writeback(solo_instr_writeback),

  .i_mem_issue_hazard(i_mem_issue_hazard),
  .i_mem_recv_hazard(i_mem_recv_hazard),
  .d_mem_issue_hazard(d_mem_issue_hazard),
  .d_mem_recv_hazard(d_mem_recv_hazard),
  .JALR_branch_hazard(JALR_branch_hazard),
  .JAL_hazard(JAL_hazard),
  .solo_instr_hazard(solo_instr_hazard),

  .scan(scan)
);

always #5 clock = ~clock;

initial begin
  clock = 1'b1;
  reset = 1'b1;

  // Initialize to hazard free state

  fetch_valid      = 1'b1;
  fetch_ready      = 1'b1;
  issue_request    = 1'b0;
  issue_PC         = 0;
  fetch_address_in = 0;
  memory_valid     = 1'b1;
  memory_ready     = 1'b1;

  load_memory      = 1'b0;
  store_memory     = 1'b0;
  load_address     = 0;
  memory_address_in = 0;

  opcode_decode  = R_TYPE;
  opcode_execute = R_TYPE;
  branch_execute = 1'b0;

  solo_instr_execute        = 1'b0;
  solo_instr_memory_issue   = 1'b0;
  solo_instr_memory_receive = 1'b0;
  solo_instr_writeback      = 1'b0;

  scan             = 1'b0;


  repeat (1) @ (posedge clock);
  reset = 1'b0;

  repeat (1) @ (posedge clock);

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: No hazard should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end

  // Instruction memory hazard
  fetch_valid   = 1'b0;
  issue_request = 1'b1;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b1 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only instruction memory hazard should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end

  fetch_valid      = 1'b1;
  fetch_address_in = 4;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b1 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only instruction memory hazard should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end


  issue_request    = 1'b0;
  fetch_valid      = 1'b1;
  fetch_address_in = 0;
  // Data memory hazard
  memory_ready = 1'b0;
  store_memory = 1'b1;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |

      d_mem_issue_hazard !== 1'b1 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only data memory issue hazard (store) should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end

  memory_ready = 1'b1;
  store_memory = 1'b0;

  // Data memory hazard
  memory_valid = 1'b0;
  load_memory  = 1'b1;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b1 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only data memory recv hazard (load) should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end

  load_memory = 1'b0;

  // JAL hazard
  opcode_decode = JAL;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only JAL hazard should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end

  opcode_decode = R_TYPE;
  // JAL hazard
  opcode_execute = JALR;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b1 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only JALR hazard should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end

  // Branch hazard
  opcode_execute = BRANCH;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: No branch hazard should exist when branch not taken!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end


  // Branch hazard
  opcode_execute = BRANCH;
  branch_execute = 1'b1;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |

      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b1 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only branch hazard should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end

  opcode_execute = R_TYPE;
  branch_execute = 1'b0;

  // Data Memory Hazard
  load_memory = 1'b1;
  load_address = 4;

  repeat (1) @ (posedge clock);


  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b1 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b0 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only Data memory recv hazard should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end

  load_memory = 1'b0;

  // Solo Instruction Hazard
  solo_instr_execute = 1'b1;

  repeat (1) @ (posedge clock);

  if( i_mem_issue_hazard !== 1'b0 |
      i_mem_recv_hazard  !== 1'b0 |
      d_mem_issue_hazard !== 1'b0 |
      d_mem_recv_hazard  !== 1'b0 |
      JALR_branch_hazard !== 1'b0 |
      JAL_hazard         !== 1'b0 |
      solo_instr_hazard  !== 1'b1 ) begin
    scan = 1'b1;
    repeat (1) @ (posedge clock);
    $display("\nError: Only solo instruction hazard should exist!");
    $display("\ntb_hazard_detection_unit --> Test Failed!\n\n");
    $stop();
  end


  $display("\ntb_hazard_detection_unit --> Test Passed!\n\n");
  $stop();

end

endmodule
