"""Owner's premium gift selection rules, checked before any asset import."""
from collections import Counter
import re


def validate_selection(rows, *, allow_partial=False):
    if len(rows) != 20 and not (allow_partial and 0 < len(rows) < 20):
        raise ValueError('Select exactly 20 additional gifts')
    prices = Counter(row['coin_price'] for row in rows)
    if (allow_partial and (not set(prices) <= {500000, 1000000} or max(prices.values()) > 10)
            or not allow_partial and prices != {500000: 10, 1000000: 10}):
        raise ValueError('Select 10 gifts at 500K and 10 at 1M coins')
    families = []
    for row in rows:
        family = row.get('family', '')
        if not isinstance(family, str) or not re.fullmatch(r'[a-z]+(?:_[a-z]+)*', family):
            raise ValueError('Every gift needs a reviewed semantic family')
        families.append(family)
    repeated = sorted(family for family, count in Counter(families).items() if count > 2)
    if repeated:
        raise ValueError('Maximum 2 gifts per type: ' + ', '.join(repeated))
    hashes = [row['sha256'] for row in rows]
    if len(set(hashes)) != len(hashes):
        raise ValueError('Duplicate original gift bytes')

