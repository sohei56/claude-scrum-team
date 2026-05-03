"""Characterization tests for dashboard/app.py.

These tests pin down the current behavior of pure helpers and panel widgets
before defensive-code cleanup. They are the regression net for the strip
commits in Phase 3.

Coverage scope:
  - Pure helpers (format_phase, read_json, get_backlog_items): full coverage.
  - Panel widgets (SprintOverview.update_content, PBIProgressBoard.update_content):
    covered via Textual's app.run_test() pilot pattern. Widgets need an active
    App context (NoActiveAppError otherwise), so each panel test instantiates
    a minimal harness App and drives it with asyncio.run.

Run with:
    source .venv/bin/activate
    pytest tests/dashboard/ -v
"""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

import pytest
from textual.app import App, ComposeResult

from dashboard.app import (
    PBIProgressBoard,
    SprintOverview,
    format_phase,
    get_backlog_items,
    read_json,
)

FIXTURES_DIR = Path(__file__).resolve().parent.parent / "fixtures"


# ---------------------------------------------------------------------------
# Pure helper tests
# ---------------------------------------------------------------------------


class TestFormatPhase:
    def test_known_phase_renders_blue(self) -> None:
        result = format_phase("implementation")
        assert "Implementation" in result
        assert "white on blue" in result

    def test_known_phase_complete(self) -> None:
        result = format_phase("complete")
        assert "Complete" in result
        assert "white on blue" in result

    def test_unknown_phase_renders_red(self) -> None:
        result = format_phase("nonsense_phase")
        assert "nonsense_phase" in result
        assert "white on red" in result


class TestReadJson:
    def test_missing_file_returns_none(self, tmp_path: Path) -> None:
        result = read_json(tmp_path / "does-not-exist.json")
        assert result is None

    def test_invalid_json_returns_none(self, tmp_path: Path) -> None:
        bad = tmp_path / "bad.json"
        bad.write_text("{not valid json", encoding="utf-8")
        result = read_json(bad)
        assert result is None

    def test_valid_json_dict_returns_dict(self, tmp_path: Path) -> None:
        good = tmp_path / "good.json"
        good.write_text('{"key": "value"}', encoding="utf-8")
        result = read_json(good)
        assert result == {"key": "value"}

    def test_valid_json_list_returns_list(self, tmp_path: Path) -> None:
        good = tmp_path / "list.json"
        good.write_text("[1, 2, 3]", encoding="utf-8")
        result = read_json(good)
        assert result == [1, 2, 3]


class TestGetBacklogItems:
    def test_fixture_shaped_backlog_returns_items(self) -> None:
        backlog = json.loads((FIXTURES_DIR / "valid-backlog.json").read_text())
        items = get_backlog_items(backlog)
        assert isinstance(items, list)
        assert len(items) == 1
        assert items[0]["id"] == "pbi-001"

    def test_empty_dict_returns_empty_list(self) -> None:
        assert get_backlog_items({}) == []

    def test_none_returns_empty_list(self) -> None:
        assert get_backlog_items(None) == []

    def test_dict_with_items_key(self) -> None:
        backlog = {"items": [{"id": "pbi-1"}]}
        assert get_backlog_items(backlog) == [{"id": "pbi-1"}]


# ---------------------------------------------------------------------------
# Panel-level tests using Textual app.run_test() pilot pattern
# ---------------------------------------------------------------------------


def _seed_scrum_dir(scrum_dir: Path) -> None:
    """Copy fixtures into scrum_dir as state.json/sprint.json/backlog.json."""
    scrum_dir.mkdir(parents=True, exist_ok=True)
    (scrum_dir / "state.json").write_text(
        (FIXTURES_DIR / "valid-state.json").read_text(),
        encoding="utf-8",
    )
    (scrum_dir / "sprint.json").write_text(
        (FIXTURES_DIR / "valid-sprint.json").read_text(),
        encoding="utf-8",
    )
    (scrum_dir / "backlog.json").write_text(
        (FIXTURES_DIR / "valid-backlog.json").read_text(),
        encoding="utf-8",
    )


class _SprintOverviewHarness(App):
    def compose(self) -> ComposeResult:
        yield SprintOverview(id="overview")


class _PBIBoardHarness(App):
    def compose(self) -> ComposeResult:
        yield PBIProgressBoard(id="board")


def _run_async(coro):
    """Drive an async coroutine to completion in a sync test."""
    return asyncio.run(coro)


class TestSprintOverview:
    def test_renders_fixture_content(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        async def runner() -> str:
            import dashboard.app as dash

            scrum = tmp_path / ".scrum"
            _seed_scrum_dir(scrum)
            monkeypatch.setattr(dash, "SCRUM_DIR", scrum)

            app = _SprintOverviewHarness()
            async with app.run_test():
                overview = app.query_one("#overview", SprintOverview)
                overview.update_content()
                return str(overview.render())

        rendered = _run_async(runner())
        assert "Sprint:" in rendered
        assert "sprint-001" in rendered
        assert "Status:" in rendered
        assert "active" in rendered
        assert "Goal:" in rendered
        assert "Implement user management" in rendered
        assert "PBIs:" in rendered

    def test_no_state_shows_placeholder(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        async def runner() -> str:
            import dashboard.app as dash

            scrum = tmp_path / ".scrum"
            scrum.mkdir(parents=True, exist_ok=True)
            # Deliberately do NOT seed any files.
            monkeypatch.setattr(dash, "SCRUM_DIR", scrum)

            app = _SprintOverviewHarness()
            async with app.run_test():
                overview = app.query_one("#overview", SprintOverview)
                overview.update_content()
                return str(overview.render())

        rendered = _run_async(runner())
        assert "No project state" in rendered


class TestPBIProgressBoard:
    def test_fixture_pbi_appears_as_row(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        async def runner() -> list[list[str]]:
            import dashboard.app as dash

            scrum = tmp_path / ".scrum"
            _seed_scrum_dir(scrum)
            monkeypatch.setattr(dash, "SCRUM_DIR", scrum)

            app = _PBIBoardHarness()
            async with app.run_test():
                board = app.query_one("#board", PBIProgressBoard)
                board.update_content()
                rows = [board.get_row_at(i) for i in range(board.row_count)]
                return [[str(c) for c in row] for row in rows]

        rows = _run_async(runner())
        assert len(rows) == 1
        flat = " ".join(rows[0])
        assert "pbi-001" in flat
        assert "User Management" in flat
        # Status should contain "refined" (raw fixture status)
        assert "refined" in flat
        # Implementer resolved from sprint.developers[0].assigned_work.implement
        assert "dev-001-s1" in flat

    def test_empty_backlog_yields_no_rows(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        async def runner() -> int:
            import dashboard.app as dash

            scrum = tmp_path / ".scrum"
            scrum.mkdir(parents=True, exist_ok=True)
            (scrum / "backlog.json").write_text('{"items": []}', encoding="utf-8")
            monkeypatch.setattr(dash, "SCRUM_DIR", scrum)

            app = _PBIBoardHarness()
            async with app.run_test():
                board = app.query_one("#board", PBIProgressBoard)
                board.update_content()
                return board.row_count

        assert _run_async(runner()) == 0
