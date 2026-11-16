---
schema_version: 1
id: cs256-game-fast-crossing-research-20261029
title: CS-256 Game-Fast Crossing Research
type: note
subject: CS-256
status: proposed
created_at: "2026-10-29"
term: 2026-fall
sources:
  - "[[0002-follow-ta-divided-game-clock]]"
  - "[[0003-step-transaction-mailbox-and-render-codes]]"
  - "[[0005-build-with-provisional-interfaces]]"
  - "https://docs.amd.com/v/u/en-US/ug472_7Series_Clocking"
  - "https://docs.amd.com/r/en-US/pg065-clk-wiz"
  - "https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Unexpandable-Clocks"
review_status: unreviewed
tags:
  - tron
  - fpga
  - research
  - clocking
  - cdc
---

# CS-256 Game-Fast Crossing Research

Research checked **29 October 2026**, worktree `t3-0484e773`, HEAD `d2c61ea6fe784a185db8e9212bed0c629a8fb78e`. **Proposal, not team agreement or hardware sign-off.** Only this note and the isolated `proyecto_final/prototypes/core_blocks/crossing/` experiment were written. Game sources, the contract, ADRs and locked decisions were not edited. Git was read-only. Vendor facts below have numbered primary-source references; project observations have E references; schedules and proposed constraints are engineering deductions, not measured candidate performance.

## Recommendation and decision boundary

**Propose an explicit bundled-data, two-phase request/acknowledge crossing with two synchronizer stages on every control crossing, and qualified destination payload capture. Do not sign off the current 21 return endpoints on settling time alone.** First prototype the scheduling optimization described below for READ2 + COMMIT: resolve and issue COMMIT on the qualified READ2 capture edge, and retire on the qualified COMMIT capture edge. That targets **3 + 3 = 6 game ticks**, with no spare tick. It keeps collision state and scoring on `clk_juego`, but must pass sustained-cadence, Pause and rearm tests before selection. If that schedule fails, use ADR 0003 item 1's **atomic fast-service Step**, with game-domain state/scoring publication; a conservative registered consumer then targets **4 ticks per atomic Step**, leaving two ticks. The atomic fallback needs an explicit contract/owner interpretation of where collision *computation* may run. Neither target has been simulated or routed in this research. [S1, S4, S5; E1–E4]

Keep **(a), two board-fed Clocking Wizards plus the fabric divider**, for the next crossing experiment. **(b), one shared MMCM, is technically feasible and saves a clock manager, but does not make the final game crossing safely timeable in the measured probe.** (c) also leaves an enormous period ratio and adds cascading/clock-startup dependencies. There is no demonstrated latency/sign-off improvement that justifies a clock-source change to fix these endpoints. If saving an MMCM becomes useful, (b) is a reasonable **minor departure**, independently of the crossing choice. The closest handout fallback remains (a). [S2, S3, S8–S11; E1, E5]

**Confidence:** high that the present return path is not closed by its existing reports; high that shared outputs alone do not solve common-period expansion; moderate in the proposed six-edge optimized schedule; unverified in implementation, MTBF in years, and on-board operation. The existing four-tick model minimum is replaceable mechanism timing, whereas the six-tick launch cadence is the project requirement. [E1–E4; ADR 0003 item 2]

## Evidence register and reproducibility

**E1 — existing routed build, inspected, not rerun:** `/home/alan/.local/share/cs256-vivado/builds/tron-20261029-122928-881593/`, Vivado **2025.2**, build **6299465**, `xc7a100tcsg324-1`, production speed file **1.23**. `report_clocks.rpt`: pixel period 11.982 ns, base 213.333 ns, game 16,666,880 ns. Wizard properties: pixel M=28.375, D=4, O0=8.5; base M=6, D=1, O0=128. `report_cdc.rpt`: **five CDC-4 bus groups (20 bits) plus one CDC-1 bit**, Critical/Unknown, pixel→game; reverse direction **150 CDC-15 payload endpoints plus one CDC-3 toggle**. Thus “151 Safe” includes a synchronized control, not 151 payload bits. CDC type is **No Common Period**. `report_methodology.rpt`: TIMING-9 is a **Warning**, aggregating the unknown CDC; it is not the rule ID or severity of the individual Critical endpoints. `timing_summary.rpt`: WNS +0.202 ns, WHS +0.028 ns, WPWS +0.027 ns. `report_clock_interaction.rpt`: both data directions use Max Delay Datapath Only; its “Ignored” classification does not establish a synchronous phase relation. Limits: existing routed timing under existing exceptions, no new CDC validation or board result.

**E2 — actual source inspection:** `game/fast_core.sv`, `game/game_core.sv`, `game/run_tron.tcl`, relative to `proyecto_final/prototypes/core_blocks/`. SHA-256 respectively:

```text
34983659828c4ef7c4a3bd86b9525d7939aa5cdae7c833708f94d6f1996c397b
bdd46a3b18cb1b48f46c8569a28f596d5f97bce8c8058369601ceac1932f20cc
d79658d93473878438a7a4323dffdb721e39cf5a134356004c2bad98b189ae2c
```

`fast_core` publishes on `tick_seen` or before its 262144-cycle window expires, defers late completion, and keeps input batches separate. `game_core` unconditionally captures the 21 bits every game edge, including during Pause; `cap_*` feeds combinational game logic used at the following edge. Tcl bounds **all registers** between the two domains to 11.982 ns in each direction; it has no bus-skew assertion for these buses. `video/game_clk_div.sv` toggles a register every 39063 base edges, drives BUFG, and keeps the clock running through consumer reset/Pause. These are implementation observations, not agreed interfaces.

**E3 — existing simulation records, not rerun:** `datapath/FINDINGS.md`, delay-sweep table: at N=10000 fast cycles/game period, sweep-c max READ2 RTT 9999.5 and COMMIT 10008.5 cycles still matched logs; sweep-d at a different phase, READ2 9999.5 / COMMIT 10000.5, made the first Step one tick late. This is a phase-sensitive deadline observation, **not** a universal scalar RTT bound. `game/FINDINGS.md` records twelve matching M2 logs and a 43-check pins bench, with no late publish/overrun. These tests do not model analog metastability. The nominal 5-/14-fast-cycle datapath RTT measurements are not a proved worst-case Reward-service bound.

