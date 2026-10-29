// Owner Roman G2; builder self-check, provisional combinational ports; no CDC.
module step_resolve_tb;
    import game_pkg::*;
    logic [12:0] h1,h2,t1,t2,n1,n2,nh,nt;
    logic [3:0] c1,c2;
    logic cr1,cr2,ho;
    logic [1:0] co1,co2,dir;
    integer fd,n,count=0,a,d,x,y,ex,ey;
    integer ih1,ih2,it1,it2,ic1,ic2,en1,en2,ecr1,ecr2,eho,eco1,eco2;
    step_resolve dut(h1,h2,t1,t2,c1,c2,n1,n2,cr1,cr2,ho,co1,co2);
    next_cell nc(nh,dir,nt);
    initial begin
        for(a=0;a<8192;a=a+1) begin
            for(d=0;d<4;d=d+1) begin
                nh=a;dir=d;x=a%128;y=a/128;ex=x;ey=y;
                case(d)
                    0:ey=(y+63)%64;
                    1:ex=(x+1)%128;
                    2:ey=(y+1)%64;
                    3:ex=(x+127)%128;
                endcase
                #1;
                if(nt!==13'(ey*128+ex)) $fatal(1,"next_cell mismatch %0d %0d",a,d);
            end
        end
        fd=$fopen("src/prototypes/core_blocks/step/step_vectors.txt","r");
        if(!fd) $fatal(1,"missing step vectors");
        while(!$feof(fd)) begin
            n=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d\n",ih1,ih2,it1,it2,ic1,ic2,en1,en2,ecr1,ecr2,eho,eco1,eco2);
            if(n!=13) $fatal(1,"bad step vector");
            h1=ih1;h2=ih2;t1=it1;t2=it2;c1=ic1;c2=ic2;#1;
            if({n1,n2,cr1,cr2,ho,co1,co2}!=={en1[12:0],en2[12:0],ecr1[0],ecr2[0],eho[0],eco1[1:0],eco2[1:0]}) $fatal(1,"step mismatch row %0d",count);
            count=count+1;
        end
        if(count<12000) $fatal(1,"short file");
        $fclose(fd);
        $display("PASS step_resolve_tb vectors=%0d next_cell=32768 zero mismatches",count);$finish;
    end
endmodule
