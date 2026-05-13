# Doc style — prefer lists over tables

A small rule that applies to every `.planning/` artifact, every `SKILL.md`, every `references/*.md`, and any Korean summary the user reads.

## The rule

**Default to headers + lists. Use a table only when you have a specific reason it must be a table.**

Reasons it can't be a list (i.e., tables are OK):

- **Decision matrix** — three or more columns of categorical inputs determine one output (e.g., the prep-precondition matrix in `flow:plan`: `worktree × branch × planning-dir → action`).
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

## When a table really is the right call

Keep it tight: 3+ columns, identical row shape, every column used. Example of a legitimate table (the prep-precondition decision matrix from `flow:plan`):

```markdown
| In worktree | On task branch | Has `.planning/.../meta.md` | Action |
|---|---|---|---|
| yes | yes | yes | Proceed. |
| no  | no  | no  | Stop and ask the user. |
| any | yes | no  | Branch reused — create planning dir. |
```

Each row's columns are categorical inputs to a decision; a list would lose the matrix shape.

## Summary

| Default | Use a table only for |
|---|---|
| Headers + lists (`- ` and `- [ ]`) | Decision matrices, comparison matrices, compact reference lookups |

(Yes, that's a table. Three columns of distinct categorical content. It earned its place.)
