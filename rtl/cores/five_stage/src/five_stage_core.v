/** @module : five_stage_core
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

module five_stage_core #(
  parameter CORE            = 0,
  parameter RESET_PC        = 0,
  parameter DATA_WIDTH      = 32,
  parameter ADDRESS_BITS    = 32,
  parameter NUM_BYTES       = DATA_WIDTH/8,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input  clock,
  input  reset,
  input  start,
  input  [ADDRESS_BITS-1:0] program_address,
  //memory interface
  input  fetch_valid,
  input  fetch_ready,
  input  [DATA_WIDTH-1  :0] fetch_data_in,
  input  [ADDRESS_BITS-1:0] fetch_address_in,
  input  memory_valid,
  input  memory_ready,
  input  [DATA_WIDTH-1  :0] memory_data_in,
  input  [ADDRESS_BITS-1:0] memory_address_in,
  output fetch_read,
  output [ADDRESS_BITS-1:0] fetch_address_out,
  output memory_read,
  output memory_write,
  output [NUM_BYTES-1:   0] memory_byte_en,
  output [ADDRESS_BITS-1:0] memory_address_out,
  output [DATA_WIDTH-1  :0] memory_data_out,
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


// Pipe Parameters
localparam DECODE_PIPE_WIDTH = DATA_WIDTH // instruction
                            + ADDRESS_BITS; // inst_pc


localparam EXECUTE_PIPE_WIDTH = ADDRESS_BITS  // inst_PC
                             + DATA_WIDTH     // rs1_data
                             + DATA_WIDTH     // rs2_data
                             + 5              // rd
                             + DATA_WIDTH     // extend_imm
                             + ADDRESS_BITS   // branch_target
                             + 1              // branch_op
                             + 1              // memRead
                             + 6              // ALU_operation
                             + 1              // memWrite
                             + LOG2_NUM_BYTES // log2_bytes
                             + 1              // unsigned_load
                             + 2              // operand_A_sel
                             + 1              // operand_B_sel
                             + 1              // regWrite
                             + 7;             // opcode

localparam MEMORY_PIPE_WIDTH = 1              // load // memRead,
                             + 1              // store // memWrite,
                             + LOG2_NUM_BYTES // log2_bytes
                             + 1              // unsigned_load
                             + ADDRESS_BITS   // generated_address,
                             + DATA_WIDTH     // rs2_data
                             + 1              // regWrite_memory,
                             + 5              // rd_memory,
                             + DATA_WIDTH     // ALU_result_memory,
                             + 7;             // opcode

localparam WRITEBACK_PIPE_WIDTH = 1           // regWrite_writeback
                               + 1           // memRead_writeback
                               + 5           // rd_writeback
                               + DATA_WIDTH  // ALU_result_writeback
                               + DATA_WIDTH; // load_data_writeback



// Fetch Stage Wires
wire [DATA_WIDTH-1:0] instruction_fetch;
wire [ADDRESS_BITS-1:0] inst_PC_fetch;
wire [1:0] next_PC_select;
wire [ADDRESS_BITS-1:0] target_PC;
wire [ADDRESS_BITS-1:0] issue_PC;


// Decode Stage Wires
wire [DATA_WIDTH-1:0] instruction_decode;
wire [ADDRESS_BITS-1:0] inst_PC_decode;
wire [1:0] extend_sel_decode;
wire [DATA_WIDTH-1:0] rs1_data_decode;
wire [DATA_WIDTH-1:0] rs2_data_decode;
wire [4:0] rd_decode;
wire [6:0] opcode_decode;
wire [6:0] funct7_decode;
wire [2:0] funct3_decode;
wire [DATA_WIDTH-1:0] extend_imm_decode;
wire [ADDRESS_BITS-1:0] branch_target_decode;
wire [ADDRESS_BITS-1:0] JAL_target_decode;

wire branch_op_decode;
wire memRead_decode;
wire [5:0] ALU_operation_decode;
wire memWrite_decode;
wire [LOG2_NUM_BYTES-1:0] log2_bytes_decode;
wire unsigned_load_decode;

//wire [1:0] next_PC_select_decode;
wire [1:0] operand_A_sel_decode;
wire operand_B_sel_decode;
wire regWrite_decode;

wire stall_decode;
wire stall_execute;
wire stall_memory;
wire flush_decode;
wire flush_execute;
wire flush_writeback;

wire [1:0] rs1_data_bypass;
wire [1:0] rs2_data_bypass;

// Execute Stage Wires
wire memRead_execute;
wire [5:0] ALU_operation_execute;
wire memWrite_execute;
wire [LOG2_NUM_BYTES-1:0] log2_bytes_execute;
wire unsigned_load_execute;
wire [ADDRESS_BITS-1:0] inst_PC_execute;
wire [1:0] operand_A_sel_execute;
wire operand_B_sel_execute;
wire regWrite_execute;

wire branch_op_execute;
wire [DATA_WIDTH-1:0] rs1_data_execute;
wire [DATA_WIDTH-1:0] rs2_data_execute;
wire [DATA_WIDTH-1:0] extend_imm_execute;

wire branch_execute;
wire [DATA_WIDTH-1:0] ALU_result_execute;
wire [ADDRESS_BITS-1:0] JALR_target_execute;

wire [ADDRESS_BITS-1:0] branch_target_execute;

wire [4:0] rd_execute;
wire [6:0] opcode_execute;
wire [DATA_WIDTH-1:0] instruction_execute;

// Memory Stage Wires
wire memRead_memory;
wire regWrite_memory;
wire memWrite_memory;
wire [LOG2_NUM_BYTES-1:0] log2_bytes_memory;
wire unsigned_load_memory;


wire [ADDRESS_BITS-1:0] generated_address_memory;
wire [DATA_WIDTH-1:0] rs2_data_memory;
wire [DATA_WIDTH-1:0] load_data_memory;
wire [DATA_WIDTH-1:0] ALU_result_memory;

wire [4:0] rd_memory;
wire [6:0] opcode_memory;
wire [DATA_WIDTH-1:0] instruction_memory;

// Writeback Stage Wires
wire regWrite_writeback;
wire memRead_writeback;
wire [4:0] rd_writeback;
wire [DATA_WIDTH-1:0] ALU_result_writeback;
wire [DATA_WIDTH-1:0] load_data_writeback;

wire write_writeback;
wire [4:0] write_reg_writeback;
wire [DATA_WIDTH-1:0] write_data_writeback;
wire [DATA_WIDTH-1:0] instruction_writeback;

// Pipe Wires
wire [DECODE_PIPE_WIDTH-1:0] decode_pipe_input;
wire [DECODE_PIPE_WIDTH-1:0] decode_pipe_flush;
wire [DECODE_PIPE_WIDTH-1:0] decode_pipe_output;

wire [EXECUTE_PIPE_WIDTH-1:0] execute_pipe_input;
wire [EXECUTE_PIPE_WIDTH-1:0] execute_pipe_flush;
wire [EXECUTE_PIPE_WIDTH-1:0] execute_pipe_output;

wire [MEMORY_PIPE_WIDTH-1:0] memory_pipe_input;
wire [MEMORY_PIPE_WIDTH-1:0] memory_pipe_flush;
wire [MEMORY_PIPE_WIDTH-1:0] memory_pipe_output;

wire [WRITEBACK_PIPE_WIDTH-1:0] writeback_pipe_input;
wire [WRITEBACK_PIPE_WIDTH-1:0] writeback_pipe_flush;
wire [WRITEBACK_PIPE_WIDTH-1:0] writeback_pipe_output;

wire [ADDRESS_BITS-1:0] generated_address_execute;



assign generated_address_execute = ALU_result_execute; //in case ADDRESS_BITS and DATA_WIDTH are different.


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


/* No fetch receive*/
assign instruction_fetch = fetch_data_in;
assign inst_PC_fetch     = fetch_address_in;