**E4 — existing Gray FIFO evidence, not rerun:** `docs/design/CS-256 UART Input Prototype Findings.md`, “Vivado/XSim and routed implementation” and “CDC review and constraints”; `proyecto_final/prototypes/uart_input/uart_async_fifo.sv` and `run.tcl`. Recorded 7-bit Gray pointers each direction, skew 0.847/0.875 ns under 11.982 ns bounds, zero critical CDC, two documented CDC-6 and three CDC-15 warnings. Whole wrapper: 100 LUT, 156 FF, one RAM64M before transformation. That wrapper's measured real-ratio registered FIFO output latency was 66,649,293 ns; synchronous consumer use is another edge. This is **not** the resource count or latency of a new game bridge. In the inspected FIFO, an empty→nonempty transfer published just after edge k passes pointer stages at k+1/k+2, registered empty at k+3, registered read at k+4, consumer at k+5, assuming ready clocks and continuous reads.

**E5 — new isolated Clocking Wizard probe, actually run:**

```bash
# Executed with sandbox escalation, via the authorized fixed launcher:
bash proyecto_final/prototypes/core_blocks/crossing/run_clock_probe.sh
```

Artifact directory: `/home/alan/.local/share/cs256-vivado/builds/crossing-clock-probe-20261029-124232-970852/`. `clock_probe.tcl` generates `probe_shared` and `probe_cascade` for the target part. Shared requested outputs: 83.460 MHz and 5.5419921875 MHz. Returned shared parameters M=28.375, D=4, O0=8.5, O1=128. Cascade IP input 83.45588235294117 MHz, requested 4.6875 MHz: M=36, D=5, O0=128. A tiny shared-output divider/data-path probe was synthesized, with `create_generated_clock -divide_by 92366` at BUFG/O. **Exit zero.** `interaction.rpt`: both data directions **No Common Period / Timed (unsafe)**; `cdc.rpt`: **two CDC-1 Critical**. `console.txt` explicitly records Timing 38-127: no common period within 1000 cycles. Cascade IP was generated/configured but **not connected, synthesized or routed**. No candidate mailbox, board test or routed shared-clock timing was run. Five probe reports/property dumps are retained beside the runner in `crossing/`; probe Tcl SHA-256 is `ddb8f69504f7d9296a05d8f62732402381ef86ef0143ac65ce5f957f780c51a1`.

**E6 — installed AMD source inspection:** `/home/alan/.local/share/cs256-vivado/tools/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv`, SHA-256 `27592359d8363d7e6575298f9d0faa7c9f9258ea77f19c9a38946fbaf3783f09`. In `xpm_cdc_handshake`, `src_sendd_ff` and `src_hsdata_ff` register the source interface; two `xpm_cdc_single` instances carry request/ack; `dest_hsdata_en = ~dest_req_ff && dest_req_sync`; destination data and `dest_req` are registered. There are **no application reset ports** on this macro. This inspection is first-party implementation evidence, not a new XSim measurement. Do not equate “DEST_SYNC_FF=2” with two-edge command completion.

Recheck observations with `sha256sum`, `rg -n 'CDC-|No Common|TIMING-9'` on the named reports, and the exact runner above. Original synthesis/probe reports stay in their launcher artifact directories; rerunning creates a fresh directory. The note's calculations use exact rational M/D/O values rather than the rounded period strings.

## 1. Clock relationship and source options

### What the oscillator proves

The Nexys A7 has one **100 MHz oscillator on E3**, MRCC bank 35. That supplies a common frequency reference, not a blanket CDC exemption. Digilent explicitly delegates generated-frequency/phase behavior to the FPGA clock resources. [S2 §5, p.13]

Here the pixel MMCM's **DIVCLK_DIVIDE=4** matters: AMD's TIMING-51 rule states that parallel clock-modifying blocks cannot be safely timed together unless all relevant input dividers are 1. Separately, AMD requires **unexpandable clocks** to receive asynchronous CDC treatment when a common period cannot be established within 1000 cycles. The current build exhibits both the problematic configuration and the reported No Common Period classification. These clocks are frequency-related physically, but must be **treated asynchronously for this design's crossing sign-off**. [S3; S4; E1]

The exact nominal pixel/game ratio is `23646136/17`: coincident phases would repeat after **23,646,136 pixel periods and 17 game periods**, not within the expansion limit. Even base→game is /78126. Moving a divider's clock declaration or writing `set_clock_groups` cannot manufacture a better physical phase relation. [Calculation from E1; S4]

### Clocking Wizard comparison (frequencies are nominal achieved/configured, not oscillator measurements)

Engineering rank below is for **this repair**, including change cost and remaining CDC obligations. Handout fit is deliberately separate. All options retain real game-clocked state. None is credited with removing the 21 findings without a new crossing or a separately proved timing methodology. [E1, E5; S3–S4]

| Option / engineering rank | Frequency and feasibility evidence | Relationship after the counter / 21 return endpoints / command latency | Handout fit |
|---|---|---|---|
| **(a) two board-fed `clk_wiz` instances — 1** | Existing generated/routed: pixel **83.4558823529 MHz**, base **4.687500 MHz**, /78126 game **59.9992320098 Hz**. Two MMCMs; existing complete build. [E1] | Parallel-divider phase issue plus No Common Period. Existing return capture remains Critical; retain CDC. Source choice alone leaves **2 ticks/command, 4/Step**, uncertified crossing. [E1–E2, S3–S4] | **Close.** README Drawing step 10 and `game_top.png` show separate board-fed dividers. Closest fallback. |
| **(b) one Wizard, two outputs — 2** | **Actually generated** together: VCO **709.375 MHz**, CLKOUT0 /8.5 = **83.4558823529 MHz**, CLKOUT1 /128 = **5.5419921875 MHz**. This is the lowest ordinary second output *at this VCO*, not the global MMCM minimum. /92366 game **60.0003484778 Hz**. [E5; S8–S9] | Shared VCO removes the parallel-MMCM ambiguity. But ratio `23645696/17` still fails expansion: **measured Timed (unsafe), two Critical probe CDCs**. No latency advantage; original 21 cannot be reclassified merely by sharing the Wizard. [E5, S4] | **Minor departure.** Wizard output plus counter is retained; fewer IP instances than drawing/ADR 0002's literal “second Wizard.” Record the clarification before adoption. |
| **(c) second Wizard fed by pixel output — 3** | Generated IP returns M=36,D=5,O=128: base **4.69439338235 MHz**; /78240 gives **59.9999154186 Hz**. Keeping /78126 instead gives **60.0874661746 Hz**. Pixel output unchanged. VCO2 **600.882352941 MHz**. [E5 arithmetic; S8, S10] | Can establish a derived topology with compensated feedback and correct routing; cascading alone is not phase alignment. Final pixel/game ratio `4172800/3` remains unexpandable. No demonstrated endpoint or command-latency improvement. Connection/routing/jitter unverified. [S4, S10; E5] | **Minor departure.** Two Wizards plus counter remain, but second input differs from the figure. |
| **(d1) CLKOUT4_CASCADE — 4 for this repair** | MMCM permits CLKOUT6×CLKOUT4 division up to **16384**, using override mode. At 709.375 MHz: **43.2968139648 kHz**, /722 → **59.9678863779 Hz**. At 600 MHz: theoretical **36.62109375 kHz**, /610 → about **60.03458 Hz**. These are calculations, not generated/probed outputs. [S8–S9, S11] | Still about 1.39 million pixel periods/game period. With shared VCO example ratio `23658496/17`; no practical ordinary expansion. Counter-cascade static phase offset must be included. No removal of 21 findings or latency reduction shown. [S4, S11] | **Minor departure** if retaining Wizard+counter; explain use of advanced internal divider. Exact “lowest allowed” settings need team agreement. |
| **(d2) BUFGCE / Safe Clock Startup / phase settings — supporting features, not a bridge** | BUFGCE gates complete pulses subject to CE timing; it is not an arbitrary low-frequency divider. Safe startup uses BUFGCE after LOCKED is sampled high for **8 input clocks** in PG065 v6.0. Output rates during operation remain those selected above. No new generated settings tested. [S10–S12] | Startup quality helps but provides neither coherent bus transfer nor common-period expansion. Phase shifting/deskew can help genuinely related clock paths; it cannot eliminate the final ratio. 21 findings/latency unchanged absent redesign. [S3–S4, S12] | **Needs TA confirmation** for adopting lock/reset/startup behavior currently disabled by the handout; not a replacement for ADR 0002's game divider. |

