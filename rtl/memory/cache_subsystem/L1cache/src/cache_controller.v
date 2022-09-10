/** @module : cache_controller
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

module cache_controller #(
parameter STATUS_BITS           =  2,
          COHERENCE_BITS        =  2,
          OFFSET_BITS           =  0,
          DATA_WIDTH            = 32,
          NUMBER_OF_WAYS        =  4,
          ADDRESS_BITS          = 32,
          INDEX_BITS            =  8,
          MSG_BITS              =  4,
          CORE                  =  0,
          CACHE_NO              =  0
)(
clock, reset,
read, write, invalidate, flush,
w_byte_en,
address,
data_in,
report,
data_out,
out_address,
ready,
valid,

data_in0,
tag_in0,
matched_way0,
coh_bits0,
status_bits0,
hit0,
read0,
write0,
invalidate0,
index0,
tag0,
meta_data0,
data_out0,
way_select0,
read1,
write1,
invalidate1,
index1,
tag1,
meta_data1,
data_out1,
way_select1,
i_reset,

mem2cache_msg,
mem2cache_data,
mem2cache_address,
cache2mem_msg,
cache2mem_data,
cache2mem_address,

snoop_address,
snoop_read,
snoop_modify
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

// Local parameters
localparam CACHE_WORDS = 1 << OFFSET_BITS; //number of words in one line.
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam SBITS       = COHERENCE_BITS + STATUS_BITS;
localparam TAG_BITS    = ADDRESS_BITS - OFFSET_BITS - INDEX_BITS;
localparam WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
localparam CACHE_DEPTH = 1 << INDEX_BITS;


localparam IDLE            = 4'd0,
           RESET           = 4'd1,
           WAIT_FOR_ACCESS = 4'd2,
           CACHE_ACCESS    = 4'd3,
           READ_STATE      = 4'd4,
           WRITE_BACK      = 4'd5,
           WAIT            = 4'd6,
           UPDATE          = 4'd7,
           WB_WAIT         = 4'd8,
           SRV_FLUSH_REQ   = 4'd9,
           WAIT_FLUSH_REQ  = 4'd10,
           SRV_INVLD_REQ   = 4'd11,
           WAIT_INVLD_REQ  = 4'd12,
           WAIT_WS_ENABLE  = 4'd13,
           REACCESS        = 4'd14;

// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
// For Altera Quartus, add the following line to the .qsf file.
// set_global_assignment -name VERILOG_MACRO "INCLUDE_FILE=\"../../../includes/params.h\""
`include `INCLUDE_FILE

input clock, reset;
input read, write, invalidate, flush;
input  [DATA_WIDTH/8-1:0] w_byte_en;
input  [ADDRESS_BITS-1:0] address;
input  [DATA_WIDTH-1:  0] data_in;
input  report;
output [DATA_WIDTH-1:  0] data_out;
output [ADDRESS_BITS-1:0] out_address;
output ready;
output valid;

//interface with cache memory
input  [CACHE_WIDTH-1   :0] data_in0;
input  [TAG_BITS-1      :0] tag_in0;
input  [WAY_BITS-1      :0] matched_way0;
input  [COHERENCE_BITS-1:0] coh_bits0;
input  [STATUS_BITS-1   :0] status_bits0;
input  hit0;
output read0, write0, invalidate0;
output [INDEX_BITS-1    :0] index0;
output [TAG_BITS-1      :0] tag0;
output [SBITS-1         :0] meta_data0;
output [CACHE_WIDTH-1   :0] data_out0;
output [WAY_BITS-1      :0] way_select0;

output read1, write1, invalidate1;
output [INDEX_BITS-1    :0] index1;
output [TAG_BITS-1      :0] tag1;
output [SBITS-1         :0] meta_data1;
output [CACHE_WIDTH-1   :0] data_out1;
output [WAY_BITS-1      :0] way_select1;
output i_reset;

//interface with bus interface
input  [MSG_BITS-1:    0] mem2cache_msg;
input  [CACHE_WIDTH-1: 0] mem2cache_data;
input  [ADDRESS_BITS-1:0] mem2cache_address;
output [MSG_BITS-1:    0] cache2mem_msg;
output [CACHE_WIDTH-1: 0] cache2mem_data;
output [ADDRESS_BITS-1:0] cache2mem_address;

//inputs from snooper
input  [ADDRESS_BITS-1:0] snoop_address;
input  snoop_read;    //snooper is reading data
input  snoop_modify; //snooper is modifying data


genvar i, byte;
integer j, k;

reg [3:0] state;
reg [INDEX_BITS-1:0]   reset_counter;
reg [ADDRESS_BITS-1:0] REQ1_address, REQ2_address;
reg [DATA_WIDTH-1:0]   REQ1_data   , REQ2_data;
reg REQ1_read, REQ1_write, REQ1_flush, REQ1_invalidate, REQ2_read, REQ2_write,
    REQ2_flush, REQ2_invalidate;
reg [DATA_WIDTH/8-1:0] REQ1_w_byte_en, REQ2_w_byte_en;
reg [DATA_WIDTH-1:0] r_line_out [CACHE_WORDS-1:0];
reg [WAY_BITS-1:0] r_matched_way;
reg r_dirty_bit;
reg [MSG_BITS-1:0] r_cache2mem_msg;
reg [DATA_WIDTH-1:0] r_cache2mem_data [CACHE_WORDS-1:0];
reg [ADDRESS_BITS-1:0] r_cache2mem_address;
reg [DATA_WIDTH-1 : 0] r_words_from_mem [CACHE_WORDS-1:0];
reg [MSG_BITS-1:0] r_transaction;
reg [TAG_BITS-1:0] r_tag_out;
reg [COHERENCE_BITS-1:0] r_coh_bits_from_mem;
reg reaccess_delay;

wire request, REQ2;
wire [(ADDRESS_BITS-OFFSET_BITS)-1:0] addr_line, sn_addr_line, wb_addr_line;
wire [(ADDRESS_BITS-OFFSET_BITS)-1:0] REQ1_line, REQ2_line;
wire [INDEX_BITS-1:0] REQ1_index, REQ2_index, address_index, snoop_index;
wire [TAG_BITS-1:0] REQ1_tag, REQ2_tag, address_tag;
wire [OFFSET_BITS-1:0] REQ1_offset;
wire [DATA_WIDTH-1:0] line_out_words [CACHE_WORDS-1:0];
wire stall;
wire [OFFSET_BITS-1:0] zero_offset;
wire dirty0;

//REQ1 and REQ2 addresses shifted to remove the byte offset
wire [ADDRESS_BITS-1:0] REQ1_word_addr, REQ2_word_addr;
wire [ADDRESS_BITS-1:0] address_shifted;

//assignments
assign REQ1_word_addr  = REQ1_address >> 2;
assign REQ2_word_addr  = REQ2_address >> 2;
assign address_shifted = address >> 2;

assign dirty0  = status_bits0[STATUS_BITS-2];
assign request = read      | write      | flush      | invalidate     ;
assign REQ2    = REQ2_read | REQ2_write | REQ2_flush | REQ2_invalidate;

assign addr_line     = address_shifted[ADDRESS_BITS-1 : OFFSET_BITS];
assign sn_addr_line  = snoop_address[ADDRESS_BITS-1 : OFFSET_BITS];
assign wb_addr_line  = {r_tag_out, REQ1_index};
assign REQ1_line     = REQ1_word_addr[ADDRESS_BITS-1 : OFFSET_BITS];
assign REQ2_line     = REQ2_word_addr[ADDRESS_BITS-1 : OFFSET_BITS];
assign address_index = address_shifted[OFFSET_BITS +: INDEX_BITS];
assign REQ1_index    = REQ1_word_addr[OFFSET_BITS +: INDEX_BITS];
assign REQ2_index    = REQ2_word_addr[OFFSET_BITS +: INDEX_BITS];
assign snoop_index   = snoop_address[OFFSET_BITS +: INDEX_BITS];
assign REQ1_tag      = REQ1_word_addr[ADDRESS_BITS-1 -: TAG_BITS];
assign REQ2_tag      = REQ2_word_addr[ADDRESS_BITS-1 -: TAG_BITS];
assign address_tag   = address_shifted[ADDRESS_BITS-1 -: TAG_BITS];
assign REQ1_offset   = REQ1_word_addr[0 +: OFFSET_BITS];
assign zero_offset   = 0;

assign stall = ((REQ1_index == REQ2_index     ) & REQ2 & REQ1_write)    |
               ((REQ1_index == address_index  ) & REQ1_write & request & ready);

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin: LINEWORDS
    assign line_out_words[i] = data_in0[i*DATA_WIDTH +: DATA_WIDTH];
  end
endgenerate


//Cache controller
always @(posedge clock)begin
  if(reset & (state != RESET))begin
    reset_counter       <= {INDEX_BITS{1'b0}};
    REQ1_address        <= {ADDRESS_BITS{1'b0}};
    REQ1_data           <= {DATA_WIDTH{1'b0}};
    REQ1_read           <= 1'b0;
    REQ1_write          <= 1'b0;
    REQ1_flush          <= 1'b0;
    REQ1_invalidate     <= 1'b0;
    REQ1_w_byte_en      <= {DATA_WIDTH/8{1'b0}};
    REQ2_address        <= {ADDRESS_BITS{1'b0}};
    REQ2_data           <= {DATA_WIDTH{1'b0}};
    REQ2_read           <= 1'b0;
    REQ2_write          <= 1'b0;
    REQ2_flush          <= 1'b0;
    REQ2_invalidate     <= 1'b0;
    REQ2_w_byte_en      <= {DATA_WIDTH/8{1'b0}};
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_line_out[j]     <= {DATA_WIDTH{1'b0}};
    end
    r_matched_way       <= {WAY_BITS{1'b0}};
    r_dirty_bit         <= 1'b0;
    r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
      r_words_from_mem[j] <= {DATA_WIDTH{1'b0}};
    end
    r_cache2mem_msg     <= NO_REQ;
    r_coh_bits_from_mem <= 2'b00;
    reaccess_delay      <= 1'b0;
    state               <= RESET;
  end
  else begin
    case(state)
      RESET:begin
        if(reset_counter < CACHE_DEPTH-1)begin
          reset_counter <= reset_counter + 1;
        end
        else if((reset_counter == CACHE_DEPTH-1) & ~reset)begin
          reset_counter <= {INDEX_BITS{1'b0}};
          state         <= IDLE;
        end
      end
      IDLE:begin
        if(request & snoop_modify & (address_index == snoop_index))begin
          REQ2_read       <= read;
          REQ2_write      <= write;
          REQ2_flush      <= flush;
          REQ2_invalidate <= invalidate;
          REQ2_address    <= address;
          REQ2_data       <= data_in;
          REQ2_w_byte_en  <= w_byte_en;
          state           <= WAIT_FOR_ACCESS;
        end
        else begin
          REQ1_address    <= address;
          REQ1_data       <= data_in;
          REQ1_read       <= read;
          REQ1_write      <= write;
          REQ1_flush      <= flush;
          REQ1_invalidate <= invalidate;
          REQ1_w_byte_en  <= w_byte_en;
          state           <= request ? CACHE_ACCESS : IDLE;
        end
      end
      CACHE_ACCESS:begin
        for(j=0; j<CACHE_WORDS; j=j+1)begin
          r_line_out[j] <= data_in0[j*DATA_WIDTH +: DATA_WIDTH];
        end
        r_matched_way <= matched_way0;
        r_tag_out     <= tag_in0;
        r_dirty_bit   <= dirty0;
        if((snoop_modify|snoop_read) & REQ1_write)begin
          REQ2_address    <= REQ2 ? REQ2_address    : address;
          REQ2_data       <= REQ2 ? REQ2_data       : data_in;
          REQ2_read       <= REQ2 ? REQ2_read       : read;
          REQ2_write      <= REQ2 ? REQ2_write      : write;
          REQ2_flush      <= REQ2 ? REQ2_flush      : flush;
          REQ2_invalidate <= REQ2 ? REQ2_invalidate : invalidate;
          REQ2_w_byte_en  <= REQ2 ? REQ2_w_byte_en  : w_byte_en;
          reaccess_delay  <= snoop_read ? 1'b1 : 1'b0;
          state           <= REACCESS;
        end

        else if(hit0)begin
          if(REQ1_write & (coh_bits0 == SHARED))begin
            REQ2_address        <= REQ2 ? REQ2_address    : address;
            REQ2_data           <= REQ2 ? REQ2_data       : data_in;
            REQ2_read           <= REQ2 ? REQ2_read       : read;
            REQ2_write          <= REQ2 ? REQ2_write      : write;
            REQ2_flush          <= REQ2 ? REQ2_flush      : flush;
            REQ2_invalidate     <= REQ2 ? REQ2_invalidate : invalidate;
            REQ2_w_byte_en      <= REQ2 ? REQ2_w_byte_en  : w_byte_en;
            r_cache2mem_address <= (REQ1_word_addr >> OFFSET_BITS)
                                   << OFFSET_BITS;
            r_cache2mem_msg     <= WS_BCAST;
            state               <= WAIT_WS_ENABLE;
          end
          else if(stall)begin
            REQ1_data       <= {DATA_WIDTH{1'b0}};
            REQ1_address    <= {ADDRESS_BITS{1'b0}};
            REQ1_read       <= 1'b0;
            REQ1_write      <= 1'b0;
            REQ1_flush      <= 1'b0;
            REQ1_invalidate <= 1'b0;
            REQ1_w_byte_en  <= {DATA_WIDTH/8{1'b0}};
            REQ2_address    <= REQ2 ? REQ2_address    : address;
            REQ2_data       <= REQ2 ? REQ2_data       : data_in;
            REQ2_read       <= REQ2 ? REQ2_read       : read;
            REQ2_write      <= REQ2 ? REQ2_write      : write;
            REQ2_flush      <= REQ2 ? REQ2_flush      : flush;
            REQ2_invalidate <= REQ2 ? REQ2_invalidate : invalidate;
            REQ2_w_byte_en  <= REQ2 ? REQ2_w_byte_en  : w_byte_en;
            state           <= WAIT_FOR_ACCESS;
          end

          else if(request & snoop_modify & (address_index == snoop_index))begin
            REQ2_read       <= REQ2 ? REQ2_read       : read;
            REQ2_write      <= REQ2 ? REQ2_write      : write;
            REQ2_invalidate <= REQ2 ? REQ2_invalidate : invalidate;
            REQ2_flush      <= REQ2 ? REQ2_flush      : flush;
            REQ2_address    <= REQ2 ? REQ2_address    : address;
            REQ2_data       <= REQ2 ? REQ2_data       : data_in;
            REQ2_w_byte_en  <= REQ2 ? REQ2_w_byte_en  : w_byte_en;
            if(REQ1_flush)begin
              state <= SRV_FLUSH_REQ;
            end
            else if(REQ1_invalidate)begin
              state <= SRV_INVLD_REQ;
            end
            else begin
              state <= WAIT_FOR_ACCESS;
            end
          end

          else begin
            REQ1_read       <= REQ2 ? 1'b0                 : read;
            REQ1_write      <= REQ2 ? 1'b0                 : write;
            REQ1_flush      <= REQ2 ? 1'b0                 : flush;
            REQ1_invalidate <= REQ2 ? 1'b0                 : invalidate;
            REQ1_address    <= REQ2 ? {ADDRESS_BITS{1'b0}} : address;
            REQ1_data       <= REQ2 ? {DATA_WIDTH{1'b0}}   : data_in;
            REQ1_w_byte_en  <= REQ2 ? {DATA_WIDTH/8{1'b0}} : w_byte_en;
            if(REQ1_flush)begin
              state <= SRV_FLUSH_REQ;
            end
            else if(REQ1_invalidate)begin
              state <= SRV_INVLD_REQ;
            end
            else begin
              state <= REQ2 ? WAIT_FOR_ACCESS : (request & ready) ? CACHE_ACCESS : IDLE;
            end
          end
        end
        else begin //miss
          REQ2_read       <= REQ2 ? REQ2_read       : read;
          REQ2_write      <= REQ2 ? REQ2_write      : write;
          REQ2_flush      <= REQ2 ? REQ2_flush      : flush;
          REQ2_invalidate <= REQ2 ? REQ2_invalidate : invalidate;
          REQ2_address    <= REQ2 ? REQ2_address    : address;
          REQ2_data       <= REQ2 ? REQ2_data       : data_in;
          REQ2_w_byte_en  <= REQ2 ? REQ2_w_byte_en  : w_byte_en;
          if(REQ1_flush)begin
            state <= SRV_FLUSH_REQ;
          end
          else if(REQ1_invalidate)begin
            state <= SRV_INVLD_REQ;
          end
          else begin
            state <= dirty0 ? WRITE_BACK : READ_STATE;
          end
        end
      end
      READ_STATE:begin
        if(snoop_modify & (sn_addr_line == REQ1_line))begin
          state <= REACCESS;
        end
        else begin
          r_cache2mem_msg     <= REQ1_write ? RFO_BCAST : R_REQ;
          r_cache2mem_address <= (REQ1_word_addr >> OFFSET_BITS) << OFFSET_BITS;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= WAIT;
        end
      end
      WAIT:begin
        if(snoop_modify & (sn_addr_line == REQ1_line))begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= REACCESS;
        end
        else if((mem2cache_msg == MEM_RESP) | mem2cache_msg == MEM_RESP_S)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= UPDATE;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_words_from_mem[j] <= mem2cache_data[j*DATA_WIDTH +: DATA_WIDTH];
          end
            r_coh_bits_from_mem <= (mem2cache_msg == MEM_RESP) ? 2'b01 : 2'b11;
        end
        else begin
          state <= WAIT;
        end
      end
      UPDATE:begin
        if(snoop_modify & (sn_addr_line == REQ1_line))
          state <= REACCESS;
        else
          state <= WAIT_FOR_ACCESS;
      end
      WAIT_FOR_ACCESS:begin
        if(stall)begin
          REQ1_data       <= {DATA_WIDTH{1'b0}};
          REQ1_read       <= 1'b0;
          REQ1_write      <= 1'b0;
          REQ1_flush      <= 1'b0;
          REQ1_invalidate <= 1'b0;
          REQ1_w_byte_en  <= {DATA_WIDTH/8{1'b0}};
          state           <= WAIT_FOR_ACCESS;
        end
        else if(snoop_modify & REQ2 & (snoop_index == REQ2_index))begin
          state <= WAIT_FOR_ACCESS;
        end
        else begin
          REQ1_address    <= REQ2_address;
          REQ1_data       <= REQ2_data;
          REQ1_read       <= REQ2_read;
          REQ1_write      <= REQ2_write;
          REQ1_flush      <= REQ2_flush;
          REQ1_invalidate <= REQ2_invalidate;
          REQ1_w_byte_en  <= REQ2_w_byte_en;
          REQ2_address    <= 0;
          REQ2_data       <= 0;
          REQ2_read       <= 0;
          REQ2_write      <= 0;
          REQ2_flush      <= 0;
          REQ2_invalidate <= 0;
          REQ2_w_byte_en  <= {DATA_WIDTH/8{1'b0}};
          state           <= REQ2 ? CACHE_ACCESS : IDLE;
        end
      end
      WRITE_BACK:begin
        if(snoop_modify & (sn_addr_line == wb_addr_line))begin
          state <= REACCESS;
        end
        else begin
          r_cache2mem_msg     <= WB_REQ;
          r_cache2mem_address <= {r_tag_out, REQ1_index, zero_offset};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= r_line_out[j];
          end
          state               <= WB_WAIT;
        end
      end
      WB_WAIT:begin
        if(snoop_modify & (snoop_index == REQ1_index))begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= REACCESS;
        end
        else if(mem2cache_msg == MEM_RESP)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= READ_STATE;
        end
        else
          state <= WB_WAIT;
      end
      SRV_FLUSH_REQ:begin
        if(snoop_modify & (sn_addr_line == REQ1_line))begin
          state <= REACCESS;
        end
        else begin
          r_cache2mem_msg     <= r_dirty_bit ? FLUSH : FLUSH_S;
          r_cache2mem_address <= (REQ1_word_addr >> OFFSET_BITS) << OFFSET_BITS;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= r_line_out[j];
          end
          state               <= WAIT_FLUSH_REQ;
        end
      end
      WAIT_FLUSH_REQ:begin
        if(snoop_modify & (sn_addr_line == REQ1_line))begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= REACCESS;
        end
        else if(mem2cache_msg == MEM_RESP)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= REQ2 ? WAIT_FOR_ACCESS : IDLE;
        end
        else begin
          state <= WAIT_FLUSH_REQ;
        end
      end
      SRV_INVLD_REQ:begin
        if(snoop_modify & (sn_addr_line == REQ1_line))begin
          state <= REACCESS;
        end
        else begin
          r_cache2mem_msg     <= r_dirty_bit ? FLUSH : FLUSH_S;
          r_cache2mem_address <= (REQ1_word_addr >> OFFSET_BITS) << OFFSET_BITS;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= r_line_out[j];
          end
          state               <= WAIT_INVLD_REQ;
        end
      end
      WAIT_INVLD_REQ:begin
        if(snoop_modify & (sn_addr_line == REQ1_line))begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= REACCESS;
        end
        else if(mem2cache_msg == MEM_RESP)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= REQ2 ? WAIT_FOR_ACCESS : IDLE;
        end
        else begin
          state <= WAIT_INVLD_REQ;
        end
      end
      WAIT_WS_ENABLE:begin
        if(snoop_modify & (sn_addr_line == REQ1_line))begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= REACCESS;
        end
        else if(mem2cache_msg == EN_ACCESS)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache2mem_data[j] <= {DATA_WIDTH{1'b0}};
          end
          state               <= WAIT_FOR_ACCESS;
        end
        else begin
          state <= WAIT_WS_ENABLE;
        end
      end
      REACCESS:begin
        if(reaccess_delay)begin
          reaccess_delay <= 1'b0;
          state          <= REACCESS;
        end
        else if(snoop_modify & (sn_addr_line == REQ1_line))
          state <= REACCESS;
        else
          state <= CACHE_ACCESS;
      end
      default:begin
        state <= IDLE;
      end
    endcase
  end
end




// drive outputs
assign read0 = (((state == IDLE) | (state == CACHE_ACCESS)) & request) |
               (state == WAIT_FOR_ACCESS) | (state == REACCESS);

assign write0 = (state == RESET) | (state == UPDATE) |
                ((state == WAIT_WS_ENABLE) & (mem2cache_msg == EN_ACCESS));

assign invalidate0 = (mem2cache_msg == MEM_RESP) & ((state == WB_WAIT) |
                     (state == WAIT_FLUSH_REQ) | (state == WAIT_INVLD_REQ));


assign tag0 = (state == WAIT_FOR_ACCESS) ? REQ2_tag :
              (((state == IDLE) | (state == CACHE_ACCESS)) & request) ?
              address_tag : REQ1_tag;

assign index0 = (state == RESET) ? reset_counter        :
                (state == WAIT_FOR_ACCESS) ? REQ2_index :
                (((state == IDLE) | (state == CACHE_ACCESS)) & request) ?
                address_index : REQ1_index;


assign meta_data0 = REQ1_write ? 4'b1110 : {2'b10, r_coh_bits_from_mem};

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin: DATAOUT0
    for(byte=0; byte<(DATA_WIDTH/8); byte=byte+1) begin: BYTE_LOOP
      assign data_out0[(i*DATA_WIDTH)+(byte*8) +: 8] =
        REQ1_write & REQ1_w_byte_en[byte] & (i == REQ1_offset) ? REQ1_data[byte*8 +: 8] :
        (state == WAIT_WS_ENABLE) ? r_line_out[i][byte*8 +: 8] : r_words_from_mem[i][byte*8 +: 8];
    end
  end
endgenerate


assign way_select0 = r_matched_way;
assign read1 = 1'b0;
assign write1 = (state == CACHE_ACCESS) & REQ1_write & hit0 &
                (coh_bits0 != SHARED);
assign invalidate1 = 1'b0;
assign index1 = REQ1_index;
assign tag1   = REQ1_tag;
assign meta_data1 = {2'b11, MODIFIED};

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin:DATA_OUT1
    assign data_out1[i*DATA_WIDTH +: DATA_WIDTH] = (i == REQ1_offset) ?
      REQ1_data : data_in0[i*DATA_WIDTH +: DATA_WIDTH];
  end
endgenerate

assign way_select1 = matched_way0;
assign i_reset = reset | (state == RESET);

assign cache2mem_address = r_cache2mem_address;
generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin: DATA2MEM
    assign cache2mem_data[i*DATA_WIDTH +: DATA_WIDTH] = r_cache2mem_data[i];
  end
endgenerate
assign cache2mem_msg     = r_cache2mem_msg;
assign out_address       = REQ1_address;

generate
  if(OFFSET_BITS>0)begin
    assign data_out = (state == CACHE_ACCESS) & hit0 & REQ1_read ?
                      line_out_words[REQ1_offset]
                    : (state == UPDATE) & REQ1_read ?
                      r_words_from_mem[REQ1_offset]
                    : {DATA_WIDTH{1'b0}};
  end
  else begin
    assign data_out = (state == CACHE_ACCESS) & hit0 &
                      REQ1_read ? line_out_words[0]
                    : (state == UPDATE) & REQ1_read ?
                      r_words_from_mem[0]
                    : {DATA_WIDTH{1'b0}};
  end
endgenerate

assign valid = (((state==CACHE_ACCESS) & hit0) | (state == UPDATE)) & REQ1_read;

assign ready = ((state == IDLE) & ~flush & ~invalidate & ~(snoop_modify &
               (address_index == snoop_index))) | ((state == CACHE_ACCESS) &
               ~REQ1_flush & ~REQ1_invalidate & ~REQ2 & ~((snoop_modify |
               snoop_read | (coh_bits0 == SHARED) | (REQ1_index == address_index))
               & REQ1_write) & ~((address_index == snoop_index) & snoop_modify)
               & hit0);

endmodule
