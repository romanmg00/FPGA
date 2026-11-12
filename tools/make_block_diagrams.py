"""Block diagrams of the tron_top HDL (proyecto_final/prototypes/core_blocks/game),
drawn in the style of the course handout's game_top.png: boxes for modules,
labelled arrows for the signals between them, board pins at the edges.

Writes SVG files to OUT_DIR:
  1-tron_top.svg      board level: clocks, resets, tron_system, pins
  2-tron_system.svg   the game: input path, game_core (clk_juego), fast_core,
                      drawcon_game, vga_out, seg7_driver, LEDs
  3-step_loop.svg     one Step across the two clocks: game_core's units, the
                      mailbox, fast_core's Arena service and the snapshot
  4-drawcon_game.svg  the renderer: look-ahead, memories, layers, composition

The diagrams are hand-placed from the module ports; check them against the
code when ports change. Usage: python3 tools/make_block_diagrams.py OUT_DIR
"""

import pathlib
import sys
from xml.sax.saxutils import escape

FONT = "font-family='Helvetica, Arial, sans-serif'"


class Svg:
    def __init__(self, w, h, title):
        self.w, self.h = w, h
        self.items = [f"<rect width='{w}' height='{h}' fill='white'/>",
                      f"<text x='{w / 2}' y='22' text-anchor='middle' font-size='16' "
                      f"font-weight='bold' {FONT}>{escape(title)}</text>"]

    def region(self, x, y, w, h, label, fill):
        self.items.append(f"<rect x='{x}' y='{y}' width='{w}' height='{h}' fill='{fill}' "
                          f"stroke='#999' stroke-dasharray='6 4' rx='6'/>")
        self.items.append(f"<text x='{x + 8}' y='{y + 16}' font-size='12' fill='#555' "
                          f"font-style='italic' {FONT}>{escape(label)}</text>")

    def box(self, x, y, w, h, title, sub=None, dashed=False, fill="white", bold=True, lines=()):
        dash = " stroke-dasharray='7 5'" if dashed else ""
        self.items.append(f"<rect x='{x}' y='{y}' width='{w}' height='{h}' fill='{fill}' "
                          f"stroke='black' stroke-width='1.5'{dash}/>")
        weight = "bold" if bold else "normal"
        self.items.append(f"<text x='{x + w / 2}' y='{y + 18}' text-anchor='middle' font-size='13' "
                          f"font-weight='{weight}' {FONT}>{escape(title)}</text>")
        ty = y + 33
        if sub:
            self.items.append(f"<text x='{x + w / 2}' y='{ty}' text-anchor='middle' font-size='10.5' "
                              f"fill='#444' {FONT}>{escape(sub)}</text>")
            ty += 15
        for line in lines:
            self.items.append(f"<text x='{x + 8}' y='{ty}' font-size='10.5' fill='#333' "
                              f"xml:space='preserve' {FONT}>{escape(line)}</text>")
            ty += 14

    def text(self, x, y, s, anchor="start", size=11, color="black", italic=False):
        style = " font-style='italic'" if italic else ""
        self.items.append(f"<text x='{x}' y='{y}' text-anchor='{anchor}' font-size='{size}' "
                          f"fill='{color}'{style} xml:space='preserve' {FONT}>{escape(s)}</text>")

    def arrow(self, pts, label=None, at=0, dx=0, dy=-4, anchor="middle", color="black",
              both=False, size=11):
        """Polyline through pts with an arrowhead at the end; label near segment `at`."""
        d = " ".join(f"{x},{y}" for x, y in pts)
        marker = " marker-end='url(#ah)'" + (" marker-start='url(#ah)'" if both else "")
        self.items.append(f"<polyline points='{d}' fill='none' stroke='{color}' "
                          f"stroke-width='1.4'{marker}/>")
        if label:
            (x0, y0), (x1, y1) = pts[at], pts[at + 1]
            self.text((x0 + x1) / 2 + dx, (y0 + y1) / 2 + dy, label, anchor, size)

    def svg(self) -> str:
        head = (f"<svg xmlns='http://www.w3.org/2000/svg' width='{self.w}' height='{self.h}' "
                f"viewBox='0 0 {self.w} {self.h}'><defs><marker id='ah' markerWidth='10' "
                f"markerHeight='8' refX='9' refY='4' orient='auto-start-reverse'>"
                f"<path d='M0,0 L10,4 L0,8 z' fill='black'/></marker></defs>")
        return head + "\n".join(self.items) + "</svg>\n"


