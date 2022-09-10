/** @module : Lxcache_controller
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
  *  - Cache controller for the Lx cache. (x = 2,3,..)
  *  - Handles one request at a time.
  *  - Communicates with two interfaces
  *     - processor side
  *       - usually a bus interface
  *       - Could also be connected to a directory controller if the directory
  *         is associated with a secondary cache rather than main memory.
  *     - Memory side
  *       - bus interface or a noc interface
  *       - should be agnostic to the interface connected
  *  - This version of the controller shows a much conservative behavior in
  *    handling requests by blocking until it receives a response to a request
  *    from the interface it is currently communicating with. The only
  *    exception to this is when the noc_interface issues a REQ_FLUSH or
  *    FwdGetS request while the controller is waiting for a response from the
  *    noc interface.
  *  Paramters
  *  ---------
    *  INCLUSION: Determines whether the cache tracks inclusion or not.
    *     - 1: Tracks whether a cache line is cached in upper levels
    *     - 0: Agnostic to whether a line is cached in upper levels.
    *  LAST_LEVEL: Indicate whether this cache is the last level of the
    *     coherence domain. If so, silent evictions and upgrades from S to M are
    *     allowed. If not the cache should inform the directory or the shared
    *     cache below writing to shared lines (and evictions if MEM_SIDE = "DIR").
    *  MEM_SIDE: Indicate the type of coherence mechanism on the memory side.
    *     - DIR  : Directory based coherence
    *     - SNOOP: Snooping on a shared bus
  *
  *  I/O ports
  *  ---------
*/


module Lxcache_controller #(
parameter STATUS_BITS      = 3, // Valid bit + Dirty bit + include
          /*include bit is always zero if not tracking inclusion*/
          INCLUSION        = 1, //track inclusion
          COHERENCE_BITS   = 2,
          OFFSET_BITS      = 2,
          DATA_WIDTH       = 32,
          NUMBER_OF_WAYS   = 4,
          ADDRESS_BITS     = 32,
          INDEX_BITS       = 10,
          MSG_BITS         = 4,
          LAST_LEVEL       = 0,
          MEM_SIDE         = "DIR",
          //Do not modify this parameter unless you undestand the memory subsystem
		      //latencies clearly
		      REISSUE_COUNT    = 1000,
          //Use default value in module instantiation for following parameters
          CACHE_WORDS      = 1 << OFFSET_BITS, //number of words in one line.
          CACHE_WIDTH      = DATA_WIDTH*CACHE_WORDS,
          MBITS            = COHERENCE_BITS + STATUS_BITS,
          TAG_BITS         = ADDRESS_BITS - OFFSET_BITS - INDEX_BITS,
          WAY_BITS         = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1
)(
input clock,
input reset,
//signals to/from bus interface
input  [ADDRESS_BITS-1:0] address,
input  [CACHE_WIDTH-1 :0] data_in,
input  [MSG_BITS-1    :0] msg_in,
input  pending_requests, //not used. Added to preserve the interface
output [CACHE_WIDTH-1 :0] data_out,
output [ADDRESS_BITS-1:0] out_address,
output [MSG_BITS-1    :0] msg_out,
//signals to/from memory side interface
input  [MSG_BITS-1    :0] mem2cache_msg,
input  [ADDRESS_BITS-1:0] mem2cache_address,
input  [CACHE_WIDTH-1 :0] mem2cache_data,
input  mem_intf_busy,
input  [ADDRESS_BITS-1:0] mem_intf_address,
input  mem_intf_address_valid,
output [MSG_BITS-1    :0] cache2mem_msg,
output [ADDRESS_BITS-1:0] cache2mem_address,
output [CACHE_WIDTH-1 :0] cache2mem_data,
//signals to/from cache_memory
output read0, write0, invalidate0,
output [INDEX_BITS-1  :0] index0,
output [TAG_BITS-1    :0] tag0,
output [MBITS-1       :0] meta_data0,
output [CACHE_WIDTH-1 :0] data0,
output [WAY_BITS-1    :0] way_select0,
output i_reset,
input  [CACHE_WIDTH-1 :0] data_in0,
input  [TAG_BITS-1    :0] tag_in0,
input  [WAY_BITS-1    :0] matched_way0,
input  [COHERENCE_BITS-1:0] coh_bits0,
input  [STATUS_BITS-1 :0] status_bits0,
input  hit0,
//scan
input  scan
);

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value >> 1;
  end
