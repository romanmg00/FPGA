---
title: Reward generator, seed and placement schedule
status: proposed
created_at: "2026-11-23"
---

# Reward generator, seed and placement schedule

> Proposed by Alan on 23 November 2026 with the Rewards PR (G4). Waiting for
> Alan's approval and Roman's review: it settles three items the contract marks
> *pendiente*, and it proposes the `position_logic` and `drawcon` changes, which
> are Roman's, in [issue #61](https://github.com/romanmg00/FPGA/issues/61).
> Revised on 25 November with the `arena_ctrl` follow-up PR: a free-running
> LFSR replaces the mixed `clk_pix` count, and the `placed` mask is dropped
> (see *Seed* and *Reset*).

The [Agreed Specification](../decisions/CS-256%20Tron%20Agreed%20Specification%202026-10-20.md)
(*Rewards and randomness*) leaves "the exact generator, seed capture/advancement
and bounded placement-service schedule" to engineering, asks for a seed
influenced by Start timing plus a fixed-seed mode for tests, and says the model
and the HDL must eventually use the same sequence and schedule. The contract
(§3, *Premios (después)*; §4, *Premios*) adds two constraints: the Reward image
depends on the Cell's code, so reading the code and then the ROM takes 2 + 2
cycles, more than one 2 px read-ahead; and a Reward placed after the neighbour
read would change the Arena between that read and the Step that uses it. The
Development Plan (open item 4) estimates about 123 µs per placement and warns
against pacing a scan one word per 60 Hz tick.

## Decision

**Generator.** The shared model's candidate (`prototipos/tron_fpga/model/lfsr.py`,
`reward_place.py`), unchanged: a 32-bit Fibonacci LFSR, shift left, new bit
0 = bit 31 ^ 21 ^ 1 ^ 0 (x^32 + x^22 + x^2 + x + 1, maximal length). One draw
is 32 shifts, done in one `clk_pix` cycle. A candidate is the draw's bits 12–0, read as the Arena address
`{cy, cx}`. Up to **64 draws**; if every candidate is occupied, scan the 8192
words starting after the last candidate, wrapping. The first EMPTY (code 0)
word takes the Reward. Walls, the HUD rows and the padding hold WALL, so they
are rejected like Trails, heads and other Rewards. With no EMPTY word, the slot
stays absent until the next Prepare.

**Seed.** After a reset the LFSR holds `SEED` = `0x1D2C3B4A`, the model's
`LFSR_SEED`. With `FIXED_SEED` = 0 (the board build) it also makes one draw on
every `clk_pix` cycle that `arena_ctrl` is idle, so it free-runs between
requests. A new Match's Prepare is sent a fixed number of `clk_juego` ticks
after the Start press, and `arena_ctrl` is idle while the Players wait, so the
state that Prepare draws from depends on when Start was pressed, to the
`clk_pix` cycle; the sequence repeats every 2³² − 1 idle cycles, about 51 s.
With `FIXED_SEED` = 1 the LFSR does not free-run: it advances only when it
draws, and the first Prepare after a reset (the Prepare of each new Match,
which `arena_link` marks `reseed`) sets it back to `SEED`, so a test sees the same
Rewards in every Match and matches the model. In both modes later Rounds of a
Match continue the sequence. `game_top` passes `FIXED_SEED` and `SEED` to
`arena_ctrl`.

The free-running LFSR never reaches 0. The single shift is invertible (the old
bit 31 is the new bit 0 XOR old bits 21, 1 and 0) and maps 0 to 0, so it
permutes the 2³² − 1 nonzero states; x³² + x²² + x² + x + 1 is primitive, so they
form one cycle of length 2³² − 1 = 3 × 5 × 17 × 257 × 65537. A draw is 32
shifts, and gcd(32, 2³² − 1) = 1 because 2³² − 1 is odd, so stepping by draws is
also one cycle through every nonzero state. A nonzero `SEED` is enough: no zero
guard is needed.

