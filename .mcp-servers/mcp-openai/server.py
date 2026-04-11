"""MCP Server: codex app-server経由でOpenAIモデルを呼び出すゲートウェイ.

codex app-serverを常駐プロセスとして起動し、JSON-RPC通信でモデルを呼び出す。
ChatGPTアカウント認証（OAuth）で動作し、API別課金は不要。事前に `codex login` が必要。
"""

from __future__ import annotations

import atexit
import json

from codex_client import CodexAppServerClient
from mcp.server.fastmcp import FastMCP

# ChatGPTアカウント認証で利用不可のモデル → gpt-5.4 にフォールバック
_UNSUPPORTED_CHATGPT_MODELS = {"gpt-4o", "gpt-4o-mini", "o3", "o3-mini", "o4-mini"}
_FALLBACK_MODEL = "gpt-5.4"

mcp = FastMCP("mcp-openai")
_client: CodexAppServerClient | None = None


def _get_client() -> CodexAppServerClient:
    """Lazy initialization でクライアントを取得."""
    global _client
    if _client is None or not _client.is_alive():
        if _client is not None:
            _client.stop()
        _client = CodexAppServerClient()
        _client.start()
    return _client


def _shutdown() -> None:
    """MCP Serverシャットダウン時にapp-serverプロセスを停止."""
    global _client
    if _client is not None:
        _client.stop()
        _client = None


atexit.register(_shutdown)


def _parse_response(text: str) -> tuple[str, str]:
    """レスポンスからSTATUS行を抽出し、本文とstatusに分離する."""
    lines = text.strip().split("\n")
    status = "complete"
    response_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("STATUS:"):
            status_value = stripped.split(":", 1)[1].strip().lower()
            if status_value in ("complete", "needs_info"):
                status = status_value
        else:
            response_lines.append(line)
    return "\n".join(response_lines).strip(), status


@mcp.tool()
def openai_chat(
    model: str,
    system_prompt: str,
    messages: str,
) -> str:
    """codex app-server経由でOpenAIモデルを呼び出す.

    Args:
        model: 使用するモデル名 (例: "gpt-5.4")。ChatGPTアカウント非対応モデルは自動でgpt-5.4にフォールバック
        system_prompt: システムプロンプト（ペルソナ・レビュー基準を含む）
        messages: JSON文字列。会話履歴の配列。各要素は {"role": "user"|"assistant", "content": "..."} の形式。
                  初回は [{"role": "user", "content": "レビュー依頼内容"}] の1件のみ。
                  質問ループ時は assistant(質問) + user(回答) を追記していく。

    Returns:
        JSON文字列。{"response": "...", "status": "complete"|"needs_info"} の形式。
        status が "needs_info" の場合、response に質問が含まれている。
        呼び出し元は回答を messages に追加して再度呼び出す。
    """
    try:
        parsed_messages = json.loads(messages)
    except json.JSONDecodeError as e:
        return json.dumps(
            {
                "response": f"messages のJSONパースに失敗しました: {e}",
                "status": "complete",
            },
            ensure_ascii=False,
        )

    # ChatGPTアカウントで非サポートのモデルを自動フォールバック
    effective_model = model
    if model.lower() in _UNSUPPORTED_CHATGPT_MODELS:
        effective_model = _FALLBACK_MODEL

    try:
        client = _get_client()
    except FileNotFoundError as e:
        return json.dumps(
            {"response": str(e), "status": "complete"},
            ensure_ascii=False,
        )

    try:
        raw_response, turn_status = client.chat(
            effective_model, system_prompt, parsed_messages
        )

        if turn_status == "error":
            return json.dumps(
                {
                    "response": f"codex app-server エラー: {raw_response}",
                    "status": "complete",
                },
                ensure_ascii=False,
            )

        if turn_status == "timeout":
            return json.dumps(
                {
                    "response": f"codex app-server タイムアウト。部分レスポンス: {raw_response}",
                    "status": "complete",
                },
                ensure_ascii=False,
            )

        if not raw_response.strip():
            return json.dumps(
                {
                    "response": "codex app-serverから空のレスポンスが返されました",
                    "status": "complete",
                },
                ensure_ascii=False,
            )

        response, status = _parse_response(raw_response)
        return json.dumps(
            {"response": response, "status": status},
            ensure_ascii=False,
        )

    except TimeoutError as e:
        return json.dumps(
            {
                "response": f"codex app-server実行がタイムアウトしました: {e}",
                "status": "complete",
            },
            ensure_ascii=False,
        )
    except Exception as e:
        return json.dumps(
            {
                "response": f"codex app-server呼び出しに失敗しました: {type(e).__name__}: {e}",
                "status": "complete",
            },
            ensure_ascii=False,
        )


if __name__ == "__main__":
    mcp.run()