endfunction

localparam CACHE_DEPTH = 1 << INDEX_BITS;

localparam IDLE           = 4'd0,
           SEND_INDEX     = 4'd1, //initiate read from cache memory
           READING        = 4'd2,
           SERVING        = 4'd3,
           RECALL         = 4'd4, //not used in this version of the controller
           RESPOND        = 4'd5,
           WRITE_BACK     = 4'd6,
           READ_STATE     = 4'd7,
           READ_WAIT      = 4'd8,
           EVICT_WAIT     = 4'd9,
           FLUSH_WAIT     = 4'd10,
           WAIT_WS_ENABLE = 4'd11,
           RESET          = 4'd12,
           BACKOFF        = 4'd13;

`include `INCLUDE_FILE

genvar i;
integer j;

reg [3:0] state;
reg [INDEX_BITS-1:0] reset_counter;
reg write, invalidate;
reg [MSG_BITS-1:0] r_msg;
reg [ADDRESS_BITS-1:0] r_address;
reg [DATA_WIDTH-1:0] r_data [CACHE_WORDS-1:0];
reg [DATA_WIDTH-1:0] r_data_out [CACHE_WORDS-1:0];
reg [DATA_WIDTH-1:0] r_data0 [CACHE_WORDS-1:0];
reg r_hit, r_valid, r_dirty, r_include;
reg [COHERENCE_BITS-1:0] r_coh_bits;
reg [TAG_BITS-1:0] r_tag, r_tag_out;
reg [WAY_BITS-1:0] r_matched_way, r_way_select;
reg [MSG_BITS-1:0] r_msg_out;
reg [MBITS-1       :0] r_meta_data;
reg [MSG_BITS-1    :0] r_cache2mem_msg;
reg [ADDRESS_BITS-1:0] r_cache2mem_address;
reg recall_active;
reg [ADDRESS_BITS-1:0] recall_address;
reg recall_invalidate;
reg own_flush_req;
reg [ADDRESS_BITS-1:0] own_flush_req_addr;


wire request, mem_request, mem_response;
wire coh_request;
wire [DATA_WIDTH-1:0] w_data_in   [CACHE_WORDS-1:0];
wire [DATA_WIDTH-1:0] w_read_data [CACHE_WORDS-1:0];
wire [DATA_WIDTH-1:0] w_mem_data  [CACHE_WORDS-1:0];
wire collision;
wire response_address_match;


//assignments
assign i_reset = reset | (state == RESET);

assign coh_request = (msg_in == C_WB) | (msg_in == C_FLUSH);

assign request = (msg_in == WB_REQ   ) | (msg_in == R_REQ)    |
                 (msg_in == RFO_BCAST) | (msg_in == FLUSH)    |
                 (msg_in == EN_ACCESS) | (msg_in == WS_BCAST) |
                 coh_request           ;

assign mem_request = (mem2cache_msg == REQ_FLUSH) | (mem2cache_msg == FwdGetS);

assign mem_response = (mem2cache_msg == MEM_RESP) | (mem2cache_msg == MEM_C_RESP)
                    | (mem2cache_msg == EN_ACCESS); 

