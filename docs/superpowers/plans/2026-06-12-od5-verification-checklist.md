# OD-5 Verification Checklist (2026-06-12)

cleanup-audit OD-5 で導出された **target-project 実機検証 3 項目** を 1
ターンで確認するための手順書。フレームワーク repo (このリポジトリ) では
登録されていない hook と、フレームワーク repo に存在しない alias の
実機挙動を確かめる。

## 前提

- 任意の target project 配下で `sh /path/to/claude-scrum-team/scrum-start.sh`
  実行済 (または `setup-user.sh` で `.claude/` 一式デプロイ済)
- `.scrum/config.json` で `po_mode: "agent"` を設定 (Item 1 用)
- 別ターミナルで `tail -f .scrum/communications.json` および `.scrum/dashboard.json`
  を見られる状態

## Item 1: `claude-fable-5` alias が解決するか

**背景**: `agents/product-owner.md` の `model: claude-fable-5` は公開 alias
一覧に該当無し。spawn 試行で確証する。

**手順**:
```
（SM ペインで実行）
（テスト用に PO への 1 件の dummy 質問を SendMessage で送る）
```

具体的には `.scrum/communications.json` への append-communication 経由で
`[test] PO_DECISION_REQUEST kind=spec_clarification ...` を 1 件入れ、
Stop すると SM が product-owner teammate を spawn する流れを観察する。
あるいは autonomous-PO モードで 1 iteration 回す方が簡単 (autonomous
watchdog が PO を spawn するため)。

**期待**:
- product-owner teammate が `claude-fable-5` で spawn → 成功
- もしくは "unknown model" 系の API エラーが Claude Code 側で出る → **要対応**

**結果記録**:
- [ ] spawn 成功 (alias 実在) — そのまま運用継続
- [ ] spawn 失敗 (`unknown model` 等) — `agents/product-owner.md:9` を有効な
      alias (`opus` / `claude-opus-4-7` 等) に修正、bats も合わせて再修正

## Item 2: `PostToolUse` matcher で `SendMessage` / `Agent` が発火するか

**背景**: `scripts/setup-user.sh:270` heredoc が PostToolUse の matcher に
`Agent` と `SendMessage` を含めている。`hooks/dashboard-event.sh:206,227` に
対応ハンドラが存在するが、Claude Code が実際に PostToolUse をこれら
メタツールで発火するかは未確認。

**手順**:
1. SM ペインから明示的に `Agent(subagent_type="developer", ...)` を 1 回起動
2. 起動完了直後に `.scrum/dashboard.json` および `.scrum/communications.json`
   を確認

**期待**:
- `dashboard.json` の `events[]` に `tool_use` か `task_completed` 行が追加
- `communications.json` の `messages[]` に `agent_spawn` (type) でエントリが
  追加 (handler は line 224 で append)

**結果記録**:
- [ ] 両ファイルに対応エントリ追加 → matcher 維持
- [ ] エントリ追加されず → setup-user.sh の matcher から該当を削除、
      dashboard-event.sh のハンドラもデッドコードとして整理

同様に `SendMessage` ツールも 1 回手動発火し、`communications.json` の
`messages[]` に該当エントリが追加されるか確認 (handler は line 251)。

## Item 3: `FileChanged` event は誰が emit するか

**背景**: `scripts/setup-user.sh:357-366` の heredoc で `FileChanged` event
が登録されている。`hooks/dashboard-event.sh:382` に handler 存在。しかし
Anthropic 公式ドキュメント上で `FileChanged` という event は明記されておらず、
発火元 (Claude Code 本体 / dashboard の watchdog Python / 他) は未確認。

**手順**:
1. `.scrum/dashboard.json` の `events[]` を初期状態 (空 or 既知の最後の event
   timestamp) で記憶
2. target project 内で **Claude Code を介さず** ファイル変更 (例: 別 terminal
   から `echo x > some-file.txt`)
3. 10 秒待機後、`.scrum/dashboard.json` を再確認

**期待**:
- 新規 event (`file_changed` type) が追加されている → FileChanged 動作
- 追加されない → FileChanged は Claude Code が **emit していない**
  ので `setup-user.sh` から削除し、`dashboard-event.sh` の handler も削除

**結果記録**:
- [ ] FileChanged event 観測 → matcher / handler 維持
- [ ] 観測されず → matcher / handler を削除する別 PR を作成

## 検証完了後の後始末

3 項目すべてに結果を記入したら、このファイルを以下のいずれかへ:
- 全て期待どおり (matcher 全部維持 + claude-fable-5 実在) → このファイルを
  削除 (`git rm`) し、メモリ `project_cleanup_audit_2026_06_12.md` に結果
  を追記
- いずれか NG → 別 PR (`fix(setup-user): drop dead matcher` 等) を切り、
  該当箇所を修正してこのファイルを削除

## 2026-06-13 cleanup-audit 追加項目

cleanup-audit 2026-06-13 の OD-B / OD-E / OD-F は本 checklist と
同じ実機検証パスでまとめて潰すのが効率的。Item 1〜3 のついでに
以下も観測する。

### OD-B addendum: `dashboard.json.change_type` 実機分布

Item 3 (FileChanged 発火) と同セッションで観測:

- FileChanged が発火する場合、`.scrum/dashboard.json.events[].change_type`
  に `created` / `modified` / `deleted` が現れるか?
  - **すべて `modified`** → schema enum を `"modified" | null` に絞れる
  - **`created` / `deleted` も出現** → 現行 schema enum を維持し説明文を
    追加 (`docs/contracts/scrum-state/dashboard.schema.json`)。

判定後、stale-refs #27 を閉じる。

### OD-E addendum: `effort: xhigh` が parser に honor されるか

Item 1 (`claude-fable-5` alias) と同セッションで観測:

- PO teammate (`agents/product-owner.md`) は `model: claude-fable-5`
  かつ `effort: xhigh`。Item 1 が PASS (alias 解決) した時点で teammate
  session 開始ログを確認:
  - `effort: xhigh` が strapline / debug log に現れる → 効いている。pin
    維持で OK。
  - `effort` が `ultra` (or 公式 enum 値) に silently coerce されている →
    `agents/{requirement-conformance,functional-quality,security,maintainability,docs-consistency}-reviewer.md` および `product-owner.md` の `effort:` を `ultra` に書き換える別 PR を切る。

### OD-F addendum: dead-hooks F1-F4 確認方針

dead-hooks 監査 § Findings (F1-F4) の各 matcher について、本 checklist
Item 2, 3 と同セッション内で `.scrum/dashboard.json` / `.scrum/communications.json` を tail:

- `tool_name: "Agent"` の PostToolUse → F1 (Agent / SendMessage)
- `event_type` に `task_completed` → F3
- `event_type` に `teammate_idle` / `subagent_start` / `stop_failure` → F4
- `event_type: "file_changed"` で外部 emitter 起源のもの → F2

各 matcher について 1 Sprint 観測後 0 件であれば、setup-user.sh
heredoc の該当ブロック + `dashboard-event.sh` の case 分岐を別 PR で
削除する。OD-F の決着もそこで付く。

## 関連

- cleanup-audit Synthesis: `/tmp/claude/cleanup-audit/SYNTHESIS.md` § OD-5
- agent frontmatter overhaul: メモリ `project_agent_frontmatter_overhaul.md`
- dashboard team log: メモリ `project_dashboard_team_log.md` (SendMessage
  実機発火が未検証、と既に記載)