assign decode_pipe_input = { instruction_fetch,
                             inst_PC_fetch
                           };

assign decode_pipe_flush = { 32'h00000013,
                             {ADDRESS_BITS{1'b0}}
                           };

assign { instruction_decode,
         inst_PC_decode } = decode_pipe_output;

pipeline_register #(
  .PIPELINE_STAGE("Decode Pipe"),
  .PIPE_WIDTH(DECODE_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) decode_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_decode),
  .flush(flush_decode),
  .pipe_input(decode_pipe_input),
  .flush_input(decode_pipe_flush),
  .pipe_output(decode_pipe_output),
  //scan signal
  .scan(scan)
);


/*decode unit*/
five_stage_decode_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) ID (
  .clock(clock),
  .reset(reset),

  .PC(inst_PC_decode),
  .instruction(instruction_decode),
  .extend_sel(extend_sel_decode),
  .write(write_writeback),
  .write_reg(write_reg_writeback),
  .write_data(write_data_writeback),

  .rs1_data(rs1_data_decode),
  .rs2_data(rs2_data_decode),
  .rd(rd_decode),
  .opcode(opcode_decode),
  .funct7(funct7_decode),
  .funct3(funct3_decode),
  .extend_imm(extend_imm_decode),
  .branch_target(branch_target_decode),
  .JAL_target(JAL_target_decode),

  // Data Bypassing Signals
  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),
  .ALU_result_execute(ALU_result_execute),
  .ALU_result_memory(ALU_result_memory),
  //.ALU_result_writeback(ALU_result_writeback),
  .ALU_result_writeback(write_data_writeback), // TODO: rename bypass signals

  //scan signal
  .scan(scan)
);




