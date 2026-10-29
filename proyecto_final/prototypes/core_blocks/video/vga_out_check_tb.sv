`timescale 1ns/1ps
// Owner Roman; independent builder bench (not the official cross-owner bench).
// Reference raster from contract, no DUT internal counter access. clk_pix only.
module vga_out_check_tb;
    logic clk_pix = 0;
    logic rst = 1;
    logic [3:0] draw_r, draw_g, draw_b;
    logic [10:0] curr_x, curr_y;
    logic tick_60hz;
    logic [3:0] pix_r, pix_g, pix_b;
    logic hsync, vsync;
    integer h = 0;
    integer v = 0;
    integer old_h, old_v;
    integer n;
    integer sync_errors = 0;
    integer blank_errors = 0;
    integer coordinate_errors = 0;
    integer pipeline_errors = 0;
    integer visible_pixels = 0;
    logic [11:0] sampled_draw;
    logic output_visible;
    vga_out dut (.*);
    always #5 clk_pix = ~clk_pix;
    // Exercise changing colour as well as nonzero blanking rejection.
    always_comb begin
        draw_r = 4'hf;
        draw_g = curr_x[3:0];
        draw_b = curr_y[3:0];
    end
    initial begin
        repeat (3) @(negedge clk_pix);
        rst = 0;
        for (n=0; n<2*1680*828; n=n+1) begin
            old_h = h; old_v = v;
            sampled_draw = {draw_r,draw_g,draw_b};
            @(posedge clk_pix); #1;
            if (h == 1679) begin
                h = 0;
                if (v == 827) v = 0; else v = v+1;
            end else h = h+1;
            // Handout contract: sync, colour and curr_x/curr_y all describe the
            // current raster position; colour is the current draw_* when visible.
            output_visible = h>=336 && h<1616 && v>=27 && v<827;
            if (hsync !== !(h<136) || vsync !== (v<3)) sync_errors++;
            if (!output_visible && {pix_r,pix_g,pix_b} !== 12'h000) blank_errors++;
            if (output_visible && {pix_r,pix_g,pix_b} !== {draw_r,draw_g,draw_b}) pipeline_errors++;
            if (output_visible) begin
                visible_pixels++;
                if (curr_x !== h-336 || curr_y !== v-27) begin
                    if (coordinate_errors < 4)
                        $display("Coordinate mismatch raster=(%0d,%0d) curr=(%0d,%0d)",h-336,v-27,curr_x,curr_y);
                    coordinate_errors++;
                end
            end
            @(negedge clk_pix);
        end
        $display("Two frames: pixels=%0d sync_mismatches=%0d blank_mismatches=%0d coordinate_mismatches=%0d colour_mismatches=%0d",visible_pixels,sync_errors,blank_errors,coordinate_errors,pipeline_errors);
        if (visible_pixels != 2*1280*800 || h != 0 || v != 0) $fatal(1,"Bench coverage mismatch");
        if (sync_errors || blank_errors || coordinate_errors || pipeline_errors)
            $fatal(1,"vga_out violates output coordinate/raster alignment; see video/FINDINGS.md");
        $display("PASS vga_out_check_tb");
        $finish;
    end
endmodule
