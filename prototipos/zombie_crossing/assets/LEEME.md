# Imágenes opcionales

Si pones aquí un PNG con alguno de estos nombres, el juego lo usa en lugar del
pixel art. Se escala solo al tamaño del sprite.

| Archivo | Qué es | Tamaño en pantalla |
|---|---|---|
| `zombie.png` | El personaje | 32 × 32 |
| `lanzaguisantes.png` | Planta que dispara (mirando a la derecha) | 32 × 32 |
| `hielaguisantes.png` | Planta de los carriles rápidos (mirando a la derecha) | 32 × 32 |
| `guisante.png` | Guisante normal | 16 × 16 |
| `guisante_hielo.png` | Guisante de hielo | 16 × 16 |
| `nenufar.png` | Nenúfar de la piscina | 32 × 32 |
| `nuez.png` | Nuez que bloquea el paso | 32 × 32 |
| `podadora.png` | Podadora (mirando a la derecha) | 32 × 32 |

Usa PNG con fondo transparente. Todo lo que pongas en esta carpeta, salvo este
archivo, está en el `.gitignore`: **no se sube a GitHub**. Así se pueden usar
imágenes con derechos de autor para una presentación sin publicarlas.

Recuerda que en la FPGA los sprites serán los de pixel art de `sprites.py`
(16 × 16 con colores RGB444), no estas imágenes.
