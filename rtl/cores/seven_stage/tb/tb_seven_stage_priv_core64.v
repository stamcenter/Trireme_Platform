/** @module : tb_seven_stage_priv_core64
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

`define CORE_REGISTER_FILE DUT.ID.base_decode.registers.register_file

module tb_seven_stage_priv_core64();

parameter RESET_PC        = 0;
parameter DATA_WIDTH      = 64;
parameter NUM_BYTES       = DATA_WIDTH/8;
parameter ADDRESS_BITS    = 64;
parameter SATP_MODE_BITS =  4;
parameter ASID_BITS      = 16;
parameter PPN_BITS       = 44;

task print_state;
  integer x;
  begin
    $display("Time:\t%0d", $time);
    for( x=0; x<32; x=x+1) begin
      $display("Register %d: %h", x, `CORE_REGISTER_FILE[x]);
    end
    $display("--------------------------------------------------------------------------------");
    $display("\n\n");
  end
endtask

integer x;

reg  clock;
reg  reset;
reg  start;
reg  [ADDRESS_BITS-1:0] program_address;
//memory interface
reg  fetch_valid;
reg  fetch_ready;
reg  [DATA_WIDTH-1  :0] fetch_data_in;
reg  [ADDRESS_BITS-1:0] fetch_address_in;
reg  memory_valid;
reg  memory_ready;
reg  [DATA_WIDTH-1  :0] memory_data_in;
reg  [ADDRESS_BITS-1:0] memory_address_in;
wire fetch_read;
wire [ADDRESS_BITS-1:0] fetch_address_out;
wire memory_read;
wire memory_write;
wire [NUM_BYTES-1:   0] memory_byte_en;
wire [ADDRESS_BITS-1:0] memory_address_out;
wire [DATA_WIDTH-1  :0] memory_data_out;
// Interrupts
reg m_ext_interrupt;
reg s_ext_interrupt;
reg software_interrupt;
reg timer_interrupt;
reg i_mem_page_fault;
reg i_mem_access_fault;
reg d_mem_page_fault;
reg d_mem_access_fault;

// Privilege CSRs for Virtual Memory
wire [PPN_BITS-1      :0] PT_base_PPN; // from satp register
wire [ASID_BITS-1     :0] ASID;        // from satp register
wire [1               :0] priv;        // current privilege level
wire [1               :0] MPP;         // from mstatus register
wire [SATP_MODE_BITS-1:0] MODE;        // paging mode
wire                       SUM;         // permit Supervisor User Memory access
wire                       MXR;         // Make eXecutable Readable
wire                       MPRV;        // Modify PRiVilege

// TLB invalidate signals from sfence.vma
wire       tlb_invalidate;
wire [1:0] tlb_invalidate_mode;

//scan signal
reg  scan;


//instantiate single_cycle_top
seven_stage_priv_core #(
  .RESET_PC(RESET_PC),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SATP_MODE_BITS(SATP_MODE_BITS),
  .ASID_BITS(ASID_BITS),
  .PPN_BITS(PPN_BITS)
) DUT (
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

  // TLB invalidate signals from sfence.vma
  .tlb_invalidate(tlb_invalidate),
  .tlb_invalidate_mode(tlb_invalidate_mode),

  //scan signal
  .scan(scan)
);

initial begin
  for(x=0; x<32; x=x+1) begin
    `CORE_REGISTER_FILE[x] = 32'd0;
  end
end

// generate clock signal
always #1 clock = ~clock;

initial begin
  clock <= 1;
  reset <= 1;
  start <= 0;
  program_address   <= 0;
  fetch_valid       <= 0;
  fetch_ready       <= 0;
  fetch_data_in     <= 0;
  fetch_address_in  <= 0;
  memory_valid      <= 0;
  memory_ready      <= 0;
  memory_address_in <= 0;
  memory_data_in    <= 0;
  m_ext_interrupt   <= 0;
  s_ext_interrupt   <= 0;
  software_interrupt<= 0;
  timer_interrupt   <= 0;
  i_mem_page_fault   <= 1'b0;
  i_mem_access_fault <= 1'b0;
  d_mem_page_fault   <= 1'b0;
  d_mem_access_fault <= 1'b0;

  scan              <= 0;

  repeat(2) @(posedge clock);
  @(posedge clock) reset <= 0;

  @(posedge clock)begin
    start <= 0;
    fetch_ready  <= 1;
    fetch_valid  <= 1;
    memory_ready <= 1;
    memory_valid <= 1;
    fetch_data_in <= 32'h00000013;
  end

  wait(fetch_read & fetch_address_out == 4);
  fetch_data_in <= {32'h00000013, 32'h00000013};
  wait(fetch_read & fetch_address_out == 20);
  fetch_data_in <={32'b000000000010_00000_000_01100_0010011, 32'b000000000001_00000_000_01011_0010011}; // addi a1, zero, 1;
  wait(fetch_read & fetch_address_out == 24);
  fetch_data_in <={32'b000000000010_00000_000_01100_0010011, 32'b000000000001_00000_000_01011_0010011}; // addi a2, zero, 2
  wait(fetch_read & fetch_address_out == 28);
  fetch_data_in <= {32'b000000000110_00000_000_01110_0010011, 32'b000000000101_00000_000_01101_0010011}; // addi a3, zero, 5
  wait(fetch_read & fetch_address_out == 32);
  fetch_data_in <= {32'b000000000110_00000_000_01110_0010011, 32'b000000000101_00000_000_01101_0010011}; // addi a4, zero, 6
  wait(fetch_read & fetch_address_out == 36);
  fetch_data_in <= {32'h00000013, 32'b111111111111_00000_000_01111_0010011}; // addi a5, zero, -1
  wait(fetch_read & fetch_address_out == 40);
  fetch_data_in <= {32'h00000013, 32'h00000013};
  repeat(1) @(posedge clock);
  print_state();


  wait(fetch_read & fetch_address_out == 60);
  fetch_data_in <= 32'b0000000_01100_01011_000_10000_0110011; // add a6, a1, a2
  $display("add a6, a1, a2");


  wait(fetch_read & fetch_address_out == 80);
  if(`CORE_REGISTER_FILE[16] != 0)begin
    $display("\ntb_seven_stage_priv_core64 --> Test Failed!\n\n");
    print_state();
    $stop;
  end
  wait(fetch_read & fetch_address_out == 84);
  if(`CORE_REGISTER_FILE[16] != 3)begin
    $display("\ntb_seven_stage_priv_core64 --> Test Failed!\n\n");
    print_state();
    $stop;
  end

  fetch_data_in <= {32'h00000013, 32'h00000013};
  fetch_valid  <= 1;

  wait(fetch_read & fetch_address_out == 100);
  repeat(1) @(posedge clock);
  // fetch sfence.vma instruction
  fetch_data_in <= {32'b0001001_00001_00000_000_00000_1110011, 32'h00000013}; // nop, sfence.vma
  fetch_valid  <= 1;
  repeat(1) @(posedge clock);
  fetch_data_in <= {32'h00000013, 32'h00000013};
  fetch_valid  <= 1;

  repeat(3) @(posedge clock);
  if(tlb_invalidate      !== 1'b1  |
     tlb_invalidate_mode !== 2'b10 )begin
    $display("Error! Unexpected TLB Invalidate signals.");
    $display("\ntb_seven_stage_priv_core64 --> Test Failed!\n\n");
    print_state();
    $display("tlb inv: %b, mode: %b", tlb_invalidate, tlb_invalidate_mode);
    $stop;
  end

  repeat(1) @(posedge clock);
  fetch_data_in <= {32'h00000013, 32'h00000013};
  fetch_valid  <= 0;


  // Test Instruction Memory Page Fault Exception
  repeat(10) @(posedge clock);
  i_mem_page_fault = 1'b1;
  repeat(1) @(posedge clock);
  i_mem_page_fault = 1'b0;

  wait(DUT.CTRL.exception);
  repeat(1) @(posedge clock);
  // Send in valid signal with trap vector address
  fetch_valid  <= 1;
  #1
  if(DUT.FI.PC_reg !== 64'h00000000_00001000) begin
    $display("Error! Unexpected PC after I-mem Page Fault trap.");
    $display("PC reg: %h", DUT.FI.PC_reg);
    $display("\ntb_seven_stage_priv_core64 --> Test Failed!\n\n");
    $stop;
  end

  repeat(1) @(posedge clock);
  #1
  if(DUT.FI.PC_reg !== 64'h00000000_00001004) begin
    $display("Error! Unexpected PC after I-mem Page Fault trap.");
    $display("PC reg: %h", DUT.FI.PC_reg);
    $display("\ntb_seven_stage_priv_core64 --> Test Failed!\n\n");
    $stop;
  end

  // fetch m_ret instruction
  fetch_data_in <= {32'b00110000001000000000000001110011, 32'b00110000001000000000000001110011}; // mret, mret
  repeat(1) @(posedge clock);
  fetch_data_in <= {32'h00000013, 32'h00000013};


  fetch_data_in <= {32'b00000000000000000000000010000011, 32'b00000000000000000000000010000011}; // lb x1, 0(x0), lb x1, 0(x0)
  memory_valid  <= 0;

  // Test Data Memory Page Fault Exception
  repeat(20) @(posedge clock);
  d_mem_page_fault = 1'b1;
  repeat(1) @(posedge clock);
  d_mem_page_fault = 1'b0;
  #1
  if(DUT.FI.PC_reg !== 64'h00000000_00001000) begin
    $display("Error! Unexpected PC after D-mem Page Fault trap.");
    $display("PC reg: %h", DUT.FI.PC_reg);
    $display("\ntb_seven_stage_priv_core64 --> Test Failed!\n\n");
    $stop;
  end

  repeat(1) @(posedge clock);
  #1
  if(DUT.FI.PC_reg !== 64'h00000000_00001004) begin
    $display("Error! Unexpected PC after D-mem Page Fault trap.");
    $display("PC reg: %h", DUT.FI.PC_reg);
    $display("\ntb_seven_stage_priv_core64 --> Test Failed!\n\n");
    $stop;
  end


  repeat(10) @(posedge clock);
  $display("\ntb_seven_stage_priv_core64 --> Test Passed!\n\n");
  $stop;

end

always @(posedge clock) fetch_address_in = fetch_address_out;

initial begin
  repeat(500) @(posedge clock);
  $display("\nError: Timeout");
  $display("\ntb_seven_stage_priv_core64 --> Test Failed!\n\n");
  $stop;
end


endmodule
