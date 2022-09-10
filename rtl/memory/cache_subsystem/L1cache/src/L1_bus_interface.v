/** @module : L1_bus_interface
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

module L1_bus_interface #(
parameter CACHE_OFFSET_BITS =  2, //max offset bits from cache side
          BUS_OFFSET_BITS   =  1, //determines width of the bus
          DATA_WIDTH        = 32,
          ADDRESS_WIDTH     = 32,
          MSG_BITS          =  4,
          MAX_OFFSET_BITS   =  3
)(
clock, 
reset,
cache_offset, //current offset_bits of the cache.

cache_msg_in,
cache_address_in,
cache_data_in,
cache_msg_out,
cache_address_out,
cache_data_out,

snoop_msg_in,
snoop_address_in,
snoop_data_in,
snoop_msg_out,
snoop_address_out,
snoop_data_out,

bus_msg_in,
bus_address_in,
bus_data_in,
bus_msg_out,
bus_address_out,
bus_data_out,
active_offset,

bus_master,
req_ready
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
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam BUS_WIDTH   = DATA_WIDTH*BUS_WORDS;

localparam IDLE              =  4'd0,
           SNOOPER_REQ       =  4'd1,
           CACHE_REQ         =  4'd2, 
           SN_WAIT_FOR_BUS   =  4'd3,
           SN_WAIT_FOR_READY =  4'd4,
           SN_TRANSFER       =  4'd5,
           SN_WAIT_RESP      =  4'd6,
           WAIT_FOR_BUS      =  4'd7,
           WAIT_RESP         =  4'd8,
           TRANSFER          =  4'd9,
           RECEIVE           = 4'd10,
           WAIT_FOR_SNOOP    = 4'd11,
           WAIT_FOR_CACHE    = 4'd12,
           HOLD_BUS_SN       = 4'd13;

`include `INCLUDE_FILE

input clock, reset;
input  [log2(CACHE_OFFSET_BITS):0] cache_offset;

input  [MSG_BITS-1:      0] cache_msg_in     ;
input  [ADDRESS_WIDTH-1: 0] cache_address_in ;
input  [CACHE_WIDTH-1:   0] cache_data_in    ;
output [MSG_BITS-1:      0] cache_msg_out    ;
output [ADDRESS_WIDTH-1: 0] cache_address_out;
output [CACHE_WIDTH-1:   0] cache_data_out   ;

input  [MSG_BITS-1:      0] snoop_msg_in     ;
input  [ADDRESS_WIDTH-1: 0] snoop_address_in ;
input  [CACHE_WIDTH-1:   0] snoop_data_in    ;
output [MSG_BITS-1:      0] snoop_msg_out    ;
output [ADDRESS_WIDTH-1: 0] snoop_address_out;
output [CACHE_WIDTH-1:   0] snoop_data_out   ;

input  [MSG_BITS-1:      0]     bus_msg_in  ;
input  [ADDRESS_WIDTH-1: 0] bus_address_in  ;
input  [BUS_WIDTH-1:     0]    bus_data_in  ;
output [MSG_BITS-1:      0]     bus_msg_out ;
output [ADDRESS_WIDTH-1: 0] bus_address_out ;
output [BUS_WIDTH-1:     0]    bus_data_out ;
output [log2(MAX_OFFSET_BITS):0] active_offset;

input req_ready;
input bus_master;


genvar i;
integer j;
reg [3:0] state;
reg [DATA_WIDTH-1:0] r_cache_data_out [CACHE_WORDS-1:0];
reg [DATA_WIDTH-1:0] r_snoop_data_out [CACHE_WORDS-1:0];
reg [DATA_WIDTH-1:0] r_bus_data_out   [BUS_WORDS-1:  0];

reg [MSG_BITS-1:     0] r_cache_msg_out, r_bus_msg_out, r_snoop_msg_out;
reg [ADDRESS_WIDTH-1:0] r_cache_address_out, r_bus_address_out,
                        r_snoop_address_out;

reg [MAX_OFFSET_BITS:0] block_counter;
reg [MAX_OFFSET_BITS:0] word_counter;

reg current_owner; /*0-cache; 1-snooper*/ //what owns the bus interface.
reg [MSG_BITS-1:0] curr_msg;
reg [ADDRESS_WIDTH-1:0] curr_address;
reg [DATA_WIDTH-1:0] curr_data [CACHE_WORDS-1:0];

