module vga_out_tb;
    //inputs
    logic clk_pix, rst;
    logic [3:0]  draw_r, draw_g, draw_b;
    //outputs
    logic [10:0] curr_x;
    logic [10:0] curr_y;
    logic        tick_60hz;
    logic [3:0]  pix_r, pix_g, pix_b;
    logic        hsync, vsync;
    // These variables are used for measuring cycles.
    time         inicio_hsync;
    time         final_hsync;
    time         last_hsync;
    time         inicio_vsync;
    time         final_vsync;
    time         last_vsync;
    integer      errors = 0;
    logic        it_was_visible;

    //Initialize module
    vga_out dut (
        .clk_pix   (clk_pix),
        .rst       (rst),
        .tick_60hz (tick_60hz),
        .curr_x    (curr_x),
        .curr_y    (curr_y),
        .draw_r    (draw_r),
        .draw_g    (draw_g),
        .draw_b    (draw_b),
        .pix_r     (pix_r),
        .pix_g     (pix_g),
        .pix_b     (pix_b),
        .hsync     (hsync),
        .vsync     (vsync)
    );

    //Generate clock and reset
    initial begin
        clk_pix = 1'b0;
        rst = 1'b1;
        draw_r = 4'hf;
        draw_g = 4'hf;
        draw_b = 4'hf;
        inicio_hsync = 64'b0;
        inicio_vsync = 64'b0;
        last_hsync = 64'b0;
        last_vsync = 64'b0;
        it_was_visible = 1'b0;
        #10 rst = 1'b0;
        #30000000;
        if (errors == 0) $display("PRUEBAS OK");
        else $display("Errors: %0d", errors);
        $finish;
    end

    always #5 clk_pix = ~clk_pix;
 
    // Los flancos durante el reset se ignoran: un pulso que empezó en el
    // reset no se puede medir completo, así que inicio_* se queda en 0
    // y su duración no se revisa.
    always @(hsync) if (~rst) begin
        if(~hsync) begin
            inicio_hsync = $time ;
            end
        else begin
            final_hsync = $time ;
            if (inicio_hsync!=64'b0 && final_hsync-inicio_hsync != 1360)begin
                if(errors<20) $display("ERROR: tiempo de hsync: %0d", final_hsync-inicio_hsync);
                errors = errors + 1;
            end
            if(last_hsync!=64'b0)
                if (final_hsync-last_hsync != 16800)begin 
                    if(errors<20) $display("ERROR: tiempo de fila: %0d", final_hsync-last_hsync);
                    errors = errors + 1;
                end
            last_hsync = final_hsync;
        end
    end

    always @(vsync) if (~rst) begin
        if(vsync) begin
            inicio_vsync = $time ;
            end
        else begin
            final_vsync = $time ;
            if (inicio_vsync!=64'b0 && final_vsync-inicio_vsync != 50400)begin
                if(errors<20) $display("ERROR: tiempo de vsync: %0d", final_vsync-inicio_vsync);
                errors = errors + 1;
            end
            if(last_vsync!=64'b0)
                if (final_vsync-last_vsync != 13910400) begin
                    if(errors<20) $display("ERROR: tiempo de cuadro: %0d", final_vsync-last_vsync);
                    errors = errors + 1;
                end
            last_vsync = final_vsync;
        end    
    end

    always @(posedge clk_pix) begin
        if(curr_x < 1280 && curr_y < 800) it_was_visible <= 1'b1;
        else it_was_visible <= 1'b0;

        if (it_was_visible) begin
            if (pix_r != draw_r || pix_g != draw_g || pix_b != draw_b) begin
                if(errors < 20)begin
                    $display("ERROR: pix_* != draw_* at %0d, %0d", curr_x, curr_y);
                end
                errors = errors + 1;
            end
        end else begin
            if (pix_r != 4'b0 || pix_g != 4'b0 || pix_b != 4'b0) begin
                if(errors < 20)begin
                    $display("ERROR: pix_* != 0 at %0d, %0d", curr_x, curr_y);
                end
                errors = errors + 1;
            end
        end
    end
  

endmodule
