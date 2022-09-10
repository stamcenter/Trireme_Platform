/** @module : 
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

//bus messages
localparam NO_REQ     = 4'd0,
           R_REQ      = 4'd1, //read(GetS)
           RFO_BCAST  = 4'd2, //get line for modifying (GetM)
           WB_REQ     = 4'd3, //writeback (PutM)
           FLUSH      = 4'd4,
           FLUSH_S    = 4'd5,
           WS_BCAST   = 4'd6, //requesting to modify a shared line (GetM)
           C_WB       = 4'd7, //coherence writeback in response to a busread
           C_FLUSH    = 4'd8, //flushing a line requested by L2
           EN_ACCESS  = 4'd9, //enable current transaction on the bus
           HOLD_BUS   = 4'd10,
           REQ_FLUSH  = 4'd11, //Same as invalidation request from L2
           MEM_C_RESP = 4'd12,
           MEM_RESP   = 4'd13, //memory responding with E data (DataE)
           MEM_RESP_S = 4'd14; //memory responding with S data (Data)


// coherence states
localparam INVALID   = 2'b00,
           EXCLUSIVE = 2'b01,
           SHARED    = 2'b11,
           MODIFIED  = 2'b10;



/*NoC related messages*/
localparam NoMsg    = 4'd0,
//cache messages
           GetS     = 4'd1,  // get cache line in shared state                 // cache requests line from directory, its ok that line is shared
           GetM     = 4'd2,  // get cache line to be modified                  // cache requests line from directory, used for write miss, line will be modified
           PutM     = 4'd3,  // write back modified line                       // cache writing back to directory
           PutS     = 4'd4,  // inform directory of eviction (no data)         // cache edits line because of conflict miss, cache lets go of line without modifing it
           PutE     = 4'd5,  // acknowledge a share request                    // cache gives up exclusive state on line, line becomes shared
           InvAck   = 4'd6,  // acknowledge an invalidation request            // cache invalidates line, sends response to directory
           NackD    = 4'd8,  // reject because the request cannot be fulfilled // cache does not have requested data/cannot do what the directory asked
           RespPutM = 4'd9,  // a writeback corresponding to a Invalidation    // cache writes back line that directory requested be invalidated
                             // request
           NackC    = 4'd15, // conveys the same information as NackB, but     // directory sends request to cache, but cache cannot buffer/service request, cache responsts with NackC
                             // issued directory messages
           FwdGetS  = 4'd10, // share request to cache holding a line in       // directory sends message to cache with exclusive copy to make copy shared
                             // E state
           Inv      = 4'd11, // invalidation request                           // directory asks caches to let go of stored lines
           PutAck   = 4'd12, // acknowledge PutS, PutE or PutM                 // directory responds to cache writebacks or exclusive-to-shared transitions
           Data     = 4'd13, // respond with E data                            // directory sends exculusive copy of a cacheline
           DataS    = 4'd14, // respond with S data                            // directory sends shared copy of a cacheline
                             // by the caches.
           NackB    = 4'd7;  // reject request because controller is           // cache sends request to directory, but directory cannot buffer/service request, directory responds with NackB
                             // busy (& buffers full)
