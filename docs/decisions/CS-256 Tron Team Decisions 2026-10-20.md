---
schema_version: 1
id: cs256-tron-team-decisions-20261020
title: CS-256 Tron Team Decisions 2026-10-20
type: note
subject: CS-256
status: active
created_at: "2026-10-20T12:48:14"
updated_at: "2026-10-20T14:21:11"
term: 2026-fall
sources:
  - "[[CS-256 Tron Game Mechanics]]"
  - "[[CS-256 Tron Glossary]]"
  - "[[CS-256 Tron Development Plan]]"
  - "[[CS-256 VGA and Sprite Design Plan]]"
  - "[[CS-256 Tron Integration Comparison]]"
review_status: unreviewed
tags:
  - tron
---

# CS-256 Tron Team Decisions 2026-10-20

The two folders currently define different games and different hardware interfaces. Settle the winning rule and input hardware first; geometry, module ownership and verification depend on those choices.

The live decision record below contains the team's explicit answers. The comparison and recommendations that follow preserve the pre-meeting evidence; recommendations do not become approved decisions automatically. Live GitHub `main` was checked on 20 October at `f5cb82c901e33a453fcaea2720a80702fda54718` (commit timestamp 15 October). It is still the revision reviewed in [[CS-256 Tron Integration Comparison]]. That note is a draft: its “Already agreed” label and technical recommendations do not establish team approval or TA confirmation. Below, “team implementation” means the actual Python in `prototipos/tron/`; “contract” means the proposed HDL interfaces in `proyecto_final/`.

## Live decision record

**Session closed and decisions locked at the user’s request.** The consolidated baseline is [[CS-256 Tron Agreed Specification 2026-10-20]]. Arena layout and the schedule remain explicitly tentative/revisable. Team answers below take precedence over the pre-meeting recommendations that follow.

