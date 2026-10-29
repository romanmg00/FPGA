"""Roman G1/G2 provisional evidence. Run with python3 from prototipos/tron_fpga/."""
from pathlib import Path
import random
import sys
sys.path.insert(0, str(Path.cwd()))
from model.turn_unit import TurnUnit, next_cell
from model.step_unit import step_resolve
out=Path(__file__).resolve().parent
rng=random.Random(256)
pack=lambda p:p[0]|p[1]<<7
with (out/'step_vectors.txt').open('w') as f:
    def emit(h,t,c,expected=None):
        r=step_resolve(h,t,c)
        result=(*r.heads,*map(int,r.crashed),int(r.head_on),*(3 if x is None else x for x in r.collected))
        if expected is not None: assert result==expected,(result,expected)
        f.write(' '.join(map(str,(*map(pack,h),*map(pack,t),*c,*map(pack,r.heads),*result[2:])))+'\n')
    h=((10,20),(30,20));t=((11,20),(29,20))
    for code in (1,2,3,4,5,6,7,11,12,13,14,15):
        emit(h,t,(code,0),(h[0],t[1],1,0,0,3,3))
        emit(h,t,(0,code),(t[0],h[1],0,1,0,3,3))
    emit(h,t,(1,4),(*h,1,1,0,3,3))
    for slot in range(3):
        emit(h,t,(1,8+slot),(h[0],t[1],1,0,0,3,slot))
        emit(h,t,(8+slot,1),(t[0],h[1],0,1,0,slot,3))
        emit(h,(t[0],t[0]),(8+slot,8+slot),(*h,1,1,1,3,3))
    emit(h,(t[0],t[0]),(0,0),(*h,1,1,1,3,3))
    emit(h,(h[1],h[0]),(0,0),(*h,1,1,1,3,3))
    emit(h,(h[1],h[0]),(5,3),(*h,1,1,1,3,3))
    emit(h,(h[1],t[1]),(5,0),(h[0],t[1],1,0,0,3,3))
    assert next_cell((0,20),3)==(127,20)
    emit(((0,20),h[1]),((127,20),t[1]),(1,0),((0,20),t[1],1,0,0,3,3))
    for a in range(16):
        for b in range(16): emit(h,t,(a,b))
    for i in range(12000):
        hs=tuple((rng.randrange(128),rng.randrange(64)) for _ in range(2))
        ts=tuple(next_cell(p,rng.randrange(4)) for p in hs)
        if i%4==0: ts=(ts[0],ts[0])
        if i%4==1: ts=(hs[1],hs[0])
        cs=tuple(rng.choice((0,8,9,10)) if i%3==0 else rng.randrange(16) for _ in range(2))
        emit(hs,ts,cs)
with (out/'turn_vectors.txt').open('w') as f:
    u=TurnUnit()
    def emit(rst=0,load=0,lh=0,vv=0,vd=0,hv=0,hl=0,apply=0,launch=0):
        if rst:u.load(1)
        elif load:u.load(lh)
        else:u.clock((None if not vv else 2 if vd else 0,None if not hv else 3 if hl else 1),bool(apply),bool(launch))
        f.write(' '.join(map(str,(rst,load,lh,vv,vd,hv,hl,apply,launch,u.heading,u.pending)))+'\n')
    for heading in range(4):
        for pending in (heading,(heading+1)%4,(heading+3)%4):
            for bits in range(16):
                for apply in range(2):
                    for launch in range(2):
                        emit(load=1,lh=heading)
                        if pending!=heading:emit(vv=1,vd=int(pending==2),hv=1,hl=int(pending==3),apply=1)
                        emit(vv=bits&1,vd=(bits>>1)&1,hv=(bits>>2)&1,hl=(bits>>3)&1,apply=apply,launch=launch)
    emit(load=1,lh=1);emit(vv=1,apply=1)
    assert (u.heading,u.pending)==(1,0)
    emit(hv=1,hl=1,apply=1,launch=1)
    assert (u.heading,u.pending)==(0,0)
    emit(hv=1,hl=1,apply=1);emit(vv=1,vd=1,apply=1)
    assert (u.heading,u.pending)==(0,3)
    emit(launch=1)
    assert (u.heading,u.pending)==(3,3)
    emit(rst=1,load=1,lh=2,apply=1,launch=1)
    for i in range(1000):emit(rst=int(i%97==0),load=int(i%53==0),lh=rng.randrange(4),vv=rng.randrange(2),vd=rng.randrange(2),hv=rng.randrange(2),hl=rng.randrange(2),apply=rng.randrange(2),launch=rng.randrange(2))
print('Generated',*(f'{p.name}: {sum(1 for _ in p.open())}' for p in out.glob('*_vectors.txt')))
