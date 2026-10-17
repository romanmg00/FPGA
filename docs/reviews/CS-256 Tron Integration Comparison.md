---
schema_version: 1
id: cs256-tron-integration-comparison-20261017
title: CS-256 Tron Integration Comparison
type: note
subject: CS-256
status: draft
created_at: "2026-10-17T17:30:00"
term: 2026-fall
sources:
  - "[[CS-256 Tron Game Mechanics]]"
  - "[[CS-256 Tron Development Plan]]"
  - "[[CS-256 VGA and Sprite Design Plan]]"
  - "[[CS-256 Official FPGA Coding Practices]]"
review_status: unreviewed
tags:
  - tron
  - integration
---

# CS-256 Tron Integration Comparison

Every difference between Roman's team repository and this research folder, for one team meeting. Each row ends in either a **team decision** or a **recommendation** that the team can accept without much discussion.

- **Roman's side:** [romanmg00/FPGA](https://github.com/romanmg00/FPGA), `main` at `f5cb82c` (15 Oct). The main sources are `README.md`, `proyecto_final/Contrato de interfaces game_top (CS 256).md` (the **contract**, dated 11 Oct), `proyecto_final/{counters,vga_out}.sv` with their testbenches, and the Python reference model `prototipos/tron/`.
- **Our side:** [[CS-256 Tron Game Mechanics]] (14 Oct), [[CS-256 Tron Development Plan]], [[CS-256 VGA and Sprite Design Plan]], [ADR 0001](docs/adr/0001-pixel-clock-with-frame-enable.md), and `prototype/` (Game Model and Look viewer).
- **Binding for both:** the course handout (`classproject/README.md`) and the sprite tips (`classproject/sprites/README.md`).

Roman's contract was written before our Mechanics note, so neither side was contradicting the other on purpose. Both are complete designs for the same game.

**How this was checked.** An adversarial review (GPT-6.1 Sol, high effort) cross-checked the first draft, and its corrections are included. No HDL simulator was available, so the HDL timing claims come from a cycle model ([tools/vga_out_tb_cycle_model.py](tools/vga_out_tb_cycle_model.py)), not from simulation.

## 0. Agenda in one list

Decide in this order, because later items depend on earlier ones:

1. Which document is the single authority (§5.1).
2. Inputs (R1).
3. How a Match is won (R2), Rewards (R3), and Survival Bonus (R4).
4. Menus vs Setup Phase, and live switches (R6, R7).
5. Round flow (R8), steering (R9), and smooth movement (R10).
6. Accept or reject the technical recommendations in §3 as a block, discussing only the rows someone objects to.
7. Owners, calendar, and language (§5).

## 1. Already agreed: no discussion needed

| Topic | Shared choice |
|---|---|
| Board and video | Nexys A7-100T, 1280 × 800, totals 1680 × 828, RGB444, colour computed per pixel as the beam scans (no framebuffer) |
| Clock design | One pixel clock with a once-per-frame enable. Roman's `tick_60hz` is our Path B (ADR 0001); see §4 |
| Arena storage | Grid in dual-port BRAM. Address `{cy, cx}`. The game logic writes on one port; the drawing logic only reads on the other |
| Step semantics | Both Bikes move at once; both target Cells are read before any write. Head-on (same Cell or swap) means both Crash. Reversals of 180° are ignored, judged against the Heading from the last Step |
| Crash Step | A crashed Bike stays put and loses a Life. The other Bike still completes its move |
| Points cap | Saturates at 99 (Roman: `SCORE_MAX`; ours: 🔵, so this agreement can be marked ✅) |
| Start positions | P1 left-centre heading right, P2 right-centre heading left |
| Sprites | Bike stored once, facing up; the other Headings come from swapping and inverting ROM address bits |
| Arena reset | Engine clears the BRAM at the start of each Round (BRAM ignores `rst`) |
| Collisions | Use the grid; the sprite is cosmetic |

## 2. Game rules: team decisions

These change what the game *is*, so the team decides them. Each row gives the cost of each option and my lean.

