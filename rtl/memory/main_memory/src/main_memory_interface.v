/** @module : main_memory_interface
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

module main_memory_interface #(
parameter OFFSET_BITS    =  2,
          DATA_WIDTH     = 32,
          ADDRESS_WIDTH  = 32,
          MSG_BITS       =  4
)(
clock, reset,

cache2interface_msg,
cache2interface_address,
cache2interface_data,

interface2cache_msg,
interface2cache_address,
interface2cache_data,

mem2interface_msg,
mem2interface_address,
mem2interface_data,

interface2mem_msg,
interface2mem_address,
interface2mem_data
);

localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam BUS_WIDTH      = DATA_WIDTH*WORDS_PER_LINE;

localparam IDLE         = 0,
           READ_MEMORY  = 1,
           WRITE_MEMORY = 2,
           RESPOND      = 3;

// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
`include `INCLUDE_FILE

input clock, reset;
input [MSG_BITS-1     :0] cache2interface_msg;
input [ADDRESS_WIDTH-1:0] cache2interface_address;
input [BUS_WIDTH-1    :0] cache2interface_data;

output [MSG_BITS-1     :0] interface2cache_msg;
output [ADDRESS_WIDTH-1:0] interface2cache_address;
output [BUS_WIDTH-1    :0] interface2cache_data;

input [MSG_BITS-1     :0] mem2interface_msg;
input [ADDRESS_WIDTH-1:0] mem2interface_address;
input [DATA_WIDTH-1   :0] mem2interface_data;

output [MSG_BITS-1     :0] interface2mem_msg;
output [ADDRESS_WIDTH-1:0] interface2mem_address;
output [DATA_WIDTH-1   :0] interface2mem_data;


genvar i;
integer j;
reg [2:0] state;
reg [DATA_WIDTH-1   :0] r_intf2cache_data [WORDS_PER_LINE-1:0];
reg [MSG_BITS-1     :0] r_intf2cache_msg;
reg [ADDRESS_WIDTH-1:0] r_intf2cache_address;
reg [DATA_WIDTH-1   :0] from_intf_data;
reg [MSG_BITS-1     :0] from_intf_msg;
reg [ADDRESS_WIDTH-1:0] from_intf_address;
reg [OFFSET_BITS    :0] word_counter;

wire [DATA_WIDTH-1   :0] w_cache2intf_data [WORDS_PER_LINE-1:0];
wire [MSG_BITS-1     :0] to_intf_msg;
wire [ADDRESS_WIDTH-1:0] to_intf_address;
wire [DATA_WIDTH-1   :0] to_intf_data;



generate
  for(i=0; i<WORDS_PER_LINE; i=i+1)begin : SPLIT_INPUTS
    assign w_cache2intf_data[i] = cache2interface_data[i*DATA_WIDTH +:
                                  DATA_WIDTH];
  end
endgenerate

assign to_intf_msg     = mem2interface_msg;
assign to_intf_address = mem2interface_address;
assign to_intf_data    = mem2interface_data;

//assign outputs
assign interface2cache_msg     = r_intf2cache_msg;
assign interface2cache_address = r_intf2cache_address;
generate
  for(i=0; i<WORDS_PER_LINE; i=i+1)begin: OUTDATA
    assign interface2cache_data[i*DATA_WIDTH +: DATA_WIDTH] =
                                        r_intf2cache_data[i];
  end
endgenerate

assign interface2mem_msg     = from_intf_msg;
assign interface2mem_address = from_intf_address;
assign interface2mem_data    = from_intf_data;


always @(posedge clock)begin
  if(reset)begin
    r_intf2cache_msg     <= NO_REQ;
    r_intf2cache_address <= 0;
    from_intf_msg        <= NO_REQ;
    from_intf_address    <= 0;
    from_intf_data       <= 0;
    for(j=0; j<WORDS_PER_LINE; j=j+1)begin
      r_intf2cache_data[j] <= 0;
    end
    state <= IDLE;
  end
  else begin
    case(state)
      IDLE:begin
        if(cache2interface_msg == R_REQ | cache2interface_msg == RFO_BCAST)begin
          word_counter         <= 0;
          from_intf_msg        <= R_REQ;
          from_intf_address    <= cache2interface_address;
          r_intf2cache_address <= cache2interface_address;
          state                <= READ_MEMORY;
        end
        else if((cache2interface_msg == FLUSH) | (cache2interface_msg == WB_REQ))
        begin
          word_counter         <= 0;
          from_intf_msg        <= WB_REQ;
          from_intf_address    <= cache2interface_address;
          from_intf_data       <= w_cache2intf_data[0];
          r_intf2cache_address <= cache2interface_address;
          state                <= WRITE_MEMORY;
        end
        else
          state <= IDLE;
      end
      READ_MEMORY:begin
        if((to_intf_msg == MEM_RESP) & (word_counter < WORDS_PER_LINE-1))begin
          r_intf2cache_data[word_counter] <= to_intf_data;
          word_counter                    <= word_counter + 1;
          from_intf_address               <= from_intf_address + 1;
          from_intf_msg                   <= R_REQ;
        end
        else if((to_intf_msg == MEM_RESP) &
        (word_counter == WORDS_PER_LINE-1))begin
          r_intf2cache_data[word_counter] <= to_intf_data;
          from_intf_address               <= 0;
          from_intf_msg                   <= NO_REQ;
          r_intf2cache_msg                <= MEM_RESP;
          state                           <= RESPOND;
        end
        else
          state <= READ_MEMORY;
      end
      WRITE_MEMORY:begin
        if((to_intf_msg == MEM_RESP) & (word_counter < WORDS_PER_LINE-1))begin
          from_intf_data    <= w_cache2intf_data[word_counter + 1];
          word_counter      <= word_counter + 1;
          from_intf_address <= from_intf_address + 1;
          from_intf_msg     <= WB_REQ;
        end
        else if((to_intf_msg == MEM_RESP) &
        (word_counter == WORDS_PER_LINE-1))begin
          from_intf_data    <= 0;
          from_intf_address <= 0;
          from_intf_msg     <= NO_REQ;
          r_intf2cache_msg  <= MEM_RESP;
          state             <= RESPOND;
        end
        else
          state <= WRITE_MEMORY;
      end
      RESPOND:begin
        r_intf2cache_address <= 0;
        r_intf2cache_msg     <= NO_REQ;
        state                <= IDLE;
      end
      default: state <= IDLE;
    endcase
  end
end

endmodule
