---
schema_version: 1
id: cs256-vga-sprite-design-plan-20261014
title: CS-256 VGA and Sprite Design Plan
type: note
subject: CS-256
status: draft
created_at: "2026-10-14T15:57:29"
updated_at: "2026-10-20T14:53:11"
term: 2026-fall
sources:
  - "[[CS-256 Tron Agreed Specification 2026-10-20]]"
  - "[[CS-256 Tron Team Decisions 2026-10-20]]"
  - "[[CS-256 Tron Game Overview]]"
  - "[[Nexys_A7_Game_Research_Report]]"
  - "[[CS-256 Official FPGA Coding Practices]]"
review_status: unreviewed
tags:
  - fpga
  - vga
  - sprites
  - tron
---

# CS-256 VGA and Sprite Design Plan

Use [[CS-256 Tron Architecture and Documentation Map]] for document status. The locked [[CS-256 Tron Agreed Specification 2026-10-20]] owns the selected game rules and implementation boundary; this note records design guidance and planned verification, not completed hardware behavior.

The 20 October documentation pass checked agreement consistency and navigation. Complete source review and implementation validation remain outstanding; the note's source-review status remains unchanged.

> [!decision] Follow the course READMEs — preference settled 2026-10-15
> Use the [class project handout](../cs256-fall-2026/classproject/README.md) and [sprite tips](../cs256-fall-2026/classproject/sprites/README.md) as the implementation baseline.
>
> 1. **Decision A (confirmed 2026-10-20, see [ADR 0002](docs/adr/0002-follow-ta-divided-game-clock.md)):** follow the TAs’ strict handout architecture. The second Clocking Wizard plus counter divider produces the approximately **60 Hz clock for the final game’s game-state logic**, not only milestone V4. ADR 0001 is superseded.
>    **Evidence:** AMD recommends enables instead of HDL clock gating ([UG949: Using Gated Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Using-Gated-Clocks)), describes enable inference ([Creating Clock Enables](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Creating-Clock-Enables)), and advises avoiding local clocks from fabric counter division ([Avoiding Local Clocks](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Avoiding-Local-Clocks)). Those guidelines motivated the superseded frame-enable proposal; they do not override the TAs’ course-architecture instruction. Routing, generated-clock constraints and coherent transfers remain implementation work.
> 2. **Decision B:** keep `curr_x`/`curr_y` aligned with the pixel being output and leave the handout's sync/visible timing unchanged. Start sprite reads early by the configured ROM latency, as the sprite tips describe.
>
> [[CS-256 Official FPGA Coding Practices]] documents implementation guidance and the [[CS-256 Official FPGA Coding Practices#Historical comparison of both clock paths|historical clock-path comparison]]. For the final game, the divided-clock path is selected (ADR 0002). Output-aligned coordinates and early sprite reads remain the course baseline; alternatives are historical research, not active design choices. Timing constraints, state transfers and boundary handling still require implementation evidence.

This note covers the research and planning phase for the VGA display and sprite pipeline of the Tron game in [[CS-256 Tron Game Overview]]. The binding requirements are the [class project README](../cs256-fall-2026/classproject/README.md) (the **handout**) and the [sprite tips](../cs256-fall-2026/classproject/sprites/README.md) (the **sprite tips**). Section 6 checks every design choice against them, step by step.

This remains a design plan, with no implementation validation claimed. Course requirements and the TAs’ architecture instruction take precedence, followed by the locked team decisions in [[CS-256 Tron Agreed Specification 2026-10-20]]. The remote interface contract is the selected implementation contract after it has been reconciled with that baseline. The previous one-clock/delayed-sync sketch is retained in the appendix as **superseded, unsimulated reference**. A Python model previously checked sprite-rotation addressing; it did not verify clocking or VGA alignment.

> [!info] Working geometry and assets, selected 20 October 2026
> Use **16 px Cells**, **32 × 32 px Bike sprites** and **16 × 16 px Reward sprites** on the course's **1280 × 800** visible image (80 × 50 screen Cells before Walls/HUD). Reserve **64 px at the top for HUD**, exactly four Cell rows and 8% of image height, initially with **32 px text**. A separate 16 px Wall below gives **78 × 44 playable Cells**, `cx=1..78`, `cy=5..48`. Per Q23, these are **revisable working bounds, not a hard lock**. Until revised consistently, text must fit the selected band. Earlier 8 px examples below are historical calculations, not the selected geometry. **Native 12-bit RGB444 `.coe` sprites are selected**: 1024 words per Bike and 256 per Reward. Q35 centres Bike sprites on head Cells; Q36 selects `000` transparency, `0F0` tint and initial P1 cyan/P2 orange, without a special `080` glow key. Implementation details remain open. The course sprite README permits arbitrary image sizes (its example is 40 × 30), so square power-of-two art is our addressing choice. Its 2-cycle latency is an example; inspect the actual IP configuration. See [[CS-256 Tron Team Decisions 2026-10-20#Course README guidance checked for Q14]].

## 1. Settled facts

### The video mode is fixed by the course: 1280 × 800 at about 60 Hz

This settles the whiteboard note "Revisar 1280p": the course mode is 1280 × 800, not 720p and not the report's 640 × 480 starting mode. The numbers come from the handout's *VGA Sync Signals* and *Outputing Pixels* sections:

| Parameter | Horizontal (pixels) | Vertical (lines) |
|---|---|---|
| Counter range | `hcount` 0–1679 (11 bits) | `vcount` 0–827 (10 bits) |
| Sync pulse | 0–135 (136), **active low** | 0–2 (3), **active high** |
| Back porch | 136–335 (200) | 3–26 (24) |
| Visible | 336–1615 (1280) | 27–826 (800) |
| Front porch | 1616–1679 (64) | 827 (1) |
| Total | 1680 | 828 |

- The pixel clock is **83.46 MHz**, so 83.46 MHz / (1680 × 828) = **59.998 Hz** frame rate and 49.68 kHz line rate.
- The counters start at the sync pulse: sync, then back porch, visible region, and front porch, as in [vgawaveform.png](../cs256-fall-2026/classproject/vgawaveform.png).
- Use the **handout's numbers**. Digilent's official manual §8.1 illustrates 640 × 480 and directs readers to VESA for other modes; it does not independently certify this course's 1280 × 800 timing ([manual, physical pp. 18–21](https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf#page=18)).
- **Risk:** monitors vary in which 16:10 timing they lock to. Test the lab monitor at milestone M0.

### A full framebuffer does not fit, so render per pixel ("race the beam")

| Store | Size | vs. 4,860 Kb BRAM |
|---|---|---|
| 1280 × 800 × 12-bit frame | 12,288,000 b | **does not fit** (2.5×) |
| 80 × 50 Arena grid (16 px Cells), 4 bits per Cell | 32 Kb (8192 × 4, padded 128 × 64 allocation) | 1 RAMB36 estimate; verify generated IP/synthesis |
| 32 × 32 × 12-bit bike sprite, one ROM per bike | 12,288 b each | 1 RAMB18 each |

The XC7A100T has 135 × 36 Kb = 4,860 Kb BRAM ([DS180, Table 4, p. 3](Datasheets/DS180_7_Series_FPGA_Overview.pdf)). Pixel colour is therefore computed from small memories as the beam scans: the handout's `vga_out` + `drawcon` structure ([game_top.png](../cs256-fall-2026/classproject/game_top.png)).

### Clock and timing headroom

- **MMCM:** for speed grade -1, the VCO range is 600–1200 MHz and the PFD range is 10–450 MHz ([DS181, Table 37, pp. 38–39](Datasheets/DS181_Artix_7_DC_AC_Switching.pdf)). A search over legal settings found **83.4586 MHz** (D = 7, M = 55.5, O = 9.5, VCO = 792.9 MHz), an error of 0.002%. The handout notes the wizard "will not achieve the exact requested frequency, but it will be close enough". Record the frequency it actually reports.
- **BRAM:** -1 Fmax is 388.20 MHz ([DS181, Table 30, p. 31](Datasheets/DS181_Artix_7_DC_AC_Switching.pdf)), about 4.6× the pixel clock. Clock-to-out is 0.89 ns with the output register (p. 30), which leaves the 11.98 ns pixel period mostly free for the colour mux.

### Board pins

The VGA pins come from the class copy of the master XDC, [nexys-a7-100t-master.xdc](../cs256-fall-2026/nexys-a7-100t-master.xdc). Its header notes that the Nexys 4 DDR (the board named in the handout) and the Nexys A7 share the XDC.

| Signal | Pins |
|---|---|
| `VGA_R[3:0]` | A4, C5, B4, A3 (bit 3 → 0) |
| `VGA_G[3:0]` | A6, B6, A5, C6 |
| `VGA_B[3:0]` | D8, D7, C7, B7 |
| `VGA_HS`, `VGA_VS` | B11, B12 |
| `CLK100MHZ` | E3 (`create_clock -period 10.00`) |
| `BTNC/U/L/R/D` | N17, M18, P17, M17, P18 |

The DAC is a 4-bit resistor-divider circuit per colour (RGB444, 4,096 colours), producing about 0–0.7 V with the monitor's 75 Ω termination. Verified directly in [Digilent's reference manual, §8, physical p. 18](https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf#page=18) on 2026-10-15.

## 2. Architecture

Keep the handout's hierarchy and signal meanings: `game_top` contains the clock generation, position/game logic, `vga_out` and combinational `drawcon`. Extend that baseline with sprite ROMs and the Arena grid.

### Decision A: use the handout's divided game clock

> [!decision] Applies to the final game, confirmed 2026-10-20
> The TAs recommended following this architecture strictly. This section is the active baseline; [ADR 0002](docs/adr/0002-follow-ta-divided-game-clock.md) supersedes ADR 0001.

Follow *Drawing Logic Module* steps 10–13: instantiate the second clock divider, request a low supported frequency, then use a counter to divide it to approximately 60 Hz. Update the moving block's position on that slow clock. For M1, implement the literal centre reset and ±4-pixel button-controlled movement with boundary checks before extending to Tron rules.

The manufacturer's detailed guidance is in [[CS-256 Official FPGA Coding Practices#Game clock and Decision A]] and [[CS-256 Official FPGA Coding Practices#Clock-domain transfers for Path A]]. A divider flip-flop feeding a BUFG is device-supported, but UG472 marks the interconnect-to-BUFG source route as not recommended; the buffer improves distribution after its input, not the whole source path. Verify the actual implementation. A full handshake back to a 60 Hz source also has a multi-tick turnaround, so its throughput must be checked before selecting it.

The display and ROM reads run on `pixclk` (requested 83.46 MHz). The game clock is separate and is not assumed to coincide with vertical blanking. Use suitable clock routing and generated-clock constraints, and inspect the actual relationship in Vivado. A divided clock is not automatically asynchronous, but any transfer still needs a defined timing/coherency contract. See [[CS-256 Official FPGA Coding Practices#Game clock and Decision A]].

The selected boundary uses fast Arena/memory service alongside the slower game-state domain and fast video. Work out how a Step request, coherent Bike position/Heading state, and grid updates cross those interfaces; the exact service clock and transfer protocol remain implementation tasks. Multi-cycle memory work must not be paced by the 60 Hz game clock. Do not assume independently synchronized bits form a coherent position, or claim blanking-only updates before the transfer is designed and tested.

### Decision B: prefetch sprite data while keeping current-pixel timing

Follow *Visible Pixel Counter* step 1: `curr_x`/`curr_y` describe the pixel currently being output. They range from 0/0 at the first visible pixel to 1279/799 at the last. Connect these current coordinates to `drawcon` for the border, background and current sprite-region selection. Keep `hsync`, `vsync` and RGB blanking tied to the handout's raster counters.

Use a separate **prefetch coordinate** only for memory addressing. If the generated sprite ROM reports a read latency of `L` pixel clocks, issue the address for a pixel `L` cycles before that pixel is displayed. The sprite tips' example has `L=2`; verify the actual generated IP Summary and model rather than assuming every ROM has that latency.

Advance the complete raster position by `L`, handling horizontal wrap and vertical/frame wrap, then derive the future visible coordinate and sprite-local address. Do not use a bare `curr_x + L`: current coordinates are invalid in blanking and cannot handle the next line alone. Prefetch the first visible pixels during the preceding porch. Qualify future coordinates with future visibility and sprite bounds; qualify composition with the current visible interval and current sprite bounds.

Sprite positions and Heading used for a prefetched address must match those used to display its returned texel. Keep a coherent render snapshot stable across the read/display interval, and validate startup and update boundaries. If the trail grid has a different read latency, issue its address with its own lead or balance the data paths so both results match the current output pixel.

| Time | Memory work | Display work |
|---|---|---|
| `t-L` | Issue the sprite address for the pixel that will be visible at `t` | Render the current pixel using previously fetched data |
| `t` | Continue fetching later pixels | ROM data, `curr_x`/`curr_y`, current sprite mask and unchanged VGA timing all describe the same pixel |

This follows the sprite tips' early-read instruction while preserving the handout's output-coordinate contract. There is no selected `LAT` delay on sync or current coordinates. Detailed latency, first/last-pixel and wrap examples are in [[CS-256 Official FPGA Coding Practices#Pixel alignment and Decision B]]. The delayed-stream sketch is retained as historical pipeline research and is not an outstanding design choice.

### Decision C: collisions use the Arena grid; the sprite is cosmetic

Retain the grid-based game design and rules in [[CS-256 Tron Agreed Specification 2026-10-20]]. The earlier 8-pixel Cell and two-bit grid are historical exploration, not the selected baseline. Rewards require the agreed four-bit encoding.

Render-side grid reads must describe the current displayed pixel after their memory latency. Game-side reads/writes need an explicit memory-controller schedule and same-address collision policy. Evaluate both Bikes' proposed moves before committing either Trail so a Step respects the agreed simultaneous movement rules. Do not use the superseded per-Player read/check/write loop as a complete collision algorithm.

## 3. Implementation contracts following the handouts

| Module or stage | Baseline contract |
|---|---|
| `vga_out` | Handout counters, sync polarities, visible region, zero RGB in blanking and output-aligned `curr_x`/`curr_y`. No delayed-sync sprite variant. |
| Pixel clock | Clocking Wizard requests 83.46 MHz. At the initial handout stage, leave reset/locked unchecked as instructed; move the instance to `game_top` at *Visible Pixel Counter* steps 2–3. Any later startup additions must preserve the demonstrated baseline. |
| Game clock | Second clock divider plus counter, approximately 60 Hz, used by the position/game logic as described in *Drawing Logic Module* steps 10–12. Record the achieved rate. |
| Sprite address logic | Uses future raster coordinates and the coherent sprite state to issue reads `L` cycles early; rotation by address remains available for square art. |
| Sprite memory | Block Memory Generator, Single Port ROM, 12-bit width and depth matching the `.coe`; inspect address width and latency in Summary. |
| `drawcon` | Purely combinational. Uses current display coordinates with matching prefetched texels; the nonzero foreground wins, otherwise background. |
| Game/render boundary | The fast Arena service owns memory writes. Define and test coherent slow-game requests/results and render snapshots; the exact fast clock, transfer protocol, and service bounds remain unresolved. |

No replacement HDL is claimed here. The previous code is preserved in the appendix to avoid mistaking its frame-enable and delayed-sync assumptions for the selected implementation.

## 4. Sprite asset pipeline (follows the sprite tips)

1. Draw the bike at 32 × 32, pointing up, on a black (`000`) background, with pure-green paint areas. 32 × 32 keeps the address a bit concatenation. The palm example is 40 × 30, which needs `row*40 + col`.
2. Convert with a short Python script (planned: `tools/png2coe.py`, using Pillow), as the sprite tips suggest. Quantize each channel to 4 bits (`v >> 4`) and write the pixels **row by row** (1024 × 1 vector, radix 16):

   ```text
   memory_initialization_radix=16;
   memory_initialization_vector=
   000,000,...;
   ```

3. Configure Block Memory Generator exactly as in the sprite tips:
   - component name `bike`;
   - **Single Port ROM**, other parameters left at their defaults;
   - Port A width 12, depth 1024, Enable Port Type "Always Enabled";
   - Other Options → Load Init File → `bike.coe`.

   In the Summary tab, confirm the **address width (10)** and the **actual reported read latency** (2 cycles in the course example). Use the measured configuration as the prefetch lead; keep current coordinates and sync timing unchanged.
4. Instantiate it twice, once per bike: `bike bike1 (...)`, `bike bike2 (...)`. Each instance is a separate single-port ROM: 2 of 270 RAMB18 blocks.

## 5. Planned verification (feeds the 3-mark testing section of the report)

| Test | Checks |
|---|---|
| `tb_vga_out`, handout steps 4–8 | `hcount` wraps 1679 → 0, `vcount` 827 → 0. `hsync` is low for exactly 0–135 and `vsync` is high for exactly 0–2. Pixels are non-zero only in 336–1615 × 27–826. `curr_x`/`curr_y` read 0/0 at the first visible pixel and 1279/799 at the last. A frame is 1,391,040 cycles. |
| Sprite prefetch timing | Read each texel `L` cycles early and check it appears at the current `curr_x`/`curr_y`, with unchanged sync timing. Check first/last pixels, line/frame wrap, startup and state updates. |
| `tb_frame_dump` ("virtual monitor") | Works only from `hsync`/`vsync`, as a monitor would. It counts pixels after each sync edge and writes one frame to a `.ppm` file (`P3 1280 800 15`) via `$fwrite`. View the frame on the PC before using the board. |
| Sprite alignment | In the dumped frame, the sprite's top-left texel lands exactly at (`blkpos_x`, `blkpos_y`) in all four rotations. This proves the latency compensation. |
| Game logic and clock transfer | Check the divided game-clock rate and M1 button/reset behavior. Then check coherent game/render transfers, grid operations and simultaneous Steps against the agreed specification. |

The Block Memory Generator ships a behavioural simulation model, so the ROMs work in xsim. Keep waveform captures and the `.ppm` frames as report figures.

## 6. Compliance check against the handout and sprite tips

Status key:

- ✅ = the planned contract follows the instruction; implementation verification is still pending.
- ➕ = adds something the handout does not mention, without changing what it asks for.
- ⚠️ = deliberate deviation, with the reason given.

### Handout: VGA Sync Signals and Outputing Pixels

| Handout instruction | Plan | Status |
|---|---|---|
| Step 5: ports `clk`; 4-bit `pix_r/g/b`; 1-bit `hsync`, `vsync` | Same names and widths | ✅ |
| Step 6: internal 11-bit `hcount`, 10-bit `vcount` | Same | ✅ |
| Step 7: `always_ff`, `hcount` counts to 1679 and wraps | Same | ✅ |
| Step 8: `vcount` increments on wrap and wraps after 827, in a single always block | Same block, `vcount` updated only when `hcount == 1679` | ✅ |
| Step 9: `assign` statements; `hsync` 0 for 0–135; `vsync` 1 for 0–2 | `assign`, same ranges, no sprite-induced delay | ✅ |
| Pixels: visible 336–1615 and 27–826, colours via `assign`, else 0 | Same ranges and `assign` gating | ✅ |
| Switch-selected colour across the frame | M0 connects switches to `draw_r/g/b` | ✅ |
| Testbench: instantiate, clock, run behavioural simulation, check counters/pulses | `tb_vga_out`. Counters get declaration initial values (`= '0`) because the handout has no reset. Without them, the counters stay X in simulation | ✅ ➕ |
| Clocking Wizard 83.46 MHz, reset/locked unchecked, output `pixclk`, used by all `always_ff` | Follow the handout settings for the baseline; manufacturer startup guidance remains documented separately | ✅ |
| Constraints: VGA, clock and switch lines uncommented and renamed | Plan uses the class XDC copy | ✅ |

### Handout: Visible Pixel Counter

| Handout instruction | Plan | Status |
|---|---|---|
| Step 1: `curr_x` 0–1279 and `curr_y` 0–799, aligned with the valid region; separate always block *or* offset counter | Offset counter (`hcount - 336`, `vcount - 27`), valid during the visible region and aligned with `pix_*` | ✅ |
| Same step, with sprites enabled | Keep current coordinates output-aligned; use separate future coordinates only for early memory reads | ✅ |
| Steps 2–3: clock wizard moved to `game_top`; `vga_out` uses `clk` | Same | ✅ |
| Step 5: rectangle `520 < x < 760`, `300 < y < 500` | Milestone M1 | ✅ |

### Handout: Drawing Logic Module

| Handout instruction | Plan | Status |
|---|---|---|
| Step 2: `drawcon` with `blkpos_x/y`, `draw_x/y` in; `r, g, b` out | Same names. The plan also adds `mem_bike*`, `cell`, and colour inputs | ✅ ➕ |
| Steps 3–4: `bg_r/g/b`, 10-pixel white border | Same. Trails and grid lines are drawn in the `bg` block | ✅ ➕ |
| Steps 5–6: `blk_r/g/b` bright when inside `blkpos + 32` | Same box test; colour comes from the ROM | ✅ (sprite version) |
| Step 7: non-zero foreground wins, otherwise background | Same rule. Black is the sprite's transparent colour | ✅ |
| Step 8: all `drawcon` logic combinational | Combinational. ROM and prefetch logic sit outside `drawcon` | ✅ |
| Step 9: instantiate in `game_top` and connect to `vga_out` | Connect current coordinates and matching prefetched texels, without delaying the handout timing | ✅ ➕ |
| Step 10: second clock divider + counter → ~60 Hz game clock | Second clock divider plus counter as instructed (Decision A) | ✅ |
| Steps 11–12: five buttons; centre resets to the centre; ±4 per tick | Literal ±4 version at M1. The selected game moves one 16 px Cell every six approximately 60 Hz game-clock ticks | ✅ M1 / ➕ game |
| Step 13: the block cannot hit the border | Selected 16 px Cells use side Wall columns 0/79; preserve the 10 px white border, keep head Cells inside the playable bounds and clip cosmetic sprite overlap as needed | ✅ |
| `game_top` diagram: position logic / `drawcon` / `vga_out` / two clock dividers | Retain the two clock dividers and handout blocks; add sprite/grid/Scoreboard modules | ✅ ➕ |

### Sprite tips

| Sprite-tips instruction | Target plan | Workspace status |
|---|---|---|
| `.coe` row-by-row vector, radix 16, 12-bit RGB (4 bits each) | Planned converter emits the handout format | Not implemented; `tools/png2coe.py` is absent from this workspace |
| Matlab/Python conversion script | Planned Python converter using Pillow | Not implemented |
| Block Memory Generator, renamed component, **Single Port ROM**, other defaults | Planned `bike` ROM, one instance per Bike | No generated IP project is present |
| Port A width = bits per pixel (12), depth = rows (1024); enable "Always Enabled" | Planned configuration | Not generated or verified |
| Load the init file in Other Options | Planned `.coe` association | Not generated or verified |
| Instantiation: `name inst (.clka(clk), .addra(...), .douta(...))` | Planned ROM instances and connections | No HDL implementation is present |
| Address derives from the current pixel, sprite position and size; width from the Summary tab | Use prefetched position and sprite bounds, then check generated address width | No HDL implementation or IP Summary is present |
| 2-cycle ROM latency: start reading 2 cycles before display | Use the actual configured end-to-end latency as the prefetch lead; 2 cycles is the course example | Not verified; actual IP latency is unknown |

**Course-baseline decision:** follow the divided game clock and early sprite reads. The clock-enable and delayed-stream alternatives in [[CS-256 Official FPGA Coding Practices#Historical comparison of both clock paths]] are preserved only as historical context. Clock transfer, prefetch boundary handling and simulation remain implementation work.

## 7. Design work and verification links

The work-list IDs and their completion checks live in [[CS-256 Tron Development Plan#Work list]]. Internal build targets remain tentative; the course assessment dates remain fixed as recorded in that plan.

| Design work | Existing work-list IDs | Readiness and evidence |
|---|---|---|
| Course video timing and handout movement exercise | V1–V4 | Testbench and board checks listed in the development plan; the game clock must follow ADR 0002. |
| Sprite assets and output-aligned prefetch | L3, P2, P3 | Test actual ROM latency, first/last pixels, line/frame wrap, and all four rotations. |
| Agreed game core, Arena service, input, and Scoreboard | A1/A2, G1–G5, I1–I4, X1/X2 | Follow the agreed specification; record simulation, CDC/timing, and board evidence under the existing objective IDs. |
| On-screen HUD and optional styling | H2, C1/C2 | HUD follows the core. Menus, live customization, glow, scanlines, animated backgrounds, and power-ups are outside the core; power-ups are out of term. |

Planned source files go in `CS-256/Game_research/`, per the folder policy in [README](README.md):

- `hdl/`: `vga_out.sv`, `drawcon.sv`, `game_top.sv`, `game_top.xdc`;
- `sim/`: `tb_vga_out.sv`, `tb_frame_dump.sv`;
- `tools/png2coe.py`;
- `assets/`: `.coe` files.

## 8. Settled inputs and remaining engineering work

Gameplay and the project baseline are settled in [[CS-256 Tron Agreed Specification 2026-10-20]]; this plan has no remaining group rule questions. Use [[CS-256 Tron Glossary]] for terms. The Arena layout is revisable after playtesting, and the internal 15/23 November planning targets are flexible.

The selected clock and pixel pipeline are documented above and in ADR 0002. The exact generated-clock setup, ROM latency, fast-memory schedule, clock-domain transfer protocol, reset/Pause handling during transactions, and resource/timing results still need engineering and verification evidence. These are open implementation tasks, not undecided replacements for the selected architecture.

The initial art format excludes the candidate `080` dim-tint key. Reconcile candidate assets before claiming they follow the core format. Optional effects remain subject to scope and the design/evidence checks in the development plan.

## Sources to confirm

- [x] Nexys A7 Reference Manual, §8, physical p. 18: resistor-divider DAC, 75 Ω termination, 0–0.7 V. Official PDF checked on 2026-10-15.
- [x] Official AMD coding guidance for Decisions A/B: [[CS-256 Official FPGA Coding Practices]]. Technical evidence gathered; user selected the course baseline instead of the proposed deviations.
- [ ] The Clocking Wizard's achieved frequency and the Block Memory Generator Summary latency, once the IPs are generated.

## Appendix. Alternative one-clock and delayed-sync sketch

> [!warning] Alternative reference only — not the current baseline
> The following unsimulated sketch is retained as historical research. Its `frame_tick` game architecture and `LAT`-delayed sync/request-stage `curr_x`/`curr_y` are **not the selected baseline**, and its timing/behavior claims are unverified. It is not an implementation candidate or an outstanding architecture decision. See the historical comparison in [[CS-256 Official FPGA Coding Practices#Historical comparison of both clock paths]].


#### `vga_out`: handout timing, plus `LAT` and `frame_tick`

```systemverilog
module vga_out #(
    parameter int LAT = 0                 // render latency to compensate (0 = handout version)
    )(
    input  logic        clk,              // pixel clock from clk_wiz in game_top
    input  logic [3:0]  draw_r, draw_g, draw_b,
    output logic [3:0]  pix_r, pix_g, pix_b,
    output logic        hsync, vsync,
    output logic [10:0] curr_x,           // 0..1279 across the visible region
    output logic [9:0]  curr_y,           // 0..799 across the visible region
    output logic        frame_tick        // one cycle per frame, first blanking line
    );

    logic [10:0] hcount = '0;             // initial values: simulation does not start at X
    logic [9:0]  vcount = '0;

    // hcount counts 0..1679; vcount steps when hcount wraps and counts 0..827
    always_ff @(posedge clk)
    begin
        if (hcount == 11'd1679)
        begin
            hcount <= 11'd0;
            if (vcount == 10'd827)
                vcount <= 10'd0;
            else
                vcount <= vcount + 1'b1;
        end
        else
            hcount <= hcount + 1'b1;
    end

    // Sync and visible region straight from the counters (handout steps)
    logic hs_now, vs_now, vis_now;
    assign hs_now  = ~(hcount <= 11'd135);                    // 0 for hcount 0..135
    assign vs_now  =  (vcount <= 10'd2);                      // 1 for vcount 0..2
    assign vis_now = (hcount >= 11'd336) && (hcount <= 11'd1615) &&
                     (vcount >= 10'd27)  && (vcount <= 10'd826);

    // Offset counters, aligned with the visible region
    assign curr_x = hcount - 11'd336;
    assign curr_y = vcount - 10'd27;
    assign frame_tick = (hcount == 11'd0) && (vcount == 10'd827);

    // Delay sync/visible by LAT cycles to match the sprite ROM latency
    logic hs_out, vs_out, vis_out;
    generate
        if (LAT == 0)
        begin : g_nodelay
            assign {hs_out, vs_out, vis_out} = {hs_now, vs_now, vis_now};
        end
        else
        begin : g_delay
            logic [2:0] sr [1:LAT];
            always_ff @(posedge clk)
            begin
                sr[1] <= {hs_now, vs_now, vis_now};
                for (int i = 2; i <= LAT; i++)
                    sr[i] <= sr[i-1];
            end
            assign {hs_out, vs_out, vis_out} = sr[LAT];
        end
    endgenerate

    assign hsync = hs_out;
    assign vsync = vs_out;
    assign pix_r = vis_out ? draw_r : 4'h0;
    assign pix_g = vis_out ? draw_g : 4'h0;
    assign pix_b = vis_out ? draw_b : 4'h0;

endmodule
```

With `LAT = 0`, everything after the counters is `assign` statements, as in handout step 9 and *Outputing Pixels* step 2. With `LAT = 2`, sync comes straight from flip-flops, so it is glitch-free.

For milestone M0, connect switches to `draw_r/g/b` and instantiate the clock wizard inside `vga_out`, as the handout first does. At *Visible Pixel Counter* step 2, move the wizard to `game_top`.

#### `bike_addr` plus ROM: rotation by address (sequential side)

```systemverilog
// in game_top, one per bike (bike 1 shown)
logic [10:0] dx_full;
logic [9:0]  dy_full;
logic [4:0]  dx, dy;
logic [9:0]  address_bike1;               // 1024 words -> 10 bits (check the Summary tab)
logic [11:0] mem_bike1;

assign dx_full = curr_x - blkpos_x;       // offset inside the 32 x 32 box
assign dy_full = curr_y - blkpos_y;
assign dx = dx_full[4:0];
assign dy = dy_full[4:0];

// Art is stored pointing UP, row by row: address = {row, col}
always_comb
begin
    case (dir1)
        UP:      address_bike1 = { dy,  dx};
        DOWN:    address_bike1 = {~dy, ~dx};      // 180 degrees
        RIGHT:   address_bike1 = {~dx,  dy};      // 90 degrees clockwise
        LEFT:    address_bike1 = { dx, ~dy};      // 90 degrees counter-clockwise
        default: address_bike1 = { dy,  dx};
    endcase
end

// Block Memory Generator: Single Port ROM, width 12, depth 1024, bike.coe
bike bike1 (.clka(pixclk), .addra(address_bike1), .douta(mem_bike1));
bike bike2 (.clka(pixclk), .addra(address_bike2), .douta(mem_bike2));

// Delay the coordinates by the ROM latency (2) so drawcon sees matching pixels
always_ff @(posedge pixclk)
begin
    x_d1   <= curr_x;
    y_d1   <= curr_y;
    draw_x <= x_d1;
    draw_y <= y_d1;
end
```

A Python model checked the rotation table on a 4 × 4 image for all four directions. **One ROM image covers all four headings.** The trail grid's port A uses the same `{curr_y[9:3], curr_x[10:3]}` address at *t*, so its `cell` output is aligned with `draw_x`/`draw_y` too.

#### `drawcon`: combinational, using the handout's names

```systemverilog
// bg_r/g/b: 10-pixel white border, then Tron grid lines, then background colour
always_comb
begin
    if (draw_x < 10 || draw_x > 1269 || draw_y < 10 || draw_y > 789)
        {bg_r, bg_g, bg_b} = 12'hFFF;
    else if (cell == 2'd1)
        {bg_r, bg_g, bg_b} = p1_trail;
    else if (cell == 2'd2)
        {bg_r, bg_g, bg_b} = p2_trail;
    else if (draw_x[4:0] == 5'd0 || draw_y[4:0] == 5'd0)
        {bg_r, bg_g, bg_b} = GRID;
    else
        {bg_r, bg_g, bg_b} = bg_colour;
end

// blk_r/g/b: inside the 32 x 32 box, take the ROM pixel (handout step 6 with a sprite)
always_comb
begin
    if (draw_x >= blkpos_x && draw_x < blkpos_x + 32 &&
        draw_y >= blkpos_y && draw_y < blkpos_y + 32)
        {blk_r, blk_g, blk_b} = (mem_bike1 == KEY_TINT) ? p1_colour : mem_bike1;
    else
        {blk_r, blk_g, blk_b} = 12'h000;
end

// Handout step 7: non-zero foreground wins, otherwise background
assign {r, g, b} = ({blk_r, blk_g, blk_b} != 12'h000) ? {blk_r, blk_g, blk_b}
                                                     : {bg_r, bg_g, bg_b};
```

The second bike gets a second `blk2_*` block, and the same non-zero rule picks bike 1, then bike 2, then the background.

**Transparency follows the handout's rule: `12'h000` (black) is transparent.** The art therefore uses `12'h111` where it needs near-black. One extra key, `12'h0F0` (pure green), marks "paint" pixels that are replaced by the switch-selected player colour. That key is the whiteboard's customization feature.

#### Game logic: runs only when `frame_tick` is high

```text
IDLE --frame_tick--> (every K ticks, K from the challenge switch)
  for each player:
    READ   grid[next_head]        (port B, wait 2 cycles)
    CHECK  != 0  -> crash: lives--, respawn or round over
    WRITE  grid[next_head] = player_id ; head <= next_head
  blkpos = head*8 - 12 (sprite centred on the head cell), dir
  BTNC  -> reset positions to the centre (handout step 12)
```

The target is fewer than 20 cycles inside the 47,040-cycle vertical blank; verify this bound in simulation. `blkpos_x/y` and `dir` must be stable while visible pixels are in flight. Buttons pass through a synchronizer clocked on every `pixclk` edge. Frame-rate sampling is separate from synchronization and is not a guaranteed debounce method; use a stable-sample interval and event detection where one press must produce one action. These are implementation recommendations from [[CS-256 Official FPGA Coding Practices]], not simulated properties of this sketch.

