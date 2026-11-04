module position_logic (
    input  logic        clk,        // clk_juego (~60 Hz)
    input  logic        rst,
    input  logic [4:0]  btn,        // [0] arriba, [1] abajo, [2] izquierda, [3] derecha
    output logic [10:0] blkpos_x, blkpos_y
);

    always_ff @(posedge clk) begin
        if(rst) begin
            blkpos_x <= 11'd320;
            blkpos_y <= 11'd432;
        end
        else begin
            if(btn[0] && blkpos_y > 11'd80) blkpos_y <= blkpos_y - 11'd4;   //up
            if(btn[1] && blkpos_y < 11'd768) blkpos_y <= blkpos_y + 11'd4;   //down
            if(btn[2] && blkpos_x > 11'd16) blkpos_x <= blkpos_x - 11'd4;     //left
            if(btn[3] && blkpos_x < 11'd1248) blkpos_x <= blkpos_x + 11'd4;   //right
        end
    end

endmodule
