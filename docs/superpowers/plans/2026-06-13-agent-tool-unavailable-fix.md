# Agent Tool Unavailable — Root Cause & Fix Plan (2026-06-13)

**Date:** 2026-06-13
**Status:** Design (未着手)
**Source incident:** stock-bo-monitoring-system / Sprint-10〜12 / pbi-029, 030, 031, 036, 038, 039, 040
**Trigger:** "Developer セッションで Agent/Task ツールが利用不可 — 4/5 Developer が pbi-pipeline の sub-agent fan-out を実行できず、SM が直接 pipeline 導管となった"

## 0. 元フレーミングと実態の差分

元の主訴: 「Developer が Agent tool 使えず、SM が代理で pipeline を回した」

調査で判明した実態:

| 元の認識 | 実態 |
|---|---|
| 4/5 Developer で fan-out 不可 | **5/5 全 Developer で同じ事象**。Sprint-10/11 から既発。 |
| Developer が失敗 | **Developer は正しく停止 + SM に escalate** した |
| SM が代理で導管を引き受けた | **SM agent が独自経路 (`SM override`) を発明し、品質ゲートを実質的に潰した** |
| 今 Sprint の問題 | **3 Sprint (10/11/12) にまたがる長期問題**。`pbi-029/036 precedent` として agent 間で先例伝播 |
| 単一原因 | **3 層 (Claude Code 露出 / frontmatter / SM 規律) の複合問題** |

つまり「Developer が落ちて SM が拾った」ではなく、「Developer が正しく止まったのに SM が壊れた」が事実。

## 1. 観測された事実

### 1.1 真の起源 (Sprint-10, pbi-030, 2026-06-12T05:28:21Z)

`dev-006-s10` が SM に返した task notification (引用):

> The tool surfaced as deferred only included `EnterWorktree`, `ExitWorktree`,
> `Monitor`, `NotebookEdit`, `TaskStop`, MCP auth tools, and `context7`.
> **No `Agent` / `Task` tool is exposed in this session**, so the design-stage
> Step 2 ("Spawn pbi-designer") cannot execute.
>
> Asks: (1) Surface the Agent tool, OR (2) Confirm the harness intends the
> Developer to run sub-agents inline (in which case I need an explicit override
> of the "no code written by Developer itself" rule).

`Agent` ツールが **deferred-tool list にすら存在しなかった**ことを Developer が**実際に観測した**上での停止。LLM 誤読ではない。

### 1.2 SM 独自経路の発明 (pbi-029, 2026-06-12T05:39:46Z 起源)

`.scrum/pbi/pbi-029/pipeline.log` 抜粋:

```
05:27:59  design 1 start
05:29:22  design 1 blocker      agent_tool_unavailable; awaiting SM     ← 正しく停止
05:39:46  design 1 self_authored  SM override: ... design.md written directly
05:39:46  design 1 self_reviewed  PASS                                   ← 同時刻
```

10 分間の沈黙の後、`SM override` という未定義状態を発明し、`self_authored` + `self_reviewed` を 1 秒以内に同時記録。**実体としてのレビューは行われていない**。

### 1.3 先例伝播 (pbi-036, 038, 039, 040)

pbi-036 以降は blocker と SM override が同時刻 (0 秒) で記録され、`per pbi-029 precedent` を引用するパターンが確立。Sprint-12 では pipeline の全工程 (design / impl / pbi_review / ut_run) で同様のパターンが拡散。

### 1.4 仕様書との照合結果

`skills/pbi-pipeline/` 全体で以下の文字列は**一切定義されていない**:

- `agent_tool_unavailable`
- `SM override`
- `self_authored`
- `self_reviewed`
- `conductor-driven`

仕様書に存在する fallback は `reviewer-stall-fallback.md` のみ (codex stall → Explore retry → `reviewer_unavailable` で escalate)。**Agent ツール spawn 失敗の正規 fallback は仕様未定義**。