wire [DATA_WIDTH-1:0] w_cache_data_in [CACHE_WORDS-1: 0];
wire [DATA_WIDTH-1:0] w_snoop_data_in [CACHE_WORDS-1: 0];
wire [DATA_WIDTH-1:0] w_bus_data_in   [BUS_WORDS-1:   0];

wire [MAX_OFFSET_BITS-1:0] offset_diff;
wire [CACHE_OFFSET_BITS  :0] current_words;
wire [MAX_OFFSET_BITS    :0] ratio;
wire wider_bus, wider_line;
wire cache_req,  snoop_req;

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin : SPLIT_INPUTS
    assign w_cache_data_in[i] = (i < current_words) ? 
                                cache_data_in[i*DATA_WIDTH +: DATA_WIDTH] :
                                {DATA_WIDTH{1'b0}};
    assign w_snoop_data_in[i] = (i < current_words) ?
                                snoop_data_in[i*DATA_WIDTH +: DATA_WIDTH] :
                                {DATA_WIDTH{1'b0}};
  end
  for(i=0; i<BUS_WORDS; i=i+1)begin: SPLIT_BUS
    assign w_bus_data_in[i] = bus_data_in[i*DATA_WIDTH +: DATA_WIDTH];
  end
endgenerate

assign current_words = 1 << cache_offset;

assign offset_diff = (cache_offset   >= BUS_OFFSET_BITS) ?
                     (cache_offset    - BUS_OFFSET_BITS) :
                     (BUS_OFFSET_BITS - cache_offset   ) ;

assign ratio = 1 << offset_diff;
assign wider_bus  = BUS_OFFSET_BITS >= cache_offset;
assign wider_line = cache_offset > BUS_OFFSET_BITS;

assign cache_req = (cache_msg_in == R_REQ)    | (cache_msg_in == WB_REQ)   |
                   (cache_msg_in == FLUSH)    | (cache_msg_in == FLUSH_S)  |
                   (cache_msg_in == WS_BCAST) | (cache_msg_in == RFO_BCAST);

assign snoop_req = (snoop_msg_in == C_WB)     | (snoop_msg_in == C_FLUSH) |
                   (snoop_msg_in == EN_ACCESS);

//assign outputs
assign active_offset = cache_offset;
assign cache_msg_out     = r_cache_msg_out;
assign cache_address_out = r_cache_address_out;
assign snoop_msg_out     = r_snoop_msg_out;
assign snoop_address_out = r_snoop_address_out;
assign bus_msg_out       = r_bus_msg_out;
assign bus_address_out   = r_bus_address_out;

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin: OUTDATA
    assign cache_data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_cache_data_out[i];
    assign snoop_data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_snoop_data_out[i];
  end
  for(i=0; i<BUS_WORDS; i=i+1)begin: OUTBUS
    assign bus_data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_bus_data_out[i];
  end
endgenerate



always @(posedge clock)begin
  if(reset)begin
    r_cache_msg_out     <= NO_REQ;
    r_snoop_msg_out     <= NO_REQ;
    r_bus_msg_out       <= NO_REQ;
    r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
    r_snoop_address_out <= {ADDRESS_WIDTH{1'b0}};
    r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
    block_counter       <= {(MAX_OFFSET_BITS+1){1'b0}};
    word_counter        <= {(MAX_OFFSET_BITS+1){1'b0}};
    current_owner       <= 1'b0;
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_cache_data_out[j] <= {DATA_WIDTH{1'b0}};
      r_snoop_data_out[j] <= {DATA_WIDTH{1'b0}};
      curr_data[j]        <= {DATA_WIDTH{1'b0}};
    end
    for(j=0; j<BUS_WORDS; j=j+1)begin
      r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
    end
    state <= IDLE;
  end
  else if(~current_owner & snoop_req)begin
    curr_msg       <= snoop_msg_in;
    curr_address   <= snoop_address_in;
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      curr_data[j] <= snoop_data_in[j*DATA_WIDTH +: DATA_WIDTH];
    end
    current_owner  <= 1'b1;
    state          <= SNOOPER_REQ;
  end
  else begin
    case(state)
      IDLE:begin
        if(snoop_req)begin
          curr_msg       <= snoop_msg_in;
          curr_address   <= snoop_address_in;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            curr_data[j] <= snoop_data_in[j*DATA_WIDTH +: DATA_WIDTH];
          end
          current_owner  <= 1'b1;
          state          <= SNOOPER_REQ;
        end
        else if(cache_req)begin
          curr_msg       <= cache_msg_in;
          curr_address   <= cache_address_in;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            curr_data[j] <= cache_data_in[j*DATA_WIDTH +: DATA_WIDTH];
          end
          current_owner  <= 1'b0;
          state          <= CACHE_REQ;
        end
        else
          state <= IDLE;
      end
      SNOOPER_REQ:begin
        r_bus_msg_out     <= curr_msg;
        r_bus_address_out <= curr_address;
        state             <= (curr_msg == EN_ACCESS) ? SN_WAIT_FOR_READY :
                             SN_WAIT_FOR_BUS; 
      end
      SN_WAIT_FOR_READY:begin
        if(req_ready)begin
          r_bus_msg_out       <= NO_REQ;
          r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
          r_snoop_msg_out     <= EN_ACCESS;
          r_snoop_address_out <= curr_address;
          state               <= WAIT_FOR_SNOOP;
        end
        else
          state <= SN_WAIT_FOR_READY;
      end
      SN_WAIT_FOR_BUS:begin
        if(bus_master)begin
          if(wider_line)begin
            r_bus_address_out <= curr_address;
            for(j=0; j<BUS_WORDS; j=j+1)begin
              r_bus_data_out[j] = curr_data[j];
            end
            block_counter <= 1;
            word_counter  <= BUS_WORDS;
            state         <= SN_TRANSFER;
          end
          else if(wider_bus)begin
            r_bus_address_out <= curr_address;
            for(j=0; j<BUS_WORDS; j=j+1)begin
              if(j < current_words)
                r_bus_data_out[j] = curr_data[j];
              else
                r_bus_data_out[j] = {DATA_WIDTH{1'b0}};
            end
            block_counter <= 0;
            state         <= SN_WAIT_RESP;
          end
        end
        else
          state <= SN_WAIT_FOR_BUS;
      end
      SN_WAIT_RESP:begin
        if(bus_msg_in == MEM_C_RESP)begin
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
          end
          r_snoop_msg_out     <= MEM_RESP;
          r_snoop_address_out <= curr_address;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_snoop_data_out[j] <= {DATA_WIDTH{1'b0}};
          end
          r_bus_msg_out       <= HOLD_BUS;
          r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
          end
          state <= WAIT_FOR_SNOOP;
        end
      end
      SN_TRANSFER:begin
        if(block_counter == ratio)begin
          state <= SN_WAIT_RESP;
        end
        else begin
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= curr_data[word_counter + j];
          end
          block_counter <= block_counter + 1;
          word_counter  <= word_counter + BUS_WORDS;
          state         <= SN_TRANSFER;
        end
      end
      CACHE_REQ:begin
        r_bus_msg_out     <= curr_msg;
        r_bus_address_out <= curr_address;
        state             <= (curr_msg == NO_REQ) ? IDLE : WAIT_FOR_BUS;
      end
      WAIT_FOR_BUS:begin
        if(bus_master)begin
          if((curr_msg == R_REQ) | (curr_msg == RFO_BCAST) | 
          (curr_msg == FLUSH_S)  | (curr_msg == WS_BCAST ) )begin
            state <= WAIT_RESP;
          end
          else begin
            if(wider_line)begin
              for(j=0; j<BUS_WORDS; j=j+1)begin
                r_bus_data_out[j] <= curr_data[j];
              end
              block_counter <= 1;
              word_counter  <= BUS_WORDS;
              state         <= TRANSFER;
            end
            else if(wider_bus)begin
              for(j=0; j<BUS_WORDS; j=j+1)begin
                if(j < current_words)
                  r_bus_data_out[j] <= curr_data[j];
                else
                  r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
              end
              state <= WAIT_RESP;
            end
          end
        end
        else
          state <= WAIT_FOR_BUS;
      end
      WAIT_RESP:begin
        if((curr_msg == WB_REQ) | (curr_msg == FLUSH) | 
        (curr_msg == FLUSH_S))begin
          if(bus_msg_in == MEM_RESP)begin
            r_bus_msg_out     <= NO_REQ;
            r_bus_address_out <= {ADDRESS_WIDTH{1'b0}};
            for(j=0; j<BUS_WORDS; j=j+1)begin
              r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
            end
            r_cache_msg_out     <= MEM_RESP;
            r_cache_address_out <= curr_address;
            for(j=0; j<CACHE_WORDS; j=j+1)begin
              r_cache_data_out[j] <= {DATA_WIDTH{1'b0}};
            end
            state         <= WAIT_FOR_CACHE;
          end
          else
            state <= WAIT_RESP;
        end
        else if(curr_msg == WS_BCAST)begin
          if(req_ready)begin
            r_cache_msg_out     <= EN_ACCESS;
            r_cache_address_out <= curr_address;
            for(j=0; j<CACHE_WORDS; j=j+1)begin
              r_cache_data_out[j] <= {DATA_WIDTH{1'b0}};
            end
            state <= WAIT_FOR_CACHE;
          end
          else
            state <= WAIT_RESP;
        end
        else begin
          if((bus_msg_in == MEM_RESP) | (bus_msg_in == MEM_RESP_S))begin
            if(wider_line)begin
              for(j=0; j<BUS_WORDS; j=j+1)begin
                r_cache_data_out[j] <= w_bus_data_in[j];
              end
              block_counter <= 1;
              word_counter  <= BUS_WORDS;
              state <= RECEIVE;
            end
            else if(wider_bus)begin
              r_cache_msg_out     <= bus_msg_in;
              r_cache_address_out <= curr_address;
              for(j=0; j<CACHE_WORDS; j=j+1)begin
                r_cache_data_out[j] <= (j < BUS_WORDS) ? w_bus_data_in[j] :
					                             {DATA_WIDTH{1'b0}};
              end
              state <= WAIT_FOR_CACHE;
            end
          end
        end
      end
      TRANSFER:begin
        if(block_counter == ratio)begin
          state <= WAIT_RESP;
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
      RECEIVE:begin
        if(block_counter == ratio-1)begin
          r_cache_msg_out     <= bus_msg_in;
          r_cache_address_out <= curr_address;
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_cache_data_out[word_counter + j] <= w_bus_data_in[j];
          end
          state <= WAIT_FOR_CACHE;
        end
        else begin
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_cache_data_out[word_counter + j] <= w_bus_data_in[j];
          end
          block_counter <= block_counter + 1;
          word_counter  <= word_counter + BUS_WORDS;
          state         <= RECEIVE;
        end
      end
      WAIT_FOR_CACHE:begin
        r_cache_msg_out       <= NO_REQ;
        r_cache_address_out   <= {ADDRESS_WIDTH{1'b0}};
        for(j=0; j<CACHE_WORDS; j=j+1)begin
          r_cache_data_out[j] <= {DATA_WIDTH{1'b0}};
        end
        r_bus_msg_out       <= NO_REQ;
        r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
        for(j=0; j<BUS_WORDS; j=j+1)begin
          r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
        end
        current_owner <= 1'b0;
        state         <= IDLE;
      end
      WAIT_FOR_SNOOP:begin
        r_snoop_msg_out       <= NO_REQ;
        r_snoop_address_out   <= {ADDRESS_WIDTH{1'b0}};
        for(j=0; j<CACHE_WORDS; j=j+1)begin
          r_snoop_data_out[j] <= {DATA_WIDTH{1'b0}};
        end
        if(snoop_msg_in == NO_REQ)begin
          r_bus_msg_out       <= NO_REQ;
          r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
          end
          current_owner   <= 1'b0;
          state           <= IDLE;
        end
        else if(snoop_msg_in == HOLD_BUS)begin
          r_bus_msg_out       <= HOLD_BUS;
          r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
          end
          current_owner   <= 1'b1;
          state           <= HOLD_BUS_SN;
        end
        else if(snoop_msg_in == EN_ACCESS)begin
          r_bus_msg_out <= EN_ACCESS;
          r_bus_address_out <= curr_address;
          for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
          end
          state <= SN_WAIT_FOR_READY;
        end
        else begin
          state <= WAIT_FOR_SNOOP;
        end
      end
      HOLD_BUS_SN:begin
        if(snoop_req)begin
          curr_msg       <= snoop_msg_in;
          curr_address   <= snoop_address_in;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            curr_data[j] <= snoop_data_in[j*DATA_WIDTH +: DATA_WIDTH];
          end
          current_owner  <= 1'b1;
          state          <= SNOOPER_REQ;
        end
        else
          state <= HOLD_BUS_SN;
      end
      default:begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule
