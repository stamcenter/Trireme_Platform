/** @module : seven_stage_priv_BRAM_top
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

module seven_stage_priv_BRAM_top #(
  parameter CORE             = 0,
  parameter CLOCK_FREQUENCY  = 100000000, // 100MHz
  parameter BAUD_RATE        = 115200,
  parameter DATA_WIDTH       = 64,
  parameter ADDRESS_BITS     = 64,
  parameter MEM_ADDRESS_BITS = 14,

  parameter UART_FIFO_SIZE   = 1024,
  parameter INIT_FILE_BASE   = "",
  parameter SCAN_CYCLES_MIN  = 0,
  parameter SCAN_CYCLES_MAX  = 1000
) (
  input clock,
  input reset,

  input start,
  input [ADDRESS_BITS-1:0] program_address,

  // Interrupts
  input m_ext_interrupt,
  input s_ext_interrupt,

  output [ADDRESS_BITS-1:0] PC,

  input uart_rx,
  output uart_tx,

  input scan
);

localparam BRAM_ADDR_MIN = 64'h00000000;
localparam BRAM_ADDR_MAX = 1 << MEM_ADDRESS_BITS;
localparam UART_ADDR_MIN = 64'h000C0000;
localparam UART_ADDR_MAX = 64'h000C0027;
localparam TIME_ADDR_MIN = 64'h000D0000;
localparam TIME_ADDR_MAX = 64'h000D0010;
localparam SW_INTR_ADDR_MIN = 64'h000E0000;
localparam SW_INTR_ADDR_MAX = 64'h000E0007;

localparam UART_RX_ADDR       = 64'h000C0010;
localparam UART_TX_ADDR       = 64'h000C0020;
localparam UART_RX_READY_ADDR = 64'h000C0014;
localparam UART_TX_READY_ADDR = 64'h000C0024;

localparam MTIME_ADDR    = 64'h000D0000;
localparam MTIMECMP_ADDR = 64'h000D0008;

localparam SATP_MODE_BITS = DATA_WIDTH == 32 ? 1 : 4;
localparam ASID_BITS      = DATA_WIDTH == 32 ? 4 : 16;
localparam PPN_BITS       = DATA_WIDTH == 32 ? 22 : 44;

//fetch stage interface
wire fetch_read;
wire [ADDRESS_BITS-1:0] fetch_address_out;
wire [DATA_WIDTH-1  :0] fetch_data_in;
wire [ADDRESS_BITS-1:0] fetch_address_in;
wire fetch_valid;
wire fetch_ready;
//memory stage interface
wire memory_read;
wire memory_write;
wire [DATA_WIDTH/8-1:0] memory_byte_en;
wire [ADDRESS_BITS-1:0] memory_address_out;
wire [DATA_WIDTH-1  :0] memory_data_out;
wire [DATA_WIDTH-1  :0] memory_data_in;
wire [ADDRESS_BITS-1:0] memory_address_in;
wire memory_valid;
wire memory_ready;
//instruction memory/cache interface
wire [DATA_WIDTH-1  :0] i_mem_data_out;
wire [ADDRESS_BITS-1:0] i_mem_address_out;
wire i_mem_valid;
wire i_mem_ready;
wire i_mem_read;
wire [ADDRESS_BITS-1:0] i_mem_address_in;
//data memory/cache interface
wire [DATA_WIDTH-1  :0] d_mem_data_out;
wire [ADDRESS_BITS-1:0] d_mem_address_out;
wire d_mem_valid;
wire d_mem_ready;
wire d_mem_read;
wire d_mem_write;
wire [DATA_WIDTH/8-1:0] d_mem_byte_en;
wire [ADDRESS_BITS-1:0] d_mem_address_in;
wire [DATA_WIDTH-1  :0] d_mem_data_in;

wire i_mem_page_fault;
wire i_mem_access_fault;
wire d_mem_page_fault;
wire d_mem_access_fault;

// Privilege CSRs for Virtual Memory
wire [PPN_BITS-1      :0] PT_base_PPN; // from satp register
wire [ASID_BITS-1     :0] ASID;        // from satp register
wire [1               :0] priv;        // current privilege level
wire [1               :0] MPP;         // from mstatus register
wire [SATP_MODE_BITS-1:0] MODE;        // paging mode
wire                       SUM;         // permit Supervisor User Memory access
wire                       MXR;         // Make eXecutable Readable
wire                       MPRV;        // Modify PRiVilege

wire                  software_interrupt;
wire [DATA_WIDTH-1:0] sw_intr_register;
wire                  sw_intr_read;
wire                  sw_intr_write;
wire [DATA_WIDTH-1:0] sw_intr_data_out;
wire                  sw_intr_interrupt;
wire                  sw_intr_addr;
reg                   sw_intr_valid;

wire                  timer_read;
wire                  timer_write;
wire [DATA_WIDTH-1:0] timer_data_out;
wire                  timer_interrupt;
wire                  timer_addr;
reg                   timer_valid;

wire                  uart_read;
wire                  uart_write;
wire [DATA_WIDTH-1:0] uart_data_out;
wire                  uart_addr;
reg                   uart_valid;

wire                  bram_read;
wire                  bram_write;
wire [DATA_WIDTH-1:0] bram_data_out;
wire                  bram_valid;
wire                  bram_addr;

assign PC = fetch_address_in << 1;

assign i_mem_page_fault   = 1'b0;
assign i_mem_access_fault = 1'b0;
assign d_mem_page_fault   = 1'b0;
assign d_mem_access_fault = 1'b0;

assign software_interrupt = sw_intr_register[0];

seven_stage_priv_core #(
  .CORE(CORE),
  .RESET_PC(64'd0),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SATP_MODE_BITS(SATP_MODE_BITS),
  .ASID_BITS(ASID_BITS),
  .PPN_BITS(PPN_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) core (
  .clock(clock),
  .reset(reset),
  .start(start),
  .program_address(program_address),
  //memory interface
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .fetch_data_in(fetch_data_in),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  .fetch_read(fetch_read),
  .fetch_address_out(fetch_address_out),
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address_out(memory_address_out),
  .memory_data_out(memory_data_out),
  // Interrupts
  .m_ext_interrupt(m_ext_interrupt),
  .s_ext_interrupt(s_ext_interrupt),
  .software_interrupt(software_interrupt),
  .timer_interrupt(timer_interrupt),
  .i_mem_page_fault(i_mem_page_fault),
  .i_mem_access_fault(i_mem_access_fault),
  .d_mem_page_fault(d_mem_page_fault),
  .d_mem_access_fault(d_mem_access_fault),
  // Privilege CSRs for Virtual Memory
  .PT_base_PPN(PT_base_PPN),
  .ASID(ASID),
  .priv(priv),
  .MPP(MPP),
  .MODE(MODE),
  .SUM(SUM),
  .MXR(MXR),
  .MPRV(MPRV),

  .tlb_invalidate(),
  .tlb_invalidate_mode(),

  //scan signal
  .scan(scan)
);

memory_interface #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) mem_interface (
  //fetch stage interface
  .fetch_read(fetch_read),
  .fetch_address_out(fetch_address_out),
  .fetch_data_in(fetch_data_in),
  .fetch_address_in(fetch_address_in),
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  //memory stage interface
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address_out(memory_address_out),
  .memory_data_out(memory_data_out),
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  //instruction memory/cache interface
  .i_mem_data_out(i_mem_data_out),
  .i_mem_address_out(i_mem_address_out),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_ready),
  .i_mem_read(i_mem_read),
  .i_mem_address_in(i_mem_address_in),
  //data memory/cache interface
  .d_mem_data_out(d_mem_data_out),
  .d_mem_address_out(d_mem_address_out),
  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),
  .d_mem_byte_en(d_mem_byte_en),
  .d_mem_address_in(d_mem_address_in),
  .d_mem_data_in(d_mem_data_in),

  .scan(scan)
);

assign sw_intr_addr = (d_mem_address_in >= SW_INTR_ADDR_MIN) & ( d_mem_address_in <= SW_INTR_ADDR_MAX);
assign timer_addr = (d_mem_address_in >= TIME_ADDR_MIN) & ( d_mem_address_in <= TIME_ADDR_MAX);
assign uart_addr  = (d_mem_address_in >= UART_ADDR_MIN) & ( d_mem_address_in <= UART_ADDR_MAX);
// Only use "less than" comparison for BRAM max address comparison because of
// how the BRAM_ADDR_MAX parameter is set
assign bram_addr  = (d_mem_address_in >= BRAM_ADDR_MIN) & ( d_mem_address_in <  BRAM_ADDR_MAX);

assign d_mem_data_out = timer_valid ? timer_data_out :
                        uart_valid  ? uart_data_out  :
                        sw_intr_valid ? sw_intr_data_out :
                        bram_data_out;

assign sw_intr_read = sw_intr_addr & d_mem_read;
assign timer_read = timer_addr & d_mem_read;
// As long as the memory system is always ready, the pipeline should never
// stall the memory issue stage during a uart read, which would cause multiple
// reads to the UART RX FIFO
assign uart_read  = uart_addr & d_mem_read;
assign bram_read  = bram_addr & d_mem_read;

assign sw_intr_write = sw_intr_addr & d_mem_write;
assign timer_write = timer_addr & d_mem_write;
assign uart_write  = uart_addr  & d_mem_write;
assign bram_write  = bram_addr  & d_mem_write;

assign d_mem_valid = bram_valid | sw_intr_valid |timer_valid | uart_valid;

dual_port_BRAM_memory_subsystem #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MEM_ADDRESS_BITS(MEM_ADDRESS_BITS),
  .INIT_FILE_BASE(INIT_FILE_BASE),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) memory (
  .clock(clock),
  .reset(reset),
  //instruction memory
  .i_mem_read(i_mem_read),
  .i_mem_address_in(i_mem_address_in),
  .i_mem_data_out(i_mem_data_out),
  .i_mem_address_out(i_mem_address_out),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_ready),
  //data memory
  .d_mem_read(bram_read),
  .d_mem_write(bram_write),
  .d_mem_byte_en(d_mem_byte_en),
  .d_mem_address_in(d_mem_address_in),
  .d_mem_data_in(d_mem_data_in),
  .d_mem_data_out(bram_data_out),
  .d_mem_address_out(d_mem_address_out),
  .d_mem_valid(bram_valid),
  .d_mem_ready(d_mem_ready),

  .scan(scan)
);

// Memory mapped machine software interrupt register
mm_register #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDRESS_BITS),
  .NUM_REGS(1)
) SW_INTR_REG (
  .clock(clock),
  .reset(reset),

  // Output register value
  .register(sw_intr_register),

  // Memory Mapped Port
  .readEnable(sw_intr_read),
  .writeEnable(sw_intr_write),
  .writeByteEnable(d_mem_byte_en),
  .address(d_mem_address_in),
  .writeData(d_mem_data_in),
  .readData(sw_intr_data_out)
);


timer #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  //.MTIME_ADDR_H(MTIME_ADDR_H),
  //.MTIMECMP_ADDR_H(MTIMECMP_ADDR_H),
  .MTIME_ADDR(MTIME_ADDR),
  .MTIMECMP_ADDR(MTIMECMP_ADDR)
) TIMER (
  .clock(clock),
  .reset(reset),

  .readEnable(timer_read),
  .writeEnable(timer_write),
  .writeByteEnable(d_mem_byte_en),
  .address(d_mem_address_in),
  .writeData(d_mem_data_in),
  .readData(timer_data_out),

  .timer_interrupt(timer_interrupt)
);

mm_uart #(
  .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
  .BAUD_RATE(BAUD_RATE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDRESS_BITS),
  .RX_ADDR(UART_RX_ADDR),
  .TX_ADDR(UART_TX_ADDR),
  .RX_READY_ADDR(UART_RX_READY_ADDR),
  .TX_READY_ADDR(UART_TX_READY_ADDR),
  .UART_FIFO_SIZE(UART_FIFO_SIZE)
) UART (
  .clock(clock),
  .reset(reset),

  .uart_rx(uart_rx),
  .uart_tx(uart_tx),

  .readEnable(uart_read),
  .writeEnable(uart_write),
  .writeByteEnable(d_mem_byte_en),
  .address(d_mem_address_in),
  .writeData(d_mem_data_in),
  .readData(uart_data_out)

);

always@(posedge clock) begin
  sw_intr_valid  <= sw_intr_read;
  timer_valid <= timer_read;
  uart_valid  <= uart_read;
end


endmodule
