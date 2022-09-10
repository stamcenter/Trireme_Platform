/** @module : mm_uart
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


module mm_uart #(
  parameter CLOCK_FREQUENCY = 100000000, // 100MHz
  parameter BAUD_RATE       = 115200,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 8,
  parameter RX_ADDR = 32'h90000010,
  parameter TX_ADDR = 32'h90000020,
  parameter RX_READY_ADDR = 32'h90000014,
  parameter TX_READY_ADDR = 32'h90000024,
  parameter UART_FIFO_SIZE = 1024
) (
  input clock,
  input reset,

  // UART Rx/Tx
  input uart_rx,
  output uart_tx,

  // Memory Mapped Port
  input  readEnable,
  input  writeEnable,
  input  [DATA_WIDTH/8-1:0] writeByteEnable,
  input  [ADDR_WIDTH-1:0] address,
  input  [DATA_WIDTH-1:0] writeData,
  output reg [DATA_WIDTH-1:0] readData

);

//define the log2 function
function integer log2;
  input integer num;
  integer i, result;
  begin
    for (i = 0; 2 ** i < num; i = i + 1)
      result = i + 1;
    log2 = result;
  end
endfunction


// Tx FIFO
wire tx_fifo_wr_en;
//wire tx_fifo_rd_en;
reg tx_fifo_rd_en;

wire [7:0] tx_fifo_read_data;
wire tx_fifo_valid;
wire tx_fifo_full;
wire tx_fifo_empty;

// Rx Show-Ahead FIFO
wire [7:0] rx_fifo_write_data;
wire rx_fifo_wr_en;
wire rx_fifo_rd_en;

wire [7:0] rx_fifo_read_data;
wire rx_fifo_valid;
wire rx_fifo_full;
wire rx_fifo_empty;

// UART Tx
wire tx_busy;

assign tx_fifo_wr_en = (address == TX_ADDR) & writeEnable & writeByteEnable[0];
assign rx_fifo_rd_en = (address == RX_ADDR) & readEnable;

always@(posedge clock) begin
  if(reset) begin
    readData <= {DATA_WIDTH{1'b0}};
  end
  else if(writeEnable) begin
    readData <= {DATA_WIDTH{1'b0}};
  end
  else if(readEnable) begin
    readData <= (address == TX_READY_ADDR) ? {{DATA_WIDTH-1{1'b0}}, ~tx_fifo_full}  :
                (address == RX_READY_ADDR) ? {{DATA_WIDTH-1{1'b0}}, ~rx_fifo_empty} :
                (address == RX_ADDR      ) & rx_fifo_valid ? {{DATA_WIDTH-9{1'b0}}, rx_fifo_valid, rx_fifo_read_data[7:0]} :
                {DATA_WIDTH{1'b0}};
  end
  else begin
    readData <= {DATA_WIDTH{1'b0}};
  end
end


always@(posedge clock) begin
  if(reset) begin
    tx_fifo_rd_en <= 1'b0;
  end
  else if(tx_fifo_rd_en) begin
    // Do not read two cycles in a row
    tx_fifo_rd_en <= 1'b0;
  end
  else begin
    tx_fifo_rd_en <= ~tx_fifo_empty & ~tx_busy;
  end
end


fifo #(
  .DATA_WIDTH(8),
  .Q_DEPTH_BITS(log2(UART_FIFO_SIZE)),
  .Q_IN_BUFFERS(0)
) TX_FIFO (
  .clk(clock),
  .reset(reset),
  .write_data(writeData[7:0]),
  .wrtEn(tx_fifo_wr_en),
  .rdEn(tx_fifo_rd_en),
  .peek(1'b0),

  .read_data(tx_fifo_read_data),
  .valid(tx_fifo_valid),
  .full(tx_fifo_full),
  .empty(tx_fifo_empty)
);

fifo #(
  .DATA_WIDTH(8),
  .Q_DEPTH_BITS(log2(UART_FIFO_SIZE)),
  .Q_IN_BUFFERS(0)
) RX_FIFO (
  .clk(clock),
  .reset(reset),
  .write_data(rx_fifo_write_data),
  .wrtEn(rx_fifo_wr_en),
  .rdEn(rx_fifo_rd_en),
  .peek(1'b0),

  .read_data(rx_fifo_read_data),
  .valid(rx_fifo_valid), // Unused
  .full(rx_fifo_full), // Unused
  .empty(rx_fifo_empty)
);

uart_rx #(
  .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
  .BAUD_RATE(BAUD_RATE)
) RX (
  .clock(clock),
  .reset(reset),

  .serial_rx(uart_rx),
  .rx_valid(rx_fifo_wr_en),
  .rx_data(rx_fifo_write_data)
);

uart_tx #(
  .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
  .BAUD_RATE(BAUD_RATE)
) TX (
  .clock(clock),
  .reset(reset),
  .tx_valid(tx_fifo_valid),
  .tx_data_in(tx_fifo_read_data),
  .serial_tx(uart_tx),
  .tx_busy(tx_busy)
);


always@(posedge clock) begin
  if(writeEnable) begin
    $write("%s", writeData[7:0]);
  end
end

endmodule
