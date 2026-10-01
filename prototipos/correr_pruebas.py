"""
Corre las pruebas de todos los prototipos.  Ejecutar:  python3 correr_pruebas.py
"""

import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
fallos = 0
for carpeta in sorted(os.listdir(AQUI)):
    if os.path.exists(os.path.join(AQUI, carpeta, "test_juego.py")):
        print(f"== {carpeta}")
        r = subprocess.run([sys.executable, "test_juego.py"], cwd=os.path.join(AQUI, carpeta))
        fallos += r.returncode != 0
print("Todo bien." if fallos == 0 else f"Fallaron {fallos} prototipo(s).")
sys.exit(1 if fallos else 0)
