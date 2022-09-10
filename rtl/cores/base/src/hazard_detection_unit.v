/** @module : hazard_detection_unit
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

module hazard_detection_unit #(
  parameter CORE            = 0,
  parameter ADDRESS_BITS    = 32,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  input fetch_valid,
  input fetch_ready,
  input issue_request,
  input [ADDRESS_BITS-1:0] issue_PC,
  input [ADDRESS_BITS-1:0] fetch_address_in,
  input memory_valid,
  input memory_ready,

  input load_memory,
  input store_memory,
  input [ADDRESS_BITS-1:0] load_address,
  input [ADDRESS_BITS-1:0] memory_address_in,

  input [6:0] opcode_decode,
  input [6:0] opcode_execute,
  input branch_execute,

  input solo_instr_decode,
  input solo_instr_execute,
  input solo_instr_memory_issue,
  input solo_instr_memory_receive,
  input solo_instr_writeback,

  output i_mem_issue_hazard,
  output i_mem_recv_hazard,
  output d_mem_issue_hazard,
  output d_mem_recv_hazard,
  output JALR_branch_hazard,
  output JAL_hazard,
  output solo_instr_hazard,

  input scan
);

localparam [6:0]R_TYPE  = 7'b0110011,
                BRANCH  = 7'b1100011,
                JALR    = 7'b1100111,
                JAL     = 7'b1101111;


// Instruction/Data memory hazard detection
assign i_mem_issue_hazard = (~fetch_ready & ~issue_request);
assign i_mem_recv_hazard  = (issue_request & (~fetch_valid  | (issue_PC != fetch_address_in)));

assign d_mem_issue_hazard = ~memory_ready;
assign d_mem_recv_hazard  = (load_memory & (~memory_valid | (load_address != memory_address_in)));

// JALR BRANCH and JAL hazard detection
// JALR_branch and JAL hazard signals are high when there is a control flow
// change caused by one of these instructions. These signals are present in
// both pipelines and unpipelined versions of the processor.
assign JALR_branch_hazard = (opcode_execute == JALR  ) |
                            ((opcode_execute == BRANCH) & branch_execute);

assign JAL_hazard         = (opcode_decode == JAL);



// Some instructions must be executed without any other instructions in the
// pipeline to ensure sidefects take place in the correct order. If any of
// these instructions are in the pipeline, set the solo_instr hazard signal.
assign solo_instr_hazard = solo_instr_decode | solo_instr_execute | solo_instr_memory_issue | solo_instr_memory_receive | solo_instr_writeback;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Hazard Detection Unit - Current Cycle %d ------", CORE, cycles);

    $display ("| Fetch Valid        [%b]", fetch_valid);
    $display ("| Fetch Ready        [%b]", fetch_ready);
    $display ("| Issue Request      [%b]", issue_request);
    $display ("| Issue PC           [%h]", issue_PC);
    $display ("| Fetch Address In   [%h]", fetch_address_in);
    $display ("| Load Memory        [%b]", load_memory);
    $display ("| Memory Valid       [%b]", memory_valid);
    $display ("| Store Memory       [%b]", store_memory);
    $display ("| Memory Ready       [%b]", memory_ready);
    //$display ("| I-Mem Hazard       [%b]", i_mem_hazard);
    $display ("| I-Mem Iss Hazard   [%b]", i_mem_issue_hazard);
    $display ("| I-Mem Recv Hazard  [%b]", i_mem_recv_hazard);
    $display ("| D-Mem Iss Hazard   [%b]", d_mem_issue_hazard);
    $display ("| D-Mem Recv Hazard  [%b]", d_mem_recv_hazard);
    $display ("| JALR/branch Hazard [%b]", JALR_branch_hazard);
    $display ("| JAL Hazard         [%b]", JAL_hazard);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
