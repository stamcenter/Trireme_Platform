/** @module : tb_Lxcache_controller
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
module tb_Lxcache_controller();

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value >> 1;
  end
endfunction

parameter STATUS_BITS      = 3, // Valid bit + Dirty bit + inclusion bit
          INCLUSION        = 1,
          COHERENCE_BITS   = 2,
          OFFSET_BITS      = 2,
          DATA_WIDTH       = 8,
          NUMBER_OF_WAYS   = 4,
          ADDRESS_BITS     = 32,
          INDEX_BITS       = 6,
          MSG_BITS         = 4,
          LAST_LEVEL       = 0,
          MEM_SIDE         = "DIR",
		  REISSUE_COUNT    = 100;

localparam CACHE_WORDS = 1 << OFFSET_BITS; //number of words in one line.
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam MBITS       = COHERENCE_BITS + STATUS_BITS;
localparam TAG_BITS    = ADDRESS_BITS - OFFSET_BITS - INDEX_BITS;
localparam WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
localparam CACHE_DEPTH = 1 << INDEX_BITS;

localparam IDLE           = 4'd0,
           SEND_INDEX     = 4'd1, //initiate read from cache memory
           READING        = 4'd2,
           SERVING        = 4'd3,
           SEND_TO_MEM    = 4'd4,
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

reg clock;
reg reset;
//signals to/from bus interface
reg  [ADDRESS_BITS-1:0] address;
reg  [CACHE_WIDTH-1 :0] data_in;
reg  [MSG_BITS-1    :0] msg_in;
reg  pending_requests;
reg  report;
wire [CACHE_WIDTH-1 :0] data_out;
wire [ADDRESS_BITS-1:0] out_address;
wire [MSG_BITS-1    :0] msg_out;
//signals to/from next level cache/memory
reg  [MSG_BITS-1    :0] mem2cache_msg;
reg  [ADDRESS_BITS-1:0] mem2cache_address;
reg  [CACHE_WIDTH-1 :0] mem2cache_data;
reg  [ADDRESS_BITS-1:0] mem_intf_address;
reg  mem_intf_address_valid;
reg  mem_intf_busy; 
wire [MSG_BITS-1    :0] cache2mem_msg;
wire [ADDRESS_BITS-1:0] cache2mem_address;
wire [CACHE_WIDTH-1 :0] cache2mem_data;
//signals to/from cache_memory
wire i_reset;
wire read0, write0, invalidate0;
wire [INDEX_BITS-1  :0] index0;
wire [TAG_BITS-1    :0] tag0;
wire [MBITS-1       :0] meta_data0;
wire [CACHE_WIDTH-1 :0] data0;
wire [WAY_BITS-1    :0] way_select0;
reg  [CACHE_WIDTH-1 :0] data_in0;
reg  [TAG_BITS-1    :0] tag_in0;
reg  [WAY_BITS-1    :0] matched_way0;
reg  [COHERENCE_BITS-1:0] coh_bits0;
reg  [STATUS_BITS-1 :0] status_bits0;
reg  hit0;


//instantiate DUT
Lxcache_controller #(
  .STATUS_BITS(STATUS_BITS),
  .INCLUSION(INCLUSION),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .MSG_BITS(MSG_BITS),
  .LAST_LEVEL(LAST_LEVEL),
  .MEM_SIDE(MEM_SIDE),
  .REISSUE_COUNT(REISSUE_COUNT)
) DUT (
  .clock(clock),
  .reset(reset),
  .address(address),
  .data_in(data_in),
  .msg_in(msg_in),
  .pending_requests(pending_requests),
  .scan(report),
  .data_out(data_out),
  .out_address(out_address),
  .msg_out(msg_out),

  .mem2cache_msg(mem2cache_msg),
  .mem2cache_address(mem2cache_address),
  .mem2cache_data(mem2cache_data),
  .mem_intf_busy(mem_intf_busy),
  .mem_intf_address(mem_intf_address),
  .mem_intf_address_valid(mem_intf_address_valid),
  .cache2mem_msg(cache2mem_msg),
  .cache2mem_address(cache2mem_address),
  .cache2mem_data(cache2mem_data),

  .read0(read0), 
  .write0(write0), 
  .invalidate0(invalidate0),
  .index0(index0),
  .tag0(tag0),
  .meta_data0(meta_data0),
  .data0(data0),
  .way_select0(way_select0),
  .i_reset(i_reset),
  .data_in0(data_in0),
  .tag_in0(tag_in0),
  .matched_way0(matched_way0),
  .coh_bits0(coh_bits0),
  .status_bits0(status_bits0),
  .hit0(hit0)
);

//generate clock
always #1 clock = ~clock;

//cycle counter
reg [31:0] cycles;
always @(posedge clock)begin
  cycles <= cycles + 1;
end

// Test patterns
initial begin
  clock                  = 0;
  reset                  = 0;
  cycles                 = 0;
  address                = 0;
  data_in                = 0;
  msg_in                 = 0;
  pending_requests       = 0;
  report                 = 0;
  mem2cache_msg          = 0;
  mem2cache_address      = 0;
  mem2cache_data         = 0;
  data_in0               = 0;
  tag_in0                = 0;
  matched_way0           = 0;
  coh_bits0              = 0;
  status_bits0           = 0;
  hit0                   = 0;
  mem_intf_busy          = 0;
  mem_intf_address       = 0;
  mem_intf_address_valid = 0;

  repeat(1) @(posedge clock);
  @(posedge clock) begin
    reset <= 1;
    $display("%0d> Assert reset.", cycles);
  end
  repeat(1) @(posedge clock);
  @(posedge clock) begin
    reset <= 0;
    $display("%0d> Deassert reset.", cycles);
  end
  wait(DUT.state == IDLE);
  $display("%0d> DUT in IDLE state", cycles-1);

  //read request
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    msg_in <= R_REQ;
    address <= 32'h11111144;
  end
  @(address) $display("%0d> Read request. address:%h", cycles-1, address);
  wait(read0 & index0 == 6'h11 & tag0 == 24'h111111);
  $display("%0d> Read request sent to cache memory. index0:%h", cycles-1, 
    index0);
  @(posedge clock)begin
    data_in0 <= 32'h11_22_33_44;
    tag_in0  <= 24'h111111;
    matched_way0 <= 3;
    coh_bits0 <= 2'b11;
    status_bits0 <= 3'b101;
  	hit0 <= 1;
  end
  @(data_in0) $display("%0d> cache memory responds. data:%h | matched way:%d | coh_bits:%b | status bits:%b", cycles-1, data_in0, matched_way0, coh_bits0,
  status_bits0);
  @(posedge clock)begin
    data_in0 <= 0;
    tag_in0  <= 0;
    matched_way0 <= 0;
    coh_bits0 <= 0;
    status_bits0 <= 0;
  	hit0 <= 0;
  end
  wait(msg_out == MEM_RESP_S);
  $display("%0d> Controller responds to the read request. ", cycles-1);
  @(posedge clock)begin
    msg_in <= NO_REQ;
    address <= 0;
  end
  
  //write request
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    msg_in <= WB_REQ;
    address <= 32'h11111148;
	  data_in <= 32'h99_88_77_66;
  end
  @(address) $display("%0d> Write back request. address:%h | data:%h", cycles-1,
    address, data_in);
  wait(read0 & index0 == 6'h12);
  $display("%0d> Read request sent to cache memory. index0:%h", cycles-1, 
    index0);
  @(posedge clock)begin
    data_in0 <= 32'h00_11_22_00;
    tag_in0  <= 24'h111111;
    matched_way0 <= 1;
    coh_bits0 <= 2'b01;
    status_bits0 <= 3'b101;
  	hit0 <= 1;
  end
  @(data_in0) $display("%0d> cache memory responds. data:%h | matched way:%d | coh_bits:%b | status bits:%b", cycles-1, data_in0, matched_way0, coh_bits0,
  status_bits0);
  @(posedge clock)begin
    data_in0 <= 0;
    tag_in0  <= 0;
    matched_way0 <= 0;
    coh_bits0 <= 0;
    status_bits0 <= 0;
  	hit0 <= 0;
  end 
  wait(write0 & index0==6'h12 & tag0 == 24'h111111 & meta_data0 == 5'b11010);
  $display("%0d> Write request sent to cache memory. Data=%h | meta_data=%b, selected_way=%h", 
    cycles-1, data0, meta_data0, way_select0);
  wait(msg_out == MEM_RESP);
  $display("%0d> Cache controller responds to writeback request.", cycles-1);
  
  @(posedge clock)begin
    msg_in  <= NO_REQ;
    address <= 0;
	  data_in <= 0;
  end


  //read miss (replacing a line which is cached in L1 caches)
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    msg_in  <= R_REQ;
    address <= 32'h11223388;
  end
  $display("%0d> Read request", cycles-1);

  wait(read0 & index0 == 'h22 & tag0 == 24'h112233);
  $display("%0d> Read cache memory", cycles-1);

  @(posedge clock)begin
    data_in0     <= 32'h33_66_22_70;
    tag_in0      <= 24'h444444;
    matched_way0 <= 2;
    coh_bits0    <= 2'b10;
    status_bits0 <= 3'b111;
  	hit0         <= 0;
  end
  @(data_in0) $display("%0d> cache memory responds. data:%h | matched way:%d | coh_bits:%b | status bits:%b", cycles-1, data_in0, matched_way0, coh_bits0,
  status_bits0);
  @(posedge clock)begin
    data_in0 <= 0;
    tag_in0  <= 0;
    matched_way0 <= 0;
    coh_bits0 <= 0;
    status_bits0 <= 0;
  	hit0 <= 0;
  end 

  wait(msg_out == REQ_FLUSH && out_address == 32'h44444488);
  $display("%0d> Cache issues REQ_FLUSH on the bus. address:%h", cycles-1, out_address);
  @(posedge clock)begin
    msg_in  <= NO_REQ;
    address <= 0;
	  data_in <= 0;
  end
  
 repeat(2) @(posedge clock);
  @(posedge clock)begin
    msg_in  <= C_FLUSH;
    address <= 32'h44444488;
    data_in <= 32'h01_02_03_04;
  end
  $display("%0d> Cache line flushed in response to a callback from Lx cache", cycles-1);

  wait(read0 & index0 == 'h22 & tag0 == 24'h444444);
  $display("%0d> Read cache memory", cycles-1);
  @(posedge clock)begin
    data_in0     <= 32'h33_66_22_70;
    tag_in0      <= 26'h0444444;
    matched_way0 <= 2;
    coh_bits0    <= 2'b10;
    status_bits0 <= 3'b111;
  	hit0         <= 1;
  end
  @(data_in0) $display("%0d> cache memory responds. data:%h | matched way:%d | coh_bits:%b | status bits:%b", cycles-1, data_in0, matched_way0, coh_bits0,
  status_bits0);
  @(posedge clock)begin
    data_in0 <= 0;
    tag_in0  <= 0;
    matched_way0 <= 0;
    coh_bits0 <= 0;
    status_bits0 <= 0;
  	hit0 <= 0;
  end 
  //check writing the flushed line to memory
  wait(write0 & index0 == 6'h22 & tag0 == 24'h444444 & data0 == 32'h01_02_03_04
  & meta_data0 == 5'b11010);
  //check response
  wait(msg_out == MEM_C_RESP);
  @(posedge clock)begin
    msg_in  <= NO_REQ;
    address <= 0;
    data_in <= 0;
  end

  //EN_ACCESS message from the processor side completing the flush request transactions.
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    msg_in  <= EN_ACCESS;
    address <= 32'h44444488;
  end
  $display("%0d> Read request", cycles-1);
  wait(msg_out == MEM_RESP & out_address == 32'h44444488);
  @(posedge clock)begin
    msg_in  <= NO_REQ;
    address <= 32'd0;
  end
  
  //miss on a line not cached in other caches
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    msg_in  <= R_REQ;
    address <= 32'h1122338C;
  end
  $display("%0d> Read request", cycles-1);

  wait(read0 & index0 == 'h23);
  $display("%0d> Read cache memory", cycles-1);

  @(posedge clock)begin
    data_in0     <= 32'h33_66_22_70;
    tag_in0      <= 24'h444444;
    matched_way0 <= 1;
    coh_bits0    <= 2'b00;
    status_bits0 <= 3'b110;
  	hit0         <= 0;
  end
  @(data_in0) $display("%0d> cache memory responds. data:%h | matched way:%d | coh_bits:%b | status bits:%b", cycles-1, data_in0, matched_way0, coh_bits0,
  status_bits0);
  @(posedge clock)begin
    data_in0     <= 0;
    tag_in0      <= 0;
    matched_way0 <= 0;
    coh_bits0    <= 0;
    status_bits0 <= 0;
  	hit0 <= 0;
  end 

  wait(cache2mem_msg == WB_REQ & cache2mem_address == 32'h4444448C);
  repeat(4) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg     <= MEM_RESP;
    mem2cache_address <= 32'h4444448C;
  end
  @(posedge clock)begin
    mem2cache_msg     <= NO_REQ;
    mem2cache_address <= 0;
  end

  wait(cache2mem_msg == R_REQ & cache2mem_address == 32'h1122338C);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg     <= MEM_RESP;
    mem2cache_address <= 32'h1122338C;
    mem2cache_data    <= 32'h99_99_99_99;
  end
  @(posedge clock)begin
    mem2cache_msg     <= NO_REQ;
    mem2cache_address <= 0;
    mem2cache_data    <= 0;
  end
  //check write to cache memory
  wait(write0 & index0 == 6'h23 & tag0 == 24'h112233 & meta_data0 == 5'b10101);
  //check response
  wait(msg_out == MEM_RESP & data_out == 32'h99999999 & out_address == 32'h1122338c);
  @(posedge clock)begin
    msg_in  <= NO_REQ;
    address <= 0;
  end


  //check REQ_FLUSH from memory side and pending_requests signal
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg     <= Inv; //same encoding as REQ_FLUSH
    mem2cache_address <= 32'h333333CC;
  end
  $display("%0d> Flush request form the memory side", cycles-1);

  //wait(read0 & index0 == 'h33);
  wait(read0);
  $display("Index is:%h", index0);
  $display("%0d> Read cache memory", cycles-1);
  @(posedge clock)begin
    data_in0     <= 32'h55_55_55_55;
    tag_in0      <= 24'h333333;
    matched_way0 <= 3;
    coh_bits0    <= 2'b10; //modified
    status_bits0 <= 3'b111; //cached in level above and dirty
  	hit0         <= 1;
  end
  @(data_in0) $display("%0d> cache memory responds. data:%h | matched way:%d | coh_bits:%b | status bits:%b", cycles-1, data_in0, matched_way0, coh_bits0,
  status_bits0);
  @(posedge clock)begin
    data_in0     <= 0;
    tag_in0      <= 0;
    matched_way0 <= 0;
    coh_bits0    <= 0;
    status_bits0 <= 0;
  	hit0 <= 0;
  end 
  wait(msg_out == REQ_FLUSH & out_address == 32'h333333CC);

  //L1 caches respond to the flush request
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    msg_in   <= EN_ACCESS;
	address  <= 32'h333333CC;
	data_in  <= 32'h0;
  end

  wait(read0 & index0 == 'h33 & tag0 == 24'h333333);
  $display("%0d> Read cache memory", cycles-1);
  @(posedge clock)begin
    data_in0     <= 32'h55_55_55_55;
    tag_in0      <= 24'h333333;
    matched_way0 <= 3;
    coh_bits0    <= 2'b10; //modified
    status_bits0 <= 3'b111; //cached in level above and dirty
  	hit0         <= 1;
  end

  //check response to processor side interface amd memory-side interface
  wait(msg_out == MEM_RESP & out_address == 32'h333333CC);
  wait(cache2mem_msg == C_FLUSH & cache2mem_address == 32'h333333CC &
    cache2mem_data == 32'h55_55_55_55);
  @(posedge clock)begin
    msg_in            <= NO_REQ;
	address           <= 32'h0;
	data_in           <= 32'h0;
	mem2cache_msg     <= NO_REQ;
	mem2cache_address <= 32'h0;
  end

  #20;
  $display("\ntb_Lxcache_controller --> Test Passed!\n\n");
  $stop;
end

//timeout
initial begin
  #1500;
  $display("\ntb_Lxcache_controller --> Test Failed!\n\n");
  $stop;
end

endmodule
