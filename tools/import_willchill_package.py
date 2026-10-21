#!/usr/bin/env python3
"""Fail closed: the historical 441-item import reintroduced legacy VIP/SVIP.

NIMZO now retains 261 verified non-membership items. Import new authorized
media through a fresh audited integration with explicit catalog review.
"""
import sys

sys.exit(
    "RETIRED: importing the old WillChill archive can restore obsolete VIP/SVIP. "
    "Do not run this importer; use the maintained 261-item catalog."
)