**Schedule.** `arena_ctrl`, the only writer, places Rewards inside the request
it is serving, before it reads the neighbours:

| Request | Order in `arena_ctrl` |
|---|---|
| Prepare | clear 8192 words (with `FIXED_SEED` = 1, set the LFSR to `SEED` if it starts a Match), write both heads, place slots 0, 1, 2, read the 8 neighbours, answer |
| Step | write the 2 Trails and 2 heads, place each slot taken in that Step (lowest first), read the 8 neighbours, answer |

Because the reads come last, the codes `position_logic` receives already show
any Reward placed next to a head. Nothing writes the Arena between those reads
and the next Step: the next request is sent only after that Step. Each
candidate is checked and written inside one request, and no other write can
happen in between, so a candidate never needs revalidating.

**Bound.** One placement takes 1 cycle to pick the slot, 3 per draw, 2 per
scanned word and 1 to write: at most 1 + 64 × 3 + 8192 × 2 + 1 = 16,578
`clk_pix` cycles, 199 µs. A Prepare with three worst-case placements takes
8,208 + 3 × 16,578 ≈ 58,000 cycles (0.7 ms); a Step without Rewards takes 18
cycles. Any request shorter than one `clk_juego` period (16.7 ms) is answered
before the edge k+2, so the codes still reach `position_logic` at k+4 (contract
§3) and the Step interval does not change. On a nearly empty Arena a
placement usually needs 1–3 draws, about 5–11 cycles.

