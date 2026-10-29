// Alan integration. PROVISIONAL BOARD TEST PATTERN, not game_top/the game.
// Crossings: CPU reset -> per-domain 2FF; buttons/SW0 -> io syncs;
// registered game Gray tick -> 2FF pixel bank (TEST-PATTERN crossing ONLY).
// No game-to-Arena transfer, coherent game snapshot or mailbox selected.
module core_board_top #(
    parameter integer debounce_hz=83460000,
    parameter integer game_half_cycles=39063
)(
    input logic clk, cpu_resetn,
    input logic [4:0] btn,
    input logic [15:0] sw,
    output logic [3:0] vga_r,vga_g,vga_b,
    output logic vga_hs,vga_vs,
    output logic [6:0] seg,
    output logic [7:0] an,
    output logic [15:0] led
);
    logic clk_in,clk_pix,clk_base,clk_juego;
`ifdef SYNTHESIS
    IBUF u_input(.I(clk),.O(clk_in));
`else
    assign clk_in=clk;
`endif
    video_pixel_clock u_pixel(.clk_in1(clk_in),.clk_out1(clk_pix));
    video_game_clock u_base(.clk_in1(clk_in),.clk_out1(clk_base));
    game_clk_div #(.half_cycles(game_half_cycles)) u_div(.clk_base(clk_base),.rst(1'b0),.clk_juego(clk_juego));
    logic reset_request,rst_pix,rst_game,pause_pattern;
    logic [15:0] sw_sync;
    for(genvar i=0;i<16;i=i+1) begin: switches
        sync_2ff u_sync(clk_pix,rst_pix,sw[i],sw_sync[i]);
    end
    assign reset_request=~cpu_resetn;
    board_reset_sync u_reset_pix(clk_pix,reset_request,rst_pix);
    board_reset_sync u_reset_game(clk_juego,reset_request,rst_game);
    assign pause_pattern=sw_sync[0];
    logic [4:0] press;
    btn_debounce #(.CLK_HZ(debounce_hz)) u_buttons(clk_pix,rst_pix,btn,press);
    logic [5:0] tick_binary=0,tick_gray=0;
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic [5:0] gray_meta=0,gray_settled=0;
    logic [5:0] tick_fast;
    always_ff @(posedge clk_juego) begin
        if(rst_game) begin tick_binary<=0; tick_gray<=0; end
        else begin
            tick_binary<=tick_binary+6'd1;
            tick_gray<=((tick_binary+6'd1)>>1)^(tick_binary+6'd1);
        end
    end
    always_ff @(posedge clk_pix) begin
        gray_meta<=tick_gray; gray_settled<=gray_meta;
    end
    always_comb begin
        tick_fast[5]=gray_settled[5];
        for(integer i=4;i>=0;i=i-1) tick_fast[i]=tick_fast[i+1]^gray_settled[i];
    end
    seg7_driver u_display(clk_pix,rst_pix,tick_fast,6'd0,2'd0,2'd0,1'b0,seg,an);
    logic [10:0] curr_x,curr_y;
    logic [3:0] dr,dg,db,b_data;
    logic [12:0] b_addr,head,target;
    logic busy,done,valid,ready;
    logic [1:0] op;
    logic [3:0] unused1,unused2;
    typedef enum logic [2:0] {CLEAR_SEND,CLEAR_WAIT,SEED_SEND,SEED_WAIT,IDLE,MOVE_SEND,MOVE_WAIT} state_t;
    state_t state;
    assign valid=(state==CLEAR_SEND || state==SEED_SEND || state==MOVE_SEND);
    assign op=(state==CLEAR_SEND)?2'd1:2'd3;
    // P2 fixed test marker at (59,27); same old/target writes head last.
    arena_ctrl u_arena(clk_pix,rst_pix,valid,op,head,13'd3515,target,13'd3515,
        1'b1,1'b1,busy,done,unused1,unused2,b_addr,b_data);
    always_ff @(posedge clk_pix) begin
        if(rst_pix) begin state<=CLEAR_SEND; head<=13'd3476; target<=13'd3476; ready<=0; end
        else case(state)
            CLEAR_SEND: if(!busy) state<=CLEAR_WAIT;
            CLEAR_WAIT: if(done) state<=SEED_SEND;
            SEED_SEND: if(!busy) state<=SEED_WAIT;
            SEED_WAIT: if(done) begin ready<=1; state<=IDLE; end
            IDLE: if((|press) && !pause_pattern && head[6:0]<78) begin target<=head+13'd1;state<=MOVE_SEND;end
            MOVE_SEND: if(!busy) state<=MOVE_WAIT;
            MOVE_WAIT: if(done) begin head<=target;state<=IDLE;end
            default: state<=CLEAR_SEND;
        endcase
    end
    drawcon_arena u_draw(curr_x,curr_y,b_data,ready,b_addr,dr,dg,db);
    vga_out u_vga(clk_pix,rst_pix,dr,dg,db,curr_x,curr_y,,vga_r,vga_g,vga_b,vga_hs,vga_vs);
    always_comb begin
        led=0; led[15:4]=sw_sync[15:4]; led[3]=^sw_sync[3:1]; led[0]=tick_binary[5]; led[1]=ready; led[2]=pause_pattern;
    end
endmodule