/*control unit*/
five_stage_control_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .NUM_BYTES(NUM_BYTES),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) CTRL (
  // Base Control Unit Ports
  .clock(clock),
  .reset(reset),
  .opcode_decode(opcode_decode),
  .opcode_execute(opcode_execute),
  .funct3(funct3_decode),
  .funct7(funct7_decode),

  .JALR_target_execute(JALR_target_execute),
  .branch_target_execute(branch_target_execute),
  .JAL_target_decode(JAL_target_decode),
  .branch_execute(branch_execute),

  .branch_op(branch_op_decode),
  .memRead(memRead_decode),
  .ALU_operation(ALU_operation_decode),
  .memWrite(memWrite_decode),
  .log2_bytes(log2_bytes_decode),
  .unsigned_load(unsigned_load_decode),
  .next_PC_sel(next_PC_select),
  .operand_A_sel(operand_A_sel_decode),
  .operand_B_sel(operand_B_sel_decode),
  .extend_sel(extend_sel_decode),
  .regWrite(regWrite_decode),

  .target_PC(target_PC),
  .i_mem_read(fetch_read),

  // Base Hazard Detection Unit Ports
  .fetch_valid(fetch_valid),
  .fetch_ready(fetch_ready),
  .issue_PC(issue_PC),
  .fetch_address_in(fetch_address_in),
  .memory_valid(memory_valid),
  .memory_ready(memory_ready),
  .load_memory(memRead_memory),
  .store_memory(memWrite_memory),
  .load_address(generated_address_memory),
  .memory_address_in(memory_address_in),

  // Five Stage Stall Unit Ports
  .stall_decode(stall_decode),
  .stall_execute(stall_execute),
  .stall_memory(stall_memory),

  .flush_decode(flush_decode),
  .flush_execute(flush_execute),
  .flush_writeback(flush_writeback),

  // Five Stage Bypass Unit Ports
  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),

  // New Ports
  .opcode_memory(opcode_memory),
  .rs1(instruction_decode[19:15]), // Slice instruction here to avoid adding output to base decode
  .rs2(instruction_decode[24:20]),
  .rd_execute(rd_execute),
  .rd_memory(rd_memory),
  .rd_writeback(rd_writeback),
  .regWrite_execute(regWrite_execute),
  .regWrite_memory(regWrite_memory),
  .regWrite_writeback(regWrite_writeback),

  .scan(scan)
);



