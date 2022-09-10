/** @module : memory_issue
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

module memory_issue #(
  parameter CORE            = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter NUM_BYTES       = DATA_WIDTH/8,
  parameter LOG2_NUM_BYTES  = log2(NUM_BYTES),
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  // Execute stage interface
  input load,
  input store,
  input [ADDRESS_BITS-1:0] address,
  input [DATA_WIDTH-1:0] store_data,
  input [LOG2_NUM_BYTES-1:0] log2_bytes,

  // Memory interface
  output memory_read,
  output memory_write,
  output [NUM_BYTES-1:0] memory_byte_en,
  output [ADDRESS_BITS-1:0] memory_address,
  output [DATA_WIDTH-1:0] memory_data,

  // Scan signal
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

genvar i,j;

// A one-hot encoded wire representing the least significant byte in the word
// that will be written.
wire [NUM_BYTES-1:0] base_byte;
// A wire to hold outputs of mux chain based decoder
wire [NUM_BYTES-1:0] mux_chain [NUM_BYTES:0];
// A wire to extend the base byte wire by the size needed for each possible write size.
wire [NUM_BYTES-1:0] byte_en_mask [LOG2_NUM_BYTES:0];

wire [DATA_WIDTH-1:0] byte_data;
wire [DATA_WIDTH-1:0] half_word_data;
wire [DATA_WIDTH-1:0] word_data;

generate
for (i=0; i<NUM_BYTES; i=i+1) begin : BASE_BYTE_DECODER
  assign mux_chain[i] = address[LOG2_NUM_BYTES-1:0] == i ? 1 << i : mux_chain[i+1];
end
endgenerate

assign mux_chain[NUM_BYTES] = 0;
assign base_byte = mux_chain[0];

/*
assign base_byte = address[LOG2_NUM_BYTES-1:0] == 0 ? 1 :
                   address[LOG2_NUM_BYTES-1:0] == 1 ? 2 :
                   address[LOG2_NUM_BYTES-1:0] == 2 ? 4 :
                   address[LOG2_NUM_BYTES-1:0] == 3 ? 8 :
                   address[LOG2_NUM_BYTES-1:0] == 4 ? 16 :
                   address[LOG2_NUM_BYTES-1:0] == 5 ? 32 :
                   address[LOG2_NUM_BYTES-1:0] == 6 ? 64 :
                   address[LOG2_NUM_BYTES-1:0] == 7 ? 128 :
                   0;
*/

// Extend the base_byte bits by the number of bits needed for each write size.
// For RV32:
//SB: byte_en_mask[0] = {base_byte[3], base_byte[2], base_byte[1], base_byte[0]}
//SH: byte_en_mask[1] = {base_byte[2], base_byte[2], base_byte[0], base_byte[0]}
//SW: byte_en_mask[3] = {base_byte[0], base_byte[0], base_byte[0], base_byte[0]}
generate
for(i=1; i<=NUM_BYTES; i=i*2) begin : BYTE_ENABLE_MASK_LOOP
  for(j=0; j<NUM_BYTES; j=j+i) begin : BYTE_ENABLE_BIT_LOOP
    assign byte_en_mask[log2(i)][j +: i] = {i{base_byte[j]}};
  end // j
end // i
endgenerate


// Create masks for each size of data to be able to write bytes, half words,
// etc. to non-word aligned addresses.
assign byte_data      = {DATA_WIDTH/8 {store_data[ 7:0]}};
assign half_word_data = {DATA_WIDTH/16{store_data[15:0]}};
assign word_data      = {DATA_WIDTH/32{store_data[31:0]}};


assign memory_read    = load;
assign memory_write   = store;
assign memory_byte_en = byte_en_mask[log2_bytes];
assign memory_address = address;
assign memory_data    = log2_bytes == 0 ?  byte_data      : // Byte
                        log2_bytes == 1 ?  half_word_data : // Half Word
                        log2_bytes == 2 ?  word_data      : // Word
                        log2_bytes == 3 ?  store_data     : // Double
                        {DATA_WIDTH{1'b0}};


reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if(scan & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) ) begin
    $display ("------ Core %d Memory Issue - Current Cycle %d -------", CORE, cycles);
    $display ("| Load           [%b]", load);
    $display ("| Store          [%b]", store);
    $display ("| Address        [%h]", address);
    $display ("| Store Data     [%h]", store_data);
    $display ("| Log2 Bytes     [%b]", log2_bytes);
    $display ("| Memory Read    [%b]", memory_read);
    $display ("| Memory Write   [%b]", memory_write);
    $display ("| Memory Byte En [%b]", memory_byte_en);
    $display ("| Memory Address [%h]", memory_address);
    $display ("| Memory Data    [%h]", memory_data);
    $display ("----------------------------------------------------------------------");
  end
end

always@(posedge clock) begin
  if(store && (address[0] != 1'b0) && (log2_bytes == 2'b01)) begin
    $display("Unalligned Half Word Write at %d", $time);
    $display ("| Address        [%h]", address);
  end
  if(load && (address[0] != 1'b0) && (log2_bytes == 2'b01)) begin
    $display("Unalligned Half Word Read at %d", $time);
    $display ("| Address        [%h]", address);
  end
  if(store && (address[1:0] != 2'b00) && (log2_bytes == 2'b10)) begin
    $display("Unalligned Word Write at %d", $time);
    $display ("| Address        [%h]", address);
  end
  if(load && (address[1:0] != 2'b00) && (log2_bytes == 2'b10)) begin
    $display("Unalligned Word Read at %d", $time);
    $display ("| Address        [%h]", address);
  end

end


endmodule
