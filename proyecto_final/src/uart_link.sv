// Author: Alan (AIF31).
// Carries P2's commands from clk_pix (uart_rx, uart_decode) to clk_juego, one at a time
// (ADR 0013). A command goes into cmd_pix and flips cmd_tgl. clk_juego sees the flip through
// sync_2ff, copies cmd_pix, which has not changed for at least one tick, and answers with
// ack_tgl. A new command is taken only once that answer is back on clk_pix, 2 to 3 ticks
// later (up to 50 ms); a command that arrives before that is dropped. On clk_juego each
// command lasts 2 ticks, because bike_move ignores a Turn in the tick of a Step and two
// Steps are never in consecutive ticks.
module uart_link (
    input  logic       clk_pix,         // 83.46 MHz
    input  logic [4:0] cmd,             // from uart_decode: [0] Up, [1] Right, [2] Down, [3] Left, [4] Start
    input  logic       cmd_valid,       // rx_valid from uart_rx: cmd is from a new byte
    input  logic       clk_juego,       // ~60 Hz
    input  logic       rst_juego,
    output logic [4:0] cmd_juego        // the command for 2 ticks, then 0; same bits as cmd
);

    // The toggles and their synchronizers are never reset, as in arena_link: a reset must not
    // fake or repeat a command.
    // clk_pix side
    logic [4:0] cmd_pix = 5'd0;         // the command sent; changes only when the mailbox is empty
    logic       cmd_tgl = 1'b0;         // flips with each command sent
    logic       ack_tgl_sync;           // ack_tgl after sync_2ff
    logic       empty;                  // the last command sent was taken
    // clk_juego side
    logic       cmd_tgl_sync;           // cmd_tgl after sync_2ff
    logic       ack_tgl = 1'b0;         // cmd_tgl_sync one tick later: the answer
    logic       new_cmd;                // a command waits to be taken
    logic       hold_cmd;               // cmd_juego keeps its command one more tick

    assign empty = (cmd_tgl == ack_tgl_sync);

    always_ff @(posedge clk_pix) begin
        if (cmd_valid && cmd != 5'd0 && empty) begin
            cmd_pix <= cmd;
            cmd_tgl <= ~cmd_tgl;
        end
    end

    sync_2ff u_sync_ack (.clk(clk_pix), .rst(1'b0), .async_in(ack_tgl), .sync_out(ack_tgl_sync));

    sync_2ff u_sync_cmd (.clk(clk_juego), .rst(1'b0), .async_in(cmd_tgl), .sync_out(cmd_tgl_sync));

    assign new_cmd = (cmd_tgl_sync != ack_tgl);

    // The answer is given in the same tick cmd_pix is copied, so cmd_pix cannot change
    // before the copy. During rst_juego a command is answered but not passed on.
    always_ff @(posedge clk_juego) begin
        ack_tgl <= cmd_tgl_sync;
        if (rst_juego) begin
            cmd_juego <= 5'd0;
            hold_cmd  <= 1'b0;
        end else if (new_cmd) begin
            cmd_juego <= cmd_pix;           // first tick
            hold_cmd  <= 1'b1;
        end else if (hold_cmd) begin
            hold_cmd  <= 1'b0;              // second tick: cmd_juego keeps the command
        end else begin
            cmd_juego <= 5'd0;
        end
    end

endmodule
