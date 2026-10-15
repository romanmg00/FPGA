module counters(
    input  logic        clk, 
    input  logic        rst, 
    output logic [10:0]  hcnt, 
    output logic [9:0] vcnt
);
    
    always_ff @(posedge clk) begin
        if(rst) begin
            hcnt<=11'd0;
            vcnt<=10'd0;
        end
        else if (hcnt == 11'd1679) begin
            hcnt<=11'd0;
            if(vcnt==10'd827) begin
                vcnt<=10'd0;
            end
            else begin
                vcnt<=vcnt+1'b1;
            end
        end
        else 
            hcnt<=hcnt+1'b1;
    end


endmodule