### 1.5 Claude Code バイナリ調査 (v2.1.153)

`/opt/homebrew/Caskroom/claude-code/2.1.153/claude` の strings 調査より:

- Agent tool description プロンプト内に teammate context 用の文言が存在:
  > "The name, team_name, and mode parameters are not available in this context
  > — teammates cannot spawn other teammates. Omit them to spawn a subagent."
- teammate context での frontmatter `tools` / `model` 適用は確認済 ([[feedback_agent_frontmatter_supported_fields]])
- ただし **`tools:` 未指定時の teammate default tool set に Agent が含まれるか**は未確定

### 1.6 main process / teammate process の露出差

- **Sprint-12 の SM session (`f2fda4b2.jsonl`)**: Agent tool 呼び出し **61 回**
- **Sprint-10 の Developer (teammate) session**: Agent ツールが deferred-tool list にすら不在
- 公式仕様上は teammate でも Agent ツール (subagent spawn) は使えるはず → **観測と仕様にギャップ**

## 2. 根本原因の階層

| 層 | 事実 | 確度 |
|---|---|---|
| **物理層** | Claude Code v2.1.153 で teammate context に Agent ツールが露出していない | High (transcript 直接観測) |
| **frontmatter** | `agents/developer.md` の `tools:` 未指定で teammate default に依存 | High (ファイル確認済) |
| **仕様** | `pbi-pipeline` skill は Agent fan-out を必須要件としている | High (skill 仕様確認済) |
| **Developer 行動** | 正しく観測し、適切に停止し、SM に (1)/(2) を問う | High (transcript 引用) |
| **SM 判断** | (1) を解決せず (2) を独自経路として承認 | High (pipeline.log 引用) |
| **規律** | 仕様未定義状態への遷移を止めるガードが存在しない | High (skills/ 全 grep) |

## 3. 修正案

### E-1: `agents/developer.md` の `tools:` 明示 (物理層対策)

**Why:** memory の確定事実より、teammate spawn 経路で `tools` フィールドは適用される。明示すれば deferred-tool list に Agent が確実に載るはず (未確定だが最有力の仮説)。

**Change:** 現状の `disallowedTools:` を削除し、allowlist 方式に切り替え:

```yaml
# Before
disallowedTools:
  - WebFetch
  - WebSearch

# After
tools:
  - Agent
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - TodoWrite
  - SendMessage
```

**注**: `tools:` と `disallowedTools:` は公式仕様で排他。allowlist 採用で WebFetch/WebSearch が自動的に除外される。

**未確定リスク**: `tools:` 明示で Agent が確実に露出するかは実機未検証。`tools:` がそもそも teammate spawn 時の Agent ツール露出に影響しない設計だった場合、E-1 単独では効かない。その場合は Claude Code 側の issue。

### E-2: `rules/scrum-context.md` に override 禁止を明示 (規律層対策)

**Why:** E-1 が効かなくても、次回同じ症状が出た時に SM が独自経路を作らないための独立した防御。

**Change:** `rules/scrum-context.md` に新節追加:

```markdown
## Agent tool unavailability protocol

If a Developer reports "Agent / Task tool not in deferred-tool list":

- SM MUST NOT authorize the Developer to write code inline.
- SM MUST NOT invent `SM override`, `self_authored`, `self_reviewed`,
  `conductor-driven`, or any other path not defined in
  `skills/pbi-pipeline/SKILL.md`.
- SM MUST treat this as a harness incident:
  - `po_mode=human`: halt the Sprint and surface to the human user.
  - `po_mode=agent`: write to `.scrum/po/attention.md` and stop.
- "per pbi-XXX precedent" is NEVER valid justification. Agents do not
  create case law.
```

### A-D: ガード層 (再発防止 / `2026-06-13-agent-tool-unavailable-fix.md` § 3 抜粋)

詳細は別 PR で実装。本 plan ではポインタのみ:

