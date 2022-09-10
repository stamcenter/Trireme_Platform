/** @module : snooper
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

module snooper #(
parameter CACHE_OFFSET_BITS =  2, //max offset bits from cache side
          BUS_OFFSET_BITS   =  1, //determines width of the bus
          DATA_WIDTH        = 32,
          ADDRESS_WIDTH     = 32,
          MSG_BITS          =  4,
          INDEX_BITS        =  8,  //max index bits for the cache
          COHERENCE_BITS    =  2,
          STATUS_BITS       =  2,
          NUMBER_OF_WAYS    =  4,
	        MAX_OFFSET_BITS   =  2
)(
clock,
reset,
data_in,
matched_way,
coh_bits,
status_bits,
hit,
read, 
write, 
invalidate,
index,
tag,
meta_data,
data_out,
way_select,

intf_msg,
intf_address,
intf_data,
snoop_msg,
snoop_address,
snoop_data,

bus_msg,
bus_address,
req_ready,
bus_master,
curr_offset
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
localparam SBITS       = COHERENCE_BITS + STATUS_BITS;
localparam TAG_BITS    = ADDRESS_WIDTH - CACHE_OFFSET_BITS - INDEX_BITS;
localparam WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;

localparam IDLE            = 3'd0,
           START           = 3'd1,
           READ_LINE       = 3'd2,
           WRITE_LINE      = 3'd3,
           INVALIDATE_LINE = 3'd4,
           ACTION          = 3'd5,
           WAIT_FOR_RESP   = 3'd6;



`include `INCLUDE_FILE


input clock, reset;
//interface to cache memory
input  [CACHE_WIDTH-1   :0] data_in;
input  [WAY_BITS-1      :0] matched_way;
input  [COHERENCE_BITS-1:0] coh_bits;
input  [STATUS_BITS-1   :0] status_bits;
input  hit;
output read, write, invalidate;
output [INDEX_BITS-1    :0] index;
output [TAG_BITS-1      :0] tag;
output [SBITS-1         :0] meta_data;
output [CACHE_WIDTH-1   :0] data_out;
output [WAY_BITS-1      :0] way_select;

//interface to L1 bus interface
input  [MSG_BITS-1:      0] intf_msg;
input  [ADDRESS_WIDTH-1: 0] intf_address;
input  [CACHE_WIDTH-1:   0] intf_data;
output [MSG_BITS-1:      0] snoop_msg;
output [ADDRESS_WIDTH-1: 0] snoop_address;
output [CACHE_WIDTH-1:   0] snoop_data;

//interface to the shared bus
input  [MSG_BITS-1:      0] bus_msg;
input  [ADDRESS_WIDTH-1: 0] bus_address;
input req_ready;
input bus_master;
input [log2(MAX_OFFSET_BITS):0] curr_offset;


//internal variables
genvar i;
integer j;

wire [DATA_WIDTH-1:0] w_cache_data [CACHE_WORDS-1:0];
wire [MAX_OFFSET_BITS-1:0] offset_diff;
wire [MAX_OFFSET_BITS  :0] ratio;
wire wider_transfer, wider_line;
wire read_req, write_req, flush_req, mflush_req;
wire dirty;


reg [2:0] state;
reg r_read, r_write, r_invalidate;
reg [INDEX_BITS-1 :0] r_index;
reg [TAG_BITS-1   :0] r_tag;
reg [SBITS-1      :0] r_meta_data;
reg [DATA_WIDTH-1: 0] r_data_out [CACHE_WORDS-1:0];
reg [WAY_BITS-1   :0] r_way_select;
reg [MSG_BITS-1:     0] r_snoop_msg;
reg [ADDRESS_WIDTH-1:0] r_snoop_address;
reg [DATA_WIDTH-1:   0] r_snoop_data [CACHE_WORDS-1:0];
reg [MSG_BITS-1:     0] r_bus_msg;
reg [ADDRESS_WIDTH-1:0] r_bus_address;
reg [DATA_WIDTH-1:   0] r_transfer_words;
reg [ADDRESS_WIDTH-1:0] address_counter;
reg [MAX_OFFSET_BITS:0] line_counter, word_counter;
reg [log2(MAX_OFFSET_BITS):0] r_curr_offset;


generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin: SPLIT_CACHE_DATA
    assign w_cache_data[i] = data_in[i*DATA_WIDTH +: DATA_WIDTH];
  end
endgenerate

assign dirty = status_bits[STATUS_BITS-2];

assign offset_diff = (r_curr_offset > CACHE_OFFSET_BITS) ? 
                     (r_curr_offset - CACHE_OFFSET_BITS) : 0;

assign ratio = 1 << offset_diff;
assign wider_transfer = r_curr_offset     >  CACHE_OFFSET_BITS;
assign wider_line     = CACHE_OFFSET_BITS >= r_curr_offset;

assign read_req   = ((bus_msg == R_REQ) | (bus_msg == RFO_BCAST)) & ~bus_master
                    & ~req_ready;
assign write_req  = (bus_msg == WS_BCAST) & ~bus_master & ~req_ready;
assign mflush_req = (bus_msg == REQ_FLUSH);
assign flush_req  = (bus_msg == FLUSH_S) & ~bus_master & ~req_ready;


//assign outputs
assign read = r_read;
assign write = r_write;
assign invalidate = r_invalidate;
assign index = r_index;
assign tag = r_tag;
assign meta_data = r_meta_data;
assign way_select = r_way_select;
assign snoop_msg = r_snoop_msg;
assign snoop_address = r_snoop_address;

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin: SN_DATA
    assign snoop_data[i*DATA_WIDTH +: DATA_WIDTH] = r_snoop_data[i];
    assign data_out[i*DATA_WIDTH +: DATA_WIDTH]   = r_data_out[i]  ;
  end
endgenerate





//coherence FSM
always @(posedge clock)begin
  if(reset)begin
    r_read       <= 1'b0;
    r_write      <= 1'b0;
    r_invalidate <= 1'b0;
    r_index      <= {INDEX_BITS{1'b0}};
    r_tag        <= {TAG_BITS{1'b0}};
    r_meta_data  <= {SBITS{1'b0}};
    r_way_select <= {WAY_BITS{1'b0}};
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_data_out[j] <= {DATA_WIDTH{1'b0}};
    end
    r_snoop_msg <= NO_REQ;
    r_snoop_address <= {ADDRESS_WIDTH{1'b0}};
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_snoop_data[j] <= {DATA_WIDTH{1'b0}};
    end
    r_bus_address   <= {ADDRESS_WIDTH{1'b0}};
    address_counter <= {ADDRESS_WIDTH{1'b0}};
    r_bus_msg       <= NO_REQ;
    line_counter    <= {(MAX_OFFSET_BITS+1){1'b0}};
    word_counter    <= {MAX_OFFSET_BITS{1'b0}};
    state           <= IDLE;
  end
  else begin
    case(state)
      IDLE:begin
        if(read_req | write_req | flush_req | mflush_req)begin
          r_bus_msg     <= bus_msg;
          r_bus_address <= bus_address;
          r_curr_offset <= curr_offset;
          state         <= START;
        end
        else
          state <= IDLE;
      end
      START:begin
        r_index         <= r_bus_address[CACHE_OFFSET_BITS +: INDEX_BITS];
        address_counter <= {r_bus_address[ADDRESS_WIDTH-1 : CACHE_OFFSET_BITS],
                           {CACHE_OFFSET_BITS{1'b0}}};
        r_tag           <= r_bus_address[ADDRESS_WIDTH-1 -: TAG_BITS];
        r_read          <= 1'b1;
        line_counter    <= 1;
        state           <= READ_LINE;
      end
      READ_LINE:begin
        state <= ACTION;
      end
      ACTION:begin
        for(j=0; j<CACHE_WORDS; j=j+1)begin
          r_snoop_data[j] <= w_cache_data[j];
        end
        r_way_select <= matched_way;
        case(r_bus_msg)
          R_REQ:begin
            if(hit)begin
              if(dirty)begin
                r_snoop_msg     <= C_WB;
                r_snoop_address <= address_counter;
                r_read          <= 1'b0;
                r_invalidate    <= 1'b1;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                r_read       <= 1'b0;
                r_write      <= 1'b1;
                r_meta_data  <= {2'b10, SHARED};
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data_out[j] <= w_cache_data[j];
                end
                state        <= WRITE_LINE;
              end
            end
            else begin
              if(line_counter == ratio)begin
                r_read          <= 1'b0;
                r_snoop_msg     <= EN_ACCESS;
                r_snoop_address <= r_bus_address;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                r_read          <= 1'b1;
                r_index         <= r_index + 1;
                address_counter <= address_counter + CACHE_WORDS;
                line_counter    <= line_counter + 1;
                state           <= READ_LINE;
              end
            end
          end
          RFO_BCAST:begin
            if(hit)begin
              if(line_counter == ratio)begin
                r_read          <= 1'b0;
                r_invalidate    <= 1'b1;
                r_snoop_msg     <= EN_ACCESS;
                r_snoop_address <= r_bus_address;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                r_read       <= 1'b0;
                r_invalidate <= 1'b1;
                state        <= INVALIDATE_LINE;
              end
            end
            else begin
              if(line_counter == ratio)begin
                r_read          <= 1'b0;
                r_snoop_msg     <= EN_ACCESS;
                r_snoop_address <= r_bus_address;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                r_read          <= 1'b1;
                r_index         <= r_index + 1;
                address_counter <= address_counter + CACHE_WORDS;
                line_counter    <= line_counter + 1;
                state           <= READ_LINE;
              end
            end
          end
          WS_BCAST:begin
            if(hit)begin
              if(line_counter == ratio)begin
                r_read          <= 1'b0;
                r_invalidate    <= 1'b1;
                r_snoop_msg     <= EN_ACCESS;
                r_snoop_address <= r_bus_address;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                r_read       <= 1'b0;
                r_invalidate <= 1'b1;
                state        <= INVALIDATE_LINE;
              end
            end
            else begin
              if(line_counter == ratio)begin
                r_read          <= 1'b0;
                r_snoop_msg     <= EN_ACCESS;
                r_snoop_address <= r_bus_address;
                state <= WAIT_FOR_RESP;
              end
              else begin
                r_read          <= 1'b1;
                r_index         <= r_index + 1;
                address_counter <= address_counter + CACHE_WORDS;
                line_counter    <= line_counter + 1;
                state           <= READ_LINE;
              end
            end
          end
          FLUSH_S:begin
            if(hit)begin
              if(dirty)begin
                r_snoop_msg     <= C_FLUSH;
                r_snoop_address <= address_counter;
                r_read          <= 1'b0;
                r_invalidate    <= 1'b1;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                if(line_counter == ratio)begin
                  r_read          <= 1'b0;
                  r_invalidate    <= 1'b1;
                  r_snoop_msg     <= EN_ACCESS;
                  r_snoop_address <= r_bus_address;
                  state           <= WAIT_FOR_RESP;  
                end
                else begin
                  r_read          <= 1'b0;
                  r_invalidate    <= 1'b1;
                  state           <= INVALIDATE_LINE;
                end
              end
            end
            else begin
              if(line_counter == ratio)begin
                r_read          <= 1'b0;
                r_snoop_msg     <= EN_ACCESS;
                r_snoop_address <= r_bus_address;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                r_read          <= 1'b1;
                r_index         <= r_index + 1;
                address_counter <= address_counter + CACHE_WORDS;
                line_counter    <= line_counter + 1;
                state           <= READ_LINE;
              end
            end
          end
          REQ_FLUSH:begin
            if(hit)begin
              if(dirty)begin
                r_snoop_msg     <= C_FLUSH;
                r_snoop_address <= address_counter;
                r_read          <= 1'b0;
                r_invalidate    <= 1'b1;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                if(line_counter == ratio)begin
                  r_read          <= 1'b0;
                  r_invalidate    <= 1'b1;
                  r_snoop_msg     <= EN_ACCESS;
                  r_snoop_address <= r_bus_address;
                  state <= WAIT_FOR_RESP;  
                end
                else begin
                  r_read          <= 1'b0;
                  r_invalidate    <= 1'b1;
                  state           <= INVALIDATE_LINE;
                end
              end
            end
            else begin
              if(line_counter == ratio)begin
                r_read          <= 1'b0;
                r_snoop_msg     <= EN_ACCESS;
                r_snoop_address <= r_bus_address;
                state           <= WAIT_FOR_RESP;
              end
              else begin
                r_read          <= 1'b1;
                r_index         <= r_index + 1;
                address_counter <= address_counter + CACHE_WORDS;
                line_counter    <= line_counter + 1;
                state           <= READ_LINE;
              end
            end
          end
          default:begin
            state <= IDLE;
          end
        endcase
      end
      WAIT_FOR_RESP:begin
        r_invalidate <= 1'b0;
        if(intf_msg == REQ_FLUSH)begin
          r_snoop_msg       <= NO_REQ;
          r_snoop_address   <= {ADDRESS_WIDTH{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_snoop_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state <= IDLE;
        end
        else begin
          if(line_counter == ratio)begin
            if(intf_msg == MEM_RESP)begin
              r_snoop_msg     <= EN_ACCESS;
              r_snoop_address <= r_bus_address;
              for(j=0; j<CACHE_WORDS; j=j+1)begin
                r_snoop_data[j] <= {DATA_WIDTH{1'b0}};
              end
              state <= WAIT_FOR_RESP;
            end
            else if(req_ready)begin
              r_snoop_msg     <= NO_REQ;
              r_snoop_address <= {ADDRESS_WIDTH{1'b0}};
              for(j=0; j<CACHE_WORDS; j=j+1)begin
                r_snoop_data[j] <= {DATA_WIDTH{1'b0}};
              end
              state <= IDLE;
            end
            else
              state <= WAIT_FOR_RESP;
          end
          else begin
            if(intf_msg == MEM_RESP)begin
                r_read          <= 1'b1;
                r_index         <= r_index + 1;
                address_counter <= address_counter + CACHE_WORDS;
                line_counter    <= line_counter + 1;
                r_snoop_msg     <= HOLD_BUS;
                r_snoop_address <= {ADDRESS_WIDTH{1'b0}};
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_snoop_data[j] <= {DATA_WIDTH{1'b0}};
                end
                state <= READ_LINE;
            end
          end
        end
      end
      INVALIDATE_LINE:begin
        r_invalidate    <= 1'b0;
        r_read          <= 1'b1;
        r_index         <= r_index + 1;
        address_counter <= address_counter + CACHE_WORDS;
        line_counter    <= line_counter + 1;
        state           <= READ_LINE;
      end
      WRITE_LINE:begin
        r_write <= 1'b0;
        if(line_counter == ratio)begin
          r_snoop_msg     <= EN_ACCESS;
          r_snoop_address <= r_bus_address;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_snoop_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state <= WAIT_FOR_RESP;
        end
        else begin
          r_read          <= 1'b1;
          r_index         <= r_index + 1;
          address_counter <= address_counter+ CACHE_WORDS;
          line_counter    <= line_counter + 1;
          state           <= READ_LINE;
        end
      end
      default:begin
        r_read       <= 1'b0;
        r_write      <= 1'b0;
        r_invalidate <= 1'b0;
        r_index      <= {INDEX_BITS{1'b0}};
        r_tag        <= {TAG_BITS{1'b0}};
        r_meta_data  <= {SBITS{1'b0}};
        r_way_select <= {WAY_BITS{1'b0}};
        for(j=0; j<CACHE_WORDS; j=j+1)begin
          r_data_out[j] <= {DATA_WIDTH{1'b0}};
        end
        r_snoop_msg <= NO_REQ;
        r_snoop_address <= {ADDRESS_WIDTH{1'b0}};
        for(j=0; j<BUS_WORDS; j=j+1)begin
          r_snoop_data[j] <= {DATA_WIDTH{1'b0}};
        end
        r_bus_address <= {ADDRESS_WIDTH{1'b0}};
        r_bus_msg     <= NO_REQ;
        state <= IDLE;
      end
    endcase
  end
end

endmodule
