/** @module : fetch_issue_intr
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

module fetch_issue_intr #(
  parameter CORE            =    0,
  parameter RESET_PC        =    0,
  parameter ADDRESS_BITS    =   32,
  parameter SCAN_CYCLES_MIN =    1,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input  clock,
  input  reset,
  // Control signals
  input  [1:0] next_PC_select,
  input  [ADDRESS_BITS-1:0] target_PC,

  input                     trap_branch,
  input  [ADDRESS_BITS-1:0] trap_target,
  output [ADDRESS_BITS-1:0] next_PC,
  // Interface to fetch receive
  output [ADDRESS_BITS-1:0] issue_PC,
  // instruction cache interface
  output [ADDRESS_BITS-1:0] i_mem_read_address,
  // Scan signal
  input scan
);

reg [ADDRESS_BITS-1:0] PC_reg;

// Assign Outputs
assign issue_PC           = PC_reg;
assign i_mem_read_address = PC_reg;

// next_PC wire to send to *epc CSR on a trap
assign next_PC = (next_PC_select == 2'b00) ? PC_reg + 4 :
                 (next_PC_select == 2'b01) ? PC_reg     :
                 (next_PC_select == 2'b10) ? target_PC  :
                 RESET_PC;

always @(posedge clock)begin
  if(reset) begin
    PC_reg <= RESET_PC;
  end
  else if(trap_branch) begin
    PC_reg <= trap_target;
  end
  else begin
    PC_reg <= next_PC;
  end
end

endmodule

/**** next_PC_select encoding ****
* 2'b00: Increment PC (PC = PC  +  4 )
* 2'b01: Stall        (PC =   PC     )
* 2'b10: Jump/branch  (PC = target_PC)
*************************************/
