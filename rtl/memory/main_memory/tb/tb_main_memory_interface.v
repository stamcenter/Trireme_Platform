/** @module : tb_main_memory_interface
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

module tb_main_memory_interface();

parameter OFFSET_BITS           = 2,
	        DATA_WIDTH            = 8,
          ADDRESS_WIDTH         = 12,
	        MSG_BITS              = 4;

localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam BUS_WIDTH      = DATA_WIDTH*WORDS_PER_LINE;

localparam IDLE          = 0,
           READ_MEMORY   = 1,
           WRITE_MEMORY  = 2,
           RESPOND       = 3;

// Define INCLUDE_FILE  to point to /includes/params.h. The path should be
// relative to your simulation/sysnthesis directory. You can add the macro
// when compiling this file in modelsim by adding the following argument to the
// vlog command that compiles this module:
// +define+INCLUDE_FILE="../../../includes/params.h"
`include `INCLUDE_FILE


reg clock, reset;
reg [MSG_BITS-1 : 0] cache2interface_msg;
reg [ADDRESS_WIDTH-1 : 0] cache2interface_address;
reg [BUS_WIDTH-1 : 0] cache2interface_data;

wire [MSG_BITS-1 : 0] interface2cache_msg;
wire [ADDRESS_WIDTH-1 : 0] interface2cache_address;
wire [BUS_WIDTH-1 : 0] interface2cache_data;

reg [MSG_BITS-1 : 0] mem2interface_msg;
reg [ADDRESS_WIDTH-1 : 0] mem2interface_address;
reg [DATA_WIDTH-1 : 0] mem2interface_data;

wire [MSG_BITS-1 : 0] interface2mem_msg;
wire [ADDRESS_WIDTH-1 : 0] interface2mem_address;
wire [DATA_WIDTH-1 : 0] interface2mem_data;

//generate clock
always #1 clock = ~clock;

//Instantiate main_memory_interface
main_memory_interface #(OFFSET_BITS, DATA_WIDTH,
    ADDRESS_WIDTH, MSG_BITS)
    DUT(clock, reset, cache2interface_msg, cache2interface_address,
        cache2interface_data, interface2cache_msg, interface2cache_address,
        interface2cache_data, mem2interface_msg, mem2interface_address,
        mem2interface_data, interface2mem_msg, interface2mem_address,
        interface2mem_data);

// processes
//Global signals
initial begin
    clock = 1;
    reset = 1;
    repeat(4) @(posedge clock);
    @(posedge clock) reset = 0;
end

// Last level cache
initial begin
    cache2interface_msg     = NO_REQ;
    cache2interface_address = 0;
    cache2interface_data    = 0;
    wait(~reset);
    @(posedge clock)begin
        cache2interface_msg     = R_REQ;
        cache2interface_address = 12'h104;
    end
    wait((interface2cache_msg == MEM_RESP) & (interface2cache_address == 12'h104));
    @(posedge clock) cache2interface_msg = NO_REQ;

    repeat(4) @(posedge clock);
    @(posedge clock)begin
        cache2interface_msg     = WB_REQ;
        cache2interface_address = 12'h200;
        cache2interface_data    = 32'h99887766;
    end
    wait((interface2cache_msg == MEM_RESP) & (interface2cache_address == 12'h200));
    @(posedge clock) cache2interface_msg = NO_REQ;

    repeat(2)@(posedge clock);
    @(posedge clock)begin
        cache2interface_msg     = FLUSH;
        cache2interface_address = 12'h324;
        cache2interface_data    = 32'h12345678;
    end
    wait((interface2cache_msg == MEM_RESP) & (interface2cache_address == 12'h324));
    @(posedge clock) cache2interface_msg = NO_REQ;
end

//Main memory
initial begin
    mem2interface_msg     = NO_REQ;
    mem2interface_address = 0;
    mem2interface_data    = 0;
    wait((interface2mem_msg == R_REQ) & (interface2mem_address == 12'h104));
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_data    = 8'h11;
        mem2interface_address = 12'h104;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == R_REQ) & (interface2mem_address == 12'h105));
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_data    = 8'h22;
        mem2interface_address = 12'h105;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == R_REQ) & (interface2mem_address == 12'h106));
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_data    = 8'h33;
        mem2interface_address = 12'h106;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == R_REQ) & (interface2mem_address == 12'h107));
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_data    = 8'h44;
        mem2interface_address = 12'h107;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;

    wait((interface2mem_msg == WB_REQ) & (interface2mem_address == 12'h200));
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_address = 12'h200;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == WB_REQ) & (interface2mem_address == 12'h201));
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_address = 12'h201;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == WB_REQ) & (interface2mem_address == 12'h202));
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_address = 12'h202;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == WB_REQ) & (interface2mem_address == 12'h203));
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_address = 12'h203;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;

    wait((interface2mem_msg == WB_REQ) & (interface2mem_address == 12'h324));
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_address = 12'h324;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == WB_REQ) & (interface2mem_address == 12'h325));
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_address = 12'h325;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == WB_REQ) & (interface2mem_address == 12'h326));
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_address = 12'h326;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;
    wait((interface2mem_msg == WB_REQ) & (interface2mem_address == 12'h327));
    @(posedge clock)begin
        mem2interface_msg     = MEM_RESP;
        mem2interface_address = 12'h327;
    end
    @(posedge clock) mem2interface_msg = NO_REQ;

    #20;
    $display("\ntb_main_memory_interface --> Test Passed!\n\n");
    $stop;
end

//timeout
initial begin
  #500;
  $display("\ntb_main_memory_interface --> Test Failed!\n\n");
  $stop;
end


endmodule
