// Alan's provisional G5 checks, expectations independently from locked rules.
module score_directed_tb;
    logic clk=0, rst=1, new_match=0, step_outcome=0;
    logic [1:0] goal_sel=0, collected_slot_p1=0, collected_slot_p2=0;
    logic crashed_p1=0, crashed_p2=0, collected_valid_p1=0, collected_valid_p2=0;
    logic [5:0] points_p1, points_p2, points_goal;
    logic [1:0] lives_p1, lives_p2, result;
    integer checks=0;
    score_unit dut(.*);
    always #5 clk=~clk;
    task automatic check(input integer p1,p2,l1,l2,goal,res);
        if ({points_p1,points_p2,lives_p1,lives_p2,points_goal,result} !==
            {6'(p1),6'(p2),2'(l1),2'(l2),6'(goal),2'(res)})
            $fatal(1,"Check %0d got %0d,%0d lives %0d,%0d goal %0d result %0d expected %0d,%0d %0d,%0d %0d %0d",
                   checks,points_p1,points_p2,lives_p1,lives_p2,points_goal,result,p1,p2,l1,l2,goal,res);
        checks++;
    endtask
    task automatic start(input logic [1:0] sel);
        @(negedge clk); goal_sel=sel; new_match=1; step_outcome=1;
        @(posedge clk); #1; check(0,0,3,3,10*(int'(sel)+1),0);
        @(negedge clk); new_match=0; step_outcome=0;
    endtask
    task automatic outcome(input logic c1,c2, input integer r1,r2);
        @(negedge clk); step_outcome=1; crashed_p1=c1; crashed_p2=c2;
        collected_valid_p1=(r1>=0); collected_slot_p1=2'(r1);
        collected_valid_p2=(r2>=0); collected_slot_p2=2'(r2);
        @(posedge clk); #1;
        @(negedge clk); step_outcome=0;
    endtask
    initial begin
        @(posedge clk); #1; check(0,0,3,3,10,0);   // reset: Lives 3 (idle view 03)
        @(negedge clk); rst=0;
        start(3);
        outcome(0,0,0,1); check(1,1,3,3,40,0);
        outcome(1,0,-1,2); check(1,7,2,3,40,0);
        repeat(4) @(posedge clk); #1; check(1,7,2,3,40,0); // Round wait
        outcome(0,1,1,-1); check(5,7,2,2,40,0);
        outcome(1,1,-1,-1); check(5,7,1,1,40,0); // Head-on: no Bonus
        outcome(1,1,-1,-1); check(5,7,0,0,40,2);
        outcome(0,0,2,1); check(5,7,0,0,40,2); // terminal hold
        start(3); repeat(3) outcome(1,1,-1,-1); check(0,0,0,0,40,3);
        start(3); repeat(3) outcome(1,0,-1,-1); check(0,9,0,3,40,2);
        start(3); repeat(3) outcome(0,1,-1,-1); check(9,0,3,0,40,1);
        start(0); repeat(9) outcome(0,0,0,-1);
        outcome(0,0,1,-1); check(10,0,3,3,10,1);
        start(0); repeat(9) outcome(0,0,-1,0);
        outcome(0,0,-1,2); check(0,12,3,3,10,2);
        start(0); repeat(9) outcome(0,0,0,1);
        outcome(0,0,2,0); check(12,10,3,3,10,1);
        start(0); repeat(9) outcome(0,0,0,1);
        outcome(0,0,0,2); check(10,12,3,3,10,2);
        start(0); repeat(9) outcome(0,0,0,1);
        outcome(0,0,0,1); check(10,10,3,3,10,3);
        start(0); repeat(2) outcome(1,0,-1,-1);
        outcome(1,0,-1,2); check(0,12,0,3,10,2);
        start(3); repeat(39) outcome(0,0,0,-1);
        outcome(0,1,2,-1); check(45,0,3,2,40,1);
        for (integer sel=0; sel<4; sel++) begin
            start(2'(sel));
            @(negedge clk); goal_sel=2'(3-sel);
            outcome(0,0,0,-1); check(1,0,3,3,10*(sel+1),0);
        end
        // Adversarial Crash + collection (outside legal resolver traffic):
        // checks goal priority over final Life loss as in model.match_result.
        start(0); repeat(2) outcome(1,1,-1,-1);
        repeat(9) outcome(0,0,0,-1);
        outcome(1,1,0,-1); check(10,0,0,0,10,1);
        @(negedge clk); rst=1; new_match=1; step_outcome=1;
        @(posedge clk); #1; check(0,0,3,3,10,0);   // reset: Lives 3 (idle view 03)
        $display("Directed checks: %0d",checks);
        $display("PASS score_directed_tb"); $finish;
    end
    initial begin #100000; $fatal(1,"Timeout"); end
endmodule
