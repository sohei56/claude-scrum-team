# ECC Plugin Sub-Agent Catalog Integration

**Date:** 2026-04-11
**Status:** Draft

## Summary

`install-subagents` スキルを拡張し、ECCプラグインのエージェント群を
追加のカタログソースとして参照できるようにする。これにより、
code-reviewer、security-reviewer、tdd-guide、architectなどの専門家
エージェントをPBI実装時に動的に選択・利用可能になる。

## Background

現在の `install-subagents` スキルは awesome-claude-code-subagents
カタログ（`.claude/subagents-catalog/categories/`）のみを参照している。
ECCプラグイン（Everything Claude Code）は38の専門家エージェントを
提供しており、これらをサブエージェント候補として活用できる。

## Design

### 変更対象

`skills/install-subagents/SKILL.md` の1ファイルのみ。

### カタログソース

Step 2「Browse Catalog」を複数カタログの走査に拡張する。

| 優先度 | カタログ名 | パス | 形式 |
|--------|-----------|------|------|
| 1 | awesome-claude-code-subagents | `.claude/subagents-catalog/categories/` | カテゴリ別サブディレクトリ |
| 2 | ECC Plugin | `~/.claude/plugins/cache/ecc/ecc/*/agents/` | フラットな `.md` ファイル群 |

### 走査ロジック

1. 各カタログソースのパスが存在するか確認する
2. 存在するカタログのエージェント定義ファイル（`.md`）を列挙する
3. 各ファイルのYAMLフロントマター（`name`, `description`）を読み、
   PBI要件との関連度を判断する
4. 複数カタログに同名エージェントがある場合、優先度の高いカタログを
   採用する（awesome-claude-code-subagents > ECC）

### ECCエージェントの活用想定

| ECCエージェント | Scrumフェーズ | 用途 |
|----------------|-------------|------|
| `architect` | design | 設計ドキュメントのアーキテクチャレビュー |
| `tdd-guide` | implementation | テストファースト手法のガイド |
| `security-reviewer` | implementation | セキュリティ脆弱性チェック |
| `code-reviewer` | cross-review | コード品質レビューの補助 |

これらは代表例であり、PBI内容に応じてECCの他のエージェント
（e2e-runner、performance-optimizerなど）も選択対象となる。

### Graceful Degradation

既存のgraceful degradationポリシーをECCカタログにも適用する:

- ECCプラグインが未インストールの場合、そのカタログをスキップする
- ECCプラグインのバージョンが変わりパスが変わった場合、glob
  パターン（`*/agents/`）で対応する
- カタログソースが全て利用不可でも、開発者は通常通り実装を進められる

### 変更しないもの

- `agents/developer.md` — 変更不要（既にinstall-subagentsスキルの
  呼び出しとTask toolによるサブエージェント利用が定義済み）
- `agents/scrum-master.md` — 変更不要
- 各セレモニースキル（design, implementation, cross-review）—
  サブエージェントの利用はdeveloperの判断で行われるため変更不要
- データモデル — `sprint.json` の `developers[].sub_agents` は
  既にサブエージェント名の記録に対応済み

### Inputs（更新後）

- PBI assignment（`backlog.json` → assigned PBI details）
- カタログパス1: `.claude/subagents-catalog/categories/`
- カタログパス2: `~/.claude/plugins/cache/ecc/ecc/*/agents/`

### Outputs（変更なし）

- `.claude/agents/*.md` — インストール済みサブエージェント定義
- `sprint.json` → `developers[].sub_agents` — 実行時に記録

## Testing

- ECCプラグインがインストール済みの環境で、install-subagentsスキルが
  ECCエージェントをカタログとして認識すること
- ECCプラグインが未インストールの環境で、既存のカタログのみで
  正常動作すること
- 両カタログが利用不可の環境で、graceful degradationが機能すること
