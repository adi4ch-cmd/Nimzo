import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from gift_selection_policy import validate_selection


class GiftSelectionPolicyTest(unittest.TestCase):
    def selection(self):
        families = ['car', 'dragon', 'angel', 'warrior', 'castle',
                    'romance', 'lion', 'fireworks', 'flower', 'spaceship']
        return [dict(family=families[i // 2], coin_price=500000 if i < 10 else 1000000,
                     sha256=f'{i:064x}') for i in range(20)]

    def test_twenty_diverse_originals_at_both_requested_prices(self):
        validate_selection(self.selection())

    def test_third_car_rejected_even_with_different_name_and_price(self):
        rows = self.selection()
        rows[-1].update(family='car', name='Different luxury car')
        with self.assertRaisesRegex(ValueError, 'Maximum 2 gifts per type: car'):
            validate_selection(rows)

    def test_missing_reviewed_family_fails_closed(self):
        rows = self.selection()
        del rows[0]['family']
        with self.assertRaisesRegex(ValueError, 'reviewed semantic family'):
            validate_selection(rows)

    def test_duplicate_original_is_not_an_additional_gift(self):
        rows = self.selection()
        rows[-1]['sha256'] = rows[0]['sha256']
        with self.assertRaisesRegex(ValueError, 'Duplicate original'):
            validate_selection(rows)

    def test_shortlist_requires_explicit_partial_mode(self):
        rows = self.selection()[:7]
        with self.assertRaisesRegex(ValueError, 'exactly 20'):
            validate_selection(rows)
        validate_selection(rows, allow_partial=True)

    def test_partial_mode_still_rejects_three_same_type(self):
        rows = self.selection()[:7]
        rows[-1]['family'] = 'car'
        with self.assertRaisesRegex(ValueError, 'Maximum 2'):
            validate_selection(rows, allow_partial=True)


if __name__ == '__main__':
    unittest.main()