`proyecto_final/game_top.sv` instantiates Roman's **`clk_wiz_0`** with `clk_out1` driving `clk_pix`, matching the handout's first Wizard role. No `clk_wiz_0.xci` or generated configuration was found in this checkout: **its actual achieved frequency, primitive, M/D/O and reset settings cannot be verified from that instantiation**. E5 proves a new compatible configuration, not the configuration on Roman's workstation. Renaming it or assuming the playable build's properties would not supply that evidence. [E2 inspection; S9]

For one ordinary shared MMCM, **4.6875 MHz and the present exact pixel rate cannot coexist at the existing VCO**: 709.375/4.6875 = 151⅓, exceeding the ordinary integer /128 output divider. The 5.541992 MHz output is legal and was generated. The global ordinary minimum 600/128 = 4.6875 MHz follows the -1 VCO minimum, but forcing that VCO changes achievable pixel synthesis. This note does not claim to have exhausted every approximate-pixel VCO combination. [E5; S8–S9]

**TA explanation if (b) is later chosen:** “We retain a real approximately 60-Hz clock, generated by a Clocking Wizard output and a counter, and keep the game state clocked by it. We use two outputs of one Wizard to share its MMCM rather than instantiate two Wizards; the pixel frequency remains 83.455882 MHz and the game rate is 60.000348 Hz. This saves one MMCM. We still implement an explicit CDC bridge because the final divided clock is unexpandable relative to the pixel clock in Vivado. The architecture is still Wizard-plus-counter game timing, rather than a game enable in the video domain.” This is an engineering justification, **not recorded TA approval**. [E5; S4; ADR 0002]

No option (b)/(c) changes the bridge recommendation: neither demonstrated cleaner sign-off for the final data paths. The shared-output choice has the best clock-resource economy; (a) has the best demonstrated integration evidence. [E1, E5]

## 2. Quiet-window capture, metastability and sign-off

### Quantified timing argument and its limits

Arithmetic from E1–E2 gives game period **16.666880 ms**, window **3.1411087 ms**, and approximately **13.5257713 ms** between the last permitted window update and the next game edge, before detection delay, routing, jitter and setup allowances. A deferred publish occurs a few fast clocks *after* a detected game edge. Thus the protocol intends a large setup margin before the next edge **and a smaller, crucial hold margin after the current edge**. The latter requires minimum-latency/clock-skew analysis; a maximum-delay constraint alone does not prove it. Reset, lock loss, shortened first intervals and WINDOW changes are separate obligations. [E1–E2; S5, S8]

If a capture flop nevertheless becomes metastable, its downstream register is used one game period later. Available resolution time is approximately

```text
Tresolve = 16,666,880 ns - (capture clk-to-Q + logic + routing
                          + downstream setup + clock uncertainty/skew)
```

This is millisecond-scale slack **only if every downstream use is registered at that following edge and no control/glitch escapes sooner**. E2 shows combinational decoding and resolution after `cap_*`; it is not an isolated, recognized two-register synchronizer chain. Large settling time reduces the probability of a late metastable transition but does **not** repair a coherent word captured with some old and some new bits. A binary `seq`, Cell code and axes batch are not Gray-coded independent signals. [E2; S1, S6–S7, S13]

AMD's published -1 CLB figures include **TCKO 0.53 ns max**, direct AX–DX setup/hold **0.09/0.26 ns min**, and AN–DN LUT-input-to-FF setup/hold **0.11/0.18 ns min** at 1.0 V. These are different physical paths and **not metastability recovery constants**. Use the implemented path timing, not these standalone numbers, to subtract logic/routing/setup. DS181 Table 27 p.28 publishes these; no Artix-7 -1 synchronizer τ/aperture/MTBF constants were found there. [S8]

The exponential recovery model gives proportional behavior `MTBF ∝ exp(Tresolve/τ)/(fclock × ftoggle × C)`; here `fclock ≈ 60 Hz` and worst per-bit publication activity is of order 60 transitions/s, unlike a fast synchronizer sampling at 83.456 MHz. That supports the qualitative “long time to settle” argument. **No defensible MTBF in years can be calculated from the located primary data:** τ and C for this Artix-7 speed grade were not found. XAPP094's characterized/extrapolated values concern **Virtex-II Pro**, not Artix-7. AMD's `report_synchronizer_mtbf` expressly does **not support 7-series**. Do not paste an UltraScale MTBF figure or treat TCKO as τ. [S13–S15]

### What AMD accepts, and what a waiver means

UG949 calls for recognizable CDC circuits and correctly applied `ASYNC_REG`. UG906 identifies the present return structure as **Unknown**, not a proven failure and not an endorsed synchronization scheme. `set_max_delay -datapath_only` can bound transfer delay while ignoring the unrelated launch/capture relationship; it does not validate the quiet-window protocol. `set_bus_skew` adds a separate coherency assertion, likewise without creating synchronization. [S1, S5–S7]

A manual sign-off of the present circuit would therefore need a complete protocol/physical proof: all publication edges, all destination capture apertures, worst relative clocks/skew, reset/startup, and coherent payload retention. **No AMD primary source was found that specifically certifies this exact one-register, early-window, delayed-use scheme**, or says 16.7 ms settling alone is sufficient for arbitrary buses. This research does not supply that missing proof. It recommends replacement rather than waiving CDC-1/4. [E1–E2; S1, S6–S7]