- **Q1 — Precedence:** Course requirements first. Q25 subsequently selects the team repository's interface contract as the authoritative project document; it must incorporate these decisions before its older rules can serve as the synchronized specification.
- **Q2 — Match victory:** The first Player to reach or exceed the Points Goal wins immediately; otherwise, a Player at zero Lives loses. This replaces the research rule that final Points can let the Player who lost the last Life win. The initially selected default 20 was subsequently changed to 10 by Q7. Q11 and Q13 below settle simultaneous finishes and sampling time.
- **Q3 — Inputs:** Option A: P1 board direction buttons; P2 WASD through the browser/USB-UART controller. PS/2 for both Players is not the selected input plan.
- **Q4 — First integrated build:** Movement, permanent Trails, Crashes, Rounds/Lives, chosen scoring rules, sprites, working selected inputs and 7-segment Scoreboard. HUD follows; menus, finite Trails, smooth movement and live configuration are extras. Switch configuration of the Points Goal is specifically selected by Q2.
- **Q5 — Rewards:** Three single-Cell Rewards, with values **+1, +1, +3**. Keep a technical follow-up on implementing random placement or a deterministic pseudorandom generator. Exact algorithm, seed/advance schedule and hardware respawn timing remain open.
- **Q6 — Survival Bonus:** **+3 Points** to the Player who survives the other Player's Crash.
- **Q7 — Points Goal switches:** **SW15/SW14**, interpreted as `{SW15, SW14}`: `00` → **10**, `01` → **20**, `10` → **30**, `11` → **40**; new default **10**. Q13 confirms sampling at new-Match Start.
- **Q8 — Steering:** Remember the **last valid Turn**. Q10 settles event order and authorizes a simple physical-button tie fallback; keep one Pending Turn, without replaying older requests.
- **Q9 — Round Start:** The next Round waits for **Space or Enter from the UART controller, or board BTNC** (the team identified pin N17). Either Player may start it. The wait is distinct from a debugging pause of an already running Round.
- **Q10 — Input order:** Follow keyboard-event/arrival order for both Players where an order exists; otherwise use the easiest implementation. Selected implementation fallback: debounced board press events are processed in sampled arrival order; multiple valid same-sample requests use **UP > RIGHT > DOWN > LEFT**, after filtering invalid requests. This exact tie priority is an agent-selected implementation detail under the team's explicit fallback authorization, not a keyboard behavior guaranteed by the course. UART remains naturally byte-ordered. Both Players' movement remains simultaneous.
- **Q11 — Simultaneous finishes:** Apply the Step's Reward Points and Survival Bonus before testing victory. If both reach the goal in the same Step, higher final Points wins; equal Points is a Draw. If neither reaches the goal and both lose their last Life, higher final Points wins; equal Points is a Draw.
- **Q12 — Reward replacement:** A Reward may remain temporarily absent during placement while play continues; replace it as soon as placement succeeds. If no empty Cell exists, leave the slot absent until the next Round.
- **Q13 — Switch sampling:** Read the Points Goal only for a **new Match**, then hold it across its Rounds.
- **Q14 — Geometry:** **16 px Cells, 32 × 32 px Bike sprites, 16 × 16 px Reward sprites**, on the course's 1280 × 800 visible image. The full screen grid is 80 × 50 before Walls/HUD. Q17/Q23 settle the revisable working reservation/bounds, and Q24 selects native RGB444; Q35 later selects the centred sprite anchor. The team requested checking the course READMEs; findings are below.
- **Q15 — Speed:** **One Cell per six divided-game-clock ticks**, approximately **10 Cells/s or 160 px/s** at a nominal 60 Hz. Fixed for the first build and tuned during playtesting.
- **Q16 — Crash/restart:** Approximately **2 seconds** of crashed-Bike blinking, then preparation and a wait for a **fresh Start press**. Ignore Turns and Start during Crash display, no pre-start steering and no next-Round countdown. Q21 below settles the single Start for a new Match.
- **Q17 — HUD reservation:** **64 px at the top**, exactly **four 16 px Cell rows** and **8% of image height**. Keep text readable inside the selected band and preserve the 10 px white border. Q23 clarifies that the layout may be revised after testing and is not a hard lock. HUD rendering still follows the core build.
- **Q18 — Revised physical Scoreboard:** **P2 uses the leftmost four digits; P1 the rightmost four**. Inside each bank, its left two show `P2`/`L2` or `P1`/`L1`, and the right two show that Player's Points/Lives respectively as two decimal digits. Each view lasts **3 seconds**. Q19/Q20 settle alternation and synchronized banks. This supersedes both earlier proposed fixed-digit layouts.
- **Q19 — Alternation:** Points for **3 seconds**, Lives for **3 seconds**, repeating and **continuously visible**, without intentional blanking/flashing.
- **Q20 — Synchronized banks:** Accept the synchronized-bank recommendation: both Players show the same statistic at once, begin each new Match on Points, display current values and continue cycling during Crash, ready wait, debug pause and Match-over.
- **Q21 — New-Match Start:** **One press** from power-up or Match-over resets/prepares the Match and begins play as soon as preparation completes; no second Start is required. Goal switches are sampled for that Match. Subsequent Rounds retain the separate fresh-Start wait.
- **Q22 — Pause/reset:** **SW0 up** pauses game state and game timers and ignores steering; **SW0 down** resumes immediately. Video and Scoreboard cycling continue. Red **CPU_RESETN** clears the game and returns to waiting for Start. Do not gate clocks to implement Pause.
- **Q23 — Working Arena layout, not a hard lock:** Accept the current **64 px HUD + 16 px top Wall**, with interior **78 × 44 Cells**, `cx=1..78`, `cy=5..48` (pixels `x=16..1263`, `y=80..783`), and initial **32 px HUD text**. The team explicitly permits changes after game review/testing; this is a working baseline, not an irreversible lockdown. Keep revisions consistent across the contract, notes and code.
- **Q24 — Asset format:** Native-size **12-bit RGB444 `.coe` sprites**. Bike depth is 1024 words at 32 × 32; Reward depth 256 at 16 × 16. This replaces the team prototype's selected indexed-art/2× enlargement path. Q36 later confirms the transparency/tint keys and initial Player colours.
- **Q25 — Project authority:** **The interface contract in [romanmg00/FPGA](https://github.com/romanmg00/FPGA)**, below course requirements and the TAs' strict-architecture instruction. Reconcile both projects to the explicit meeting decisions; neither unchanged prototype overrides them. The user wants remaining discrepancies discussed now. Q26 selects one shared executable model.
- **Q26 — Shared rules model:** **One shared, headless rules model in the team repository**, used by the PC viewers and HDL verification scenarios. Do not maintain separate authoritative rule implementations in each viewer. The migration location/base and adapters still need implementation planning.
- **Q27 — Cell encoding:** Retain the team's **four-bit Cell format**: 0 empty, 1 Wall, 2 P1 Trail, 3 P1 head, 4 P2 Trail, 5 P2 head, 6 Crash, 7 reserved, 8/9/10 Reward slots 0/1/2. Use matching Python/HDL constants and three independent Reward-slot states. Review [[CS-256 Official FPGA Coding Practices#Arena memory and reset]] for port ownership, collisions, clearing and memory-service timing; encoding width does not solve those issues.
- **Q28 / Q32 — Clock clarification:** The Q28 phrase “60 Hz only for display” was explicitly clarified in Q32: **keep the handout's approximately 60 Hz game-state clock, with fast video and memory service**. ADR 0002 remains selected. Video's pixel clock is approximately 83.46 MHz and its frame refresh approximately 60 Hz. The fast memory controller services slow-domain commands and returns results; the game logic is not silently moved into that fast domain. Exact transfer implementation remains engineering work.
- **Q29 — Randomness policy:** Use **pseudorandom placement with a seed influenced by Start timing for normal games**, plus a **fixed-seed mode for repeatable tests**. Exact generator, advancement schedule and placement-service implementation remain the requested technical investigation.
- **Q30 — Team membership:** The TAs require a **two-member team: Roman and Alan**. Kevin is no longer a project member. The previous three-person ownership and official-testbench rotation are superseded; Q33 settles a two-person split.
- **Q31 / Q34 — Planning targets:** **15 November** for the pre-demo build and **23 November** for demo-code freeze. Q40 subsequently makes the schedule and feature staging **tentative and flexible**; the course assessment dates remain fixed.
- **Q33 — Two-person work split, including shared HDL game development:** The team wants the HDL game engine distributed between both members, otherwise retaining the recommended division. Concrete allocation implementing that request: **Roman owns HDL movement/Turn handling and collision resolution (G1/G2), VGA/clock generation, renderer, sprites and later HUD. Alan owns HDL Round/Match control, Lives and scoring (G3/G5), alongside the shared software model, Arena/fast memory and Reward-placement service (A1/A2/G4), inputs/UART/web controller, Scoreboard and top-level integration/build.** Both define the interfaces and write official tests for the other's blocks. The former whole-model/whole-engine different-author arrangement is replaced by per-block cross-testing; no longer claim one person authors the entire HDL engine.
- **Q34 — Demo freeze target:** **23 November 2026**, before the 30 November demo; retain time for fixes and rehearsal. Q40 subsequently marks the schedule tentative.
- **Q35 — Starts/anchor:** Working starts **P1 `(20,27)` RIGHT**, **P2 `(59,27)` LEFT**; Bike sprites centred on their head Cells. Preserve mirrored starts and both collision rules; same-Cell Head-on Crash tests use deliberately arranged positions. Geometry remains revisable after testing.
- **Q36 — Core art conventions:** **`000` transparent**, **`0F0` Player-colour tint**, **P1 cyan/P2 orange** initially. **No special `080` dim/glow key** in the core format. Glow, scanlines and animated backgrounds are optional after the core game works; current candidate assets/effects still need reconciliation.

- **Q37 — Initial Rewards:** Prepare all three Rewards before releasing a Round; temporary absence remains permitted for replacements during active play.
- **Q38 — Match-ending Crash presentation:** Retain the winner immediately, blink crashed Bikes at their last valid Cells for approximately two seconds, then enter Match-over without preparing another Round. Ignore Start during the effect. A goal reached without a Crash goes directly to Match-over.
- **Q39 — Remove obsolete Points cap:** The user rejected the old 99-Point cap. The selected 10/20/30/40 goal is the victory threshold. Keep the full final-Step total, consistent with Q11's simultaneous-finish comparison; no new goal-clamping rule was introduced.
- **Q40 — Schedule tentative:** Keep the schedule and feature staging flexible. The 15 November pre-demo-build and 23 November demo-freeze dates are **tentative targets**, not hard locks. The chosen core scope remains agreed and the course's assessment dates remain fixed.
- **Session close:** The user explicitly requested **“Lock what we have done so far and explain what decisions have been made.”** This locks the agreed baseline in [[CS-256 Tron Agreed Specification 2026-10-20]], preserving the explicit flexibility of layout and schedule. It does not claim completed implementation or authorize unrequested publishing.

The discussion is closed. [[CS-256 Tron Agreed Specification 2026-10-20]] records the locked decisions and explicit provisional items. Prototype/HDL code and the remote contract have not been changed in this session. Remaining work is implementation/verification and reconciling the team contract, not another unrecorded game-rule interview.

**Clock architecture — settled after Q14:** The team reports that its TAs recommended following the handout architecture **strictly**. Use the **second Clocking Wizard plus divider counter to generate the approximately 60 Hz clock for the final game logic**. Keep video/sprite reads on the pixel clock. [[0002-follow-ta-divided-game-clock]] supersedes ADR 0001; frame-enable approval is no longer an open question. Restore X1 for game/render and Arena command/result transfers. This also supersedes the team repo’s single-clock proposal.

### Technical follow-ups requested during Q5–Q9

- **Pseudorandom Reward placement:** Both existing prototypes already use deterministic LFSRs. A fixed seed and advancement schedule give reproducible positions for model/HDL comparison. Q29 selects Start-timing-influenced seeding for normal games and fixed-seed tests; investigate the exact capture/advance implementation. Define empty-Cell validation, no overlap with Bikes/Trails/Walls/HUD/other Rewards, and full-Arena behavior. Budget placement cycles; functional “immediate” replacement does not prove that two placements fit vertical blanking. Record the chosen method only after verification.
- **Simultaneous direction requests:** Inspect the current models' ordering, distinguish same-Player requests from both Players turning at once, and select a rule for input events that arrive in the same board-clock sample. Debounce and UART ordering must not create an undocumented priority.
- **UART Start:** The previous protocol lists only WASD and Space. Extend the eventual controller/decoder contract to cover Enter as well; choose a canonical transmitted byte and test accepted line endings without generating unintended repeated Start events.

### Follow-up facts checked during the session

- **HUD size and fit:** With 16 px Cells, 64 px is exactly four rows and 8% of the 800 px image height. The current model with that reservation adds a separate 16 px top Wall, producing an interior of `cx=1..78`, `cy=5..48` (**78 × 44 Cells**); Q23 accepts these as revisable working bounds. The existing top-HUD placement starts at `y=13`: actual 32 px and 48 px digit heights fit the band, while 64 px digits spill below it. Recommend **32 px digits** for clear but secondary feedback, with monitor confirmation. The viewer currently derives reservation from font size (32 px text selects only a 48 px band), so implementation must enforce the newly agreed **fixed 64 px reservation** independently of font selection. Sources: [[CS-256/Game_research/prototype/model/params.py|geometry]], [[CS-256/Game_research/prototype/look/hud.py|HUD layout]], [[CS-256/Game_research/prototype/look/font.py|font scaling]], [[CS-256/Game_research/prototype/look/candidates.py|current reservation logic]].
- **Physical Scoreboard mapping:** The course numbers digits from rightmost `dig0` to leftmost `dig7`, so P2 owns `dig7..4` and P1 `dig3..0`. For the Points view, left-to-right output is `P 2 [P2 tens] [P2 units] | P 1 [P1 tens] [P1 units]`; the Lives view uses `L` and Lives values. The reference hexadecimal decoder only handles 0–F and needs a project-owned extension for P/L. Q19 selects continuously visible pages, so no intentional blank/blink glyph is required. The rapid digit scan is separate from the three-second view timer. Leave the course homework unchanged. Sources: [[CS-256/cs256-fall-2026/homework1/README|homework digit order]], [[CS-256/cs256-fall-2026/homework1/sevenseg.sv|reference decoder]], [[CS-256/cs256-fall-2026/homework1/multidigit.sv|reference scanner]].
- The local [[CS-256/Game_research/prototype/model/steering.py|Turn latch]] retains one Pending Turn. The [[CS-256/Game_research/prototype/look/app.py|viewer]] processes keyboard events in queue order; heading RIGHT, UP then DOWN yields DOWN, and the reverse event order yields UP. Old requests are not replayed later. There is no implemented local HDL policy for two physical direction buttons becoming active in the same sample.
- The [[CS-256/Game_research/prototype/model/lfsr.py|local LFSR]] is a 32-bit deterministic generator; [[CS-256/Game_research/prototype/model/rewards.py|placement]] tries 64 candidates then scans the grid. Hard reset repeats the fixed-seed sequence; ordinary new Matches continue it. The cached team model uses a different 16-bit LFSR. The selected model and HDL must agree on algorithm, seed and advancement schedule before exact state-log comparisons are meaningful.
- The [[CS-256/Game_research/Datasheets/Nexys-A7-100T-Master.xdc|vendor master XDC]] confirms **BTNC = N17**, **SW14 = U11** and **SW15 = V10**. These are commented template constraints, not evidence of a completed build. The selector's bit order is SW15 as the high bit and SW14 as the low bit.
- The local PC viewer already accepts Space/Enter, but the existing UART plan names only Space as Start. A simple proposed wire contract is for both browser keys to send the same existing Start byte, `0x20`; serial-terminal CR/LF support would be a separate decoder choice. No local UART/controller implementation was found during this check.

### Course README guidance checked for Q14

Sources: [[CS-256/cs256-fall-2026/README|course root README]], [[CS-256/cs256-fall-2026/homework1/README|homework README]], [[CS-256/cs256-fall-2026/classproject/README|class-project handout]], and [[CS-256/cs256-fall-2026/classproject/sprites/README|sprite tips]]. The course repository is reference-only and was not modified.

- **Chosen sizes are compatible.** The handout's moving-block exercise uses a nominal 32 px block. Sprite tips use a **40 × 30** image as an example and allow other image sizes, pixel encodings and radices. Square/power-of-two dimensions, black transparency and green tint keys are project choices, not TA mandates. The course does not prescribe this game's Cell size or Reward size.
- **Memory-backed sprites matter for assessment.** The assessment includes sprites from a memory block. The tips show Single Port ROM through Block Memory Generator, `.coe` initialization, and a 12-bit RGB444 example flattened row by row. They also allow creating the memory in code. For native RGB444 art, our selected dimensions imply Bike depth **1024** (10-bit address) and Reward depth **256** (8-bit address); Q24 subsequently selects native 12-bit RGB444 words rather than indexed palette data.
- **Latency must be respected.** The tips' example ROM takes **2 cycles**, and pixels must be requested that much earlier than display. Inspect the generated IP's actual latency; 2 is not a guarantee for every ROM configuration. The handout asks current visible coordinates to align with the pixels actually being output. This supports the existing project prefetch approach but does not settle every possible rendering architecture.
- **Video baseline:** the handout specifies RGB444 outputs, 1280 × 800 visible coordinates, a requested **83.46 MHz** pixel clock, a white **10 px** border, combinational `drawcon` in the exercise, and testbench checks before the board.
- **Clock architecture is settled:** Drawing Logic Module step 10 explicitly builds a second divider and a roughly **60 Hz clock** for game logic. The team subsequently confirmed that its TAs instructed it to follow this architecture strictly. The **final game** uses the divided game clock; ADR 0002 supersedes ADR 0001. A literal lab exercise alone would not satisfy this selected final-game architecture.
- **Inputs in the exercise:** four direction buttons and centre reset are shown, and switches select the initial full-screen colour. These exercises do not prescribe our final UART mapping, goal switches, reward values or Match rules. The root README concerns board power/programming and the test bitstream, not additional game rules.

## Decisions to settle, in priority order

### 1. What ends a Match, and who wins?

**Team implementation:** reaching the configurable Points target ends the Match immediately (default 20). Otherwise, a Player reaching zero Lives loses, even if ahead on Points; Points decide only when both exhaust their Lives together. **Research rules:** the Match ends when either reaches zero Lives, and the higher Points total wins, including when that Player has no Lives left. These produce opposite winners. Sources: [team scoring and Match end](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L426-L450), [defaults](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/config.py#L68-L78), [[CS-256 Tron Game Mechanics#Match and Rounds]].

**Recommended default for discussion:** retain the research Points-based winner and remove the target from the core scope. **Acceptance case:** P1 finishes a crash Step at 0 Lives and 12 Points; P2 has 2 Lives and 8 Points. The team model gives P2 the win; the research model gives P1 the win. Agree the expected winner before changing either model. Also decide whether reaching 20 Points while both still have Lives ends anything.

### 2. Which Rewards and incentive to survive?

**Team implementation:** at most one Reward, a 2 × 2 Cell rayo; default +1, with a configurable delay of 1 s after collection and a retry each frame until placement succeeds. It awards no Survival Bonus. Both Bikes can collect the same rayo in one Step if they enter different Cells of it. **Research:** three one-Cell Reward slots, values +3/+3/+5 proposed, immediate replacement in the functional model, and a Survival Bonus (proposed +5); Points cap 99 is proposed locally and implemented by both models. Sources: [team constants](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/config.py#L68-L106), [placement and collection](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L352-L436), [[CS-256 Tron Game Mechanics#Rewards]], [[CS-256 Tron Game Mechanics#Points]], [[CS-256/Game_research/prototype/README#Game Model and HDL contract]].

**Recommended default:** retain three Rewards and a Survival Bonus if choosing the research winning rule, but approve an implementable replacement schedule. Do not treat the earlier comparison's “within a few frames” as a guaranteed bound: random retries can keep failing, especially in a crowded Arena. Local worst-case placement for two Rewards is estimated at 834 µs, exceeding the 563.6 µs blanking budget. Sources: [[CS-256 Tron Development Plan#Open items]], [[CS-256 Tron Integration Comparison#3. Technical choices: recommendations]].

**Acceptance cases:** one Player collects while the other Crashes; apply the agreed Reward and Survival Bonus order and cap once the additions are defined. Both Crash: no Survival Bonus. Full Arena: define whether a Reward slot stays empty. If adopting the rayo, specify whether two collectors both receive Points.

### 3. Which physical controls, and which Player uses which keys?

**Team implementation and contract:** both Players share a keyboard connected to the Nexys USB HOST, decoded as PS/2; P1 = WASD, P2 = arrows. Board buttons control menus. **Research:** P1 = board direction buttons, P2 = WASD over a browser USB-UART controller (115200, 8N1). The local Look viewer simulates P1 with arrows and P2 with WASD, reversing the team prototype's PC Player mapping. This changes pins, receiver modules, button ownership, browser support and C's workload. Sources: [team mappings](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/config.py#L119-L133), [contract ports](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/proyecto_final/Contrato%20de%20interfaces%20game_top%20(CS%20256).md#L36-L50), [[CS-256 Tron Game Mechanics#Controls]], [[CS-256 Tron Development Plan#W1 Tasks (18–22 Oct)]], [[CS-256/Game_research/prototype/README#Controls]].

**Recommendation:** choose one demonstrated input path for the demo, then freeze Player labels across both viewers, HDL, controller and report. Test PS/2 with simultaneous WASD/arrows if selecting the team path; test actual browser-to-board UART if selecting the research path. Neither path is approved by this brief.

### 4. Turn buffering and Round flow

The team decoder stores the **latest key**, then rejects reversals when a Step executes; local code retains the **last valid Turn** judged against the current Heading. Heading RIGHT → UP → LEFT before one Step makes the team Bike continue RIGHT, while the local Bike turns UP. A same-Heading request also cancels an earlier Turn in the team model but preserves it locally. Sources: [team decoder](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L86-L113), [Step](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L385-L391), [[CS-256 Tron Game Mechanics#Movement]], [[CS-256/Game_research/prototype/README#Game Model and HDL contract]].

The team model uses a 120-frame pre-Round countdown allowing Heading selection, a 120-frame Crash screen, automatic next-Round countdown and BTNC back to the menu after a Match. Local defaults wait for Start after the Crash freeze, ignore Turns outside RUNNING and let Start immediately begin a new Match from the final screen. Sources: [team Round states](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L281-L363), [[CS-256 Tron Game Mechanics#Match and Rounds]], [[CS-256 Tron Game Mechanics#Movement]].

**Recommended defaults:** last valid Turn; explicit Start for the next Round. **Acceptance cases:** RIGHT → UP → LEFT; RIGHT → UP → RIGHT; Turns during countdown/freeze; Start during freeze and on the final screen. Record the expected Heading and next state for each.

### 5. Geometry, Cell codes and sprite format

**Team implementation:** 16 px Cells, an 80 × 50 screen grid, two HUD rows, 13-bit addresses and 8192 × 4-bit allocation. It distinguishes head, Trail and Crash codes; a rayo occupies four Cells. Sprites are 16 × 16 ROM art displayed at 2×. **Research default:** 8 px Cells, a 160 × 100 screen grid, 256 × 128 padded allocation and 3-bit Cell words; `3` means P2 Trail locally but P1 head in the team model. Heads remain in registers; Reward slots use codes 4–6. Native Bike art defaults to 32 × 32. These encodings cannot be exchanged directly. HUD reservations and final sizes remain subject to lockdown. Sources: [team geometry and encoding](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/config.py#L24-L49), [sprites](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/config.py#L114-L117), [[CS-256 Tron Game Mechanics#Display sizes]], [[CS-256/Game_research/prototype/README#Game Model and HDL contract]], [[CS-256/Game_research/prototype/README#Panel and FPGA limits]].

**Recommendation:** use the 22 October playtest to lock one geometry, HUD reserve, Cell table and ROM format before HDL ports. **Acceptance:** an agreed memory dump decodes identically in model and HDL; HUD/padding are inaccessible; the white border remains visible; Bike collision uses its head Cell. Both models already read both destinations before writing and handle simultaneous Crashes; retain that shared behavior.

### 6. Core scope: menus, live switches, smooth movement and finite Trails

The team prototype already has menus/configuration, live speed/colour/background switches, interpolated sprite movement, and finite Trail options (16/32/64 Cells; infinite is the default). Local scope makes permanent Trails core, HUD “Should,” Setup/customisation “Could,” and smooth movement “Won't this term.” Local Setup vocabulary also freezes settings during play, while team switches act during play. The Scoreboard differs too: research proposes two Points and two Lives digits per Player; team shows Lives, blank, two Points digits. Sources: [team options](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/config.py#L68-L106), [finite Trails and interpolation](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L385-L465), [Scoreboard](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L173-L180), [[CS-256 Tron Game Mechanics#Beyond the core game]], [[CS-256 Tron Game Mechanics#Scoreboard (7-segment)]], [[CS-256 Tron Glossary#Participants and phases]].

**Recommendation:** permanent Trails and stepped sprites for the first integrated build; optional features follow demonstrated core behavior. **Acceptance:** toggling switches during RUNNING has the agreed effect; entering a Cell vacated by a finite Trail tail has a defined result if that option survives. Decide pause/reset separately: the local pause switch has no corresponding gameplay action in the team prototype's input loop.

### 7. Clock and pixel pipeline: align the contract with actual HDL

The team **contract** and local ADR both favor one pixel clock with a frame enable; the ADR remains `proposed`, pending TA confirmation. The local README still says divided game clock baseline, and later VGA-plan sections retain stale divided-clock wording. Resolve those local contradictions. The clock decision is separate from the pixel pipeline: team contract delays sync/blanking by `DRAW_LATENCY`; local Decision B retains output-aligned coordinates and issues memory reads early. The draft comparison recommends changing to delayed sync, but that recommendation has not changed Decision B. Sources: [team clock and latency contract](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/proyecto_final/Contrato%20de%20interfaces%20game_top%20(CS%20256).md#L24-L34), [latency](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/proyecto_final/Contrato%20de%20interfaces%20game_top%20(CS%20256).md#L126-L128), [[0001-pixel-clock-with-frame-enable#Consequences]], [[CS-256/Game_research/README#Rules]], [[CS-256 VGA and Sprite Design Plan#2. Architecture]], [[CS-256 Tron Integration Comparison#7. Fixes needed in our own documents]].

Actual team `vga_out.sv` still ties `tick_60hz` to zero. It registers RGB/sync but does not implement the contract's configurable draw-latency pipeline; its output registers have no reset branch. Do not confuse declared interfaces with completed game hardware. [Actual HDL](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/proyecto_final/vga_out.sv#L23-L43).

**Recommendation:** preserve the selected frame-enable direction pending the TA reply, use the handout's 83.46 MHz, and make an explicit independent pipeline decision. **Acceptance:** exactly one frame pulse at the agreed blanking boundary; all memory updates finish before active video; RGB, text, sync and visibility agree at first/last pixels and line/frame wrap. Measure actual ROM latency instead of assuming it from prose. No HDL simulation result is claimed here.

### 8. One canonical model, ownership and calendar

The team contract explicitly names `prototipos/tron/juego.py` as the HDL reference; local planning names its separate `prototype/model/` and future Step-log comparison. They use different PRNGs too: team 16-bit Galois, seed `0xACE1`, advancing every frame; local 32-bit Fibonacci, seed `0x1D2C3B4A`, advancing for placement draws. Equal seeds or equal input keys cannot make these references agree. Sources: [team PRNG](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L28-L40), [frame advance](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/juego.py#L304-L315), [reference and ownership](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/proyecto_final/Contrato%20de%20interfaces%20game_top%20(CS%20256).md#L514-L538), [[CS-256/Game_research/prototype/README#Game Model and HDL contract]], [[CS-256 Tron Development Plan#Step-log comparison]].

The team uses Mon–Sun milestones and a **26 November demo freeze**; local planning uses Sun–Thu weeks and **23 November**. Both target **15 November** for the pre-demo build, but local planning schedules remaining Must features after that freeze while the team plan expects a complete game by it. Both show 19 November pre-demo, 30 November demo and 10 December report. Sources: [team calendar](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/proyecto_final/Contrato%20de%20interfaces%20game_top%20(CS%20256).md#L547-L571), [[CS-256 Tron Development Plan#Calendar and freezes]], [[CS-256 Tron Development Plan#Ownership]].

**Recommendation:** keep the team repo as the implementation home; select one executable model revision after settling these rules, assign actual people to modules and independent testbenches, and publish one milestone calendar including what “pre-demo ready” contains. **Acceptance:** identical scenario inputs, PRNG schedule and expected per-Step heads/Headings/Points/Lives/Reward positions in the selected model and HDL. Update mechanics, glossary, interface contract and tests together when the team approves a rule.

## Verification performed

Local model suite: **17 tests passed** with `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_model.py` from local `prototype/`. Team standalone suite: **35 tests passed** with `PYTHONDONTWRITEBYTECODE=1 python3 test_juego.py` from team `prototipos/tron/`. These suites pass against different rule sets; they do not establish parity. The new note's YAML and local wikilink targets/headings were checked.

## Commands to open either game

Run on a graphical desktop. These commands create separate Python environments outside the synced vault; install once. GUI launch was not exercised during this review because system Python lacked pygame.

**Local Look Prototype** — the research viewer:

```bash
python3 -m venv "$HOME/.venvs/cs256-look"
"$HOME/.venvs/cs256-look/bin/python" -m pip install -r "/home/alan/Documents/Maestría/CS-256/Game_research/prototype/requirements.txt"
cd "/home/alan/Documents/Maestría/CS-256/Game_research/prototype"
"$HOME/.venvs/cs256-look/bin/python" -m look
```

After setup, only the last two lines are needed. **Arrows = P1; WASD = P2; Space/Enter = Start; P = pause; Backspace = reset; Esc = leave fullscreen/quit.** Full controls: [[CS-256/Game_research/prototype/README#Controls]].

**Team Tron prototype** — first obtain the repo if it is not already cloned:

```bash
git clone https://github.com/romanmg00/FPGA.git "$HOME/FPGA"
python3 -m venv "$HOME/.venvs/cs256-team"
"$HOME/.venvs/cs256-team/bin/python" -m pip install -r "$HOME/FPGA/prototipos/requirements.txt"
cd "$HOME/FPGA/prototipos"
"$HOME/.venvs/cs256-team/bin/python" tron/main.py
```

After setup, only the last two lines are needed; substitute an existing checkout's path if already cloned. For the launcher, run `"$HOME/.venvs/cs256-team/bin/python" lanzador.py` from the same folder. **Enter/Space = select Jugar; P1 = WASD; P2 = arrows; menu arrows = board buttons; 1–6 = switches; C = toggle P2 bot; Esc = quit.** It starts with a two-second countdown. Sources: [team controls](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/tron/main.py#L18-L26), [launcher](https://github.com/romanmg00/FPGA/blob/f5cb82c901e33a453fcaea2720a80702fda54718/prototipos/lanzador.py#L1-L31).
