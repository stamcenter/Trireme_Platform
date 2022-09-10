/** @module : lx_bus_interface
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

/** Module description
* --------------------
 *  - Interface which connects the Lx cache to a shared bus on the processor
 *    side.
 *  - Handles line width differences between the Lx cache and L(x-1) caches
 *    connected on the bus.
 *  - A more conservative version of the bus interface to work with the
 *    blocking Lx cache controller.
 *  Parameters
 *  ----------
   *  MAX_OFFSET_BITS: Offset bits corresponding to the widest cache lines in
   *  the caches connected to the shared bus.
**/


module lx_bus_interface #(
parameter CACHE_OFFSET_BITS =  2, //max offset bits from cache side
          BUS_OFFSET_BITS   =  1, //determines width of the bus
          DATA_WIDTH        = 32,
          ADDRESS_WIDTH     = 32,
          MSG_BITS          =  4,
          MAX_OFFSET_BITS   =  3
)(
clock,
reset,

bus_msg_in,
bus_address_in,
bus_data_in,
bus_msg_out,
bus_address_out,
bus_data_out,
req_offset,
req_ready,
active_offset,

cache_msg_in,
cache_address_in,
cache_data_in,
cache_msg_out,
cache_address_out,
cache_data_out,
pending_requests
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

localparam CACHE_WORDS = 1 << CACHE_OFFSET_BITS; //number of words in one line.
localparam BUS_WORDS   = 1 << BUS_OFFSET_BITS; //width of data bus.
localparam MAX_WORDS   = 1 << MAX_OFFSET_BITS;
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam BUS_WIDTH   = DATA_WIDTH*BUS_WORDS;
localparam CACHE2BUS_OFFSETDIFF = (CACHE_OFFSET_BITS >= BUS_OFFSET_BITS ) ? 
                                  (CACHE_OFFSET_BITS -  BUS_OFFSET_BITS ) :
                                  (BUS_OFFSET_BITS   - CACHE_OFFSET_BITS) ;
localparam CACHE2BUS_RATIO = 1 << CACHE2BUS_OFFSETDIFF;

localparam IDLE            = 4'd0 ,
           RECEIVE         = 4'd1 ,
           SEND_ADDR       = 4'd2 ,
           SEND_TO_CACHE   = 4'd3 ,
           READ_DATA       = 4'd4 ,
           READ_FILLER     = 4'd5 ,
           TRANSFER        = 4'd6 ,
           WAIT_FOR_RESP   = 4'd7 ,
           WAIT_BUS_CLEAR  = 4'd8 ,
           WAIT_FLUSH_RESP = 4'd9 , 
           GET_BUS         = 4'd10;

`include `INCLUDE_FILE

input clock, reset;

input  [MSG_BITS-1:      0]     bus_msg_in;
input  [ADDRESS_WIDTH-1: 0] bus_address_in;
input  [BUS_WIDTH-1:     0]    bus_data_in;
input  req_ready;
input  [log2(MAX_OFFSET_BITS):0] req_offset;
output [MSG_BITS-1           :0] bus_msg_out;
output [ADDRESS_WIDTH-1      :0] bus_address_out;
output [BUS_WIDTH-1          :0] bus_data_out;
output [log2(MAX_OFFSET_BITS):0] active_offset;

input  [MSG_BITS-1     :0] cache_msg_in;
input  [ADDRESS_WIDTH-1:0] cache_address_in;
input  [CACHE_WIDTH-1  :0] cache_data_in;
output [MSG_BITS-1     :0] cache_msg_out;
output [ADDRESS_WIDTH-1:0] cache_address_out;
output [CACHE_WIDTH-1  :0] cache_data_out;
output reg pending_requests;


genvar i;
integer j;

reg [3:0] state;
reg [DATA_WIDTH-1:0] r_cache_data_out [CACHE_WORDS-1:0];
reg [DATA_WIDTH-1:0] r_bus_data_out   [BUS_WORDS-1:  0];

reg [MSG_BITS-1:     0] r_cache_msg_out, r_bus_msg_out;
reg [ADDRESS_WIDTH-1:0] r_cache_address_out, r_bus_address_out;
reg [MAX_OFFSET_BITS:0] block_counter, word_counter;

reg [MSG_BITS-1:0] curr_msg;
reg [ADDRESS_WIDTH-1:0] curr_address;
reg [CACHE_OFFSET_BITS-1:0] curr_offset;
reg [DATA_WIDTH-1:0] curr_data [MAX_WORDS-1:0];
reg [MAX_OFFSET_BITS-1:0] r_req_offset;

reg shared_line;

reg flush_active;
reg [ADDRESS_WIDTH-1:0] flush_address;

wire [DATA_WIDTH-1:0] w_cache_data_in [CACHE_WORDS-1: 0];
wire [DATA_WIDTH-1:0] w_bus_data_in   [BUS_WORDS-1:   0];

wire [MAX_OFFSET_BITS-1:0] cache2req_offsetdiff;
wire [MAX_OFFSET_BITS  :0] cache2req_ratio;
wire [MAX_OFFSET_BITS-1:0] req2bus_offsetdiff;
wire [MAX_OFFSET_BITS  :0] req2bus_ratio;
wire [MAX_OFFSET_BITS  :0] req_words;
wire cache_wt_req, bus_wt_req, req_wt_cache, req_wt_bus;
wire cache_req, coh_req, upgrade_req;
wire read_req, receive_req;

assign cache2req_offsetdiff = (CACHE_OFFSET_BITS > r_req_offset) ?
                              (CACHE_OFFSET_BITS - r_req_offset) :
                              (r_req_offset - CACHE_OFFSET_BITS) ;
assign cache2req_ratio = 1 << cache2req_offsetdiff;

assign req2bus_offsetdiff = (r_req_offset > BUS_OFFSET_BITS) ?
                            (r_req_offset - BUS_OFFSET_BITS) :
                            (BUS_OFFSET_BITS - r_req_offset) ;
assign req2bus_ratio = 1 << req2bus_offsetdiff;


assign cache_wt_req = CACHE_OFFSET_BITS > r_req_offset;
assign bus_wt_req   = BUS_OFFSET_BITS > r_req_offset;
assign req_wt_cache = r_req_offset > CACHE_OFFSET_BITS;
assign req_wt_bus   = r_req_offset > BUS_OFFSET_BITS;

assign req_words = 1 << r_req_offset;

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin : SPLIT_CACHELINE
    assign w_cache_data_in[i] = cache_data_in[i*DATA_WIDTH +: DATA_WIDTH];
  end
  for(i=0; i<BUS_WORDS; i=i+1)begin: SPLIT_BUS
    assign w_bus_data_in[i] = bus_data_in[i*DATA_WIDTH +: DATA_WIDTH];
  end
endgenerate

assign cache_req = (bus_msg_in == R_REQ) | (bus_msg_in == WB_REQ   ) |
                   (bus_msg_in == FLUSH) | (bus_msg_in == RFO_BCAST) ;

assign upgrade_req = (bus_msg_in == WS_BCAST);

assign coh_req     = (bus_msg_in == C_WB) | (bus_msg_in == C_FLUSH);

assign read_req    = (bus_msg_in == R_REQ) | (bus_msg_in == RFO_BCAST);
assign receive_req = (bus_msg_in == WB_REQ) | (bus_msg_in == FLUSH) | coh_req;


/*FSM*/
always @(posedge clock)begin
  if(reset)begin
    r_cache_msg_out     <= NO_REQ;
    r_bus_msg_out       <= NO_REQ;
    r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
    r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
    block_counter       <= {MAX_OFFSET_BITS{1'b0}};
    word_counter        <= {MAX_OFFSET_BITS{1'b0}};
    curr_msg            <= NO_REQ;
    curr_address        <= {ADDRESS_WIDTH{1'b0}};
    curr_offset         <= {CACHE_OFFSET_BITS{1'b0}};
    r_req_offset        <= {MAX_OFFSET_BITS{1'b0}};
	  shared_line         <= 1'b0;
    flush_active        <= 1'b0;
    flush_address       <= {ADDRESS_WIDTH{1'b0}};
    pending_requests    <= 1'b0;
    for(j=0; j<MAX_WORDS; j=j+1)begin
      curr_data[j] <= {DATA_WIDTH{1'b0}};
    end
    for(j=0; j<BUS_WORDS; j=j+1)begin
      r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
    end
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_cache_data_out[j] <= {DATA_WIDTH{1'b0}};
    end
    state  <= IDLE;
  end
  else begin
    case(state)
      IDLE:begin
        if(cache_msg_in == REQ_FLUSH & ~flush_active)begin
        /*Cache isses a flush request due to a request from the directory or
        * the L(x+1) cache.*/
          r_bus_msg_out     <= REQ_FLUSH;
          r_bus_address_out <= cache_address_in;
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j]   <= {DATA_WIDTH{1'b0}};
          end
          flush_active      <= 1'b1;
          flush_address     <= cache_address_in;
          r_cache_msg_out   <= NO_REQ;
          state             <= GET_BUS;
        end
        else if((cache_req & req_ready) | coh_req | upgrade_req)begin
          curr_msg        <= bus_msg_in;
          curr_address    <= bus_address_in;
          curr_offset     <= bus_address_in[0 +: CACHE_OFFSET_BITS];
          r_req_offset    <= req_offset;
          if(receive_req)begin
            block_counter <= 1;
            word_counter  <= 0;
            state         <= RECEIVE;
          end
          else begin
            block_counter       <= 1;
            word_counter        <= 0;
			      shared_line         <= 1'b0;
            state               <= SEND_ADDR;
          end
        end
        else if(req_ready & (bus_msg_in == NO_REQ) & flush_active)begin
        /*No cache had a dirty copy to be flushed. They all sent EN_ACCESS.*/
          r_bus_msg_out       <= HOLD_BUS;
          r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
          r_cache_msg_out     <= EN_ACCESS;
          r_cache_address_out <= flush_address;
          flush_active        <= 1'b0;
          state               <= WAIT_FLUSH_RESP;
        end
        else
          state <= IDLE;
      end
      RECEIVE:begin
        for(j=0; j<BUS_WORDS; j=j+1)begin
          curr_data[word_counter + j] <= w_bus_data_in[j];
        end
        if(req_wt_bus)begin
          if(block_counter == req2bus_ratio)begin
            block_counter <= 1;
            word_counter  <= 0;
            state         <= SEND_TO_CACHE;
          end
          else begin
            block_counter <= block_counter + 1;
            word_counter  <= word_counter + BUS_WORDS;
            state         <= RECEIVE;
          end
        end
        else begin
          if(cache2req_ratio == 1)begin
            r_cache_msg_out     <= curr_msg;
            r_cache_address_out <= curr_address;
            block_counter       <= 1;
            word_counter        <= 0;
            for(j=0; j<CACHE_WORDS; j=j+1)begin
              r_cache_data_out[j] <= (j<BUS_WORDS) ? w_bus_data_in[j] :
                                     {DATA_WIDTH{1'b0}};
            end
            state <= WAIT_FOR_RESP;
          end
          else begin
            r_cache_msg_out     <= R_REQ;
            r_cache_address_out <= (curr_address >> CACHE_OFFSET_BITS) <<
                                   CACHE_OFFSET_BITS;
            state               <= READ_FILLER;
          end
        end
      end
      READ_FILLER:begin
        if((cache_msg_in == MEM_RESP) | (cache_msg_in == MEM_RESP_S))begin
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache_data_out[j] <= w_cache_data_in[j];
          end
          r_cache_msg_out     <= NO_REQ;
          r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
          block_counter       <= 1;
          word_counter        <= 0;
          state               <= SEND_TO_CACHE;
        end
        else if(cache_msg_in == REQ_FLUSH & ~flush_active)begin
          r_bus_msg_out     <= REQ_FLUSH;
          r_bus_address_out <= cache_address_in;
          flush_active      <= 1'b1;
          flush_address     <= cache_address_in;
          r_cache_msg_out   <= NO_REQ;
          state             <= GET_BUS;
        end
        else
          state <= READ_FILLER;
      end
      SEND_TO_CACHE:begin
        if(req_wt_cache)begin
          r_cache_msg_out     <= curr_msg;
          r_cache_address_out <= curr_address + word_counter;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache_data_out[j] <= curr_data[word_counter + j];
          end
        end
        else begin
          r_cache_msg_out     <= curr_msg;
          r_cache_address_out <= (curr_address >> CACHE_OFFSET_BITS) <<
                                 CACHE_OFFSET_BITS;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache_data_out[j] <= (j>=curr_offset & j<(curr_offset+req_words))
                                   ? curr_data[j-curr_offset] : 
                                   r_cache_data_out[j];
          end
        end
        pending_requests <= 1'b0;
        state            <= WAIT_FOR_RESP;
      end
      WAIT_FOR_RESP:begin
      /*Previous version did not have a check for a possible flush request
      * becase inclusion was assumed and flush requests from L(x+1) level were
      * not considered. This state waits for a response for a write request
      * which cannot result in a flush request under old assumptions.*/
        if(cache_msg_in == REQ_FLUSH & ~flush_active)begin
          r_bus_msg_out     <= REQ_FLUSH;
          r_bus_address_out <= cache_address_in;
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j]   <= {DATA_WIDTH{1'b0}};
          end
          flush_active      <= 1'b1;
          flush_address     <= cache_address_in;
          r_cache_msg_out   <= NO_REQ;
          state             <= GET_BUS;
        end
        else begin
          if((cache_msg_in == MEM_RESP) | (cache_msg_in == MEM_C_RESP))begin
            if((block_counter == cache2req_ratio) | cache_wt_req)begin
              r_bus_msg_out     <= cache_msg_in;
              r_bus_address_out <= curr_address;
              for(j=0; j<BUS_WORDS; j=j+1)begin
                r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
              end
              state <= WAIT_BUS_CLEAR;
            end
            else begin
              block_counter    <= block_counter + 1;
              word_counter     <= word_counter + CACHE_WORDS;
              r_cache_msg_out  <= NO_REQ;
              pending_requests <= 1'b1;
              state            <= SEND_TO_CACHE;
            end
            r_cache_msg_out     <= NO_REQ;
            r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
          end
          else
            state <= WAIT_FOR_RESP;
        end
      end
      SEND_ADDR:begin
        pending_requests    <= 1'b0;
        r_cache_msg_out     <= curr_msg;
        r_cache_address_out <= ((curr_address >> CACHE_OFFSET_BITS) <<
                               CACHE_OFFSET_BITS) + word_counter;
        state               <= READ_DATA;
      end
      READ_DATA:begin
        if((cache_msg_in == MEM_RESP) | (cache_msg_in == MEM_RESP_S))begin
          r_cache_msg_out <= NO_REQ;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            curr_data[word_counter + j] <= w_cache_data_in[j];
          end
          if((block_counter == cache2req_ratio) | cache_wt_req)begin
            block_counter     <= 0;
            word_counter      <= curr_offset;
            r_bus_msg_out     <= (shared_line | (cache_msg_in == MEM_RESP_S)) ? 			                                                MEM_RESP_S : MEM_RESP; 
            r_bus_address_out <= curr_address;
            state             <= TRANSFER;
          end
          else begin
            block_counter    <= block_counter + 1;
            word_counter     <= word_counter + CACHE_WORDS;
      			shared_line      <= shared_line | (cache_msg_in == MEM_RESP_S);
            pending_requests <= 1'b1;
            state            <= SEND_ADDR;
          end
        end
        else if(cache_msg_in == EN_ACCESS)begin
        /*Lx cache is responding to a WS_BCAST on the bus*/
          r_cache_msg_out <= NO_REQ;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            curr_data[word_counter + j] <= {DATA_WIDTH{1'b0}};
          end
          if((block_counter == cache2req_ratio) | cache_wt_req)begin
            block_counter     <= 0;
            word_counter      <= curr_offset;
            r_bus_msg_out     <= EN_ACCESS; 
            r_bus_address_out <= curr_address;
            state             <= TRANSFER;
          end
          else begin
            block_counter    <= block_counter + 1;
            word_counter     <= word_counter + CACHE_WORDS;
            pending_requests <= 1'b1;
            state            <= SEND_ADDR;
          end
        end
        else if(cache_msg_in == REQ_FLUSH)begin
          r_bus_msg_out     <= REQ_FLUSH;
          r_bus_address_out <= cache_address_in;
          flush_active      <= 1'b1;
          flush_address     <= cache_address_in;
          r_cache_msg_out   <= NO_REQ;
          state             <= GET_BUS;
        end
        else
          state <= READ_DATA;
      end
      TRANSFER:begin
        if((block_counter == req2bus_ratio) | (bus_wt_req & (block_counter==1)))
        begin
          state <= WAIT_BUS_CLEAR;
		      for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
          end
		      r_bus_msg_out     <= NO_REQ;
		      r_bus_address_out <= {ADDRESS_WIDTH{1'b0}};
        end
        else begin
		      for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= curr_data[word_counter + j];
          end
          block_counter <= block_counter + 1;
          word_counter  <= word_counter + BUS_WORDS;
          state         <= TRANSFER;
        end
      end
      WAIT_BUS_CLEAR:begin
        if(bus_msg_in == NO_REQ)begin
          if(flush_active)begin
            r_bus_msg_out     <= REQ_FLUSH;
            r_bus_address_out <= flush_address;
            r_cache_msg_out   <= NO_REQ;
            state             <= IDLE;
          end
          else begin
            r_bus_msg_out     <= NO_REQ;
            r_bus_address_out <= {ADDRESS_WIDTH{1'b0}};
            for(j=0; j<BUS_WORDS; j=j+1)begin
              r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
            end
            state <= IDLE;
          end
        end
        else
          state <= WAIT_BUS_CLEAR;
      end
      WAIT_FLUSH_RESP:begin
      /*This state is only used to complete a flush request issued due to
      * requiring to evict a line from Lx cache. No response is expected by
      * the L1 caches.*/
        if(cache_msg_in == MEM_RESP)begin
          r_cache_msg_out     <= NO_REQ;
          r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
          r_bus_msg_out       <= NO_REQ;
          r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
          state               <= IDLE;
        end
        else
          state <= WAIT_FLUSH_RESP;
      end
      GET_BUS:begin
        if(bus_msg_in == REQ_FLUSH)
          state <= IDLE;
        else
          state <= GET_BUS;
      end
      default:begin
        state <= IDLE;
      end
    endcase
  end  
end


//Assign outputs//
assign bus_msg_out       = r_bus_msg_out;
assign bus_address_out   = r_bus_address_out;
assign cache_msg_out     = r_cache_msg_out;
assign cache_address_out = r_cache_address_out;
assign active_offset     = CACHE_OFFSET_BITS;

generate
  for(i=0; i<BUS_WORDS; i=i+1)begin: BUS_DATA
    assign bus_data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_bus_data_out[i];
  end
  for(i=0; i<CACHE_WORDS; i=i+1)begin: CACHE_DATA
    assign cache_data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_cache_data_out[i];
  end
endgenerate

endmodule