AMD supports **path-specific `create_waiver`**, with user and description, and warns that waivers can conceal flawed designs. Example for a *verified qualified-capture* bus, not authorization to waive the current unknown buses:

```tcl
create_waiver -type CDC -id CDC-15 -user alan \
  -description {Qualified bundled capture; link reviewed protocol and routed evidence} \
  -from $audited_source_clock_pins -to $audited_capture_d_pins
write_waivers crossing-waivers.xdc
```

Keep both unwaived and waived reports and check exact endpoints. Do not globally waive TIMING-9. XPM handshakes normally have scoped CDC-15 waivers; Gray XPMs have CDC-6 waivers. Such waivers apply to the macro's verified topology, not arbitrary surrounding logic. [S16–S17, S22]

### Which XPM is applicable

| Macro | Appropriate scope / exclusion here | Evidence |
|---|---|---|
| `XPM_CDC_SINGLE` | Synchronize a request, ack or persistent valid/toggle; choose 2 stages only with placement/timing review. It does not convey a coherent word by itself. | S18; E6 |
| `XPM_CDC_ARRAY_SINGLE` | Independent unrelated bits; **not** a substitute for preserving seq+data/axes relationships. | S19 |
| `XPM_CDC_GRAY` | Increment/decrement-by-one counters/pointers, sampled sufficiently; not arbitrary response payloads or a seq that advances too fast to be sampled as specified. | S17 |
| `XPM_CDC_HANDSHAKE` | Coherent arbitrary bus with complete receive/ack/rearm. Use `DEST_SYNC_FF=2`, `SRC_SYNC_FF=2` for latency evaluation, not defaults of 4. Extra source/destination registers and four-phase rearm still matter. No reset port; design a protocol drain/epoch wrapper. | S16; E6 |
| `XPM_CDC_PULSE` | A fast pulse cannot be sampled directly by 60 Hz logic. Macro pulse transfer requires at least `2×max(Tsrc,Tdest)` between pulses and coordinated reset duration; it is not a per-tick arbitrary-bus transport. | S20 |
| `XPM_FIFO_ASYNC` | Buffer ordered words; select explicit mode, depth and read latency; observe reset busy and full/empty. Do not assume one game-edge first-word availability. | S21; E4 |

UG974 is an UltraScale library guide. Its protocol descriptions are useful, but **UG953 and successful elaboration on this exact 7-series part must establish applicability**, especially when selecting FIFO options. The installed common XPM source establishes the handshake implementation present in 2025.2; it is not proof that every newer online parameter is supported. The live unversioned 2026.1 UG974 contents differ from 2024.2 (including handshake indexing); versioned links below are deliberate. [S16–S21; E6]

## 3. Crossing comparison and latency accounting

**Counting convention:** issue at game edge k means registered source payload/control becomes valid *after* k. Fast work fits before k+1 in these proposed nominal schedules. A two-stage game synchronizer produces its second-stage output *after* k+2; game sequential logic can act on that output at **k+3**, not k+2. Metastability can defer recognition; no finite-latency async scheme promises an absolute analog upper bound. Numbers below assume no extra synchronizer delay, service deadline met and no reset/Pause/backpressure. Distinguish command use, channel rearm and Step launch cadence. [S13, S16, S18; E2, E6]

Constraint recipes C0–C4 are specified in the next section. Resource entries are structural estimates, **not synthesis results**; W denotes the chosen word width. Existing measured counts are explicitly E1/E4. Each row is an engineering deduction from the cited topology.

| Candidate | Command / READ2+COMMIT Step / margin against 6; model effect | Input latency and resources | CDC expectation, constraints, reset/Pause |
|---|---|---|---|
| **Current single capture + early quiet window** | **2 / 4**, two spare ticks, unless late publication. Preserves model k+2 answer and current logs. | Published batch use 2 edges later; event can wait up to another tick for batch closure: roughly 2–3 ticks. Current full build 1025 LUT, 973 FF; no incremental claim. | **Measured** 21 Critical Unknown, reverse 150 CDC-15+1 CDC-3. **C0**; coordinated stretched reset; capture continues paused. Not signed off. [E1–E3] |
| **Two-phase toggle req/ack; or full XPM handshake** | Custom qualified capture **4 / 8** with a separate consumer register; optimized capture+resolve **3 / 6**, no spare tick. Two-phase ack returns in fast cycles before next command; hold payload until ack. Full XPM, registered slow source issue: source capture at k+1, return dest capture k+4, consumer **k+5** → **≥5 / ≥10**, before additional rearm stalls; not the often-quoted 3/6. | Custom single-outstanding input batch use ~4 edges after publication, plus batching/backpressure; cannot sustain a new batch every tick without buffering. W source+W capture FF, control chains/state; no RAM required. XPM adds source/destination registers and ack state. | Custom expected CDC-3 controls and CDC-15/16/17 payload; XPM CDC-15 normally waived. **C1**. Coordinated reset to common toggle epoch; no unilateral reset. Drain/ack through Pause. XPM must complete four-phase protocol; reset wrapper required. Logs change unless intentionally delayed to match a selected schedule. [S5–S7, S16; E6] |
| **Qualified capture with synchronized valid** | Same **4 / 8** conservative; **3 / 6** if destination game outcome/score registers are the qualified capture and resolver consumes held bus on that edge. Persistent valid must have ack or equivalent proven hold/rearm; a narrow valid pulse is insufficient. | Four edges to a separate consumer, or three to direct qualified state capture. Cannot use a one-word mailbox for per-tick batches; buffer or coalesce under an explicit changed input contract. ~W capture+source FF, ≥4 control FF per two-way control pair, compares/enable logic. | Expected CDC-15/16/17 and CDC-3; combinational resolver fanin must remain qualified at **every** destination endpoint. **C1/C2**. Reset epoch flush, Pause leaves bridge active and suppresses only semantic advancement. Three-edge Step outcome arrives one tick later than model. [S1, S5–S7; E2] |
| **Async FIFO: repository Gray FIFO / XPM_FIFO_ASYNC** | Repo isolated empty-to-nonempty command return: **5 / ≥10** consumer edges with current registered interface; additional queueing possible. Outgoing command crosses quickly if write is issued at k. XPM: parameter-dependent, **not found a universal count**; documented empty update alone is `1 wr_clk + (N+2) rd_clk` in standard mode, before read/consumer registers. | Repo batches ~5 edges after publication, plus 0–1 collection tick when empty; then one batch/edge steady state. Memory W×depth plus pointer/control FF; E4's 100 LUT/156 FF includes UART+clocks, not this bridge. | Repo measured CDC-6 pointer and CDC-15 data warnings, zero Critical; XPM scoped constraints/waivers inspect after elaboration. **C3**. Coordinated reset, readiness/busy inhibit; flush epoch on new session, tag capture eligibility; clocks/read transport continue paused. Model timing/Turn eligibility changes. [S17, S21; E4] |
| **Synchronize only game→fast; schedule fast publication from detected period** | **2 / 4** if window honored, same budget as current. Tightening the timing model is a proof obligation, not a new synchronizer. | Same ~2–3 ticks current input schedule; timer/source hold FF, no slow synchronizer added. | Still CDC-1/4 Unknown absent recognizable destination qualification, even with a larger guard. **C0/C2** plus proved min/max aperture margins. Reset/clock restart invalidates period predictor; suppress publishes until trained. Pause must never stop clock. Retains Step ticks if all deadlines hold. [S1, S4–S7; E1–E2] |
| **Atomic Step in fast service, slow game state/scoring (ADR 0003 item 1 fallback)** | One custom qualified command: **4 / 4** conservative; **3 / 3** with direct qualified outcome. Choose conservative four, **two spare ticks**. Both cells read before either write; same combinational resolver reused in service. | Use separate ordered input FIFO if batches must arrive each tick; latency ~5–6 ticks from event with repo FIFO, or optimize a separately verified transport. Added fast transaction/result regs and resolver logic; no extra Arena required. Exact resources unmeasured. | **C1+C3**, expected recognized control/qualified payload patterns. Reset drains/invalidates whole Step; Pause after admission must finish atomic memory work and later publish outcome exactly once. Outcome shifts from model k+2 to k+4 even though minimum completed Step can remain four. Needs contract/TA interpretation for fast collision computation. [S1, S5–S7; E3–E4; ADR 0003] |