assign execute_pipe_input = { inst_PC_decode,
                              rs1_data_decode,
                              rs2_data_decode,
                              rd_decode,
                              extend_imm_decode,
                              branch_target_decode,
                              branch_op_decode,
                              memRead_decode,
                              ALU_operation_decode,
                              memWrite_decode,
                              log2_bytes_decode,
                              unsigned_load_decode,
                              operand_A_sel_decode,
                              operand_B_sel_decode,
                              regWrite_decode,
                              opcode_decode
                            };

assign execute_pipe_flush = { {ADDRESS_BITS{1'b0}},   // inst_PC
                              {DATA_WIDTH{1'b0}},     // rs1_data,
                              {DATA_WIDTH{1'b0}},     // rs2_data,
                              5'b00000,               // rd,
                              {DATA_WIDTH{1'b0}},     // extend_imm,
                              {ADDRESS_BITS{1'b0}},   // branch_target,
                              1'b0,                   // branch_op,
                              1'b0,                   // memRead,
                              6'b000000,              // ALU_operation,
                              1'b0,                   // memWrite,
                              {LOG2_NUM_BYTES{1'b0}}, // log2_bytes,
                              1'b0,                   // unsigned_load,
                              2'b00,                  // operand_A_sel,
                              1'b0,                   // operand_B_sel,
                              1'b0,                   // regWrite
                              7'b0110011              // opcode
                            };

assign { inst_PC_execute,
         rs1_data_execute,
         rs2_data_execute,
         rd_execute,
         extend_imm_execute,
         branch_target_execute,
         branch_op_execute,
         memRead_execute,
         ALU_operation_execute,
         memWrite_execute,
         log2_bytes_execute,
         unsigned_load_execute,
         operand_A_sel_execute,
         operand_B_sel_execute,
         regWrite_execute,
         opcode_execute
       } = execute_pipe_output;




pipeline_register #(
  .PIPELINE_STAGE("Execute Pipe"),
  .PIPE_WIDTH(EXECUTE_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) execute_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_execute),
  .flush(flush_execute),
  .pipe_input(execute_pipe_input),
  .flush_input(execute_pipe_flush),
  .pipe_output(execute_pipe_output),
  //scan signal
  .scan(scan)
);


pipeline_register #(
  .PIPELINE_STAGE("Instruction Execute Pipe"),
  .PIPE_WIDTH(DATA_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) instruction_execute_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_execute),
  .flush(flush_execute),
  .pipe_input(instruction_decode),
  .flush_input(32'h00000013),
  .pipe_output(instruction_execute),
  //scan signal
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
  .ALU_operation(ALU_operation_execute),
  .PC(inst_PC_execute),
  .operand_A_sel(operand_A_sel_execute),
  .operand_B_sel(operand_B_sel_execute),
  .branch_op(branch_op_execute),
  .rs1_data(rs1_data_execute),
  .rs2_data(rs2_data_execute),
  .extend(extend_imm_execute),

  .branch(branch_execute),
  .ALU_result(ALU_result_execute),
  .JALR_target(JALR_target_execute),
  //scan signal
  .scan(scan)
);


assign memory_pipe_input = { memRead_execute,
                             memWrite_execute,
                             log2_bytes_execute,
                             unsigned_load_execute,
                             generated_address_execute,
                             rs2_data_execute,
                             regWrite_execute,
                             rd_execute,
                             ALU_result_execute,
                             opcode_execute
                           };

assign memory_pipe_flush = { 1'b0,                   // memRead_execute,
                             1'b0,                   // memWrite_execute,
                             {LOG2_NUM_BYTES{1'b0}}, // log2_bytes_execute,
                             1'b0,                   // unsigned_load_execute,
                             {ADDRESS_BITS{1'b0}},   // generated_address_execute,
                             {DATA_WIDTH{1'b0}},     // rs2_data_execute,
                             1'b0,                   // regWrite_execute,
                             5'b00000,               // rd_execute,
                             {DATA_WIDTH{1'b0}},     // ALU_result_execute,
                             7'b0110011              // opcode
                           };

assign { memRead_memory,
         memWrite_memory,
         log2_bytes_memory,
         unsigned_load_memory,
         generated_address_memory,
         rs2_data_memory,
         regWrite_memory,
         rd_memory,
         ALU_result_memory,
         opcode_memory
       } = memory_pipe_output;

pipeline_register #(
  .PIPELINE_STAGE("Memory Pipe"),
  .PIPE_WIDTH(MEMORY_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) memory_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_memory),
  .flush(1'b0),
  .pipe_input(memory_pipe_input),
  .flush_input(memory_pipe_flush),
  .pipe_output(memory_pipe_output),
  //scan signal
  .scan(scan)
);

pipeline_register #(
  .PIPELINE_STAGE("Instruction Memory Pipe"),
  .PIPE_WIDTH(DATA_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) instruction_memory_pipe (
  .clock(clock),
  .reset(reset),
  .stall(stall_memory),
  .flush(1'b0),
  .pipe_input(instruction_execute),
  .flush_input(32'h00000013),
  .pipe_output(instruction_memory),
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
  .load(memRead_memory),
  .store(memWrite_memory),
  .address(generated_address_memory),
  .store_data(rs2_data_memory),
  .log2_bytes(log2_bytes_memory),
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

  .log2_bytes(log2_bytes_memory),
  .unsigned_load(unsigned_load_memory),

  // Memory interface
  .memory_data_in(memory_data_in),
  .memory_address_in(memory_address_in),
  // Writeback interface
  .load_data(load_data_memory),
  // scan signal
  .scan(scan)
);

assign writeback_pipe_input = { regWrite_memory,
                                memRead_memory,
                                rd_memory,
                                ALU_result_memory,
                                load_data_memory
                              };

assign writeback_pipe_flush = { 1'b0,              // opWrite_writeback
                                1'b0,              // opSel_writeback
                                5'd0,              // opReg_writeback
                                {DATA_WIDTH{1'b0}}, // ALU_result_writeback
                                {DATA_WIDTH{1'b0}}  // load_data_writeback
                              };

assign { regWrite_writeback,
         memRead_writeback,
         rd_writeback,
         ALU_result_writeback,
         load_data_writeback
         } = writeback_pipe_output;

pipeline_register #(
  .PIPELINE_STAGE("Writeback Pipe"),
  .PIPE_WIDTH(WRITEBACK_PIPE_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) writeback_pipe (
  .clock(clock),
  .reset(reset),
  .stall(1'b0),
  .flush(flush_writeback),
  .pipe_input(writeback_pipe_input),
  .flush_input(writeback_pipe_flush),
  .pipe_output(writeback_pipe_output),
  //scan signal
  .scan(scan)
);


pipeline_register #(
  .PIPELINE_STAGE("Instruction Writeback Pipe"),
  .PIPE_WIDTH(DATA_WIDTH),
  .SCAN_CYCLES_MIN(SCAN_CYCLES_MIN),
  .SCAN_CYCLES_MAX(SCAN_CYCLES_MAX)
) instruction_writeback_pipe (
  .clock(clock),
  .reset(reset),
  .stall(1'b0),
  .flush(flush_writeback),
  .pipe_input(instruction_memory),
  .flush_input(32'h00000013),
  .pipe_output(instruction_writeback),
  //scan signal
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

  .opWrite(regWrite_writeback),
  .opSel(memRead_writeback),
  .opReg(rd_writeback),
  .ALU_result(ALU_result_writeback),
  .memory_data(load_data_writeback),
  //decode unit interface
  .write(write_writeback),
  .write_reg(write_reg_writeback),
  .write_data(write_data_writeback),
  //scan signal
  .scan(scan)
);

endmodule
