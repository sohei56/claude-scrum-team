# Token Efficiency Rule

Apply to ALL agents, skills, and context. Keep all technical substance. Kill fluff only.

References: [caveman](https://github.com/JuliusBrussee/caveman), [genshijin](https://github.com/InterfaceX-co-jp/genshijin)

## English Rules (caveman style)

Drop: articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries (sure/certainly/of course/happy to), hedging (might be worth/you could consider/it would be good to).

Compress: "in order to"→"to", "make sure to"→"ensure", "implement a solution for"→"fix". Fragments OK. Short synonyms (big not extensive, fix not remediate).

Keep exact: technical terms, code blocks, error messages, file paths, commands, URLs.

Pattern: `[thing] [action] [reason]. [next step].`

Bad: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
Good: "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

## Japanese Rules (genshijin style)

Drop: 敬語(です/ます→体言止め), クッション言葉, 前置き, ぼかし, 冗長助詞/接続詞, 自明な助詞/副詞/指示詞.

Allow: 体言止め, キーワード列挙(スペース区切り), 漢字連結助詞省略, 接続助詞→矢印「→」.

## Both Languages

- Markdown tables→bullet lists (tables waste tokens)
- Answer only what asked. No exhaustive lists, unsolicited examples, auto-generated code samples
- Remove duplicate meanings (synonyms near each other→keep one)
- Drop self-evident predicates
- One example per pattern, not multiple

## Agent-to-Agent Communication

- Progress: `[PBI-ID] [status]. [remaining/blockers].`
- Review: `[Verdict] [count] findings. [top issue].`
- Error: `[type] [file:line]. [cause]. [proposal].`

## User-Facing Communication

- Natural language maintained (FR-015) but stripped of fluff
- Structured data→concise summary, no raw JSON
- Security/destructive ops→switch to clear full sentences→resume terse after

## Skill/Context Compression

- Descriptions: human-readable minimum
- Redundant preconditions/exit criteria: keep essentials only
- Step explanations: action + condition only. Skip rationale when obvious
- Command examples: one pattern only, never multiple
