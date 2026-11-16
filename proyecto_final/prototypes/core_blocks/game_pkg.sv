// game_pkg: shared constants, copied verbatim from contract section 5
// (proyecto_final/Contrato de interfaces game_top (CS 256).md).
// Provisional (ADR 0005): first compile of the contract package; change the
// contract first, then this file.

package game_pkg;

    // Timing VGA 1280x800 (diapositiva 7)
    localparam int H_SYNC = 136, H_BP = 200, H_ACTIVE = 1280, H_FP = 64;
    localparam int H_TOTAL = H_SYNC + H_BP + H_ACTIVE + H_FP;      // 1680
    localparam int V_SYNC = 3, V_BP = 24, V_ACTIVE = 800, V_FP = 1;
    localparam int V_TOTAL = V_SYNC + V_BP + V_ACTIVE + V_FP;      // 828
    localparam int BORDER_PX = 10;                                 // borde blanco

    // Cuadrícula: celdas de 16x16 px
    localparam int TILE_SHIFT = 4;
    localparam int GRID_W = 80, GRID_H = 50, HUD_ROWS = 4;         // 64 px de marcador
    localparam int CX_W = 7, CY_W = 6, ADDR_W = 13;               // dirección = {cy, cx}
    localparam int PLAY_CX_MIN = 1, PLAY_CX_MAX = 78;             // 78 x 44 celdas jugables
    localparam int PLAY_CY_MIN = 5, PLAY_CY_MAX = 48;

    // Contenido de una celda (igual en el modelo y en el HDL)
    localparam logic [3:0] CELL_EMPTY    = 4'd0;
    localparam logic [3:0] CELL_WALL     = 4'd1;
    localparam logic [3:0] CELL_P1_TRAIL = 4'd2;
    localparam logic [3:0] CELL_P1_HEAD  = 4'd3;
    localparam logic [3:0] CELL_P2_TRAIL = 4'd4;
    localparam logic [3:0] CELL_P2_HEAD  = 4'd5;
    localparam logic [3:0] CELL_CRASH    = 4'd6;
    localparam logic [3:0] CELL_RESERVED = 4'd7;
    localparam logic [3:0] CELL_REWARD0  = 4'd8;
    localparam logic [3:0] CELL_REWARD1  = 4'd9;
    localparam logic [3:0] CELL_REWARD2  = 4'd10;

    // Direcciones: girar a la derecha = sumar 1 (mod 4)
    localparam logic [1:0] DIR_UP = 2'd0, DIR_RIGHT = 2'd1, DIR_DOWN = 2'd2, DIR_LEFT = 2'd3;

    // Estados de la partida (propuesta, sección 4)
    localparam logic [2:0] G_IDLE = 3'd0, G_PLAY = 3'd1, G_CRASH = 3'd2, G_READY = 3'd3, G_MATCH = 3'd4;

    // Botones
    localparam int BTN_U = 0, BTN_D = 1, BTN_L = 2, BTN_R = 3, BTN_C = 4;

    // Reglas (en ticks de clk_juego, ~60 Hz)
    localparam int STEP_TICKS     = 6;     // un paso cada 6 ticks
    localparam int LIVES_START    = 3;
    localparam int REWARD_PTS0    = 1, REWARD_PTS1 = 1, REWARD_PTS2 = 3;
    localparam int SURVIVAL_BONUS = 3;
    localparam int CRASH_TICKS    = 120;   // ~2 s de parpadeo
    localparam int SCORE_VIEW_TICKS = 180; // ~3 s por vista del display
    // Meta según {SW15, SW14}: 10, 20, 30, 40

    // Salidas: P1 en (20, 27) hacia la derecha, P2 en (59, 27) hacia la izquierda
    localparam logic [6:0] SAL_P1_CX = 7'd20, SAL_P2_CX = 7'd59;
    localparam logic [5:0] SAL_CY    = 6'd27;

    // Sprites RGB444
    localparam logic [11:0] COLOR_TRANSPARENT = 12'h000;
    localparam logic [11:0] COLOR_TINT_KEY    = 12'h0F0;

endpackage