/*collision signal detects whether the cache controller is about to operate
* on the same cache line as the memory side interface. In this case the
* interface gets priority over the cache controller.*/
assign collision = (r_address[ADDRESS_BITS-1:OFFSET_BITS] == mem_intf_address
                   [ADDRESS_BITS-1:OFFSET_BITS]) & mem_intf_address_valid;

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin:SEPARATE_INPUTS
    assign w_data_in[i]   = data_in[i*DATA_WIDTH +: DATA_WIDTH];
    assign w_read_data[i] = data_in0[i*DATA_WIDTH +: DATA_WIDTH];
    assign w_mem_data[i]  = mem2cache_data[i*DATA_WIDTH +: DATA_WIDTH];
  end
endgenerate


/*FSM*/
always @(posedge clock)begin
  if(reset & (state != RESET))begin
    reset_counter         <= {INDEX_BITS{1'b0}};
    write                 <= 1'b0;
    invalidate            <= 1'b1;
    r_cache2mem_msg       <= NO_REQ;
    r_cache2mem_address   <= {ADDRESS_BITS{1'b0}};
    r_msg                 <= NO_REQ;
    r_address             <= {ADDRESS_BITS{1'b0}};
    r_hit                 <= 1'b0;
    r_valid               <= 1'b0;
    r_dirty               <= 1'b0;
    r_include             <= 1'b0;
    r_coh_bits            <= {COHERENCE_BITS{1'b0}};
    r_tag                 <= {TAG_BITS{1'b0}};
    r_tag_out             <= {TAG_BITS{1'b0}};
    r_matched_way         <= {WAY_BITS{1'b0}};
    r_way_select          <= {WAY_BITS{1'b0}};
    r_msg_out             <= NO_REQ;
    r_meta_data           <= {MBITS{1'b0}};
    recall_active         <= 1'b0;
    recall_invalidate     <= 1'b0;
    recall_address        <= {ADDRESS_BITS{1'b0}};
    own_flush_req         <= 1'b0;
    own_flush_req_addr    <= {ADDRESS_BITS{1'b0}};
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_data[j]           <= {DATA_WIDTH{1'b0}};
      r_data_out[j]       <= {DATA_WIDTH{1'b0}};
      r_data0[j]          <= {DATA_WIDTH{1'b0}};
    end
    state                 <= RESET;
  end
  else begin
    case(state)
      RESET:begin
        if(reset_counter < CACHE_DEPTH-1)begin
          reset_counter <= reset_counter + 1;
        end
        else if((reset_counter == CACHE_DEPTH-1) & ~reset)begin
          reset_counter <= {INDEX_BITS{1'b0}};
          invalidate    <= 1'b0;
          state         <= IDLE;
        end
        else
          state <= RESET;
      end
      IDLE:begin
        if(mem_request & ~recall_active & ~own_flush_req)begin
          r_msg             <= mem2cache_msg;
          r_address         <= mem2cache_address;
          /*no data because this is always an invalidation request*/
          //recall_active     <= 1'b1;
          //recall_invalidate <= 1'b1;
          state             <= SEND_INDEX;        
        end
        else if(request)begin
          r_msg     <= msg_in;
          r_address <= address;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_data[j] <= w_data_in[j];
          end
          state                 <= SEND_INDEX;          
        end
        else begin
          state <= IDLE;
        end
      end
      BACKOFF:begin
        state <= collision ? BACKOFF : IDLE;
        /*This works because both processor side and memory side interfaces
        * hold requests until the controller responds.*/
      end
      SEND_INDEX:begin
        state <= READING;
      end
      READING:begin
	    /*Backoff if there is an address collision with the mem-side interface*/
	      if(collision)
	        state <= BACKOFF;
		    else begin
          r_hit         <= hit0;
          r_valid       <= status_bits0[STATUS_BITS-1];
          r_dirty       <= status_bits0[STATUS_BITS-2];
          r_include     <= status_bits0[STATUS_BITS-3];
          r_coh_bits    <= coh_bits0;
          r_tag         <= tag_in0;
          r_matched_way <= matched_way0;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_data_out[j] <= w_read_data[j];
          end
          state <= SERVING;
		    end
      end
      SERVING:begin
        if(collision)
          state <= BACKOFF;
        else begin
          case(r_msg)
            R_REQ:begin
              if(r_hit)begin
                r_msg_out    <= (r_include | r_coh_bits == SHARED) ? MEM_RESP_S 
                              : MEM_RESP;
                write        <= 1'b1;
                r_tag_out    <= r_tag;
                r_way_select <= r_matched_way;
                r_meta_data  <= {1'b1, r_dirty, 1'b1, r_coh_bits};
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data[j]  <= r_data_out[j];
                  r_data0[j] <= r_data_out[j];
                end
                state <= RESPOND;
              end
              else begin
                if(r_include)begin
                  r_msg_out                             <= REQ_FLUSH;
                  r_address[ADDRESS_BITS-1 -: TAG_BITS] <= r_tag;
                  own_flush_req                         <= 1'b1;
                  own_flush_req_addr                    <= {r_tag, 
                  r_address[OFFSET_BITS +: INDEX_BITS], {OFFSET_BITS{1'b0}}};
                  state                                 <= RESPOND;
                end
                else if(r_dirty)begin
                  r_cache2mem_msg     <= WB_REQ;
                  r_cache2mem_address <= {r_tag, r_address[OFFSET_BITS +: 
                                         INDEX_BITS], {OFFSET_BITS{1'b0}}};
                  for(j=0; j<CACHE_WORDS; j=j+1)begin
                    r_data[j]         <= r_data_out[j];
                  end
                  state                <= WRITE_BACK;
                end
                else begin
                  if(r_valid & !LAST_LEVEL & (MEM_SIDE == "DIR"))begin //valid line to be evicted
                    r_cache2mem_msg     <= PutS;
                    r_cache2mem_address <= {r_tag, r_address[OFFSET_BITS +: 
                                           INDEX_BITS], {OFFSET_BITS{1'b0}}};
                    state               <= EVICT_WAIT;
                  end
                  else begin //not a valid line
                    r_cache2mem_msg     <= R_REQ;
                    r_cache2mem_address <= {r_address[ADDRESS_BITS-1:OFFSET_BITS], 
                                           {OFFSET_BITS{1'b0}}};
                    state               <= READ_WAIT;
                  end
                end
              end
            end
            RFO_BCAST:begin
              if(r_hit)begin
              /*line can already be in another Lx cache. Action depends on the
              * line's coherence state.*/
                if(r_coh_bits == MODIFIED | r_coh_bits == EXCLUSIVE)begin
                  r_msg_out    <= MEM_RESP;
                  write        <= 1'b1;
                  r_tag_out    <= r_tag;
                  r_way_select <= r_matched_way;
                  r_meta_data  <= {1'b1, r_dirty, 1'b1, MODIFIED};
                  for(j=0; j<CACHE_WORDS; j=j+1)begin
                    r_data[j]  <= r_data_out[j];
                    r_data0[j] <= r_data_out[j];
                  end
                  state <= RESPOND;
                end
                else begin //line in Shared state
                  r_cache2mem_msg     <= WS_BCAST;
                  r_cache2mem_address <= {r_address[ADDRESS_BITS-1:OFFSET_BITS], 
                                         {OFFSET_BITS{1'b0}}};
                  state               <= WAIT_WS_ENABLE;
                end
              end
              else begin
                if(r_include)begin
                  r_msg_out                             <= REQ_FLUSH;
                  r_address[ADDRESS_BITS-1 -: TAG_BITS] <= r_tag;
                  own_flush_req                         <= 1'b1;
                  own_flush_req_addr                    <= {r_tag, 
                      r_address[OFFSET_BITS +: INDEX_BITS], {OFFSET_BITS{1'b0}}};
                  state                                 <= RESPOND;
                end
                else if(r_dirty)begin
                  r_cache2mem_msg     <= WB_REQ;
                  r_cache2mem_address <= {r_tag, r_address[OFFSET_BITS +: 
                                         INDEX_BITS], {OFFSET_BITS{1'b0}}};
                  for(j=0; j<CACHE_WORDS; j=j+1)begin
                    r_data[j] <= r_data_out[j];
                  end
                  state               <= WRITE_BACK;
                end
                else begin
                  if(r_valid & !LAST_LEVEL & (MEM_SIDE == "DIR"))begin //valid line
                    r_cache2mem_msg     <= PutS;
                    r_cache2mem_address <= {r_tag, r_address[OFFSET_BITS +: 
                                           INDEX_BITS], {OFFSET_BITS{1'b0}}};
                    state               <= EVICT_WAIT;
                  end
                  else begin
                    r_cache2mem_msg     <= RFO_BCAST;
                    r_cache2mem_address <= {r_address[ADDRESS_BITS-1:OFFSET_BITS], 
                                           {OFFSET_BITS{1'b0}}};
                    state               <= READ_WAIT;
                  end
                end
              end
            end
            WB_REQ:begin
              if(r_hit)begin
                /*checking because non-inclusive caches are also supported*/
                write         <= 1'b1;
                r_tag_out     <= r_tag;
                r_way_select  <= r_matched_way;
                r_meta_data   <= {3'b110, MODIFIED};
                r_msg_out     <= MEM_RESP;
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data0[j] <= r_data[j];
                end
                state         <= RESPOND;
              end
              else begin // exclusive/non-inclusive cache hierarchy
              /*Cache acts as a write-through cache for a write miss. This
              * behavior will be changed later if necessary.
              * r_data does not have to be updated as in a normal writeback
              * because we are writing through the data written back by the
              * L(x-1) cache.*/
                r_cache2mem_msg     <= WB_REQ;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                state               <= WRITE_BACK;
              end
            end
            FLUSH:begin
              /*No checking for hit because both inclusive and non-inclusive 
              * behavior does the same here. Since the L1 cache issuing the
              * FLUSH has already obtained the exclusive copy of the line, Lx
              * cache only has to forward it to lower levels.
              * No need to check for inclusion since L1 cache flushing makes sure 
              * that it has the only valid copy of the line.
              * When the flushing L1 cache acquires an exclusive copy of the
              * cache line, Lx cache is also forced to do so. Therefore, no
              * need to do it again. Cache line should be in EXCLUSIVE or
              * MODIFIED state*/
              /*When invalidating the line, make sure that it is a hit.*/
              r_cache2mem_msg     <= FLUSH;
              r_cache2mem_address <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
                                     {OFFSET_BITS{1'b0}}};
              state               <= FLUSH_WAIT;
            end
            C_WB:begin
              write         <= 1'b1;
              r_tag_out     <= r_tag;
              r_way_select  <= r_matched_way;
              r_meta_data   <= {3'b110, r_coh_bits};
              r_msg_out     <= MEM_C_RESP;
              for(j=0; j<CACHE_WORDS; j=j+1)begin
                r_data0[j] <= r_data[j];
              end
              state         <= RESPOND; 
            end
            C_FLUSH:begin //response to REQ_FLUSH
            /*changed behavior to only write to the cache memory without flushing
            * it to the next level. When the next time it needs to be replaced,
            * the line is not cached in L1 caches and can be written back.
            * When there is a flush request from the lower level for the same line, 
            * flush the line to the lower level immediately*/
              //if(recall_active & recall_address == r_address)begin
              //  invalidate           <= 1'b1;
              //  r_tag_out            <= r_tag;
              //  r_way_select         <= r_matched_way;
              //  r_cache2mem_address  <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
              //                          {OFFSET_BITS{1'b0}}};
              //  r_cache2mem_msg      <= C_FLUSH;
              //  //recall_active        <= 1'b0;
              //  r_msg_out            <= MEM_C_RESP;//TODO: possible to reduce to MEM_RESP?
              //  state                <= RESPOND;
              //end
              //else begin
                write         <= 1'b1;
                r_tag_out     <= r_tag;
                r_way_select  <= r_matched_way;
                r_meta_data   <= {3'b110, r_coh_bits};
                r_msg_out     <= MEM_C_RESP; //might be reduced to MEM_RESP
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data0[j] <= r_data[j];
                end
                state         <= RESPOND;
              //end
            end
            REQ_FLUSH:begin //from memory side (same encoding as Inv)
            /*By this point, the memory side interface has already checked
            * whether the line exists in the cache. Repond depending on the
            * state of the line.*/
              if(r_include)begin //recall the line
                r_msg_out         <= REQ_FLUSH;
                recall_address    <= r_address;
                recall_active     <= 1'b1;
                recall_invalidate <= 1'b1;
                state             <= RESPOND;
              end
              else if(r_dirty)begin //Flush the line
                r_cache2mem_msg     <= C_FLUSH;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                invalidate          <= 1'b1;
                r_tag_out           <= r_tag;
                r_way_select        <= r_matched_way;
                state               <= RESPOND;
              end
              else if(r_hit)begin //Line is clean. Invalidate and send EN_ACCESS
                r_cache2mem_msg     <= EN_ACCESS;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                invalidate          <= 1'b1;
                r_tag_out           <= r_tag;
                r_way_select        <= r_matched_way;
                state               <= RESPOND;
                /*interface cannot be busy. Handling request from interface.*/
              end
            end
            FwdGetS:begin
              if(r_include)begin
              /*memory-side interface has already checked for the cache hit.*/
                r_msg_out           <= REQ_FLUSH;
                recall_address      <= r_address;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                recall_active       <= 1'b1;
                recall_invalidate   <= 1'b0;
                state               <= RESPOND;
              end
              /*Checking other conditions in case the line was written back in
              * while the request was forwarded by the interface.*/
              else if(r_dirty)begin //Flush the line change state M -> S
                r_cache2mem_msg     <= C_FLUSH;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                write               <= 1'b1;
                r_tag_out           <= r_tag;
                r_way_select        <= r_matched_way;
                r_meta_data         <= {3'b100, SHARED};
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data[j]  <= r_data_out[j];
                  r_data0[j] <= r_data_out[j];
                end
                state               <= RESPOND;
                /*interface cannot be busy. Same reasoning as above.*/
              end
              else begin //Line is clean/INVALID Send EN_ACCESS
                r_cache2mem_msg     <= EN_ACCESS;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                write               <= 1'b1;
                r_tag_out           <= r_tag;
                r_way_select        <= r_matched_way;
                r_meta_data         <= r_hit ? {3'b100, SHARED} : {3'b000, INVALID};
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data[j]  <= r_data_out[j];
                  r_data0[j] <= r_data_out[j];
                end
                state               <= RESPOND;
                /*interface cannot be busy. Same reasoning as above.*/
              end
            end
            EN_ACCESS:begin
              if(recall_active & recall_address == r_address)begin
                r_cache2mem_msg     <= r_dirty ? C_FLUSH : EN_ACCESS;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1 : OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data[j]         <= r_data_out[j];
                end
                invalidate          <= recall_invalidate;
                r_tag_out           <= r_tag;
                r_way_select        <= r_matched_way;
                r_msg_out           <= MEM_RESP; //This response is required by the 
                                                 //bus interface to release the
                                                 //bus
                recall_active       <= 1'b0;
                recall_invalidate   <= 1'b0;
                state               <= RESPOND;
                /*interface cannot be busy. Same reasoning as above.*/
              end
              else if(own_flush_req & own_flush_req_addr == r_address)begin
              /*Flush request was issued by the Lxcache because there is a line
              * which needs to be evicted but the inclusion bit is set*/
                write         <= 1'b1;
                r_tag_out     <= r_tag;
                r_way_select  <= r_matched_way;
                r_meta_data   <= {r_valid, r_dirty, 1'b0, r_coh_bits};
                r_msg_out     <= MEM_RESP;
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data0[j]  <= r_data_out[j];
                end
                own_flush_req <= 1'b0;
                state         <= RESPOND;
              end
              else begin
                r_msg_out       <= NO_REQ;
                r_cache2mem_msg <= NO_REQ;
                state           <= IDLE;
              end
            end
            WS_BCAST:begin
              if(r_hit)begin //inclusive cache
                if(r_coh_bits == MODIFIED)begin
                  r_msg_out    <= EN_ACCESS;
                  state        <= RESPOND;  
                end
                else if(r_coh_bits == EXCLUSIVE)begin
                  r_msg_out    <= EN_ACCESS;
                  write        <= 1'b1;
                  r_tag_out    <= r_tag;
                  r_way_select <= r_matched_way;
                  r_meta_data  <= {3'b101, MODIFIED};
                  for(j=0; j<CACHE_WORDS; j=j+1)begin
                    r_data0[j] <= r_data_out[j];
                  end
                  state        <= RESPOND;  
                end
                else if(r_coh_bits == SHARED)begin //upgrade request
                  r_cache2mem_msg     <= WS_BCAST;
                  r_cache2mem_address <= {r_address[ADDRESS_BITS-1:OFFSET_BITS], 
                                         {OFFSET_BITS{1'b0}}};
                  state                <= WAIT_WS_ENABLE;
                end
              end
              else begin
              /*Exclusive cache behavior not fully supported. Review and update in 
              * later iteration.*/
                r_msg_out <= EN_ACCESS;
                state     <= IDLE;
              end
            end
            default:begin
              state <= IDLE;
            end
          endcase
        end
      end
      WRITE_BACK:begin
        if(mem_request)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= IDLE;
        end
        else if(mem2cache_msg == MEM_RESP)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          invalidate          <= 1'b1;
          r_tag_out           <= r_tag;
          r_way_select        <= r_matched_way;
          state               <= (r_msg == WB_REQ & ~r_hit) ? IDLE : READ_STATE;
          /*Cache miss for a WB_REQ is only possible when the cache is
          * non-inclusive. Cache acts as a write through in such a situation.
          * Therefore, go to IDLE after writing back.*/
        end
        else
          state <= WRITE_BACK;
      end
      READ_STATE:begin
        invalidate          <= 1'b0;
        r_cache2mem_msg     <= r_msg; //R_REQ or RFO_BCAST
        r_cache2mem_address <= {r_address[ADDRESS_BITS-1:OFFSET_BITS],
                               {OFFSET_BITS{1'b0}}};
        state               <= READ_WAIT;
      end
      READ_WAIT:begin
        if(mem_request)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= IDLE;
        end
        else if(mem2cache_msg == MEM_RESP | mem2cache_msg == MEM_RESP_S)begin
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_data[j]     <= w_mem_data[j];
            r_data_out[j] <= w_mem_data[j];
          end
          r_tag_out           <= r_address[ADDRESS_BITS-1 -: TAG_BITS];
          r_way_select        <= r_matched_way;
          r_meta_data[4:2]    <= INCLUSION ? 3'b101 : 3'b100;
          r_meta_data[1:0]    <= (r_msg == RFO_BCAST) ? MODIFIED :
                                 (mem2cache_msg == MEM_RESP) ? EXCLUSIVE : SHARED;
          /*If the line is fetched by a RFO_BCAST message, set the coherence
          * state to MODIFIED because the L(x-1) cache will modify it 
          * immediately.*/
          write               <= 1'b1;
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          r_msg_out           <= mem2cache_msg;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_data0[j] <= w_mem_data[j];
          end
          state               <= RESPOND;
        end
        else
          state <= READ_WAIT;
      end
      EVICT_WAIT:begin
        if(mem_request)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= IDLE;
        end
        else if(mem2cache_msg == MEM_RESP)begin //TODO check the conversion in noc interface
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          //invalidation should be done here
          invalidate          <= 1'b1;
          r_tag_out           <= r_tag;
          r_way_select        <= r_matched_way;
          state               <= READ_STATE;
        end
        else
          state <= EVICT_WAIT; 
      end
      WAIT_WS_ENABLE:begin
        if(mem_request)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= IDLE;
        end
        else if(mem2cache_msg == EN_ACCESS)begin //noc interface converts directory 
                                                 //response to EN_ACCESS
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          write               <= 1'b1;
          r_tag_out           <= r_tag;
          r_way_select        <= r_matched_way;
          r_meta_data         <= INCLUSION ? {3'b101, MODIFIED} : {3'b100, MODIFIED};
          /*Not marked as dirty until L1 writes back.
          * This state can only be reached through a RFO_BCAST or WS_BCAST
          * from an L(x-1) cache. In both cases the L(x-1) cache received
          * a write request from the core. Once the data is returned it will
          * modify the line. Therefore, it is okay to mark the coherence state
          * as MODIFIED at this point.
          * Other option is to do a silent E->M upgrade when the L(x-1) cache
          * writes back.*/
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_data0[j] <= r_data_out[j];
          end
          if(r_msg == FLUSH)begin
            r_coh_bits <= EXCLUSIVE;
            state      <= SERVING; //now the line can be flushed.
          end
          else begin
            r_msg_out  <= (r_msg == WS_BCAST) ? EN_ACCESS : MEM_RESP;
            state      <= RESPOND;
          end
        end
        else
          state <= WAIT_WS_ENABLE;
      end
      RESPOND:begin
        write                 <= 1'b0;
        invalidate            <= 1'b0;
        r_msg_out             <= (r_msg_out == REQ_FLUSH) ? r_msg_out : NO_REQ;
        r_cache2mem_msg       <= NO_REQ;
        state                 <= IDLE;
      end
      FLUSH_WAIT:begin
        if(mem_request)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= IDLE;
        end
        else if(mem2cache_msg == MEM_RESP)begin
          r_msg_out           <= MEM_RESP;
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          invalidate          <= r_hit ? 1'b1 : 1'b0;
          r_tag_out           <= r_tag;
          r_way_select        <= r_matched_way;
          state               <= RESPOND;
        end
        else
          state <= FLUSH_WAIT;
      end
      RECALL:begin
        state <= IDLE;  
      end
      default:begin
        state <= IDLE;
      end
    endcase
  end
end


//assign outputs
assign read0       = (state == SEND_INDEX);
assign write0      = write;
assign invalidate0 = invalidate;
assign tag0        = (state == SEND_INDEX) ? r_address[ADDRESS_BITS-1 -: TAG_BITS] 
                   : r_tag_out;
assign meta_data0  = r_meta_data;
assign way_select0 = r_way_select;

assign index0 = (state == RESET) ? reset_counter :
                r_address[OFFSET_BITS +: INDEX_BITS];

assign msg_out     = r_msg_out;
assign out_address = r_address;

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin: DATAOUT
    assign data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_data_out[i]; 
  end
  for(i=0; i<CACHE_WORDS; i=i+1)begin: C2MDATA
    assign cache2mem_data[i*DATA_WIDTH +: DATA_WIDTH] = r_data[i]; 
  end
  for(i=0; i<CACHE_WORDS; i=i+1)begin: WRITEDATA
    assign data0[i*DATA_WIDTH +: DATA_WIDTH] = r_data0[i]; 
  end
endgenerate

assign cache2mem_msg     = r_cache2mem_msg;
assign cache2mem_address = r_cache2mem_address;


endmodule



















