// Builder integration evidence, not official bench. ALL boundary ports provisional.
// SIMULATION ONLY bridge: procedural waits and coherent unsynchronized buses.
// NEVER synthesize this bridge; no metastability, CDC or reset-epoch proof.
module datapath_tb;
 import game_pkg::*;
 parameter integer N=10000, PHASE=2, FORWARD=0, BACKWARD=0;
 logic clk=0,fast=0,rst=1,load=0,new_match=0,paused=0,apply=0,launch=0;
 logic [12:0] start_p1=0,start_p2=0;
 logic [1:0] dir_p1=0,dir_p2=0,goal_sel=0;
 logic [3:0] axes_p1=0,axes_p2=0;
 logic rsp_tag=0,cmd_tag;
 logic [3:0] rsp_p1=0,rsp_p2=0;
 logic [1:0] cmd_op,shown_p1,shown_p2,lives_p1,lives_p2,result;
 logic [12:0] old_p1,old_p2,target_p1,target_p2,head_p1,head_p2;
 logic survive_p1,survive_p2,crashed_p1,crashed_p2,head_on,outcome,ready;
 logic [5:0] points_p1,points_p2,points_goal;
 step_core dut(.*);
 always #5 fast=~fast;
 initial begin #(PHASE); forever #(N*5) clk=~clk; end
 logic av=0,ab,ad;logic [1:0] op=0;
 logic [12:0] o1=0,o2=0,t1=0,t2=0;
 logic s1=0,s2=0;logic [3:0] ac1,ac2,br;
 arena_ctrl arena(fast,rst,av,op,o1,o2,t1,t2,s1,s2,ab,ad,ac1,ac2,13'd0,br);
 integer fd,fl,rc,row,scenario,hazards=0,outcomes=0;
 integer z[0:20]; integer slots[0:2]; integer repl[0:2]; integer ticks=0;
 always @(posedge clk) if(rst) ticks<=0; else ticks<=ticks+1;
 string name,path,logpath;
 logic seen=0,bridge_busy=0;
 integer bridge_repl[0:2]; realtime started,max_read=0,max_commit=0;
 logic [3:0] oracle_code;
 task automatic command(input integer operation,a,b,c,d,sp1,sp2);
  @(negedge fast);while(ab) @(negedge fast);
  op=operation;o1=a;o2=b;t1=c;t2=d;s1=sp1;s2=sp2;av=1;
  @(negedge fast);av=0;
  wait(ad);@(negedge fast);
 endtask
 // Test-only payload override: controller owns all addresses and write strobes.
 // Its public interface has no generic Reward write. Both crash writes target
 // the same oracle cell; force only data during that local COMMIT, then release.
 task automatic put(input integer address,code);
  oracle_code=code;
  force arena.a_wdata=oracle_code;
  command(3,address,address,address,address,0,0);
  release arena.a_wdata;
 endtask
 initial forever begin
  @(negedge fast);
  if(rst) begin seen=cmd_tag;rsp_tag=cmd_tag;end
  else if(cmd_tag!=seen) begin
   bridge_busy=1;seen=cmd_tag;started=$realtime;
   for(integer k=0;k<3;k++) bridge_repl[k]=repl[k];
   repeat(FORWARD) @(posedge fast);
   command(cmd_op,old_p1,old_p2,target_p1,target_p2,survive_p1,survive_p2);
   rsp_p1=ac1;rsp_p2=ac2;
   if(cmd_op==3) for(integer k=0;k<3;k++) if(bridge_repl[k]>=0) put(bridge_repl[k],8+k);
   repeat(BACKWARD) @(posedge fast);
   if(cmd_op==2 && $realtime-started>max_read) max_read=$realtime-started;
   if(cmd_op==3 && $realtime-started>max_commit) max_commit=$realtime-started;
   rsp_tag=seen;bridge_busy=0;
  end
 end
 function automatic string heading(input integer h);
  case(h) 0:heading="U";1:heading="R";2:heading="D";3:heading="L";endcase
 endfunction
 function automatic string phase_name(input integer p);
  case(p) 0:phase_name="IDLE";1:phase_name="PLAY";2:phase_name="CRASH";3:phase_name="READY";4:phase_name="MATCH_OVER";5:phase_name="PREP";default:phase_name="?";endcase
 endfunction
 function automatic string cell_name(input integer p);
  if(p<0) cell_name="-";else cell_name=$sformatf("%0d,%0d",p%128,p/128);
 endfunction
 function automatic string result_name(input integer r);
  case(r) 0:result_name="-";1:result_name="P1";2:result_name="P2";3:result_name="draw";endcase
 endfunction
 initial begin
  // Scenario manifest has one basename per line; no plusargs required.
  fl=$fopen("src/prototypes/core_blocks/datapath/manifest.txt","r");
  if(!fl) $fatal(1,"missing manifest");
  while(!$feof(fl)) begin
   rc=$fscanf(fl,"%s\n",name);
   if(rc!=1) $fatal(1,"manifest row");
   @(negedge clk);rst=1;load=0;launch=0;apply=0;new_match=0;
   @(negedge clk);rst=0;
   path={"src/prototypes/core_blocks/datapath/",name,".trace"};
   logpath={name,".hdl.log"};fd=$fopen(path,"r");scenario=$fopen(logpath,"w");row=0;
   if(!fd || !scenario) $fatal(1,"file open");
   for(integer k=0;k<3;k++) slots[k]=-1;
   while(!$feof(fd)) begin
    rc=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",z[0],z[1],z[2],z[3],z[4],z[5],z[6],z[7],z[8],z[9],z[10],z[11],z[12],z[13],z[14],z[15],z[16],z[17],z[18],z[19],z[20]);
    if(rc!=21) $fatal(1,"trace parse %s row %0d count %0d",name,row,rc);
    // reset in a scenario consumes a separate reset edge, preserving tick 1.
    if(z[0]) begin rst=1;@(posedge clk);#1;rst=0;end
    load=z[1];new_match=z[2];paused=z[3];apply=z[4];launch=z[5];axes_p1=z[6];axes_p2=z[7];
    start_p1=z[8];start_p2=z[9];dir_p1=z[10];dir_p2=z[11];goal_sel=z[12];
    if(launch && !ready) begin hazards++;$display("CADENCE_OVERRUN %s tick=%0d",name,z[17]);end
    @(posedge clk);#1;
    for(integer k=0;k<3;k++) repl[k]=z[13+k];
    if(load) begin
     wait(!bridge_busy);command(1,0,0,0,0,0,0);
     command(3,start_p1,start_p2,start_p1,start_p2,1,1);
    end
    // Replacements occur after this tick's real COMMIT, before next READ2.
    if(z[13]!=-2 || z[14]!=-2 || z[15]!=-2) begin
     for(integer k=0;k<3;k++) if(z[13+k]!=-2) begin
      slots[k]=z[13+k];if(load && slots[k]>=0) put(slots[k],8+k);
     end
    end
    if(outcome || z[16]==1) begin
     if(outcome) begin
      outcomes++;
      if(head_on && !(crashed_p1 && crashed_p2)) $fatal(1,"Head-on must crash both");
      if(crashed_p1 && head_p1!==old_p1) $fatal(1,"Crashed P1 moved");
      if(crashed_p2 && head_p2!==old_p2) $fatal(1,"Crashed P2 moved");
     end
     $fwrite(scenario,"tick=%0d round=%0d step=%0d phase=%s p1=%0d,%0d,%s p2=%0d,%0d,%s crash=%0d%0d points=%0d,%0d lives=%0d,%0d goal=%0d r0=%s r1=%s r2=%s result=%s\n",ticks,z[18],z[19],phase_name(z[20]),head_p1[6:0],head_p1[12:7],heading(shown_p1),head_p2[6:0],head_p2[12:7],heading(shown_p2),crashed_p1,crashed_p2,points_p1,points_p2,lives_p1,lives_p2,points_goal,cell_name(slots[0]),cell_name(slots[1]),cell_name(slots[2]),result_name(result));
    end
    row++;#1;
   end
   $fclose(fd);$fclose(scenario);$display("REPLAY %s rows=%0d",name,row);
  end
  $display("MEASURE N=%0d phase=%0d forward=%0d backward=%0d outcomes=%0d overruns=%0d",N,PHASE,FORWARD,BACKWARD,outcomes,hazards);
  $display("MAX_RTT_FAST read=%0.1f commit=%0.1f",max_read/10,max_commit/10);
  $display("PASS datapath_tb");$finish;
 end
 initial begin #(64'd100000000000); $fatal(1,"timeout");end
endmodule
