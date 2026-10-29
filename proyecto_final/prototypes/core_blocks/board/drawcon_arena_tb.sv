// Builder independent physical raster check: two frames, actual RAM latency.
module drawcon_arena_tb;
    logic clk=0,rst=1;
    always #6 clk=~clk;
    logic [10:0] x,y;
    logic [3:0] dr,dg,db,r,g,b,data,ar;
    logic [12:0] addr,aa=0;
    logic we=0; logic [3:0] wd=0;
    logic hs,vs;
    integer h=0,v=0,px,py,checks=0;
    logic [11:0] want;
    arena_map ram(clk,aa,we,wd,ar,addr,data);
    drawcon_arena draw(x,y,data,1'b1,addr,dr,dg,db);
    vga_out video(clk,rst,dr,dg,db,x,y,,r,g,b,hs,vs);
    function automatic logic [11:0] colour(input integer c);
        case(c)
            0:colour=12'h000;1:colour=12'h444;2:colour=12'h08f;3:colour=12'h0ff;
            4:colour=12'hf80;5:colour=12'hff0;6:colour=12'hf00;7:colour=12'h888;
            8:colour=12'h0f0;9:colour=12'h80f;10:colour=12'hf0f;default:colour=12'h888;
        endcase
    endfunction
    initial begin
        for(integer a=0;a<8192;a=a+1) begin
            @(negedge clk); aa=a;wd=(a%128+a/128)%16;we=1;
        end
        @(negedge clk);we=0;rst=0;
        repeat(1680*828*2) begin
            @(posedge clk); #1;
            px=h-336;py=v-27;want=0;
            if(px>=0 && px<1280 && py>=0 && py<800) begin
                want=colour(((px/16)+(py/16))%16);
                if(px<10 || px>=1270 || py<10 || py>=790) want=12'hfff;
                checks++;
            end
            if({r,g,b}!==want || hs!==(h>=136) || vs!==(v<3))
                $fatal(1,"raster (%0d,%0d) rgb=%h want=%h",h,v,{r,g,b},want);
            if(h==1679) begin h=0;if(v==827)v=0;else v++;end else h++;
        end
        $display("PASS drawcon_arena_tb visible=%0d all Cell edges, porches, frame wrap",checks);$finish;
    end
endmodule
