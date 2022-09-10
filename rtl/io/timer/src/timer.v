/*  @module : timer
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
module timer #(
  parameter DATA_WIDTH   = 32,
  parameter ADDRESS_BITS = 32,
  parameter MTIME_ADDR      = 32'h0020bff8,
  parameter MTIME_ADDR_H    = 32'h0020bffC,
  parameter MTIMECMP_ADDR   = 32'h00204000,
  parameter MTIMECMP_ADDR_H = 32'h00204004
) (
  input clock,
  input reset,

  input  readEnable,
  input  writeEnable,
  input [DATA_WIDTH/8-1:0] writeByteEnable,
  input  [ADDRESS_BITS-1:0] address,
  input  [DATA_WIDTH-1:0] writeData,
  output reg [DATA_WIDTH-1:0] readData,

  output timer_interrupt
);


reg [63:0] mtime;
reg [63:0] mtimecmp;

assign timer_interrupt = mtime >= mtimecmp;

generate
  if(DATA_WIDTH == 32) begin

    // RV32 MTIME Write Logic
    always@(posedge clock) begin
      if(reset) begin
        mtime    <= 64'd0;
      end
      else if(writeEnable && address == MTIME_ADDR) begin
        mtime[ 7: 0] <= writeByteEnable[0] ? writeData[ 7: 0] : mtime[ 7: 0];
        mtime[15: 8] <= writeByteEnable[1] ? writeData[15: 8] : mtime[15: 8];
        mtime[23:16] <= writeByteEnable[2] ? writeData[23:16] : mtime[23:16];
        mtime[31:24] <= writeByteEnable[3] ? writeData[31:24] : mtime[31:24];
      end
      else if(writeEnable && address == MTIME_ADDR_H) begin
        mtime[39:32] <= writeByteEnable[0] ? writeData[ 7: 0] : mtime[39:32];
        mtime[47:40] <= writeByteEnable[1] ? writeData[15: 8] : mtime[47:40];
        mtime[55:48] <= writeByteEnable[2] ? writeData[23:16] : mtime[55:48];
        mtime[63:56] <= writeByteEnable[3] ? writeData[31:24] : mtime[63:56];
      end
      else begin
        mtime <= mtime + 64'd1;
      end
    end

    // RV32 MTIMECMP Write Logic
    always@(posedge clock) begin
      if(reset) begin
        mtimecmp <= 64'hffffffff_ffffffff;
      end
      else if(writeEnable && address == MTIMECMP_ADDR) begin
        mtimecmp[ 7: 0] <= writeByteEnable[0] ? writeData[ 7: 0] : mtimecmp[ 7: 0];
        mtimecmp[15: 8] <= writeByteEnable[1] ? writeData[15: 8] : mtimecmp[15: 8];
        mtimecmp[23:16] <= writeByteEnable[2] ? writeData[23:16] : mtimecmp[23:16];
        mtimecmp[31:24] <= writeByteEnable[3] ? writeData[32:24] : mtimecmp[31:24];
      end
      else if(writeEnable && address == MTIMECMP_ADDR_H) begin
        mtimecmp[39:32] <= writeByteEnable[0] ? writeData[ 7: 0] : mtimecmp[39:32];
        mtimecmp[47:40] <= writeByteEnable[1] ? writeData[15: 8] : mtimecmp[47:40];
        mtimecmp[55:48] <= writeByteEnable[2] ? writeData[23:16] : mtimecmp[55:48];
        mtimecmp[63:56] <= writeByteEnable[3] ? writeData[31:24] : mtimecmp[63:56];
      end
    end

    // RV32 Read Logic
    always@(posedge clock) begin
      if(reset) begin
        readData <= {DATA_WIDTH{1'b0}};
      end
      else if(readEnable) begin
        case(address)
          MTIME_ADDR:      readData <= mtime[31:0];
          MTIMECMP_ADDR:   readData <= mtimecmp[31:0];
          MTIME_ADDR_H:    readData <= mtime[63:32];
          MTIMECMP_ADDR_H: readData <= mtimecmp[63:32];
          default:         readData <= {DATA_WIDTH{1'b0}};
        endcase
      end // else reset
    end // always

  end
  else if(DATA_WIDTH == 64) begin

    // RV64 MTIME Write Logic
    always@(posedge clock) begin
      if(reset) begin
        mtime    <= 64'd0;
      end
      else if(writeEnable && address == MTIME_ADDR) begin
        mtime[ 7: 0] <= writeByteEnable[0] ? writeData[ 7: 0] : mtime[ 7: 0];
        mtime[15: 8] <= writeByteEnable[1] ? writeData[15: 8] : mtime[15: 8];
        mtime[23:16] <= writeByteEnable[2] ? writeData[23:16] : mtime[23:16];
        mtime[31:24] <= writeByteEnable[3] ? writeData[31:24] : mtime[31:24];
        mtime[39:32] <= writeByteEnable[4] ? writeData[39:32] : mtime[39:32];
        mtime[47:40] <= writeByteEnable[5] ? writeData[47:40] : mtime[47:40];
        mtime[55:48] <= writeByteEnable[6] ? writeData[55:48] : mtime[55:48];
        mtime[63:56] <= writeByteEnable[7] ? writeData[63:56] : mtime[63:56];
      end
      else begin
        mtime <= mtime + 64'd1;
      end
    end

    // RV64 MTIMECMP Write Logic
    always@(posedge clock) begin
      if(reset) begin
        mtimecmp <= 64'hffffffff_ffffffff;
      end
      else if(writeEnable && address == MTIMECMP_ADDR) begin
        mtimecmp[ 7: 0] <= writeByteEnable[0] ? writeData[ 7: 0] : mtimecmp[ 7: 0];
        mtimecmp[15: 8] <= writeByteEnable[1] ? writeData[15: 8] : mtimecmp[15: 8];
        mtimecmp[23:16] <= writeByteEnable[2] ? writeData[23:16] : mtimecmp[23:16];
        mtimecmp[31:24] <= writeByteEnable[3] ? writeData[31:24] : mtimecmp[31:24];
        mtimecmp[39:32] <= writeByteEnable[4] ? writeData[39:32] : mtimecmp[39:32];
        mtimecmp[47:40] <= writeByteEnable[5] ? writeData[47:40] : mtimecmp[47:40];
        mtimecmp[55:48] <= writeByteEnable[6] ? writeData[55:48] : mtimecmp[55:48];
        mtimecmp[63:56] <= writeByteEnable[7] ? writeData[63:56] : mtimecmp[63:56];
      end
    end

    // RV64 Read Logic
    always@(posedge clock) begin
      if(reset) begin
        readData <= {DATA_WIDTH{1'b0}};
      end
      else if(readEnable) begin
        case(address)
          MTIME_ADDR:      readData <= mtime;
          MTIMECMP_ADDR:   readData <= mtimecmp;
          default:         readData <= {DATA_WIDTH{1'b0}};
        endcase
      end // else reset
    end // always

  end
endgenerate

endmodule
