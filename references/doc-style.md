# Doc style — Simplified Technical English, and lists over tables

Two rules that apply to every `.flow/tasks/` artifact, every `SKILL.md`, every `references/*.md`, every commit subject, every Issue / PR body, and any Korean summary the user reads:

1. **Sentence style** — write Simplified Technical English (ASD-STE100).
2. **Structure** — default to headers + lists; a table needs a reason.

## Sentence style — Simplified Technical English (ASD-STE100)

ASD-STE100 is the aerospace controlled-language standard. Apply this subset to everything you author:

- **One idea per sentence.** Split a sentence that needs two clauses to explain itself.
- **Length limits.** Procedural sentence: 20 words maximum. Descriptive sentence: 25 words maximum. Paragraph: 6 sentences maximum.
- **Active voice, simple tense.** "The skill reads `tasks.md`" — not "`tasks.md` is read by the skill".
- **One word, one meaning.** Choose one term per concept and reuse it for the whole document. Do not alternate `task dir` / `task folder` / `working dir`.
- **Imperative for instructions.** "Run `prep.sh`." — not "You would want to run `prep.sh`."
- **Spell out an abbreviation on first use**, then use the short form. Never invent a new short form.
- **No slang, no internet shorthand, no coined words, no jargon for flavor.** Write the plain word.
- **Noun clusters: three words maximum.** "review brief for the PR" — not "PR code review brief material document".

This covers prose, headings, bullet text, commit subjects, Issue / PR bodies, and every question put to the user.

### Korean text follows the same discipline

STE is defined for English. Apply its intent — not its word list — to the Korean user-facing docs:

- Short sentences, one idea each. No stacked subordinate clauses.
- Plain standard Korean. No slang, no clipped internet forms, no invented abbreviations.
- One term per concept, including the Korean-or-English choice. Do not switch between `브랜치` and `branch` inside one document.
- **Read the Korean back before you send it.** Confirm every syllable forms a real word. Observed corruption: `원격 브랜치` came out as `원적 밌랜치`, and `20개씩` as `20개낀`. Rewrite the string when a syllable looks wrong.

### Why

- Skills and references are read by an LLM at runtime. Ambiguous prose becomes wrong behavior.
- Briefs and PR bodies get one fast read, often on a phone.
- A stable vocabulary keeps diffs meaningful: a wording change then signals a real change.

## Structure — prefer lists over tables

**Default to headers + lists. Use a table only when you have a specific reason it must be a table.**

Reasons it can't be a list (i.e., tables are OK):

- **Decision matrix** — three or more columns of categorical inputs determine one output (e.g., the prep-precondition matrix in `flow:plan`: `worktree × branch × task-dir → action`).
- **Comparison matrix** — N items × M attributes, where readers visually scan across attributes (e.g., model registry in `references/models.md`).
- **Compact reference lookup** — N rows of identical shape that a reader will search by row key, and where every row genuinely uses every column.

Anything else → list.

## Why

- **Renderer drift.** Markdown tables render inconsistently across GitHub, VSCode preview, Bear, Obsidian, terminal previewers, Slack, and various LLM UIs. Column widths, alignment, and overflow all differ.
- **Mobile.** Tables overflow horizontally on phones. Readers either side-scroll or get cut off.
- **Hard to edit.** Adding a row means re-aligning pipes. Adding a column means re-aligning every row. Lists take a new bullet.
- **Hard to diff.** A small text change in a table cell re-flows the whole row's alignment, polluting diffs.
- **Bad for `flow:develop` and other tooling.** Anything tracked by checkbox state (`[ ]` vs `[x]`) must be a list, not a table cell. See `../skills/plan/SKILL.md` tasks.md rule.

## How to convert a table to a list

### Status/audit "checklist" tables

Don't:

```markdown
| 항목                   | 상태 | 비고                       |
| ---------------------- | ---- | -------------------------- |
| Phase 0a 코드 산출물    | ✅   | Task 4.1~4.4 머지 완료     |
| Spike B 실측           | ❌   | provider별 결과 미입력     |
| iOS Plist audit 반영   | 🟡   | 문서 작성됨, 코드 미반영   |
```

Do:

```markdown
- ✅ **Phase 0a 코드 산출물** — Task 4.1~4.4 머지 완료
- ❌ **Spike B 실측** — provider별 결과 미입력
- 🟡 **iOS Plist audit 반영** — 문서 작성됨, 코드 미반영
```

If items are checkable, use `- [ ]` / `- [x]` instead of emoji.

### Key-value "spec" tables

Don't:

```markdown
| Field         | Value                       |
| ------------- | --------------------------- |
| bundleId      | `com.estsoft.gepeto`        |
| target SDK    | 34                          |
| min SDK       | 24                          |
```

Do:

```markdown
- **bundleId** — `com.estsoft.gepeto`
- **target SDK** — 34
- **min SDK** — 24
```

### Grouped facts — use headers + lists

If you have a "Category × items" table, split it into sub-headers:

```markdown
### Code artifacts
- ✅ `app.config.ts`
- ✅ `ChatWebView` component
- ❌ `assetlinks.json` draft

### Device validation
- ❌ EG-1 (iOS)
- ❌ EG-2 (Android)
```

This is easier to scan on a phone and survives renderer drift.

## GitHub body gotcha — ordered lists

In GitHub Issue / PR / comment bodies, **do not prefix a list number with `#`.** GitHub auto-links `#N` as an issue/PR reference, so `#1.` turns into a link to issue 1 instead of a list marker. Write plain `1.` `2.` `3.`. (This is a rendering gotcha, not a style preference — it produces wrong links, not just ugly ones.) Cross-referenced from `commit-conventions.md`.

## When a table really is the right call

Keep it tight: 3+ columns, identical row shape, every column used. Example of a legitimate table (the prep-precondition decision matrix from `flow:plan`):

```markdown
| In worktree | On task branch | Has `.flow/tasks/.../prepare.md` | Action |
|---|---|---|---|
| yes | yes | yes | Proceed. |
| no  | no  | no  | Stop and ask the user. |
| any | yes | no  | Branch reused — create task dir. |
```

Each row's columns are categorical inputs to a decision; a list would lose the matrix shape.

## Summary

| Default | Use a table only for |
|---|---|
| Headers + lists (`- ` and `- [ ]`) | Decision matrices, comparison matrices, compact reference lookups |

(Yes, that's a table. Three columns of distinct categorical content. It earned its place.)
