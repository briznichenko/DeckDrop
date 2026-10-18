import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from deckdrop.transfer.progress import ProgressEstimate, remaining_text


class ProgressTests(unittest.TestCase):
    def test_estimate_requires_elapsed_time_and_received_bytes(self):
        now = [0.0]
        estimate = ProgressEstimate(clock=lambda: now[0])
        self.assertIsNone(estimate.remaining(10, 100))
        now[0] = 2
        self.assertIsNone(estimate.remaining(0, 100))
        self.assertEqual(estimate.remaining(25, 100), 6)
        self.assertIsNone(estimate.remaining(100, 100))
        self.assertIsNone(estimate.remaining(0, 0))

    def test_remaining_time_is_labelled_and_rounded(self):
        self.assertEqual(remaining_text(None), "Estimating…")
        self.assertEqual(remaining_text(.5), "About 1s left")
        self.assertEqual(remaining_text(61), "About 2m left")
        self.assertEqual(remaining_text(3601), "About 1h 1m left")
