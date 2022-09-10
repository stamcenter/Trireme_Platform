/** @module : tb_seven_stage_priv_BRAM_top_gcd
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

// Undefine macros used in this file
`ifdef REGISTER_FILE
  `undef REGISTER_FILE
`endif
`ifdef CURRENT_PC
  `undef CURRENT_PC
`endif
`ifdef PROGRAM_BRAM_MEMORY
  `undef PROGRAM_BRAM_MEMORY
`endif

// Redefine macros used in this file
`define PROGRAM_BRAM_MEMORY DUT.memory.memory.ram
`define REGISTER_FILE DUT.core.ID.base_decode.registers.register_file
`define CURRENT_PC DUT.core.FI.PC_reg

module tb_seven_stage_priv_BRAM_top_gcd();

parameter CORE             = 0;
parameter DATA_WIDTH       = 64;
parameter ADDRESS_BITS     = 64;
parameter MEM_ADDRESS_BITS = 18;
parameter SCAN_CYCLES_MIN  = 0;
parameter SCAN_CYCLES_MAX  = 1000;
parameter PROGRAM          = "./binaries/gcd64_262144.vmh";
parameter TEST_NAME        = "Greatest Common Denominator - 64-Bit";

genvar byte;
integer x;
integer x32;
integer x64;

reg clock;
reg reset;
reg start;
reg [ADDRESS_BITS-1:0] program_address;

reg m_ext_interrupt;
reg s_ext_interrupt;

wire [ADDRESS_BITS-1:0] PC;

wire uart_rx;
wire uart_tx;

reg scan;

// Single reg to load program into before splitting it into bytes in the
// byte enabled dual port BRAM
reg [DATA_WIDTH-1:0] dummy_ram [2**MEM_ADDRESS_BITS-1:0];

assign uart_rx = uart_tx;

seven_stage_priv_BRAM_top #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MEM_ADDRESS_BITS(MEM_ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  .clock(clock),
  .reset(reset),
  .start(start),
  .m_ext_interrupt(m_ext_interrupt),
  .s_ext_interrupt(s_ext_interrupt),
  .program_address(program_address),
  .PC(PC),
  .uart_rx(uart_rx),
  .uart_tx(uart_tx),
  .scan(scan)
);


// Clock generator
always #1 clock = ~clock;

// Initialize program memory
initial begin
  for(x=0; x<2**MEM_ADDRESS_BITS; x=x+1) begin
    dummy_ram[x] = {DATA_WIDTH{1'b0}};
  end
  for(x=0; x<32; x=x+1) begin
    `REGISTER_FILE[x] = 32'd0;
  end
  $readmemh(PROGRAM, dummy_ram);
end

generate
for(byte=0; byte<4; byte=byte+1) begin : BYTE_LOOP
  initial begin
    #1 // Wait for dummy ram to be initialzed
    // Copy dummy ram contents into each byte BRAM
    for(x64=0; x64<2**(MEM_ADDRESS_BITS); x64=x64+1) begin
      x32 = x64<<1;
      DUT.memory.memory.BYTE_LOOP[byte].ELSE_INIT.BRAM_byte.ram[x64] = dummy_ram[x32][8*byte +: 8];
      DUT.memory.memory.BYTE_LOOP[byte+4].ELSE_INIT.BRAM_byte.ram[x64] = dummy_ram[x32+1][8*byte +: 8];
    end
  end
end
endgenerate


integer start_time;
integer end_time;
integer total_cycles;

initial begin
  clock  = 1;
  reset  = 1;
  scan = 0;
  start = 0;
  m_ext_interrupt = 1'b0;
  s_ext_interrupt = 1'b0;
  program_address = {ADDRESS_BITS{1'b0}};
  #10

  #1
  reset = 0;
  start = 1;
  start_time = $time();
  #1

  start = 0;

end

always begin

  #1
  if(`CURRENT_PC == 32'h000000b0 || `CURRENT_PC == 32'h000000b4) begin
    end_time = $time();
    total_cycles = (end_time - start_time)/2;
    #100 // Wait for pipeline to empty
    $display("\nRun Time (cycles): %d", total_cycles);
    if(`REGISTER_FILE[9] == 32'h00000010) begin
      $display("\ntb_seven_stage_BRAM_top (%s) --> Test Passed!\n\n", TEST_NAME);
    end else begin
      $display("Dumping reg file states:");
      $display("Reg Index, Value");
      for( x=0; x<32; x=x+1) begin
        $display("%d: %h", x, `REGISTER_FILE[x]);
      end
      $display("");
      $display("\ntb_seven_stage_BRAM_top (%s) --> Test Failed!\n\n", TEST_NAME);
    end // pass/fail check

    $stop();

  end // pc check
end // always

/*
always@(posedge clock) begin
  if(DUT.core.instruction_writeback !== 32'h00000013) begin
    //$display("%g: %h", $time, DUT.core.instruction_writeback);
    $display("%h", DUT.core.instruction_writeback);
  end
end
*/

endmodule
