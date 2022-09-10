/** @module : fifo
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

// You can write and read the same data from the fifo during the same
// clock cycle.

module fifo #(
  parameter DATA_WIDTH   = 32,
  parameter Q_DEPTH_BITS = 3,
  parameter Q_IN_BUFFERS = 2
) (
  input clk,
  input reset,
  input [DATA_WIDTH-1:0] write_data,
  input wrtEn,
  input rdEn,
  input peek,

  output [DATA_WIDTH-1:0] read_data,
  output valid,
  output full,
  output empty
);

localparam Q_DEPTH    = 1 << Q_DEPTH_BITS;
localparam BUFF_DEPTH = Q_DEPTH - Q_IN_BUFFERS;

reg  [Q_DEPTH_BITS-1:0]   front;
reg  [Q_DEPTH_BITS-1:0]   rear;
reg  [DATA_WIDTH - 1: 0]  queue [0:Q_DEPTH-1];
reg  [Q_DEPTH_BITS:0]     current_size;
wire bare   = (current_size == 0);
wire filled = (current_size == Q_DEPTH);
integer i;

//--------------Code Starts Here-----------------------
always @ (posedge clk) begin
  if (reset) begin
    front        <= 0;
    rear         <= 0;
    current_size <= 0;
  end
  else  begin
    if(bare & wrtEn & rdEn) begin
      queue [rear]  <= queue [rear];
      rear          <= rear;
      front         <= front;
      current_size  <= 0;
    end
    else begin
      queue [rear]  <= (wrtEn & ~filled)? write_data : queue [rear];
      rear          <= (wrtEn & ~filled)? (rear == (Q_DEPTH -1))? 0 :
               (rear + 1) : rear;
      front         <= (rdEn & ~bare)? (front == (Q_DEPTH -1))? 0 :
               (front + 1) : front;
      current_size  <= (wrtEn & ~rdEn & ~filled)? (current_size + 1) :
               (~wrtEn & rdEn & ~bare)?
               (current_size -1): current_size;
    end

    if (wrtEn & filled) begin
         $display ("ERROR: Trying to enqueue data: %h  on a full Q!",  write_data);
         $display ("INFO:  Q depth %d and current Q size %d",Q_DEPTH, current_size);
     $display ("INFO:  Current head %d and current rear %d",front, rear);
     // For large FIFOs (>5000 words) quartus won't synthesize this because
     // the loop is too large.
     //for (i = 0; i < Q_DEPTH; i=i+1) begin
     // $display ("INFO: Index [%d] data [%h]",i, queue[i]);
     //end
    end
    //if (rdEn & bare & ~wrtEn) $display ("Warning: Trying to dequeue an empty Q!");
    //if (peek & bare & ~wrtEn) $display ("Warning: Peeking at an empty Q!");
  end
end

//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
assign  read_data   = (wrtEn & (rdEn|peek) & bare)? write_data : queue [front];
assign  valid       = (((wrtEn & (rdEn|peek) & bare) | ((rdEn|peek) & ~bare))& ~reset)? 1 : 0;
assign  full        = (~reset & (filled | (current_size >= BUFF_DEPTH)));
assign  empty       = (reset | bare |(~wrtEn & rdEn & (current_size == 1)));

endmodule