PIX = "#eaf2fb"     # clk_pix region
GAME = "#fdf0e3"    # clk_juego region


def tron_top() -> Svg:
    s = Svg(1060, 600, "tron_top: board level (Nexys A7-100T)")
    s.box(170, 45, 760, 535, "tron_top", bold=True)
    # pins in
    pins = [("clk (100 MHz)", 470), ("cpu_resetn", 330), ("btn[4:0]", 120), ("sw[15:0]", 165),
            ("uart_rx", 210)]
    for name, y in pins:
        s.text(20, y + 4, name)
    s.box(200, 440, 175, 70, "tron_pixel_clock", "Clocking Wizard IP")
    s.arrow([(110, 470), (200, 470)])
    s.box(430, 440, 170, 70, "game_clk_div", "toggle every 695,466")
    s.arrow([(375, 475), (430, 475)], "clk_pix", dy=-6)
    s.text(380, 500, "83.46 MHz", size=10, color="#555")
    s.box(200, 300, 175, 60, "reset_stretch", "hold 6 game periods")
    s.arrow([(110, 330), (200, 330)])
    s.box(430, 270, 170, 45, "board_reset_sync")
    s.box(430, 340, 170, 45, "board_reset_sync")
    s.arrow([(375, 330), (400, 330), (400, 292), (430, 292)], "rst_req", at=0, dy=-6)
    s.arrow([(400, 330), (400, 362), (430, 362)])
    s.box(660, 75, 240, 480, "tron_system", "the game (diagram 2)", fill="#f7f7f7")
    for name, y in pins[2:]:
        s.arrow([(110, y), (660, y)], name if False else None)
    s.arrow([(600, 292), (630, 292), (630, 300), (660, 300)])
    s.arrow([(600, 362), (640, 362), (640, 340), (660, 340)])
    s.text(665, 304, "rst_pix", size=10)
    s.text(665, 344, "rst_game", size=10)
    s.arrow([(400, 475), (400, 525), (650, 525), (650, 420), (660, 420)], "clk_pix", at=1, dy=-5)
    s.arrow([(600, 475), (625, 475), (625, 460), (660, 460)], "clk_juego", at=0, dy=-6, dx=4)
    s.text(605, 500, "≈ 60 Hz", size=10, color="#555")
    s.text(665, 424, "clk_pix", size=10)
    s.text(665, 464, "clk_juego", size=10)
    for name, y in (("btn", 120), ("sw", 165), ("uart_rx", 210)):
        s.text(665, y + 4, name, size=10)
    outs = [("vga_r, vga_g, vga_b [3:0]", 120), ("vga_hs, vga_vs", 165), ("seg[6:0], an[7:0]", 250),
            ("led[15:0]", 330)]
    for name, y in outs:
        s.arrow([(900, y), (1045, y)], name, dy=-6)
    s.arrow([(930, 410), (1045, 410)], "dp = 1 (off)", dy=-6)
    return s


