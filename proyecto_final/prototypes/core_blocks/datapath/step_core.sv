// Roman G1/G2 plus Alan G5 composition; clk is clk_juego. ALL ports provisional.
// No CDC hardware: external SIMULATION bridge supplies stable response bus.
// One outstanding command, toggled tag; capture stage deliberately models k+2.
// rst > load > normal. Pause inhibits resolve, but issued COMMIT can retire.
module step_core (
 input logic clk,rst,load,new_match,paused,apply,launch,
 input logic [12:0] start_p1,start_p2,
 input logic [1:0] dir_p1,dir_p2,goal_sel,
 input logic [3:0] axes_p1,axes_p2,
 input logic rsp_tag,
 input logic [3:0] rsp_p1,rsp_p2,
 output logic cmd_tag,
 output logic [1:0] cmd_op,
 output logic [12:0] old_p1,old_p2,target_p1,target_p2,
 output logic survive_p1,survive_p2,
 output logic [12:0] head_p1,head_p2,
 output logic [1:0] shown_p1,shown_p2,
 output logic crashed_p1,crashed_p2,head_on,outcome,ready,
 output logic [5:0] points_p1,points_p2,points_goal,
 output logic [1:0] lives_p1,lives_p2,result
);
 import game_pkg::*;
 logic [1:0] state,heading_p1,heading_p2,pending_p1,pending_p2,chosen_p1,chosen_p2,launched_p1,launched_p2;
 logic cap_tag,resolve_now,c1,c2,ho;
 logic [3:0] cap_p1,cap_p2;
 logic [12:0] next_p1,next_p2,new_p1,new_p2;
 logic [1:0] slot_p1,slot_p2;
 turn_unit t1(clk,rst,load,dir_p1,axes_p1[3],axes_p1[2],axes_p1[1],axes_p1[0],apply,launch,heading_p1,pending_p1);
 turn_unit t2(clk,rst,load,dir_p2,axes_p2[3],axes_p2[2],axes_p2[1],axes_p2[0],apply,launch,heading_p2,pending_p2);
 always_comb begin
  chosen_p1=pending_p1; chosen_p2=pending_p2;
  if(apply) begin
   if(heading_p1[0] && axes_p1[3]) chosen_p1=axes_p1[2]?DIR_DOWN:DIR_UP;
   if(!heading_p1[0] && axes_p1[1]) chosen_p1=axes_p1[0]?DIR_LEFT:DIR_RIGHT;
   if(heading_p2[0] && axes_p2[3]) chosen_p2=axes_p2[2]?DIR_DOWN:DIR_UP;
   if(!heading_p2[0] && axes_p2[1]) chosen_p2=axes_p2[0]?DIR_LEFT:DIR_RIGHT;
  end
  ready=(state==0 || (state==2 && cap_tag==cmd_tag));
  resolve_now=(state==1 && cap_tag==cmd_tag && !paused);
 end
 next_cell n1(head_p1,chosen_p1,next_p1);
 next_cell n2(head_p2,chosen_p2,next_p2);
 step_resolve sr(head_p1,head_p2,target_p1,target_p2,cap_p1,cap_p2,new_p1,new_p2,c1,c2,ho,slot_p1,slot_p2);
 score_unit score(clk,rst,new_match,resolve_now,goal_sel,c1,c2,(slot_p1!=3),(slot_p2!=3),slot_p1,slot_p2,points_p1,points_p2,lives_p1,lives_p2,points_goal,result);
 always_ff @(posedge clk) begin
  if(rst) begin
   state<=0;cmd_tag<=0;cmd_op<=0;cap_tag<=0;cap_p1<=0;cap_p2<=0;
   head_p1<=0;head_p2<=0;shown_p1<=0;shown_p2<=0;launched_p1<=0;launched_p2<=0;
   old_p1<=0;old_p2<=0;target_p1<=0;target_p2<=0;survive_p1<=0;survive_p2<=0;
   crashed_p1<=0;crashed_p2<=0;head_on<=0;outcome<=0;
  end else begin
   cap_tag<=rsp_tag;cap_p1<=rsp_p1;cap_p2<=rsp_p2;outcome<=0;
   if(load) begin
    state<=0;head_p1<=start_p1;head_p2<=start_p2;shown_p1<=dir_p1;shown_p2<=dir_p2;
    crashed_p1<=0;crashed_p2<=0;head_on<=0;
   end else begin
    if(state==2 && cap_tag==cmd_tag) state<=0;
    if(resolve_now) begin
     state<=2;cmd_tag<=!cmd_tag;cmd_op<=3;
     old_p1<=head_p1;old_p2<=head_p2;survive_p1<=!c1;survive_p2<=!c2;
     head_p1<=new_p1;head_p2<=new_p2;shown_p1<=launched_p1;shown_p2<=launched_p2;
     crashed_p1<=c1;crashed_p2<=c2;head_on<=ho;outcome<=1;
    end
    if(launch && ready) begin
     state<=1;cmd_tag<=!cmd_tag;cmd_op<=2;target_p1<=next_p1;target_p2<=next_p2;
     launched_p1<=chosen_p1;launched_p2<=chosen_p2;
    end
   end
  end
 end
endmodule
