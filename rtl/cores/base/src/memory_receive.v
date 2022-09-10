/** @module : memory_receive
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

module memory_receive #(
  parameter CORE            =  0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter NUM_BYTES       = DATA_WIDTH/8,
  parameter LOG2_NUM_BYTES  = log2(NUM_BYTES),
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  // Memory Issue Interface
  input [LOG2_NUM_BYTES-1:0] log2_bytes,
  input unsigned_load,
  // Data Memory interface
  input [DATA_WIDTH-1:0] memory_data_in,
  input [DATA_WIDTH-1:0] memory_address_in,

  // Writeback interface
  output [DATA_WIDTH-1:0] load_data,

  input scan

);

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

wire [LOG2_NUM_BYTES:0] load_type;
wire [LOG2_NUM_BYTES-1:0] byte_shift;
wire [DATA_WIDTH-1:0] shifted_data;

assign load_type = {log2_bytes, unsigned_load};
assign byte_shift = memory_address_in[LOG2_NUM_BYTES-1:0];

assign shifted_data = memory_data_in >> {byte_shift, 3'b000};



generate
  if(DATA_WIDTH == 64) begin
    assign load_data =
      load_type == 3'd0 ? {{DATA_WIDTH-8{shifted_data[7]}}  , shifted_data[7:0]}  : // LB
      load_type == 3'd1 ? {{DATA_WIDTH-8{1'b0}}             , shifted_data[7:0]}  : // LBU
      load_type == 3'd2 ? {{DATA_WIDTH-16{shifted_data[15]}}, shifted_data[15:0]} : // LH
      load_type == 3'd3 ? {{DATA_WIDTH-16{1'b0}}            , shifted_data[15:0]} : // LHU
      load_type == 3'd4 ? {{DATA_WIDTH-32{shifted_data[31]}}, shifted_data[31:0]} : // LW
      load_type == 3'd5 ? {{DATA_WIDTH-32{1'b0}}            , shifted_data[31:0]} : // LWU
      load_type == 3'd6 ? {{DATA_WIDTH-64{shifted_data[63]}}, shifted_data[63:0]} : // LD
      {DATA_WIDTH{1'b0}};
  end
  else begin
    assign load_data =
      load_type == 3'd0 ? {{DATA_WIDTH-8{shifted_data[7]}}  , shifted_data[7:0]}  : // LB
      load_type == 3'd1 ? {{DATA_WIDTH-8{1'b0}}             , shifted_data[7:0]}  : // LBU
      load_type == 3'd2 ? {{DATA_WIDTH-16{shifted_data[15]}}, shifted_data[15:0]} : // LH
      load_type == 3'd3 ? {{DATA_WIDTH-16{1'b0}}            , shifted_data[15:0]} : // LHU
      load_type == 3'd4 ? {{DATA_WIDTH-32{shifted_data[31]}}, shifted_data[31:0]} : // LW
      load_type == 3'd5 ? {{DATA_WIDTH-32{1'b0}}            , shifted_data[31:0]} : // LWU
      {DATA_WIDTH{1'b0}};
  end
endgenerate

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if(scan & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) ) begin
    $display ("------ Core %d Memory Receive - Current Cycle %d -------", CORE, cycles);
    $display ("| Log2 Bytes      [%b]", log2_bytes);
    $display ("| Unsigned Load   [%b]", unsigned_load);
    $display ("| Memory Data In  [%h]", memory_data_in);
    $display ("| Memory Addr In  [%h]", memory_address_in);
    $display ("| Load Data       [%h]", load_data);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
