/** @module : dual_port_RAM
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
 *  - Dual port RAM with pass-through logic.
 *  - When one port reads the address written by the other port, RW parameter
 *    determines whether the new data or old data is read.
 *  Sub modules:
 *    - simple_dual_port_ram
 *  Parameters:
 *    - RW: Select whether "OLD_DATA" or "NEW_DATA" is returned when one port
 *      is reading the same address written to by the other port.
 */
 
module dual_port_RAM #(
parameter DATA_WIDTH    = 32,
          ADDRESS_WIDTH = 32,
          INDEX_BITS    = 8,
          RW            = "NEW_DATA"
) (
input clock,
input writeEnable_0, writeEnable_1, // we0 => writeEnable_1 & we1 => writeEnable_2
input  [DATA_WIDTH-1:0]    writeData_0, //data_in0 => writeData_1
input  [DATA_WIDTH-1:0]    writeData_1, //data_in1 => writeData_2
input  [ADDRESS_WIDTH-1:0] address_0, //address0 => address_1
input  [ADDRESS_WIDTH-1:0] address_1, //address1 => address_2
output [DATA_WIDTH-1:0]   readData_0, // data_out0 => readData_1
output [DATA_WIDTH-1:0]   readData_1 // data_out1 => readData_2
);

reg r_we0, r_we1; 
reg [INDEX_BITS-1:0] r_address0, r_address1;

wire [DATA_WIDTH-1:0] t_data_out0, t_data_out1;

always @(posedge clock)begin
  r_address0 <= address_0[INDEX_BITS-1:0];
  r_address1 <= address_1[INDEX_BITS-1:0];
  r_we0      <= writeEnable_0 & ~(writeEnable_1 & (address_0 == address_1));
  r_we1      <= writeEnable_1;
end

// instantiate basic dual port RAM
simple_dual_port_ram #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_WIDTH),
  .INDEX_BITS(INDEX_BITS)
) RAM (
  .clock(clock),
  .writeEnable_0(writeEnable_0), 
  .writeEnable_1(writeEnable_1),
  .writeData_0(writeData_0), 
  .writeData_1(writeData_1), 
  .address_0(address_0),
  .address_1(address_1),
  .readData_0(t_data_out0),
  .readData_1(t_data_out1)
);

// pass through logic
assign readData_0 = r_we1 & (r_address1 == r_address0) & (RW == "NEW_DATA") ?
                   t_data_out1 : t_data_out0;
assign readData_1 = r_we0 & (r_address0 == r_address1) & (RW == "NEW_DATA") ?
                   t_data_out0 : t_data_out1;

endmodule