| # | Topic | Roman (contract) | Ours (Mechanics) | Cost / consequence | Lean |
|---|---|---|---|---|---|
| R1 | **Inputs** | One USB keyboard on the USB HOST port (seen as PS/2): P1 WASD, P2 arrows. Buttons drive the menus | P1 board buttons; P2 WASD over USB-UART from our Web Serial page; BTNC/Space = Start | Both need a small serial receiver (`ps2_rx` ≈ UART RX in size). PS/2 risks: the keyboard must work with the board's USB HOST port, and cheap keyboards may drop some WASD + arrows combinations (Roman's contract flags both; test in his week 2). UART risks: needs a laptop with Chrome/Edge at the demo, and P1 crowds the board. Either counts as "extra I/O" | **PS/2 for both Players** if the board test passes. UART stays as fallback or an extra P2 source. This decides who builds `ps2_rx`/`teclado` vs `uart_rx` |
| R2 | **How a Match ends** | Points goal (`cfg_meta`, default 20) ends the Match at once. A Player with 0 Lives loses; if both reach 0, more Points wins | Ends when either Player reaches 0 Lives; **more Points wins**, so a Player can lose the last Life and still win | Same hardware cost (one comparator more for the goal). Ours makes Points matter until the end. Roman's makes Lives decisive and Rounds shorter | Team call. Our test `test_points_carry_over_and_decide_the_winner_not_lives` must change if Roman's rule wins |
| R3 | **Rewards** | One "rayo" of 2 × 2 Cells, value 1–5 (default 1), respawn delay 0–5 s (default 1 s). Both Players score if they take it in the same Step | Three Rewards at all times (+3, +3, +5 🔵), one Cell each, immediate respawn | One 2 × 2 Reward is easier to see at 16 px Cells and needs one position register. Three Rewards need three slot codes and three positions. Placement cost: see T6 | Team call. If three are kept, use Roman's one-attempt-per-frame placement (T6) |
| R4 | **Survival Bonus** | None | ✅ +5 🔵 to the Player who did not Crash | One adder at Round end. Its purpose is to make crashing on purpose a losing move, which matters only under our R2 rule | Keep it if our R2 rule wins; optional under Roman's |
| R5 | **Trail length** | Infinite / 64 / 32 / 16, chosen in the menu; each Bike has a 64-entry circular buffer | Infinite only (a finite Trail is a possible challenge variant) | The buffer costs 2 × 64 × 13 bits plus head and tail pointers, and an extra erase write each Step | Infinite for the Must tier; finite as a cut-first extra (it is already 5th in Roman's own cut order) |
| R6 | **Menus and settings** | On-screen main menu, Configuration and How-to-play screens (`menu_ctrl`, `texto_capa`, `font_rom`) | No on-screen menu. Setup Phase with the switches (Could tier); HUD is the Should tier | The text layer is the largest optional block. It needs the same `DRAW_LATENCY` as `drawcon` (T7) | Team call. Text is a visible demo feature, but schedule it after the core game, as Roman's week 4 does |
| R7 | **Switches** | Live, even mid-play: `sw[1:0]` speed, `sw[3:2]` colour theme, `sw[5:4]` background | Settings fixed for the Match; switches ignored during play; one switch = pause / Setup | Live speed changes need `desliz` trimming (Roman §4). Live theme and background are free | Live for cosmetic switches; speed only between Rounds (removes the `desliz` corner case); keep one pause switch |
| R8 | **Round flow** | 2 s countdown (can pre-choose start Heading), 2 s Crash screen, next Round starts by itself. BTNC leaves the Match screen | About 2 s freeze with the crashed Bike blinking; next Round waits for Start (🔵) | Same timer either way | Team call. The countdown fits PS/2 (hands on keyboard); waiting for Start fits buttons |
| R9 | **Steering buffer** | `teclado` keeps the last key pressed. The Step rejects it if it reverses the Step Heading. Heading RIGHT, press UP then LEFT → keeps going **RIGHT** | Keep the last *valid* Turn, judged against the current Heading. Same presses → turns **UP** | Ours forgives a fast UP-then-LEFT. It can be built **inside `tron_engine`** by watching `dir_pX` change, with no interface change | Ours, implemented in the engine; check with `prototype/tests` steering cases |
| R10 | **Smooth movement** | Sprite slides between Cells (`desliz`, week 4) | Won't this term | Adds per-Bike sprite position math in `drawcon` and a lookup table per speed. Collisions do not change | Stretch item (Roman cuts it 3rd anyway) |
| R11 | **7-segment layout** | Per Player: Lives, blank, 2 Points digits (`3 07  3 12`) | P1 Points, P1 Lives, P2 Points, P2 Lives (two Lives digits each) | Lives ≤ 9, so two Lives digits only add a leading zero | **Roman's** |
| R12 | **Crash display** | `CELL_CRASH` drawn as an X at the crashed head | Crashed Bike stays and blinks | Both are cheap | Both: X in the grid plus blink during the freeze |
| R13 | **Speed** | `MOVE_FRAMES` 6/4/3/2 by switch | `frames_per_step` 4 ⏳ | Same Cells/s at 4 frames (15 Cells/s). Pixel speed doubles at 16 px Cells | Roman's table, if R7 accepts speed on a switch |

## 3. Technical choices: recommendations

Rules are not affected here. Each row compares performance (time inside the 563.6 µs vertical blanking window, BRAM use) and how easily it integrates with the code that exists today.

Blanking budget used below: 28 blank lines × 1680 = **47,040 pixel cycles ≈ 563.6 µs** per frame.

| # | Topic | Roman | Ours | Performance | Ease of integration | Recommendation |
|---|---|---|---|---|---|---|
| T1 | Pixel clock | "83.5 MHz", left open (vs 106 MHz) | 83.46 MHz | — | — | **83.46 MHz.** The handout says so (README line 41); close the question in the contract |
| T2 | Sync polarity | Left open | hsync low for `hcount` 0–135; vsync high for `vcount` 0–2 | — | Roman's `vga_out.sv` already does this | **Handout values**; close the question |
| T3 | Frame enable name and timing | `tick_60hz`, at the end of the last visible line | `frame_tick` (ADR 0001) | Equivalent: both give the full 563.6 µs window | Roman's name is in the contract and the ports | **`tick_60hz`**; update ADR 0001 wording to refer to it |
| T4 | Cell size and grid | 16 px; 80 × 50 Cells; rows 0–1 are the HUD band; 13-bit `{cy[5:0], cx[6:0]}`; 8192 × 4 BRAM | 8 px default ⏳ (4/8/16 under test); 15-bit address | 16 px: 1 BRAM36, clear in 8192 cycles (≈ 98 µs). 8 px: 32 K words, 3–4 BRAM36, clear in 32,768 cycles (≈ 393 µs, 70% of blanking); placement scans 4× longer. Both fit the 135 BRAM36 of the XC7A100T | 16 px is what the contract, Python model and widths assume. Our 32 × 32 Bike covers 2 × 2 Cells at 16 px, 4 × 4 at 8 px | **16 px as the baseline**, with `TILE_SHIFT` a parameter so the 8 px monitor test (our L1) can still run. 16 px Rounds are shorter (3,840 Arena Cells vs about 15,500), which suits a demo |
| T5 | Cell encoding | 4 bits: 0 EMPTY, 1 WALL, 2 P1_TRAIL, 3 P1_HEAD, 4 P2_TRAIL, 5 P2_HEAD, 6 CRASH, 7 RAYO | 3 bits: 0 empty, 1 Wall, 2 P1 Trail, 3 P2 Trail, 4–6 Reward slots | 4 bits is free at 8192 depth (8K × 4 is a native BRAM36 shape) | Codes collide (3 = P1 head vs P2 Trail). Python, `game_pkg.sv` and the drawing logic must all agree | **4 bits, Roman's codes 0–7**, plus `8 + slot` for Reward slots if R3 keeps three Rewards. Update `prototype/model/arena.py` |
| T6 | Reward placement | One try per frame: corner from `rnd`; written if all 4 Cells are inside the Arena and empty; otherwise retry next frame | Up to 64 random draws, then a full grid scan, in one Step (Open item 4) | Roman: about 10 cycles per frame. Ours: up to ≈ 417 µs per placement, ≈ 834 µs for two, which **exceeds the blanking window** | Roman's needs no extra state machine. About 43% of 2 × 2 tries land inside the Arena, so an empty Arena places in ~2–3 frames (≤ 50 ms) | **Roman's scheme.** "Respawns at once" becomes "within a few frames", which Players cannot see. This closes our Open item 4 |
| T7 | Random numbers (LFSR) | 16-bit Galois, mask `0xB400`, **1 shift per frame** | 32-bit Fibonacci, taps 31/21/1/0, 32 shifts per draw | With 1 shift per frame, the next frame's `rnd[6:0]` is always the previous value shifted right by one bit (100% in a 20,000-frame check), so retries are correlated. With 16 shifts per frame this drops to 1% | Roman's module and port are simpler to keep | **Roman's 16-bit LFSR and port, advanced 16 steps per `tick_60hz`** (one cycle with an unrolled XOR network, or 16 cycles in blanking). Change `LFSR16` in `juego.py` to match |
| T8 | Pixel alignment | **Delayed stream**: `vga_out` delays `hsync`, `vsync` and blanking by `DRAW_LATENCY`; `curr_x`/`curr_y` are request coordinates | **Decision B**: `curr_x`/`curr_y` are the output pixel; sprite reads are issued early with wrap-aware future coordinates | Both meet 83.46 MHz easily. Delayed stream costs `DRAW_LATENCY` flip-flops on 3 signals | Delayed stream is much simpler: no future-coordinate math or line and frame wrap cases, and every layer (arena, sprites, text) pipelines the same way. It also matches the sprite tips' "start reading earlier" intent | **Delayed stream (Roman's).** Retire Decision B to "alternative" in our VGA plan. Define `DRAW_LATENCY` from the *measured* ROM IP latency, not 1 + 1 (see H5) |
| T9 | Sprite format | 16 × 16 colour-index ROM (colour, shadow, highlight, tyre) drawn at 2×; the theme chooses the palette | 32 × 32 12-bit RGB `.coe` (sprite tips), `000` transparent, `0F0` tint key | Both are tiny (≤ 12 Kb, one BRAM18 each) | The index plus palette makes Roman's colour themes free. The sprite tips allow any width and radix | **Colour-index ROM plus palette**, at 32 × 32 if our Look art needs the detail (4-bit index = 4 Kb). Roman, as video owner, picks the art |
| T10 | Reset | Synchronous active-high `rst` on every module; BRAM cleared by the engine | Declaration initial values | — | Testbenches need a reset; Roman's code uses it | **Roman's.** Also reset the `vga_out` output registers (H3) |
| T11 | Sync output | Registered (`always_ff`) | Handout step 9: `assign` | Registered outputs are glitch-free and can use I/O flip-flops | Required anyway once sync is delayed (T8) | **Registered**; record the deviation from step 9 in the report |
| T12 | Coordinates in blanking | `curr_x = hcnt - 336` wraps outside the visible area | Same in our sketch | — | Every consumer must gate with a "visible" flag | **Export one `visible` (delayed) signal** from `vga_out`, and never use raw coordinates outside it |
| T13 | White border | Missing in the prototype | Handout step 4: 10 px white border; in ours the Wall ring covers it | Free (compare 4 coordinate ranges) | — | **Add it to `drawcon`** as the top layer over the Wall Cells; the handout requires it |
| T14 | Simulator | Icarus (`iverilog -g2012`) on a Mac | Vivado xsim | — | Contract already bans port arrays for Icarus | **Both must pass:** every testbench compiles in Icarus and xsim, has `` `timescale ``, and ends with `$fatal` on error |

## 4. Paths A and B: can they coexist?

**Yes, as two separate builds.**

| Build | Clock | Purpose |
|---|---|---|
| `lab_top` (milestone V4) | Handout step 10 literally: a second divided ~60 Hz clock runs the moving block | Shows the handout steps to the TA; no game logic |
| `game_top` | One pixel clock plus `tick_60hz` (Path B) | The game, as in both Roman's contract and ADR 0001 |

A "divided clock that triggers the Path B engine" is still Path B: the engine runs on the pixel clock. It would also need a rule for when the trigger drifts away from vertical blanking. A true Path A game would need a command and result interface between the slow and pixel domains. Build it only if the TAs reject Path B, which is why the TA email ([[CS-256 TA Email - Game Clock]]) should still go out.

## 5. Process and documents

| # | Topic | Roman | Ours | Recommendation |
|---|---|---|---|---|
| P1 | **Authority** | The contract says interface changes are recorded *in the contract* first | Mechanics note, Glossary, Development Plan, ADRs | **One authority:** the contract in the team repo, rewritten with the team decisions from §2 and §3. Our notes become research or history and link to it. *Team decision.* |
| P2 | Document and code language | Spanish (identifiers such as `cab_p1`, `desliz`, `rayo`) | English with Glossary terms | *Team decision.* Reports and TA reviews are in English, which favours English identifiers before code grows. At minimum, add an English glossary column to the contract |
| P3 | Reference model | `prototipos/tron/juego.py` with `test_juego.py`; `arena_hex()` for `$readmemh` | `prototype/model` with Step logs; `prototype/look` for art and effects | **One rules model:** `juego.py`, updated to the §2 decisions. Port our Step-log comparison and steering tests into it. Keep our Look viewer for art and HUD candidates |
| P4 | Roles | A video, B game, C inputs/menus/top; unassigned. Testbench rotation A → B → C → A | Roman video, Kevin game logic and Arena, Alan inputs and Game Model | They map directly: **A = Roman, B = Kevin, C = Alan.** Keep both independence rules: testbench rotation, and the rules model and HDL engine written by different people |
| P5 | Calendar | Mon–Sun weeks; milestone due Sunday 23:59; tag `predemo` Sun 15 Nov; code freeze Thu 26 Nov | Sun–Thu KAUST weeks; pre-demo freeze Sun 15 Nov; demo freeze Mon 23 Nov | Both agree on the Sun 15 Nov pre-demo freeze. *Team decision* on the demo freeze (Mon 23 vs Thu 26 Nov) and the week format. Roman's week 1 (ends Sun 18 Oct) is behind: only `vga_out` exists |
| P6 | Scope order | Weeks 3–4: menus, text, themes, slide | Must: core game; Should: HUD; Could: Setup Phase | Use our tiers with Roman's cut order inside them |
| P7 | Contract gaps | `menu_ctrl` has no `tick_60hz` port, but the signal table says it receives one. `teclado` needs `nueva_ronda` | — | Fix in the contract |

## 6. Roman's HDL: review findings

| # | File | Finding | Fix |
|---|---|---|---|
| H1 | `counters.sv` | Correct: `hcnt` 0–1679, `vcnt` 0–827, synchronous reset | — |
| H2 | `proyecto_final/README.md` | Stale: still describes counting to 799 | Update to 1679 / 827 |
| H3 | `vga_out.sv` | Sync and RGB are registered together, so pins agree only while `drawcon` is combinational. `curr_x`/`curr_y` are one cycle ahead of the pins. `tick_60hz` is tied to 0. Output registers ignore `rst` | Add the `DRAW_LATENCY` delay line (T8), `tick_60hz`, a delayed `visible`, and reset of the output registers |
| H4 | `vga_out_tb.sv` | Compares the registered `pix` with `draw` at the *current* coordinates. Expect false mismatches at x = 0 and x = 1280 of every line: 1,600 per frame (cycle model; not run in a simulator) | Compare against coordinates delayed by the latency; add `` `timescale ``; check vsync, frame length and `tick_60hz`; `$fatal` on error |
| H5 | Contract §3 | `DRAW_LATENCY = 2` assumes one cycle for the arena read plus one for the ROM read. The sprite tips' ROM takes 2 cycles, and the ROM address does not depend on the arena data, so the two reads run in parallel | `DRAW_LATENCY` = max(arena, ROM IP latency) + 1 compose register; read it from the generated IP summary |
| H6 | Constraints file (XDC) | Entirely commented out | Owner C (Alan) uncomments the pins in week 2 |

## 7. Fixes needed in our own documents

These are independent of the team's decisions:

- `README.md` line 39 still says to keep the divided game clock as the baseline. It should say Path B (ADR 0001).
- [[CS-256 VGA and Sprite Design Plan]] §3 table, §6 step 10 row and closing "Course-baseline decision", §7 M3, and §8 Q3 still describe the divided clock as the baseline, contradicting the note's own header.
- ADR 0001 links depend on the old folder layout; check them after any move into the team repo.
- [[CS-256 Tron Development Plan]] Open item 4 closes if T6 is accepted.
