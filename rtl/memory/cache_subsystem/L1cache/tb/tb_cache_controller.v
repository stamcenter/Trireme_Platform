/** @module : tb_cache_controller
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

module tb_cache_controller();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter STATUS_BITS           =  2,
          COHERENCE_BITS        =  2,
          OFFSET_BITS           =  2,
          DATA_WIDTH            = 32,
          NUMBER_OF_WAYS        =  4,
          ADDRESS_BITS          = 32,
          INDEX_BITS            =  6,
          MSG_BITS              =  4,
          CORE                  =  0,
          CACHE_NO              =  0;


localparam CACHE_WORDS = 1 << OFFSET_BITS; //number of words in one line.
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam SBITS       = COHERENCE_BITS + STATUS_BITS;
localparam TAG_BITS    = ADDRESS_BITS - OFFSET_BITS - INDEX_BITS;
localparam WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;


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

`include `INCLUDE_FILE


reg  clock, reset;
reg  read, write, flush;
reg  cflush;
reg  c_wb;
reg  [ADDRESS_BITS-1:0] address;
reg  [DATA_WIDTH-1:  0] data_in;
reg  report;
wire [DATA_WIDTH-1:  0] data_out;
wire [ADDRESS_BITS-1:0] out_address;
wire ready;
wire valid;

//interface with cache memory
reg  [CACHE_WIDTH-1   :0] data_in0;
reg  [TAG_BITS-1      :0] tag_in0;
reg  [WAY_BITS-1      :0] matched_way0;
reg  [COHERENCE_BITS-1:0] coh_bits0;
reg  [STATUS_BITS-1   :0] status_bits0;
reg  hit0;
wire read0, write0, invalidate0;
wire [INDEX_BITS-1    :0] index0;
wire [TAG_BITS-1      :0] tag0;
wire [SBITS-1         :0] meta_data0;
wire [CACHE_WIDTH-1   :0] data_out0;
wire [WAY_BITS-1      :0] way_select0;

wire read1, write1, invalidate1;
wire [INDEX_BITS-1    :0] index1;
wire [TAG_BITS-1      :0] tag1;
wire [SBITS-1         :0] meta_data1;
wire [CACHE_WIDTH-1   :0] data_out1;
wire [WAY_BITS-1      :0] way_select1;
wire i_reset;

//interface with bus interface
reg  [MSG_BITS-1:    0] mem2cache_msg;
reg  [CACHE_WIDTH-1: 0] mem2cache_data;
reg  [ADDRESS_BITS-1:0] mem2cache_address;
wire [MSG_BITS-1:    0] cache2mem_msg;
wire [CACHE_WIDTH-1: 0] cache2mem_data;
wire [ADDRESS_BITS-1:0] cache2mem_address;

//inputs from snooper
reg  [ADDRESS_BITS-1:0] snoop_address;
reg  snoop_read;    //snooper is reading data
reg  snoop_modify;


//instantiate DUT
cache_controller #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .MSG_BITS(MSG_BITS),
  .CORE(CORE),
  .CACHE_NO(CACHE_NO)
) DUT (
  .clock(clock),
  .reset(reset),
  .read(read),
  .write(write),
  .invalidate(1'b0),
  .flush(flush),
  .w_byte_en(4'b1111),
  .address(address),
  .data_in(data_in),
  .report(report),
  .data_out(data_out),
  .out_address(out_address),
  .ready(ready),
  .valid(valid),

  .data_in0(data_in0),
  .tag_in0(tag_in0),
  .matched_way0(matched_way0),
  .coh_bits0(coh_bits0),
  .status_bits0(status_bits0),
  .hit0(hit0),
  .read0(read0),
  .write0(write0),
  .invalidate0(invalidate0),
  .index0(index0),
  .tag0(tag0),
  .meta_data0(meta_data0),
  .data_out0(data_out0),
  .way_select0(way_select0),
  .read1(read1),
  .write1(write1),
  .invalidate1(invalidate1),
  .index1(index1),
  .tag1(tag1),
  .meta_data1(meta_data1),
  .data_out1(data_out1),
  .way_select1(way_select1),
  .i_reset(i_reset),

  .mem2cache_msg(mem2cache_msg),
  .mem2cache_data(mem2cache_data),
  .mem2cache_address(mem2cache_address),
  .cache2mem_msg(cache2mem_msg),
  .cache2mem_data(cache2mem_data),
  .cache2mem_address(cache2mem_address),

  .snoop_address(snoop_address),
  .snoop_read(snoop_read),
  .snoop_modify(snoop_modify)
);


// cycle counter
reg [31:0] cycles;
always @(posedge clock)begin
  cycles <= cycles + 32'd1;
end

//clock generator
always
  #1 clock = ~clock;


// test vectors
initial begin
  cycles            = 0;
  clock             = 0;
  reset             = 0;
  read              = 0;
  write             = 0;
  flush             = 0;
  address           = 0;
  data_in           = 0;
  report            = 0;
  mem2cache_msg     = 0;
  mem2cache_data    = 0;
  mem2cache_address = 0;
  snoop_address     = 0;
  snoop_read        = 0;
  snoop_modify      = 0;

  repeat(1) @(posedge clock);
  @(posedge clock) reset <= 1;
  $display("%0d> Assert reset signal.", cycles);
  repeat(10) @(posedge clock);
  @(posedge clock) reset <= 0;
  $display("%0d> Deassert reset signal.", cycles);

  wait(DUT.state == IDLE);
  $display("%0d> Reset sequence completed." ,cycles);

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    $display("%0d> Read multiple memory locations in a pipelined manner.", cycles);
    read <= 1;
    address <= 32'hEEEEEE04;
  end
  @(address) $display("%0d> Read address:%h", cycles-1, address);
  @(posedge clock)begin
    address <= 32'hEEEEEE05;
  end
  @(address) $display("%0d> Read address:%h", cycles-1, address);
  @(posedge clock)begin
    address <= 32'hEEEEEE06;
  end
  @(address) $display("%0d> Read address:%h", cycles-1, address);
  @(posedge clock)begin
    address <= 32'hbbbbbb06;
  end
  @(address) $display("%0d> Read address:%h", cycles-1, address);
  @(posedge clock)begin
    address <= 32'h33333308;
  end
  @(address) $display("%0d> Read address:%h", cycles-1, address);
  @(posedge clock)begin
    read <= 0;
    address <= 32'h0;
  end


  repeat(3) @(posedge clock);
  @(posedge clock)begin
    $display("Write to an address already cached and modified.");
    write <= 1;
    address <= 32'h55555504;
    data_in <= 32'h12345678;
  end
  @(address) $display("%0d> Write address:%h | value:%h", cycles-1, address,
    data_in);
  @(posedge clock)begin
    $display("Write to an address already cached and shared.");
    address <= 32'hBBBBBB07;
    data_in <= 32'hABABABAB;
  end
  @(address) $display("%0d> Write address:%h | value:%h", cycles-1, address,
    data_in);
  @(posedge clock)begin
    write <= 0;
    address <= 32'h0;
    data_in <= 32'h0;
  end

  wait(cache2mem_msg == WS_BCAST);
  $display("%0d> Cache issues WS_BCAST.", cycles-1);
  repeat(5) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg <= EN_ACCESS;
    mem2cache_address <= 32'hBBBBBB04;
    $display("%0d> EN_ACCESS signal from the bus interface.", cycles);
  end
  wait(cache2mem_msg == NO_REQ);
  $display("%0d> Cache clears the WS_BCAST message.", cycles-1);
  @(posedge clock)begin
    mem2cache_msg <= NO_REQ;
    mem2cache_address <= 0;
  end


  repeat(3) @(posedge clock);
  @(posedge clock)begin
    $display("%0d> Write to an address not cached.", cycles);
    write <= 1;
    address <= 32'hFCFCFC04;
    data_in <= 32'h00000035;
  end
  @(address) $display("%0d> Write address:%h | value:%h", cycles-1, address,
    data_in);
  @(posedge clock)begin
    $display("%0d> Read an address not cached.", cycles);
    write <= 0;
    read  <= 1;
    address <= 32'h00000404;
    data_in <= 32'h00000000;
  end
  @(address) $display("%0d> Read address:%h", cycles-1, address);
  @(posedge clock)begin
    read <= 0;
    address <= 0;
  end

  wait(cache2mem_msg == RFO_BCAST);
  $display("%0d> Cache issues RFO_BCAST message.", cycles-1);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    $display("%0d> Cache gets the bus.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg <= MEM_RESP;
    mem2cache_address <= 32'h3f3f3f00;
    mem2cache_data <= 128'h11111111_22222222_33333333_44444444;
    $display("%0d> MEM_RESP from bus interface.", cycles);
  end
  wait(cache2mem_msg == NO_REQ);
  $display("%0d> Cache clears RFO_BCAST message.", cycles-1);
  @(posedge clock)begin
    mem2cache_data <= 0;
    mem2cache_address <= 0;
    mem2cache_msg <= NO_REQ;
  end

  wait(cache2mem_msg == R_REQ);
  $display("%0d> Cache issues a read request", cycles-1);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    $display("%0d> Cache obtains the bus.", cycles);
  end
  @(posedge clock)begin
    $display("%0d> Other caches enable the access.", cycles);
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg     <= MEM_RESP_S;
    mem2cache_address <= 32'h00000100;
    mem2cache_data    <= 128'h99991111_88882222_77773333_66664444;
    $display("%0d> L2 cache responds.", cycles);
  end
  wait(cache2mem_msg == NO_REQ);
  $display("%0d> Cache clears the request.", cycles-1);
  @(posedge clock)begin
    mem2cache_msg     <= NO_REQ;
    mem2cache_address <= 32'h00000000;
    mem2cache_data    <= 0;
  end

  //test behavior with coherence operations.
  wait(DUT.state == IDLE);
  @(posedge clock)begin
    read <= 1;
    address <= 32'heeeddd05;
    snoop_modify <= 1;
    snoop_address <= 32'heeeddd04 >> 2;
    $display("%0d> Snooper modifies address:32'heeeddd04", cycles);
  end
  @(address) $display("%0d> Read address:%h", cycles-1, address);
  @(posedge clock)begin
    read <= 0;
    address <= 32'h00000000;
    snoop_modify <= 0;
    snoop_address <= 32'h00000000;
  end

  wait(cache2mem_msg == R_REQ);
  $display("%0d> Cache issues a read request", cycles-1);
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg     <= MEM_RESP;
    mem2cache_address <= 32'heeeddd04 >> 2;
    mem2cache_data    <= 128'h00000001_00000002_00000003_00000004;
    $display("%0d> L2 cache responds.", cycles);
  end
  wait(cache2mem_msg == NO_REQ);
  $display("%0d> Cache clears the request.", cycles-1);
  @(posedge clock)begin
    mem2cache_msg     <= NO_REQ;
    mem2cache_address <= 32'h00000000;
    mem2cache_data    <= 0;
  end

  wait(DUT.state == IDLE);
  @(posedge clock)begin
    write <= 1;
    address <= 32'h11223307;
  end
  @(address) $display("%0d> Write address:%h", cycles-1, address);
  @(posedge clock)begin
    address <= 32'heeeddd04;
    data_in <= 32'hffffffff;
    snoop_read <= 1;
    snoop_address <= 32'h11223304 >> 2;
    $display("%0d> Snooper reads address:32'h11223304", cycles);
  end
  @(address) $display("%0d> Write address:%h", cycles-1, address);
  @(posedge clock)begin
    write <= 0;
    address <= 32'h00000000;
    data_in <= 32'h00000000;
    snoop_read <= 0;
    snoop_address <= 32'h00000000;
  end

  wait(cache2mem_msg == RFO_BCAST);
  $display("%0d> Cache issues RFO_BCAST message.", cycles-1);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2cache_msg <= MEM_RESP;
    mem2cache_address <= 32'h11223304;
    mem2cache_data <= 128'h10000000_20000000_30000000_40000000;
    $display("%0d> MEM_RESP from bus interface.", cycles);
  end
  wait(cache2mem_msg == NO_REQ);
  $display("%0d> Cache clears RFO_BCAST message.", cycles-1);
  @(posedge clock)begin
    mem2cache_data <= 0;
    mem2cache_address <= 0;
    mem2cache_msg <= NO_REQ;
  end
  wait(DUT.state == IDLE);
  $display("%0d> Cache in IDLE state.", cycles-1);


  wait(ready);


  #10;
  $display("\ntb_cache_controller --> Test Passed!\n\n");
  $stop();
end


//cache memory interface
initial begin
  data_in0 = 0;
  tag_in0 = 0;
  matched_way0 = 0;
  coh_bits0 = 0;
  status_bits0 = 2'b00;
  hit0 = 0;

  wait(read0 & index0 == 6'h20 & tag0 == 24'h3bbbbb);
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'h3bbbbb;
    data_in0     <= 128'h11111111_77777777_33333333_AAAAAAAA;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b01;
    matched_way0 <= 0;
  end
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'h3bbbbb;
    data_in0     <= 128'h11111111_77777777_33333333_AAAAAAAA;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b01;
    matched_way0 <= 0;
  end
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'h3bbbbb;
    data_in0     <= 128'h11111111_77777777_33333333_AAAAAAAA;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b01;
    matched_way0 <= 0;
  end
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'hbbbbbb >> 2;
    data_in0     <= 128'h22222222_88888888_44444444_BBBBBBBB;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b11;
    matched_way0 <= 1;
  end
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'h333333 >> 2;
    data_in0     <= 128'h77777777_11111111_33333333_AAAAAAAA;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b01;
    matched_way0 <= 0;
  end
  @(posedge clock)begin
    hit0         <= 0;
    tag_in0      <= 24'h000000;
    data_in0     <= 128'h00000000_00000000_00000000_00000000;
	  status_bits0 <= 2'b00;
    coh_bits0    <= 2'b00;
    matched_way0 <= 0;
  end

  wait(read0 & index0==6'h10);
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'h555555 >> 2;
    data_in0     <= 128'h33333333_99999999_55555555_CCCCCCCC;
	  status_bits0 <= 2'b11;
    coh_bits0    <= 2'b10;
    matched_way0 <= 2;
  end
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'hbbbbbb >> 2;
    data_in0     <= 128'h22222222_88888888_44444444_BBBBBBBB;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b11;
    matched_way0 <= 1;
  end
  @(posedge clock)begin //same output on next clock edge as well
    hit0         <= 1;
    tag_in0      <= 24'hbbbbbb;
    data_in0     <= 128'h22222222_88888888_44444444_BBBBBBBB;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b11;
    matched_way0 <= 1;
  end
  @(posedge clock)begin
    hit0         <= 0;
    tag_in0      <= 24'h000000;
    data_in0     <= 128'h00000000_00000000_00000000_00000000;
	  status_bits0 <= 2'b00;
    coh_bits0    <= 2'b00;
    matched_way0 <= 0;
  end


  wait(read0 & tag0==24'hfcfcfc >> 2);
  @(posedge clock)begin
    hit0         <= 0;
    tag_in0      <= 24'h000000;
    data_in0     <= 128'h00000000_00000000_00000000_00000000;
	  status_bits0 <= 2'b00;
    coh_bits0    <= 2'b00;
    matched_way0 <= 3;
  end
  wait(read0 & tag0==24'h000004 >> 2);
  @(posedge clock)begin
    hit0         <= 0;
    tag_in0      <= 24'h000000;
    data_in0     <= 128'h00000000_00000000_00000000_00000000;
	  status_bits0 <= 2'b00;
    coh_bits0    <= 2'b00;
    matched_way0 <= 0;
  end

  wait(read0 & tag0==24'heeeddd >> 2);
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'heeeddd >> 2;
    data_in0     <= 128'h00000000_33330000_00004444_00000000;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b11;
    matched_way0 <= 3;
  end
  @(posedge clock)begin
    hit0         <= 0;
    tag_in0      <= 24'h000000;
    data_in0     <= 128'h00000000_00000000_00000000_00000000;
	  status_bits0 <= 2'b00;
    coh_bits0    <= 2'b00;
    matched_way0 <= 0;
  end


  wait(read0 & tag0==24'h112233 >> 2);
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'h112233 >> 2;
    data_in0     <= 128'h00000005_00000006_00000007_00000008;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b01;
    matched_way0 <= 2;
  end
  //repeat(1) @(posedge clock);
  @(posedge clock)begin
    hit0         <= 0;
    tag_in0      <= 24'h000000;
    data_in0     <= 128'h00000000_00000000_00000000_00000000;
	  status_bits0 <= 2'b00;
    coh_bits0    <= 2'b00;
    matched_way0 <= 0;
  end
  wait(read0 & tag0==24'heeeddd >> 2);
  wait(read0 & tag0==24'h112233 >> 2);
  wait(read0 & tag0==24'heeeddd >> 2);
  @(posedge clock)begin
    hit0         <= 1;
    tag_in0      <= 24'heeddd >> 2;
    data_in0     <= 128'h00000005_00000006_00000007_00000008;
	  status_bits0 <= 2'b10;
    coh_bits0    <= 2'b01;
    matched_way0 <= 2;
  end
  @(posedge clock)begin
    hit0         <= 0;
    tag_in0      <= 24'h000000;
    data_in0     <= 128'h00000000_00000000_00000000_00000000;
	  status_bits0 <= 2'b00;
    coh_bits0    <= 2'b00;
    matched_way0 <= 0;
  end

end

//timeout
initial begin
  #4000;
  $display("\ntb_cache_controller --> Test Failed!\n\n");
  $stop;
end


//print values returned by the cache
always @(posedge clock)begin
  if(valid)
    $display("%0d> Data word returned:%h | Address:%h", cycles-1, data_out,
      out_address);
end


endmodule