**Why the simple “add 2 FFs = 3 ticks/command” estimate needs qualification:** E3's estimate describes extending capture/consume timing, not a measured coherent handshake. Independent 2-FF bus bits can still form a mixed binary word (CDC-6); a proper held-bus valid scheme needs explicit qualification and rearm. A three-edge implementation is possible by **collapsing qualified capture and game resolve into the same edge**, not by using the first synchronizer stage or ignoring XPM registers. [S6–S7, S16, S19; E2–E3, E6]

## 4. Proposed constraints and concrete protocol

### Protocol selected for the first experiment (proposal)

Use one outstanding command; game registers payload and toggles `req_tgl` at k. Fast two-stage synchronization detects change, captures stable payload, executes READ2, then holds a complete registered response and toggles `rsp_tgl`. Game synchronizes `rsp_tgl` through two FFs; only `rsp_sync2 != rsp_seen` qualifies capture. The source holds payload until the game acknowledgement crosses back. On READ2 acceptance at k+3, **all** collision/game/scoring state registers use the held response bus under that qualification, while COMMIT payload/control is registered on that same edge. COMMIT arrives/qualifies at k+6; retirement and next scheduled launch may share the edge, as E3 already allows in the abstract datapath. Fast response ownership is released by an explicit game ack; the next command must be buffered until that ack has arrived. [Engineering proposal based on S5–S7 and E3]

Use persistent toggles, not pulses; first-stage synchronizer outputs feed only the second stage. Mark control chains `ASYNC_REG=TRUE`, `SHREG_EXTRACT=NO` in RTL. Every state endpoint reached by unsynchronized payload must be gated by the **same synchronized qualification**, or first copy into a qualified capture word and accept the extra tick. Verify synthesis extraction: complicated score arithmetic/enables may need restructuring to obtain recognizable CDC-15/16 paths. No claim that the current `game_core` already has this structure. [S1, S6–S7]

For per-tick input batches, use a separate **ordered Gray FIFO**, initially adapting E4's transport, with explicit batch tick/session and arrival-phase metadata. It must support one batch/game edge after pipeline fill. A single full handshake per batch cannot do that at 60 Hz. Do not silently turn an axis batch into a latest-value register or delay a Crash-era Start into Ready. The resulting input latency and Turn eligibility must be represented in the model and reviewed. An input bridge optimization can be researched independently; command throughput does not prove input throughput. [S16, S21; E2, E4]

### Exact constraint recipes

**C0, existing scheme (evidence, not recommended closure):** E2 currently uses these broad domain collections:

```tcl
set game [get_clocks clk_juego]
set pix [get_clocks -of_objects [get_pins u_pixel_wiz/clk_out1]]
set_max_delay -datapath_only 11.982 \
  -from [all_registers -clock $game] -to [all_registers -clock $pix]
set_max_delay -datapath_only 11.982 \
  -from [all_registers -clock $pix] -to [all_registers -clock $game]
```

**C1/C2, proposed explicit bridge:** the following is executable Tcl for a **new naming contract**, not a patch applicable to today's hierarchy. Implement instances `u_x1/g2f` and `u_x1/f2g`, each with `payload_hold_reg[*]`, `payload_capture_reg[*]`, `send_tgl_reg`, `send_meta_reg`, `send_sync_reg`, `ack_tgl_reg`, `ack_meta_reg`, `ack_sync_reg`. The optimized return capture collection must instead enumerate **every actual game outcome/scoring/command endpoint reached by that response bus**, not pretend a distinct capture register still exists. Record that exact endpoint manifest after synthesis; direct-capture constraints cannot be finalized before those registers exist. The conservative four-edge version uses the names below unchanged. [S5–S7]

```tcl
# Root input clock and Wizard clocks: keep existing top/IP constraints.
# Define divider clock once at BUFG/O, preserving its data feedback domain.
create_generated_clock -name clk_juego \
  -source [get_pins u_div/game_toggle_reg/C] -divide_by 78126 \
  [get_pins u_div/u_game_buf/O]

proc required_cells {pattern} {
  set c [get_cells -hier -regexp $pattern]
  if {[llength $c] == 0} {error "Empty crossing collection: $pattern"}
  return $c
}
proc bound_bus {src dst} {
  set_max_delay -datapath_only 11.982 -from $src -to $dst
  set_bus_skew 11.982 -from $src -to $dst
}
foreach ch {g2f f2g} {
  set p "u_x1/$ch"
  set src [required_cells [format {%s/payload_hold_reg\[[0-9]+\]} $p]]
  set dst [required_cells [format {%s/payload_capture_reg\[[0-9]+\]} $p]]
  bound_bus $src $dst
  foreach ctl {send ack} {
    set launch [required_cells "${p}/${ctl}_tgl_reg"]
    set meta [required_cells "${p}/${ctl}_meta_reg"]
    set sync [required_cells "${p}/${ctl}_sync_reg"]
    if {[llength $launch] != 1 || [llength $meta] != 1 ||
        [llength $sync] != 1} {error "Nonunique control chain $p/$ctl"}
    set_property ASYNC_REG TRUE [concat $meta $sync]
    set_property SHREG_EXTRACT NO [concat $meta $sync]
    set_max_delay -datapath_only 11.982 -from $launch -to $meta
    # meta->sync remains timed by the receiving clock; never false-path it.
  }
}
```

