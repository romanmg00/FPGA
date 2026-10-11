module counters(
    input  logic        clk, 
    input  logic        rst, 
    output logic [9:0]  count
);
    
    always_ff @(posedge clk) begin
        if (count == 10'd799 || rst)
            count<=10'd0;
        else 
            count<=count+1'b1;
    end


endmodule
