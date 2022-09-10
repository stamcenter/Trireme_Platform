/** @module : tb_coherence_controller
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
module tb_coherence_controller();

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value>>1;
  end
endfunction

parameter MSG_BITS       = 4,
          NUM_CACHES     = 4;


// states
localparam IDLE            = 0,
           WAIT_EN         = 1,
           COHERENCE_OP    = 2,
           WAIT_FOR_MEM    = 3,
           HOLD            = 4,
           END_TRANSACTION = 5;

`include `INCLUDE_FILE

localparam BUS_PORTS     = NUM_CACHES + 1;
localparam MEM_PORT      = BUS_PORTS - 1;
localparam BUS_SIG_WIDTH = log2(BUS_PORTS);

genvar j;
integer i;
reg clock, reset;
wire [(NUM_CACHES*MSG_BITS)-1 : 0] w_cache2mem_msg;
reg [MSG_BITS-1 : 0] cache2mem_msg [NUM_CACHES-1 : 0];
reg [MSG_BITS-1 : 0] mem2controller_msg;
reg [MSG_BITS-1 : 0] bus_msg;
wire [BUS_SIG_WIDTH-1 : 0] bus_control;
wire bus_en;
wire req_ready;
wire [BUS_PORTS-1 : 0] curr_master;

// bundle inputs
generate
  for(j=0; j<NUM_CACHES; j=j+1)begin
    assign w_cache2mem_msg[j*MSG_BITS +: MSG_BITS]    =    cache2mem_msg[j];
  end
endgenerate

//instantiate coherence controller
coherence_controller #(
  MSG_BITS,
  NUM_CACHES
) DUT (
  .clock(clock), 
  .reset(reset),
  .cache2mem_msg(w_cache2mem_msg),
  .mem2controller_msg(mem2controller_msg),
  .bus_msg(bus_msg),
  .bus_control(bus_control),
  .bus_en(bus_en),
  .curr_master(curr_master),
  .req_ready(req_ready)
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
  cycles = 0;
  clock  = 0;
  reset <= 0;
  for(i=0; i<NUM_CACHES; i=i+1)begin
    cache2mem_msg[i]    <= NO_REQ;
  end
  mem2controller_msg <= NO_REQ;
  bus_msg            <= NO_REQ;

  repeat(1) @(posedge clock);
  @(posedge clock) reset <= 1;
  $display("%d> Assert reset signal.", cycles);
  repeat(10) @(posedge clock);
  @(posedge clock) reset <= 0;
  $display("%d> Deassert reset signal.", cycles);

  wait(DUT.state == IDLE);
  $display("%d> Reset sequence completed." ,cycles);

  //1. read request. no dirty copies in caches. no flush requests.//
  $display("1) Read request. No dirty copies of data in the L1 caches. L2 cache doesn't make flush requests.");
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[2] <= R_REQ;
    $display("%d> Cache 2 issues a read request.", cycles);
  end
  wait(DUT.state == WAIT_EN);
  $display("%d> Coherence controller waiting for other caches to enable the access.", 
    (cycles-1));
  bus_msg = R_REQ;
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[0] <= EN_ACCESS;
    cache2mem_msg[1] <= EN_ACCESS;
    $display("%d> Caches 0 and 1 enable the access.", cycles);
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[3] <= EN_ACCESS;
    $display("%d> Cache 3 enables the access.", cycles);
  end
  wait(req_ready);
  $display("%d> Controller waiting for L2 cache. req_ready=%b", (cycles-1), req_ready);
  @(posedge clock)begin
    cache2mem_msg[0] <= NO_REQ;
    cache2mem_msg[1] <= NO_REQ;
    cache2mem_msg[3] <= NO_REQ;
  end
  repeat(4) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= MEM_RESP;
    $display("%d> L2 cache responds to the request.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  $display("%d> Controller waiting for L1 cache to end the transaction.", (cycles-1));
  bus_msg = MEM_RESP;
  @(posedge clock)begin
    cache2mem_msg[2] <= NO_REQ;
    $display("%d> Cache 2 clears the request to the bus.", cycles);
  end
  wait(DUT.state == IDLE & ~req_ready);
  $display("%d> Controller in IDLE state.", (cycles-1));
  bus_msg = NO_REQ;
  @(posedge clock) mem2controller_msg <= NO_REQ;

  //2. read request. no dirty copies. L2 requests a flush. Read requester and 
  //another cache responds to the flush request.
  repeat(4) @(posedge clock);
  $display("2) Read request. No dirty copies of data in the L1 caches. L2 cache requests a flush. Read requestor and another cache responds to REQ_FLUSH.");
  @(posedge clock)begin
    cache2mem_msg[1] <= R_REQ;
    $display("%d> Cache 1 issues a R_REQ.", cycles);
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[0] <= EN_ACCESS;
    cache2mem_msg[2] <= EN_ACCESS;
    cache2mem_msg[3] <= EN_ACCESS;
    $display("%d> Caches 0, 2 and 3 enables the access.", cycles);
  end
  bus_msg = R_REQ;
  wait(req_ready);
  $display("%d> Controller waiting for L2 cache. req_ready=%b", (cycles-1), req_ready);
  @(posedge clock)begin
    cache2mem_msg[0] <= NO_REQ;
    cache2mem_msg[2] <= NO_REQ;
    cache2mem_msg[3] <= NO_REQ;
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= REQ_FLUSH;
    $display("%d> L2 cache issue a flush request.", cycles);
  end
  wait(~req_ready);
  $display("%d> Controller deasserts req_ready signal.", (cycles-1));
  bus_msg = REQ_FLUSH;
  repeat(1) @(posedge clock); //might want to comment this line.
  @(posedge clock)begin
    cache2mem_msg[0] <= EN_ACCESS;
    cache2mem_msg[1] <= C_FLUSH;
    cache2mem_msg[2] <= EN_ACCESS;
    cache2mem_msg[3] <= C_FLUSH;
    $display("%d> Caches 1 and 3 flushes the cache line requested by L2.", cycles);
  end
  wait(curr_master == 4'b0010);
  bus_msg = C_FLUSH;
  $display("%d> Controller assign cache 1 as bus master. curr_master=%b", (cycles-1), 
    curr_master);
  @(posedge clock)begin
    $display("%d> Caches 1 starts flushing.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= MEM_C_RESP;
    $display("%d> L2 cache responds to C_FLUSH.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  $display("%d> Controller waiting for L1 cache to end the transaction.", (cycles-1));
  bus_msg = MEM_C_RESP;
  @(posedge clock)begin
    cache2mem_msg[1] <= HOLD_BUS;
    $display("%d> Cache 1 issues a HOLD_BUS message.", cycles);
  end
  wait(DUT.state == HOLD);
  bus_msg = HOLD_BUS;
  $display("%d> Controller waiting for cache 1 to transfer the next block.", (cycles-1));
  @(posedge clock) mem2controller_msg <= NO_REQ;
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[1] <= C_FLUSH;
    $display("%d> Cache 1 flushes next block.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= MEM_C_RESP;
    $display("%d> L2 cache responds to C_FLUSH.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  $display("%d> Controller waiting for L1 cache to end the transaction.", (cycles-1));
  bus_msg = MEM_C_RESP;

  @(posedge clock)begin
    cache2mem_msg[1] <= HOLD_BUS;
    $display("%d> Cache 1 issues a HOLD_BUS message.", cycles);
  end
  wait(DUT.state == HOLD);
  bus_msg = HOLD_BUS;
  $display("%d> Controller waiting for cache 1 to transfer the next block.", (cycles-1));
  @(posedge clock) mem2controller_msg <= NO_REQ;
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[1] <= EN_ACCESS;
    bus_msg <= EN_ACCESS;
    $display("%d> Cache 1 sends EN_ACCESS message.", cycles);
  end
  wait(DUT.state == WAIT_EN);
  $display("%d> Controller goes to WAIT_EN state.", (cycles-1));
  bus_msg = NO_REQ;
  wait(bus_control == 3);
  bus_msg = C_FLUSH;
  $display("%d> Controller assign cache 3 as bus master. curr_master=%b", (cycles-1), 
    curr_master);
  @(posedge clock)begin
    $display("%d> Caches 3 starts flushing.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= MEM_C_RESP;
    $display("%d> L2 cache responds to C_FLUSH.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  $display("%d> Controller waiting for L1 cache to end the transaction.", (cycles-1));
  bus_msg = MEM_C_RESP;
  @(posedge clock)begin
    cache2mem_msg[3] <= EN_ACCESS;
    $display("%d> Cache 1 issues EN_ACCESS message.", cycles);
  end
  wait(DUT.state == WAIT_EN);
  $display("%d> Controller goes to WAIT_EN state.", (cycles-1));
  bus_msg = NO_REQ;
  @(posedge clock) mem2controller_msg <= NO_REQ;
  wait(req_ready);
  @(posedge clock)begin
    cache2mem_msg[0] <= NO_REQ;
    cache2mem_msg[1] <= NO_REQ;
    cache2mem_msg[2] <= NO_REQ;
    cache2mem_msg[3] <= NO_REQ;
    $display("%d> All L1 caches clears their responses.", cycles);
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[1] <= R_REQ;
    bus_msg <= R_REQ;
    $display("%d> cache 1 puts its original R_REQ on the bus.", cycles);
  end
  repeat(4) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= MEM_RESP;
    $display("%d> L2 cache responds to the request.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  $display("%d> Controller waiting for L1 cache to end the transaction.", (cycles-1));
  bus_msg = MEM_RESP;
  @(posedge clock)begin
    cache2mem_msg[1] <= NO_REQ;
    $display("%d> Cache 1 clears the request to the bus.", cycles);
  end
  wait(DUT.state == IDLE & ~req_ready);
  $display("%d> Controller in IDLE state.", (cycles-1));
  bus_msg = NO_REQ;
  @(posedge clock) mem2controller_msg <= NO_REQ;



  //3. Read request. One of the caches has a dirty copy of the requested cache
  //line.
  //4. writeback request. 
  $display("3)Read request. One of the caches has a dirty copy of the requested cache line.\n4)Writeback request.");
  repeat(4) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[1] <= R_REQ;
    $display("%d> Cache 1 issues a read request.", cycles);
    cache2mem_msg[3] <= WB_REQ;
    $display("%d> Cache 3 issues a writeback request.", cycles);
  end
  wait(DUT.state == WAIT_EN);
  $display("%d> Controller waiting for caches to enable the access.", (cycles-1));
  bus_msg = R_REQ;
  @(posedge clock)begin
    cache2mem_msg[0] <= EN_ACCESS;
    cache2mem_msg[2] <= C_WB;
    cache2mem_msg[3] <= EN_ACCESS;
    $display("%d> Cache 2 writes back the dirty cache line.", cycles);
  end

  wait(curr_master == 4'b0100);
  bus_msg = C_WB;
  $display("%d> Controller assign cache 2 as bus master. curr_master=%b", (cycles-1), 
    curr_master);
  @(posedge clock)begin
    $display("%d> Caches 1 starts writeback.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= MEM_C_RESP;
    $display("%d> L2 cache responds to C_WB.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  $display("%d> Controller waiting for L1 cache to end the transaction.", (cycles-1));
  bus_msg = MEM_C_RESP;
  @(posedge clock)begin
    cache2mem_msg[2] <= EN_ACCESS;
    $display("%d> Cache 1 issues a EN_ACCESS message.", cycles);
  end
  wait(DUT.state == WAIT_EN);
  $display("%d> Controller goes to WAIT_EN state.", (cycles-1));
  bus_msg = NO_REQ;
  @(posedge clock) mem2controller_msg <= NO_REQ;
  wait(req_ready);
  bus_msg <= R_REQ;
  @(posedge clock)begin
    cache2mem_msg[0] <= NO_REQ;
    cache2mem_msg[2] <= NO_REQ;
    cache2mem_msg[3] <= WB_REQ;
    $display("%d> All L1 caches clears their coherence responses.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= MEM_RESP;
    $display("%d> L2 Cache responds to the R_REQ.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  bus_msg = MEM_RESP;
  $display("%d> Controller waits for cache 1 to end the transaction.", (cycles-1));
  @(posedge clock)begin
    cache2mem_msg[1] = NO_REQ;
    $display("%d> Cache 1 clears the R_REQ.", cycles);
  end
  wait(DUT.state == IDLE);
  $display("%d> Controller goes to IDLE state.", (cycles-1));
  bus_msg = NO_REQ;
  @(posedge clock) mem2controller_msg <= NO_REQ;

  wait(bus_control == 3);
  bus_msg = WB_REQ;
  $display("%d> Controller assign cache 3 as bus master. curr_master=%b", (cycles-1), 
    curr_master);
  @(posedge clock)begin
    $display("%d> Caches 3 starts writeback.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= MEM_RESP;
    $display("%d> L2 Cache responds to the WB_REQ.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  bus_msg = MEM_RESP;
  $display("%d> Controller waits for cache 3 to end the transaction.", (cycles-1));
  @(posedge clock)begin
    cache2mem_msg[3] = NO_REQ;
    $display("%d> Cache 3 clears the WB_REQ.", cycles);
  end
  wait(DUT.state == IDLE);
  $display("%d> Controller goes to IDLE state.", (cycles-1));
  bus_msg = NO_REQ;
  @(posedge clock) mem2controller_msg <= NO_REQ;


  //5) Writing to a shared line.
  repeat(5) @(posedge clock);
  $display("5) Writing to a shared line.");
  @(posedge clock)begin
    cache2mem_msg[2] <= WS_BCAST;
    $display("%d> cache 2 braodcasts its intent to write to a shared line.", cycles);
  end
  wait(DUT.state == WAIT_EN);
  $display("%d> Controller waiting for other caches to enable the operation.", (cycles-1));
  bus_msg = WS_BCAST;
  @(posedge clock)begin
    cache2mem_msg[0] <= EN_ACCESS;
    cache2mem_msg[1] <= EN_ACCESS;
    cache2mem_msg[3] <= EN_ACCESS;
    $display("%d> caches 0, 1, and 3 enable the operation.", cycles);
  end
  repeat(2) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= EN_ACCESS;
	$display("%d> Lx cache enables the operation.", cycles);
  end
  wait(DUT.state == END_TRANSACTION);
  $display("%d> Controller waiting cache 2 to clear the request.", (cycles-1));
  @(posedge clock)begin
    cache2mem_msg[0]   <= NO_REQ;
    cache2mem_msg[1]   <= NO_REQ;
    cache2mem_msg[3]   <= NO_REQ;
	mem2controller_msg <= NO_REQ;
  end
  repeat(1) @(posedge clock);
  @(posedge clock)begin
    cache2mem_msg[2] <= NO_REQ;
    $display("%d> cache 2 clears the request.", cycles);
  end
  wait(DUT.state == IDLE);
  $display("%d> Controller goes to IDLE state.", (cycles-1));
  bus_msg = NO_REQ;

  //test flush request initiated by the Lx cache
  repeat(3) @(posedge clock);
  @(posedge clock)begin
    mem2controller_msg <= REQ_FLUSH;
	$display("%d> Lx cache issues a flush request.", cycles);
  end
  wait(bus_en);
  bus_msg = REQ_FLUSH;
  $display("%d> Controller grants the Lx cache control of the bus.", (cycles-1));
  
  repeat(2) @(posedge clock);
  @(posedge clock)begin
	cache2mem_msg[0] <= EN_ACCESS;
	cache2mem_msg[1] <= EN_ACCESS;
	cache2mem_msg[2] <= EN_ACCESS;
	cache2mem_msg[3] <= EN_ACCESS;
	$display("%d> Every L(x-1) cache sends EN_ACCESS.", cycles);
  end
  
  wait(req_ready);
  $display("%d> Controller sets req_ready signal.", (cycles-1));
  
  @(posedge clock)begin
	mem2controller_msg <= NO_REQ;
	$display("%d> Lx cache clears the flush request.", cycles);
  end
  
  #50;
  $display("\ntb_coherence_controller --> Test Passed!\n\n");
  $finish;
end

//Timeout
initial begin
  #400;
  $display("\ntb_coherence_controller --> Test Failed!\n\n");
  $finish;
end

endmodule