def tron_system() -> Svg:
    s = Svg(1340, 800, "tron_system: the game, two clock domains")
    s.region(30, 40, 1290, 470, "clk_pix  83.46 MHz", PIX)
    s.region(30, 525, 1290, 255, "clk_juego  ≈ 60 Hz  (a counter on clk_pix, ADR 0006)", GAME)
    # input path
    s.text(40, 98, "btn[4:0]")
    s.box(110, 70, 150, 50, "btn_debounce", "1 ms, press pulses")
    s.arrow([(85, 94), (110, 94)])
    s.text(40, 178, "uart_rx")
    s.box(110, 150, 150, 40, "uart_sync_2ff")
    s.box(110, 205, 150, 40, "uart_rx", "115200 8N1")
    s.box(110, 260, 150, 50, "uart_cmd_decode", "W A S D, Space/Enter")
    s.arrow([(85, 174), (110, 174)])
    s.arrow([(185, 190), (185, 205)])
    s.arrow([(185, 245), (185, 260)])
    s.text(192, 202, "rx_sync", size=9.5)
    s.text(192, 257, "rx_byte, rx_valid", size=9.5)
    # fast_core
    s.box(380, 60, 270, 420, "fast_core", "clk_pix half of the core (diagram 3)",
          lines=["• input batch: latches per game tick",
                 "• tick_tgl 2-FF sync → tick_seen",
                 "• command queue → arena_svc",
                 "    arena_map BRAM 8192 × 4 bit",
                 "    Reward LFSR, 3 slots",
                 "• render snapshot (on tick_seen)"])
    s.arrow([(260, 95), (380, 95)], "btn_pulse[4:0]")
    s.arrow([(260, 285), (320, 285), (320, 140), (380, 140)], "uart_cmd[2:0],", at=1, dx=6, anchor="start", dy=0)
    s.text(326, 226, "valid", size=11)
    # game_core
    s.box(380, 580, 270, 180, "game_core", "clk_juego (diagram 3)",
          lines=["• Step sequencer: PREPARE, READ2, COMMIT",
                 "• turn_unit ×2, next_cell ×2, step_resolve",
                 "• score_unit: Points, Lives, result",
                 "• phase: IDLE PLAY CRASH READY MATCH",
                 "• seg7_page: Points / Lives / Goal"])
    s.text(40, 650, "sw[0] Pause")
    s.text(40, 670, "sw[15:14] Goal")
    s.arrow([(130, 655), (380, 655)])
    s.text(200, 700, "raw pins, 2-FF synced inside", size=9.5, color="#555")
    # crossings
    s.arrow([(430, 580), (430, 480)], "tick_tgl, cmd_*", dx=-6, anchor="end")
    s.arrow([(480, 580), (480, 480)], "g_* (snapshot)", dx=6, anchor="start", dy=-20)
    s.arrow([(600, 480), (600, 580)], "rsp_*", dx=6, anchor="start")
    s.box(660, 525, 150, 45, "batch_fifo", "QUALIFIED only", dashed=True)
    s.arrow([(630, 480), (630, 500), (735, 500), (735, 525)], "batch_*", at=1, dy=-5)
    s.arrow([(735, 570), (735, 600), (650, 600)], "batch axes, start", at=1, dy=-5)
    # drawcon, vga
    s.box(770, 60, 200, 270, "drawcon_game", "picture (diagram 4)",
          lines=["HUD, background, Wall,", "Trails, Rewards, Bikes"])
    s.arrow([(650, 110), (770, 110)], "snap_* (latched/frame)", dy=-5)
    s.arrow([(770, 170), (650, 170)], "b_addr[12:0]", dy=-5)
    s.arrow([(650, 200), (770, 200)], "b_rdata[3:0] (port B)", dy=-5)
    s.box(1060, 60, 160, 270, "vga_out", "1680 × 828 raster")
    s.arrow([(970, 110), (1060, 110)], "draw_r/g/b[3:0]", dy=-5)
    s.arrow([(1060, 200), (970, 200)], "curr_x[10:0]", dy=-5)
    s.arrow([(1060, 240), (970, 240)], "curr_y[10:0]", dy=-5)
    s.arrow([(1220, 110), (1310, 110)], "vga_r/g/b", dy=-5)
    s.arrow([(1220, 170), (1310, 170)], "vga_hs, vga_vs", dy=-5)
    # seg7, leds
    s.box(770, 360, 200, 70, "seg7_driver", "8 digits, 1 kHz scan")
    s.arrow([(650, 395), (770, 395)], "snap points, lives, page", dy=-5)
    s.arrow([(970, 395), (1310, 395)], "seg[6:0], an[7:0]", dy=-5)
    s.box(770, 445, 200, 50, "LED status", "always_comb")
    s.arrow([(650, 470), (770, 470)], "phase, paused, busy…", dy=-5)
    s.arrow([(970, 470), (1310, 470)], "led[15:0]", dy=-5)
    return s


