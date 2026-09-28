# Crossy FPGA

Nuestro primer proyecto de FPGA: un videojuego tipo **Crossy Road** (una gallina
que cruza calles y ríos) que se mostrará por **VGA 640x480** y se controlará con
los botones de la tarjeta.

## Estructura

```
prototipo_python/   Prototipo jugable en Python (modelo de referencia)
  config.py         Constantes: resolución, tiles, paleta RGB444, reglas
  juego.py          Lógica pura (sin pygame): LFSR, carriles, máquina de estados
  main.py           Dibujo y teclado con pygame
  test_juego.py     Pruebas de la lógica
```

## Correr el prototipo

```bash
cd prototipo_python
pip3 install -r requirements.txt
python3 main.py        # flechas o WASD para saltar, Esc para salir
python3 test_juego.py  # pruebas
```

## Reglas

- Cada salto hacia adelante suma 1 punto.
- **Calle:** si un auto te toca, pierdes.
- **Río:** solo puedes pararte sobre troncos; te arrastran, y si te sacan de la pantalla pierdes.
- **Pasto:** los árboles bloquean el paso.
- Si pasas 8 s sin avanzar, se te lleva el águila.

## Decisiones pensadas para la FPGA

El prototipo está escrito para que traducirlo a Verilog/VHDL sea casi directo:

| En Python | En hardware |
|---|---|
| Pantalla 640x480 a 60 FPS | Controlador VGA estándar (reloj de píxel de 25 MHz) |
| Tiles de 32 px | `tile = x[9:5]`: solo cortar bits, sin dividir |
| Carril = patrón de 32 bits + `offset` de 10 bits | Un registro de 32 bits y un contador que se desborda solo |
| `Carril.ocupado(x)` | Resta de 10 bits + multiplexor 32→1 |
| Buffer circular de 16 carriles | 16 registros, índice `fila[3:0]` |
| `LFSR16` | Registro de desplazamiento con 3 XOR |
| ROM de patrones (`ROM_CALLE`, `ROM_RIO`, `ROM_PASTO`) | ROM de 12 palabras de 32 bits |
| `Juego.paso()` = un frame | Se ejecuta una vez por pulso de vsync |
| Estados `INICIO / JUGANDO / MUERTO` | Máquina de estados finitos |
| Paleta RGB444 | Salida VGA de 4 bits por canal (Basys 3, Nexys A7, DE10-Lite) |
| Solo enteros | Sin punto flotante |

## Siguientes pasos

1. Elegir la tarjeta y probar un patrón de barras de color por VGA.
2. Dibujar carriles estáticos (pasto / calle / río) en función de `(x, y)`.
3. Mover los autos con el `offset` en cada vsync.
4. Agregar la gallina controlada por los botones (con antirrebote).
5. Colisiones, puntaje en el display de 7 segmentos y máquina de estados.
