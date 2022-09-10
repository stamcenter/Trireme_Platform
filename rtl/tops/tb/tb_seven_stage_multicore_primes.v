/** @module : tb_seven_stage_multicore_primes
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
`ifdef REGISTER_FILE0
  `undef REGISTER_FILE0
`endif
`ifdef REGISTER_FILE1
  `undef REGISTER_FILE1
`endif
`ifdef REGISTER_FILE2
  `undef REGISTER_FILE2
`endif
`ifdef REGISTER_FILE3
  `undef REGISTER_FILE3
`endif
`ifdef CURRENT_PC0
  `undef CURRENT_PC0
`endif
`ifdef CURRENT_PC1
  `undef CURRENT_PC1
`endif
`ifdef CURRENT_PC2
  `undef CURRENT_PC2
`endif
`ifdef CURRENT_PC3
  `undef CURRENT_PC3
`endif
`ifdef PROGRAM_BRAM_MEMORY
  `undef PROGRAM_BRAM_MEMORY
`endif

// Redefine macros used in this file
`define PROGRAM_BRAM_MEMORY DUT.memory.BRAM_inst.ram
`define REGISTER_FILE0 DUT.CORES[0].core.ID.base_decode.registers.register_file
`define REGISTER_FILE1 DUT.CORES[1].core.ID.base_decode.registers.register_file
`define REGISTER_FILE2 DUT.CORES[2].core.ID.base_decode.registers.register_file
`define REGISTER_FILE3 DUT.CORES[3].core.ID.base_decode.registers.register_file
`define CURRENT_PC0 DUT.CORES[0].core.FI.PC_reg
`define CURRENT_PC1 DUT.CORES[1].core.FI.PC_reg
`define CURRENT_PC2 DUT.CORES[2].core.FI.PC_reg
`define CURRENT_PC3 DUT.CORES[3].core.FI.PC_reg

module tb_seven_stage_multicore_primes();

parameter PROGRAM             = "./binaries/quad_core_primes.vmh";
parameter TEST_NAME           = "Prime Number Counter";

parameter NUM_CORES           = 4;
parameter DATA_WIDTH          = 32;
parameter ADDRESS_BITS        = 32;
parameter MEM_ADDRESS_BITS    = 14;
parameter SCAN_CYCLES_MIN     = 0;
parameter SCAN_CYCLES_MAX     = 1000;
// Cache hierarchy parameters
parameter STATUS_BITS_L1      = 2;
parameter OFFSET_BITS_L1      = {32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2};
parameter NUMBER_OF_WAYS_L1   = {32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2};
parameter INDEX_BITS_L1       = {32'd5, 32'd5, 32'd5, 32'd5, 32'd5, 32'd5, 32'd5, 32'd5};
parameter REPLACEMENT_MODE_L1 = 1'b0;
parameter STATUS_BITS_L2      = 3;
parameter OFFSET_BITS_L2      = 2;
parameter NUMBER_OF_WAYS_L2   = 4;
parameter INDEX_BITS_L2       = 6;
parameter REPLACEMENT_MODE_L2 = 1'b0;
parameter L2_INCLUSION        = 1'b1;
parameter COHERENCE_BITS      = 2;
parameter MSG_BITS            = 4;
parameter BUS_OFFSET_BITS     = 2;
parameter MAX_OFFSET_BITS     = 2;

genvar i;
integer x;

reg clock;
reg reset;
reg start;
reg [NUM_CORES*ADDRESS_BITS-1:0] program_address;

wire [NUM_CORES*ADDRESS_BITS-1:0] PC;

reg scan;

// Instantiate DUT
seven_stage_multicore_top #(
  .NUM_CORES(NUM_CORES),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MEM_ADDRESS_BITS(MEM_ADDRESS_BITS),
  .PROGRAM(PROGRAM),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX),
  .STATUS_BITS_L1(STATUS_BITS_L1),
  .OFFSET_BITS_L1(OFFSET_BITS_L1),
  .NUMBER_OF_WAYS_L1(NUMBER_OF_WAYS_L1),
  .INDEX_BITS_L1(INDEX_BITS_L1),
  .REPLACEMENT_MODE_L1(REPLACEMENT_MODE_L1),
  .STATUS_BITS_L2(STATUS_BITS_L2),
  .OFFSET_BITS_L2(OFFSET_BITS_L2),
  .NUMBER_OF_WAYS_L2(NUMBER_OF_WAYS_L2),
  .INDEX_BITS_L2(INDEX_BITS_L2),
  .REPLACEMENT_MODE_L2(REPLACEMENT_MODE_L2),
  .L2_INCLUSION(L2_INCLUSION),
  .COHERENCE_BITS(COHERENCE_BITS),
  .MSG_BITS(MSG_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) DUT (
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
    `PROGRAM_BRAM_MEMORY[x] = 32'd0;
  end
  for(x=0; x<32; x=x+1) begin
    `REGISTER_FILE0[x] = 32'd0;
    `REGISTER_FILE1[x] = 32'd0;
    `REGISTER_FILE2[x] = 32'd0;
    `REGISTER_FILE3[x] = 32'd0;
  end
  $readmemh(PROGRAM, `PROGRAM_BRAM_MEMORY);
end

integer start_time;
integer end_time;
integer total_cycles;
integer core0_finished, core1_finished, core2_finished, core3_finished;
integer core0_passed, core1_passed, core2_passed, core3_passed;
integer finished_count;

initial begin
  clock  = 1;
  reset  = 1;
  scan = 0;
  start = 0;
  program_address = {NUM_CORES*ADDRESS_BITS{1'b0}};
  core0_finished = 0;
  core1_finished = 0;
  core2_finished = 0;
  core3_finished = 0;
  core0_passed   = 0;
  core1_passed   = 0;
  core2_passed   = 0;
  core3_passed   = 0;
  finished_count = 0;
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
  if((`CURRENT_PC0 == 32'h000000dc || `CURRENT_PC0 == 32'h000000e0) & ~core0_finished) begin
    end_time = $time();
    total_cycles = (end_time - start_time)/10;
    #100 // Wait for pipeline to empty
    $display("\nCore 0 finished. Run Time (cycles): %d", total_cycles);
    core0_finished = 1;
    finished_count = finished_count + 1;
    if(`REGISTER_FILE0[9] == 32'h00000008) begin
      core0_passed   = 1;
    end else begin
      $display("\ntb_seven_stage_multicore_primes --> Test Failed!\n\n");
      $display("Dumping core 0 reg file states:");
      $display("Reg Index, Value");
      for( x=0; x<32; x=x+1) begin
        $display("%d: %h", x, `REGISTER_FILE0[x]);
      end
      $display("");
    end // pass/fail check
  end // pc0 check

  if((`CURRENT_PC1 == 32'h00000190 || `CURRENT_PC1 == 32'h00000194) & ~core1_finished) begin
    end_time = $time();
    total_cycles = (end_time - start_time)/10;
    #100 // Wait for pipeline to empty
    $display("\nCore 1 finished. Run Time (cycles): %d", total_cycles);
    core1_finished = 1;
    finished_count = finished_count + 1;
    if(`REGISTER_FILE1[9] == 32'h00000001) begin
      core1_passed   = 1;
    end else begin
      $display("\ntb_seven_stage_multicore_primes --> Test Failed!\n\n");
      $display("Dumping core 1 reg file states:");
      $display("Reg Index, Value");
      for( x=0; x<32; x=x+1) begin
        $display("%d: %h", x, `REGISTER_FILE1[x]);
      end
      $display("");
    end // pass/fail check
  end // pc1 check

  if((`CURRENT_PC2 == 32'h00000244 || `CURRENT_PC2 == 32'h00000248) & ~core2_finished) begin
    end_time = $time();
    total_cycles = (end_time - start_time)/10;
    #100 // Wait for pipeline to empty
    $display("\nCore 2 finished. Run Time (cycles): %d", total_cycles);
    core2_finished = 1;
    finished_count = finished_count + 1;
    if(`REGISTER_FILE2[9] == 32'h00000002) begin
      core2_passed   = 1;
    end else begin
      $display("\ntb_seven_stage_multicore_primes --> Test Failed!\n\n");
      $display("Dumping core 2 reg file states:");
      $display("Reg Index, Value");
      for( x=0; x<32; x=x+1) begin
        $display("%d: %h", x, `REGISTER_FILE2[x]);
      end
      $display("");
    end // pass/fail check
  end // pc2 check

  if((`CURRENT_PC3 == 32'h000002f8 || `CURRENT_PC3 == 32'h000002fc) & ~core3_finished) begin
    end_time = $time();
    total_cycles = (end_time - start_time)/10;
    #100 // Wait for pipeline to empty
    $display("\nCore 3 finished. Run Time (cycles): %d", total_cycles);
    core3_finished = 1;
    finished_count = finished_count + 1;
    if(`REGISTER_FILE3[9] == 32'h00000002) begin
      core3_passed   = 1;
    end else begin
      $display("\ntb_seven_stage_multicore_primes --> Test Failed!\n\n");
      $display("Dumping core 3 reg file states:");
      $display("Reg Index, Value");
      for( x=0; x<32; x=x+1) begin
        $display("%d: %h", x, `REGISTER_FILE1[x]);
      end
      $display("");
    end // pass/fail check
  end // pc3 check


  if(finished_count == 4)begin
    if(core1_passed & core0_passed & core2_passed & core3_passed)begin
      $display("\ntb_seven_stage_multicore_primes --> Test Passed!\n\n");
      $stop();
    end
    else begin
      $display("\ntb_seven_stage_multicore_primes --> Test Failed!\n\n");
      $stop();
    end
  end

end // always

endmodule
