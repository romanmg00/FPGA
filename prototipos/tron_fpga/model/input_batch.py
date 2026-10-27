"""Input capture in the fast domain (I1-I3): btn_debounce, uart_rx decoder, input_batch.

PROPOSAL (review section 5.5, option D4-A, and E2), not yet agreed.

- btn_debounce: the model receives clean press pulses, one 5-bit mask per
  button sample (bit order BTN_U, BTN_D, BTN_L, BTN_R, BTN_C). The 2-FF
  synchronizer and the stable-for-D counter are not modelled; PC key
  presses do not bounce.
- uart decoder: one byte at a time, in arrival order. w/a/s/d in either
  case steer P2; 0x20 (Space) and 0x0D (Enter) mean Start; every other
  byte, including 0x0A, is ignored. The 115200-baud bit timing of uart_rx
  is not modelled.
- input_batch: one axis latch per Player, V in {None, UP, DOWN} and
  H in {None, RIGHT, LEFT}. Each direction event overwrites its own axis.
  In one button sample UP beats DOWN and RIGHT beats LEFT, which is the
  agreed UP > RIGHT > DOWN > LEFT tie order restricted to one axis. A
  Start from BTNC or the UART sets one flag. On each tick strobe the batch
  is published to the game domain and the latches clear, so every event
  lands in exactly one tick.
- Eligibility at arrival: the fast domain already holds the render snapshot
  the game published after the last edge, with its phase and synchronized
  Pause. Direction events are latched only while that snapshot shows
  running play, and Start only in a wait state (G_IDLE, G_READY, G_MATCH),
  both unpaused. So a Start pressed during the Crash display or a Turn
  pressed in the ready wait is dropped even though the batch reaches the
  game two ticks later, when the phase may already have changed. The game
  domain checks the phase again when it applies the batch.

Why two axes are enough: within one tick the Heading cannot change, and a
request is valid exactly when it is on the axis across the Heading. So
"the last valid request wins" is "the last event on the crossing axis
wins", whatever the order of events on the other axis. turn_unit makes
that judgment in the game domain.
"""

from dataclasses import dataclass

from .params import BTN_C, BTN_D, BTN_L, BTN_R, BTN_U, DIR_DOWN, DIR_LEFT, DIR_RIGHT, DIR_UP

UART_DIRS = {ord("w"): DIR_UP, ord("a"): DIR_LEFT, ord("s"): DIR_DOWN, ord("d"): DIR_RIGHT}
UART_DIRS.update({k - 32: v for k, v in list(UART_DIRS.items())})   # W A S D
UART_START = (0x20, 0x0D)
UART_KEY = {DIR_UP: b"w", DIR_LEFT: b"a", DIR_DOWN: b"s", DIR_RIGHT: b"d"}
BTN_OF = {DIR_UP: 1 << BTN_U, DIR_DOWN: 1 << BTN_D, DIR_LEFT: 1 << BTN_L, DIR_RIGHT: 1 << BTN_R}
BTN_START = 1 << BTN_C


def uart_decode(byte: int):
    """('turn', Heading), ('start', None) or None."""
    if byte in UART_DIRS:
        return "turn", UART_DIRS[byte]
    if byte in UART_START:
        return "start", None
    return None


@dataclass(frozen=True)
class Batch:
    """One tick's inputs as the game domain receives them."""
    axes: tuple = ((None, None), (None, None))   # (V, H) for P1, for P2
    start: bool = False


EMPTY_BATCH = Batch()


class AxisLatch:
    def __init__(self):
        self.v = self.h = None

    def event(self, heading: int) -> None:
        if heading in (DIR_UP, DIR_DOWN):
            self.v = heading
        else:
            self.h = heading


class InputBatch:
    def __init__(self):
        self.reset()
        self.enable(True, True)          # game_top sets this every tick

    def reset(self) -> None:
        self.latch = [AxisLatch(), AxisLatch()]
        self.start = False

    def enable(self, turns: bool, start: bool) -> None:
        """From the latched render snapshot: which events count right now."""
        self.turns_ok, self.start_ok = turns, start

    def button_sample(self, mask: int) -> None:
        """One debounced sample of btn_pulse[4:0]: P1's directions and Start."""
        p1 = self.latch[0]
        if mask & BTN_START and self.start_ok:
            self.start = True
        if not self.turns_ok:
            return
        if mask & BTN_OF[DIR_UP]:
            p1.v = DIR_UP
        elif mask & BTN_OF[DIR_DOWN]:
            p1.v = DIR_DOWN
        if mask & BTN_OF[DIR_RIGHT]:
            p1.h = DIR_RIGHT
        elif mask & BTN_OF[DIR_LEFT]:
            p1.h = DIR_LEFT

    def uart_byte(self, byte: int) -> None:
        decoded = uart_decode(byte)
        if decoded is None:
            return
        kind, heading = decoded
        if kind == "turn" and self.turns_ok:
            self.latch[1].event(heading)
        elif kind == "start" and self.start_ok:
            self.start = True

    def publish(self) -> Batch:
        """Tick strobe: hand over this tick's batch and clear the latches."""
        batch = Batch(tuple((l.v, l.h) for l in self.latch), self.start)
        self.reset()
        return batch
