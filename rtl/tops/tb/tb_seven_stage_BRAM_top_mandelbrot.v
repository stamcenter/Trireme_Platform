/** @module : tb_seven_stage_BRAM_top_mandelbrot
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
`define PROGRAM_BRAM_MEMORY dut.memory.memory.ram
`define REGISTER_FILE dut.core.ID.base_decode.registers.register_file
`define CURRENT_PC dut.core.FI.PC_reg

module tb_seven_stage_BRAM_top_mandelbrot();

parameter CORE             = 0;
parameter DATA_WIDTH       = 32;
parameter ADDRESS_BITS     = 32;
parameter MEM_ADDRESS_BITS = 14;
parameter D_ADDRESS_BITS   = 14;
parameter SCAN_CYCLES_MIN  = 0;
parameter SCAN_CYCLES_MAX  = 1000;
parameter PROGRAM          = "./binaries/short_mandelbrot6140.vmh";
parameter TEST_NAME        = "Mandelbrot";
parameter LOG_FILE         = "mandelbrot_results.txt";

genvar byte;
integer x;

reg clock;
reg reset;
reg start;
reg [ADDRESS_BITS-1:0] program_address;

wire [ADDRESS_BITS-1:0] PC;

reg scan;

// Single reg to load program into before splitting it into bytes in the
// byte enabled dual port BRAM
reg [DATA_WIDTH-1:0] dummy_ram [2**MEM_ADDRESS_BITS-1:0];


seven_stage_BRAM_top #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MEM_ADDRESS_BITS(MEM_ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) dut (
  .clock(clock),
  .reset(reset),
  .start(start),
  .program_address(program_address),
  .PC(PC),
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
for(byte=0; byte<DATA_WIDTH/8; byte=byte+1) begin : BYTE_LOOP
  initial begin
    #1 // Wait for dummy ram to be initialzed
    // Copy dummy ram contents into each byte BRAM
    for(x=0; x<2**MEM_ADDRESS_BITS; x=x+1) begin
      dut.memory.memory.BYTE_LOOP[byte].ELSE_INIT.BRAM_byte.ram[x] = dummy_ram[x][8*byte +: 8];
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

  // Check pass/fail condition every 1000 cycles so that check does not slow
  // down simulation to much
  #1
  if(`CURRENT_PC == 32'h000000b0 || `CURRENT_PC == 32'h000000b4) begin
    end_time = $time();
    total_cycles = (end_time - start_time)/2;
    #100 // Wait for pipeline to empty
    $display("\nRun Time (cycles): %d", total_cycles);
    if(`REGISTER_FILE[9] == 32'h00000002) begin
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

endmodule
