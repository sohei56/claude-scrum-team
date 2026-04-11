"""codex app-server (JSON-RPC over stdio) クライアント.

codex app-server を常駐プロセスとして起動し、JSON-RPC通信で
OpenAIモデルを呼び出す。毎回 codex exec を起動する方式と比較して、
プロセス起動コストの排除と構造化通信による安定性向上を実現する。
"""

from __future__ import annotations

import glob
import json
import os
import select
import shutil
import subprocess
import threading
import time


def _find_codex() -> str:
    """codex コマンドのパスを検索する."""
    codex_path = shutil.which("codex")
    if codex_path:
        return codex_path
    for candidate in [
        os.path.expanduser("~/.local/bin/codex"),
        "/usr/local/bin/codex",
        "/opt/homebrew/bin/codex",
        os.path.expanduser("~/.nvm/versions/node/*/bin/codex"),
    ]:
        if "*" in candidate:
            matches = glob.glob(candidate)
            if matches:
                return matches[-1]
        elif os.path.isfile(candidate):
            return candidate
    raise FileNotFoundError(
        "codex コマンドが見つかりません。"
        "`npm i -g @openai/codex` でインストールしてください"
    )


class CodexAppServerClient:
    """codex app-server (JSON-RPC over stdio) クライアント."""

    def __init__(self) -> None:
        self._process: subprocess.Popen[bytes] | None = None
        self._request_id: int = 0
        self._lock = threading.Lock()
        self._codex_path: str = _find_codex()
        self._initialized: bool = False

    def start(self) -> None:
        """app-serverプロセスを起動し、initializeハンドシェイクを実行."""
        if self._process is not None and self._process.poll() is None:
            return
        self._process = subprocess.Popen(
            [self._codex_path, "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self._initialized = False
        self._initialize()

    def _initialize(self) -> None:
        """initializeハンドシェイクを実行."""
        req_id = self._send("initialize", {
            "clientInfo": {"name": "mcp-openai", "version": "0.3.0"},
        })
        resp = self._wait_for_response(req_id, timeout=10.0)
        if "error" in resp:
            err = resp["error"]
            raise RuntimeError(f"initialize failed: {err.get('message', str(err))}")
        self._initialized = True

    def stop(self) -> None:
        """app-serverプロセスを停止."""
        if self._process is None:
            return
        try:
            if self._process.stdin:
                self._process.stdin.close()
            self._process.terminate()
            self._process.wait(timeout=5)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            self._process.kill()
            self._process.wait(timeout=3)
        finally:
            self._process = None
            self._initialized = False

    def is_alive(self) -> bool:
        """プロセスの生存確認."""
        return (
            self._process is not None
            and self._process.poll() is None
            and self._initialized
        )

    def _ensure_alive(self) -> None:
        """プロセスが死んでいたら自動再起動."""
        if not self.is_alive():
            self.stop()
            self.start()

    def _next_id(self) -> int:
        self._request_id += 1
        return self._request_id

    def _send(self, method: str, params: dict) -> int:
        """JSON-RPCリクエストを送信. リクエストIDを返す."""
        assert self._process is not None
        assert self._process.stdin is not None
        req_id = self._next_id()
        msg = json.dumps({"method": method, "params": params, "id": req_id})
        self._process.stdin.write(msg.encode() + b"\n")
        self._process.stdin.flush()
        return req_id

    def _read_messages(self, timeout: float = 5.0) -> list[dict]:
        """stdoutからJSON-RPCメッセージを読む. 複数行が一度に来る場合に対応."""
        assert self._process is not None
        assert self._process.stdout is not None
        stdout_fd = self._process.stdout.fileno()
        ready, _, _ = select.select([stdout_fd], [], [], timeout)
        if not ready:
            return []
        data = os.read(stdout_fd, 65536)
        if not data:
            return []
        results = []
        for line in data.decode().strip().split("\n"):
            if line.strip():
                try:
                    results.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
        return results

    def _wait_for_response(self, req_id: int, timeout: float = 30.0) -> dict:
        """指定IDのJSON-RPCレスポンスを待つ. notificationはスキップ."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            msgs = self._read_messages(timeout=min(remaining, 5.0))
            for msg in msgs:
                if msg.get("id") == req_id:
                    return msg
        raise TimeoutError(f"JSON-RPC response for id={req_id} timed out ({timeout}s)")

    def _collect_turn_output(self, timeout: float = 300.0) -> tuple[str, str]:
        """turn完了までイベントを読み、テキストとステータスを返す."""
        text_parts: list[str] = []
        deadline = time.monotonic() + timeout

        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            msgs = self._read_messages(timeout=min(remaining, 5.0))
            for msg in msgs:
                method = msg.get("method", "")
                params = msg.get("params", {})

                if "agentMessage" in method and "delta" in method:
                    delta = params.get("delta", "")
                    if delta:
                        text_parts.append(delta)
                elif "turn" in method and "completed" in method.lower():
                    turn = params.get("turn", {})
                    status = turn.get("status", "completed")
                    error = turn.get("error")
                    if status == "failed" and error:
                        error_msg = error.get("message", "不明なエラー")
                        return error_msg, "error"
                    return "".join(text_parts), status

        full_text = "".join(text_parts)
        if full_text:
            return full_text, "timeout"
        raise TimeoutError(f"Turn completion timed out ({timeout}s)")

    def chat(
        self,
        model: str,
        system_prompt: str,
        messages: list[dict],
    ) -> tuple[str, str]:
        """thread/start + turn/start でチャットを実行.

        Args:
            model: 使用するモデル名
            system_prompt: baseInstructionsとして渡すシステム指示
            messages: 会話履歴

        Returns:
            (response_text, turn_status) のタプル
        """
        with self._lock:
            self._ensure_alive()

            # 1. thread/start
            thread_req_id = self._send("thread/start", {
                "model": model,
                "baseInstructions": system_prompt,
                "approvalPolicy": "never",
                "ephemeral": True,
                "personality": "none",
            })
            thread_resp = self._wait_for_response(thread_req_id, timeout=30.0)

            if "error" in thread_resp:
                err = thread_resp["error"]
                error_msg = err.get("message", str(err))
                return f"thread/start エラー: {error_msg}", "error"

            result = thread_resp.get("result", {})
            thread_id = result.get("thread", {}).get("id")
            if not thread_id:
                return (
                    f"thread/start: threadIdが返されませんでした"
                    f" (result: {json.dumps(result)[:200]})"
                ), "error"

            # 2. messagesをテキストに統合
            user_text = self._format_messages(messages)

            # 3. turn/start
            turn_req_id = self._send("turn/start", {
                "threadId": thread_id,
                "input": [{"type": "text", "text": user_text}],
            })
            # turn/startのレスポンスを待つ
            self._wait_for_response(turn_req_id, timeout=30.0)

            # 4. ストリーミングイベントを収集して完了を待つ
            return self._collect_turn_output(timeout=300.0)

    @staticmethod
    def _format_messages(messages: list[dict]) -> str:
        """messages配列をテキストに統合."""
        parts = []
        for msg in messages:
            role = msg.get("role", "user").upper()
            content = msg.get("content", "")
            parts.append(f"[{role}]\n{content}")
        return "\n\n".join(parts)
