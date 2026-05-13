# Posting Inline Code Review Comments on a PR

GitHub draws a hard line between **issue comments** (general top-level PR comments) and **review comments** (anchored to a specific file:line). `gh pr review --comment` only does the former. To post inline comments programmatically you need the **REST review API**, which `gh api` can drive.

## High-level mechanism

1. Compute the diff/positions for the lines you want to comment on.
2. POST a single review object containing an array of `comments`, each pointing to a file path and a line.
3. Use `event: "COMMENT"` (or `REQUEST_CHANGES` / `APPROVE`) to publish the review in one shot.

This is preferred over posting comments one-at-a-time because it groups them under a single review on the PR.

## Payload shape

```bash
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  /repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/reviews \
  --input - <<'JSON'
{
  "body": "<top-level summary, Korean>",
  "event": "COMMENT",
  "comments": [
    {
      "path": "src/auth/google.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "..."
    },
    {
      "path": "src/auth/google.test.ts",
      "line": 17,
      "side": "RIGHT",
      "body": "..."
    }
  ]
}
JSON
```

- `path`: relative to repo root, exactly as it appears in the diff.
- `line`: 1-indexed line number in the file at the head commit (the new version, for `RIGHT`).
- `side`: `RIGHT` (after the change) or `LEFT` (before). For most review comments use `RIGHT`.
- For a multi-line range, add `"start_line": N` and `"start_side": "RIGHT"`.

## Required body format for each inline comment

Each inline comment body **MUST** start with a severity tag and end with a model signature. The format is fixed so reviewers downstream can grep / filter:

```
**[CRITICAL]** Brief one-line headline.

<detailed body in Korean>

— signed: gemini-3.1-pro
```

Severity tag values: `[CRITICAL]` (must fix before merge), `[MAJOR]` (should fix), `[MINOR]` (nice to have), `[NIT]` (style/preference), `[QUESTION]` (asking for clarification).

The signature line (`— signed: <model-id>`) tells the human which model raised the point. When multiple models flagged the same line, list them comma-separated: `— signed: gemini-3.1-pro, kimi-k2.6`.

## Top-level review body

The review's top-level `body` field is the **Korean aggregated summary** the user reads first. It comes from `code-reviews/code-summary.md` content. Include:

1. 전체 평가 한 줄
2. 합의된 주요 이슈 (3-5개)
3. 인라인 코멘트 개수 by 심각도
4. 머지 권장 여부

## Verifying the post

```bash
gh pr view <PR> --json reviews --jq '.reviews[-1] | {state, author: .author.login, comments: .comments | length}'
```

Should show your review with the expected comment count.

## Failure modes to watch for

- **Wrong line number** — GitHub rejects the comment if the line is not part of the diff. Run `git diff origin/main...HEAD -- <file>` first to confirm the line is in the patch.
- **Stale `path`** — if a file was renamed after review started, the path must match the current PR diff.
- **Too-long body** — single comments over ~65k chars get truncated. Split into multiple comments or shorten.
