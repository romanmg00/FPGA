"""Copy and compare XSim's emitted logs, keeping every field including tick."""
import sys, subprocess, shutil
from pathlib import Path
p=Path(__file__).resolve().parent
build=Path(sys.argv[1]);label=sys.argv[2]
out=p/'evidence'/label;out.mkdir(exist_ok=True)
results=[]
for model in sorted(p.glob('*.model.log')):
    name=model.name.replace('.model.','.hdl.');hdl=build/name
    if not hdl.exists(): results.append(f'{name}: MISSING');continue
    shutil.copy(hdl,out/name)
    r=subprocess.run([sys.executable,str(p.parents[3]/'tools/steplog_diff.py'),str(model),str(hdl)],text=True,capture_output=True)
    results.append(f'{name}: '+('MATCH ' if r.returncode==0 else 'DIFFERENCE ')+r.stdout.strip())
(out/'diff.txt').write_text('\n'.join(results)+'\n')
print('\n'.join(results))
