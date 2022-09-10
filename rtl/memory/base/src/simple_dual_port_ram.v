/** @module : simple_dual_port_ram
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


/**
* Module description
* ------------------
 *  - Dual port RAM without pass-through logic for cross-port read during
 *    write.
 *  - When both ports simultaneously write to the same address, port1 gets
 *    priority.
 */

module simple_dual_port_ram #(
parameter DATA_WIDTH    = 32,
          ADDRESS_WIDTH = 32,
          INDEX_BITS    =  8,
          PROGRAM       = ""
) (
input clock,
input writeEnable_0, writeEnable_1, // we0 made writeEnable_1 & we1 made writeEnable_2
input  [DATA_WIDTH-1:0]    writeData_0, // data_in0 => writeData_1
input  [DATA_WIDTH-1:0]    writeData_1, // data_in1 => writeData_2
input  [ADDRESS_WIDTH-1:0] address_0, // address0 => address_1
input  [ADDRESS_WIDTH-1:0] address_1, //address1 => address_2
output reg [DATA_WIDTH-1:0] readData_0, // data_out0 => readData_1
output reg [DATA_WIDTH-1:0] readData_1 // data_out1 => readData_2
);
	
localparam RAM_DEPTH = 1 << INDEX_BITS;
//localparam NUM_BYTES = DATA_WIDTH/8; // added to match dpBbe

reg [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];

wire port0_we;

assign port0_we = writeEnable_0 & ~(writeEnable_1 & (address_0 == address_1)); // If both ports
                                                         // attempt writing to
                                                         // the same address,
                                                         // port1 gets
                                                         // priority.

// port A
always@(posedge clock)begin
  if(port0_we) begin
    ram[address_0] <= writeData_0;
	  readData_0     <= writeData_0;
  end
  else begin
	  readData_0 <= ram[address_0];
  end
end

// port B
always@(posedge clock)begin
  if(writeEnable_1) begin
    ram[address_1]  <= writeData_1;
	  readData_1      <= writeData_1;
  end
  else begin
	  readData_1 <= ram[address_1];
  end
end

// Memory initialization only if parameter PROGRAM is a non empty string

initial begin
  if(PROGRAM != "")begin
    $readmemh(PROGRAM, ram);
  end
end

endmodule