def step_loop() -> Svg:
    s = Svg(1340, 720, "One Step: game_core (clk_juego) and fast_core (clk_pix)")
    s.region(20, 40, 560, 660, "game_core  · clk_juego ≈ 60 Hz", GAME)
    s.region(760, 40, 560, 660, "fast_core  · clk_pix 83.46 MHz", PIX)
    s.box(50, 80, 230, 60, "sw sync", "Pause, Goal: 2-FF")
    s.box(50, 170, 230, 70, "turn_unit ×2", "pending Turn, reversal ignored")
    s.box(50, 270, 230, 50, "next_cell ×2", "head + Heading → target")
    s.box(320, 75, 230, 140, "Step sequencer (FSM)", "every STEP_TICKS ticks",
          lines=["PREPARE: clear Arena, heads,", "  three Rewards", "READ2: read both targets",
                 "COMMIT: write heads/Trails,", "  replace collected Rewards"])
    s.box(320, 270, 230, 110, "step_resolve", "codes → Crash / collect",
          lines=["Walls, Trails, head-on,", "swap = both Crash"])
    s.box(50, 360, 230, 110, "score_unit", "Points, Lives, result",
          lines=["+1 / +1 / +3 Rewards", "+3 Survival Bonus", "Goal 10/20/30/40"])
    s.box(320, 410, 230, 110, "phase", "IDLE · PLAY · CRASH ·", lines=["READY · MATCH", "phase_ticks, blink_ticks"])
    s.box(50, 500, 230, 60, "seg7_page", "Points → Lives (→ Goal)")
    s.arrow([(165, 140), (165, 170)], "pause", dx=6, anchor="start", dy=4)
    s.arrow([(165, 240), (165, 270)])
    s.arrow([(280, 295), (320, 295)], "targets", dy=-5)
    s.arrow([(320, 340), (280, 400)], "outcome", dx=-4)
    s.arrow([(280, 440), (320, 450)])
    # crossings
    s.arrow([(550, 120), (790, 120)], "tick_tgl (toggle each tick)", dy=-6)
    s.arrow([(550, 170), (790, 170)], "cmd_op, cmd_seq, cmd_a/b_p1/p2, cmd_*", dy=-6)
    s.arrow([(1060, 330), (550, 330)], "rsp_seq, rsp_code_p1/p2 (target codes)", dy=-6)
    s.arrow([(790, 260), (600, 260), (600, 228), (280, 228)], "batch_axes_p1/p2, batch_start", at=2, dy=-5)
    s.arrow([(550, 470), (790, 470)], "g_phase, g_head_*, g_points_*, g_lives_*, g_result…", dy=-6)
    s.text(670, 600, "Crossing: every bus is latched on tick_seen or sampled a whole tick later", "middle", 10.5, "#555", True)
    s.text(670, 616, "(mailbox, ADR 0003); QUALIFIED = 1 adds req/ack and batch_fifo", "middle", 10.5, "#555", True)
    # fast side
    s.box(790, 80, 230, 70, "sync_2ff → tick_seen", "edge of tick_tgl")
    s.box(790, 160, 230, 50, "command queue", "start arena_svc")
    s.box(1060, 80, 230, 280, "arena_svc", "Arena service FSM",
          lines=["PREPARE: clear 8192 Cells,", "  Walls, heads, Rewards",
                 "READ2: codes at 2 targets", "COMMIT: Trails, heads,", "  Crash Cells, Rewards",
                 "Reward LFSR (seed + Start", "  tick), 3 slots", "", "arena_map: dual-port BRAM",
                 "  A: service read/write", "  B: drawcon read-only"])
    s.arrow([(1020, 185), (1060, 185)])
    s.box(790, 240, 230, 70, "input batch", "btn_pulse, uart_cmd → axes",
          lines=["per-tick latches, gated by phase"])
    s.box(790, 400, 230, 110, "render snapshot", "registers, updated on tick_seen",
          lines=["snap_phase, heads, Headings,", "points, lives, result, blink", "→ drawcon_game, seg7"])
    s.arrow([(1175, 360), (1175, 560), (1290, 560)], "b_addr / b_rdata", at=1, dy=-5)
    s.text(1300, 590, "drawcon_game", "end", 11, italic=True)
    return s


