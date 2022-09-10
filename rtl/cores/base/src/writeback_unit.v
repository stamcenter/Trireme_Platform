/** @module : writeback_unit
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

module writeback_unit #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  input opWrite,
  input opSel,
  input [4:0] opReg,
  input [DATA_WIDTH-1:0] ALU_result,
  input [DATA_WIDTH-1:0] memory_data,

  output write,
  output [4:0] write_reg,
  output [DATA_WIDTH-1:0] write_data,

  input scan

);

assign write_data = opSel? memory_data : ALU_result;
assign write_reg  = opReg;
assign write      = opWrite;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Writeback Unit - Current Cycle %d ----", CORE, cycles);
    $display ("| opSel       [%b]", opSel);
    $display ("| opReg       [%b]", opReg);
    $display ("| ALU_result  [%d]", ALU_result);
    $display ("| Memory_data [%d]", memory_data);
    $display ("| write       [%b]", write);
    $display ("| write_reg   [%d]", write_reg);
    $display ("| write_data  [%d]", write_data);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule

