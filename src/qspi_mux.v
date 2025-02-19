
//=============================================================================
// This multiplexes multiple inputs to a single output.  Only one input at a 
// time will be connected to the output.
// 
// The algorithm for using this is:
//
// (1) The requestor initializes one of the "mux_inX" inputs
// (2) The requestor asserts the corresponding "request_X" input
// (3) The requestor waits for "grant_X" to go high
// (4) The requestor performs its transactions
// (5) The requestor deasserts the "request_X" input
//
// The lower the value of "X" in "request_X" the higher priority it has
// during request arbitration.   request_1 is higher priority than request_2,
// request_2 is higher priority than request_3, etc.
//=============================================================================

module qspi_mux # (parameter INPUTS = 2, DW = 32)
(
    input clk, resetn,

    // Raise one of these to request access to the mux output
    input request_1, request_2,
    
    // When one of these go high, it indicates the mux request has been granted
    output grant_1, grant_2,
    
    // These inputs will be routed to the mux output
    input[DW-1:0] mux_in1, mux_in2,
    
    // The mux output
    output reg[DW-1:0] mux_out
);

// This keeps track of which request_X is currently granted.  Its value will
// always be in the range 0...INPUTS.  A zero means that there are no requests.
reg[$clog2(INPUTS):0] granted;

//=============================================================================
// Map the request_X inputs to bits in request[]
//=============================================================================
wire[INPUTS:0]      request;
assign request[0] = 0;
assign request[1] = request_1;
assign request[2] = request_2;
//=============================================================================


//=============================================================================
// This will assert one of the grant_X outputs, but only if the corresponding
// request_X input is active
//=============================================================================
wire[INPUTS:0]   assert_grant = (1 << granted);
assign grant_1 = assert_grant[1] & request_1;
assign grant_2 = assert_grant[2] & request_2;
//=============================================================================


//=============================================================================
// This block drives "mux_out" depending on the state of the "granted" register
//=============================================================================
always @* begin

    // By default, the mux-output is always cleared
    mux_out = 0;

    // If there is a valid request, drive its inputs to mux_out
    if (resetn == 1 && request[granted]) case(granted)
        1:  mux_out = mux_in1;
        2:  mux_out = mux_in2;
    endcase
end
//=============================================================================


//=============================================================================
// This block determines the highest priority request input
//=============================================================================
reg[$clog2(INPUTS):0] highest_prio_req;
//-----------------------------------------------------------------------------
integer i;
always @* begin
    highest_prio_req = 0;
    for (i=1; i<=INPUTS; i=i+1) begin
        if (request[i]) begin
            if (highest_prio_req == 0) highest_prio_req = i;
        end
    end
end
//=============================================================================


//============================================================================
// This block continously checks to see if the currently granted request
// is no longer valid, and if that's true, checks for pending request
//
// request[0] is never valid, so on any clock cycle where "granted == 0" we
// will always check for a pending request
//============================================================================
always @(posedge clk) begin

    // If we're in reset, no requests are granted
    if (resetn == 0)
        granted <= 0;
    
    // If the current request is no longer valid, 
    // find out if there is a new pending request
    else if (request[granted] == 0)
        granted <= highest_prio_req;
end
//============================================================================



endmodule


