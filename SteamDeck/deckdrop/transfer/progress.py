import math
import time


class ProgressEstimate:
    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.started = clock()

    def remaining(self, completed, total):
        elapsed = self.clock() - self.started
        if elapsed < 1 or completed <= 0 or completed >= total:
            return None
        return (total - completed) * elapsed / completed


def remaining_text(seconds):
    if seconds is None:
        return "Estimating…"
    seconds = max(1, math.ceil(seconds))
    if seconds < 60:
        return f"About {seconds}s left"
    minutes = math.ceil(seconds / 60)
    if minutes < 60:
        return f"About {minutes}m left"
    hours, minutes = divmod(minutes, 60)
    return f"About {hours}h {minutes}m left"
