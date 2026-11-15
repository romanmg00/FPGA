// Movement of one bike: cell, heading and pending turn. Instantiated once per bike.
// Headings are clockwise: 0 UP, 1 RIGHT, 2 DOWN, 3 LEFT. Coordinates are in cells.
module bike_move #(
    parameter logic [6:0] START_CX      = 7'd20,
    parameter logic [6:0] START_CY      = 7'd27,
    parameter logic [1:0] START_HEADING = 2'd1
) (
    input  logic       clk,        // clk_juego (~60 Hz)
    input  logic       rst,
    input  logic       load,       // from round_fsm: hold the bike at its start cell
    input  logic       run,        // from round_fsm: turns are accepted
    input  logic       advance,    // pulse: the bike moves to (next_cx, next_cy)
    input  logic [3:0] turn_req,   // same order as heading: [0] UP, [1] RIGHT, [2] DOWN, [3] LEFT
    output logic [6:0] cx, cy,
    output logic [1:0] heading,
    output logic [6:0] next_cx, next_cy
);

    // pending_turn: direction of the next step. req_code/req_valid: the request now.
    // valid_turn: the request is a 90-degree turn from the current heading.
    logic [1:0] pending_turn, req_code;  
    logic req_valid, valid_turn;

    // Priority encoder (UP > RIGHT > DOWN > LEFT), then the turn rule: a turn is valid only
    // if it changes axis, i.e. bit 0 differs. It is checked against heading, not the pending
    // turn, so two turns between steps cannot add up to a reversal.
    always_comb begin 
        if(turn_req[0]) begin
            req_valid = 1'b1;
            req_code = 2'b00;
        end else if(turn_req[1]) begin
            req_valid = 1'b1;
            req_code = 2'b01;
        end else if(turn_req[2]) begin
            req_valid = 1'b1;
            req_code = 2'b10;
        end else if(turn_req[3]) begin
            req_valid = 1'b1;
            req_code = 2'b11;
        end else begin
            req_valid = 1'b0;
            req_code = heading;
        end 
        valid_turn = req_valid && (req_code[0] != heading[0]);
    end 

    // Next cell: one cell from (cx, cy) in the direction of the pending turn.
    // The screen y axis grows downwards, so UP subtracts 1.
    always_comb begin
        next_cx = cx;
        next_cy = cy;
        case(pending_turn)
            2'b00: next_cy = cy - 1'b1;          // UP
            2'b01: next_cx = cx + 1'b1;          // RIGHT
            2'b10: next_cy = cy + 1'b1;          // DOWN
            2'b11: next_cx = cx - 1'b1;          // LEFT
            default: begin
                next_cx = cx;
                next_cy = cy;
            end
        endcase    
    end


    // Registers, by priority:
    //   rst or load: start cell, heading and pending turn from START_*.
    //   advance:     move to the next cell; the heading takes the pending turn.
    //   run:         a valid request replaces the pending turn.

    always_ff @(posedge clk) begin
        if(rst || load) begin
            cx <= START_CX;
            cy <= START_CY;
            heading <= START_HEADING;
            pending_turn <= START_HEADING;
        end else if(advance) begin
            cx <= next_cx;
            cy <= next_cy;
            heading <= pending_turn;
        end else if(run) begin
            if(valid_turn) pending_turn <= req_code;
        end
    end

endmodule