For the optimized direct-capture version, **replace the `f2g` payload destination query** with a checked manifest of actual qualified state register cells, allowing combinational resolver paths from the held response register to those cells. Same max-delay/skew values apply. This is an explicit implementation-dependent gap: no exact existing register list can be supplied for unimplemented RTL. Do not install an empty or guessed collection. Assert expected payload widths/counts once packing is selected; audit every source fanout. These 11.982 ns values deliberately use the faster clock bound and are much tighter than the slow response stable-time requirement. They require actual routed closure; they are not magic setup/hold guarantees for an unqualified bus. [S5–S7]

**C3, FIFO:** use E4's `proyecto_final/prototypes/uart_input/run.tcl` lines 139–195 as the concrete implementation template: for each direction query `*_gray_sync1_reg[*]`, trace its registered physical driver with `all_fanin -startpoints_only`, apply **both** `set_max_delay -datapath_only 11.982` and `set_bus_skew 11.982` to those source cells→first-stage cells. Check address_width+1 endpoints (7 for depth 64); Gray MSB may merge with a binary MSB. Bound actual RAMD64E launch clock pins→qualified `rd_data_reg[*]` at 11.982 ns, as that script does; trace again for widened words. Readiness and external reset exceptions terminate only at first control synchronizer stages. Preserve the separate readiness handshake. For an XPM FIFO retain its generated scoped constraints, inspect overlap/waivers, and verify on this target; do not paste a custom RAMD64E recipe onto a different inferred memory. [E4; S5, S17, S21]

**C4, genuinely synchronous alternative:** only after a clock implementation has an established phase relationship, expandable periods, correct generated waveform and both setup/hold analyses, retain ordinary synchronous timing with **no** interdomain false paths, async clock group or max-delay-datapath-only replacement. No such full-game configuration was demonstrated here. Multicycle exceptions would require a proved launch/capture enable schedule and corresponding hold treatment; do not add a blanket six-cycle exception. [S3–S5]

Across C1–C3 retain existing asynchronous-pin/reset handling and normal intra-domain timing. **Never add `set_clock_groups -asynchronous` between the complete domains when these max-delay bounds are needed**: it overrides max delay. A bus-skew assertion survives exception precedence but does not restore an overridden max-delay bound. Endpoint-specific constraints expose unintended new crossings rather than quietly covering them. [S5]

## 5. Verification and selection gates (not run)

1. **Independent protocol bench:** in `crossing/`, continuous actual-ratio clocks plus accelerated/phase-swept clocks; independently assert no duplicate, lost or mixed transaction; response seq matches one outstanding request; hold payload until ack; first synchronizer stages have no functional fanout; no use before qualification. Inject one-cycle synchronizer uncertainty digitally and delays straddling each service deadline. Simulation checks protocol tolerance, not analog MTBF. [S1, S6, S13; E3]
2. **Composed scheduling:** READ2 issue k, qualified resolve+COMMIT k+3, retire and next launch k+6; sustained hundreds of Steps without channel-busy stalls. Exercise CLEAR/PREPARE, full Reward search/replacement, worst legal Arena occupancy, response backpressure and ack arriving with the next command. Compare every M2 Step log including `tick`; independently test Head-on same/swap, scoring once and no Player priority. If this misses the six-tick cadence, prototype the conservative atomic fallback and require issue k→game result k+4→next launch k+6. Do not reinterpret a changed log as a passing old schedule. [E2–E4; ADR 0003 items 1–2]
3. **Inputs/reset/Pause:** per-tick FIFO batches at full sustained rate; queue full/backpressure/overflow; batch eligibility and session transitions; eligible pending Start; Pause/reset at every request/capture/resolve/commit/ack phase. Pause leaves clocks and bridge draining; game semantics choose whether already admitted work is published. Common reset flushes both ends, toggles and FIFO, with synchronized release and explicit ready/epoch handshake before new traffic. One-sided live reset unsupported unless separately designed. XPM full-handshake variant must drain/rearm despite having no reset ports. [E2, E4, E6; S16, S21]
4. **Routed sign-off:** full target build, not merely the probe: `check_timing -verbose`, `report_clocks`, `report_clock_interaction`, `report_cdc -details`, `report_cdc -all_checks_per_endpoint`, `report_methodology`, `report_exceptions -ignored`, `report_bus_skew`, `report_timing_summary -delay_type min_max -report_unconstrained`, DRC/utilization. Expected **zero unreviewed Critical/Unknown** crossings; controls CDC-3; payload CDC-15/16/17 reviewed with qualification evidence; custom Gray pointers CDC-6 explained by actual Gray operation and physical bounds. The old 21 CDC-1/4 endpoints must disappear as unknown paths, not just disappear behind a broad waiver. Meet setup/hold/pulse width, each skew bound and coverage checks. Save endpoint manifest, exceptions and raw/waived reports. Exact classification/count is a target, **not a measured result**. [S5–S7, S16–S17; E1, E4]
5. **Board check:** program the hashed bitstream on Nexys A7; monitor/ILA command tick, response toggle, qualified capture, commit/ack, late/overflow flags; repeatedly reset and Pause at transaction boundaries. Verify stable display, ten Cells/s, no stuck busy, no double scoring, fresh Start and Turn eligibility at phase changes. Board testing establishes observed behavior, not an MTBF lower bound in years. Test lock-aware startup separately if adopted; current stretched reset is not lock-loss recovery. [E1–E2, E4; S10, S12–S15]

For command admission under exceptional delay, record a deadline miss and suppress overlapping launch; never consume incoherent data to meet a tick deadline. Decide with the team whether a rare delayed Step is permissible. Async metastability uncertainty cannot be converted into an absolute six-edge guarantee by assertion. [S13; engineering proposal]

## 6. Required documentation/model changes if adopted

**ADR 0003 item 2:** record actual packed words, two-phase control, one outstanding command, stable-until-ack ownership, capture/consume edges, input FIFO transport/metadata, reset epochs, Pause/drain behavior, sign-off artifacts and deadline handling. Item 1 keeps READ2+COMMIT only if optimized six-edge scheduling passes; otherwise record activation of the atomic fallback and why. Item 3 remains pixel service. These are later edits for team review under **ADR 0005**, not edits performed here.

