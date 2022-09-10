/** @module : uart_rx
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

module uart_rx #(
  parameter CLOCK_FREQUENCY = 100000000, // 100MHz
  parameter BAUD_RATE       = 115200
) (
  input clock,
  input reset,

  input serial_rx,
  output reg rx_valid,
  output reg [7:0] rx_data
);

localparam CLOCKS_PER_BIT = CLOCK_FREQUENCY/BAUD_RATE;

localparam IDLE      = 4'd0;
localparam START_BIT = 4'd1;
localparam DATA_BIT0 = 4'd2;
localparam DATA_BIT1 = 4'd3;
localparam DATA_BIT2 = 4'd4;
localparam DATA_BIT3 = 4'd5;
localparam DATA_BIT4 = 4'd6;
localparam DATA_BIT5 = 4'd7;
localparam DATA_BIT6 = 4'd8;
localparam DATA_BIT7 = 4'd9;
localparam STOP_BIT  = 4'd10;

reg [3:0] state;
reg [15:0] count;

reg serial_rx_r1;
reg serial_rx_r2;

// Double register serial input to avoid meta-stability problems
always@(posedge clock) begin
  if(reset) begin
    serial_rx_r1 <= 1'b1;
    serial_rx_r2 <= 1'b1;
  end
  else begin
    serial_rx_r1 <= serial_rx;
    serial_rx_r2 <= serial_rx_r1;
  end
end

// State machine to receive data
always@(posedge clock) begin
  if(reset) begin
    state    <= IDLE;
    count    <= 16'd0;
    rx_data  <= 8'd0;
    rx_valid <= 1'b0;
  end
  else begin
    case(state)
      IDLE: begin
        state    <= serial_rx_r2 ? IDLE : START_BIT;
        count    <= 16'd0;
        rx_data  <= 8'd0;
        rx_valid <= 1'b0;
      end
      START_BIT: begin
        if(count == (CLOCKS_PER_BIT-1)/2) begin
          state <= serial_rx_r2 ? IDLE : DATA_BIT0;
          count <= 16'd0;
        end
        else begin
          count <= count + 16'd1;
          state <= START_BIT;
        end
      end
      DATA_BIT0: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state <= DATA_BIT1;
          count <= 16'd0;
          rx_data <= {serial_rx_r2, rx_data[7:1]};
        end
        else begin
          count   <= count + 16'd1;
          state   <= DATA_BIT0;
          rx_data <= rx_data;
        end
      end
      DATA_BIT1: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state <= DATA_BIT2;
          count <= 16'd0;
          rx_data <= {serial_rx_r2, rx_data[7:1]};
        end
        else begin
          count   <= count + 16'd1;
          state   <= DATA_BIT1;
          rx_data <= rx_data;
        end
      end
      DATA_BIT2: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state <= DATA_BIT3;
          count <= 16'd0;
          rx_data <= {serial_rx_r2, rx_data[7:1]};
        end
        else begin
          count   <= count + 16'd1;
          state   <= DATA_BIT2;
          rx_data <= rx_data;
        end
      end
      DATA_BIT3: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state <= DATA_BIT4;
          count <= 16'd0;
          rx_data <= {serial_rx_r2, rx_data[7:1]};
        end
        else begin
          count   <= count + 16'd1;
          state   <= DATA_BIT3;
          rx_data <= rx_data;
        end
      end
      DATA_BIT4: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state <= DATA_BIT5;
          count <= 16'd0;
          rx_data <= {serial_rx_r2, rx_data[7:1]};
        end
        else begin
          count   <= count + 16'd1;
          state   <= DATA_BIT4;
          rx_data <= rx_data;
        end
      end
      DATA_BIT5: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state <= DATA_BIT6;
          count <= 16'd0;
          rx_data <= {serial_rx_r2, rx_data[7:1]};
        end
        else begin
          count   <= count + 16'd1;
          state   <= DATA_BIT5;
          rx_data <= rx_data;
        end
      end
      DATA_BIT6: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state <= DATA_BIT7;
          count <= 16'd0;
          rx_data <= {serial_rx_r2, rx_data[7:1]};
        end
        else begin
          count   <= count + 16'd1;
          state   <= DATA_BIT6;
          rx_data <= rx_data;
        end
      end
      DATA_BIT7: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state <= STOP_BIT;
          count <= 16'd0;
          rx_data <= {serial_rx_r2, rx_data[7:1]};
        end
        else begin
          count   <= count + 16'd1;
          state   <= DATA_BIT7;
          rx_data <= rx_data;
        end
      end
      STOP_BIT: begin
        if(count == CLOCKS_PER_BIT-1) begin
          state    <= IDLE;
          count    <= 16'd0;
          rx_valid <= serial_rx_r2;
        end
        else begin
          count    <= count + 16'd1;
          state    <= STOP_BIT;
          rx_valid <= 1'b0;
        end
      end
      default: begin
        state <= state;
      end
    endcase
  end
end

endmodule