**Collection** (Roman's `position_logic`, proposed in [issue #61](https://github.com/romanmg00/FPGA/issues/61)). `position_logic`
reports `reward1` and `reward2` on the Step
tick: 0 none, 1–3 for slots 0–2, read from the neighbour code of the Cell the
Bike enters, and only when it moves (none in a Crash Step,
[ADR 0011](0011-a-crash-stops-both-bikes.md)). `score_unit` adds +1, +1 or +3;
`arena_link` sends the slots taken as a 3-bit mask with the heads.

**Reset.** As before, a reset of `arena_ctrl` makes it serve the open request
again from its start, and the LFSR returns to `SEED` on `rst_pix`. A Step cut
after it wrote a Reward places that slot a second time when it is served
again, so the slot can be on two Cells. Nothing in `arena_ctrl` remembers the
first write. A CPU_RESETN press that `clk_juego`'s synchronizer sees resets
`arena_link` too, and `round_fsm` resets into `s_release` (load = 1) while
`arena_link` resets `load_last` to 0, so the first request after that reset is
always a Prepare, which clears the Arena. The duplicate lives less than a tick,
with the Bikes held at their starts. `board_reset_sync` samples CPU_RESETN, so a
press shorter than one `clk_juego` period (about 16.7 ms) can reach only
`clk_pix`. A duplicate then needs the press to begin in the about 10 `clk_pix` cycles
between that Reward's write and the answer (about 120 ns of a 16.7 ms tick) of a
Step that takes a Reward, and it lasts until the next Prepare, at the next Round.
Alan accepted this limit on 25 November: a deliberate press is longer than one
`clk_juego` period; bounce on release comes right after a reset, when no Step
can take a Reward; and bounce on press is followed by the long press, which
resets both domains.

**Drawing** (Roman's `drawcon`, proposed in [issue #61](https://github.com/romanmg00/FPGA/issues/61)). `drawcon` has two
`reward_rom` instances, one for each image
(words 0–255, the +1 gem; 256–511, the +3 star). Both are read for the pixel 2
ahead, like the Arena code, and the code chooses between their outputs when
both arrive. The code selects the output, not the address, so nothing is read
in series. `0F0` is tinted yellow (`FE3`, +1) or violet (`C8F`, +3), the
Python viewer's synthwave Reward colours, and `000` is transparent. Layers:
background, Arena, Rewards, Bikes.

**Release and Goal.** A Round is released only after its Prepare has placed
the Rewards: `match_fsm` holds G_START, and its `round_start`, until
`codes_valid` (about 4 ticks after a new Match's Start). `score_unit`'s Goal
follows `{SW15, SW14}` only while `match_fsm` waits for a new Match, so it keeps
the value of the tick on which Start was accepted, even if Pause holds the
next states. A Match that reaches the Points Goal without a Crash ends at once:
`match_fsm` goes from G_PLAY to G_MATCH, and `position_logic` stops the Round on
`match_over` as it would after a Crash (the last is in the issue).

## Considered options

| Option | Why not |
|---|---|
| Place after the neighbour reads, or in a later request, leaving the slot absent meanwhile (the specification allows it) | A Reward placed next to a head would not be in the codes. The Bike would move onto it unseen and its head write would erase it. Excluding the 8 neighbour Cells adds comparators, and the bound above makes the delay unnecessary |
| A placement service that searches over several frames | The worst case is 0.7 ms per request, well under one tick |
| Mix a `clk_juego` tick count, as the model does | It needs 32 more bits in the Arena crossing. The free-running LFSR gives the same dependence on Start timing with no new crossing |
| XOR a 32-bit `clk_pix` count, never reset, into the LFSR at each new Match (this ADR's first version) | A 32-bit counter, a 32-bit XOR and a zero guard. Stepping the LFSR while idle gives the same dependence on Start timing with the draw logic already there |
| Reset the LFSR to `SEED` at every Prepare in fixed-seed mode | Every Round would restart the sequence, and the model would no longer match |
| Keep a `placed` mask, not reset, that remembers the slots already written for the open request (this ADR's first version) | It is written even on a reset edge and cleared at two points of the request, for a duplicate that the Prepare after a full reset clears within a tick. A press short enough to reach only `clk_pix` and timed inside a Step's placement is the only case it covers for longer |
| One `reward_rom`, with the code choosing the image address | Needs the Arena read 4 px ahead and the code delayed 2 cycles for the Trails; the second ROM costs one 18 Kb BRAM |

## Consequences

- **First Match.** Until now the first Match after power-up used the Prepare
  made at reset. `game_top` now resets `arena_link` with `match_fsm`'s `restart`,
  so every new Match gets its own Prepare, including the first.
  The power-up Prepare also places three Rewards, which are shown while waiting
  for Start and replaced when Start is pressed.
- **Shared model.** Same generator, draw count, scan, slot order and `SEED`;
  `arena_ctrl_tb` checks that with `FIXED_SEED` the first two Prepares place
  the Rewards on the model's Cells, (39,32) (10,9) (1,12), then (5,23) (61,39)
  (30,28). Differences: the seed in normal play (the model XORs in the tick
  count at Start; the HDL free-runs while idle; no test compares it), the power-up
  Prepare (the model has Walls only until Start), and the cycle costs (the
  model counts 33 per draw). The model needs to follow only the power-up
  Prepare, and only if Step logs are compared from power-up.
- **`reseed` in the board build.** With `FIXED_SEED` = 0, `arena_ctrl` does not
  use `reseed`, so synthesis removes its copy and `arena_link`'s `reseed`
  register. The Arena crossing constraint and `build_game_top.tcl`'s check no
  longer name it; `arena_tb` still checks that `arena_link` sends it.
- **Contract.** §3 *Premios (después)* and §4 *Premios* can be settled with
  this text; they are Roman's to edit.
- **Until Roman's change.** `game_top` drives `reward1` and `reward2` with 0.
  The Rewards are placed but not drawn (`drawcon` draws codes 8–10 as empty
  Arena), and `position_logic` already treats them as free Cells: a Bike that
  drives onto one writes its head over it, with no Points, and the slot stays
  empty until the next Prepare. No Goal can be reached yet.
- **Handout.** Once `drawcon` reads two ROMs for the Rewards and chooses by
  code, ADR 0009's rows 6, 7, 9 and 10 name them.
