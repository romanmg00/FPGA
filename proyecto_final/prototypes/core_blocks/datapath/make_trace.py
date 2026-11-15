"""Run headless from prototipos/tron_fpga: python3 ../../proyecto_final/prototypes/core_blocks/datapath/make_trace.py"""
from pathlib import Path
import sys
sys.path.insert(0, str(Path.cwd()))
from model.game_top import Game
from model.scenario import parse, run
from model.params import G_PLAY, SW_PAUSE
from model.mailbox import OP_PREPARE
OUT=Path(__file__).resolve().parent

def cell(c): return -1 if c is None else c[0]+128*c[1]
def axes(a):
    v,h=a
    return (8 | (4 if v==2 else 0) if v is not None else 0) | (2 | (1 if h==3 else 0) if h is not None else 0)
class TraceGame(Game):
    def reset(self):
        super().reset(); self.reset_pending=True
    def tick(self, inputs):
        paused=bool(self.sw_sync[-1]>>SW_PAUSE&1)
        running=self.phase==G_PLAY and not paused
        launch=running and self.step_cnt==self.step_period-1
        aa=[axes(a) for a in self.batch_cap.axes]
        seq=self.mbox.cmd.seq
        reset=self.reset_pending;self.reset_pending=False
        before=len(self.ctrl.placements)
        super().tick(inputs)
        prep=self.mbox.cmd.seq!=seq and self.mbox.cmd.op==OP_PREPARE
        starts=self.rules.starts
        nm=prep and self.mbox.cmd.new_match
        # Metadata belongs to unselected match_ctrl; no expected heads/scores supplied.
        kind=2 if self._trace_log and self._trace_log[-1].startswith(f'tick={self.ticks} ') and len(self._trace_log)>self.nlog else 0
        if kind: kind=1 if 'step=0 ' in self._trace_log[-1] else 2
        self.nlog=len(self._trace_log)
        placements=self.ctrl.placements[before:]
        rr=[-2,-2,-2]
        for slot,p in placements: rr[slot]=cell(p.cell)
        self.rows.append([int(reset),int(prep),int(nm),int(paused),int(running),int(launch),*aa,
          cell(starts[0][:2]),cell(starts[1][:2]),starts[0][2],starts[1][2],self.goal//10-1,
          *rr,kind,self.ticks,self.round_index,self.step_count,self.phase])
for path in sorted(Path('scenarios').glob('*.txt')):
    sc=parse(path.read_text());g=TraceGame(sc.rules());g.rows=[];g._trace_log=[];g.nlog=0
    # scenario.run installs its callback; mirror emitted lines before finishing row.
    original=g._fast_after_edge
    def fast(g=g,original=original):
        cb=g.steplog
        def emit(line): cb(line);g._trace_log.append(line)
        g.steplog=emit;original();g.steplog=cb
    g._fast_after_edge=fast
    log=run(sc,g)
    (OUT/(path.stem+'.trace')).write_text('\n'.join(' '.join(map(str,r)) for r in g.rows)+'\n')
    (OUT/(path.stem+'.model.log')).write_text('\n'.join(log)+'\n')
    print(path.stem,len(g.rows),len(log))
