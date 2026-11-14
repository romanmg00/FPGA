// Gives a 1-tick pulse every STEP_TICKS ticks while run = 1, and restarts from 0 whenever run = 0.
// With STEP_TICKS = 6 and clk_juego at ~60 Hz, a bike moves ~10 cells per second.
// With STEP_TICKS = 120 it measures the 2 s pause after a crash.
module step_counter #(
    parameter int STEP_TICKS = 6
) (
    input  logic clk,     // clk_juego (~60 Hz)
    input  logic rst,
    input  logic run,     // count while 1; restart from 0 while 0
    output logic step     // 1-tick pulse on the last tick of each period
);

    // Counts 0 to STEP_TICKS-1; $clog2 gives just enough bits for each instance.
    logic [$clog2(STEP_TICKS)-1:0] counter; 
    // Priority: rst or run = 0 restarts; the last value wraps to 0; otherwise count up.
    always_ff @(posedge clk) begin
        if (rst || !run) begin
            counter <= 3'b0;
        end
        else if (counter == STEP_TICKS - 1'b1) begin
            counter <= 3'b0;
        end
        else begin
            counter <= counter + 3'b1;
        end
    end
    // step is 1 while the counter holds its last value, so the step is taken on the next edge.
    assign step = (counter == STEP_TICKS - 1);

endmodule
