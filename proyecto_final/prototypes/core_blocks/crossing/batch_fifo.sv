// batch_fifo: per-tick input batches from clk_pix to clk_juego for the
// qualified crossing (QUALIFIED = 1; crossing/FINDINGS.md). Owner: Alan.
// Domains: write side wclk = clk_pix, read side rclk = clk_juego.
//
// A Gray-pointer FIFO. The write side stores one batch per tick and advances
// a Gray write pointer; the read side sees it through a 2-FF ASYNC_REG
// synchronizer and, while not empty, pops the oldest batch on each edge. A
// stored word is read only after the pointer that covers it has crossed: at
// least one full clk_juego period after it was written.
//   RD_REG = 1 (default): the popped word is copied into rd_q, a game-domain
//     register whose only enable is the synchronized not-empty (the standard
//     FIFO read register); rdata is rd_q gated by the registered valid. A
//     batch written after game edge n is used at edge n + 4, as the model's
//     crossing="qualified". Vivado classifies mem -> rd_q as CDC-15.
//   RD_REG = 0: rdata is the memory word itself, gated by the not-empty, used
//     at n + 3. Functionally equivalent, but its payload reaches enable logic
//     all over game_core and Vivado reports those endpoints as CDC-1
//     (crossing/FINDINGS.md, first build).
// Crossings: wgray -> wgray_s1 and rgray -> rgray_s1 (Gray, one bit changes
// per update; constrain with set_max_delay -datapath_only and set_bus_skew),
// and mem -> rd_q (stable, enabled by the synchronized not-empty).
// Reset: assert wrst and rrst together for several clk_juego edges
// (reset_stretch); a one-sided live reset is not supported.
// PROVISIONAL (ADR 0005).
module batch_fifo #(
    parameter integer W  = 9,
    parameter integer AW = 3,                        // 8 entries; steady state holds 3
    parameter bit     RD_REG = 1'b1
) (
    input  logic         wclk, wrst, wen,
    input  logic [W-1:0] wdata,
    output logic         overflow,                   // sticky (wclk): a batch was dropped
    input  logic         rclk, rrst,
    output logic [W-1:0] rdata,                      // this edge's batch, 0 when none
    output logic         rvalid
);
    logic [W-1:0] mem [2**AW];
    logic [AW:0] wbin, wgray, rbin, rgray, wbin_n, rbin_n;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [AW:0] rgray_s1, rgray_s2;  // in wclk
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [AW:0] wgray_s1, wgray_s2;  // in rclk
    logic full, ne;                                  // ne: not empty, from the synchronized pointer
    logic [W-1:0] head;

    always_comb begin
        wbin_n = wbin + 1'b1;
        rbin_n = rbin + 1'b1;
        full   = wgray == {~rgray_s2[AW:AW-1], rgray_s2[AW-2:0]};
        ne     = wgray_s2 != rgray;
        head   = mem[rbin[AW-1:0]];
    end

    always_ff @(posedge wclk) begin
        if (wrst) begin
            wbin <= 0; wgray <= 0; rgray_s1 <= 0; rgray_s2 <= 0; overflow <= 0;
        end else begin
            rgray_s1 <= rgray; rgray_s2 <= rgray_s1;
            if (wen && full) overflow <= 1;
            else if (wen) begin
                wbin <= wbin_n; wgray <= wbin_n ^ (wbin_n >> 1);
            end
        end
    end
    always_ff @(posedge wclk) if (!wrst && wen && !full) mem[wbin[AW-1:0]] <= wdata;

    always_ff @(posedge rclk) begin
        if (rrst) begin
            rbin <= 0; rgray <= 0; wgray_s1 <= 0; wgray_s2 <= 0;
        end else begin
            wgray_s1 <= wgray; wgray_s2 <= wgray_s1;
            if (ne) begin rbin <= rbin_n; rgray <= rbin_n ^ (rbin_n >> 1); end
        end
    end

    generate
        if (RD_REG) begin : g_rd_reg
            logic [W-1:0] rd_q;
            logic rd_q_valid;
            always_ff @(posedge rclk) begin
                if (rrst) rd_q_valid <= 0;
                else rd_q_valid <= ne;
            end
            always_ff @(posedge rclk) if (ne) rd_q <= head;  // enable = synchronized not-empty only
            always_comb begin
                rvalid = rd_q_valid;
                rdata  = rd_q_valid ? rd_q : '0;
            end
        end else begin : g_rd_comb
            always_comb begin
                rvalid = ne;
                rdata  = ne ? head : '0;
            end
        end
    endgenerate
endmodule
