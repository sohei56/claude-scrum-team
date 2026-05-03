"""Test fixtures and path setup for dashboard tests.

dashboard/ has no __init__.py (it's a script directory), so we make it
importable by adding the repo root to sys.path.
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
