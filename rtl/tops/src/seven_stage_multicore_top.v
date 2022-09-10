/** @module : seven_stage_multicore_top
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
 *  - Multi-core processor top module.
 *  - Instantiates a parameterized number of seven-stage pipelined cores.
 *  - Memory subsystem consists of a two level cache hierarchy and the main 
 *    memory.
 *  - Private L1 instruction caches and shared L2 cache.
 *
 *  Sub modules
 *  -----------
   *  seven_stage_core
   *  memory_interface
   *  two_level_cache_hierarchy
   *  main_memory_interface
   *  main_memory
 *
 *  Parameters
 *  ----------
   *  NUM_CORES : Number of cores.
*/

module seven_stage_multicore_top #(
  parameter NUM_CORES           = 2,
  parameter DATA_WIDTH          = 32,
  parameter ADDRESS_BITS        = 32,
  parameter MEM_ADDRESS_BITS    = 14,
  parameter PROGRAM             = "",
  parameter SCAN_CYCLES_MIN     = 0,
  parameter SCAN_CYCLES_MAX     = 1000,
  // Cache hierarchy parameters
  parameter STATUS_BITS_L1      = 2,
  parameter OFFSET_BITS_L1      = {32'd2, 32'd2, 32'd2, 32'd2},
  parameter NUMBER_OF_WAYS_L1   = {32'd2, 32'd2, 32'd2, 32'd2},
  parameter INDEX_BITS_L1       = {32'd5, 32'd5, 32'd5, 32'd5},
  parameter REPLACEMENT_MODE_L1 = 1'b0,
  parameter STATUS_BITS_L2      = 3,
  parameter OFFSET_BITS_L2      = 2,
  parameter NUMBER_OF_WAYS_L2   = 4,
  parameter INDEX_BITS_L2       = 6,
  parameter REPLACEMENT_MODE_L2 = 1'b0,
  parameter L2_INCLUSION        = 1'b1,
  parameter COHERENCE_BITS      = 2,
  parameter MSG_BITS            = 4,
  parameter BUS_OFFSET_BITS     = 2,
  parameter MAX_OFFSET_BITS     = 2,
  //Use default value in module instantiation for following parameters
  parameter NUM_L1_CACHES       = 2*NUM_CORES
) (
  input clock,
  input reset,

  input start,
  input [NUM_CORES*ADDRESS_BITS-1:0] program_address,

  output [NUM_CORES*ADDRESS_BITS-1:0] PC,

  input scan
);

localparam L2_WIDTH  = DATA_WIDTH*(1 << OFFSET_BITS_L2);

//fetch stage interface
  wire [NUM_CORES-1:0] fetch_read;
  wire [NUM_CORES*ADDRESS_BITS-1:0] fetch_address_out;
  wire [NUM_CORES*DATA_WIDTH-1:0] fetch_data_in;
  wire [NUM_CORES*ADDRESS_BITS-1:0] fetch_address_in;
  wire [NUM_CORES-1:0] fetch_valid;
  wire [NUM_CORES-1:0] fetch_ready;
//memory stage interface
  wire [NUM_CORES-1:0] memory_read;
  wire [NUM_CORES-1:0] memory_write;
  wire [NUM_CORES*DATA_WIDTH/8-1:0] memory_byte_en;
  wire [NUM_CORES*ADDRESS_BITS-1:0] memory_address_out;
  wire [NUM_CORES*DATA_WIDTH-1:0] memory_data_out;
  wire [NUM_CORES*DATA_WIDTH-1:0] memory_data_in;
  wire [NUM_CORES*ADDRESS_BITS-1:0] memory_address_in;
  wire [NUM_CORES-1:0] memory_valid;
  wire [NUM_CORES-1:0] memory_ready;
//instruction memory/cache interface
  wire [NUM_CORES*DATA_WIDTH-1:0] i_mem_data_out;
  wire [NUM_CORES*ADDRESS_BITS-1:0] i_mem_address_out;
  wire [NUM_CORES-1:0] i_mem_valid;
  wire [NUM_CORES-1:0] i_mem_ready;
  wire [NUM_CORES-1:0] i_mem_read;
  wire [NUM_CORES*ADDRESS_BITS-1:0] i_mem_address_in;
//data memory/cache interface
  wire [NUM_CORES*DATA_WIDTH-1:0] d_mem_data_out;
  wire [NUM_CORES*ADDRESS_BITS-1:0] d_mem_address_out;
  wire [NUM_CORES-1:0] d_mem_valid;
  wire [NUM_CORES-1:0] d_mem_ready;
  wire [NUM_CORES-1:0] d_mem_read;
  wire [NUM_CORES-1:0] d_mem_write;
  wire [NUM_CORES*DATA_WIDTH/8-1:0] d_mem_byte_en;
  wire [NUM_CORES*ADDRESS_BITS-1:0] d_mem_address_in;
  wire [NUM_CORES*DATA_WIDTH-1:0] d_mem_data_in;
