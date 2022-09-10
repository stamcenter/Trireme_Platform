/** @module : tb_pipeline_register
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

module tb_pipeline_register();

task print_state;
  begin
    $display("reset\t:%b", reset);
    $display("stall\t:%b", stall);
    $display("flush\t:%b", flush);
    $display("pipe_input\t:%b", pipe_input);
    $display("flush_input\t:%b", flush_input);
    $display("pipe_output\t:%b", pipe_output);
    $display("i\t:%b", i);
  end
endtask

parameter PIPELINE_STAGE  =    0;
parameter PIPE_WIDTH      =   32;
parameter SCAN_CYCLES_MIN =    1;
parameter SCAN_CYCLES_MAX = 1000;

reg  clock;
reg  reset;
reg  stall;
reg  flush;
reg  [PIPE_WIDTH-1:0] pipe_input;
reg  [PIPE_WIDTH-1:0] flush_input;
wire [PIPE_WIDTH-1:0] pipe_output;
//scan signal
reg scan;

//value generators
integer i;

//instantiate pipeline_register
pipeline_register #(
  .PIPELINE_STAGE(PIPELINE_STAGE),
  .PIPE_WIDTH(PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) DUT (
  .clock(clock),
  .reset(reset),
  .stall(stall),
  .flush(flush),
  .pipe_input(pipe_input),
  .flush_input(flush_input),
  .pipe_output(pipe_output),
  .scan(scan)
);


// generate clock signal
always #1 clock = ~clock;

always @(posedge clock)begin
  if(~reset)begin
    pipe_input <= pipe_input + 1;
    i          <= i + 1;
  end
end

initial begin
  clock <= 0;
  reset <= 1;
  stall <= 0;
  flush <= 0;
  scan  <= 0;
  i     <= 0;
  pipe_input  <= 1;
  flush_input <= 32'h00000013;

  repeat(3) @(posedge clock);
  @(posedge clock)begin
    reset <= 0;
  end
  repeat(1) @(posedge clock);
  if(pipe_output != i)begin
    $display("\ntb_pipeline_register --> Test Failed!\n\n");
    print_state();
  end

  repeat(3) @(posedge clock);
  @(posedge clock)begin
    stall     <= 1;
  end
  @(posedge clock)begin
    stall     <= 0;
  end
  @(stall)
  if(pipe_output != i-1)begin
    $display("\ntb_pipeline_register --> Test Failed!\n\n");
    print_state();
  end

  repeat(1) @(posedge clock);
  @(pipe_output)
  if(pipe_output != i)begin
    $display("\ntb_pipeline_register --> Test Failed!\n\n");
    print_state();
  end

  repeat(3) @(posedge clock);
  @(posedge clock)begin
    flush <= 1;
  end
  @(posedge clock)begin
    flush     <= 0;
  end
  @(flush)
  if(pipe_output != 32'h00000013)begin
    $display("\ntb_pipeline_register --> Test Failed!\n\n");
    print_state();
  end

  repeat(1) @(posedge clock);
  @(pipe_output)
  if(pipe_output != i)begin
    $display("\ntb_pipeline_register --> Test Failed!\n\n");
    print_state();
  end

  $display("\ntb_pipeline_register --> Test Passed!\n\n");
  $stop;
end



initial begin
  #500;
  $display("Error: timeout");
  $display("\ntb_pipeline_register --> Test Failed!\n\n");
  $stop;
end

endmodule