def drawcon() -> Svg:
    s = Svg(1340, 760, "drawcon_game: the picture, one pixel per clk_pix")
    s.region(20, 40, 1300, 700, "clk_pix · reads ahead of the beam, composes at curr_x / curr_y", PIX)
    s.text(40, 90, "curr_x, curr_y")
    s.text(40, 106, "(from vga_out)", size=10, color="#555")
    s.box(140, 65, 190, 140, "ahead(lead)", "raster position + lead",
          lines=["lead 1: Arena, HUD, Wall,", "   Trail stripes", "lead 2: sprite ROMs",
                 "lead 7: background"])
    s.arrow([(125, 95), (140, 95)])
    s.text(40, 270, "snap_* (fast_core)")
    s.box(140, 240, 190, 90, "per-frame latch", "at curr_y = 800",
          lines=["heads, Headings, shown,", "Points, Lives, blink, result"])
    s.arrow([(125, 275), (140, 275)])
    # middle column: sources
    col = 400
    s.box(col, 60, 260, 60, "Arena port B", "b_addr → b_rdata, 1 cycle")
    s.box(col, 130, 260, 80, "sprite_rom ×4", "BRAM, 2 cycles",
          lines=["bike-synth-32 ×2 (rotated by address)", "reward gem / star 16 × 16"])
    s.box(col, 220, 260, 90, "HUD", "registered (lead 1)",
          lines=["7-seg digits: comparators", "Lives / play / crown: 64 × 16 ROM"])
    s.box(col, 320, 260, 110, "background", "7 registers (lead 7)",
          lines=["sky 64 × 12 ROM, sun 321 × 21 ROM", "star hash: 3 DSP48 (MREG, PREG)",
                 "grid every 32 px, pulse ROM", "Arena-edge glow"])
    s.box(col, 440, 260, 60, "neon Wall", "registered (lead 1): tube, glow")
    s.box(col, 510, 260, 60, "Trail stripes", "(x + y − 2·frame) mod 64 < 6")
    s.box(col, 580, 260, 50, "frame counter", "frame[4:3] = animation phase")
    for y in (90, 170, 265, 375, 470, 540):
        s.arrow([(330, 135 if y < 300 else 135), (365, 135 if y < 300 else 135), (365, y), (col, y)])
    s.arrow([(330, 285), (380, 285), (380, 600), (col, 600)], None)
    # composition
    s.box(760, 60, 280, 570, "composition (always_comb)", "bottom → top, at the current pixel",
          lines=["1  Cell code from Arena port B:",
                 "     empty → background (sky, sun,",
                 "       stars, grid, edge glow)",
                 "     Wall → neon Wall colour",
                 "     Trail / head → Player colour,",
                 "       shine on stripes",
                 "     Crash → its Player's Trail",
                 "     Reward → gem / star texel,",
                 "       000 transparent, 0F0 tint",
                 "2  Bikes: P2 then P1 texel",
                 "     (0F0 → Player colour)",
                 "3  HUD band (y < 64)",
                 "4  10 px white border",
                 "5  black outside 1280 × 800"])
    for y in (90, 170, 265, 375, 470, 540):
        s.arrow([(col + 260, y), (760, y)])
    s.arrow([(1040, 330), (1180, 330)], "draw_r/g/b[3:0]", dy=-6)
    s.text(1190, 334, "vga_out")
    s.text(40, 690, "Only composition sits between curr_x/curr_y and the pins (vga_out is combinational): everything "
           "else is read early and registered.", size=10.5, color="#555", italic=True)
    return s


def main(out: pathlib.Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in (("1-tron_top", tron_top), ("2-tron_system", tron_system),
                     ("3-step_loop", step_loop), ("4-drawcon_game", drawcon)):
        (out / f"{name}.svg").write_text(fn().svg())
        print(out / f"{name}.svg")


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
