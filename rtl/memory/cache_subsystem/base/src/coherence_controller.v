/** @module : coherence_controller
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

/** Module description
* --------------------
  *  - Grants access to the shared bus in an order which  maintains cache
  *    coherence of the caches connected to the bus.
  *  - Receives the bus messages from all the caches connected including the
  *    shared cache at L(x) and L(x-1) caches sharing it. Uses these messages
  *    to determine which cache wins cache arbitration.
*/

module coherence_controller #(
parameter MSG_BITS       = 4,
          NUM_CACHES     = 4
)(
clock, reset,
cache2mem_msg,
mem2controller_msg,
bus_msg,
bus_control,
bus_en,
curr_master,
req_ready
);

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value>>1;
  end
endfunction

//function to find next power of 2
function integer next_pow2;
input integer number;
begin
  next_pow2 = 1;
  while(number > next_pow2)begin
    next_pow2 = next_pow2 << 1;
  end
end
endfunction

`include `INCLUDE_FILE

// Local parameters //
localparam BUS_PORTS     = NUM_CACHES + 1;
localparam MEM_PORT      = BUS_PORTS - 1;
localparam BUS_SIG_WIDTH = log2(BUS_PORTS);

// states
localparam IDLE            = 3'd0,
           WAIT_EN         = 3'd1,
           COHERENCE_OP    = 3'd2,
           WAIT_FOR_MEM    = 3'd3,
           HOLD            = 3'd4,
           END_TRANSACTION = 3'd5,
           MEM_HOLD        = 3'd6;

input clock, reset;
input [(NUM_CACHES*MSG_BITS)-1:0] cache2mem_msg;
input [MSG_BITS-1:             0] mem2controller_msg;
input [MSG_BITS-1:             0] bus_msg;
output reg [BUS_SIG_WIDTH-1:   0] bus_control;
output reg bus_en;
output reg req_ready;
output [BUS_PORTS-1          : 0] curr_master;


//internal variables
genvar i;
integer j;
reg  [2:0] state;
wire [MSG_BITS-1        :0] w_msg_in [BUS_PORTS-1:0];
wire [NUM_CACHES-1      :0] requests;
wire [log2(NUM_CACHES)-1:0] serve_next;
wire [NUM_CACHES-1      :0] tr_en_access;
wire [next_pow2(NUM_CACHES)-1:0] tr_coherence_op;
wire [log2(NUM_CACHES)-1:0] coh_op_cache;
wire [log2(next_pow2(NUM_CACHES))-1:0] temp_coh_op_cache;
wire coh_op_valid;
wire req_valid;

reg [BUS_SIG_WIDTH-1:0] r_curr_master;
reg [BUS_SIG_WIDTH-1:0] transaction_owner;
reg r_curr_master_valid;


// separate bundled inputs
generate
  for(i=0; i<BUS_PORTS; i=i+1)begin : MSG_IN
	if(i == BUS_PORTS-1)
	  assign w_msg_in[i] = mem2controller_msg;
	else
    assign w_msg_in[i] = cache2mem_msg[i*MSG_BITS +: MSG_BITS];
  end
endgenerate


// instantiate arbiter
arbiter #(
  .WIDTH(NUM_CACHES),
  .ARB_TYPE("PACKET")
) arbitrator (
    .clock(clock), 
    .reset(reset),
    .requests(requests),
    .grant(serve_next),
	.valid(req_valid)
  );
  
// instantiate one-hot encoder
one_hot_encoder #(.WIDTH(BUS_PORTS))
  curr_master_encoder(
    .in(r_curr_master),
    .valid_input(r_curr_master_valid),
    .out(curr_master)
  );

priority_encoder #(
  .WIDTH(next_pow2(NUM_CACHES)),
  .PRIORITY("LSB")
) coh_op_encoder (
    .decode(tr_coherence_op),
    .encode(temp_coh_op_cache),
    .valid(coh_op_valid)
  );

//assign output to a wire of appropriate width
assign coh_op_cache = temp_coh_op_cache[0 +: log2(NUM_CACHES)];

generate
// track requests from caches
  for(i=0; i<NUM_CACHES; i=i+1)begin : REQUESTS
    assign requests[i] = (w_msg_in[i] == R_REQ) | (w_msg_in[i] == WB_REQ  ) |
                         (w_msg_in[i] == FLUSH) | (w_msg_in[i] == WS_BCAST) |
                         (w_msg_in[i] == RFO_BCAST);
  end

