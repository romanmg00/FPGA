"""cmd_mailbox (X1): the slow/fast boundary between the game domain and arena_ctrl.

PROPOSAL, not yet agreed: this is the stable-payload mailbox recommended in
the Opus 5.5 review (section 5.4, option D3-A), modelled at tick level.

Slow side (game clock). A command is the registers `op`, its arguments and
`seq`. They change only on a tick edge and then stay stable for the whole
tick. Only one command is outstanding: the game issues a new one only when
the captured response carries the current `seq` (`idle`).

Fast side (pixel clock). Shortly after each tick edge, a synchronized tick
strobe (`tick_seen`) lets the fast side latch the payload. If `seq` is new,
arena_ctrl runs the command and publishes a response within SERVICE_WINDOW
cycles, long before the next tick.

Back to the slow side. At each tick edge one capture register takes the
response bus (`rsp_cap`). Logic reads `rsp_cap` at the following edge. A
command issued at edge k is therefore answered at edge k + 2: STEP_LATENCY.

The HDL also needs an epoch tag or an equivalent reset order so that a
stale response cannot complete after CPU_RESETN (review F7). The model
resets both domains together, so it has no epoch.
"""

from dataclasses import dataclass, field

from .params import SEQ_W

OP_NONE, OP_PREPARE, OP_READ2, OP_COMMIT = 0, 1, 2, 3
OP_NAMES = ("NONE", "PREPARE", "READ2", "COMMIT")
SEQ_MASK = (1 << SEQ_W) - 1


@dataclass(frozen=True)
class Command:
    op: int = OP_NONE
    seq: int = 0
    # PREPARE: new_match, seed_mix, heads ((cx, cy) for P1, for P2)
    new_match: bool = False
    seed_mix: int = 0
    heads: tuple = ()
    # READ2: the two target Cells
    targets: tuple = ()
    # COMMIT: Arena writes ((cx, cy, code), ...) and collected Reward slots
    writes: tuple = ()
    collected: tuple = ()


@dataclass(frozen=True)
class Response:
    seq: int = 0
    codes: tuple = (0, 0)            # READ2: the two target codes
    slots: tuple = (None, None, None)  # Reward slot Cells after the command
    cycles: int = 0                  # fast cycles the command took (estimate)


@dataclass
class Mailbox:
    cmd: Command = field(default_factory=Command)     # slow-side registers
    rsp_bus: Response = field(default_factory=Response)  # fast-side registers
    rsp_cap: Response = field(default_factory=Response)  # slow-side capture register
    fast_seq: int = 0                                  # last seq the fast side ran

    # --- slow side ---------------------------------------------------------
    def idle(self) -> bool:
        """The captured response answers the current command."""
        return self.rsp_cap.seq == self.cmd.seq

    def issue(self, op: int, **args) -> None:
        if not self.idle():
            raise RuntimeError(f"mailbox busy: {OP_NAMES[op]} issued while "
                               f"{OP_NAMES[self.cmd.op]} is outstanding")
        self.cmd = Command(op=op, seq=(self.cmd.seq + 1) & SEQ_MASK, **args)

    def capture(self) -> None:
        """Tick edge: the capture register takes the response bus."""
        self.rsp_cap = self.rsp_bus

    # --- fast side ---------------------------------------------------------
    def take(self):
        """After tick_seen: the new command, if `seq` changed, else None."""
        if self.cmd.seq == self.fast_seq:
            return None
        self.fast_seq = self.cmd.seq
        return self.cmd

    def publish(self, rsp: Response) -> None:
        self.rsp_bus = rsp
