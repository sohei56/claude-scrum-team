"""Textual TUI Dashboard for AI-Powered Scrum Team.

Four-panel real-time dashboard that monitors .scrum/ JSON files via
watchdog filesystem events. Designed to run in a tmux side pane alongside
Claude Code.

Panels:
  (a) Sprint Overview — Sprint Goal, phase, PBI count, Developer assignments
  (b) PBI Progress Board — sortable DataTable of PBIs with status colors
  (c) Communication Log — scrollable agent message log
  (d) File Change Log — scrollable file modification log
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock

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
    "in_progress": "yellow",
    "review": "magenta",
    "done": "green",
}


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

        if not state:
            self.update("[bold]No project state[/bold]\nRun scrum-start.sh to begin.")
            return

        phase = state.get("phase", "unknown")
        product_goal = state.get("product_goal", "Not defined")

        lines = [f"[bold]Product Goal:[/bold] {product_goal}"]
        lines.append(f"[bold]Phase:[/bold] {phase}")

        if sprint:
            sprint_id = sprint.get("id", "?")
            goal = sprint.get("goal", "No goal")
            sprint_type = sprint.get("type", "?")
            pbi_count = len(sprint.get("pbi_ids", []))
            dev_count = sprint.get("developer_count", 0)

            lines.append(f"[bold]Sprint:[/bold] {sprint_id} ({sprint_type})")
            lines.append(f"[bold]Goal:[/bold] {goal}")
            lines.append(f"[bold]PBIs:[/bold] {pbi_count} | [bold]Developers:[/bold] {dev_count}")

            devs = sprint.get("developers", [])
            if devs:
                dev_parts = []
                for d in devs:
                    did = d.get("id", "?")
                    status = d.get("status", "?")
                    impl = d.get("assigned_work", {}).get("implement", [])
                    dev_parts.append(f"{did}:{status}({','.join(impl)})")
                lines.append(f"[bold]Agents:[/bold] {' | '.join(dev_parts)}")

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
        self.clear()

        if not backlog:
            return

        items = backlog.get("items", [])
        for item in items:
            pbi_id = item.get("id", "?")
            title = item.get("title", "Untitled")[:35]
            status = item.get("status", "?")
            impl = item.get("implementer_id") or "-"
            reviewer = item.get("reviewer_id") or "-"

            color = STATUS_COLORS.get(status, "")
            if color:
                status_display = f"[{color}]{status}[/{color}]"
            else:
                status_display = status

            self.add_row(pbi_id, title, status_display, impl, reviewer, key=pbi_id)


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
            msg_type = msg.get("type", "?")
            content = msg.get("content", "")

            # Format timestamp to HH:MM:SS
            try:
                dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                ts_short = dt.strftime("%H:%M:%S")
            except (ValueError, AttributeError):
                ts_short = ts[:8]

            self.write(
                f"[dim]{ts_short}[/dim] "
                f"[bold]{sender}[/bold]({role}) → {recipient} "
                f"[{msg_type}] {content}"
            )


class FileChangeLog(RichLog):
    """Panel (d): Scrollable file modification log."""

    DEFAULT_CSS = """
    FileChangeLog {
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
                color = {"created": "green", "modified": "yellow", "deleted": "red"}.get(
                    change, ""
                )
                change_str = f"[{color}]{change}[/{color}]" if color else change
                self.write(f"[dim]{ts_short}[/dim] {change_str} {file_path} ({agent})")
            else:
                self.write(f"[dim]{ts_short}[/dim] [{evt_type}] {detail} ({agent})")


class ScrumFileHandler(FileSystemEventHandler):
    """Watchdog handler that triggers dashboard updates on .scrum/ changes."""

    def __init__(self, app: ScrumDashboard) -> None:
        super().__init__()
        self.app = app
        self._lock = Lock()

    def on_modified(self, event) -> None:
        if event.is_directory:
            return
        self._schedule_update()

    def on_created(self, event) -> None:
        if event.is_directory:
            return
        self._schedule_update()

    def _schedule_update(self) -> None:
        with self._lock:
            self.app.call_from_thread(self.app.refresh_panels)


class ScrumDashboard(App):
    """Main Textual TUI dashboard application."""

    TITLE = "Scrum Team Dashboard"
    CSS = """
    Screen {
        layout: grid;
        grid-size: 2 3;
        grid-rows: auto 1fr 1fr;
    }
    #overview {
        column-span: 2;
    }
    #pbi-board {
        row-span: 2;
    }
    #comm-title, #file-title {
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
            Static("[bold]PBI Progress Board[/bold]", id="pbi-title"),
            PBIProgressBoard(id="pbi-board"),
        )
        yield Vertical(
            Static("[bold]Communication Log[/bold]", id="comm-title"),
            CommunicationLog(id="comm-log"),
            Static("[bold]File Change Log[/bold]", id="file-title"),
            FileChangeLog(id="file-log"),
        )
        yield Footer()

    def on_mount(self) -> None:
        self.refresh_panels()
        self._start_watcher()

    def _start_watcher(self) -> None:
        """Start watchdog observer for .scrum/ directory."""
        if not SCRUM_DIR.exists():
            SCRUM_DIR.mkdir(parents=True, exist_ok=True)

        self._observer = Observer()
        self._observer.schedule(
            ScrumFileHandler(self),
            str(SCRUM_DIR),
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

        comm_log = self.query_one("#comm-log", CommunicationLog)
        comm_log.update_content()

        file_log = self.query_one("#file-log", FileChangeLog)
        file_log.update_content()

    def action_refresh(self) -> None:
        self.refresh_panels()

    def on_unmount(self) -> None:
        if hasattr(self, "_observer"):
            self._observer.stop()
            self._observer.join(timeout=2)


if __name__ == "__main__":
    app = ScrumDashboard()
    app.run()
