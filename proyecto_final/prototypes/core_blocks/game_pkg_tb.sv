// game_pkg_tb: checks the derived constants of the contract package.
module game_pkg_tb;
    import game_pkg::*;
    initial begin
        if (H_TOTAL != 1680) $fatal(1, "H_TOTAL=%0d", H_TOTAL);
        if (V_TOTAL != 828) $fatal(1, "V_TOTAL=%0d", V_TOTAL);
        if (CX_W + CY_W != ADDR_W) $fatal(1, "address width");
        if (PLAY_CX_MAX - PLAY_CX_MIN + 1 != 78) $fatal(1, "playable width");
        if (PLAY_CY_MAX - PLAY_CY_MIN + 1 != 44) $fatal(1, "playable height");
        if (CELL_REWARD2 != 4'd10) $fatal(1, "reward code");
        $display("PASS game_pkg_tb");
        $finish;
    end
endmodule
