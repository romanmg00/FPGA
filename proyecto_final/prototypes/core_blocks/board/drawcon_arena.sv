// Owners Roman drawing / Alan integration. PROVISIONAL test-pattern interface.
// Combinational clk_pix service, no CDC. RAM B has one synchronous stage.
// curr coordinates lead physical RGB by one cycle in unchanged vga_out.
// Fetch NEXT coordinate now: after RAM edge data matches new curr coordinate;
// vga_out consumes that pair on the following edge. No extra RGB register.
module drawcon_arena (
    input logic [10:0] curr_x, curr_y,
    input logic [3:0] b_rdata,
    input logic ready,
    output logic [12:0] b_addr,
    output logic [3:0] draw_r, draw_g, draw_b
);
    logic [10:0] nx, ny;
    logic [11:0] rgb;
    always_comb begin
        nx = curr_x + 11'd1;
        ny = curr_y;
        // Reconstruct complete raster wrap, including horizontal porch.
        if (curr_x == 11'd1343) begin
            nx = 11'd1712; // (0 - 336) modulo 2048
            ny = (curr_y == 11'd800) ? 11'd2021 : curr_y + 11'd1;
        end
        b_addr = 0;
        if (nx < 1280 && ny < 800) b_addr = {ny[9:4],nx[10:4]};
        rgb = 12'h000;
        if (ready && curr_x < 1280 && curr_y < 800) begin
            case (b_rdata)
                0: rgb=12'h000; 1: rgb=12'h444;
                2: rgb=12'h08f; 3: rgb=12'h0ff;
                4: rgb=12'hf80; 5: rgb=12'hff0;
                6: rgb=12'hf00; 8: rgb=12'h0f0;
                9: rgb=12'h80f; 10: rgb=12'hf0f;
                default: rgb=12'h888;
            endcase
        end
        if (curr_x < 1280 && curr_y < 800 &&
            (curr_x < 10 || curr_x >= 1270 || curr_y < 10 || curr_y >= 790)) rgb=12'hfff;
        {draw_r,draw_g,draw_b}=rgb;
    end
endmodule