**Contract:** reconcile §1 clocks, §4 Arena/input interface and §6 integration: explicit ownership, qualification, latency/backpressure, reset readiness, input eligibility, scoring and Arena publication. The direct-capture resolver must keep all game-state registers on `clk_juego`. Atomic fallback explicitly changes the present §4 statement that collision logic runs in the game domain; ask both owners and, if necessary, TAs before treating it as selected. Display coherence is still an independent open item: a safe CDC bridge does not make mid-frame Arena writes frame-atomic. [E2 inspection; ADR 0002, ADR 0003, ADR 0005]

**Python model:** replace fixed two-tick return timing in `model/mailbox.py` and the scheduling in `model/game_top.py`; update `model/input_batch.py` transport/arrival metadata as selected, without silently altering rules. Optimized READ2 resolves **k+3 rather than k+2** and COMMIT retires **k+6 rather than k+4**. Keep scheduled launches six ticks apart if verified. Conservative atomic service resolves memory immediately in the fast domain but publishes slow state **k+4**; model that split and Pause explicitly. Input FIFO increases event delivery latency and can change Pending Turn/Start eligibility; replay all M2 scenarios and document each intentional `tick` difference. Do not regenerate expected logs merely to conceal a mismatch. [E2–E4; ADR 0003 item 2]

## Open questions for Roman and Alan

- Can direct qualified READ2 capture feed the existing game-domain resolver/scoring registers on the same edge, with every endpoint under the synchronized enable, while simultaneously issuing COMMIT? This is the decisive six-tick optimization to test; no new measurement establishes it yet.
- If that fails, does the atomic fast resolver count as permitted fast service under ADR 0002, while slow state/scoring remain game-clocked? The current contract puts collision logic on the slow side; explicit shared-boundary acknowledgement is needed.
- Is the increased input-pipeline latency acceptable, and what capture-time phase/session metadata preserves Turn ordering and fresh Start semantics? Should a different input crossing be optimized independently?
- On Pause after admission, complete memory work and publish its already-resolved result, or hold publication? How does the renderer get a coherent Arena/snapshot pair?
- Can the team enable reset/LOCKED or Safe Clock Startup despite the handout's disabled ports? Who owns clock-loss recovery and the official independent crossing bench?
- Is sharing a Wizard worth saving one MMCM despite leaving the same CDC obligations? Obtain Roman's `.xci` before claiming anything about the installed `clk_wiz_0` configuration.

These are proposal-selection questions, not requests to block the isolated research. No recorded agreement is inferred.

Document checks run: frontmatter/section/source-ID/code-fence checks passed; `bash -n` passed for the new runner; proposed C1 Tcl syntax executed with mocked netlist queries. This checks Tcl syntax only, not Vivado endpoint selection or physical constraints.

## Primary sources and access limits

All URLs accessed **2026-10-29**. Section names are stable locators when online pages have no printed page numbers. No secondary technical sources were used. Project/course records establish project requirements and experiment observations only, not AMD guarantees.