// track coherence messages from L1 caches
  for(i=0; i<next_pow2(NUM_CACHES); i=i+1)begin : TR_COH_MSGS
    if(i<NUM_CACHES)
      assign tr_coherence_op[i] = (w_msg_in[i] == C_WB)    |
                                  (w_msg_in[i] == C_FLUSH) ;
    else
      assign tr_coherence_op[i] = 1'b0;
  end

//track enable access signals
  for(i=0; i<NUM_CACHES; i=i+1)begin: TR_EN
    assign tr_en_access[i] = (w_msg_in[i] == EN_ACCESS) | 
                            ((i == transaction_owner) & (bus_msg != REQ_FLUSH));
  end
endgenerate



//control logic
always @(posedge clock)begin
  if(reset)begin
    bus_control         <= {BUS_SIG_WIDTH{1'b0}};
    r_curr_master       <= {BUS_SIG_WIDTH{1'b0}};
    transaction_owner   <= {BUS_SIG_WIDTH{1'b0}};
    r_curr_master_valid <= 1'b0;
    bus_en              <= 1'b0;
    req_ready           <= 1'b0;
    state               <= IDLE;
  end
  else begin
    case(state)
      IDLE:begin
        if(mem2controller_msg == REQ_FLUSH)begin
        /*Lx cache is issuing a flush request. This should always win the
        * arbitration*/
          bus_control         <= MEM_PORT;
          r_curr_master       <= MEM_PORT;
          transaction_owner   <= MEM_PORT;
          r_curr_master_valid <= 1'b1;
          bus_en              <= 1'b1;
          state               <= WAIT_EN;
        end
        else if(req_valid)begin
          bus_control         <= serve_next;
          r_curr_master       <= serve_next;
          transaction_owner   <= serve_next;
          r_curr_master_valid <= 1'b1;
          bus_en              <= 1'b1;
          if((w_msg_in[serve_next] == WB_REQ) | (w_msg_in[serve_next] == FLUSH))
          begin
            req_ready <= 1'b1;
            state     <= WAIT_FOR_MEM;
          end
          else
            state     <= WAIT_EN;
        end
        else begin
          state <= IDLE;
        end
      end
      WAIT_EN:begin
        if(mem2controller_msg == REQ_FLUSH & bus_msg != REQ_FLUSH)begin
          bus_control         <= MEM_PORT;
          bus_en              <= 1'b1;
          req_ready           <= 1'b0;
          r_curr_master       <= MEM_PORT;
          r_curr_master_valid <= 1'b1;
          state               <= WAIT_EN;
        end
        else if(&tr_en_access & (mem2controller_msg == EN_ACCESS | bus_msg != WS_BCAST))begin
		    /*WS_BCAST is the only time the Lx cache has to respond with EN_ACCESS*/
          if(bus_msg == WS_BCAST)begin
            bus_control <= {BUS_SIG_WIDTH{1'b0}};
            bus_en      <= 1'b0;
            req_ready   <= 1'b1;
            state       <= END_TRANSACTION;
          end
          else if(bus_msg == REQ_FLUSH)begin
            bus_control         <= {BUS_SIG_WIDTH{1'b0}};
            bus_en              <= 1'b0;
            req_ready           <= 1'b1;
            r_curr_master       <= transaction_owner;
            r_curr_master_valid <= 1'b1;
            state               <= (transaction_owner == MEM_PORT) ? 
			                             END_TRANSACTION : WAIT_FOR_MEM;
          end
          else begin
            bus_control         <= transaction_owner;
            bus_en              <= 1'b1;
            req_ready           <= 1'b1;
            r_curr_master       <= transaction_owner;
            r_curr_master_valid <= 1'b1;
            state               <= WAIT_FOR_MEM;
          end
        end
        else if(coh_op_valid)begin
          bus_control         <= coh_op_cache;
          bus_en              <= 1'b1;
          r_curr_master       <= coh_op_cache;
          r_curr_master_valid <= 1'b1;
          state               <= COHERENCE_OP;
        end
        else begin
          state <= WAIT_EN;
        end
      end
      WAIT_FOR_MEM:begin
        if(mem2controller_msg == REQ_FLUSH & bus_en)begin
        /*checking bus_en signal to stop coherence controller going to WAIT_FOR_MEM 
        * state by reading the old REQ_FLUSH message from the Lxcache while informing 
        * the Lx that all caches sent EN_ACCESS for the REQ_FLUSH.*/
          bus_control         <= MEM_PORT;
          bus_en              <= 1'b1;
          r_curr_master       <= MEM_PORT;
          r_curr_master_valid <= 1'b1;
          req_ready           <= 1'b0;
          state               <= WAIT_EN;
        end
        else if((mem2controller_msg == MEM_RESP) | (mem2controller_msg == 
        MEM_RESP_S) | (mem2controller_msg == MEM_C_RESP))begin
          bus_control         <= MEM_PORT;
          bus_en              <= 1'b1;
          r_curr_master       <= transaction_owner;
          r_curr_master_valid <= 1'b1;
          req_ready           <= 1'b0;
          state               <= END_TRANSACTION;
        end      
        else if(mem2controller_msg == HOLD_BUS)begin
          bus_control         <= MEM_PORT;
          bus_en              <= 1'b1;
          r_curr_master       <= MEM_PORT;
          r_curr_master_valid <= 1'b1;
          req_ready           <= 1'b0;
          state               <= MEM_HOLD;
        end
        else begin
          state <= WAIT_FOR_MEM;
        end
      end
      END_TRANSACTION:begin
        if(w_msg_in[r_curr_master] == EN_ACCESS)begin
          bus_control         <= {BUS_SIG_WIDTH{1'b0}};
          bus_en              <= 1'b0;
          r_curr_master       <= transaction_owner;
          r_curr_master_valid <= 1'b1;
          state               <= WAIT_EN;
        end
        else if(w_msg_in[r_curr_master] == HOLD_BUS)begin
          bus_control         <= r_curr_master;
          bus_en              <= 1'b1;
          state               <= (r_curr_master == MEM_PORT) ? MEM_HOLD : HOLD;
        end
        else if(w_msg_in[r_curr_master] == NO_REQ)begin
          bus_control         <= {BUS_SIG_WIDTH{1'b0}};
          bus_en              <= 1'b0;
          req_ready           <= 1'b0;
          r_curr_master       <= {BUS_SIG_WIDTH{1'b0}};
          r_curr_master_valid <= 1'b0;
          state               <= IDLE;
        end
        else begin
          state <= END_TRANSACTION;
        end
      end
      COHERENCE_OP:begin
          if(mem2controller_msg == MEM_C_RESP)begin
            bus_control         <= MEM_PORT;
            bus_en              <= 1'b1;
            state               <= END_TRANSACTION;
          end
      end
      HOLD:begin
        if(w_msg_in[r_curr_master] == EN_ACCESS)begin
          bus_control         <= {BUS_SIG_WIDTH{1'b0}};
          bus_en              <= 1'b0;
          r_curr_master       <= transaction_owner;
          r_curr_master_valid <= 1'b1;
          state               <= WAIT_EN;
        end
        else if((w_msg_in[r_curr_master] == C_WB) | (w_msg_in[r_curr_master] == 
        C_FLUSH))begin
          bus_control         <= r_curr_master;
          bus_en              <= 1'b1;
          r_curr_master_valid <= 1'b1;
          state               <= COHERENCE_OP;
        end
      end
      MEM_HOLD:begin
        if(mem2controller_msg == NO_REQ)begin
          bus_control         <= transaction_owner;
          bus_en              <= (transaction_owner != MEM_PORT) ? 1'b1 : 1'b0;
          req_ready           <= ((w_msg_in[transaction_owner] == WB_REQ) | 
                                  (w_msg_in[transaction_owner] == FLUSH)) ?
                                  1'b1 : 1'b0;
          r_curr_master       <= transaction_owner;
          r_curr_master_valid <= 1'b1;
          state               <= (transaction_owner == MEM_PORT) | 
                                 (w_msg_in[transaction_owner] == NO_REQ)  ? IDLE 
                               : ((w_msg_in[transaction_owner] == WB_REQ) | 
                                  (w_msg_in[transaction_owner] == FLUSH)) ?
                                 WAIT_FOR_MEM : WAIT_EN;
        end
        else 
          state <= MEM_HOLD;
      end
      default:begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule
