# Comandos para Vivado en myws

Líneas para copiar y pegar en la estación remota (`myws.kaust.edu.sa`). Los bloques `bash` van en una terminal; los bloques `tcl` van en la *Tcl Console* de Vivado, con el proyecto abierto.

Cambia `~/FPGA` si clonaste el repo en otra carpeta.

## 1. Traer la versión nueva del repo (terminal)

La primera vez, para clonar:

```bash
cd ~
git clone https://github.com/romanmg00/FPGA.git
cd FPGA
git checkout hdl/second-bike
```

Cada vez que haya cambios en GitHub:

```bash
cd ~/FPGA
git pull
```

Cuando la rama ya esté fusionada en `main`:

```bash
cd ~/FPGA
git checkout main
git pull
```

Para ver en qué rama estás y si tienes cambios locales:

```bash
cd ~/FPGA
git status
```

No edites archivos dentro del clon: si cambias algo aquí y también cambia en GitHub, `git pull` se niega a sobrescribirlo. El proyecto de Vivado debe vivir fuera del clon.

## 2. Cargar las fuentes de diseño (Tcl de Vivado)

Si Vivado avisa que los archivos ya existen, o el proyecto tiene versiones viejas, primero quita del proyecto todas las fuentes `.sv` y `.v` de diseño:

```tcl
set old [get_files -quiet -norecurse -of_objects [get_filesets sources_1] -filter {FILE_TYPE == SystemVerilog || FILE_TYPE == Verilog}]
if {[llength $old]} { remove_files $old }
```

- Solo las saca del proyecto; no borra nada del disco ni del clon.
- No toca el IP `clk_wiz_0` (`-norecurse` y el filtro dejan fuera el `.xci` y los archivos que genera), ni las restricciones (`constrs_1`), ni los testbenches (`sim_1`).

Luego carga las fuentes del clon:

```tcl
cd ~/FPGA/proyecto_final
set design [lsearch -all -inline -not [glob *.sv] *_tb.sv]
add_files -norecurse $design
set_property top game_top [current_fileset]
```

- Toma solo los `.sv` de primer nivel de `proyecto_final`, sin los testbenches (`*_tb.sv`).
- `-norecurse` deja fuera las subcarpetas. **`sim_clocks/clk_wiz_0.sv` nunca entra a la síntesis**: es un reloj ideal para simulación con el mismo nombre que el IP real. `prototypes/` tampoco es del juego.
- `add_files` referencia los archivos, no los copia: después de un `git pull`, Vivado ve la versión nueva.
- Si el proyecto tiene copias viejas de estos archivos (creado con *Copy sources into project*), quítalas antes con el bloque de arriba para no tener módulos duplicados.
- El IP `clk_wiz_0` y las restricciones (`game_top.xdc`, `game_top_timing.xdc`) se quedan como están en el proyecto.

Para ver qué archivos quedaron cargados:

```tcl
get_files -norecurse -of_objects [get_filesets sources_1]
```

Debe salir la lista de `.sv` desde `~/FPGA/proyecto_final` y el `.xci` de `clk_wiz_0`, sin rutas dentro de la carpeta del proyecto (`.srcs`).

## 3. Después de cada `git pull`

- Si solo cambiaron archivos que ya estaban, vuelve a correr la síntesis.
- Si llegó un archivo `.sv` nuevo (un módulo nuevo), repite el bloque de la sección 2 y luego sintetiza.
- Revisa en *Design Sources* que `game_top` esté arriba y que no haya módulos sueltos sin padre.

## 4. Sintetizar, implementar y generar el bitstream (Tcl de Vivado)

```tcl
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

Para revisar el timing al terminar (WNS y WHS deben ser positivos):

```tcl
open_run impl_1
report_timing_summary -max_paths 5
```
