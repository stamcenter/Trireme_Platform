/** @module : single_cycle_core
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

module single_cycle_core #(
  parameter CORE            = 0,
  parameter RESET_PC        = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter NUM_BYTES       = DATA_WIDTH/8,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
)(
  input  clock,
  input  reset,
  input  start,
  input  [ADDRESS_BITS-1 :0] program_address,
  //memory interface
  input  fetch_valid,
  input  fetch_ready,
  input  [DATA_WIDTH-1    :0] fetch_data_in,
  input  [ADDRESS_BITS-1  :0] fetch_address_in,
  input  memory_valid,
  input  memory_ready,
  input  [DATA_WIDTH-1    :0] memory_data_in,
  input  [ADDRESS_BITS-1  :0] memory_address_in,
  output fetch_read,
  output [ADDRESS_BITS-1  :0] fetch_address_out,
  output memory_read,
  output memory_write,
  output [NUM_BYTES-1:     0] memory_byte_en,
  output [ADDRESS_BITS-1  :0] memory_address_out,
  output [DATA_WIDTH-1    :0] memory_data_out,
  //scan signal
  input  scan
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

localparam LOG2_NUM_BYTES  = log2(NUM_BYTES);

//internal wires
wire [1             :0] next_PC_select;
wire [ADDRESS_BITS-1:0] target_PC;
wire [ADDRESS_BITS-1:0] issue_PC;

wire                    flush_fetch_receive;
wire [DATA_WIDTH-1  :0] instruction;

wire [ADDRESS_BITS-1:0] inst_PC;
wire [1             :0] extend_sel;
wire                    write;
wire [4             :0] write_reg;
wire [DATA_WIDTH-1  :0] write_data;
wire [DATA_WIDTH-1  :0] rs1_data;
wire [DATA_WIDTH-1  :0] rs2_data;
wire [4             :0] rd;
wire [6             :0] opcode;
wire [6             :0] funct7;
wire [2             :0] funct3;
wire [DATA_WIDTH-1  :0] extend_imm;
wire [ADDRESS_BITS-1:0] branch_target;
wire [ADDRESS_BITS-1:0] JAL_target;

wire [5             :0] ALU_operation;
wire [1             :0] operand_A_sel;
wire                    operand_B_sel;
wire                    branch_op;
wire [DATA_WIDTH-1  :0] ALU_result;
wire [ADDRESS_BITS-1:0] JALR_target;
wire                    branch;

wire                    memRead;
wire                    memWrite;
wire [LOG2_NUM_BYTES-1:0] log2_bytes;
wire                    unsigned_load;
wire [ADDRESS_BITS-1:0] generated_address;
wire [DATA_WIDTH-1  :0] load_data;

wire                    regWrite;


assign generated_address   = ALU_result; //in case ADDRESS_BITS and DATA_WIDTH are different.
assign inst_PC             = fetch_address_in;


/*fetch issue*/
fetch_issue #(
  .CORE(CORE),
  .RESET_PC(RESET_PC),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) FI (
  .clock(clock),
  .reset(reset),
  .next_PC_select(next_PC_select),
  .target_PC(target_PC),
  .issue_PC(issue_PC),
  // instruction cache interface
  .i_mem_read_address(fetch_address_out),
  //scan signal
  .scan(scan)
);


/*fetch receive*/
fetch_receive #(
  .DATA_WIDTH(DATA_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) FR (
  .flush(flush_fetch_receive),
  .i_mem_data(fetch_data_in),
  .issue_PC(issue_PC),
  .instruction(instruction),
  //scan signal
  .scan(scan)
);


/*decode unit*/
decode_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) ID (
  .clock(clock),
  .reset(reset),

  .PC(inst_PC),
  .instruction(instruction),
  .extend_sel(extend_sel),
  .write(write),
  .write_reg(write_reg),
  .write_data(write_data),

  .rs1_data(rs1_data),
  .rs2_data(rs2_data),
  .rd(rd),
  .opcode(opcode),
  .funct7(funct7),
  .funct3(funct3),
  .extend_imm(extend_imm),
  .branch_target(branch_target),
  .JAL_target(JAL_target),
  //scan signal
  .scan(scan)
);


/*control unit*/
single_cycle_control_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) CTRL (
  // Control Unit Ports
  .clock(clock),
  .reset(reset),

  .opcode_decode(opcode),
  .opcode_execute(opcode),
  .funct7(funct7),
  .funct3(funct3),

  .JALR_target_execute(JALR_target),
  .branch_target_execute(branch_target),
  .JAL_target_decode(JAL_target),
  .branch_execute(branch),

  .branch_op(branch_op),
  .memRead(memRead),
  .ALU_operation(ALU_operation),
  .memWrite(memWrite),
  .log2_bytes(log2_bytes),
  .unsigned_load(unsigned_load),
  .next_PC_sel(next_PC_select),
  .operand_A_sel(operand_A_sel),
  .operand_B_sel(operand_B_sel),
  .extend_sel(extend_sel),
  .regWrite(regWrite),

  .target_PC(target_PC),
  .i_mem_read(fetch_read),

  // Hazard Detection Unit Ports
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .issue_PC(issue_PC),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  .load_address(generated_address),
  .memory_address_in(memory_address_in),

  .load_memory(memRead),
  .store_memory(memWrite),

  // Flush fetch receive
  .flush_fetch_receive(flush_fetch_receive),

  // Scan signal
  .scan(scan)
);


/*execute unit*/
execution_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) EX (
  .clock(clock),
  .reset(reset),
  .ALU_operation(ALU_operation),
  .PC(inst_PC),
  .operand_A_sel(operand_A_sel),
  .operand_B_sel(operand_B_sel),
  .branch_op(branch_op),
  .rs1_data(rs1_data),
  .rs2_data(rs2_data),
  .extend(extend_imm),

  .branch(branch),
  .ALU_result(ALU_result),
  .JALR_target(JALR_target),
  //scan signal
  .scan(scan)
);


/*memory issue*/
memory_issue #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) MI (
  .clock(clock),
  .reset(reset),

  // Execute stage interface
  .load(memRead),
  .store(memWrite),
  .address(generated_address),
  .store_data(rs2_data),
  .log2_bytes(log2_bytes),
  // Memory interface
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_byte_en(memory_byte_en),
  .memory_address(memory_address_out),
  .memory_data(memory_data_out),
  // scan signal
  .scan(scan)
);


/*memory receive*/
memory_receive #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) MR (
  .clock(clock),
  .reset(reset),

  .log2_bytes(log2_bytes),
  .unsigned_load(unsigned_load),
  // Memory interface
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  // Writeback interface
  .load_data(load_data),
  // scan signal
  .scan(scan)
);


/*writeback unit*/
writeback_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) WB (
  .clock(clock),
  .reset(reset),

  .opWrite(regWrite),
  .opSel(memRead),
  .opReg(rd),
  .ALU_result(ALU_result),
  .memory_data(load_data),
  //decode unit interface
  .write(write),
  .write_reg(write_reg),
  .write_data(write_data),
  //scan signal
  .scan(scan)
);

endmodule
