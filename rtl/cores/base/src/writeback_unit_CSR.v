/** @module : writeback_unit_CSR
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

module writeback_unit_CSR #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  input opWrite,
  input opSel,
  input CSR_read_data_valid,
  input [4:0] opReg,
  input [DATA_WIDTH-1:0] ALU_result,
  input [DATA_WIDTH-1:0] CSR_read_data,
  input [DATA_WIDTH-1:0] memory_data,

  output write,
  output [4:0] write_reg,
  output [DATA_WIDTH-1:0] write_data,

  input scan

);

wire [DATA_WIDTH-1:0] mux_out;

assign mux_out = CSR_read_data_valid ? CSR_read_data : ALU_result;

writeback_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) WB (
  .clock(clock),
  .reset(reset),

  .opWrite(opWrite),
  .opSel(opSel),
  .opReg(opReg),
  .ALU_result(mux_out),
  .memory_data(memory_data),
  //decode unit interface
  .write(write),
  .write_reg(write_reg),
  .write_data(write_data),
  //scan signal
  .scan(scan)
);


reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Writeback Unit CSR - Current Cycle %d ----", CORE, cycles);
    $display ("| CSR_read_data_valid [%b]", CSR_read_data_valid);
    $display ("| CSR_read_data valid [%h]", CSR_read_data);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule

