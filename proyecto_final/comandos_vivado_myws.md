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

Para cambiar a una rama nueva que se creó en GitHub (por ejemplo `hdl/sprites`):

```bash
cd ~/FPGA
git fetch
git checkout hdl/sprites
```

`git fetch` baja la lista de ramas nuevas sin cambiar tus archivos; `git checkout` cambia los archivos a esa rama. Después, en esa rama, basta `git pull` para traer lo nuevo.

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

## 1b. Una sola vez: pasar el proyecto a las carpetas nuevas

Desde el PR de las carpetas, `proyecto_final/` separa el diseño (`src/`), los testbenches (`testbenches/`) y las restricciones (`constraints/`). Un proyecto creado antes apunta a las rutas viejas, que ya no existen. Esta sección se hace una sola vez.

**Antes de que se fusione ese PR**, pruébalo en una copia: clona el repo en otra carpeta (`git clone https://github.com/romanmg00/FPGA.git ~/FPGA-carpetas`, y ahí `git checkout chore/proyecto-final-folders`), haz una copia del proyecto (*File → Project → Save As*), y en los bloques de abajo cambia `~/FPGA` por `~/FPGA-carpetas`. El proyecto de la presentación y `~/FPGA` no se tocan hasta que el PR esté en `main`.

1. Guarda cómo está el proyecto: las fuentes de cada conjunto, sus propiedades y su `top`.

   ```tcl
   set log [open ~/vivado_antes_de_carpetas.txt w]
   foreach fs {sources_1 sim_1 constrs_1} {
       puts $log "== $fs top: [get_property -quiet top [get_filesets $fs]]"
       foreach f [get_files -norecurse -of_objects [get_filesets $fs]] {
           set props {USED_IN_SYNTHESIS USED_IN_IMPLEMENTATION USED_IN_SIMULATION}
           if {[string match *.xdc $f]} {set props {USED_IN_SYNTHESIS USED_IN_IMPLEMENTATION PROCESSING_ORDER}}
           set vals {}
           foreach p $props {lappend vals "$p=[get_property -quiet $p [get_files $f]]"}
           puts $log "$f $vals"
       }
   }
   close $log
   ```

2. Restricciones: quita las dos viejas y agrega las nuevas, en el mismo orden.

   ```tcl
   remove_files -fileset constrs_1 [get_files -of_objects [get_filesets constrs_1] *game_top*.xdc]
   add_files -fileset constrs_1 -norecurse [glob ~/FPGA/proyecto_final/constraints/game_top.xdc]
   add_files -fileset constrs_1 -norecurse [glob ~/FPGA/proyecto_final/constraints/game_top_timing.xdc]
   ```

   Compara con `~/vivado_antes_de_carpetas.txt` y regresa solo lo que no estaba en su valor normal. Por ejemplo, si `game_top_timing.xdc` tenía `USED_IN_SYNTHESIS=0` (`build_game_top.tcl` lo deja así), corre `set_property USED_IN_SYNTHESIS false [get_files game_top_timing.xdc]`; lo mismo con `USED_IN_IMPLEMENTATION` y `PROCESSING_ORDER`.

3. Diseño: corre el primer bloque de la sección 2 (quita los `.sv` viejos) y luego el segundo (carga `src/*.sv` y pone `top` en `game_top`). Las IP se quedan como están.

4. Testbenches: cambia cada uno de `sim_1` por el mismo archivo en `testbenches/`, uno por uno, sin agregar otros.

   ```tcl
   foreach f [get_files -quiet -norecurse -of_objects [get_filesets sim_1] *_tb.sv] {
       remove_files -fileset sim_1 $f
       add_files -fileset sim_1 -norecurse [glob ~/FPGA/proyecto_final/testbenches/[file tail $f]]
   }
   ```

   Vuelve a poner el `top` de `sim_1` que salió en el paso 1: `set_property top NOMBRE_tb [get_filesets sim_1]`.

5. Revisa que lo que se sintetiza sea exactamente `src/*.sv`:

   ```tcl
   set esperado [lsort [glob ~/FPGA/proyecto_final/src/*.sv]]
   set cargado [lsort [lmap f [get_files -norecurse -of_objects [get_filesets sources_1] -filter {FILE_TYPE == SystemVerilog}] {file normalize $f}]]
   if {$cargado eq $esperado} {puts "OK: sources_1 = src/*.sv"} else {puts "DISTINTO:\n$cargado"}
   ```

6. Corre la sección 4 hasta el bitstream: la temporización debe cumplirse y `check_timing` no debe empeorar. Corre también uno de tus testbenches (por ejemplo `position_logic_tb`) en *Run Simulation*.

Pega en el PR la salida del paso 5, el WNS/WHS y el resultado del testbench.

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
add_files -norecurse [glob ~/FPGA/proyecto_final/src/*.sv]
set_property top game_top [current_fileset]
```

- `src/` tiene solo el diseño, todo lo que se sintetiza. Los testbenches están en `testbenches/` y las restricciones en `constraints/`.
- **`sim_clocks/clk_wiz_0.sv` nunca entra a la síntesis**: es un reloj ideal para simulación con el mismo nombre que el IP real. `prototypes/` tampoco es del juego.
- `add_files` referencia los archivos, no los copia: después de un `git pull`, Vivado ve la versión nueva.
- Si el proyecto tiene copias viejas de estos archivos (creado con *Copy sources into project*), quítalas antes con el bloque de arriba para no tener módulos duplicados.
- Los IP (`clk_wiz_0`, `bike_rom`, `reward_rom`) se quedan como están en el proyecto.

Para ver qué archivos quedaron cargados:

```tcl
get_files -norecurse -of_objects [get_filesets sources_1]
```

Debe salir la lista de `.sv` desde `~/FPGA/proyecto_final/src` y los `.xci` de los IP, sin rutas dentro de la carpeta del proyecto (`.srcs`).

### Restricciones (`.xdc`)

Para ver qué `.xdc` usa el proyecto:

```tcl
get_files -of_objects [get_filesets constrs_1]
```

Deben salir los dos del clon: `/home/<usuario>/FPGA/proyecto_final/constraints/game_top.xdc` (pines) y `constraints/game_top_timing.xdc` (reloj `clk_juego`). Si sale otra ruta, por ejemplo una copia en otra carpeta, cámbialos por los del clon:

```tcl
remove_files -fileset constrs_1 [get_files -of_objects [get_filesets constrs_1]]
add_files -fileset constrs_1 -norecurse [glob ~/FPGA/proyecto_final/constraints/game_top.xdc]
add_files -fileset constrs_1 -norecurse [glob ~/FPGA/proyecto_final/constraints/game_top_timing.xdc]
```

- `glob` es necesario: dentro de `[list ...]` Tcl no expande `~` y Vivado responde `File or Directory '~/FPGA/...' does not exist`. Una ruta escrita a mano debe empezar con `/home/...`.
- `remove_files` solo los saca del proyecto; no borra nada del disco.
- Si lanzaste una síntesis antes de arreglar las restricciones, esa corrida no sirve: vuelve a correr la sección 4.

### IP del proyecto

```tcl
get_ips
```

Deben salir `clk_wiz_0`, `bike_rom` y `reward_rom`. Si falta alguna ROM, créala en este proyecto:

```tcl
source ~/FPGA/proyecto_final/ip/bike_rom/bike_rom.tcl
source ~/FPGA/proyecto_final/ip/reward_rom/reward_rom.tcl
```

## Revisar antes de sintetizar

Si la placa no muestra el cambio nuevo, revisa en este orden.

1. El clon tiene el código nuevo (terminal):

   ```bash
   cd ~/FPGA
   git status
   git log --oneline -1
   ```

   `git status` dice la rama y si estás al día; `git log` muestra el último commit, que debe ser el mismo que en GitHub. Si no, `git pull`.

2. Vivado usa los archivos del clon y tiene los IP: los tres bloques de arriba (`get_files` de `sources_1`, `get_files` de `constrs_1`, `get_ips`).

3. El `.bit` viene de la corrida nueva (Tcl):

   ```tcl
   get_property STATUS [get_runs impl_1]
   ```

   Debe decir `write_bitstream Complete!`. Para ver la hora del `.bit` (terminal; cambia la carpeta por la de tu proyecto):

   ```bash
   ls -l ~/DigitalDesignsFinalProject/DigitalDesignsFinalProject.runs/impl_1/*.bit
   ```

   La hora debe ser posterior a tu último `git pull` y al último cambio de restricciones.

## 3. Después de cada `git pull`

- Si solo cambiaron archivos que ya estaban, vuelve a correr la síntesis.
- Si llegó un archivo `.sv` nuevo (un módulo nuevo), repite el bloque de la sección 2 y luego sintetiza.
- Revisa en *Design Sources* que `game_top` esté arriba y que no haya módulos sueltos sin padre.

## Quitar el IP viejo `clk_wiz_1` (Tcl de Vivado)

Desde el Paso 4c el diseño ya no usa `clk_wiz_1`. Si el proyecto todavía lo tiene, la implementación da dos critical warnings `Could not find module 'clk_wiz_1'`. Para quitarlo del proyecto:

```tcl
remove_files [get_files clk_wiz_1.xci]
```

Solo lo saca del proyecto; no toca `clk_wiz_0`. Después vuelve a correr la síntesis.

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
