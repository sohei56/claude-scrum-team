"""Textual TUI Dashboard for AI-Powered Scrum Team.

Four-panel real-time dashboard that monitors .scrum/ JSON files via
watchdog filesystem events. Designed to run in a tmux side pane alongside
Claude Code.

Panels:
  (a) Sprint Overview — Sprint Goal, phase, PBI count, Developer assignments
  (b) PBI Progress Board — sortable DataTable of PBIs with status colors
  (c) Communication Log — scrollable agent message log
  (d) Work Log — scrollable activity/work log
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from threading import Lock, Timer

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.widgets import DataTable, Footer, Header, RichLog, Static
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

SCRUM_DIR = Path(".scrum")

# Status colors for PBI Progress Board
STATUS_COLORS = {
    "draft": "dim",
    "refined": "cyan",
    "ready": "cyan",
    "planned": "cyan",
    "in_progress": "yellow",
    "in-progress": "yellow",
    "in progress": "yellow",
    "review": "magenta",
    "in_review": "magenta",
    "done": "green",
    "completed": "green",
    "complete": "green",
}

# Normalize status values to canonical forms
STATUS_NORMALIZE = {
    "ready": "refined",
    "planned": "refined",
    "in-progress": "in_progress",
    "in progress": "in_progress",
    "in_review": "review",
    "completed": "done",
    "complete": "done",
}

# Ordered phase flow for "you are here" display
PHASE_FLOW = [
    ("new", "New"),
    ("requirements_sprint", "Requirements"),
    ("backlog_created", "Backlog Created"),
    ("sprint_planning", "Sprint Planning"),
    ("design", "Design"),
    ("implementation", "Implementation"),
    ("review", "Review"),
    ("sprint_review", "Sprint Review"),
    ("retrospective", "Retrospective"),
    ("integration_sprint", "Integration"),
    ("complete", "Complete"),
]


def format_phase(current_phase: str) -> str:
    """Render the current phase as a compact highlighted label."""
    for phase_key, phase_label in PHASE_FLOW:
        if phase_key == current_phase:
            return f"[bold]Phase:[/bold] [bold white on blue] {phase_label} [/]"
    return f"[bold]Phase:[/bold] [bold white on red] {current_phase} [/]"


def get_backlog_items(backlog: dict | list | None) -> list:
    """Extract PBI items from backlog data, handling variant key names."""
    if isinstance(backlog, dict):
        return (
            backlog.get("items")
            or backlog.get("backlog_items")
            or backlog.get("pbis")
            or backlog.get("pbi_list")
            or backlog.get("product_backlog")
            or backlog.get("backlog")
            or []
        )
    if isinstance(backlog, list):
        return backlog
    return []


def read_json(path: Path) -> dict | list | None:
    """Read a JSON file, returning None if missing or invalid."""
    try:
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        pass
    return None


class SprintOverview(Static):
    """Panel (a): Sprint Goal, phase, PBI count, Developer assignments."""

    DEFAULT_CSS = """
    SprintOverview {
        height: auto;
        min-height: 5;
        border: solid $accent;
        padding: 0 1;
    }
    """

    def update_content(self) -> None:
        state = read_json(SCRUM_DIR / "state.json")
        sprint = read_json(SCRUM_DIR / "sprint.json")
        backlog = read_json(SCRUM_DIR / "backlog.json")

        if not state:
            self.update("[bold]No project state[/bold]\nRun scrum-start.sh to begin.")
            return

        phase = state.get("phase", "unknown")
        product_goal = state.get("product_goal", "Not defined")

        lines = [f"[bold]Product Goal:[/bold] {product_goal}"]
        lines.append(format_phase(phase))

        if sprint and isinstance(sprint, dict):
            # Handle both data-model field names and agent-produced field names
            sprint_id = sprint.get("id") or sprint.get("sprint_number") or "?"
            goal = sprint.get("goal") or sprint.get("sprint_goal") or "No goal"
            sprint_status = sprint.get("status") or "?"

            # PBI IDs: from pbi_ids[] (spec) or pbis[] objects (agent)
            pbi_ids = sprint.get("pbi_ids") or []
            sprint_pbis = sprint.get("pbis") or []
            if not pbi_ids and sprint_pbis:
                pbi_ids = [p.get("id", "?") for p in sprint_pbis if isinstance(p, dict)]
            pbi_count = len(pbi_ids)

            # Count done PBIs: from backlog (spec) or inline pbis (agent)
            done_count = 0
            if sprint_pbis:
                for p in sprint_pbis:
                    if isinstance(p, dict) and p.get("status") == "done":
                        done_count += 1
            elif backlog and pbi_ids:
                for item in get_backlog_items(backlog):
                    if not isinstance(item, dict):
                        continue
                    if item.get("id") in pbi_ids and item.get("status") == "done":
                        done_count += 1

            # Developer count: from developer_count, developers[], or pbis[]
            devs = sprint.get("developers") or []
            dev_count = sprint.get("developer_count") or len(devs) or 0
            if not dev_count and sprint_pbis:
                devs_set = set()
                for p in sprint_pbis:
                    if isinstance(p, dict):
                        assigned = p.get("assigned_to")
                        if assigned:
                            devs_set.add(assigned)
                dev_count = len(devs_set)

            lines.append(
                f"[bold]Sprint:[/bold] {sprint_id}"
                f" | [bold]Status:[/bold] {sprint_status}"
                f" | [bold]Goal:[/bold] {goal}"
            )

            lines.append(
                f"[bold]PBIs:[/bold] {done_count}/{pbi_count} done"
                f" | [bold]Developers:[/bold] {dev_count}"
            )

            # Agent assignments: from developers[] (spec) or pbis[] (agent)
            if devs:
                dev_parts = []
                for d in devs:
                    if isinstance(d, str):
                        dev_parts.append(d)
                        continue
                    if not isinstance(d, dict):
                        continue
                    did = d.get("id", "?")
                    status = d.get("status", "?")
                    impl = d.get("assigned_work", {}).get("implement", [])
                    dev_parts.append(f"{did}:{status}({','.join(impl)})")
                lines.append(f"[bold]Agents:[/bold] {' | '.join(dev_parts)}")
            elif sprint_pbis:
                dev_parts = []
                for p in sprint_pbis:
                    if isinstance(p, dict):
                        assigned = p.get("assigned_to") or "?"
                        pid = p.get("id") or "?"
                        pstatus = p.get("status") or "?"
                        dev_parts.append(f"{assigned}→{pid}({pstatus})")
                lines.append(f"[bold]Agents:[/bold] {' | '.join(dev_parts)}")
        else:
            lines.append("[dim]No active Sprint — waiting for Sprint Planning[/dim]")

        self.update("\n".join(lines))


class PBIProgressBoard(DataTable):
    """Panel (b): Sortable DataTable of PBIs with status-colored rows."""

    DEFAULT_CSS = """
    PBIProgressBoard {
        height: 1fr;
        border: solid $accent;
    }
    """

    def on_mount(self) -> None:
        self.add_columns("ID", "Title", "Status", "Implementer", "Reviewer")
        self.cursor_type = "row"
        self.update_content()

    def update_content(self) -> None:
        backlog = read_json(SCRUM_DIR / "backlog.json")
        sprint = read_json(SCRUM_DIR / "sprint.json")
        self.clear()

        # Build PBI→developer lookup from sprint.json developers[]
        # Use lowercase keys for case-insensitive matching
        pbi_impl_map: dict[str, str] = {}
        pbi_review_map: dict[str, str] = {}
        if sprint and isinstance(sprint, dict):
            for dev in sprint.get("developers") or []:
                if not isinstance(dev, dict):
                    continue
                did = dev.get("id") or dev.get("name") or "?"
                assigned = dev.get("assigned_work") or {}
                if not isinstance(assigned, dict):
                    continue
                for pbi_id in assigned.get("implement") or []:
                    pbi_impl_map[str(pbi_id).lower()] = did
                for pbi_id in assigned.get("review") or []:
                    pbi_review_map[str(pbi_id).lower()] = did

            # Also check sprint.pbis[] for inline assignments
            for p in sprint.get("pbis") or []:
                if not isinstance(p, dict):
                    continue
                pid = str(p.get("id", "")).lower()
                if pid:
                    if p.get("assigned_to") and pid not in pbi_impl_map:
                        pbi_impl_map[pid] = p["assigned_to"]
                    if p.get("reviewer") and pid not in pbi_review_map:
                        pbi_review_map[pid] = p["reviewer"]

        # Collect PBI items from backlog (spec format) or sprint.pbis (agent format)
        # Try multiple key names — LLM agents may use non-canonical names
        items = get_backlog_items(backlog)
        if not items and sprint and isinstance(sprint, dict):
            items = sprint.get("pbis", [])

        for item in items:
            if not isinstance(item, dict):
                continue
            pbi_id = item.get("id", "?")
            title = item.get("title", "Untitled")[:35]
            raw_status = item.get("status", "?")
            # Normalize status to canonical form
            status = STATUS_NORMALIZE.get(raw_status, raw_status)
            # Resolve implementer: prefer sprint.json developer map (most
            # reliable — set by spawn-teammates after reconciliation), then
            # fall back to backlog.json fields which may hold placeholders.
            pbi_key = str(pbi_id).lower()
            impl = (
                pbi_impl_map.get(pbi_key)
                or item.get("implementer_id")
                or item.get("implementer")
                or item.get("assigned_to")
                or item.get("developer")
                or item.get("developer_id")
                or "-"
            )
            reviewer = (
                pbi_review_map.get(pbi_key)
                or item.get("reviewer_id")
                or item.get("reviewer")
                or item.get("assigned_reviewer")
                or "-"
            )

            color = STATUS_COLORS.get(status, "")
            status_display = f"[{color}]{status}[/{color}]" if color else status

            self.add_row(pbi_id, title, status_display, impl, reviewer, key=pbi_id)

        # Scroll to the last row so the latest PBI is visible
        if self.row_count:
            self.move_cursor(row=self.row_count - 1)


class TestResultsPanel(Static):
    """Panel: Test results from Integration Sprint smoke-test."""

    DEFAULT_CSS = """
    TestResultsPanel {
        height: auto;
        min-height: 3;
        border: solid $accent;
        padding: 0 1;
    }
    """

    STATUS_STYLES = {
        "passed": "[bold green]PASSED[/bold green]",
        "failed": "[bold red]FAILED[/bold red]",
        "running": "[bold yellow]RUNNING[/bold yellow]",
        "pending": "[bold dim]PENDING[/bold dim]",
        "skipped": "[dim]SKIPPED[/dim]",
    }

    def update_content(self) -> None:
        results = read_json(SCRUM_DIR / "test-results.json")
        if not results:
            self.display = False
            return

        self.display = True
        overall = results.get("overall_status", "unknown")
        overall_styled = self.STATUS_STYLES.get(overall, f"[bold]{overall}[/bold]")

        lines = [f"[bold]Test Results:[/bold] {overall_styled}"]

        for cat in results.get("categories", []):
            if not isinstance(cat, dict):
                continue
            name = cat.get("name", "?")
            status = cat.get("status", "?")
            total = cat.get("total", 0)
            passed = cat.get("passed", 0)
            failed = cat.get("failed", 0)

            if status == "passed":
                line = f"  [green]{name}: {passed}/{total} passed[/green]"
            elif status == "failed":
                line = f"  [red]{name}: {passed}/{total} passed ({failed} failed)[/red]"
            elif status == "skipped":
                line = f"  [dim]{name}: skipped[/dim]"
            else:
                line = f"  [yellow]{name}: {status}[/yellow]"
            lines.append(line)

            # Show first 3 errors for failed categories
            if status == "failed":
                errors = cat.get("errors", [])
                for err in errors[:3]:
                    test_name = err.get("test_name", "?")
                    message = err.get("message", "?")
                    lines.append(f"    [red]- {test_name}: {message}[/red]")
                if len(errors) > 3:
                    lines.append(f"    [dim]  (+{len(errors) - 3} more errors)[/dim]")

        self.update("\n".join(lines))


class CommunicationLog(RichLog):
    """Panel (c): Scrollable agent message log."""

    DEFAULT_CSS = """
    CommunicationLog {
        height: 1fr;
        border: solid $accent;
    }
    """

    def __init__(self, **kwargs) -> None:
        super().__init__(highlight=True, markup=True, wrap=True, **kwargs)
        self._last_count = 0

    def update_content(self) -> None:
        comms = read_json(SCRUM_DIR / "communications.json")
        if not comms:
            return

        messages = comms.get("messages", [])
        new_messages = messages[self._last_count :]
        self._last_count = len(messages)

        for msg in new_messages:
            ts = msg.get("timestamp", "?")
            sender = msg.get("sender_id", "?")
            role = msg.get("sender_role", "")
            recipient = msg.get("recipient_id") or "all"
            content = msg.get("content", "")

            # Format timestamp to HH:MM:SS
            try:
                dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                ts_short = dt.strftime("%H:%M:%S")
            except (ValueError, AttributeError):
                ts_short = ts[:8]

            role_str = f" ({role})" if role else ""
            recipient_str = f" → {recipient}" if recipient != "all" else ""
            self.write(
                f"[dim]{ts_short}[/dim] [bold]{sender}[/bold]{role_str}{recipient_str} {content}"
            )


class WorkLog(RichLog):
    """Panel (d): Scrollable activity/work log."""

    DEFAULT_CSS = """
    WorkLog {
        height: 1fr;
        border: solid $accent;
    }
    """

    def __init__(self, **kwargs) -> None:
        super().__init__(highlight=True, markup=True, wrap=True, **kwargs)
        self._last_count = 0

    def update_content(self) -> None:
        dashboard = read_json(SCRUM_DIR / "dashboard.json")
        if not dashboard:
            return

        events = dashboard.get("events", [])
        new_events = events[self._last_count :]
        self._last_count = len(events)

        for evt in new_events:
            ts = evt.get("timestamp", "?")
            evt_type = evt.get("type", "?")
            agent = evt.get("agent_id") or "?"
            file_path = evt.get("file_path") or ""
            change = evt.get("change_type") or ""
            detail = evt.get("detail", "")

            try:
                dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                ts_short = dt.strftime("%H:%M:%S")
            except (ValueError, AttributeError):
                ts_short = ts[:8]

            if evt_type == "file_changed" and file_path:
                color = {"created": "green", "modified": "yellow", "deleted": "red"}.get(change, "")
                change_str = f"[{color}]{change}[/{color}]" if color else change
                self.write(f"[dim]{ts_short}[/dim] {change_str} {file_path} ({agent})")
            elif evt_type == "teammate_idle":
                self.write(f"[dim]{ts_short}[/dim] [cyan]idle[/cyan] {detail} ({agent})")
            elif evt_type == "session_event":
                self.write(f"[dim]{ts_short}[/dim] [magenta]event[/magenta] {detail}")
            elif detail:
                self.write(f"[dim]{ts_short}[/dim] {detail} ({agent})")
            else:
                self.write(f"[dim]{ts_short}[/dim] {evt_type} ({agent})")


class ScrumFileHandler(FileSystemEventHandler):
    """Watchdog handler that triggers debounced dashboard updates on .scrum/ changes.

    Uses a 200ms debounce timer so that rapid writes (e.g., tmp-file + mv)
    are coalesced into a single refresh rather than causing redundant redraws.
    """

    DEBOUNCE_SECONDS = 0.2

    def __init__(self, app: ScrumDashboard) -> None:
        super().__init__()
        self.app = app
        self._lock = Lock()
        self._pending_timer: object | None = None

    def on_modified(self, event) -> None:
        if event.is_directory:
            return
        self._schedule_update()

    def on_created(self, event) -> None:
        if event.is_directory:
            return
        self._schedule_update()

    def on_moved(self, event) -> None:
        self._schedule_update()

    def _schedule_update(self) -> None:
        with self._lock:
            # Cancel any pending debounce timer and start a new one
            if self._pending_timer is not None:
                self._pending_timer.cancel()
            self._pending_timer = Timer(
                self.DEBOUNCE_SECONDS,
                lambda: self.app.call_from_thread(self.app.refresh_panels),
            )
            self._pending_timer.daemon = True
            self._pending_timer.start()


class ScrumDashboard(App):
    """Main Textual TUI dashboard application."""

    TITLE = "Scrum Team Dashboard"
    CSS = """
    Screen {
        layout: grid;
        grid-size: 1 3;
        grid-rows: auto 1fr 1fr;
    }
    #logs-row {
        layout: grid;
        grid-size: 2 1;
    }
    #comm-title, #work-title {
        height: 1;
        text-style: bold;
        color: $text;
        padding: 0 1;
    }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("r", "refresh", "Refresh"),
        Binding("tab", "focus_next", "Next Panel"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield SprintOverview(id="overview")
        yield Vertical(
            TestResultsPanel(id="test-results"),
            Static("[bold]PBI Progress Board[/bold]", id="pbi-title"),
            PBIProgressBoard(id="pbi-board"),
        )
        with Horizontal(id="logs-row"):
            yield Vertical(
                Static("[bold]Communication Log[/bold]", id="comm-title"),
                CommunicationLog(id="comm-log"),
            )
            yield Vertical(
                Static("[bold]Work Log[/bold]", id="work-title"),
                WorkLog(id="work-log"),
            )
        yield Footer()

    def on_mount(self) -> None:
        self.refresh_panels()
        self._start_watcher()
        # Periodic fallback: refresh every 1 second in case watchdog misses events
        self.set_interval(1, self.refresh_panels)

    def _start_watcher(self) -> None:
        """Start watchdog observer for .scrum/ directory."""
        if not SCRUM_DIR.exists():
            SCRUM_DIR.mkdir(parents=True, exist_ok=True)

        # Use absolute path to avoid working directory issues
        watch_path = str(SCRUM_DIR.resolve())

        self._observer = Observer()
        self._observer.schedule(
            ScrumFileHandler(self),
            watch_path,
            recursive=True,
        )
        self._observer.daemon = True
        self._observer.start()

    def refresh_panels(self) -> None:
        """Refresh all dashboard panels from disk."""
        overview = self.query_one("#overview", SprintOverview)
        overview.update_content()

        pbi_board = self.query_one("#pbi-board", PBIProgressBoard)
        pbi_board.update_content()

        test_results = self.query_one("#test-results", TestResultsPanel)
        test_results.update_content()

        comm_log = self.query_one("#comm-log", CommunicationLog)
        comm_log.update_content()

        work_log = self.query_one("#work-log", WorkLog)
        work_log.update_content()

    def action_refresh(self) -> None:
        self.refresh_panels()

    def on_unmount(self) -> None:
        if hasattr(self, "_observer"):
            self._observer.stop()
            self._observer.join(timeout=2)


if __name__ == "__main__":
    app = ScrumDashboard()
    app.run()