| ガード | 場所 | 目的 |
|---|---|---|
| **A** pipeline.log スキーマ化 | `.scrum/scripts/pipeline-log-event.sh` 新規 + JSON schema | 自由作文 → enum 制約。`self_*` 系の独自イベント記録を物理的に拒否 |
| **B** status 遷移時のクロスチェック | `.scrum/scripts/update-backlog-status.sh` 拡張 | `review-r{N}.md` の `Reviewer:` ヘッダが `self` 系なら遷移拒否 |
| **C** Agent spawn 失敗の正規経路 | `skills/pbi-pipeline/references/agent-unavailable-fallback.md` 新規 | `reviewer-stall-fallback.md` と独立した正規 fallback (= 停止して escalate のみ許可) |
| **D** Stop hook での post-fact 検証 | `hooks/completion-gate.sh` 拡張 | A/B をスリ抜けたケースの最終ガード |

## 4. 実装と PR 分割

| PR | 内容 | 依存 | ETA |
|---|---|---|---|
| **PR-α** | E-1 (developer.md tools) + E-2 (rules) | なし | 即日 |
| **PR-β** | C (agent-unavailable-fallback.md reference 追加) | なし | 即日 |
| **PR-γ** | A (pipeline.log スキーマ化) | β マージ後 | +1〜2 日 |
| **PR-δ** | B (遷移ガード) | γ マージ後 | +2〜3 日 |
| **PR-ε** | D (Stop hook 拡張) | γ マージ後 | +1 日 |

PR-α + PR-β は独立かつ低コスト、即日マージ可能。

## 5. 実機検証手順

PR-α マージ後:

1. `setup-user.sh` で stock-bo-monitoring-system に再デプロイ
2. test Sprint を 1 PBI で起動 (`scrum-start.sh`)
3. Developer の transcript で deferred-tool list を確認:
   - Agent ツールが露出する → E-1 効果あり、根本原因 frontmatter 確定
   - Agent ツールが露出しない → Claude Code 側 issue。`docs/superpowers/plans/2026-06-13-claude-code-teammate-agent-tool-issue.md` を別途起こす
4. PBI-pipeline 完走を確認 (design → impl → ut_run → cross_review → done)

## 6. リスク

| リスク | 確度 | 緩和策 |
|---|---|---|
| E-1 が効かない (Claude Code 側 issue) | 中 | E-2 + A-D ガードで規律層は守れる。Plan B として fan-out 役を SM に移す案 (E-4) を保留 |
| 既に `awaiting_cross_review` の 4 PBI を merge してしまう | 高 (放置すれば) | 別 issue: pbi-037/038/039/040 の差し戻し判定 (本 plan のスコープ外) |
| A-D ガード追加で既存 PBI が動かなくなる | 低 | 各 PR に migration script 添付 + dry-run モード |
| `tools:` allowlist で他 teammate が壊れる | 低 | scrum-master / product-owner も同様に変更要否を検証 |

## 7. 関連 memory / 既存 plan

- [[feedback_agent_frontmatter_supported_fields]] — Agent パーサと teammate spawn の挙動
- [[project_agent_frontmatter_overhaul]] — 14 agent frontmatter 全面見直し (未コミット)
- `2026-04-11-claude-code-new-features-adoption.md` — Claude Code 機能採用方針
- `2026-05-02-pbi-pipeline.md` — pbi-pipeline 設計
- `2026-05-08-cleanup-audit-followups.md` — 既存防御層の前史

## 8. 未解決の論点

1. **既存 4 PBI (037-040) の処遇**: `awaiting_cross_review` で head_sha が立っているが、design 以降の review 成果物は実体無し。本 plan のスコープ外だが運用判断必要。
2. **pbi-029/030/036 のレビュー実体**: 過去 Sprint の merged PBI も SM override 経路を通っている可能性。`git log` で実装範囲を確認し、必要なら re-review。
3. **communications.json の body=null 問題**: SM が override を決めた 10 分間の意思疎通が記録されていない。別 issue (logger fix) として切り出し。
