// Alan's provisional G5 model replay bench; all inputs synchronous, no CDC.
module score_model_tb;
    logic clk=0, rst=1, new_match=0, step_outcome=0;
    logic [1:0] goal_sel=0, collected_slot_p1=0, collected_slot_p2=0;
    logic crashed_p1=0, crashed_p2=0, collected_valid_p1=0, collected_valid_p2=0;
    logic [5:0] points_p1, points_p2, points_goal;
    logic [1:0] lives_p1, lives_p2, result;
    score_unit dut(.*);
    always #5 clk=~clk;
    integer fd, rc, rows=0;
    integer nm, st, gs, c1, c2, v1, s1, v2, s2, p1, p2, l1, l2, goal, res;
    initial begin
        @(posedge clk); #1;
        fd=$fopen("src/prototypes/core_blocks/score/model_vectors.txt", "r");
        if (!fd) $fatal(1,"Cannot open vectors");
        while (!$feof(fd)) begin
            rc=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
                       nm,st,gs,c1,c2,v1,s1,v2,s2,p1,p2,l1,l2,goal,res);
            if (rc != 15) $fatal(1,"Malformed vector row %0d",rows);
            @(negedge clk);
            rst=0; new_match=1'(nm); step_outcome=1'(st); goal_sel=2'(gs);
            crashed_p1=1'(c1); crashed_p2=1'(c2);
            collected_valid_p1=1'(v1); collected_slot_p1=2'(s1);
            collected_valid_p2=1'(v2); collected_slot_p2=2'(s2);
            @(posedge clk); #1;
            if ({points_p1,points_p2,lives_p1,lives_p2,points_goal,result} !==
                {6'(p1),6'(p2),2'(l1),2'(l2),6'(goal),2'(res)})
                $fatal(1,"Model mismatch row %0d", rows);
            rows=rows+1;
        end
        $fclose(fd);
        if (rows < 20000) $fatal(1,"Insufficient vectors");
        $display("Compared %0d rows, zero model mismatches",rows);
        $display("PASS score_model_tb"); $finish;
    end
    initial begin #10000000; $fatal(1,"Timeout"); end
endmodule
