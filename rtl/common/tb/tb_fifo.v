/** @module : tb_fifo
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

module tb_fifo ();

parameter DATA_WIDTH = 32;
parameter Q_DEPTH_BITS = 3;
parameter Q_IN_BUFFERS = 0;

reg clk;
reg reset;
reg [31:0] write_data;
reg wrtEn;
reg rdEn;
reg peek;

wire [31:0] read_data;
wire full;
wire empty;
wire valid;
// wire [3:0] free_slots; // Not used in this version of the FIFO


fifo #(
  .DATA_WIDTH(DATA_WIDTH),
  .Q_DEPTH_BITS(Q_DEPTH_BITS),
  .Q_IN_BUFFERS(Q_IN_BUFFERS)
) uut (
  .clk(clk),
  .reset(reset),
  .write_data(write_data),
  .wrtEn(wrtEn),
  .rdEn(rdEn),
  .peek(peek),

  .read_data(read_data),
  .valid(valid),
  .full(full),
  .empty(empty)
);

// Clock generator
always #5 clk = ~clk;

initial begin
  clk = 1;
  reset = 1;
  write_data = 0;
  wrtEn = 0;
  rdEn = 0;
  peek = 0;
  repeat (10) @ (posedge clk);
  reset = 0;
  repeat (1) @ (posedge clk);

  rdEn 			<= 0;
  peek 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 100;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd100 |
      full       !== 1'b0   |
      empty      !== 1'b0   |
      valid      !== 1'b0   ) begin
      // free_slots !== 4'd7   ) begin
    $display("Error: Unexpected state after initial write 100!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  peek 			<= 1;
  wrtEn 		<= 0;
  write_data 	<= 101;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd100 |
      full       !== 1'b0   |
      empty      !== 1'b0   |
      valid      !== 1'b1   ) begin
      // free_slots !== 4'd7   ) begin
    $display("Error: Unexpected state after peak 100!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end


  rdEn 			<= 1;
  peek 			<= 0;
  wrtEn 		<= 0;
  write_data 	<= 101;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'hxxxxxxxx |
      full       !== 1'b0   |
      empty      !== 1'b1   |
      valid      !== 1'b0   ) begin
      // free_slots !== 4'd8   ) begin
    $display("Error: Unexpected state after read 100!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 0;
  write_data 	<= 5;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'hxxxxxxxx |
      full       !== 1'b0         |
      empty      !== 1'b1         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd8         ) begin
    $display("Error: Unexpected initial state!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end


  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 7;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'h00000007 |
      full       !== 1'b0         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd7         ) begin
    $display("Error: Unexpected state after writing 7!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end


  rdEn 			<= 1;
  wrtEn 		<= 0;
  write_data 	<= 22;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'hxxxxxxxx |
      full       !== 1'b0         |
      empty      !== 1'b1         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd8         ) begin
    $display("Error: Unexpected state after reading 7!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end


  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 51;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b0         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd7         ) begin
    $display("Error: Unexpected after writing 51!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 78;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b0         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd6         ) begin
    $display("Error: Unexpected after writing 78!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 39;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b0         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd5         ) begin
    $display("Error: Unexpected after writing 39!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 23;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51|
      full       !== 1'b0         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd4         ) begin
    $display("Error: Unexpected after writing 23!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 44;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b0         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd3         ) begin
    $display("Error: Unexpected after writing 44!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 19;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b0         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd2         ) begin
    $display("Error: Unexpected after writing 19!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 32;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b0         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd1         ) begin
    $display("Error: Unexpected after writing 32!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 88;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b1         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd0         ) begin
    $display("Error: Unexpected after writing 88!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 28;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b1         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd0         ) begin
    $display("Error: Unexpected after writing while full!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 72;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd51       |
      full       !== 1'b1         |
      empty      !== 1'b0         |
      valid      !== 1'b0         ) begin
      // free_slots !== 4'd0         ) begin
    $display("Error: Unexpected after writing while full!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 1;
  wrtEn 		<= 0;
  write_data 	<= 80;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd78 |
      full       !== 1'b0   |
      empty      !== 1'b0   |
      valid      !== 1'b1   ) begin
      // free_slots !== 4'd1   ) begin
    $display("Error: Unexpected after reading 51!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 0;
  write_data 	<= 77;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd78 |
      full       !== 1'b0   |
      empty      !== 1'b0   |
      valid      !== 1'b0   ) begin
      // free_slots !== 4'd1   ) begin
    $display("Error: Unexpected after idle cycle!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  wrtEn 		<= 0;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd78 |
      full       !== 1'b0   |
      empty      !== 1'b0   |
      valid      !== 1'b0   ) begin
      // free_slots !== 4'd1   ) begin
    $display("Error: Unexpected after idle cycle!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  peek 			<= 1;
  wrtEn 		<= 1;
  write_data 	<= 89;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd78 |
      full       !== 1'b1   |
      empty      !== 1'b0   |
      valid      !== 1'b1   ) begin
      // free_slots !== 4'd0   ) begin
    $display("Error: Unexpected after peak 78 & write 89!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 1;
  peek 			<= 0;
  wrtEn 		<= 1;
  write_data 	<= 17;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd39 |
      full       !== 1'b1   |
      empty      !== 1'b0   |
      valid      !== 1'b1   ) begin
      // free_slots !== 4'd0   ) begin
    $display("Error: Unexpected after read 78 & write 17!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  rdEn 			<= 0;
  peek 		  <= 1;
  wrtEn 		<= 0;
  write_data 	<= 77;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd39 |
      full       !== 1'b1   |
      empty      !== 1'b0   |
      valid      !== 1'b1   ) begin
      // free_slots !== 4'd0   ) begin
    $display("Error: Unexpected after peak 39 & write 77!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end


  rdEn 			<= 1;
  peek 		  <= 1;
  wrtEn 		<= 1;
  write_data 	<= 63;
  repeat (1) @ (posedge clk);
  #1
  if( read_data  !== 32'd23 |
      full       !== 1'b1   |
      empty      !== 1'b0   |
      valid      !== 1'b1   ) begin
      // free_slots !== 4'd0   ) begin
    $display("Error: Unexpected after read 39 & write 63!");
    $display("\ntb_fifo --> Test Failed!\n\n");
    $stop();
  end

  $display("\ntb_fifo --> Test Passed!\n\n");
  $stop();

end

/*
always @ (posedge clk) begin
    if(wrtEn) begin
    	$display ("Written Data        [%d] Current free_slots [%d] Full [%b] Empty [%b]", write_data, free_slots, full, empty);
	end
    if(valid) begin
    	$display ("Data read or peeked [%d] Current free_slots [%d] Full [%b] Empty [%b]", read_data, free_slots, full, empty);
	end
end
*/
endmodule