- **S1 — UG949**, “Clock Domain Crossing,” “Single-Bit CDC,” “Multi-Bit CDC”; recognizable circuit/attributes and single/multibit selection. [CDC](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Clock-Domain-Crossing), [multi-bit](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Multi-Bit-CDC). The current multi-bit page puts its decision tree in an image; specific macro requirements below supply the textual evidence.
- **S2 — Digilent Nexys A7 Reference Manual**, revised 2019-07-10, §5 “Oscillators/Clocks,” p.13. [Manual](https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf).
- **S3 — UG906**, 2022.1, “TIMING-51: No Common Phase between Related Clocks from Parallel CMBs,” description/resolution. [Rule](https://docs.amd.com/r/2022.1-English/ug906-vivado-design-analysis/TIMING-51-No-Common-Phase-between-Related-Clocks-from-Parallel-CMBs).
- **S4 — UG903**, 2026.1, “Unexpandable Clocks,” 1000-cycle search and treatment. [Section](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Unexpandable-Clocks).
- **S5 — UG903**, “Constraining Asynchronous Signals,” “set_bus_skew Example One/Two,” “Exceptions Priority,” “About Bus Skew Constraints.” [Max delay](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Constraining-Asynchronous-Signals), [handshake skew](https://docs.amd.com/r/2024.2-English/ug903-vivado-using-constraints/set_bus_skew-Example-One), [Gray skew](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/set_bus_skew-Example-Two), [priority](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Exceptions-Priority), [skew reporting](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/About-Bus-Skew-Constraints).
- **S6 — UG906**, 2025.1, “Understanding the Clock Domain Crossings Report Rules,” Table 1. [Rules](https://docs.amd.com/r/2025.1-English/ug906-vivado-design-analysis/Understanding-the-Clock-Domain-Crossings-Report-Rules).
- **S7 — UG906**, “CDC Rules Precedence,” Table 1; Safe/Unsafe/Unknown are topology classifications, not protocol proofs. [Table](https://docs.amd.com/r/2022.2-English/ug906-vivado-design-analysis/CDC-Rules-Precedence).
- **S8 — DS181**, v1.27.1, Table 27 p.28 and Table 37 pp.38–39, -1 at 1.0 V; VCO 600–1200 MHz, minimum ordinary output 4.69 MHz rounded, cascade footnote 0.036 MHz. [Data sheet](https://docs.amd.com/v/u/en-US/ds181_Artix_7_Data_Sheet). Local cached datasheet was identified; MinerU parse returned `server_not_running`; no server/config change was made. Numerical verification used AMD's online PDF instead.
- **S9 — PG065**, v6.0, “Configuring Output Clocks,” fractional CLKOUT0/feedback increments of 0.125, and “Features.” [Outputs](https://docs.amd.com/r/en-US/pg065-clk-wiz/Configuring-Output-Clocks), [features](https://docs.amd.com/r/en-US/pg065-clk-wiz/Features).
- **S10 — UG472**, v1.14, “MMCM and PLL Use Models,” Figures 3-15/3-16 pp.94–95 (cascade without/with closest alignment); “Global Clock Buffer Primitives,” BUFG/BUFGCE pp.38–42. [Guide](https://docs.amd.com/v/u/en-US/ug472_7Series_Clocking).
- **S11 — UG472**, “MMCM Counter Cascading,” p.76, Table 3-7 p.85; **PG065** “MMCM Counter Cascading,” override-mode requirement and static offset. [Guide](https://docs.amd.com/v/u/en-US/ug472_7Series_Clocking), [Wizard cascading](https://docs.amd.com/r/en-US/pg065-clk-wiz/MMCM-Counter-Cascading).
- **S12 — PG065**, v6.0, “Selecting Clocking Features,” Safe Clock Startup (8 input clocks), plus output sequencing in S9. [Features](https://docs.amd.com/r/en-US/pg065-clk-wiz/Selecting-Clocking-Features). Older v5.0 documentation describes 32 clocks; do not mix versions.
- **S13 — UG949**, “Optimizing for MTBF,” synchronizer count/stages/destination frequency/toggle rate; **UG835**, “report_synchronizer_mtbf,” Description (7-series unsupported). [MTBF factors](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Optimizing-for-MTBF), [command scope](https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/report_synchronizer_mtbf).
- **S14 — XAPP094**, v3.0, “Metastable Recovery in Virtex-II Pro FPGAs,” pp.1–3; experimental/extrapolated exponential recovery behavior, **different FPGA family**. [AMD application note](https://docs.amd.com/api/khub/documents/L4TL7bB1lC0UKXDZtPmCiw/content).
- **S15 — DS181**, Table 27 and inspected searchable document: no device-specific metastability constants located. Same URL as S8. A negative search is not proof that no AMD confidential/support characterization exists.
- **S16 — UG974**, **2024.2**, “XPM_CDC_HANDSHAKE,” Introduction, Ports, Attributes; **E6** supplies actual installed 2025.2 source. [Handshake](https://docs.amd.com/r/2024.2-English/ug974-vivado-ultrascale-libraries/XPM_CDC_HANDSHAKE).
- **S17 — UG974**, 2025.2, “XPM_CDC_GRAY,” Introduction (increment/decrement constraint, sampling, CDC-6 waiver). [Gray](https://docs.amd.com/r/2025.2-English/ug974-vivado-ultrascale-libraries/XPM_CDC_GRAY).
- **S18 — UG974**, 2024.2, “XPM_CDC_SINGLE,” Introduction/Attributes. [Single](https://docs.amd.com/r/2024.2-English/ug974-vivado-ultrascale-libraries/XPM_CDC_SINGLE).
- **S19 — UG974**, “XPM_CDC_ARRAY_SINGLE,” Introduction; also **PG382**, v1.0, same section explicitly requires independent bits. [UG974 2024.2](https://docs.amd.com/r/2024.2-English/ug974-vivado-ultrascale-libraries/XPM_CDC_ARRAY_SINGLE), [PG382](https://docs.amd.com/r/en-US/pg382-xpm-cdc-generator/XPM_CDC_ARRAY_SINGLE). Some versioned UG974 requests were inaccessible; the PG382 textual requirement was retrieved.
- **S20 — UG974**, 2024.2, “XPM_CDC_PULSE,” Introduction/Ports, pulse gap and reset duration. [Pulse](https://docs.amd.com/r/2024.2-English/ug974-vivado-ultrascale-libraries/XPM_CDC_PULSE).
- **S21 — UG974**, “XPM_FIFO_ASYNC,” Introduction, Latency Tables 4/8 and Attributes. [FIFO](https://docs.amd.com/r/en-US/ug974-vivado-ultrascale-libraries/XPM_FIFO_ASYNC). Current page is 2026.1 and names UltraScale families; E4 is the stronger evidence for this existing custom 7-series transport, and a new XPM configuration must be elaborated on this target.
- **S22 — UG835**, “create_waiver,” Syntax, Description and CDC example. [Waiver](https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/create_waiver).

Project authority: [ADR 0002](../adr/0002-follow-ta-divided-game-clock.md), [ADR 0003](../adr/0003-step-transaction-mailbox-and-render-codes.md), [ADR 0005](../adr/0005-build-with-provisional-interfaces.md), [contract](../../proyecto_final/Contrato%20de%20interfaces%20game_top%20%28CS%20256%29.md), [official practices](CS-256%20Official%20FPGA%20Coding%20Practices.md), [Fast Clock research](CS-256%20Fast%20Clock%20Domain%20Research.md), [UART findings](CS-256%20UART%20Input%20Prototype%20Findings.md). Course evidence inspected directly: `/home/alan/Documents/Maestría/CS-256/cs256-fall-2026/classproject/README.md`, Creating the Clock steps 1–8, Visible Pixel Counter step 3 (line 65), Drawing Logic step 10 (line 85); sibling `game_top.png` shows separate `clk_div_83mhz`/`clk_div_60hz` board-fed branches. Alan's latest instruction allows engineering-ranked minor departures; the figure is evidence of the baseline, not a veto on alternatives.

DS180 local cache (`docs/references/datasheets/DS180_7_Series_FPGA_Overview.pdf`) and the official-doc link bundle were identified. The online DS180 request timed out and the local parser was unavailable, so **no new resource-budget claim is derived from DS180**. Source-option resource differences above count instantiated clock managers only. Existing E1/E4 reports own actual utilization; new bridge utilization remains unmeasured.

## Orchestrator review, 29 October 2026

Checked by the orchestrator (Claude Opus 5.5); not a team decision.

- **Local evidence reproduced.** E1's CDC breakdown matches `report_cdc.rpt`: CDC-1 Critical 1, CDC-4 Critical 5, CDC-15 Warning 150, CDC-3 Info. The E5 probe reports show "No Common Period / Timed (unsafe)" and two CDC-1 Critical for the shared-Wizard divided clock, with the stated M = 28.375, D = 4, O0 = 8.5, O1 = 128. Both period ratios (23646136/17 and 23645696/17) recompute exactly.
- **Key citations confirmed.** UG903 "Unexpandable Clocks": no common period within 1000 cycles, so the clocks are treated "like asynchronous clocks". The UG906 TIMING-51 message: parallel clock-modifying blocks need input dividers of 1 to be timed safely. The Vivado 2025.2 help for `report_synchronizer_mtbf`: "supported for AMD UltraScale devices only, and does not support AMD 7 series devices".
- **Hold side of the quiet window.** The note leaves this as an obligation. It can be bounded from the design: every fast-to-game bus change is launched no earlier than `tick_seen`, which comes 2–3 `clk_pix` edges (≥ ~24 ns) after the `tick_tgl` change on the same `clk_juego` edge. That is well beyond a flop's sub-ns hold requirement. This is a design argument, not tool sign-off, so the conclusion stands: the 21 endpoints cannot be signed off as they are.
- **Agreement with the recommendation, with a phasing note.** Keep two board-fed Wizards; the shared Wizard was measured not to help. The current scheme is functionally robust: ~13.5 ms setup margin, ≥ ~24 ns hold margin, a 16.7 ms settling interval before use, and the LED 4 guard. It is a reasonable vehicle for board bring-up and the pre-demo. The qualified two-phase capture should be prototyped next as the sign-off-clean candidate. If its 3 + 3 = 6 tick schedule, which has no slack, fails the sustained-cadence tests, the atomic fast-service Step (4 ticks, 2 spare) is the fallback. It needs owner agreement because collision computation would move to the fast side.
- **Gameplay cost to playtest.** A FIFO input path raises Turn latency from about 2 to about 5 game ticks (+50 ms). A Turn then has to arrive earlier before a launch to count.
