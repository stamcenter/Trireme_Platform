/** @module : tb_lx_bus_interface
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
module tb_lx_bus_interface();

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

parameter CACHE_OFFSET_BITS =  2, //max offset bits from cache side
          BUS_OFFSET_BITS   =  1, //determines width of the bus
          DATA_WIDTH        =  8,
          ADDRESS_WIDTH     = 32,
          MSG_BITS          =  4,
          MAX_OFFSET_BITS   =  3;

localparam CACHE_WORDS = 1 << CACHE_OFFSET_BITS; //number of words in one line.
localparam BUS_WORDS   = 1 << BUS_OFFSET_BITS; //width of data bus.
localparam MAX_WORDS   = 1 << MAX_OFFSET_BITS;
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam BUS_WIDTH   = DATA_WIDTH*BUS_WORDS;
localparam CACHE2BUS_OFFSETDIFF = (CACHE_OFFSET_BITS >= BUS_OFFSET_BITS ) ? 
                                  (CACHE_OFFSET_BITS -  BUS_OFFSET_BITS ) :
                                  (BUS_OFFSET_BITS   - CACHE_OFFSET_BITS) ;
localparam CACHE2BUS_RATIO = 1 << CACHE2BUS_OFFSETDIFF;

localparam IDLE           = 4'd0,
           RECEIVE        = 4'd1,
           SEND_ADDR      = 4'd2,
           SEND_TO_CACHE  = 4'd3,
           READ_DATA      = 4'd4,
           READ_FILLER    = 4'd5,
           TRANSFER       = 4'd6,
           WAIT_FOR_RESP  = 4'd7,
           WAIT_BUS_CLEAR = 4'd8;

`include `INCLUDE_FILE

reg clock, reset;
reg  [MSG_BITS-1           :0] bus_msg_in;
reg  [ADDRESS_WIDTH-1      :0] bus_address_in;
reg  [BUS_WIDTH-1          :0] bus_data_in;
reg  req_ready;
reg  [log2(MAX_OFFSET_BITS):0] req_offset;
wire [MSG_BITS-1           :0] bus_msg_out;
wire [ADDRESS_WIDTH-1      :0] bus_address_out;
wire [BUS_WIDTH-1          :0] bus_data_out;
wire [log2(MAX_OFFSET_BITS):0] active_offset;
reg  [MSG_BITS-1           :0] cache_msg_in;
reg  [ADDRESS_WIDTH-1      :0] cache_address_in;
reg  [CACHE_WIDTH-1        :0] cache_data_in;
wire [MSG_BITS-1           :0] cache_msg_out;
wire [ADDRESS_WIDTH-1      :0] cache_address_out;
wire [CACHE_WIDTH-1        :0] cache_data_out;
wire pending_requests;


//instantiate DUT
lx_bus_interface #(
  CACHE_OFFSET_BITS,
  BUS_OFFSET_BITS,
  DATA_WIDTH,
  ADDRESS_WIDTH,
  MSG_BITS,
  MAX_OFFSET_BITS
) DUT (
  .clock(clock),
  .reset(reset),
  .bus_msg_in(bus_msg_in),
  .bus_address_in(bus_address_in),
  .bus_data_in(bus_data_in),
  .bus_msg_out(bus_msg_out),
  .bus_address_out(bus_address_out),
  .bus_data_out(bus_data_out),
  .req_offset(req_offset),
  .req_ready(req_ready),
  .active_offset(active_offset),
  .cache_msg_in(cache_msg_in),
  .cache_address_in(cache_address_in),
  .cache_data_in(cache_data_in),
  .cache_msg_out(cache_msg_out),
  .cache_address_out(cache_address_out),
  .cache_data_out(cache_data_out),
  .pending_requests(pending_requests)
);

// cycle counter
reg [31:0] cycles;
always @(posedge clock)begin
  cycles <= cycles + 32'd1;
end

//clock generator
always
  #1 clock = ~clock;


initial begin
  cycles = 0;
  clock  = 0;
  reset  = 0;
  bus_msg_in = NO_REQ;
  bus_address_in = 0;
  bus_data_in = 0;
  req_offset = 0;
  req_ready = 0;
  cache_msg_in = NO_REQ;
  cache_address_in = 0;
  cache_data_in = 0;

  repeat(1) @(posedge clock);
  @(posedge clock) reset <= 1;
  $display("%0d> Assert reset signal.", cycles);
  repeat(10) @(posedge clock);
  @(posedge clock) reset <= 0;
  $display("%0d> Deassert reset signal.", cycles);

  wait(DUT.state == IDLE);
  $display("%0d> Reset sequence completed." ,cycles);
  
  @(posedge clock)begin
    bus_msg_in <= R_REQ;
    bus_address_in <= 32'h11110004;
    req_offset <= 3;
  end
  @(bus_msg_in) $display("%0d> Read request on the bus. Address:%h | width:%0d"
  , cycles-1, bus_address_in, 1<<req_offset);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    req_ready <= 1;
    $display("%0d> req_ready signal goes high.", cycles);
  end

  wait(cache_msg_out == R_REQ);
  $display("%0d> Read request 1 sent to the cache. Address:%h" ,cycles-1,
    cache_address_out);

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    cache_data_in <= 32'h44_33_22_11;
  end
  @(cache_msg_in) $display("%0d> Cache returns data. Data:%h", cycles-1,
    cache_data_in);
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
    cache_data_in <= 0;
  end

  wait(cache_msg_out == NO_REQ);
  wait(cache_msg_out == R_REQ);
  $display("%0d> Read request 2 sent to the cache. Address:%h" ,cycles-1,
    cache_address_out);

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    cache_data_in <= 32'h88_77_66_55;
  end
  @(cache_msg_in) $display("%0d> Cache returns data. Data:%h", cycles-1,
    cache_data_in);
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
    cache_data_in <= 0;
  end
  wait(bus_msg_out == MEM_RESP);
  $display("%0d> Interface puts MEM_RESP message on the bus" ,cycles-1);
  @(posedge clock)begin
	bus_msg_in <= NO_REQ;
	bus_address_in <= 0;
	req_offset <= 0;
	req_ready <= 0;
  end
  repeat(4)begin
    @(bus_data_out) $display("%0d> Return data block = %h" ,cycles-1,
      bus_data_out);
  end
  
  //write-back request
  wait(DUT.state == IDLE);
  @(posedge clock)begin
    bus_msg_in <= WB_REQ;
	bus_address_in <= 32'h80004488;
	req_ready <= 1;
	req_offset <= 3; 
  end
  @(bus_msg_in) $display("%0d> Write-back request on the bus. Address:%h | Width:%0d" ,
	cycles-1, bus_address_in, req_offset);
  @(posedge clock)begin
    bus_data_in <= 16'h02_01;
  end
  @(bus_data_in) $display("%0d> Write-back block 1 = %h" ,cycles-1, 
    bus_data_in);
  @(posedge clock)begin
    bus_data_in <= 16'h04_03;
  end
  @(bus_data_in) $display("%0d> Write-back block 2 = %h" ,cycles-1, 
    bus_data_in);
  @(posedge clock)begin
    bus_data_in <= 16'h06_05;
  end
  @(bus_data_in) $display("%0d> Write-back block 3 = %h" ,cycles-1, 
    bus_data_in);
  @(posedge clock)begin
    bus_data_in <= 16'h08_07;
  end
  @(bus_data_in) $display("%0d> Write-back block 4 = %h" ,cycles-1, 
    bus_data_in);

  wait(cache_msg_out == WB_REQ);
  $display("%0d> Write-back request sent to the cache. Address:%h | Data:%h",
    cycles-1, cache_address_out, cache_data_out);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    $display("%0d> Cache responds." ,cycles);
  end
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
  end
  wait(cache_msg_out == NO_REQ);
  wait(cache_msg_out == WB_REQ);
  $display("%0d> Write-back request sent to the cache. Address:%h | Data:%h",
    cycles-1, cache_address_out, cache_data_out);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    $display("%0d> Cache responds." ,cycles);
  end
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
  end
  wait(bus_msg_out == MEM_RESP);
  $display("%0d> Interface responds on the bus." ,cycles-1);
  @(posedge clock)begin
	bus_msg_in <= NO_REQ;
	bus_data_in <= 0;
	bus_address_in <= 0;
	req_offset <= 0;
	req_ready <= 0;
  end
  
  //REQ_FLUSH on read request
  wait(DUT.state == IDLE);
  @(posedge clock)begin
	bus_msg_in <= RFO_BCAST;
	bus_address_in <= 32'hABCD0048;
	req_offset <= 3;
	req_ready <= 1;
	$display("%0d> RFO_BCAST on the bus." ,cycles);
  end
  @(bus_msg_in) $display("Address:%h", bus_address_in);
  wait(cache_msg_out == RFO_BCAST);
  $display("%0d> Request 1 sent to the cache. Address:%h" ,cycles-1,
    cache_address_out);

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    cache_data_in <= 32'hdd_cc_bb_aa;
  end
  @(cache_msg_in) $display("%0d> Cache returns data. Data:%h", cycles-1,
    cache_data_in);
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
    cache_data_in <= 0;
  end

  wait(cache_msg_out == NO_REQ);
  wait(cache_msg_out == RFO_BCAST);
  $display("%0d> Read request 2 sent to the cache. Address:%h" ,cycles-1,
    cache_address_out);

  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= REQ_FLUSH;
    cache_address_in <= cache_address_out;
    cache_data_in <= 0;
  end
  @(cache_msg_in) $display("%0d> Cache issues REQ_FLUSH. Address:%h | current data:%h",
    cycles-1, cache_address_in, cache_data_in);
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
  end
  wait(bus_msg_out == REQ_FLUSH);
  $display("%0d> REQ_FLUSH is put on the bus. Address:%h" ,cycles-1,
    bus_address_out);
  @(posedge clock)begin
    bus_msg_in <= bus_msg_out;
    bus_address_in <= bus_address_out;
    req_ready <= 0;
  end
  
  repeat(2) @(posedge clock);
  @(posedge clock)begin
  bus_msg_in <= C_FLUSH;
  bus_address_in <= 32'habcd004e;
  req_offset <= 0;
  end
  @(bus_msg_in) $display("%0d> One cache flushes a line. Address:%h",
    cycles-1, bus_address_in);
  @(posedge clock)begin
  bus_data_in <= 16'h81;
  end
  @(bus_data_in) $display("%0d> Data flushed:%h", cycles-1, bus_data_in);

  wait(cache_msg_out == R_REQ);
  $display("%0d> Read request sent to the cache. Address:%h", cycles-1, 
    cache_address_out);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    cache_data_in <= 32'h90_80_70_60;
  end
  @(cache_msg_in) $display("%0d> Cache returns a line :%h", cycles-1, 
    cache_data_in);
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
    cache_data_in <= 0;
  end
  wait(cache_msg_out == C_FLUSH);
  $display("%0d> Send the C_FLUSH to the cache.", cycles-1);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    $display("%0d> Cache responds to the C_FLUSH.", cycles);
  end
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
  end
  wait(bus_msg_out == MEM_RESP);
  $display("%0d> Response to the C_FLUSH message.", cycles-1);
  @(posedge clock)begin
    bus_msg_in <= NO_REQ;
    bus_address_in <= 0;
    bus_data_in <= 0;
  end
  wait(bus_msg_out == REQ_FLUSH);
  $display("%0d> REQ_FLUSH goes back on the bus.", cycles-1);
  @(posedge clock)begin
    bus_msg_in <= REQ_FLUSH;
    bus_address_in <= bus_address_out;
    bus_data_in <= 0;
  end
  @(posedge clock)begin
    req_ready <= 1;
    bus_msg_in <= NO_REQ;
    $display("%0d> req_ready signal goes high. Nothing else to be flushed", 
      cycles);
  end
  wait(cache_msg_out == EN_ACCESS);
  $display("%0d> EN_ACCESS message sent to the cache..", cycles-1);
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    $display("%0d> Cache responds", cycles);
  end
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
  end
  wait(bus_msg_out == NO_REQ);
  $display("%0d> Interface clears the message to hold the bus.", cycles-1);
  @(posedge clock)begin
    req_ready <= 0;
  end


  //read request for a block smaller than Lx cache line width.
  wait(DUT.state == IDLE);
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    bus_msg_in <= R_REQ;
    bus_address_in <= 32'h00770007;
    req_offset <= 0;
	$display("%0d> Read request for a block smaller than Lx cache line width.", 
      cycles);
  end
  @(bus_msg_in) $display("bus_address_in:%h | req_offset:%h", bus_address_in, req_offset);
  @(posedge clock)begin
    req_ready <= 1;
  end
  wait(cache_msg_out == R_REQ);
  $display("%0d> Read request sent to the controller.", cycles-1);
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in <= MEM_RESP;
    cache_address_in <= cache_address_out;
    cache_data_in <= 32'h23_18_22_21;
  end
  @(cache_msg_in) $display("%0d> Controller responds. Data returned:%h", cycles-1, cache_data_in);
  @(posedge clock)begin
    cache_msg_in <= NO_REQ;
    cache_address_in <= 0;
    cache_data_in <= 0;
  end
  wait(bus_msg_out == MEM_RESP);
  $display("%0d> Bus interface puts 'MEM_RESP' message the bus. bus_address_out:%h", 
    cycles-1, bus_address_out);
  @(bus_data_out) $display("%0d> Bus interface puts data on the bus. bus_address_out:%h | bus_data_out:%h", 
    cycles-1, bus_address_out, bus_data_out);
  wait(bus_msg_out == NO_REQ);
  $display("%0d> Bus interface clears the bus.", cycles-1);
  @(posedge clock)begin
    bus_msg_in <= NO_REQ;
    bus_address_in <= 0;
  end

  //WS_BCAST request to write to a shared line Lx cache also has to send an
  //enable signal
  wait(DUT.state == IDLE);
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    bus_msg_in     <= WS_BCAST;
    bus_address_in <= 32'h00770000;
    req_offset     <= 3;
	$display("%0d> Write shared request for a block larger than Lx cache line width.", 
      cycles);
  end
  wait(cache_msg_out == WS_BCAST & cache_address_out == 32'h00770000);
  $display("%0d> Request for the first half of the line sent to the Lx cache.", 
    cycles-1);
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in     <= EN_ACCESS;
    cache_address_in <= cache_address_out;
  end
  wait(cache_msg_out == NO_REQ);
  @(posedge clock)begin
    cache_msg_in     <= NO_REQ;
    cache_address_in <= 0;
  end

  wait(cache_msg_out == WS_BCAST & cache_address_out == 32'h00770004);
  $display("%0d> Request for the second half of the line sent to the Lx cache.", 
    cycles-1);
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    cache_msg_in     <= EN_ACCESS;
    cache_address_in <= cache_address_out;
  end
  wait(cache_msg_out == NO_REQ);
  @(posedge clock)begin
    cache_msg_in     <= NO_REQ;
    cache_address_in <= 0;
  end

  wait(bus_msg_out == EN_ACCESS & bus_address_out == 32'h00770000);
  $display("%0d> DUT responds on to the request over the bus.", cycles-1);

  @(posedge clock)begin
    bus_msg_in     <= NO_REQ;
    bus_address_in <= 0;
  end

  wait(DUT.state == IDLE);
  $display("%0d> DUT goes to IDLE state.", cycles-1);


  //stop simulation
  #10;
  $display("\ntb_lx_bus_interface -> Test Passed!\n\n");
  $stop;  
end

//timeout
initial begin
  #400;
  $display("\ntb_lx_bus_interface -> Test Failed!\n\n");
  $stop;
end

endmodule

