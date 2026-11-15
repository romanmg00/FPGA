// Owner Roman G1; builder self-check, provisional game ports; no CDC.
module turn_unit_tb;
    import game_pkg::*;
    logic clk=0,rst=0,load=0,vv=0,vd=0,hv=0,hl=0,apply=0,launch=0;
    logic [1:0] lh=0,heading,pending;
    integer fd,n,count=0,er,el,elh,evv,evd,ehv,ehl,ea,ela,eh,ep;
    turn_unit dut(clk,rst,load,lh,vv,vd,hv,hl,apply,launch,heading,pending);
    always #5 clk=~clk;
    initial begin
        fd=$fopen("src/prototypes/core_blocks/step/turn_vectors.txt","r");
        if (!fd) $fatal(1,"missing turn vectors");
        while (!$feof(fd)) begin
            n=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d\n",er,el,elh,evv,evd,ehv,ehl,ea,ela,eh,ep);
            if(n!=11) $fatal(1,"bad vector");
            @(negedge clk);
            rst=er;load=el;lh=elh;vv=evv;vd=evd;hv=ehv;hl=ehl;apply=ea;launch=ela;
            @(posedge clk); #1;
            if(heading!==eh[1:0] || pending!==ep[1:0]) $fatal(1,"turn mismatch row %0d",count);
            count=count+1;
        end
        $fclose(fd);
        if(count<2700) $fatal(1,"short file");
        $display("PASS turn_unit_tb vectors=%0d zero mismatches",count);$finish;
    end
endmodule
