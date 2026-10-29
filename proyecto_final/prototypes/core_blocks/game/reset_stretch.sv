// reset_stretch: power-up and CPU_RESETN reset request, held long enough that
// both clk_pix and clk_juego see reset across several game edges together.
// Owner: Alan (game_top). Domain: clk = the second Wizard's base clock, which
// runs from configuration and is never reset, so the hold counter always
// counts. Crossing: cpu_resetn (async pin) -> 2-FF synchronizer here; the
// output rst_req is a level that each domain synchronizes again
// (board/board_reset_sync).
//
// Why: the model resets both domains at once (Hardware Map, review F7). In
// hardware a reset that one domain sees and the other misses could leave a
// stale mailbox sequence number; holding rst_req for HOLD base cycles (six
// game periods by default) puts both domains in reset at the same time,
// so nothing in flight survives. PROVISIONAL (ADR 0005).
module reset_stretch #(
    parameter integer HOLD = 6 * 78126           // base cycles: six ~60 Hz game periods
) (
    input  logic clk,
    input  logic cpu_resetn,
    output logic rst_req = 1'b1
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic n_meta = 1'b0, n_sync = 1'b0;
    logic [$clog2(HOLD + 1)-1:0] count = '0;
    always_ff @(posedge clk) begin
        n_meta <= cpu_resetn;
        n_sync <= n_meta;
        if (!n_sync) begin
            count <= '0;
            rst_req <= 1'b1;
        end else if (count != HOLD[$clog2(HOLD + 1)-1:0]) begin
            count <= count + 1'b1;
            rst_req <= 1'b1;
        end else rst_req <= 1'b0;
    end
endmodule
