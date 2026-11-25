// Author: Alan (AIF31).
module uart_link (
    input  logic       clk_pix,
    input  logic [4:0] cmd,             // [0] Up, [1] Right, [2] Down, [3] Left, [4] Start
    input  logic       cmd_valid,       // rx_valid: cmd is from a new byte
    input  logic       clk_juego,
    input  logic       rst_juego,
    output logic [4:0] cmd_juego        // the command for 2 ticks, then 0
);

    // clk_pix side
    logic [4:0] cmd_pix = 5'd0;         // changes only when the mailbox is empty
    logic       cmd_tgl = 1'b0;
    logic       ack_tgl_sync;
    logic       empty;                  // the last command sent was taken
    // clk_juego side
    logic       cmd_tgl_sync;
    logic       ack_tgl = 1'b0;         // the answer
    logic       new_cmd;
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

    always_ff @(posedge clk_juego) begin
        ack_tgl <= cmd_tgl_sync;
        if (rst_juego) begin
            cmd_juego <= 5'd0;
            hold_cmd  <= 1'b0;
        end else if (new_cmd) begin
            cmd_juego <= cmd_pix;           // first tick
            hold_cmd  <= 1'b1;
        end else if (hold_cmd) begin
            hold_cmd  <= 1'b0;              // second tick
        end else begin
            cmd_juego <= 5'd0;
        end
    end

endmodule