//cache hierarchy to main memory interface signals
  wire [MSG_BITS-1    :0]     intf2cachehier_msg;
  wire [ADDRESS_BITS-1:0] intf2cachehier_address;
  wire [L2_WIDTH-1    :0]    intf2cachehier_data;
  wire [MSG_BITS-1    :0]     cachehier2intf_msg;
  wire [ADDRESS_BITS-1:0] cachehier2intf_address;
  wire [L2_WIDTH-1    :0]    cachehier2intf_data;
//main memory interface to main memory signals
  wire [MSG_BITS-1    :0]     mem2intf_msg;
  wire [ADDRESS_BITS-1:0] mem2intf_address;
  wire [DATA_WIDTH-1  :0]    mem2intf_data;
  wire [MSG_BITS-1    :0]     intf2mem_msg;
  wire [ADDRESS_BITS-1:0] intf2mem_address;
  wire [DATA_WIDTH-1  :0]    intf2mem_data;
//signals to memory mapped registers
  wire [NUM_CORES-1   :0] w_mm_write;
  wire [ADDRESS_BITS-1:0] w_mm_address [NUM_CORES-1:0];
  wire [DATA_WIDTH-1  :0] w_mm_data [NUM_CORES-1:0];


genvar i;
generate
  for(i = 0; i < NUM_CORES; i = i+1)begin : CORES
    assign PC[i*ADDRESS_BITS +: ADDRESS_BITS] = 
                            fetch_address_in[i*ADDRESS_BITS +: ADDRESS_BITS];

    seven_stage_core #(
      .CORE(i),
      .RESET_PC(i*16),
      .DATA_WIDTH(DATA_WIDTH),
      .ADDRESS_BITS(ADDRESS_BITS),
      .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
      .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
    ) core (
      .clock(clock),
      .reset(reset),
      .start(start),
      .program_address(program_address[i*ADDRESS_BITS +: ADDRESS_BITS]),
      //memory interface
      .fetch_valid(fetch_valid[i +: 1]),
      .fetch_ready(fetch_ready[i +: 1]),
      .fetch_data_in(fetch_data_in[i*DATA_WIDTH +: DATA_WIDTH]),
      .fetch_address_in(fetch_address_in[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .memory_valid(memory_valid[i +: 1]),
      .memory_ready(memory_ready[i +: 1]),
      .memory_data_in(memory_data_in[i*DATA_WIDTH +: DATA_WIDTH]),
      .memory_address_in(memory_address_in[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .fetch_read(fetch_read[i +: 1]),
      .fetch_address_out(fetch_address_out[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .memory_read(memory_read[i +: 1]),
      .memory_write(memory_write[i +: 1]),
      .memory_byte_en(memory_byte_en[i*DATA_WIDTH/8 +: DATA_WIDTH/8]),
      .memory_address_out(memory_address_out[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .memory_data_out(memory_data_out[i*DATA_WIDTH +: DATA_WIDTH]),
      //scan signal
      .scan(scan)
    );
    

    memory_interface #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDRESS_BITS(ADDRESS_BITS)
    ) mem_interface (
      //fetch stage interface
      .fetch_read(fetch_read[i +: 1]),
      .fetch_address_out(fetch_address_out[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .fetch_data_in(fetch_data_in[i*DATA_WIDTH +: DATA_WIDTH]),
      .fetch_address_in(fetch_address_in[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .fetch_valid(fetch_valid[i +: 1]),
      .fetch_ready(fetch_ready[i +: 1]),
      //memory stage interface
      .memory_read(memory_read[i +: 1]),
      .memory_write(memory_write[i +: 1]),
      .memory_byte_en(memory_byte_en[i*DATA_WIDTH/8 +: DATA_WIDTH/8]),
      .memory_address_out(memory_address_out[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .memory_data_out(memory_data_out[i*DATA_WIDTH +: DATA_WIDTH]),
      .memory_data_in(memory_data_in[i*DATA_WIDTH +: DATA_WIDTH]),
      .memory_address_in(memory_address_in[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .memory_valid(memory_valid[i +: 1]),
      .memory_ready(memory_ready[i +: 1]),
      //instruction memory/cache interface
      .i_mem_data_out(i_mem_data_out[i*DATA_WIDTH +: DATA_WIDTH]),
      .i_mem_address_out(i_mem_address_out[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .i_mem_valid(i_mem_valid[i +: 1]),
      .i_mem_ready(i_mem_ready[i +: 1]),
      .i_mem_read(i_mem_read[i +: 1]),
      .i_mem_address_in(i_mem_address_in[i*ADDRESS_BITS +: ADDRESS_BITS]),
      //data memory/cache interface
      .d_mem_data_out(d_mem_data_out[i*DATA_WIDTH +: DATA_WIDTH]),
      .d_mem_address_out(d_mem_address_out[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .d_mem_valid(d_mem_valid[i +: 1]),
      .d_mem_ready(d_mem_ready[i +: 1]),
      .d_mem_read(d_mem_read[i +: 1]),
      .d_mem_write(d_mem_write[i +: 1]),
      .d_mem_byte_en(d_mem_byte_en[i*DATA_WIDTH/8 +: DATA_WIDTH/8]),
      .d_mem_address_in(d_mem_address_in[i*ADDRESS_BITS +: ADDRESS_BITS]),
      .d_mem_data_in(d_mem_data_in[i*DATA_WIDTH +: DATA_WIDTH]),
    
      .scan(scan)
    );
  end
endgenerate

/*Cache hierarchy*/
two_level_cache_hierarchy #(
  .STATUS_BITS_L1(STATUS_BITS_L1),
  .OFFSET_BITS_L1(OFFSET_BITS_L1),
  .NUMBER_OF_WAYS_L1(NUMBER_OF_WAYS_L1),
  .INDEX_BITS_L1(INDEX_BITS_L1),
  .REPLACEMENT_MODE_L1(REPLACEMENT_MODE_L1),
  .STATUS_BITS_L2(STATUS_BITS_L2),
  .OFFSET_BITS_L2(OFFSET_BITS_L2),
  .NUMBER_OF_WAYS_L2(NUMBER_OF_WAYS_L2),
  .INDEX_BITS_L2(INDEX_BITS_L2),
  .REPLACEMENT_MODE_L2(REPLACEMENT_MODE_L2),
  .L2_INCLUSION(L2_INCLUSION),
  .COHERENCE_BITS(COHERENCE_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .NUM_L1_CACHES(NUM_L1_CACHES),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) cache_hier (
  .clock(clock),
  .reset(reset),
  //interface with processor pipelines
  .read({d_mem_read, i_mem_read}),
  .write({d_mem_write, {NUM_CORES{1'b0}}}),
  .invalidate({2*NUM_CORES{1'b0}}),
  .w_byte_en({d_mem_byte_en, {NUM_CORES*DATA_WIDTH/8{1'b0}}}),
  .flush({2*NUM_CORES{1'b0}}),
  .address({d_mem_address_in, i_mem_address_in}),
  .data_in({d_mem_data_in, {NUM_CORES*DATA_WIDTH{1'b0}}}),
  .data_out({d_mem_data_out, i_mem_data_out}),
  .out_address({d_mem_address_out, i_mem_address_out}),
  .ready({d_mem_ready, i_mem_ready}),
  .valid({d_mem_valid, i_mem_valid}),
  //interface with memory side interface
  .mem2cachehier_msg(intf2cachehier_msg),
  .mem2cachehier_address(intf2cachehier_address),
  .mem2cachehier_data(intf2cachehier_data),
  .cachehier2mem_msg(cachehier2intf_msg),
  .cachehier2mem_address(cachehier2intf_address),
  .cachehier2mem_data(cachehier2intf_data),
  .mem_intf_busy(1'b0),
  .mem_intf_address(32'd0),
  .mem_intf_address_valid(1'b0),
  //interface for memory side interface to access cache memory
  .port1_read(1'b0),
  .port1_write(1'b0),
  .port1_invalidate(1'b0),
  .port1_index(6'd0),
  .port1_tag(24'b0),
  .port1_metadata(5'b0),
  .port1_write_data(128'd0),
  .port1_way_select(2'd0),
  .port1_read_data(),
  .port1_matched_way(),
  .port1_coh_bits(),
  .port1_status_bits(),
  .port1_hit(),
  
  .scan(scan)
);


/*Main memory interface*/
main_memory_interface #(
  .OFFSET_BITS(OFFSET_BITS_L2),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS)
) mem_intf (
  .clock(clock),
  .reset(reset),
  .cache2interface_msg(cachehier2intf_msg),
  .cache2interface_address(cachehier2intf_address),
  .cache2interface_data(cachehier2intf_data),
  .interface2cache_msg(intf2cachehier_msg),
  .interface2cache_address(intf2cachehier_address),
  .interface2cache_data(intf2cachehier_data),
  .mem2interface_msg(mem2intf_msg),
  .mem2interface_address(mem2intf_address),
  .mem2interface_data(mem2intf_data),
  .interface2mem_msg(intf2mem_msg),
  .interface2mem_address(intf2mem_address),
  .interface2mem_data(intf2mem_data)
);


/*Main memory*/
main_memory #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .INDEX_BITS(MEM_ADDRESS_BITS),
  .NUM_PORTS(1),
  .PROGRAM(PROGRAM)
) memory (
  .clock(clock),
  .reset(reset),
  .msg_in(intf2mem_msg),
  .address(intf2mem_address),
  .data_in(intf2mem_data),
  .msg_out(mem2intf_msg),
  .address_out(mem2intf_address),
  .data_out(mem2intf_data)
);



endmodule
